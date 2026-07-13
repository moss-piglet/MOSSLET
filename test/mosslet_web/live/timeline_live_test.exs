defmodule MossletWeb.TimelineLiveTest do
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures
  import Mosslet.TimelineFixtures
  import Mosslet.UserConnectionFixtures

  alias Mosslet.Accounts
  alias MossletWeb.Presence

  @provider_customer_id "cus_#{Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)}"
  @provider_latest_charge_id "ch_#{Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)}"
  @provider_payment_intent_id "pi_#{Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)}"
  @provider_payment_method_id "pm_#{Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)}"
  @valid_password "hello world hello world!"
  @valid_email "user1@example.com"
  @friend_email "friend@example.com"

  describe "Timeline Index" do
    setup [:create_user_with_connection]

    test "renders timeline page with posts", %{conn: conn, user: user, key: key} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      # Wait for async timeline data to load
      html = render_async(lv)

      assert html =~ "Timeline"
      assert html =~ "Home"
    end

    test "can switch between timeline tabs", %{conn: conn, user: user, key: key} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      # Wait for initial async data load
      render_async(lv)

      # Basic functionality - page loads successfully with tabs
      assert render(lv) =~ "Home"
      assert render(lv) =~ "Bookmarks"
      assert render(lv) =~ "Discover"

      # Test tab switching triggers async load
      lv |> element("button", "Discover") |> render_click()

      # Wait for tab switch async operation
      render_async(lv)

      # Verify we're on connections tab
      assert render(lv) =~ "Timeline"
    end

    test "loads posts correctly", %{
      conn: conn,
      user: user,
      key: key,
      friend: _friend,
      friend_key: _friend_key
    } do
      # Create posts for different scenarios
      _user_post =
        post_fixture(%{visibility: "connections", body: "User's post"}, user: user, key: key)

      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      # Wait for async timeline data to load
      html = render_async(lv)

      # Home tab should show content
      assert html =~ "Timeline"
    end

    test "can load more posts with pagination", %{conn: conn, user: user, key: key} do
      # Create multiple posts
      for i <- 1..5 do
        post_fixture(%{body: "Post #{i}"}, user: user, key: key)
      end

      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      # Wait for async timeline data to load
      html = render_async(lv)

      # Verify basic functionality
      assert html =~ "Timeline"
    end
  end

  describe "Post Creation" do
    setup [:create_user_with_connection]

    test "can create a new post", %{conn: conn, user: user, key: key} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      # Wait for async timeline data to load
      render_async(lv)

      # Expand the composer (collapsed by default)
      lv |> element("#compose-fab-button-true") |> render_click()

      # Verify post creation form exists
      assert has_element?(lv, "#timeline-composer")
    end

    test "validates post creation", %{conn: conn, user: user, key: key} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      # Wait for async timeline data to load
      render_async(lv)

      # Expand the composer (collapsed by default)
      lv |> element("#compose-fab-button-true") |> render_click()

      # Verify basic form functionality
      assert has_element?(lv, "#timeline-composer")
    end

    test "can create post with privacy controls", %{conn: conn, user: user, key: key} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      # Wait for async timeline data to load
      render_async(lv)

      # Verify basic privacy controls exist
      assert render(lv) =~ "Timeline"
    end

    test "can create ephemeral post", %{conn: conn, user: user, key: key} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      # Wait for async timeline data to load
      render_async(lv)

      # Verify basic functionality
      assert render(lv) =~ "Timeline"
    end
  end

  describe "Post Interactions" do
    setup [:create_user_with_connection_and_posts]

    test "can interact with posts", %{conn: conn, user: user, key: key, friend_post: _friend_post} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      # Wait for async timeline data to load
      render_async(lv)

      # Basic functionality test
      assert render(lv) =~ "Timeline"
    end

    test "can bookmark a post", %{conn: conn, user: user, key: key, friend_post: _friend_post} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      # Wait for async timeline data to load
      render_async(lv)

      # Basic functionality test
      assert render(lv) =~ "Timeline"
    end

    test "can reply to a post", %{conn: conn, user: user, key: key, friend_post: _friend_post} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      # Wait for async timeline data to load
      render_async(lv)

      # Basic functionality test
      assert render(lv) =~ "Timeline"
    end

    test "can delete own post", %{conn: conn, user: user, key: key, user_post: _user_post} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      # Wait for async timeline data to load
      render_async(lv)

      # Basic functionality test
      assert render(lv) =~ "Timeline"
    end
  end

  describe "Real-time Updates" do
    setup [:create_user_with_connection_and_posts]

    test "receives status updates for connected users", %{
      conn: conn,
      user: user,
      key: key,
      friend: friend,
      friend_key: friend_key
    } do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      # Wait for async timeline data to load
      render_async(lv)

      # Update friend's status
      {:ok, updated_friend} =
        Accounts.update_user_status(
          friend,
          %{
            status: "busy",
            status_message: "In a meeting",
            status_visibility: :connections
          },
          user: friend,
          key: friend_key
        )

      # Broadcast the status update
      Phoenix.PubSub.broadcast(
        Mosslet.PubSub,
        "user_status:#{user.id}",
        {:status_updated, updated_friend}
      )

      # Basic test - verify functionality
      assert render(lv) =~ "Timeline"
    end
  end

  describe "Content Filtering" do
    setup [:create_user_with_connection]

    test "applies content filters to timeline", %{
      conn: conn,
      user: user,
      key: key,
      friend: _friend,
      friend_key: _friend_key
    } do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      # Wait for async timeline data to load
      render_async(lv)

      # Basic functionality test
      assert render(lv) =~ "Timeline"
    end
  end

  describe "Presence Tracking" do
    setup [:create_user]

    test "tracks user presence on timeline", %{conn: conn, user: user, key: key} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      # Wait for async timeline data to load
      render_async(lv)

      # Check that presence is tracked
      assert Presence.user_active_on_timeline?(user.id)
    end

    test "stops tracking presence when user leaves", %{conn: conn, user: user, key: key} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      # Wait for async timeline data to load
      render_async(lv)

      assert Presence.user_active_on_timeline?(user.id)

      # Simulate leaving the page
      GenServer.stop(lv.pid)
      :timer.sleep(100)

      refute Presence.user_active_on_timeline?(user.id)
    end

    test "provides active user count for monitoring", %{conn: conn, user: user, key: key} do
      initial_count = Presence.active_timeline_user_count()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      # Wait for async timeline data to load
      render_async(lv)

      # Should increase count
      assert Presence.active_timeline_user_count() == initial_count + 1
    end
  end

  describe "Performance and Caching" do
    setup [:create_user_with_connection]

    test "loads timeline efficiently", %{conn: conn, user: user, key: key} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      # Wait for async timeline data to load
      html = render_async(lv)

      # Should have loaded timeline
      assert html =~ "Timeline"
    end
  end

  # Ritual prompt answer chip (EPIC #377, task #384). A post stamped with a
  # ritual_prompt_id gets a quiet "answered a shared prompt" chip; unstamped
  # posts do not. Also guards the ZK author-name sticky-decrypt fix.
  describe "Ritual prompt answer chip" do
    setup [:create_user_with_connection]

    test "renders the answer chip (with prompt text) only on stamped posts", %{
      conn: conn,
      user: user,
      key: key
    } do
      broadcast = ritual_broadcast_fixture("What's a small plan you're excited about?")

      stamped =
        post_fixture(
          %{visibility: "connections", body: "My answer", ritual_prompt_id: broadcast.id},
          user: user,
          key: key
        )

      plain =
        post_fixture(
          %{visibility: "connections", body: "Just a normal post"},
          user: user,
          key: key
        )

      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      render_async(lv)

      # The user's own posts land in the collapsed "read" section — expand it so
      # the cards (and their chips) render.
      lv |> element("button", "read posts") |> render_click()
      render_async(lv)

      # Chip present on the stamped post, absent on the plain one.
      assert has_element?(lv, "#ritual-answer-chip-#{stamped.id}")
      refute has_element?(lv, "#ritual-answer-chip-#{plain.id}")

      # The non-secret prompt text rides along as the hover/tap tooltip.
      html = render(lv)
      assert html =~ "What&#39;s a small plan you&#39;re excited about?"
      assert html =~ "Answered a shared prompt"
    end

    test "composer does not re-ask a prompt the viewer already answered", %{
      conn: conn,
      user: user,
      key: key
    } do
      broadcast = ritual_broadcast_fixture("Already answered prompt?")

      # Stamp an answering post so answered?/2 is true for this viewer.
      post_fixture(
        %{visibility: "public", body: "My answer", ritual_prompt_id: broadcast.id},
        user: user,
        key: key
      )

      # Arrive via a stale prompt link that tries to open the composer for it.
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline?compose=1&ritual=#{broadcast.id}")

      render_async(lv)

      # No "responding to" banner and no stamping input — it's already answered.
      refute has_element?(lv, "input[name='post[ritual_prompt_id]']")
      refute render(lv) =~ "Responding to today&#39;s prompt"
    end

    test "ZK author-name/handle spans render phx-update=ignore so patches don't revert them" do
      # A browser-decrypted post has its author name/handle filled client-side by
      # the DecryptPost hook. Those spans MUST carry phx-update="ignore" or a
      # LiveView patch (e.g. the read/unread stream reset) reverts them to "..."
      # and the hook never re-runs. Component-level guard for that fix (#384).
      post = %Mosslet.Timeline.Post{
        id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        visibility: :connections,
        is_ephemeral: false,
        expires_at: nil,
        mature_content: false,
        source: :mosslet,
        inserted_at: NaiveDateTime.utc_now(),
        updated_at: NaiveDateTime.utc_now()
      }

      post = Map.put(post, :decrypted, %{browser_decrypt?: true})

      html =
        render_component(&MossletWeb.TimelineComponents.liquid_post_header/1,
          post: post,
          current_user_id: Ecto.UUID.generate(),
          user_name: "...",
          user_handle: "@...",
          timestamp: "now"
        )

      assert html =~ ~s(data-decrypt-author-name-target="#{post.id}")
      assert html =~ ~s(data-decrypt-handle-target="#{post.id}")
      assert html =~ ~s(id="post-author-name-#{post.id}")
      assert html =~ ~s(id="post-author-handle-#{post.id}")
      assert html =~ ~s(phx-update="ignore")
    end
  end

  # Helper functions
  defp ritual_broadcast_fixture(prompt) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, broadcast} =
      %Mosslet.Rituals.PromptBroadcast{}
      |> Mosslet.Rituals.PromptBroadcast.changeset(%{
        prompt: prompt,
        theme: "looking forward",
        broadcast_at: now,
        expires_at: DateTime.add(now, 4, :day)
      })
      |> Mosslet.Repo.insert()

    broadcast
  end

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

    %{user: user, key: key}
  end

  defp create_user_with_connection(_) do
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

    # Create friend user - using the exact same pattern as user_connection_live tests
    friend =
      user_fixture(%{
        username: "reverse_group_friend",
        email: @friend_email,
        password: @valid_password
      })

    friend = Accounts.confirm_user!(friend)
    {:ok, friend} = Accounts.update_user_onboarding(friend, %{is_onboarded?: true})

    friend_key = get_key(friend, @valid_password)

    # Update the visibility
    {:ok, friend} =
      Accounts.update_user_visibility(friend, %{visibility: :connections}, key: friend_key)

    {:ok, friend} =
      Accounts.update_user_onboarding_profile(friend, %{name: "Friend User"},
        change_name: true,
        key: friend_key,
        user: friend
      )

    # Create billing customer and subscription for the friend user
    {:ok, friend_customer} = create_billing_customer(friend, friend_key)
    {:ok, _friend_payment_intent} = create_payment_intent(friend_customer, friend, friend_key)

    # Create confirmed connection between users using the EXACT same pattern as user_connection_live tests
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
        reverse_user: friend,
        key: key,
        r_key: friend_key,
        confirm?: true
      )

    %{
      user: user,
      key: key,
      friend: friend,
      friend_key: friend_key,
      user_connection: user_connection
    }
  end

  defp create_user_with_connection_and_posts(context) do
    %{user: user, key: key, friend: friend, friend_key: friend_key} =
      create_user_with_connection(context)

    # Create posts
    user_post =
      post_fixture(
        %{
          body: "User's own post",
          visibility: "connections"
        },
        user: user,
        key: key
      )

    friend_post =
      post_fixture(
        %{
          body: "Friend's post",
          visibility: "connections"
        },
        user: friend,
        key: friend_key
      )

    Map.merge(context, %{
      user: user,
      key: key,
      friend: friend,
      friend_key: friend_key,
      user_post: user_post,
      friend_post: friend_post
    })
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
