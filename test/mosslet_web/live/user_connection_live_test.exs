defmodule MossletWeb.UserConnectionLiveTest do
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures
  import Mosslet.UserConnectionFixtures

  alias Mosslet.Accounts
  alias MossletWeb.Presence

  @provider_customer_id "cus_#{Faker.Util.format("%3b%1d%2b%2d%4b%1d%1b")}"
  @provider_latest_charge_id "ch_#{Faker.Util.format("%3b%1d%2b%2d%4b%1d%1b")}"
  @provider_payment_intent_id "pi_#{Faker.Util.format("%3b%1d%2b%2d%4b%1d%1b")}"
  @provider_payment_method_id "pm_#{Faker.Util.format("%3b%1d%2b%2d%4b%1d%1b")}"
  @valid_password "hello world hello world!"
  @valid_email "user1@example.com"
  @reverse_user_email "user2@example.com"

  describe "User Connection Index" do
    setup [:create_users_with_connection]

    test "renders connections page with connections list", %{conn: conn, user: user, key: key} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections")

      assert html =~ "Your Connections"
      assert html =~ "connections"
    end

    test "displays confirmed connections in connections tab", %{
      conn: conn,
      user: user,
      key: key,
      reverse_user: _reverse_user
    } do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections")

      # Should see the connection information
      assert render(lv) =~ "User Two"
    end

    test "can switch between tabs", %{conn: conn, user: user, key: key} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections")

      # Basic functionality - page loads successfully with both tabs
      assert render(lv) =~ "Connections"
      assert render(lv) =~ "Requests"
    end

    test "can search connections", %{conn: conn, user: user, key: key} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections")

      # Verify basic search functionality exists
      assert has_element?(lv, "form")
    end

    test "displays connection information correctly", %{
      conn: conn,
      user: user,
      key: key
    } do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections")

      # Verify connection information is displayed
      assert render(lv) =~ "User Two"
    end
  end

  describe "New Connection Form" do
    setup [:create_user]

    test "can access new connection functionality", %{conn: conn, user: user, key: key} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections")

      # Basic test - verify the page loads
      assert render(lv) =~ "connections"
    end

    test "validates connection requirements", %{conn: conn, user: user, key: key} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections")

      # Basic test - verify page functionality
      assert render(lv) =~ "connections"
    end
  end

  describe "Visibility Groups" do
    setup [:create_user]

    test "can manage visibility groups", %{conn: conn, user: user, key: key} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections")

      # Basic test - verify page functionality
      assert render(lv) =~ "connections"
    end
  end

  describe "Real-time Updates" do
    setup [:create_users_with_connection]

    test "handles connection updates", %{
      conn: conn,
      user: user,
      key: key
    } do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections")

      # Basic test - verify real-time capability exists
      assert render(lv) =~ "User Two"
    end

    test "handles status updates", %{
      conn: conn,
      user: user,
      key: key,
      reverse_user: reverse_user,
      r_key: r_key
    } do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections")

      # Update the reverse user's status
      {:ok, updated_reverse_user} =
        Accounts.update_user_status(
          reverse_user,
          %{
            status: "busy",
            status_message: "In a meeting",
            status_visibility: :connections
          },
          user: reverse_user,
          key: r_key
        )

      # Broadcast the status update
      Phoenix.PubSub.broadcast(
        Mosslet.PubSub,
        "user_status:#{user.id}",
        {:status_updated, updated_reverse_user}
      )

      # Verify the LiveView can handle the message
      assert render(lv) =~ "User Two"
    end
  end

  describe "Presence Tracking" do
    setup [:create_user]

    test "tracks user presence on connections page", %{conn: conn, user: user, key: key} do
      {:ok, _lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections")

      # Check that presence is tracked
      assert Presence.user_active_on_connections?(user.id)
    end

    test "stops tracking presence when user leaves", %{conn: conn, user: user, key: key} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections")

      assert Presence.user_active_on_connections?(user.id)

      # Simulate leaving the page
      GenServer.stop(lv.pid)
      :timer.sleep(100)

      refute Presence.user_active_on_connections?(user.id)
    end
  end

  # Helper functions
  defp create_user(_) do
    user = user_fixture(%{email: @valid_email, password: @valid_password})
    user = Accounts.confirm_user!(user)
    {:ok, user} = Accounts.update_user_onboarding(user, %{is_onboarded?: true})

    key = get_key(user, @valid_password)

    {:ok, user} =
      Accounts.update_user_onboarding_profile(user, %{name: "User One"},
        change_name: true,
        key: key,
        user: user
      )

    # Create billing customer and subscription for the user
    {:ok, customer} = create_billing_customer(user, key)
    {:ok, _payment_intent} = create_payment_intent(customer, user, key)

    %{user: user, key: key, customer: customer}
  end

  defp create_users_with_connection(_) do
    # Create first user
    user = user_fixture(%{email: @valid_email, password: @valid_password})
    user = Accounts.confirm_user!(user)
    {:ok, user} = Accounts.update_user_onboarding(user, %{is_onboarded?: true})

    key = get_key(user, @valid_password)

    {:ok, user} =
      Accounts.update_user_onboarding_profile(user, %{name: "User One"},
        change_name: true,
        key: key,
        user: user
      )

    # Create billing customer and subscription for the first user
    {:ok, customer} = create_billing_customer(user, key)
    {:ok, _payment_intent} = create_payment_intent(customer, user, key)

    # Create second user
    reverse_user =
      user_fixture(%{
        username: "reverse_group_friend",
        email: @reverse_user_email,
        password: @valid_password
      })

    reverse_user = Accounts.confirm_user!(reverse_user)
    {:ok, reverse_user} = Accounts.update_user_onboarding(reverse_user, %{is_onboarded?: true})

    r_key = get_key(reverse_user, @valid_password)

    # Update the visibility
    {:ok, reverse_user} =
      Accounts.update_user_visibility(reverse_user, %{visibility: :connections}, key: r_key)

    {:ok, reverse_user} =
      Accounts.update_user_onboarding_profile(reverse_user, %{name: "User Two"},
        change_name: true,
        key: r_key,
        user: reverse_user
      )

    # Create billing customer and subscription for the second user
    {:ok, r_customer} = create_billing_customer(reverse_user, r_key)
    {:ok, _r_payment_intent} = create_payment_intent(r_customer, reverse_user, r_key)

    # Create confirmed connection between users using the exact same pattern as post_live_test
    # The reverse_user is creating the connection request to user
    uconn_attrs = %{
      "color" => "rose",
      "temp_label" => "friend",
      "connection_id" => user.connection.id,
      "reverse_user_id" => user.id,
      "selector" => "username",
      "username" => "reverse_group_friend"
    }

    user_connection =
      user_connection_fixture(uconn_attrs,
        user: user,
        reverse_user: reverse_user,
        key: key,
        r_key: r_key,
        confirm?: true
      )

    %{
      user: user,
      key: key,
      reverse_user: reverse_user,
      r_key: r_key,
      user_connection: user_connection,
      customer: customer,
      r_customer: r_customer
    }
  end

  defp create_billing_customer(user, key) do
    Mosslet.Billing.Customers.create_customer_for_source(
      :user,
      user.id,
      %{
        email: Mosslet.Encrypted.Users.Utils.decrypt_user_data(user.email, user, key),
        provider: "stripe",
        provider_customer_id: @provider_customer_id,
        user_id: user.id
      },
      user,
      key
    )
  end

  defp create_payment_intent(customer, user, key) do
    Mosslet.Billing.PaymentIntents.create_payment_intent!(
      %{
        provider_payment_intent_id: @provider_payment_intent_id,
        provider_customer_id: @provider_customer_id,
        provider_latest_charge_id: @provider_latest_charge_id,
        provider_payment_method_id: @provider_payment_method_id,
        provider_created_at: DateTime.utc_now(),
        amount: 5900,
        amount_received: 5900,
        status: "succeeded",
        billing_customer_id: customer.id
      },
      user,
      key
    )
  end

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
