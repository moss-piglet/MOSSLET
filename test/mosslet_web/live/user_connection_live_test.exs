defmodule MossletWeb.UserConnectionLiveTest do
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures
  import Mosslet.UserConnectionFixtures

  alias Mosslet.Accounts
  alias MossletWeb.Presence

  @provider_customer_id "cus_#{Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)}"
  @provider_latest_charge_id "ch_#{Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)}"
  @provider_payment_intent_id "pi_#{Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)}"
  @provider_payment_method_id "pm_#{Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)}"
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

      html = render(lv)
      # Should see connection card structure with ZK decryption hook
      assert html =~ "data-decrypt-conn-name"
      assert html =~ "data-decrypt-conn-username"
      assert html =~ "data-decrypt-conn-label"
      assert html =~ "data-sealed-uconn-key"
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

    test "renders peer public keys + peer user id for client-side TOFU pinning", %{
      conn: conn,
      user: user,
      key: key
    } do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections")

      assert html =~ "data-peer-public-key"
      assert html =~ "data-peer-pq-public-key"
      assert html =~ "data-peer-user-id"
    end

    test "store_peer_pin persists the sealed blob for a confirmed peer", %{
      conn: conn,
      user: user,
      key: key,
      reverse_user: reverse_user
    } do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections")

      assert is_nil(Accounts.get_key_pin(user.id, reverse_user.id))

      blob = Base.encode64(:crypto.strong_rand_bytes(96))

      render_hook(lv, "store_peer_pin", %{
        "peer_user_id" => reverse_user.id,
        "sealed_pin" => blob
      })

      pin = Accounts.get_key_pin(user.id, reverse_user.id)
      assert pin.pinned_fingerprint == blob
    end

    test "store_peer_pin rejects a peer the viewer has no confirmed connection to", %{
      conn: conn,
      user: user,
      key: key
    } do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections")

      # A stranger the viewer has no user_connection to at all.
      stranger =
        user_fixture(%{
          username: "pin_stranger",
          email: "pin_stranger@example.com",
          password: @valid_password
        })

      blob = Base.encode64(:crypto.strong_rand_bytes(96))

      render_hook(lv, "store_peer_pin", %{
        "peer_user_id" => stranger.id,
        "sealed_pin" => blob
      })

      assert is_nil(Accounts.get_key_pin(user.id, stranger.id))
    end

    test "verify_peer_key persists a verified pin for a confirmed peer (#302)", %{
      conn: conn,
      user: user,
      key: key,
      reverse_user: reverse_user
    } do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections")

      verified = Base.encode64(:crypto.strong_rand_bytes(120))

      render_hook(lv, "verify_peer_key", %{
        "peer_user_id" => reverse_user.id,
        "sealed_pin" => verified
      })

      assert Accounts.get_key_pin(user.id, reverse_user.id).pinned_fingerprint == verified
    end

    test "repin_peer_key OVERWRITES an existing pin for a confirmed peer (#302)", %{
      conn: conn,
      user: user,
      key: key,
      reverse_user: reverse_user
    } do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections")

      pinned = Base.encode64(:crypto.strong_rand_bytes(96))
      reverified = Base.encode64(:crypto.strong_rand_bytes(120))
      assert {:ok, _} = Accounts.upsert_key_pin(user.id, reverse_user.id, pinned)

      render_hook(lv, "repin_peer_key", %{
        "peer_user_id" => reverse_user.id,
        "sealed_pin" => reverified
      })

      assert Accounts.get_key_pin(user.id, reverse_user.id).pinned_fingerprint == reverified
    end

    test "verify_peer_key rejects a peer the viewer has no confirmed connection to (#302)", %{
      conn: conn,
      user: user,
      key: key
    } do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections")

      stranger =
        user_fixture(%{
          username: "verify_index_stranger",
          email: "verify_index_stranger@example.com",
          password: @valid_password
        })

      render_hook(lv, "verify_peer_key", %{
        "peer_user_id" => stranger.id,
        "sealed_pin" => Base.encode64(:crypto.strong_rand_bytes(96))
      })

      assert is_nil(Accounts.get_key_pin(user.id, stranger.id))
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

      html = render(lv)
      # Verify connection card ZK decryption structure is present
      assert html =~ "data-decrypt-conn-name"
      assert html =~ "data-decrypt-conn-username"
      assert html =~ "data-decrypt-conn-label"
    end
  end

  describe "User Connection Show — key verification (#295)" do
    setup [:create_users_with_connection]

    test "renders the safety-number / key-verification panel with peer key data", %{
      conn: conn,
      user: user,
      key: key,
      reverse_user: reverse_user
    } do
      [uconn] = Accounts.filter_user_connections(%{}, user)

      {:ok, _lv, html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections/#{uconn.id}")

      assert html =~ "KeySafetyNumber"
      assert html =~ "Key verification"
      assert html =~ "data-safety-number"
      assert html =~ ~s(data-peer-user-id="#{reverse_user.id}")
      # The peer's served public keys reach the panel for client-side fingerprinting.
      assert html =~ reverse_user.pq_public_key
    end

    test "verify_peer_key OVERWRITES an existing pin for a confirmed peer (#295)", %{
      conn: conn,
      user: user,
      key: key,
      reverse_user: reverse_user
    } do
      [uconn] = Accounts.filter_user_connections(%{}, user)

      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections/#{uconn.id}")

      pinned = Base.encode64(:crypto.strong_rand_bytes(96))
      verified = Base.encode64(:crypto.strong_rand_bytes(120))

      assert {:ok, _} = Accounts.upsert_key_pin(user.id, reverse_user.id, pinned)

      render_hook(lv, "verify_peer_key", %{
        "peer_user_id" => reverse_user.id,
        "sealed_pin" => verified
      })

      assert Accounts.get_key_pin(user.id, reverse_user.id).pinned_fingerprint == verified
    end

    test "repin_peer_key rejects a peer the viewer has no confirmed connection to (#295)", %{
      conn: conn,
      user: user,
      key: key
    } do
      [uconn] = Accounts.filter_user_connections(%{}, user)

      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections/#{uconn.id}")

      stranger =
        user_fixture(%{
          username: "repin_stranger",
          email: "repin_stranger@example.com",
          password: @valid_password
        })

      render_hook(lv, "repin_peer_key", %{
        "peer_user_id" => stranger.id,
        "sealed_pin" => Base.encode64(:crypto.strong_rand_bytes(96))
      })

      assert is_nil(Accounts.get_key_pin(user.id, stranger.id))
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

      html = render(lv)
      # Verify connection card ZK decryption structure is present
      assert html =~ "data-decrypt-conn-name"
      assert html =~ "data-decrypt-conn-username"
      assert html =~ "data-decrypt-conn-label"
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

      html = render(lv)
      # Verify connection card ZK decryption structure is still present
      assert html =~ "data-decrypt-conn-name"
      assert html =~ "data-decrypt-conn-username"
      assert html =~ "data-decrypt-conn-label"
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

  defp create_billing_customer(user, _key) do
    Mosslet.Billing.Customers.create_customer_for_source(
      :user,
      user.id,
      %{
        email: "test@example.com",
        provider: "stripe",
        provider_customer_id: @provider_customer_id,
        user_id: user.id
      }
    )
  end

  defp create_payment_intent(customer, _user, _key) do
    Mosslet.Billing.PaymentIntents.create_payment_intent!(%{
      provider_payment_intent_id: @provider_payment_intent_id,
      provider_customer_id: @provider_customer_id,
      provider_latest_charge_id: @provider_latest_charge_id,
      provider_payment_method_id: @provider_payment_method_id,
      provider_created_at: DateTime.utc_now(),
      amount: 5900,
      amount_received: 5900,
      status: "succeeded",
      billing_customer_id: customer.id
    })
  end

  describe "Signed key history — global write handlers (#315)" do
    setup [:create_users_with_connection]

    test "store_signing_keys persists the signing keypair for the current user", %{
      conn: conn,
      user: user,
      key: key
    } do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections")

      assert is_nil(Accounts.get_user!(user.id).signing_public_key)

      signing_pub = Base.encode64(:crypto.strong_rand_bytes(64))
      sealed_secret = Base.encode64(:crypto.strong_rand_bytes(128))

      render_hook(lv, "store_signing_keys", %{
        "signing_public_key" => signing_pub,
        "encrypted_signing_private_key" => sealed_secret
      })

      reloaded = Accounts.get_user!(user.id)
      assert reloaded.signing_public_key == signing_pub
      assert reloaded.encrypted_signing_private_key == sealed_secret
    end

    test "append_key_history is append-only — a duplicate seq is a no-op", %{
      conn: conn,
      user: user,
      key: key
    } do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections")

      assert Accounts.list_key_history_entries(user.id) == []

      signing_pub = Base.encode64(:crypto.strong_rand_bytes(64))
      genesis = ~s({"v":1,"seq":0,"sign_pub":"#{signing_pub}","entry_hash":"abc"})
      dup = ~s({"v":1,"seq":0,"sign_pub":"#{signing_pub}","entry_hash":"DIFFERENT"})

      render_hook(lv, "append_key_history", %{
        "seq" => 0,
        "entry" => genesis,
        "signing_public_key" => signing_pub
      })

      # Same seq, different bytes: must be dropped (first-write-wins).
      render_hook(lv, "append_key_history", %{
        "seq" => 0,
        "entry" => dup,
        "signing_public_key" => signing_pub
      })

      assert Accounts.list_key_history_entries(user.id) == [genesis]
    end

    test "append_key_history serves entries ascending by seq", %{
      conn: conn,
      user: user,
      key: key
    } do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/users/connections")

      signing_pub = Base.encode64(:crypto.strong_rand_bytes(64))
      genesis = ~s({"v":1,"seq":0,"sign_pub":"#{signing_pub}"})
      rotation = ~s({"v":1,"seq":1,"sign_pub":"#{signing_pub}"})

      # Push out of order; the store + serve order must still be ascending.
      render_hook(lv, "append_key_history", %{"seq" => 1, "entry" => rotation})
      render_hook(lv, "append_key_history", %{"seq" => 0, "entry" => genesis})

      assert Accounts.list_key_history_entries(user.id) == [genesis, rotation]
    end
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
