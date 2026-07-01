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

  describe "POST /api/auth/salt (board #370)" do
    defp enroll_device(user) do
      {:ok, user} =
        Mosslet.Accounts.setup_recovery_key(user, "recovery-secret-256bit", "enc-recovery-blob")

      {:ok, _} =
        Mosslet.Accounts.backfill_password_wrap(user, %{
          wrapped_user_key: "opaque-pw-blob",
          wrap_salt: "cGFzc3NhbHQ="
        })

      {:ok, _} =
        Mosslet.Accounts.enroll_prf_wrap(
          user,
          %{
            wrapped_user_key: "opaque-prf-blob",
            wrap_salt: "cHJmc2FsdA==",
            credential_id: "cred-abc",
            prf_salt: "cHJmZXZhbA=="
          },
          Mosslet.Accounts.sign_recovery_confirmation(user)
        )

      user
    end

    test "non-enrolled user gets their real key_hash and enrolled:false", %{conn: conn} do
      email = unique_user_email()
      user = user_fixture(%{email: email, password: @valid_password})

      conn = post(conn, ~p"/api/auth/salt", %{email: email})
      assert %{"key_hash" => key_hash, "prf" => prf} = json_response(conn, 200)

      assert key_hash == user.key_hash
      assert String.contains?(key_hash, "$")
      assert prf == %{"enrolled" => false, "wraps" => []}
    end

    test "enrolled user exposes NO usable password door (fake key_hash) but real prf wraps", %{
      conn: conn
    } do
      email = unique_user_email()
      user = user_fixture(%{email: email, password: @valid_password})
      real_key_hash = user.key_hash
      enroll_device(user)

      conn = post(conn, ~p"/api/auth/salt", %{email: email})
      assert %{"key_hash" => key_hash, "prf" => prf} = json_response(conn, 200)

      # The served key_hash is a timing-consistent fake, NOT the (now blanked)
      # real one — the human-password brute-force door is gone.
      assert key_hash != real_key_hash
      assert String.contains?(key_hash, "$")

      assert %{"enrolled" => true, "wraps" => [wrap]} = prf
      assert wrap["credential_id"] == "cred-abc"
      assert wrap["wrapped_user_key"] == "opaque-prf-blob"
    end

    test "un-enrolling the last device makes salt serve a real key_hash again", %{conn: conn} do
      email = unique_user_email()
      user = user_fixture(%{email: email, password: @valid_password})
      enroll_device(user)

      [prf] = Enum.filter(Mosslet.Accounts.list_user_key_wraps(user), &(&1.kind == :prf))

      {:ok, :unenrolled} =
        Mosslet.Accounts.unenroll_prf_wrap(user, prf.id, %{
          wrapped_user_key: "restored-pw-blob",
          wrap_salt: "cmVzdG9yZQ=="
        })

      conn = post(conn, ~p"/api/auth/salt", %{email: email})
      assert %{"key_hash" => key_hash, "prf" => %{"enrolled" => false}} = json_response(conn, 200)
      assert key_hash == "cmVzdG9yZQ==$restored-pw-blob"
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
