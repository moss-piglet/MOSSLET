defmodule MossletWeb.API.ConversationControllerTest do
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

  describe "GET /api/conversations" do
    test "returns list of user's conversations", %{conn: conn} do
      conn = get(conn, ~p"/api/conversations")

      assert %{"conversations" => []} = json_response(conn, 200)
    end
  end

  describe "GET /api/conversations/:id" do
    test "returns 404 for non-existent conversation", %{conn: conn} do
      conn = get(conn, ~p"/api/conversations/#{Ecto.UUID.generate()}")

      assert json_response(conn, 404)
    end
  end
end
