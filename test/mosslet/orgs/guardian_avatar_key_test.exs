defmodule Mosslet.Orgs.GuardianAvatarKeyTest do
  @moduledoc """
  Family guardian safety override (Task #284): storage + server-authoritative
  gating for the per-guardianship sealed `managed_avatar_key` (the managed
  member's conn_key sealed for their guardian). The browser seal flow and avatar
  blob decryption are exercised in JS/browser; here we verify the Elixir
  storage, the active-guardian gate, and idempotency/tamper-resistance.
  """
  use Mosslet.DataCase, async: true

  import Mosslet.AccountsFixtures
  import Mosslet.OrgsFixtures

  alias Mosslet.Orgs

  setup do
    admin = user_fixture()
    guardian_user = user_fixture()
    managed_user = user_fixture()

    org = org_fixture(admin, %{"type" => "family"})

    {:ok, {:ok, guardian_ms}} =
      Mosslet.Repo.transaction_on_primary(fn ->
        Orgs.Membership.insert_changeset(org, guardian_user, :guardian)
        |> Mosslet.Repo.insert()
      end)

    {:ok, {:ok, managed_ms}} =
      Mosslet.Repo.transaction_on_primary(fn ->
        Orgs.Membership.insert_changeset(org, managed_user, :managed_member)
        |> Mosslet.Repo.insert()
      end)

    %{
      org: org,
      guardian_user: guardian_user,
      managed_user: managed_user,
      guardian_ms: guardian_ms,
      managed_ms: managed_ms
    }
  end

  describe "list_guardianships_needing_avatar_key/1" do
    test "returns active guardianships with no key yet, carrying the guardian user", ctx do
      {:ok, g} = Orgs.establish_guardianship(ctx.guardian_ms, ctx.managed_ms)
      {:ok, _g} = Orgs.accept_guardianship(g)

      assert [%{guardianship_id: gid, guardian_user: guardian}] =
               Orgs.list_guardianships_needing_avatar_key(ctx.managed_user.id)

      assert gid == g.id
      assert guardian.id == ctx.guardian_user.id
      # The seal flow needs the guardian's public keys.
      assert guardian.key_pair["public"]
    end

    test "excludes pending/declined guardianships (consent gate)", ctx do
      {:ok, _pending} = Orgs.establish_guardianship(ctx.guardian_ms, ctx.managed_ms)
      assert Orgs.list_guardianships_needing_avatar_key(ctx.managed_user.id) == []
    end

    test "excludes guardianships whose key is already sealed", ctx do
      {:ok, g} = Orgs.establish_guardianship(ctx.guardian_ms, ctx.managed_ms)
      {:ok, _g} = Orgs.accept_guardianship(g)

      {:ok, 1} =
        Orgs.seal_managed_avatar_keys(ctx.managed_user.id, [
          %{"guardianship_id" => g.id, "sealed_key" => "sealed-conn-key-blob"}
        ])

      assert Orgs.list_guardianships_needing_avatar_key(ctx.managed_user.id) == []
    end

    test "returns [] for unknown user / nil", _ctx do
      assert Orgs.list_guardianships_needing_avatar_key(Ecto.UUID.generate()) == []
      assert Orgs.list_guardianships_needing_avatar_key(nil) == []
    end
  end

  describe "seal_managed_avatar_keys/2 (server-authoritative + idempotent)" do
    setup ctx do
      {:ok, g} = Orgs.establish_guardianship(ctx.guardian_ms, ctx.managed_ms)
      {:ok, g} = Orgs.accept_guardianship(g)
      Map.put(ctx, :guardianship, g)
    end

    test "persists the sealed key for an active guardianship of this managed user", ctx do
      assert {:ok, 1} =
               Orgs.seal_managed_avatar_keys(ctx.managed_user.id, [
                 %{"guardianship_id" => ctx.guardianship.id, "sealed_key" => "blob-a"}
               ])

      # Surfaced to the guardian via the read gate.
      assert "blob-a" =
               Orgs.guardian_avatar_key_for(ctx.guardian_user.id, ctx.managed_user.id)
    end

    test "is idempotent — re-sealing an already-keyed guardianship is a no-op", ctx do
      {:ok, 1} =
        Orgs.seal_managed_avatar_keys(ctx.managed_user.id, [
          %{"guardianship_id" => ctx.guardianship.id, "sealed_key" => "blob-a"}
        ])

      assert {:ok, 0} =
               Orgs.seal_managed_avatar_keys(ctx.managed_user.id, [
                 %{"guardianship_id" => ctx.guardianship.id, "sealed_key" => "blob-b"}
               ])

      # Original key is preserved.
      assert "blob-a" =
               Orgs.guardian_avatar_key_for(ctx.guardian_user.id, ctx.managed_user.id)
    end

    test "drops entries for guardianships not belonging to this managed user (I1)", ctx do
      # A different managed user can't seal into someone else's guardianship.
      other_managed = user_fixture()

      assert {:ok, 0} =
               Orgs.seal_managed_avatar_keys(other_managed.id, [
                 %{"guardianship_id" => ctx.guardianship.id, "sealed_key" => "tampered"}
               ])

      assert is_nil(Orgs.guardian_avatar_key_for(ctx.guardian_user.id, ctx.managed_user.id))
    end

    test "drops entries with a non-binary sealed_key or unknown guardianship", ctx do
      assert {:ok, 0} =
               Orgs.seal_managed_avatar_keys(ctx.managed_user.id, [
                 %{"guardianship_id" => ctx.guardianship.id, "sealed_key" => nil},
                 %{"guardianship_id" => Ecto.UUID.generate(), "sealed_key" => "blob"}
               ])

      assert is_nil(Orgs.guardian_avatar_key_for(ctx.guardian_user.id, ctx.managed_user.id))
    end

    test "does not seal for a paused guardianship", ctx do
      {:ok, _} = Orgs.pause_guardianship(ctx.guardianship)

      assert {:ok, 0} =
               Orgs.seal_managed_avatar_keys(ctx.managed_user.id, [
                 %{"guardianship_id" => ctx.guardianship.id, "sealed_key" => "blob"}
               ])
    end
  end

  describe "guardian_avatar_key_for/2 (active-guardian read gate)" do
    setup ctx do
      {:ok, g} = Orgs.establish_guardianship(ctx.guardian_ms, ctx.managed_ms)
      {:ok, g} = Orgs.accept_guardianship(g)

      {:ok, 1} =
        Orgs.seal_managed_avatar_keys(ctx.managed_user.id, [
          %{"guardianship_id" => g.id, "sealed_key" => "the-sealed-conn-key"}
        ])

      Map.put(ctx, :guardianship, g)
    end

    test "returns the sealed key to the guardian", ctx do
      assert "the-sealed-conn-key" =
               Orgs.guardian_avatar_key_for(ctx.guardian_user.id, ctx.managed_user.id)
    end

    test "returns nil for a non-guardian viewer", ctx do
      stranger = user_fixture()
      assert is_nil(Orgs.guardian_avatar_key_for(stranger.id, ctx.managed_user.id))
    end

    test "is directional — the managed member is not a guardian of their guardian", ctx do
      assert is_nil(Orgs.guardian_avatar_key_for(ctx.managed_user.id, ctx.guardian_user.id))
    end

    test "stops returning the key once the guardianship is revoked", ctx do
      {:ok, _} = Orgs.revoke_guardianship(ctx.guardianship)
      assert is_nil(Orgs.guardian_avatar_key_for(ctx.guardian_user.id, ctx.managed_user.id))
    end

    test "stops returning the key while paused", ctx do
      {:ok, _} = Orgs.pause_guardianship(ctx.guardianship)
      assert is_nil(Orgs.guardian_avatar_key_for(ctx.guardian_user.id, ctx.managed_user.id))
    end

    test "returns nil for nil / unknown ids", _ctx do
      assert is_nil(Orgs.guardian_avatar_key_for(nil, nil))
      assert is_nil(Orgs.guardian_avatar_key_for(Ecto.UUID.generate(), Ecto.UUID.generate()))
    end
  end
end
