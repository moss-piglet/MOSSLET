defmodule Mosslet.OrgsCoverageTest do
  @moduledoc """
  Tests for the org-seat coverage bridge that exempts Family/Business members
  from the personal paywall (Task #223), plus auto-accept of a matching pending
  invitation on email confirmation.
  """
  use Mosslet.DataCase, async: true

  import Mosslet.AccountsFixtures

  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Orgs

  # Returns {user, plaintext_email}. The fixture confirms by default; the loaded
  # `user.email` is the encrypted field, so we carry the plaintext separately for
  # invitation creation (which expects a plaintext email).
  defp confirmed_user(seed) do
    email = "#{seed}#{System.unique_integer([:positive])}@example.com"
    {user_fixture(%{email: email}), email}
  end

  defp subscribe_user(user) do
    {:ok, customer} =
      Customers.create_customer_for_source(:user, user.id, %{
        email: "billing-#{System.unique_integer([:positive])}@example.com",
        provider: "stripe",
        provider_customer_id: "cus_#{System.unique_integer([:positive])}"
      })

    {:ok, _subscription} =
      Subscriptions.create_subscription(%{
        billing_customer_id: customer.id,
        plan_id: "personal-monthly",
        status: "active",
        quantity: 1,
        provider_subscription_id: "sub_#{System.unique_integer([:positive])}",
        provider_subscription_items: [%{price: "price_test"}],
        current_period_start: NaiveDateTime.utc_now()
      })

    :ok
  end

  # An org whose seats are paid for via the org's own (`:org`-source)
  # subscription — the billing model as of Task #235. Returns the org. The org's
  # sub plan matches the org type (family-monthly / business-monthly) in the
  # given status. Personal and org billing are fully independent: the owner does
  # NOT need a personal plan to create or cover an org.
  defp org_with_subscription(type, status) do
    {creator, _email} = confirmed_user("creator")

    name = if type == :family, do: "The Coverage Family", else: "Coverage Inc"
    {:ok, org} = Orgs.create_org(creator, %{"name" => name, "type" => Atom.to_string(type)})

    {:ok, customer} =
      Customers.create_customer_for_source(:org, org.id, %{
        email: "billing-#{System.unique_integer([:positive])}@example.com",
        provider: "stripe",
        provider_customer_id: "cus_#{System.unique_integer([:positive])}"
      })

    plan = if type == :family, do: "family-monthly", else: "business-monthly"

    {:ok, _subscription} =
      Subscriptions.create_subscription(%{
        billing_customer_id: customer.id,
        plan_id: plan,
        status: status,
        quantity: 5,
        provider_subscription_id: "sub_org_#{System.unique_integer([:positive])}",
        provider_subscription_items: [%{price: "price_org_test"}],
        current_period_start: NaiveDateTime.utc_now()
      })

    org
  end

  # Invites + auto-accepts (the user is already confirmed) so they become a member.
  defp add_member(org, {user, email}) do
    {:ok, _invitation} = Orgs.create_invitation(org, %{"sent_to" => email})
    Orgs.sync_user_invitations(user)
    user
  end

  describe "org_coverage_status/1 + covered_by_org_seat?/1" do
    test ":covered when the org subscription is active" do
      org = org_with_subscription(:business, "active")
      {member, _} = invitee = confirmed_user("member")
      add_member(org, invitee)

      assert Orgs.org_coverage_status(member) == :covered
      assert Orgs.covered_by_org_seat?(member)
    end

    test ":covered when the org subscription is trialing" do
      org = org_with_subscription(:family, "trialing")
      {member, _} = invitee = confirmed_user("member")
      add_member(org, invitee)

      assert Orgs.org_coverage_status(member) == :covered
      assert Orgs.covered_by_org_seat?(member)
    end

    test "{:grace, org} when the org subscription is past_due (access still granted)" do
      org = org_with_subscription(:business, "past_due")
      {member, _} = invitee = confirmed_user("member")
      add_member(org, invitee)

      assert {:grace, %{id: org_id}} = Orgs.org_coverage_status(member)
      assert org_id == org.id
      assert Orgs.covered_by_org_seat?(member)
    end

    test "{:lapsed, org} when the org subscription is canceled (access denied)" do
      org = org_with_subscription(:business, "canceled")
      {member, _} = invitee = confirmed_user("member")
      add_member(org, invitee)

      assert {:lapsed, %{id: org_id}} = Orgs.org_coverage_status(member)
      assert org_id == org.id
      refute Orgs.covered_by_org_seat?(member)
    end

    test ":none when the user has no org membership" do
      {user, _} = confirmed_user("loner")

      assert Orgs.org_coverage_status(user) == :none
      refute Orgs.covered_by_org_seat?(user)
    end

    test "covered if ANY org is active even when another lapsed (multiple memberships)" do
      active_org = org_with_subscription(:business, "active")
      lapsed_org = org_with_subscription(:family, "canceled")
      {member, _} = invitee = confirmed_user("member")
      add_member(active_org, invitee)
      add_member(lapsed_org, invitee)

      assert Orgs.org_coverage_status(member) == :covered
      assert Orgs.covered_by_org_seat?(member)
    end

    test "seat removal (membership deleted) immediately drops coverage to :none" do
      org = org_with_subscription(:business, "active")
      {member, _} = invitee = confirmed_user("member")
      add_member(org, invitee)
      assert Orgs.covered_by_org_seat?(member)

      membership = Orgs.get_membership!(member, org.slug)
      {:ok, _} = Orgs.delete_membership(membership)

      assert Orgs.org_coverage_status(member) == :none
      refute Orgs.covered_by_org_seat?(member)
    end

    test "personal subscriber who is also an org member keeps app access when the org lapses" do
      # The org's plan is canceled, so org coverage is denied...
      org = org_with_subscription(:business, "canceled")
      {member, _} = invitee = confirmed_user("member")
      add_member(org, invitee)

      refute Orgs.covered_by_org_seat?(member)

      # ...but the member has their OWN active personal subscription, so the
      # paywall (via user_has_paid?/1) still grants access — not double-charged,
      # not locked out (Task #223, decision #1 / edge case).
      subscribe_user(member)

      assert MossletWeb.Helpers.user_has_paid?(member)
    end
  end

  describe "auto-accept on confirmation (sync_user_invitations/1)" do
    test "a confirmed user with a matching pending invite is auto-joined" do
      org = org_with_subscription(:business, "active")
      {invitee, email} = confirmed_user("invitee")

      {:ok, _invitation} = Orgs.create_invitation(org, %{"sent_to" => email})
      refute Orgs.member_of_org?(org, invitee.id)

      Orgs.sync_user_invitations(invitee)

      assert Orgs.member_of_org?(org, invitee.id)
      assert Orgs.list_invitations_by_org(org) == []
    end

    test "confirming the account (Accounts.confirm_user!/1) auto-joins a pending invite" do
      org = org_with_subscription(:business, "active")
      # An UNCONFIRMED invited user.
      email = "confirmflow#{System.unique_integer([:positive])}@example.com"
      unconfirmed = user_fixture(%{email: email, confirm: false})

      {:ok, _invitation} = Orgs.create_invitation(org, %{"sent_to" => email})
      refute Orgs.member_of_org?(org, unconfirmed.id)

      confirmed = Mosslet.Accounts.confirm_user!(unconfirmed)

      assert Orgs.member_of_org?(org, confirmed.id)
      assert Orgs.covered_by_org_seat?(confirmed)
      assert Orgs.list_invitations_by_org(org) == []
    end

    test "an UNCONFIRMED user is NOT auto-joined (proof-of-inbox gate)" do
      org = org_with_subscription(:business, "active")
      email = "unconfirmed#{System.unique_integer([:positive])}@example.com"
      unconfirmed = user_fixture(%{email: email, confirm: false})

      {:ok, _invitation} = Orgs.create_invitation(org, %{"sent_to" => email})

      Orgs.sync_user_invitations(unconfirmed)

      refute Orgs.member_of_org?(org, unconfirmed.id)
      assert length(Orgs.list_invitations_by_org(org)) == 1
    end
  end

  describe "list_pending_invitations_by_email_hash/1" do
    test "finds the pending invitation by the user's email hash" do
      org = org_with_subscription(:family, "active")
      {invitee, email} = confirmed_user("hashmatch")

      {:ok, _invitation} = Orgs.create_invitation(org, %{"sent_to" => email})

      found = Orgs.list_pending_invitations_by_email_hash(invitee.email_hash)

      assert [%{org: %{id: org_id}}] = found
      assert org_id == org.id
    end

    test "returns [] when no invitation matches" do
      {user, _} = confirmed_user("nomatch")
      assert Orgs.list_pending_invitations_by_email_hash(user.email_hash) == []
    end
  end
end
