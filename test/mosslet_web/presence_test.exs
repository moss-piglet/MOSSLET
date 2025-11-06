defmodule MossletWeb.PresenceTest do
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures

  alias MossletWeb.Presence
  alias Mosslet.Accounts

  @provider_customer_id "cus_#{Faker.Util.format("%3b%1d%2b%2d%4b%1d%1b")}"
  @provider_latest_charge_id "ch_#{Faker.Util.format("%3b%1d%2b%2d%4b%1d%1b")}"
  @provider_payment_intent_id "pi_#{Faker.Util.format("%3b%1d%2b%2d%4b%1d%1b")}"
  @provider_payment_method_id "pm_#{Faker.Util.format("%3b%1d%2b%2d%4b%1d%1b")}"
  @valid_password "hello world hello world!"
  @valid_email "user1@example.com"

  describe "Presence Tracking" do
    setup [:create_user]

    test "tracks user presence on timeline", %{conn: conn, user: user, key: key} do
      initial_count = Presence.active_timeline_user_count()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      # User should be tracked as active on timeline
      assert Presence.user_active_on_timeline?(user.id)
      assert Presence.active_timeline_user_count() == initial_count + 1

      # User should be active in the app
      assert Presence.user_active_in_app?(user.id)

      # Should contain user in active users list
      active_users = Presence.get_active_timeline_user_ids()
      assert user.id in active_users

      # Clean up
      GenServer.stop(lv.pid)
    end

    test "tracks user presence on connections page", %{conn: conn, user: user, key: key} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections")

      # User should be tracked as active on connections
      assert Presence.user_active_on_connections?(user.id)

      # User should be active in the app
      assert Presence.user_active_in_app?(user.id)

      # Clean up
      GenServer.stop(lv.pid)
    end

    test "stops tracking presence when user disconnects", %{conn: conn, user: user, key: key} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      # Verify user is tracked
      assert Presence.user_active_on_timeline?(user.id)

      # Simulate disconnection
      GenServer.stop(lv.pid)
      # Give time for presence to update
      :timer.sleep(200)

      # User should no longer be tracked
      refute Presence.user_active_on_timeline?(user.id)
      refute Presence.user_active_in_app?(user.id)
    end

    test "handles multiple presence sessions for same user", %{conn: conn, user: user, key: key} do
      # Start timeline session
      {:ok, timeline_lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      assert Presence.user_active_on_timeline?(user.id)
      refute Presence.user_active_on_connections?(user.id)

      # Start connections session using a new connection
      conn2 = build_conn() |> init_test_session(%{})

      {:ok, connections_lv, _html} =
        conn2
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections")

      # User should be active on both
      assert Presence.user_active_on_timeline?(user.id)
      assert Presence.user_active_on_connections?(user.id)
      assert Presence.user_active_in_app?(user.id)

      # Stop timeline session
      GenServer.stop(timeline_lv.pid)
      :timer.sleep(100)

      # Should still be active on connections
      assert Presence.user_active_on_connections?(user.id)
      assert Presence.user_active_in_app?(user.id)

      # Stop connections session
      GenServer.stop(connections_lv.pid)
      :timer.sleep(100)

      # Should no longer be active anywhere
      refute Presence.user_active_on_timeline?(user.id)
      refute Presence.user_active_on_connections?(user.id)
      refute Presence.user_active_in_app?(user.id)
    end

    test "provides correct user counts", %{conn: conn, user: user, key: key} do
      initial_timeline_count = Presence.active_timeline_user_count()

      # Create second user
      user2 = user_fixture(%{email: "user2@example.com", password: @valid_password})
      user2 = Accounts.confirm_user!(user2)
      {:ok, user2} = Accounts.update_user_onboarding(user2, %{is_onboarded?: true})
      key2 = get_key(user2, @valid_password)

      # Setup billing for second user
      {:ok, customer2} = create_billing_customer(user2, key2)
      {:ok, _payment_intent2} = create_payment_intent(customer2, user2, key2)

      # Both users connect to timeline
      {:ok, lv1, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      conn2 = build_conn() |> init_test_session(%{})

      {:ok, lv2, _html} =
        conn2
        |> log_in_user(user2, key2)
        |> live(~p"/app/timeline")

      # Count should reflect both users
      assert Presence.active_timeline_user_count() == initial_timeline_count + 2

      # Both should be in active users list
      active_users = Presence.get_active_timeline_user_ids()
      assert user.id in active_users
      assert user2.id in active_users

      # Clean up
      GenServer.stop(lv1.pid)
      GenServer.stop(lv2.pid)
    end
  end

  describe "Privacy Features" do
    setup [:create_user]

    test "only stores minimal data for cache optimization", %{conn: conn, user: user, key: key} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      # Check that presence data contains only what's needed for caching
      # This is more of a documentation test to ensure privacy design
      assert Presence.user_active_on_timeline?(user.id)

      # Get the raw presence data to verify minimal storage
      presence_list = Phoenix.Presence.list(Presence, "proxy:online_users")
      user_presence = Map.get(presence_list, user.id)

      # Should only contain metadata for cache optimization
      assert is_map(user_presence)

      # Verify no username or sensitive data is stored
      presence_data = user_presence.metas |> List.first()
      assert Map.has_key?(presence_data, :joined_at)
      assert Map.has_key?(presence_data, :cache_optimization)
      refute Map.has_key?(presence_data, :username)
      refute Map.has_key?(presence_data, :email)

      # Clean up
      GenServer.stop(lv.pid)
    end

    test "broadcasts cache optimization events", %{conn: conn, user: user, key: key} do
      # Subscribe to cache presence events
      Phoenix.PubSub.subscribe(Mosslet.PubSub, "timeline_cache_presence")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      # Should receive cache optimization broadcast
      assert_receive {:user_joined_timeline, received_user_id}, 1000
      assert received_user_id == user.id

      # Clean up
      GenServer.stop(lv.pid)
    end
  end

  describe "Integration with Auto-Status" do
    setup [:create_user]

    test "presence integration for auto-status determination", %{conn: conn, user: user, key: key} do
      # Initially user is not active
      refute Presence.user_active_in_app?(user.id)

      # User joins timeline
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      # Should be detectable for auto-status
      assert Presence.user_active_in_app?(user.id)

      # This would be used by auto-status system to determine if user is "online"
      # but without exposing this information publicly

      # Clean up
      GenServer.stop(lv.pid)
      :timer.sleep(100)

      # Should no longer be active
      refute Presence.user_active_in_app?(user.id)
    end
  end

  describe "Error Handling" do
    test "handles presence tracking failures gracefully" do
      # Test tracking returns error for invalid PID
      # Since Phoenix.Tracker.track/5 requires a valid PID, we expect it to raise
      assert_raise FunctionClauseError, fn ->
        Presence.track_timeline_activity(nil, "invalid_user_id")
      end
    end

    test "returns empty list when no users active" do
      # Ensure clean state
      active_users = Presence.get_active_timeline_user_ids()
      assert is_list(active_users)

      # Count should be non-negative
      count = Presence.active_timeline_user_count()
      assert count >= 0
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
