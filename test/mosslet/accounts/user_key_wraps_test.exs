defmodule Mosslet.Accounts.UserKeyWrapsTest do
  @moduledoc """
  Invariant tests for the WebAuthn PRF device-bound wrapping factor (#362/#363).

  See `docs/WEBAUTHN_PRF_DESIGN.md`. The whole point is the OR→AND flip, so the
  invariants below are the security contract, not incidental behaviour:

    * non-enrolled => exactly one `:password` wrap
    * enrolled     => zero `:password` wraps, one-or-more `:prf` wraps
    * enrollment is gated on a confirmed recovery key
    * un-enrolling the last device restores the password door (no bricking)
  """
  use Mosslet.DataCase, async: true

  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts
  alias Mosslet.Accounts.UserKeyWrap

  defp password_wrap_attrs do
    %{wrapped_user_key: "opaque-password-wrap-blob", wrap_salt: "cGFzc3NhbHQ="}
  end

  defp prf_wrap_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        wrapped_user_key: "opaque-prf-wrap-blob",
        wrap_salt: "cHJmc2FsdA==",
        credential_id: "credential-abc",
        prf_salt: "cHJmZXZhbHNhbHQ="
      },
      overrides
    )
  end

  defp with_recovery(user) do
    {:ok, user} =
      Accounts.setup_recovery_key(user, "recovery-secret-256bit", "encrypted-recovery-priv-blob")

    user
  end

  describe "backfill_password_wrap/2" do
    test "writes exactly one password wrap for a fresh user" do
      user = user_fixture()

      assert {:ok, %UserKeyWrap{kind: :password}} =
               Accounts.backfill_password_wrap(user, password_wrap_attrs())

      assert [%UserKeyWrap{kind: :password}] = Accounts.list_user_key_wraps(user)
      refute Accounts.prf_enrolled?(user)
    end

    test "is idempotent — never a second password wrap" do
      user = user_fixture()
      {:ok, _} = Accounts.backfill_password_wrap(user, password_wrap_attrs())

      assert {:ok, :already_present} =
               Accounts.backfill_password_wrap(user, password_wrap_attrs())

      assert length(Accounts.list_user_key_wraps(user)) == 1
    end

    test "DB partial index rejects a second password wrap" do
      user = user_fixture()
      {:ok, _} = Accounts.backfill_password_wrap(user, password_wrap_attrs())

      assert {:error, changeset} =
               user.id
               |> UserKeyWrap.password_changeset(password_wrap_attrs())
               |> Mosslet.Repo.insert()

      assert %{user_id: _} = errors_on(changeset)
    end
  end

  describe "enroll_prf_wrap/2 — the OR→AND flip" do
    test "is refused without a confirmed recovery key" do
      user = user_fixture()
      {:ok, _} = Accounts.backfill_password_wrap(user, password_wrap_attrs())

      assert {:error, :recovery_key_required} =
               Accounts.enroll_prf_wrap(user, prf_wrap_attrs())

      # nothing changed — password door still the only door
      assert [%UserKeyWrap{kind: :password}] = Accounts.list_user_key_wraps(user)
    end

    test "inserts the prf wrap AND deletes the password wrap" do
      user = user_fixture() |> with_recovery()
      {:ok, _} = Accounts.backfill_password_wrap(user, password_wrap_attrs())

      assert {:ok, %UserKeyWrap{kind: :prf}} =
               Accounts.enroll_prf_wrap(user, prf_wrap_attrs())

      wraps = Accounts.list_user_key_wraps(user)
      assert Enum.all?(wraps, &(&1.kind == :prf))
      refute Enum.any?(wraps, &(&1.kind == :password))
      assert Accounts.prf_enrolled?(user)
    end

    test "a failed prf insert never deletes the password door (anti-brick ordering)" do
      # design §8: insert-:prf-then-delete-:password is atomic in ONE
      # transaction. Force the :prf insert to fail with invalid attrs (missing
      # required credential_id/prf_salt) and assert the :password wrap SURVIVES —
      # the account is never left with zero unlock doors.
      user = user_fixture() |> with_recovery()
      {:ok, _} = Accounts.backfill_password_wrap(user, password_wrap_attrs())

      invalid_attrs = %{wrapped_user_key: "opaque-prf-wrap-blob", wrap_salt: "cHJmc2FsdA=="}

      assert {:error, %Ecto.Changeset{}} = Accounts.enroll_prf_wrap(user, invalid_attrs)

      # password door intact, no orphan :prf wrap, account NOT bricked
      assert [%UserKeyWrap{kind: :password}] = Accounts.list_user_key_wraps(user)
      refute Accounts.prf_enrolled?(user)
    end

    test "supports multiple prf wraps (multi-device)" do
      user = user_fixture() |> with_recovery()
      {:ok, _} = Accounts.backfill_password_wrap(user, password_wrap_attrs())

      {:ok, _} = Accounts.enroll_prf_wrap(user, prf_wrap_attrs(%{credential_id: "cred-1"}))

      {:ok, _} =
        Accounts.enroll_prf_wrap(
          user,
          prf_wrap_attrs(%{credential_id: "cred-2", ecosystem_hint: "apple"})
        )

      wraps = Accounts.list_user_key_wraps(user)
      assert length(wraps) == 2
      assert Enum.all?(wraps, &(&1.kind == :prf))
    end
  end

  describe "unenroll_prf_wrap/3 — no bricking" do
    test "removing the last device restores the password door" do
      user = user_fixture() |> with_recovery()
      {:ok, _} = Accounts.backfill_password_wrap(user, password_wrap_attrs())
      {:ok, prf} = Accounts.enroll_prf_wrap(user, prf_wrap_attrs())

      assert {:ok, :unenrolled} =
               Accounts.unenroll_prf_wrap(user, prf.id, password_wrap_attrs())

      assert [%UserKeyWrap{kind: :password}] = Accounts.list_user_key_wraps(user)
      refute Accounts.prf_enrolled?(user)
    end

    test "refuses to remove the last device without a replacement password wrap" do
      user = user_fixture() |> with_recovery()
      {:ok, _} = Accounts.backfill_password_wrap(user, password_wrap_attrs())
      {:ok, prf} = Accounts.enroll_prf_wrap(user, prf_wrap_attrs())

      assert {:error, :password_wrap_required} =
               Accounts.unenroll_prf_wrap(user, prf.id, nil)

      # rolled back — still enrolled, not bricked
      assert Accounts.prf_enrolled?(user)
    end

    test "removing one of several devices keeps the account enrolled" do
      user = user_fixture() |> with_recovery()
      {:ok, _} = Accounts.backfill_password_wrap(user, password_wrap_attrs())
      {:ok, prf1} = Accounts.enroll_prf_wrap(user, prf_wrap_attrs(%{credential_id: "cred-1"}))
      {:ok, _prf2} = Accounts.enroll_prf_wrap(user, prf_wrap_attrs(%{credential_id: "cred-2"}))

      assert {:ok, :still_enrolled} = Accounts.unenroll_prf_wrap(user, prf1.id, nil)

      wraps = Accounts.list_user_key_wraps(user)
      assert length(wraps) == 1
      assert Accounts.prf_enrolled?(user)
    end
  end
end
