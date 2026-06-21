defmodule MossletWeb.GuardianAvatarDataTest do
  @moduledoc """
  Family guardian safety override (Task #284): the read helper that surfaces a
  managed member's PERSONAL avatar to their guardian. We exercise the guard
  clauses + the ETS cache-hit branch (no S3) — the browser decrypts the blob.
  """
  use Mosslet.DataCase, async: false

  import Mosslet.AccountsFixtures
  import Mosslet.OrgsFixtures

  alias Mosslet.Accounts
  alias Mosslet.Extensions.AvatarProcessor
  alias Mosslet.Orgs
  alias MossletWeb.Helpers

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
      guardian_user: guardian_user,
      managed_user: managed_user,
      guardian_ms: guardian_ms,
      managed_ms: managed_ms
    }
  end

  defp set_avatar_url(user) do
    user = Accounts.preload_connection(user)

    {:ok, {:ok, conn}} =
      Mosslet.Repo.transaction_on_primary(fn ->
        user.connection
        |> Ecto.Changeset.change(%{avatar_url: "encrypted-storage-path"})
        |> Mosslet.Repo.update()
      end)

    conn
  end

  # The read path always receives a freshly-loaded user (Accounts.get_user!/...),
  # so mirror that here rather than reusing the fixture's stale preloaded struct.
  defp reload_user(user), do: Accounts.get_user_with_preloads(user.id)

  describe "get_guardian_avatar_data/4 guard clauses" do
    test "returns nil when sealed_key is not a binary", ctx do
      assert is_nil(
               Helpers.get_guardian_avatar_data(ctx.guardian_user, ctx.managed_user, nil, "k")
             )
    end

    test "returns nil when the managed member has no personal avatar", ctx do
      assert is_nil(
               Helpers.get_guardian_avatar_data(
                 ctx.guardian_user,
                 ctx.managed_user,
                 "sealed-conn-key",
                 "session-key"
               )
             )
    end
  end

  describe "get_guardian_avatar_data/4 ETS cache hit (ZK blob is browser-decrypted)" do
    test "returns the live encrypted blob + the guardian's sealed conn_key", ctx do
      conn = set_avatar_url(ctx.managed_user)
      AvatarProcessor.put_ets_avatar("profile-#{conn.id}", <<1, 2, 3, 4>>)

      assert %{encrypted_blob_b64: blob_b64, sealed_key: "sealed-conn-key"} =
               Helpers.get_guardian_avatar_data(
                 ctx.guardian_user,
                 reload_user(ctx.managed_user),
                 "sealed-conn-key",
                 "session-key"
               )

      assert blob_b64 == Base.encode64(<<1, 2, 3, 4>>)

      AvatarProcessor.delete_ets_avatar("profile-#{conn.id}")
    end
  end

  describe "guardian_avatar_directory/3 (server-authoritative gate)" do
    test "includes only members the viewer actively guards, with a sealed key", ctx do
      {:ok, g} = Orgs.establish_guardianship(ctx.guardian_ms, ctx.managed_ms)
      {:ok, _g} = Orgs.accept_guardianship(g)

      {:ok, 1} =
        Orgs.seal_managed_avatar_keys(ctx.managed_user.id, [
          %{"guardianship_id" => g.id, "sealed_key" => "sealed-conn-key"}
        ])

      conn = set_avatar_url(ctx.managed_user)
      AvatarProcessor.put_ets_avatar("profile-#{conn.id}", <<9, 9, 9>>)

      members = [
        %{user: reload_user(ctx.managed_user), self?: false},
        %{user: ctx.guardian_user, self?: true}
      ]

      directory = Helpers.guardian_avatar_directory(members, ctx.guardian_user, "session-key")

      assert %{encrypted_blob_b64: _, sealed_key: "sealed-conn-key"} =
               directory[ctx.managed_user.id]

      # Self is excluded.
      refute Map.has_key?(directory, ctx.guardian_user.id)

      AvatarProcessor.delete_ets_avatar("profile-#{conn.id}")
    end

    test "returns an empty map when the viewer guards no one", ctx do
      members = [%{user: ctx.managed_user, self?: false}]
      assert Helpers.guardian_avatar_directory(members, ctx.guardian_user, "k") == %{}
    end
  end
end
