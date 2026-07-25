defmodule MossletWeb.FeedControllerTest do
  @moduledoc """
  Personal RSS feed (task #385). The feed is public-only and opt-in: it must
  serve valid RSS 2.0 for enabled users, 404 when disabled or unknown, and it
  must NEVER include connections/private posts (those are browser-encrypted and
  cannot be rendered server-side).
  """
  use MossletWeb.ConnCase

  import Mosslet.TimelineFixtures

  alias Mosslet.Accounts

  @password "hello world hello world"

  defp session_key(user) do
    {:ok, key} = Accounts.User.valid_key_hash?(user, @password)
    key
  end

  defp feed_user do
    user =
      Mosslet.AccountsFixtures.user_fixture(%{
        username: "rssfeeduser",
        email: "rssfeeduser#{System.unique_integer([:positive])}@example.com",
        password: @password
      })

    {user, session_key(user)}
  end

  # Production posts are created from string-keyed form params, which is what
  # makes Timeline.create_post seal the user_post key to the server's key pair
  # for public posts (so the server can render RSS). The atom-keyed
  # post_fixture path seals to the user instead, so we create feed-visible
  # public posts the same way the browser does.
  defp public_post_fixture(user, key, extra) do
    attrs =
      Map.merge(
        %{
          "body" => "some body",
          "username" => "rssfeeduser",
          "username_hash" => "rssfeeduser",
          "visibility" => "public",
          "favs_count" => 0,
          "reposts_count" => 0,
          "favs_list" => [],
          "image_urls" => [],
          "user_id" => user.id
        },
        extra
      )

    {:ok, post} = Mosslet.Timeline.create_post(attrs, user: user, key: key)
    Mosslet.Timeline.get_post!(post.id)
  end

  describe "GET /feeds/:token.xml" do
    test "serves RSS 2.0 with the correct content type for an enabled feed", %{conn: conn} do
      {user, key} = feed_user()

      post_fixture(%{username: "rssfeeduser", visibility: "public"}, user: user, key: key)

      {:ok, user} = Accounts.update_rss_feed_enabled(user, true)

      conn = get(conn, ~p"/feeds/#{user.rss_feed_token <> ".xml"}")

      assert response_content_type(conn, :xml) =~ "application/rss+xml"
      body = response(conn, 200)
      assert body =~ ~s(<?xml version="1.0" encoding="UTF-8"?>)
      assert body =~ ~s(<rss version="2.0")
      assert body =~ "<channel>"
      assert body =~ "<item>"
      assert Plug.Conn.get_resp_header(conn, "etag") != []
    end

    test "excludes connections and private posts", %{conn: conn} do
      {user, key} = feed_user()

      pub = post_fixture(%{username: "rssfeeduser", visibility: "public"}, user: user, key: key)

      priv =
        post_fixture(%{username: "rssfeeduser", visibility: "private"}, user: user, key: key)

      {:ok, user} = Accounts.update_rss_feed_enabled(user, true)

      conn = get(conn, ~p"/feeds/#{user.rss_feed_token <> ".xml"}")
      body = response(conn, 200)

      # GUIDs are the post ids
      assert body =~ pub.id
      refute body =~ priv.id
    end

    test "404s when the feed is disabled", %{conn: conn} do
      {user, key} = feed_user()
      post_fixture(%{username: "rssfeeduser", visibility: "public"}, user: user, key: key)

      {:ok, user} = Accounts.update_rss_feed_enabled(user, true)
      {:ok, user} = Accounts.update_rss_feed_enabled(user, false)

      conn = get(conn, ~p"/feeds/#{user.rss_feed_token <> ".xml"}")
      assert response(conn, 404)
    end

    test "404s for an unknown token", %{conn: conn} do
      conn = get(conn, ~p"/feeds/#{"definitely-not-a-real-token.xml"}")
      assert response(conn, 404)
    end

    test "inlines images with alt text in item descriptions", %{conn: conn} do
      {user, key} = feed_user()

      post =
        public_post_fixture(user, key, %{
          "image_urls" => ["test/photo.webp"],
          "image_alt_texts" => ["A calm mossy forest"]
        })

      {:ok, user} = Accounts.update_rss_feed_enabled(user, true)

      conn = get(conn, ~p"/feeds/#{user.rss_feed_token <> ".xml"}")
      body = response(conn, 200)

      # Inline <img> is what most readers render; enclosure/media stay for thumbnails
      assert body =~ ~s(<img src=")
      assert body =~ "/feed/public/posts/#{post.id}/images/0"
      assert body =~ ~s(alt="A calm mossy forest")
      assert body =~ ~s(<enclosure url=")
      assert body =~ ~s(<media:content url=")
    end
  end

  describe "GET /post/:id (RSS permalink)" do
    test "redirects public posts to the public timeline", %{conn: conn} do
      {user, key} = feed_user()

      post =
        post_fixture(%{username: "rssfeeduser", visibility: "public"}, user: user, key: key)

      conn = get(conn, ~p"/post/#{post.id}")
      assert redirected_to(conn) == ~p"/discover"
    end

    test "404s for non-public posts (no existence leak)", %{conn: conn} do
      {user, key} = feed_user()

      post =
        post_fixture(%{username: "rssfeeduser", visibility: "private"}, user: user, key: key)

      conn = get(conn, ~p"/post/#{post.id}")
      assert response(conn, 404)
    end

    test "404s for unknown and malformed ids", %{conn: conn} do
      conn = get(conn, ~p"/post/#{Ecto.UUID.generate()}")
      assert response(conn, 404)

      conn = get(build_conn(), ~p"/post/not-a-uuid")
      assert response(conn, 404)
    end
  end
end
