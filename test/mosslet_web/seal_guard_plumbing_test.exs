defmodule MossletWeb.SealGuardPlumbingTest do
  @moduledoc """
  Verify-before-seal SERVER plumbing (EPIC #291 / Phase 2 — #294).

  The JS verdict (string-equality fingerprint compare inside
  `pin_store.verifyOrPin`) is locked by #292/#293 and has no browser harness
  here. These tests assert the Elixir half of the contract that feeds it:

    * `Helpers.hydrate_sealed_pins/2` injects the viewer's sealed pin per
      recipient via the batched `Accounts.list_key_pins_for/2` (pinned -> blob,
      unpinned -> nil), tolerating atom- and string-keyed recipient maps;
    * `Helpers.sealed_pin_for/2` returns the single-peer blob or nil;
    * the persist handlers' server-authoritative guards:
        - `store_connection_peer_pins/2` upserts for a CONFIRMED connection and
          rejects a stranger (personal seal paths);
        - `persist_peer_pins/3` with a CO-MEMBERSHIP authorizer upserts for an
          org co-member and rejects a non-member (org/circle seal paths — no
          personal connection required);
    * insert-only / first-write-wins still holds through the handler path.
  """
  use Mosslet.DataCase

  alias Mosslet.Accounts
  alias Mosslet.Orgs
  alias MossletWeb.Helpers

  @valid_password "hello world hello world"

  defp get_session_key(user, password) do
    case Mosslet.Accounts.User.valid_key_hash?(user, password) do
      {:ok, key} -> key
      {:error, _} -> nil
    end
  end

  defp onboarded(username, name) do
    user =
      Mosslet.AccountsFixtures.user_fixture(%{
        username: username,
        email: "#{username}@example.com",
        password: @valid_password
      })

    key = get_session_key(user, @valid_password)

    {:ok, user} =
      Accounts.update_user_onboarding_profile(user, %{name: name},
        change_name: true,
        key: key,
        user: user
      )

    {user, key}
  end

  describe "hydrate_sealed_pins/2" do
    setup do
      {viewer, _key} = onboarded("seal_viewer", "Seal Viewer")
      {peer_a, _} = onboarded("seal_peer_a", "Peer A")
      {peer_b, _} = onboarded("seal_peer_b", "Peer B")

      blob = Base.encode64(:crypto.strong_rand_bytes(96))
      {:ok, _} = Accounts.upsert_key_pin(viewer.id, peer_a.id, blob)

      %{viewer: viewer, peer_a: peer_a, peer_b: peer_b, blob: blob}
    end

    test "injects sealed_pin per recipient (pinned -> blob, unpinned -> nil)", %{
      viewer: viewer,
      peer_a: peer_a,
      peer_b: peer_b,
      blob: blob
    } do
      recipients = [
        %{user_id: peer_a.id, public_key: "pk_a", pq_public_key: "pq_a"},
        %{user_id: peer_b.id, public_key: "pk_b", pq_public_key: "pq_b"}
      ]

      hydrated = Helpers.hydrate_sealed_pins(recipients, to_string(viewer.id))

      assert [%{user_id: a_id, sealed_pin: a_pin}, %{sealed_pin: b_pin}] = hydrated
      assert a_id == peer_a.id
      assert a_pin == blob
      assert is_nil(b_pin)
    end

    test "tolerates string-keyed recipient maps", %{viewer: viewer, peer_a: peer_a, blob: blob} do
      recipients = [%{"user_id" => peer_a.id, "public_key" => "pk"}]

      [hydrated] = Helpers.hydrate_sealed_pins(recipients, to_string(viewer.id))
      assert hydrated[:sealed_pin] == blob
    end

    test "sealed_pin_for/2 returns the single-peer blob or nil", %{
      viewer: viewer,
      peer_a: peer_a,
      peer_b: peer_b,
      blob: blob
    } do
      assert Helpers.sealed_pin_for(viewer.id, peer_a.id) == blob
      assert is_nil(Helpers.sealed_pin_for(viewer.id, peer_b.id))
    end
  end

  describe "store_connection_peer_pins/2 (personal seal-path guard)" do
    setup do
      {viewer, key} = onboarded("conn_viewer", "Conn Viewer")
      {peer, r_key} = onboarded("conn_peer", "Conn Peer")
      {stranger, _} = onboarded("conn_stranger", "Conn Stranger")

      {:ok, peer} =
        Accounts.update_user_visibility(peer, %{visibility: :connections}, key: r_key)

      _ =
        Mosslet.UserConnectionFixtures.user_connection_fixture(
          %{
            "color" => "rose",
            "temp_label" => "friend",
            "connection_id" => viewer.connection.id,
            "reverse_user_id" => viewer.id,
            "selector" => "username",
            "username" => "conn_peer"
          },
          user: viewer,
          reverse_user: peer,
          key: key,
          r_key: r_key,
          confirm?: true
        )

      %{viewer: viewer, peer: peer, stranger: stranger}
    end

    test "upserts a pin for a CONFIRMED connection", %{viewer: viewer, peer: peer} do
      blob = Base.encode64(:crypto.strong_rand_bytes(96))

      :ok =
        Helpers.store_connection_peer_pins(viewer, [
          %{"peer_user_id" => peer.id, "sealed_pin" => blob}
        ])

      assert Accounts.get_key_pin(viewer.id, peer.id).pinned_fingerprint == blob
    end

    test "rejects a stranger (no confirmed connection)", %{viewer: viewer, stranger: stranger} do
      blob = Base.encode64(:crypto.strong_rand_bytes(96))

      :ok =
        Helpers.store_connection_peer_pins(viewer, [
          %{"peer_user_id" => stranger.id, "sealed_pin" => blob}
        ])

      assert is_nil(Accounts.get_key_pin(viewer.id, stranger.id))
    end

    test "first-write-wins through the handler path", %{viewer: viewer, peer: peer} do
      first = Base.encode64(:crypto.strong_rand_bytes(96))
      second = Base.encode64(:crypto.strong_rand_bytes(96))
      refute first == second

      :ok =
        Helpers.store_connection_peer_pins(viewer, [
          %{"peer_user_id" => peer.id, "sealed_pin" => first}
        ])

      :ok =
        Helpers.store_connection_peer_pins(viewer, [
          %{"peer_user_id" => peer.id, "sealed_pin" => second}
        ])

      assert Accounts.get_key_pin(viewer.id, peer.id).pinned_fingerprint == first
    end

    test "ignores malformed / empty-blob entries", %{viewer: viewer, peer: peer} do
      :ok =
        Helpers.store_connection_peer_pins(viewer, [
          %{"peer_user_id" => peer.id, "sealed_pin" => ""},
          %{"bogus" => "shape"}
        ])

      assert is_nil(Accounts.get_key_pin(viewer.id, peer.id))
    end
  end

  describe "persist_peer_pins/3 (org/circle CO-MEMBERSHIP guard)" do
    setup do
      {owner, _} = onboarded("org_owner", "Org Owner")
      owner = Accounts.confirm_user!(owner)
      {:ok, owner} = Accounts.update_user_onboarding(owner, %{is_onboarded?: true})

      {member, _} = onboarded("org_member", "Org Member")
      {outsider, _} = onboarded("org_outsider", "Org Outsider")

      {:ok, org} =
        Orgs.create_org(owner, %{
          "name" => "Acme #{System.unique_integer([:positive])}",
          "type" => "business"
        })

      {:ok, {:ok, _m}} =
        Mosslet.Repo.transaction_on_primary(fn ->
          Orgs.Membership.insert_changeset(org, member, :member) |> Mosslet.Repo.insert()
        end)

      %{owner: owner, org: org, member: member, outsider: outsider}
    end

    test "upserts a pin for an org CO-MEMBER (no personal connection required)", %{
      owner: owner,
      org: org,
      member: member
    } do
      blob = Base.encode64(:crypto.strong_rand_bytes(96))

      # No personal user_connection exists between owner and member.
      assert is_nil(Accounts.get_user_connection_between_users(member.id, owner.id))

      :ok =
        Helpers.persist_peer_pins(
          to_string(owner.id),
          [%{"peer_user_id" => member.id, "sealed_pin" => blob}],
          fn pid -> Orgs.member_of_org?(org, pid) end
        )

      assert Accounts.get_key_pin(owner.id, member.id).pinned_fingerprint == blob
    end

    test "rejects a non-member", %{owner: owner, org: org, outsider: outsider} do
      blob = Base.encode64(:crypto.strong_rand_bytes(96))

      :ok =
        Helpers.persist_peer_pins(
          to_string(owner.id),
          [%{"peer_user_id" => outsider.id, "sealed_pin" => blob}],
          fn pid -> Orgs.member_of_org?(org, pid) end
        )

      assert is_nil(Accounts.get_key_pin(owner.id, outsider.id))
    end
  end
end
