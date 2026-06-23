defmodule Mosslet.Accounts.KeyPinTest do
  @moduledoc """
  Unified TOFU key-pin store (EPIC #291 / Phase 1 — #293, REVISED).

  Verifies the server-side half of the tamper-evident, per-(viewer, peer) pin:
    * `KeyPin.pin_changeset/3` sets the FKs + opaque blob explicitly and is NOT
      mass-assignable from user params (security invariant);
    * `Accounts.upsert_key_pin/3` round-trips the browser-sealed blob
      byte-for-byte AND is insert-only (a second upsert with a different blob
      does NOT overwrite — first-write-wins);
    * `Accounts.list_key_pins_for/2` batch-hydrates a peer_user_id => blob map;
    * confirmed connections preload `:reverse_user` so the peer's public keys
      reach the card for client-side fingerprinting.

  The match/mismatch verdict itself is computed entirely client-side (the
  fingerprint byte-contract is locked by test/mosslet/crypto/key_fingerprint_test.exs).
  """
  use Mosslet.DataCase

  alias Mosslet.Accounts
  alias Mosslet.Accounts.KeyPin

  @valid_password "hello world hello world"

  describe "KeyPin.pin_changeset/3" do
    test "sets the FKs and opaque blob explicitly" do
      viewer_id = Ecto.UUID.generate()
      peer_id = Ecto.UUID.generate()
      blob = "sealed-pin-blob"

      changeset = KeyPin.pin_changeset(viewer_id, peer_id, blob)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :user_id) == viewer_id
      assert Ecto.Changeset.get_change(changeset, :peer_user_id) == peer_id
      assert Ecto.Changeset.get_change(changeset, :pinned_fingerprint) == blob
    end

    test "is NOT mass-assignable — FKs/blob come from explicit args, not params" do
      # There is no `cast` of user params anywhere in the changeset: no
      # `changeset/2` arity exists, so a hostile params map can never be
      # mass-assigned. pin_changeset/3 takes scalar args only and rejects a
      # non-binary blob (no silent params coercion). Guards the AGENTS.md
      # server/browser-set field rule.
      refute function_exported?(KeyPin, :changeset, 2)

      hostile = %{"pinned_fingerprint" => "forged"}

      assert_raise FunctionClauseError, fn ->
        apply(KeyPin, :pin_changeset, [Ecto.UUID.generate(), Ecto.UUID.generate(), hostile])
      end
    end
  end

  describe "upsert_key_pin/3 + list_key_pins_for/2 (persisted)" do
    setup do
      user =
        Mosslet.AccountsFixtures.user_fixture(%{
          username: "pin_user_one",
          email: "pin_one@example.com",
          password: @valid_password
        })

      key = get_session_key(user, @valid_password)

      {:ok, user} =
        Accounts.update_user_onboarding_profile(user, %{name: "Pin One"},
          change_name: true,
          key: key,
          user: user
        )

      reverse_user =
        Mosslet.AccountsFixtures.user_fixture(%{
          username: "pin_user_two",
          email: "pin_two@example.com",
          password: @valid_password
        })

      r_key = get_session_key(reverse_user, @valid_password)

      {:ok, reverse_user} =
        Accounts.update_user_visibility(reverse_user, %{visibility: :connections}, key: r_key)

      {:ok, reverse_user} =
        Accounts.update_user_onboarding_profile(reverse_user, %{name: "Pin Two"},
          change_name: true,
          key: r_key,
          user: reverse_user
        )

      uconn_attrs = %{
        "color" => "rose",
        "temp_label" => "friend",
        "connection_id" => user.connection.id,
        "reverse_user_id" => user.id,
        "selector" => "username",
        "username" => "pin_user_two"
      }

      _ =
        Mosslet.UserConnectionFixtures.user_connection_fixture(uconn_attrs,
          user: user,
          reverse_user: reverse_user,
          key: key,
          r_key: r_key,
          confirm?: true
        )

      %{user: user, reverse_user: reverse_user, key: key, r_key: r_key}
    end

    test "round-trips the sealed blob byte-for-byte", %{
      user: user,
      reverse_user: reverse_user
    } do
      assert is_nil(Accounts.get_key_pin(user.id, reverse_user.id))

      # An opaque secretbox blob as the browser would produce (base64).
      blob = Base.encode64(:crypto.strong_rand_bytes(96))

      assert {:ok, %KeyPin{} = pin} = Accounts.upsert_key_pin(user.id, reverse_user.id, blob)
      assert pin.pinned_fingerprint == blob

      # Reload from the DB to prove durable, untransformed storage.
      reloaded = Accounts.get_key_pin(user.id, reverse_user.id)
      assert reloaded.pinned_fingerprint == blob
    end

    test "is insert-only — a second upsert does NOT overwrite (first-write-wins)", %{
      user: user,
      reverse_user: reverse_user
    } do
      first = Base.encode64(:crypto.strong_rand_bytes(96))
      second = Base.encode64(:crypto.strong_rand_bytes(96))
      refute first == second

      assert {:ok, _} = Accounts.upsert_key_pin(user.id, reverse_user.id, first)
      # Conflicting upsert resolves to :nothing; the original blob stands.
      assert {:ok, _} = Accounts.upsert_key_pin(user.id, reverse_user.id, second)

      reloaded = Accounts.get_key_pin(user.id, reverse_user.id)
      assert reloaded.pinned_fingerprint == first
    end

    test "list_key_pins_for/2 returns a peer_user_id => blob batch map", %{
      user: user,
      reverse_user: reverse_user
    } do
      assert Accounts.list_key_pins_for(user.id, []) == %{}
      assert Accounts.list_key_pins_for(user.id, [reverse_user.id]) == %{}

      blob = Base.encode64(:crypto.strong_rand_bytes(96))
      assert {:ok, _} = Accounts.upsert_key_pin(user.id, reverse_user.id, blob)

      map = Accounts.list_key_pins_for(user.id, [reverse_user.id, Ecto.UUID.generate()])
      assert map == %{reverse_user.id => blob}
    end

    test "confirmed connections preload :reverse_user with peer public keys", %{
      user: user,
      reverse_user: reverse_user
    } do
      [uconn] = Accounts.filter_user_connections(%{}, user)

      assert %Accounts.User{} = uconn.reverse_user
      assert uconn.reverse_user.id == reverse_user.id
      assert uconn.reverse_user.key_pair["public"]
      assert uconn.reverse_user.pq_public_key
    end
  end

  defp get_session_key(user, password) do
    case Mosslet.Accounts.User.valid_key_hash?(user, password) do
      {:ok, key} -> key
      {:error, _} -> nil
    end
  end
end
