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
  import Mosslet.TimelineFixtures

  alias Mosslet.Accounts
  alias Mosslet.Timeline

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

    test "no replies card when there is no unread reply activity", %{
      conn: conn,
      user: user,
      user_key: key
    } do
      {:ok, lv, _html} = visit_dashboard(conn, user, key)

      refute has_element?(lv, "#dashboard-replies")
    end

    test "surfaces unread replies with deep links to the reply in the timeline", %{
      conn: conn,
      user: user,
      user_key: key
    } do
      {reply, post} = create_reply_activity(user, key)

      {:ok, lv, _html} = visit_dashboard(conn, user, key)

      assert has_element?(lv, "#dashboard-replies")

      assert has_element?(
               lv,
               ~s{#dash-reply-#{reply.id}[href="/app/timeline?post_id=#{post.id}&reply_id=#{reply.id}"]}
             )
    end

    test "new replies appear on the dashboard in realtime", %{
      conn: conn,
      user: user,
      user_key: key
    } do
      {:ok, lv, _html} = visit_dashboard(conn, user, key)

      refute has_element?(lv, "#dashboard-replies")

      {reply, _post} = create_reply_activity(user, key)

      assert has_element?(lv, "#dashboard-replies")
      assert has_element?(lv, "#dash-reply-#{reply.id}")
    end

    test "replies to the user's own replies are surfaced too (nested)", %{
      conn: conn,
      user: user,
      user_key: key
    } do
      {replier, r_key, post} = connect_replier(user, key)

      # The dashboard user replies to their own post first…
      parent = create_reply(post, user, key, "owner chiming in")

      # …and the connection replies to THAT reply (reply-to-reply)
      nested = create_reply(post, replier, r_key, "reply to your reply", parent.id)

      {:ok, lv, _html} = visit_dashboard(conn, user, key)

      assert has_element?(lv, "#dashboard-replies")

      assert has_element?(
               lv,
               ~s{#dash-reply-#{nested.id}[href="/app/timeline?post_id=#{post.id}&reply_id=#{nested.id}"]}
             )

      refute has_element?(lv, "#dash-reply-#{parent.id}")
    end

    test "groups multiple unread replies on the same post into one row", %{
      conn: conn,
      user: user,
      user_key: key
    } do
      {replier, r_key, post} = connect_replier(user, key)

      first = create_reply(post, replier, r_key, "first reply")
      second = create_reply(post, replier, r_key, "second reply")

      # inserted_at is second-truncated, so backdate the first reply to make
      # the group's "newest" deterministic
      first
      |> Ecto.Changeset.change(inserted_at: NaiveDateTime.add(second.inserted_at, -60, :second))
      |> Mosslet.Repo.update!()

      {:ok, lv, _html} = visit_dashboard(conn, user, key)

      # One row per post, keyed by (and deep-linking to) the newest reply
      assert has_element?(lv, "#dash-reply-#{second.id}")
      refute has_element?(lv, "#dash-reply-#{first.id}")

      # …with a count badge and an aggregated link into the timeline
      assert has_element?(lv, "#dash-reply-count-#{post.id}", "2")

      assert has_element?(
               lv,
               ~s{#dash-reply-#{second.id}[href="/app/timeline?post_id=#{post.id}&reply_id=#{second.id}"]}
             )
    end

    test "replies on different posts each get their own row", %{
      conn: conn,
      user: user,
      user_key: key
    } do
      {replier, r_key, post} = connect_replier(user, key)

      other_post = post_fixture(%{username: "dashuser"}, user: user, key: key)
      share_post_with(other_post, user, key, replier)

      reply_a = create_reply(post, replier, r_key, "on post one")
      reply_b = create_reply(other_post, replier, r_key, "on post two")

      {:ok, lv, _html} = visit_dashboard(conn, user, key)

      assert has_element?(lv, "#dash-reply-#{reply_a.id}")
      assert has_element?(lv, "#dash-reply-#{reply_b.id}")

      # Neither post has a count badge — each holds a single reply
      refute has_element?(lv, "#dash-reply-count-#{post.id}")
      refute has_element?(lv, "#dash-reply-count-#{other_post.id}")
    end
  end

  describe "reply deep links (post page)" do
    setup [:create_dashboard_user]

    test "visiting a reply deep link targets the reply and marks the thread read", %{
      conn: conn,
      user: user,
      user_key: key
    } do
      {reply, post} = create_reply_activity(user, key)

      assert Timeline.count_unread_replies_for_user(user) == 1

      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/posts/#{post.id}?reply=#{reply.id}")

      assert has_element?(lv, ~s{#replies[data-target-reply-id="#{reply.id}"]})
      assert has_element?(lv, "#reply-#{reply.id}")

      # Seeing the thread clears the viewer's unread reply state
      assert Timeline.count_unread_replies_for_user(user) == 0
    end
  end

  describe "reply deep links (timeline)" do
    setup [:create_dashboard_user]

    test "visiting a reply deep link renders the post in the feed with the reply", %{
      conn: conn,
      user: user,
      user_key: key
    } do
      {reply, post} = create_reply_activity(user, key)

      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline?post_id=#{post.id}&reply_id=#{reply.id}")

      # The author's own post sits behind the read divider, so the deep link
      # injects it into the rendered feed…
      html = render_async(lv)

      assert html =~ ~s(id="timeline-card-#{post.id}")

      # …with the reply present in the (expandable) thread
      assert has_element?(lv, "#reply-thread-#{post.id}")
      assert has_element?(lv, "#reply-#{reply.id}")
    end

    test "without deep-link params the read post stays behind the divider", %{
      conn: conn,
      user: user,
      user_key: key
    } do
      {_reply, post} = create_reply_activity(user, key)

      {:ok, lv, _html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      html = render_async(lv)

      refute html =~ ~s(id="timeline-card-#{post.id}")
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

  # Creates a connected "replier" user, a post by the dashboard user shared
  # with them (mirroring the composer's per-recipient key sealing), and returns
  # {replier, replier_key, post}.
  defp connect_replier(user, key) do
    username = "replier#{System.unique_integer([:positive])}"

    replier =
      user_fixture(%{
        username: username,
        email: "#{username}@example.com",
        password: @valid_password
      })

    r_key = get_key(replier, @valid_password)

    {:ok, replier} =
      Accounts.update_user_visibility(replier, %{visibility: :connections}, key: r_key)

    {:ok, replier} =
      Accounts.update_user_onboarding_profile(replier, %{name: "Replier"},
        change_name: true,
        key: r_key,
        user: replier
      )

    uconn_attrs = %{
      "color" => "emerald",
      "temp_label" => "friend",
      "connection_id" => user.connection.id,
      "reverse_user_id" => user.id,
      "selector" => "username",
      "username" => username
    }

    _user_connection =
      Mosslet.UserConnectionFixtures.user_connection_fixture(uconn_attrs,
        user: user,
        reverse_user: replier,
        key: key,
        r_key: r_key,
        confirm?: true
      )

    post = post_fixture(%{username: "dashuser"}, user: user, key: key)

    share_post_with(post, user, key, replier)

    {replier, r_key, post}
  end

  # Seal the post key for the replier (what create_shared_user_posts does in
  # the composer flow) so they can read and reply to the post.
  defp share_post_with(post, owner, owner_key, recipient) do
    author_user_post = Timeline.get_user_post(post, owner)

    {:ok, raw_post_key} =
      Mosslet.Encrypted.Users.Utils.decrypt_user_attrs_key(author_user_post.key, owner, owner_key)

    %Mosslet.Timeline.UserPost{}
    |> Mosslet.Timeline.UserPost.sharing_changeset(
      %{key: raw_post_key, post_id: post.id, user_id: recipient.id},
      user: recipient,
      visibility: "connections"
    )
    |> Mosslet.Repo.insert!()
  end

  defp create_reply(post, replier, r_key, body, parent_reply_id \\ nil) do
    user_post = Timeline.get_user_post(post, replier)

    {:ok, reply} =
      Timeline.create_reply(
        %{
          "user_id" => replier.id,
          "post_id" => post.id,
          "parent_reply_id" => parent_reply_id,
          "visibility" => "connections",
          "body" => body,
          "username" => "replier"
        },
        user: replier,
        key: r_key,
        post: post,
        post_key: user_post.key,
        visibility: :connections
      )

    reply
  end

  defp create_reply_activity(user, key) do
    {replier, r_key, post} = connect_replier(user, key)
    reply = create_reply(post, replier, r_key, "hello from a connection")

    {reply, post}
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
