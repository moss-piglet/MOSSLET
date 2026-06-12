defmodule Mosslet.OrgsInvitationsTest do
  use Mosslet.DataCase, async: true

  import Mosslet.AccountsFixtures
  import Swoosh.TestAssertions

  alias Mosslet.Accounts
  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Orgs

  defp confirmed_user(seed) do
    user = confirmed_user_no_billing(seed)
    subscribe_user(user)
    user
  end

  defp confirmed_user_no_billing(seed) do
    email = "#{seed}#{System.unique_integer([:positive])}@example.com"

    user_fixture(%{email: email})
    |> Accounts.confirm_user!()
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

  defp business_org do
    user = confirmed_user("biz")
    {:ok, org} = Orgs.create_org(user, %{"name" => "Acme Inc", "type" => "business"})
    org
  end

  defp family_org do
    user = confirmed_user("fam")
    {:ok, org} = Orgs.create_org(user, %{"name" => "The Smiths", "type" => "family"})
    org
  end

  describe "create_invitation/2 + deliver_invitation_email/2" do
    test "creates the invitation row (no email yet) for a business org" do
      org = business_org()

      assert {:ok, invitation} =
               Orgs.create_invitation(org, %{"sent_to" => "newhire@example.com"})

      assert invitation.org_id == org.id
      assert invitation.sent_to == "newhire@example.com"
      assert [%{id: id}] = Orgs.list_invitations_by_org(org)
      assert id == invitation.id
    end

    test "deliver_invitation_email sends a tailored Business email" do
      org = business_org()
      {:ok, invitation} = Orgs.create_invitation(org, %{"sent_to" => "teammate@example.com"})

      assert {:ok, _email} = Orgs.deliver_invitation_email(invitation, org)

      assert_email_sent(fn email ->
        assert {"", "teammate@example.com"} in email.to
        assert email.subject =~ "Acme Inc"
        refute email.subject =~ "family"
        assert email.html_body =~ "org-invitations"
      end)
    end

    test "deliver_invitation_email sends a tailored Family email" do
      org = family_org()
      {:ok, invitation} = Orgs.create_invitation(org, %{"sent_to" => "cousin@example.com"})

      assert {:ok, _email} = Orgs.deliver_invitation_email(invitation, org)

      assert_email_sent(fn email ->
        assert {"", "cousin@example.com"} in email.to
        assert email.subject =~ "family"
        assert email.subject =~ "The Smiths"
        assert email.html_body =~ "org-invitations"
      end)
    end
  end

  describe "resend_invitation/1" do
    test "re-delivers the email for an existing pending invitation" do
      org = business_org()
      {:ok, invitation} = Orgs.create_invitation(org, %{"sent_to" => "resend@example.com"})

      assert {:ok, _email} = Orgs.resend_invitation(invitation)

      assert_email_sent(fn email ->
        assert {"", "resend@example.com"} in email.to
      end)
    end

    test "resolves the org when not preloaded" do
      org = business_org()
      {:ok, invitation} = Orgs.create_invitation(org, %{"sent_to" => "noassoc@example.com"})

      # Strip the (not-loaded) org association to exercise the fallback lookup.
      bare = %{invitation | org: %Ecto.Association.NotLoaded{}}

      assert {:ok, _email} = Orgs.resend_invitation(bare)
    end
  end

  describe "list_invitations_by_org/1 + delete_invitation!/1 (revoke)" do
    test "lists pending invitations and revokes them" do
      org = business_org()
      {:ok, _first} = Orgs.create_invitation(org, %{"sent_to" => "first@example.com"})
      {:ok, second} = Orgs.create_invitation(org, %{"sent_to" => "second@example.com"})

      invitations = Orgs.list_invitations_by_org(org)
      assert length(invitations) == 2

      emails = Enum.map(invitations, & &1.sent_to)
      assert "first@example.com" in emails
      assert "second@example.com" in emails

      Orgs.delete_invitation!(Orgs.get_invitation_by_org!(org, second.id))

      remaining = Orgs.list_invitations_by_org(org)
      assert length(remaining) == 1
      assert hd(remaining).sent_to == "first@example.com"
    end
  end
end
