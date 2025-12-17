defmodule MossletWeb.API.SyncControllerTest do
  use MossletWeb.ConnCase

  import Mosslet.AccountsFixtures

  alias Mosslet.API.Token

  @valid_password "hello world hello world!"

  setup %{conn: conn} do
    email = unique_user_email()
    user = user_fixture(%{email: email, password: @valid_password})
    {:ok, session_key} = Mosslet.Accounts.User.valid_key_hash?(user, @valid_password)
    {:ok, token} = Token.generate(user, session_key)

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    {:ok, conn: conn, user: user, session_key: session_key}
  end

  describe "GET /api/sync/user" do
    test "returns user data", %{conn: conn, user: user} do
      conn = get(conn, ~p"/api/sync/user")

      assert %{"user" => user_data, "synced_at" => _} = json_response(conn, 200)
      assert user_data["id"] == user.id
      assert is_binary(user_data["key_pair"]["public"])
    end
  end

  describe "GET /api/sync/posts" do
    test "returns empty list when no posts", %{conn: conn} do
      conn = get(conn, ~p"/api/sync/posts")

      assert %{"posts" => posts, "synced_at" => _, "has_more" => false} = json_response(conn, 200)
      assert posts == []
    end

    test "supports since parameter", %{conn: conn} do
      since = DateTime.utc_now() |> DateTime.to_iso8601()
      conn = get(conn, ~p"/api/sync/posts?since=#{since}")

      assert %{"posts" => _, "synced_at" => _} = json_response(conn, 200)
    end

    test "supports limit parameter", %{conn: conn} do
      conn = get(conn, ~p"/api/sync/posts?limit=10")

      assert %{"posts" => _} = json_response(conn, 200)
    end
  end

  describe "GET /api/sync/connections" do
    test "returns empty list when no connections", %{conn: conn} do
      conn = get(conn, ~p"/api/sync/connections")

      assert %{"connections" => connections, "synced_at" => _} = json_response(conn, 200)
      assert connections == []
    end
  end

  describe "GET /api/sync/groups" do
    test "returns empty list when no groups", %{conn: conn} do
      conn = get(conn, ~p"/api/sync/groups")

      assert %{"groups" => groups, "synced_at" => _} = json_response(conn, 200)
      assert groups == []
    end
  end

  describe "GET /api/sync/full" do
    test "returns all sync data", %{conn: conn, user: user} do
      conn = get(conn, ~p"/api/sync/full")

      assert %{
               "user" => user_data,
               "posts" => _posts,
               "connections" => _connections,
               "groups" => _groups,
               "synced_at" => _
             } = json_response(conn, 200)

      assert user_data["id"] == user.id
    end
  end
end
