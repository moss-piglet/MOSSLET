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

  describe "update_user_password enrolled re-wrap (design 10a, #368)" do
    @email "prf-pwchange@example.com"
    @old_pw "hello world hello world!"
    @new_pw "brand new passphrase words!"

    defp enrolled_user_with_wraps(credential_ids) do
      user = user_fixture(%{email: @email}) |> with_recovery()
      {:ok, _} = Accounts.backfill_password_wrap(user, password_wrap_attrs())

      wraps =
        for cid <- credential_ids do
          {:ok, wrap} =
            Accounts.enroll_prf_wrap(
              user,
              prf_wrap_attrs(%{
                credential_id: cid,
                wrapped_user_key: "old-blob-#{cid}"
              })
            )

          wrap
        end

      {Accounts.get_user!(user.id), wraps}
    end

    test "an enrolled password change does NOT create a :password wrap and keeps key_hash" do
      {user, [wrap]} = enrolled_user_with_wraps(["cred-1"])
      key_hash_before = user.key_hash

      rewraps = [%{"id" => wrap.id, "wrapped_user_key" => "new-blob-cred-1"}]

      assert {:ok, updated} =
               Accounts.update_user_password(user, @old_pw, %{password: @new_pw},
                 prf_rewraps: rewraps
               )

      wraps = Accounts.list_user_key_wraps(user)
      assert Enum.all?(wraps, &(&1.kind == :prf))
      refute Enum.any?(wraps, &(&1.kind == :password))
      assert Accounts.prf_enrolled?(user)

      assert updated.key_hash == key_hash_before

      assert Accounts.get_user_by_email_and_password(@email, @new_pw)
      refute Accounts.get_user_by_email_and_password(@email, @old_pw)
    end

    test "re-wraps EVERY :prf wrap's wrapped_user_key" do
      {user, wraps} = enrolled_user_with_wraps(["cred-1", "cred-2"])

      rewraps =
        for w <- wraps, do: %{"id" => w.id, "wrapped_user_key" => "rewrapped-#{w.credential_id}"}

      assert {:ok, _} =
               Accounts.update_user_password(user, @old_pw, %{password: @new_pw},
                 prf_rewraps: rewraps
               )

      reloaded = Map.new(Accounts.list_user_key_wraps(user), &{&1.credential_id, &1})

      for w <- wraps do
        assert reloaded[w.credential_id].wrapped_user_key == "rewrapped-#{w.credential_id}"
      end
    end

    test "refuses a PARTIAL re-wrap (would brick a device) and changes nothing" do
      {user, [w1, _w2]} = enrolled_user_with_wraps(["cred-1", "cred-2"])

      rewraps = [%{"id" => w1.id, "wrapped_user_key" => "only-one"}]

      assert {:error, :prf_rewraps_mismatch} =
               Accounts.update_user_password(user, @old_pw, %{password: @new_pw},
                 prf_rewraps: rewraps
               )

      assert Accounts.get_user_by_email_and_password(@email, @old_pw)

      blobs = Accounts.list_user_key_wraps(user) |> Enum.map(& &1.wrapped_user_key)
      assert Enum.sort(blobs) == Enum.sort(["old-blob-cred-1", "old-blob-cred-2"])
    end

    test "wrong current password errors without launching a re-wrap" do
      {user, [wrap]} = enrolled_user_with_wraps(["cred-1"])

      assert {:error, %Ecto.Changeset{} = changeset} =
               Accounts.update_user_password(user, "wrong password!!", %{password: @new_pw},
                 prf_rewraps: [%{"id" => wrap.id, "wrapped_user_key" => "x"}]
               )

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
      assert Accounts.get_user_by_email_and_password(@email, @old_pw)
    end

    test "list_prf_rewrap_params/1 returns opaque public params for each :prf wrap" do
      {user, _} = enrolled_user_with_wraps(["cred-1", "cred-2"])

      params = Accounts.list_prf_rewrap_params(user)
      assert length(params) == 2

      assert Enum.all?(params, fn p ->
               Map.has_key?(p, :id) and Map.has_key?(p, :credential_id) and
                 Map.has_key?(p, :prf_salt) and Map.has_key?(p, :wrap_salt)
             end)
    end
  end

  describe "update_user_password non-enrolled unchanged" do
    test "no :prf involvement; current-password validation still applies" do
      user = user_fixture(%{email: "prf-nonenrolled@example.com"})
      refute Accounts.prf_enrolled?(user)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Accounts.update_user_password(
                 user,
                 "invalid",
                 %{password: valid_user_password()},
                 []
               )

      assert %{current_password: ["is not valid"]} = errors_on(changeset)

      assert {:ok, _} =
               Accounts.update_user_password(
                 user,
                 valid_user_password(),
                 %{password: "new valid password hello!"},
                 []
               )

      assert Accounts.list_user_key_wraps(user) == []
    end
  end

  describe "key_hash retirement (board #370)" do
    test "enrolling retires User.key_hash (no password-only door on a DB dump)" do
      user = user_fixture() |> with_recovery()
      {:ok, _} = Accounts.backfill_password_wrap(user, password_wrap_attrs())
      assert is_binary(user.key_hash) and user.key_hash != ""

      {:ok, _prf} = Accounts.enroll_prf_wrap(user, prf_wrap_attrs())

      reloaded = Accounts.get_user!(user.id)
      assert reloaded.key_hash in [nil, ""]

      refute match?(
               {:ok, _},
               Mosslet.Accounts.User.valid_key_hash?(reloaded, valid_user_password())
             )
    end

    test "a failed prf insert leaves key_hash intact (anti-brick)" do
      user = user_fixture() |> with_recovery()
      {:ok, _} = Accounts.backfill_password_wrap(user, password_wrap_attrs())
      key_hash_before = user.key_hash

      invalid_attrs = %{wrapped_user_key: "opaque-prf-wrap-blob", wrap_salt: "cHJmc2FsdA=="}
      assert {:error, %Ecto.Changeset{}} = Accounts.enroll_prf_wrap(user, invalid_attrs)

      assert Accounts.get_user!(user.id).key_hash == key_hash_before
    end

    test "un-enrolling the last device restores key_hash from the password wrap" do
      user = user_fixture() |> with_recovery()
      {:ok, _} = Accounts.backfill_password_wrap(user, password_wrap_attrs())
      {:ok, prf} = Accounts.enroll_prf_wrap(user, prf_wrap_attrs())
      assert Accounts.get_user!(user.id).key_hash in [nil, ""]

      pw = password_wrap_attrs()
      assert {:ok, :unenrolled} = Accounts.unenroll_prf_wrap(user, prf.id, pw)

      restored = Accounts.get_user!(user.id).key_hash
      assert restored == pw.wrap_salt <> "$" <> pw.wrapped_user_key
    end

    test "removing a non-last device does NOT restore key_hash (still enrolled)" do
      user = user_fixture() |> with_recovery()
      {:ok, _} = Accounts.backfill_password_wrap(user, password_wrap_attrs())
      {:ok, prf1} = Accounts.enroll_prf_wrap(user, prf_wrap_attrs(%{credential_id: "cred-1"}))
      {:ok, _prf2} = Accounts.enroll_prf_wrap(user, prf_wrap_attrs(%{credential_id: "cred-2"}))

      assert {:ok, :still_enrolled} = Accounts.unenroll_prf_wrap(user, prf1.id, nil)
      assert Accounts.get_user!(user.id).key_hash in [nil, ""]
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
