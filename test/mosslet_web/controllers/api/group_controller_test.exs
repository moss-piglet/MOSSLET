defmodule MossletWeb.API.GroupControllerTest do
  use MossletWeb.ConnCase

  import Mosslet.AccountsFixtures
  import Mosslet.GroupsFixtures

  alias Mosslet.API.Token

  @valid_password "hello world hello world!"

  setup %{conn: conn} do
    conn = put_req_header(conn, "content-type", "application/json")
    user = user_fixture(%{password: @valid_password})
    {:ok, session_key} = Mosslet.Accounts.User.valid_key_hash?(user, @valid_password)
    {:ok, token} = Token.generate(user, session_key)
    conn = put_req_header(conn, "authorization", "Bearer #{token}")

    {:ok, conn: conn, user: user, session_key: session_key}
  end

  describe "GET /api/groups" do
    test "returns empty list when user has no groups", %{conn: conn} do
      conn = get(conn, ~p"/api/groups")

      assert %{"groups" => []} = json_response(conn, 200)
    end
  end

  describe "GET /api/groups/:id" do
    test "returns 404 for non-existent group", %{conn: conn} do
      conn = get(conn, ~p"/api/groups/#{Ecto.UUID.generate()}")

      assert json_response(conn, 404)
    end
  end

  describe "GET /api/groups/count" do
    test "returns zero counts for new user", %{conn: conn} do
      conn = get(conn, ~p"/api/groups/count")

      assert %{"total" => 0, "confirmed" => 0} = json_response(conn, 200)
    end
  end

  describe "GET /api/groups/unconfirmed" do
    test "returns empty list for new user", %{conn: conn} do
      conn = get(conn, ~p"/api/groups/unconfirmed")

      assert %{"groups" => []} = json_response(conn, 200)
    end
  end

  describe "GET /api/groups/public" do
    test "returns list of public groups", %{conn: conn} do
      conn = get(conn, ~p"/api/groups/public")

      assert %{"groups" => _, "count" => _} = json_response(conn, 200)
    end
  end
end
