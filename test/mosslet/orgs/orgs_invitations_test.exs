defmodule Mosslet.OrgsInvitationsTest do
  use Mosslet.DataCase, async: true

  import Mosslet.AccountsFixtures
  import Mosslet.OrgsFixtures
  import Swoosh.TestAssertions

  alias Mosslet.Accounts
  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Plans
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Orgs

  defp monthly_addon_price,
    do: Plans.subdomain_addon_price(Plans.get_plan_by_id!("business-monthly"))

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
        assert email.html_body =~ "/invite/"
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
        assert email.html_body =~ "/invite/"
      end)
    end

    test "invite link points at the branded subdomain host when subdomain is live (Task #246)" do
      org = business_org()
      ensure_org_subscription(org, quantity: 20, items: [%{"price_id" => monthly_addon_price()}])
      {:ok, org} = Orgs.set_org_subdomain(org, %{"subdomain" => "brandsub"})
      assert Orgs.subdomain_live?(org)

      {:ok, invitation} = Orgs.create_invitation(org, %{"sent_to" => "branded@example.com"})
      assert {:ok, _email} = Orgs.deliver_invitation_email(invitation, org)

      branded_base = Orgs.org_base_url(org)
      assert String.contains?(branded_base, "brandsub.")

      assert_email_sent(fn email ->
        assert email.html_body =~ branded_base <> "/invite/"
      end)
    end

    test "invite link uses the apex host when the org's subdomain is NOT live (Task #246)" do
      org = business_org()
      {:ok, invitation} = Orgs.create_invitation(org, %{"sent_to" => "apex@example.com"})
      assert {:ok, _email} = Orgs.deliver_invitation_email(invitation, org)

      refute Orgs.subdomain_live?(org)

      assert_email_sent(fn email ->
        assert email.html_body =~ MossletWeb.Endpoint.url() <> "/invite/"
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

  describe "sign_invite_token/1 + verify_invite_token/1" do
    test "round-trips a token to its invitation (+ preloaded org)" do
      org = family_org()
      {:ok, invitation} = Orgs.create_invitation(org, %{"sent_to" => "round@example.com"})

      token = Orgs.sign_invite_token(invitation)
      assert {:ok, resolved} = Orgs.verify_invite_token(token)
      assert resolved.id == invitation.id
      assert resolved.org.id == org.id
      assert resolved.sent_to == "round@example.com"
    end

    test "a tampered/garbage token is invalid (no enumeration)" do
      assert {:error, :invalid} = Orgs.verify_invite_token("garbage")
      assert {:error, :invalid} = Orgs.verify_invite_token("")
      # A raw UUID is NOT a valid signed token — prevents guessing another org.
      assert {:error, :invalid} = Orgs.verify_invite_token(Ecto.UUID.generate())
    end

    test "a token for a deleted (accepted/revoked) invitation is invalid" do
      org = business_org()
      {:ok, invitation} = Orgs.create_invitation(org, %{"sent_to" => "gone@example.com"})
      token = Orgs.sign_invite_token(invitation)

      Orgs.delete_invitation!(invitation)

      assert {:error, :invalid} = Orgs.verify_invite_token(token)
    end

    test "an expired token reports :expired" do
      org = family_org()
      {:ok, invitation} = Orgs.create_invitation(org, %{"sent_to" => "old@example.com"})

      # Sign with a backdated timestamp older than the 7-day max_age.
      eight_days_ago =
        System.system_time(:second) - (Orgs.invite_token_max_age_seconds() + 60)

      token =
        Phoenix.Token.sign(MossletWeb.Endpoint, "org invitation link", invitation.id,
          signed_at: eight_days_ago
        )

      assert {:error, :expired} = Orgs.verify_invite_token(token)
    end
  end

  describe "invite_link_expired?/1" do
    test "false for a freshly-created invitation" do
      org = family_org()
      {:ok, invitation} = Orgs.create_invitation(org, %{"sent_to" => "fresh@example.com"})
      refute Orgs.invite_link_expired?(invitation)
    end

    test "true when the invitation was last touched more than 7 days ago" do
      org = business_org()
      {:ok, invitation} = Orgs.create_invitation(org, %{"sent_to" => "stale@example.com"})

      stale =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(-(Orgs.invite_token_max_age_seconds() + 3600), :second)
        |> NaiveDateTime.truncate(:second)

      invitation = %{invitation | updated_at: stale, inserted_at: stale}
      assert Orgs.invite_link_expired?(invitation)
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
