defmodule MossletWeb.UserAuthTest do
  use MossletWeb.ConnCase, async: true

  alias Phoenix.LiveView
  alias Mosslet.Accounts
  alias MossletWeb.UserAuth
  import Mosslet.AccountsFixtures

  @remember_me_cookie "_mosslet_web_user_remember_me"
  @valid_email "validtest@example.com"
  @valid_password "hello world hello world!"

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, MossletWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{
      user: user_fixture(%{email: @valid_email, password: @valid_password}),
      conn: conn,
      params: %{"email" => @valid_email, "password" => @valid_password}
    }
  end

  describe "log_in_user/3" do
    test "stores the user token in the session", %{conn: conn, user: user, params: params} do
      {:ok, user} = Accounts.update_user_onboarding(user, %{is_onboarded?: true})
      conn = UserAuth.log_in_user(conn, user, params)
      assert token = get_session(conn, :user_token)
      assert get_session(conn, :live_socket_id) == "users_sessions:#{Base.url_encode64(token)}"
      assert redirected_to(conn) == ~p"/app"
      assert Accounts.get_user_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{
      conn: conn,
      user: user,
      params: params
    } do
      conn = conn |> put_session(:to_be_removed, "value") |> UserAuth.log_in_user(user, params)
      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, user: user, params: params} do
      {:ok, user} = Accounts.update_user_onboarding(user, %{is_onboarded?: true})
      conn = conn |> put_session(:user_return_to, "/hello") |> UserAuth.log_in_user(user, params)
      assert redirected_to(conn) == "/hello"
    end

    test "writes a cookie if remember_me is configured", %{conn: conn, user: user, params: params} do
      params = Map.put(params, "remember_me", "true")
      conn = conn |> fetch_cookies() |> UserAuth.log_in_user(user, params)
      assert get_session(conn, :user_token) == conn.cookies[@remember_me_cookie]

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :user_token)
      assert max_age == 5_184_000
    end
  end

  describe "logout_user/1" do
    test "erases session and cookies", %{conn: conn, user: user, params: params} do
      user_token = Accounts.generate_user_session_token(user)

      key =
        case Accounts.User.valid_key_hash?(user, params["password"]) do
          {:ok, key} ->
            key

          {:error, _} ->
            nil
        end

      conn =
        conn
        |> put_session(:user_token, user_token)
        |> put_session(:key, key)
        |> put_req_cookie(@remember_me_cookie, user_token)
        |> fetch_cookies()
        |> UserAuth.log_out_user()

      refute get_session(conn, :user_token)
      refute get_session(conn, :key)
      refute conn.cookies[@remember_me_cookie]
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
      refute Accounts.get_user_by_session_token(user_token)
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "users_sessions:abcdef-token"
      MossletWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> UserAuth.log_out_user()

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^live_socket_id}
    end

    test "works even if user is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> UserAuth.log_out_user()
      refute get_session(conn, :user_token)
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "fetch_current_user/2" do
    test "authenticates user from session", %{conn: conn, user: user} do
      user_token = Accounts.generate_user_session_token(user)
      conn = conn |> put_session(:user_token, user_token) |> UserAuth.fetch_current_user([])
      assert conn.assigns.current_user.id == user.id
    end

    test "authenticates user from cookies", %{conn: conn, user: user, params: params} do
      params = Map.put(params, "remember_me", "true")

      logged_in_conn =
        conn |> fetch_cookies() |> UserAuth.log_in_user(user, params)

      user_token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      conn =
        conn
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> UserAuth.fetch_current_user([])

      assert conn.assigns.current_user.id == user.id
      assert get_session(conn, :user_token) == user_token

      assert get_session(conn, :live_socket_id) ==
               "users_sessions:#{Base.url_encode64(user_token)}"
    end

    test "does not authenticate if data is missing", %{conn: conn, user: user} do
      _ = Accounts.generate_user_session_token(user)
      conn = UserAuth.fetch_current_user(conn, [])
      refute get_session(conn, :user_token)
      refute conn.assigns.current_user
    end
  end

  describe "on_mount: mount_current_user" do
    test "assigns current_user based on a valid user_token", %{conn: conn, user: user} do
      user_token = Accounts.generate_user_session_token(user)
      session = conn |> put_session(:user_token, user_token) |> get_session()

      {:cont, updated_socket} =
        UserAuth.on_mount(:mount_current_user, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_user.id == user.id
    end

    test "assigns nil to current_user assign if there isn't a valid user_token", %{conn: conn} do
      user_token = "invalid_token"
      session = conn |> put_session(:user_token, user_token) |> get_session()

      {:cont, updated_socket} =
        UserAuth.on_mount(:mount_current_user, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_user == nil
    end

    test "assigns nil to current_user assign if there isn't a user_token", %{conn: conn} do
      session = conn |> get_session()

      {:cont, updated_socket} =
        UserAuth.on_mount(:mount_current_user, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_user == nil
    end
  end

  describe "on_mount: ensure_authenticated" do
    test "authenticates current_user based on a valid user_token", %{conn: conn, user: user} do
      user_token = Accounts.generate_user_session_token(user)
      session = conn |> put_session(:user_token, user_token) |> get_session()

      {:cont, updated_socket} =
        UserAuth.on_mount(:ensure_authenticated, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_user.id == user.id
    end

    test "redirects to login page if there isn't a valid user_token", %{conn: conn} do
      user_token = "invalid_token"
      session = conn |> put_session(:user_token, user_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: MossletWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = UserAuth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_user == nil
    end

    test "redirects to login page if there isn't a user_token", %{conn: conn} do
      session = conn |> get_session()

      socket = %LiveView.Socket{
        endpoint: MossletWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = UserAuth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_user == nil
    end
  end

  describe "on_mount: :redirect_if_user_is_authenticated" do
    test "redirects if there is an authenticated  user ", %{conn: conn, user: user} do
      user_token = Accounts.generate_user_session_token(user)

      session =
        conn
        |> put_session(:user_token, user_token)
        |> put_session(:key, "test_key")
        |> get_session()

      assert {:halt, _updated_socket} =
               UserAuth.on_mount(
                 :redirect_if_user_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end

    test "doesn't redirect if there is no authenticated user", %{conn: conn} do
      session = conn |> get_session()

      assert {:cont, _updated_socket} =
               UserAuth.on_mount(
                 :redirect_if_user_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end
  end

  describe "redirect_if_user_is_authenticated/2" do
    test "redirects if user is authenticated and not onboarded", %{conn: conn, user: user} do
      conn =
        conn
        |> assign(:current_user, user)
        |> assign(:key, "test_key")
        |> UserAuth.redirect_if_user_is_authenticated([])

      assert conn.halted
      assert redirected_to(conn) == ~p"/app/users/onboarding"
    end

    test "redirects if user is authenticated and onboarded", %{conn: conn, user: user} do
      {:ok, user} = Accounts.update_user_onboarding(user, %{is_onboarded?: true})

      conn =
        conn
        |> assign(:current_user, user)
        |> assign(:key, "test_key")
        |> UserAuth.redirect_if_user_is_authenticated([])

      assert conn.halted
      assert redirected_to(conn) == ~p"/app"
    end

    test "does not redirect if user is not authenticated", %{conn: conn} do
      conn = UserAuth.redirect_if_user_is_authenticated(conn, [])
      refute conn.halted
      refute conn.status
    end
  end

  describe "require_authenticated_user/2" do
    test "redirects if user is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> UserAuth.require_authenticated_user([])
      assert conn.halted

      assert redirected_to(conn) == ~p"/auth/sign_in"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "You must log in to access this page."
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | path_info: ["foo"], query_string: ""}
        |> fetch_flash()
        |> UserAuth.require_authenticated_user([])

      assert halted_conn.halted
      assert get_session(halted_conn, :user_return_to) == "/foo"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> UserAuth.require_authenticated_user([])

      assert halted_conn.halted
      assert get_session(halted_conn, :user_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
        |> fetch_flash()
        |> UserAuth.require_authenticated_user([])

      assert halted_conn.halted
      refute get_session(halted_conn, :user_return_to)
    end

    test "does not redirect if user is authenticated", %{conn: conn, user: user} do
      conn = conn |> assign(:current_user, user) |> UserAuth.require_authenticated_user([])
      refute conn.halted
      refute conn.status
    end
  end
end
