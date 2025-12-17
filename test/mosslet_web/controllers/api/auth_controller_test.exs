defmodule MossletWeb.API.AuthControllerTest do
  use MossletWeb.ConnCase

  import Mosslet.AccountsFixtures

  alias Mosslet.API.Token

  @valid_password "hello world hello world!"

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "content-type", "application/json")}
  end

  describe "POST /api/auth/login" do
    test "returns token and user data for valid credentials", %{conn: conn} do
      email = unique_user_email()
      user = user_fixture(%{email: email, password: @valid_password})

      conn =
        post(conn, ~p"/api/auth/login", %{
          email: email,
          password: @valid_password
        })

      assert %{"token" => token, "user" => user_data} = json_response(conn, 200)
      assert is_binary(token)
      assert user_data["id"] == user.id

      {:ok, claims} = Token.verify(token)
      assert claims["sub"] == user.id
    end

    test "returns error for invalid password", %{conn: conn} do
      email = unique_user_email()
      _user = user_fixture(%{email: email, password: @valid_password})

      conn =
        post(conn, ~p"/api/auth/login", %{
          email: email,
          password: "wrong password"
        })

      assert %{"error" => "invalid_credentials"} = json_response(conn, 401)
    end

    test "returns error for non-existent email", %{conn: conn} do
      conn =
        post(conn, ~p"/api/auth/login", %{
          email: "nonexistent@example.com",
          password: @valid_password
        })

      assert %{"error" => "invalid_credentials"} = json_response(conn, 401)
    end
  end

  describe "POST /api/auth/register" do
    test "creates user and returns token", %{conn: conn} do
      email = unique_user_email()
      username = unique_username()

      conn =
        post(conn, ~p"/api/auth/register", %{
          user: %{
            email: email,
            password: @valid_password,
            username: username,
            password_reminder: true
          }
        })

      assert %{"token" => token, "user" => user_data} = json_response(conn, 201)
      assert is_binary(token)
      assert is_binary(user_data["id"])
    end

    test "returns error for invalid params", %{conn: conn} do
      conn =
        post(conn, ~p"/api/auth/register", %{
          user: %{
            email: "invalid",
            password: "short"
          }
        })

      assert %{"error" => "validation_error", "errors" => _errors} = json_response(conn, 422)
    end
  end

  describe "authenticated endpoints" do
    setup %{conn: conn} do
      email = unique_user_email()
      user = user_fixture(%{email: email, password: @valid_password})
      {:ok, session_key} = Mosslet.Accounts.User.valid_key_hash?(user, @valid_password)
      {:ok, token} = Token.generate(user, session_key)

      conn = put_req_header(conn, "authorization", "Bearer #{token}")

      {:ok, conn: conn, user: user, token: token}
    end

    test "GET /api/auth/me returns current user", %{conn: conn, user: user} do
      conn = get(conn, ~p"/api/auth/me")

      assert %{"user" => user_data} = json_response(conn, 200)
      assert user_data["id"] == user.id
    end

    test "POST /api/auth/refresh returns new token", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/refresh")

      assert %{"token" => new_token} = json_response(conn, 200)
      assert is_binary(new_token)
    end

    test "POST /api/auth/logout returns success", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/logout")

      assert %{"message" => _} = json_response(conn, 200)
    end
  end

  describe "unauthorized access" do
    test "returns 401 for missing token", %{conn: conn} do
      conn = get(conn, ~p"/api/auth/me")

      assert %{"error" => "unauthorized"} = json_response(conn, 401)
    end

    test "returns 401 for invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid.token.here")
        |> get(~p"/api/auth/me")

      assert %{"error" => "unauthorized"} = json_response(conn, 401)
    end
  end
end
