defmodule MossletWeb.API.OrgControllerTest do
  use MossletWeb.ConnCase

  import Mosslet.AccountsFixtures

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

  describe "GET /api/orgs" do
    test "returns empty list when user has no orgs", %{conn: conn} do
      conn = get(conn, ~p"/api/orgs")

      assert %{"orgs" => []} = json_response(conn, 200)
    end
  end

  describe "GET /api/orgs/mine" do
    test "returns empty list when user has no orgs", %{conn: conn} do
      conn = get(conn, ~p"/api/orgs/mine")

      assert %{"orgs" => []} = json_response(conn, 200)
    end
  end

  describe "GET /api/org-invitations/mine" do
    test "returns list of user's pending invitations", %{conn: conn} do
      conn = get(conn, ~p"/api/org-invitations/mine")

      assert %{"invitations" => []} = json_response(conn, 200)
    end
  end
end
