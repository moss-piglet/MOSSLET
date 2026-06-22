defmodule MossletWeb.UserDashLiveTest do
  @moduledoc """
  Characterization tests for `MossletWeb.UserDashLive` (the personal dashboard at
  `/app`).

  Phase 5 turned the dashboard from a placeholder that redirected profile-owners
  to their profile page into a real "Home". These pin the server-rendered
  scaffolding of the two states — the full dashboard (user has a profile) and the
  "create your profile" onboarding prompt (user has none) — asserting on stable
  DOM IDs rather than ZK-decrypted text.

  The auth harness mirrors `MossletWeb.UserHomeLiveTest`.
  """
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts

  @valid_password "hello world hello world!"

  describe "dashboard (user has a profile)" do
    setup [:create_dashboard_user]

    test "renders the dashboard home rather than redirecting to the profile", %{
      conn: conn,
      user: user,
      user_key: key
    } do
      {:ok, lv, html} = visit_dashboard(conn, user, key)

      assert lv.module == MossletWeb.UserDashLive
      assert html =~ ~s(id="dashboard-home")
      assert has_element?(lv, "#dash-whats-new")
      assert has_element?(lv, "#dash-quick-actions-title")
      assert has_element?(lv, "#dash-glance-title")
    end

    test "reuses the owner profile hero/header (ZK avatar decrypt target)", %{
      conn: conn,
      user: user,
      user_key: key
    } do
      {:ok, _lv, html} = visit_dashboard(conn, user, key)

      assert html =~ ~s(data-decrypt-field="username")
    end
  end

  describe "onboarding (subscribed user without a profile)" do
    setup [:create_profileless_user]

    test "renders the create-profile prompt", %{conn: conn, user: user, user_key: key} do
      {:ok, lv, _html} = visit_dashboard(conn, user, key)

      assert lv.module == MossletWeb.UserDashLive
      refute has_element?(lv, "#dashboard-home")
      assert has_element?(lv, "button", "Create Profile")
    end
  end

  # ---------------------------------------------------------------------------
  # Setup helpers
  # ---------------------------------------------------------------------------

  defp create_dashboard_user(_) do
    {user, key} = build_subscribed_user("dash", with_profile?: true)
    %{user: user, user_key: key}
  end

  defp create_profileless_user(_) do
    {user, key} = build_subscribed_user("nodash", with_profile?: false)
    %{user: user, user_key: key}
  end

  defp build_subscribed_user(prefix, opts) do
    username = "#{prefix}user#{System.unique_integer([:positive])}"
    email = "#{username}@example.com"

    user = user_fixture(%{username: username, email: email, password: @valid_password})
    user = Accounts.confirm_user!(user)
    {:ok, user} = Accounts.update_user_onboarding(user, %{is_onboarded?: true})

    key = get_key(user, @valid_password)

    {:ok, user} =
      Accounts.update_user_onboarding_profile(user, %{name: "#{prefix} user"},
        change_name: true,
        key: key,
        user: user
      )

    {:ok, customer} = create_billing_customer(user)
    {:ok, _payment_intent} = create_payment_intent(customer)

    user = Accounts.get_user_with_preloads(user.id)

    if Keyword.fetch!(opts, :with_profile?) do
      {:ok, _conn} = create_profile(user, key, %{username: username, email: email})
    end

    user = Accounts.get_user_with_preloads(user.id)

    {user, key}
  end

  defp create_profile(user, key, %{username: username, email: email}) do
    profile_params = %{
      "profile" => %{
        "user_id" => user.id,
        "email" => email,
        "name" => "#{username} name",
        "username" => username,
        "temp_username" => username,
        "avatar_url" => nil,
        "visibility" => "public",
        "about" => "",
        "alternate_email" => "",
        "website_url" => "",
        "website_label" => "",
        "banner_image" => "waves",
        "show_avatar?" => "false",
        "show_email?" => "false",
        "show_name?" => "true",
        "opts_map" => %{user: user, key: key, encrypt: true}
      }
    }

    Accounts.create_user_profile(user, profile_params, key: key, user: user, encrypt: true)
  end

  defp create_billing_customer(user) do
    Mosslet.Billing.Customers.create_customer_for_source(
      :user,
      user.id,
      %{
        email: "test@example.com",
        provider: "stripe",
        provider_customer_id: provider_id("cus"),
        user_id: user.id
      }
    )
  end

  defp create_payment_intent(customer) do
    Mosslet.Billing.PaymentIntents.create_payment_intent!(%{
      provider_payment_intent_id: provider_id("pi"),
      provider_customer_id: customer.provider_customer_id,
      provider_latest_charge_id: provider_id("ch"),
      provider_payment_method_id: provider_id("pm"),
      provider_created_at: DateTime.utc_now(),
      amount: 5900,
      amount_received: 5900,
      status: "succeeded",
      billing_customer_id: customer.id
    })
  end

  defp visit_dashboard(conn, user, key) do
    conn
    |> log_in_user(user, key)
    |> live(~p"/app")
  end

  defp provider_id(prefix),
    do: "#{prefix}_#{Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)}"

  defp get_key(user, password) do
    case Accounts.User.valid_key_hash?(user, password) do
      {:ok, key} -> key
      _ -> raise "Failed to get session key"
    end
  end

  defp log_in_user(conn, user, key) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, Accounts.generate_user_session_token(user))
    |> Plug.Conn.put_session(:key, key)
  end
end
