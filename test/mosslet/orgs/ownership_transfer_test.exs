defmodule Mosslet.Orgs.OwnershipTransferTest do
  use Mosslet.DataCase, async: true

  import Mosslet.AccountsFixtures
  import Mosslet.OrgsFixtures

  alias Mosslet.Orgs
  alias Mosslet.Orgs.{Membership, OwnershipTransfer}

  @password valid_user_password()
  # No org `:org` Stripe customer exists in these tests, so the ZK email
  # reconciliation on accept is a no-op — we exercise the ownership flip + role
  # promotion + status machine without touching Stripe.
  @session_key "test-session-key"

  defp add_member(org, user, role) do
    {:ok, {:ok, membership}} =
      Repo.transaction_on_primary(fn ->
        Membership.insert_changeset(org, user, role) |> Repo.insert()
      end)

    membership
  end

  defp setup_org(type \\ "business") do
    owner = user_fixture()
    member = user_fixture()
    org = org_fixture(owner, %{"type" => type})
    add_member(org, member, :member)
    %{owner: owner, member: member, org: org}
  end

  describe "initiate_ownership_transfer/4" do
    test "owner can initiate a transfer to a confirmed member" do
      %{owner: owner, member: member, org: org} = setup_org()

      assert {:ok, %OwnershipTransfer{} = transfer} =
               Orgs.initiate_ownership_transfer(org, owner, member, @password)

      assert transfer.status == :pending
      assert transfer.from_user_id == owner.id
      assert transfer.to_user_id == member.id
      assert transfer.org_id == org.id
    end

    test "refuses a non-owner" do
      %{member: member, org: org} = setup_org()
      stranger = user_fixture()

      assert {:error, :not_owner} =
               Orgs.initiate_ownership_transfer(org, member, stranger, @password)
    end

    test "refuses an incorrect password" do
      %{owner: owner, member: member, org: org} = setup_org()

      assert {:error, :invalid_password} =
               Orgs.initiate_ownership_transfer(org, owner, member, "wrong password")
    end

    test "refuses a single-member org" do
      owner = user_fixture()
      org = org_fixture(owner, %{"type" => "business"})
      other = user_fixture()

      assert {:error, :single_member_org} =
               Orgs.initiate_ownership_transfer(org, owner, other, @password)
    end

    test "refuses a target who is not a member" do
      %{owner: owner, org: org} = setup_org()
      outsider = user_fixture()

      assert {:error, :not_a_member} =
               Orgs.initiate_ownership_transfer(org, owner, outsider, @password)
    end

    test "refuses transferring to self" do
      %{owner: owner, org: org} = setup_org()

      assert {:error, :cannot_transfer_to_self} =
               Orgs.initiate_ownership_transfer(org, owner, owner, @password)
    end

    test "refuses a second pending transfer" do
      %{owner: owner, member: member, org: org} = setup_org()

      assert {:ok, _transfer} =
               Orgs.initiate_ownership_transfer(org, owner, member, @password)

      assert {:error, :transfer_already_pending} =
               Orgs.initiate_ownership_transfer(org, owner, member, @password)
    end
  end

  describe "accept_ownership_transfer/4" do
    test "flips ownership, promotes the new owner to admin, marks accepted" do
      %{owner: owner, member: member, org: org} = setup_org()

      {:ok, transfer} = Orgs.initiate_ownership_transfer(org, owner, member, @password)

      assert {:ok, %OwnershipTransfer{status: :accepted} = accepted} =
               Orgs.accept_ownership_transfer(transfer, member, @password, @session_key)

      assert accepted.accepted_at

      reloaded = Orgs.get_org_by_id(org.id)
      assert reloaded.created_by_id == member.id
      assert Orgs.owner?(reloaded, member.id)

      new_owner_ms = Orgs.get_membership!(member, org.slug)
      assert new_owner_ms.role == :admin

      # Previous owner keeps their (admin) membership.
      assert Orgs.member_of_org?(reloaded, owner.id)
    end

    test "refuses when the accepting user is not the recipient" do
      %{owner: owner, member: member, org: org} = setup_org()
      stranger = user_fixture()

      {:ok, transfer} = Orgs.initiate_ownership_transfer(org, owner, member, @password)

      assert {:error, :not_recipient} =
               Orgs.accept_ownership_transfer(transfer, stranger, @password, @session_key)
    end

    test "refuses an incorrect password" do
      %{owner: owner, member: member, org: org} = setup_org()

      {:ok, transfer} = Orgs.initiate_ownership_transfer(org, owner, member, @password)

      assert {:error, :invalid_password} =
               Orgs.accept_ownership_transfer(transfer, member, "nope nope nope", @session_key)
    end

    test "double-accept is refused (not pending after first accept)" do
      %{owner: owner, member: member, org: org} = setup_org()

      {:ok, transfer} = Orgs.initiate_ownership_transfer(org, owner, member, @password)
      {:ok, _accepted} = Orgs.accept_ownership_transfer(transfer, member, @password, @session_key)

      stale = Orgs.get_ownership_transfer(transfer.id)

      assert {:error, :not_pending} =
               Orgs.accept_ownership_transfer(stale, member, @password, @session_key)
    end
  end

  describe "decline_ownership_transfer/2 and cancel_ownership_transfer/2" do
    test "the recipient can decline" do
      %{owner: owner, member: member, org: org} = setup_org()

      {:ok, transfer} = Orgs.initiate_ownership_transfer(org, owner, member, @password)

      assert {:ok, %OwnershipTransfer{status: :declined} = declined} =
               Orgs.decline_ownership_transfer(transfer, member)

      assert declined.declined_at
      # Ownership unchanged.
      assert Orgs.owner?(Orgs.get_org_by_id(org.id), owner.id)
    end

    test "a non-recipient cannot decline" do
      %{owner: owner, member: member, org: org} = setup_org()

      {:ok, transfer} = Orgs.initiate_ownership_transfer(org, owner, member, @password)

      assert {:error, :not_recipient} = Orgs.decline_ownership_transfer(transfer, owner)
    end

    test "the initiator can cancel" do
      %{owner: owner, member: member, org: org} = setup_org()

      {:ok, transfer} = Orgs.initiate_ownership_transfer(org, owner, member, @password)

      assert {:ok, %OwnershipTransfer{status: :cancelled} = cancelled} =
               Orgs.cancel_ownership_transfer(transfer, owner)

      assert cancelled.cancelled_at
    end

    test "a non-initiator cannot cancel" do
      %{owner: owner, member: member, org: org} = setup_org()

      {:ok, transfer} = Orgs.initiate_ownership_transfer(org, owner, member, @password)

      assert {:error, :not_initiator} = Orgs.cancel_ownership_transfer(transfer, member)
    end

    test "a new transfer can be initiated after a decline" do
      %{owner: owner, member: member, org: org} = setup_org()

      {:ok, transfer} = Orgs.initiate_ownership_transfer(org, owner, member, @password)
      {:ok, _declined} = Orgs.decline_ownership_transfer(transfer, member)

      assert {:ok, %OwnershipTransfer{status: :pending}} =
               Orgs.initiate_ownership_transfer(org, owner, member, @password)
    end
  end

  describe "query helpers" do
    test "get_pending_transfer_for_org/1 returns only the pending transfer" do
      %{owner: owner, member: member, org: org} = setup_org()

      assert Orgs.get_pending_transfer_for_org(org) == nil

      {:ok, transfer} = Orgs.initiate_ownership_transfer(org, owner, member, @password)

      assert %OwnershipTransfer{id: id} = Orgs.get_pending_transfer_for_org(org)
      assert id == transfer.id

      {:ok, _declined} = Orgs.decline_ownership_transfer(transfer, member)
      assert Orgs.get_pending_transfer_for_org(org) == nil
    end

    test "list_pending_transfers_for_user/1 lists transfers addressed to the user" do
      %{owner: owner, member: member, org: org} = setup_org()

      {:ok, transfer} = Orgs.initiate_ownership_transfer(org, owner, member, @password)

      assert [%OwnershipTransfer{id: id}] = Orgs.list_pending_transfers_for_user(member)
      assert id == transfer.id

      # The owner (initiator) is not the recipient, so sees nothing here.
      assert Orgs.list_pending_transfers_for_user(owner) == []
    end
  end

  describe "family org parity" do
    test "transfer works the same for a family org" do
      %{owner: owner, member: member, org: org} = setup_org("family")

      {:ok, transfer} = Orgs.initiate_ownership_transfer(org, owner, member, @password)

      assert {:ok, %OwnershipTransfer{status: :accepted}} =
               Orgs.accept_ownership_transfer(transfer, member, @password, @session_key)

      assert Orgs.owner?(Orgs.get_org_by_id(org.id), member.id)
    end
  end
end
