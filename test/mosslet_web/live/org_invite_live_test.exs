defmodule MossletWeb.OrgInviteLiveTest do
  use MossletWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures

  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Orgs

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

  defp owner_with_org(type, name) do
    owner = user_fixture(%{email: "owner#{System.unique_integer([:positive])}@example.com"})
    subscribe_user(owner)
    {:ok, org} = Orgs.create_org(owner, %{"name" => name, "type" => to_string(type)})
    org
  end

  defp family_org, do: owner_with_org(:family, "The Smiths")
  defp business_org, do: owner_with_org(:business, "Acme Inc")

  describe "invalid / expired token (dead-ends)" do
    test "renders friendly invalid notice for a garbage token", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/invite/totally-bogus")
      assert html =~ "no longer valid"
      assert has_element?(view, "#invite-invalid")
    end

    test "renders expired notice for a stale (but well-formed) token", %{conn: conn} do
      org = family_org()
      {:ok, invitation} = Orgs.create_invitation(org, %{"sent_to" => "stale@example.com"})

      eight_days_ago =
        System.system_time(:second) - (Orgs.invite_token_max_age_seconds() + 60)

      token =
        Phoenix.Token.sign(MossletWeb.Endpoint, "org invitation link", invitation.id,
          signed_at: eight_days_ago
        )

      {:ok, view, html} = live(conn, ~p"/invite/#{token}")
      assert html =~ "expired"
      assert has_element?(view, "#invite-expired")
    end
  end

  describe "signed out" do
    test "no account → register CTA preserving the token (Family)", %{conn: conn} do
      org = family_org()
      {:ok, invitation} = Orgs.create_invitation(org, %{"sent_to" => "newcomer@example.com"})
      token = Orgs.sign_invite_token(invitation)

      {:ok, view, _html} = live(conn, ~p"/invite/#{token}")

      assert has_element?(view, "#invite-register")
      assert has_element?(view, "h1", "The Smiths family")
      # CTA preserves the token and plan through registration.
      assert has_element?(
               view,
               ~s|a[href*="/auth/register"][href*="invite_token=#{token}"]|
             )

      assert has_element?(view, ~s|a[href*="plan=family"]|)
    end

    test "existing account → sign-in CTA preserving the token (Business)", %{conn: conn} do
      org = business_org()
      # An existing confirmed user owns this email.
      _existing = user_fixture(%{email: "hasaccount@example.com"})
      {:ok, invitation} = Orgs.create_invitation(org, %{"sent_to" => "hasaccount@example.com"})
      token = Orgs.sign_invite_token(invitation)

      {:ok, view, _html} = live(conn, ~p"/invite/#{token}")

      assert has_element?(view, "#invite-sign-in")
      assert has_element?(view, "h1", "Acme Inc")

      assert has_element?(
               view,
               ~s|a[href*="/auth/sign_in"][href*="invite_token=#{token}"]|
             )
    end
  end

  describe "signed in" do
    test "invite matches the signed-in user → inline Accept/Decline", %{conn: conn} do
      org = family_org()
      email = "member#{System.unique_integer([:positive])}@example.com"
      user = user_fixture(%{email: email})
      {:ok, invitation} = Orgs.create_invitation(org, %{"sent_to" => email})
      token = Orgs.sign_invite_token(invitation)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/invite/#{token}")

      assert has_element?(view, "#invite-accept")
      assert has_element?(view, "button", "Accept invitation")
      assert has_element?(view, "button", "Decline")
    end

    test "accepting the invitation creates a membership and navigates to the org", %{conn: conn} do
      org = family_org()
      email = "joiner#{System.unique_integer([:positive])}@example.com"
      user = user_fixture(%{email: email})
      {:ok, invitation} = Orgs.create_invitation(org, %{"sent_to" => email})
      token = Orgs.sign_invite_token(invitation)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/invite/#{token}")

      assert {:error, {:live_redirect, %{to: to}}} =
               view
               |> element("button", "Accept invitation")
               |> render_click()

      assert to =~ "/app/family/"
      assert Orgs.member_of_org?(Mosslet.Orgs.get_org_by_id(org.id), user.id)
    end

    test "mismatched signed-in user sees a masked notice, not the full email", %{conn: conn} do
      org = business_org()
      {:ok, invitation} = Orgs.create_invitation(org, %{"sent_to" => "invited@example.com"})
      token = Orgs.sign_invite_token(invitation)

      other = user_fixture(%{email: "someoneelse@example.com"})
      conn = log_in_user(conn, other)
      {:ok, view, html} = live(conn, ~p"/invite/#{token}")

      assert has_element?(view, "#invite-mismatch")
      refute html =~ "invited@example.com"
      assert html =~ "different email"
    end
  end
end
