defmodule MossletWeb.UserAuth do
  @moduledoc false
  use MossletWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller
  use Gettext, backend: MossletWeb.Gettext

  alias Mosslet.Accounts
  alias Mosslet.Accounts.Scope
  alias Mosslet.Timeline

  alias Mosslet.Repo

  require Logger

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in UserToken.
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_mosslet_web_user_remember_me"
  @remember_me_options (if(Mix.env() === :dev) do
                          [encrypt: true, max_age: @max_age, same_site: "Lax"]
                        else
                          [encrypt: true, max_age: @max_age, secure: true, same_site: "Lax"]
                        end)

  # Checking the route for public routes for the
  # ensure_session_key live_session mount
  @public_list [
    "HomeLive",
    "Public",
    "PublicShow",
    "PublicProfileLive",
    "UserHomeLive",
    "Ai",
    "About",
    "Blog",
    "Download",
    "Faq",
    "Support",
    "Pricing",
    "Privacy",
    "Terms",
    "Features",
    "Updates",
    "Referrals",
    "PublicTimeline"
  ]

  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  def log_in_user(conn, %{is_suspended?: false, is_deleted?: false} = user, params) do
    user_return_to =
      get_session(conn, "user_return_to") || maybe_redirect_to_org_invitations(user)

    params = Map.put(params, "user_return_to", user_return_to)

    conn = put_user_into_session(conn, user, params)
    Accounts.UserPin.purge_pins(user)

    # If the user has set up 2FA then we need to redirect to the 2FA page for them to enter their code.
    if Accounts.two_factor_auth_enabled?(user) do
      conn
      |> put_session(:user_totp_pending, true)
      |> put_flash(:info, nil)
      |> redirect(to: ~p"/app/users/totp?#{[user: Map.take(params, ["remember_me"])]}")
    else
      redirect_user_after_login_with_remember_me(conn, user, params)
    end
  end

  @doc "This is what makes a user 'signed in'. Future requests will have user_token in the session and we fetch the current_user based off this. This also puts the user key into their session as well (the session is encrypted)."
  def put_user_into_session(conn, user, params) do
    token = Accounts.generate_user_session_token(user)

    key =
      case Accounts.User.valid_key_hash?(user, params["password"]) do
        {:ok, key} ->
          key

        {:error, _} ->
          nil
      end

    Accounts.user_lifecycle_action("after_sign_in", user, %{ip: get_ip(conn), key: key})

    conn
    |> renew_session()
    |> put_session(:user_token, token)
    |> put_session(:user_return_to, params["user_return_to"])
    |> put_token_in_session(token)
    |> put_key_in_session(key)
  end

  @doc """
  Returns to or redirects home and potentially set remember_me token. If the
  user has not been onboarded, then they are redirected to the onboarding page.
  """
  def redirect_user_after_login_with_remember_me(conn, user, params \\ %{}) do
    user_return_to =
      get_session(conn, "user_return_to") || maybe_redirect_to_org_invitations(user)

    conn =
      conn
      |> maybe_write_remember_me_cookie(params)
      |> delete_session(:user_return_to)

    if user.is_onboarded? do
      redirect(conn, to: user_return_to || signed_in_path(user))
    else
      redirect(conn, to: ~p"/app/users/onboarding")
    end
  end

  defp maybe_write_remember_me_cookie(conn, %{"remember_me" => "true"}) do
    token = get_session(conn, :user_token)
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _params) do
    conn
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user = if user_token, do: Accounts.get_user_by_session_token(user_token)
    # update user's presence to :offline if :auto_status true
    # Force status to offline during logout (bypass presence check)
    if user && user.auto_status do
      Mosslet.Statuses.update_user_status(user, %{status: :offline}, auto_update: true)
    end

    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      MossletWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/")
  end

  @doc """
  Deletes the user's session and forces all live views to reconnect (logging them out fully)
  """
  def log_out_another_user(user) do
    users_tokens = user |> Accounts.UserToken.user_and_contexts_query(["session"]) |> Repo.all()
    disconnect_user_tokens(users_tokens, true)
  end

  @doc """
  Forces all live views to reconnect for a user. Useful if their permissions have changed (eg. no longer an org member).
  """
  def disconnect_user_liveviews(user) do
    users_tokens = user |> Accounts.UserToken.user_and_contexts_query(["session"]) |> Repo.all()
    disconnect_user_tokens(users_tokens)
  end

  defp disconnect_user_tokens(users_tokens, delete_too? \\ false) do
    for user_token <- users_tokens do
      MossletWeb.Endpoint.broadcast(user_session_topic(user_token.token), "disconnect", %{})
      delete_too? && Accounts.delete_user_session_token(user_token.token)
    end
  end

  def user_session_topic(token), do: "users_sessions:#{Base.url_encode64(token)}"

  @doc """
  Authenticates the user by looking into the session
  and remember me token. Assigns `current_scope` with the user and key.

  Also assigns `current_user` and `key` for backwards compatibility during migration.
  """
  def fetch_current_scope(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    user = if user_token, do: Accounts.get_user_by_session_token(user_token), else: nil
    key = get_session(conn, :key)
    scope = Scope.for_user(user, key: key)

    conn
    |> assign(:current_scope, scope)
    |> assign(:current_user, user)
    |> assign(:key, key)
  end

  @doc false
  @deprecated "Use fetch_current_scope/2 instead"
  def fetch_current_user(conn, opts), do: fetch_current_scope(conn, opts)

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      # Only fetch the remember_me_cookie since that's all we need here
      conn = fetch_cookies(conn, encrypted: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        # Validate that the token corresponds to a valid user session before adding it to the session
        if _user = Accounts.get_user_by_session_token(token) do
          # Token is valid and corresponds to an existing user
          {token, put_token_in_session(conn, token)}
        else
          # Token is invalid or has been revoked, clear the cookie
          {nil, delete_resp_cookie(conn, @remember_me_cookie)}
        end
      else
        {nil, conn}
      end
    end
  end

  @doc """
  Handles mounting and authenticating the current_scope in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_scope` - Assigns current_scope (and current_user/key for compat)
      to socket assigns based on user_token, or nil if there's no user_token or no
      matching user.

    * `:ensure_authenticated` - Authenticates the user from the session,
      and assigns the current_scope to socket assigns based on user_token.
      Redirects to login page if there's no logged user.

    * `:redirect_if_user_is_authenticated` - Authenticates the user from the session.
      Redirects to signed_in_path if there's a logged user.

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the current_scope:

      defmodule MossletWeb.PageLive do
        use MossletWeb, :live_view

        on_mount {MossletWeb.UserAuth, :mount_current_scope}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{MossletWeb.UserAuth, :ensure_authenticated}] do
        live "/home", HomeLive, :index
      end
  """
  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:mount_current_user_session_key, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if session["user_totp_pending"] do
      socket =
        Phoenix.LiveView.redirect(socket, to: ~p"/app/users/totp")

      {:halt, socket}
    else
      if socket.assigns.current_scope && socket.assigns.current_scope.user do
        {:cont, socket}
      else
        socket =
          socket
          |> Phoenix.LiveView.put_flash(:info, "You must log in to access this page.")
          |> Phoenix.LiveView.redirect(to: ~p"/auth/sign_in")

        {:halt, socket}
      end
    end
  end

  def on_mount(:ensure_confirmed, _params, session, socket) do
    socket = mount_current_scope(socket, session)
    scope = socket.assigns.current_scope

    cond do
      is_nil(scope) or is_nil(scope.user) ->
        socket =
          socket
          |> Phoenix.LiveView.put_flash(:info, "You must log in to access this page.")
          |> Phoenix.LiveView.redirect(to: ~p"/auth/sign_in")

        {:halt, socket}

      scope.user.confirmed_at ->
        {:cont, socket}

      true ->
        socket =
          socket
          |> Phoenix.LiveView.put_flash(
            :info,
            "Please check your email to confirm your account before accessing this page."
          )
          |> Phoenix.LiveView.redirect(to: ~p"/auth/confirm")

        {:halt, socket}
    end
  end

  def on_mount(:ensure_session_key, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    view_list = Atom.to_string(socket.view) |> String.split(".")

    if Enum.any?(@public_list, fn view -> view in view_list end) do
      {:cont, socket}
    else
      scope = socket.assigns.current_scope

      cond do
        scope && scope.user && scope.key ->
          {:cont, socket}

        scope && scope.user && !scope.key ->
          socket =
            socket
            |> Phoenix.LiveView.put_flash(
              :info,
              "Please enter your password to unlock your session."
            )
            |> Phoenix.LiveView.redirect(to: ~p"/auth/unlock")

          {:halt, socket}

        true ->
          socket =
            socket
            |> Phoenix.LiveView.put_flash(
              :info,
              "You must log in to access this page."
            )
            |> Phoenix.LiveView.redirect(to: ~p"/auth/sign_in")

          {:halt, socket}
      end
    end
  end

  def on_mount(:ensure_admin_user, _params, session, socket) do
    socket = mount_current_scope(socket, session)
    scope = socket.assigns.current_scope

    cond do
      is_nil(scope) or is_nil(scope.user) ->
        socket =
          socket
          |> Phoenix.LiveView.put_flash(:info, "You must log in to access this page.")
          |> Phoenix.LiveView.redirect(to: ~p"/auth/sign_in")

        {:halt, socket}

      scope.user.is_admin? ->
        {:cont, socket}

      true ->
        socket =
          socket
          |> Phoenix.LiveView.put_flash(
            :info,
            "You are not authorized to access this page or it does not exist."
          )
          |> Phoenix.LiveView.redirect(to: ~p"/app")

        {:halt, socket}
    end
  end

  def on_mount(:maybe_ensure_connection, params, session, socket) do
    socket = mount_current_scope(socket, session)
    scope = socket.assigns.current_scope

    if is_nil(scope) or is_nil(scope.user) do
      {:cont, socket}
    else
      user = scope.user

      if params["id"] &&
           String.to_existing_atom("Elixir.MossletWeb.UserConnectionLive.Show") == socket.view do
        if user.id == params["id"] do
          {:cont, socket}
        else
          if Accounts.validate_users_in_connection(params["id"], user.id) do
            {:cont, socket}
          else
            socket =
              socket
              |> Phoenix.LiveView.put_flash(
                :info,
                "You do not have permission to view this page or it does not exist."
              )
              |> Phoenix.LiveView.redirect(to: ~p"/app")

            {:halt, socket}
          end
        end
      else
        {:cont, socket}
      end
    end
  end

  def on_mount(:maybe_ensure_private_posts, params, session, socket) do
    socket = mount_current_scope(socket, session)
    scope = socket.assigns.current_scope

    if is_nil(scope) or is_nil(scope.user) do
      {:cont, socket}
    else
      user = scope.user
      info = "You do not have permission to view this page or it does not exist."

      if String.to_existing_atom("Elixir.MossletWeb.PostLive.Show") == socket.view do
        with %Timeline.Post{} = post <- Timeline.get_post(params["id"]),
             true <- post.user_id == user.id do
          {:cont, socket}
        else
          nil ->
            socket =
              socket
              |> Phoenix.LiveView.put_flash(
                :info,
                info
              )
              |> Phoenix.LiveView.redirect(to: ~p"/app/timeline")

            {:halt, socket}

          false ->
            post = Timeline.get_post!(params["id"])

            cond do
              post.visibility == :connections &&
                  MossletWeb.Helpers.has_user_connection?(post, user) ->
                {:cont, socket}

              true ->
                socket =
                  socket
                  |> Phoenix.LiveView.put_flash(
                    :info,
                    info
                  )
                  |> Phoenix.LiveView.redirect(to: ~p"/app/timeline")

                {:halt, socket}
            end
        end
      else
        {:cont, socket}
      end
    end
  end

  def on_mount(:maybe_ensure_private_profile, params, session, socket) do
    socket = mount_current_scope(socket, session)
    current_user = socket.assigns.current_scope && socket.assigns.current_scope.user

    info = "You do not have permission to view this page or it does not exist."

    if String.to_existing_atom("Elixir.MossletWeb.UserHomeLive") == socket.view do
      with %Accounts.User{} = user <- Accounts.get_user_from_profile_slug(params["slug"]),
           %Accounts.Connection.ConnectionProfile{} = profile <-
             Map.get(user.connection, :profile) do
        cond do
          current_user && profile.visibility == :connections &&
              MossletWeb.Helpers.get_uconn_for_users(user, current_user) ->
            {:cont, socket}

          current_user && profile.visibility == :connections && user.id == current_user.id ->
            {:cont, socket}

          current_user && profile.visibility == :private && user.id == current_user.id ->
            {:cont, socket}

          profile.visibility == :public ->
            {:cont, socket}

          true ->
            socket =
              socket
              |> Phoenix.LiveView.put_flash(
                :info,
                info
              )
              |> Phoenix.LiveView.redirect(to: ~p"/")

            {:halt, socket}
        end
      else
        nil ->
          socket =
            socket
            |> Phoenix.LiveView.put_flash(
              :info,
              info
            )
            |> Phoenix.LiveView.redirect(to: ~p"/")

          {:halt, socket}

        false ->
          socket =
            socket
            |> Phoenix.LiveView.put_flash(
              :info,
              info
            )
            |> Phoenix.LiveView.redirect(to: ~p"/")

          {:halt, socket}
      end
    else
      {:cont, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    totp_pending = session["user_totp_pending"]
    socket = mount_current_scope(socket, session)
    scope = socket.assigns.current_scope

    if scope && scope.user && scope.key && !totp_pending do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(scope.user))}
    else
      if scope && scope.user && scope.key && totp_pending do
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/app/users/totp")}
      else
        {:cont, socket}
      end
    end
  end

  defp mount_current_scope(socket, session) do
    socket
    |> Phoenix.Component.assign_new(:current_user, fn ->
      if user_token = session["user_token"] do
        Accounts.get_user_by_session_token(user_token)
      end
    end)
    |> Phoenix.Component.assign_new(:key, fn -> session["key"] end)
    |> then(fn socket ->
      Phoenix.Component.assign_new(socket, :current_scope, fn ->
        Scope.for_user(socket.assigns.current_user, key: socket.assigns.key)
      end)
    end)
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    totp_pending = get_session(conn, :user_totp_pending)
    scope = conn.assigns[:current_scope]
    user = scope && scope.user

    if user && scope.key && !totp_pending do
      conn
      |> redirect(to: signed_in_path(user))
      |> halt()
    else
      if user && scope.key && totp_pending do
        conn
        |> redirect(to: ~p"/app/users/totp")
        |> halt()
      else
        conn
      end
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  Requires that the user email is confirmed.
  """
  def require_authenticated_user(conn, _opts) do
    scope = conn.assigns[:current_scope]
    user = scope && scope.user

    if get_session(conn, :user_totp_pending) && conn.request_path != "/app/users/totp" do
      conn
      |> redirect(to: "/app/users/totp")
      |> halt()
    else
      if user do
        conn
      else
        conn
        |> put_flash(:info, "You must log in to access this page.")
        |> maybe_store_return_to()
        |> redirect(to: ~p"/auth/sign_in")
        |> halt()
      end
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  Does not require the user to be confirmed by their email.
  """
  def require_authenticated_user_not_confirmed(conn, _opts) do
    scope = conn.assigns[:current_scope]
    user = scope && scope.user

    if user do
      conn
    else
      conn
      |> put_flash(:info, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/auth/sign_in")
      |> halt()
    end
  end

  def require_session_key(conn, _opts) do
    scope = conn.assigns[:current_scope]
    user = scope && scope.user

    if user && conn.private.plug_session["key"] do
      conn
    else
      cond do
        user ->
          conn
          |> put_flash(
            :info,
            "Please enter your password to unlock your session."
          )
          |> redirect(to: ~p"/auth/unlock")
          |> halt()

        true ->
          conn
          |> put_flash(:info, "Your session key has expired, please log in again.")
          |> log_out_user()
      end
    end
  end

  def maybe_require_connection(conn, _opts) do
    scope = conn.assigns[:current_scope]
    user = scope && scope.user

    paths_requiring_connection_check = [
      "connections",
      "posts",
      "memories",
      "groups"
    ]

    path_requires_check =
      case conn.path_info do
        ["app" | [segment | _]] -> segment in paths_requiring_connection_check
        _ -> false
      end

    if path_requires_check && conn.path_params["id"] do
      if conn.path_params["id"] == user.id do
        conn
      else
        if Accounts.get_user_connection_between_users!(
             conn.path_params["id"],
             user.id
           ) do
          conn
        else
          conn
          |> put_flash(
            :info,
            "You do not have permission to view this page or it does not exist."
          )
          |> redirect(to: ~p"/app")
          |> halt()
        end
      end
    else
      conn
    end
  end

  def maybe_require_private_posts(conn, _opts) do
    scope = conn.assigns[:current_scope]
    user = scope && scope.user
    info = "You do not have permission to view this page or it does not exist."

    case conn.path_info do
      ["posts", id] ->
        with %Timeline.Post{} = post <- Timeline.get_post(id),
             true <- post.user_id == user.id do
          conn
        else
          nil ->
            if :new == id || "new" == id do
              conn
            else
              conn
              |> put_flash(
                :info,
                info
              )
              |> maybe_store_return_to()
              |> redirect(to: ~p"/app/timeline")
              |> halt()
            end

          false ->
            post = Timeline.get_post!(id)

            cond do
              post.visibility == :connections &&
                  MossletWeb.Helpers.has_user_connection?(post, user) ->
                conn

              true ->
                conn
                |> put_flash(
                  :info,
                  info
                )
                |> maybe_store_return_to()
                |> redirect(to: ~p"/app/timeline")
                |> halt()
            end
        end

      _rest ->
        conn
    end
  end

  def require_confirmed_user(conn, _opts) do
    scope = conn.assigns[:current_scope]
    user = scope && scope.user

    if user && user.confirmed_at do
      conn
    else
      conn
      |> put_flash(
        :info,
        "Please check your email to confirm your account before accessing this page."
      )
      |> maybe_store_return_to()
      |> redirect(to: ~p"/auth/confirm")
      |> halt()
    end
  end

  def require_admin_user(conn, _opts) do
    scope = conn.assigns[:current_scope]
    user = scope && scope.user

    if user && user.is_admin? && user.confirmed_at do
      conn
    else
      conn
      |> put_flash(
        :info,
        "You are not authorized to access this page or it does not exist."
      )
      |> maybe_store_return_to()
      |> redirect(to: ~p"/app")
      |> halt()
    end
  end

  def kick_user_if_suspended_or_deleted(conn, opts \\ []) do
    current_scope = conn.assigns[:current_scope]

    if not is_nil(current_scope) and not is_nil(current_scope.user) and
         (current_scope.user.is_suspended? or current_scope.user.is_deleted?) do
      conn
      |> put_flash(
        :error,
        Keyword.get(opts, :flash, gettext("Your account is not accessible."))
      )
      |> log_out_user()
      |> halt()
    else
      conn
    end
  end

  def maybe_redirect_to_org_invitations(current_user) do
    invitations = Mosslet.Orgs.list_invitations_by_user(current_user)

    if Enum.any?(invitations),
      do: ~p"/app/users/org-invitations"
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
  end

  defp put_key_in_session(conn, key) do
    conn
    |> put_session(:key, key)
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(user) do
    if user.is_onboarded? do
      ~p"/app"
    else
      ~p"/app/users/onboarding"
    end
  end

  def get_ip(conn) do
    # When behind a load balancer, the client ip is provided in the x-forwarded-for header
    # examples:
    # X-Forwarded-For: 2001:db8:85a3:8d3:1319:8a2e:370:7348
    # X-Forwarded-For: 203.0.113.195
    # X-Forwarded-For: 203.0.113.195, 70.41.3.18, 150.172.238.178
    forwarded_for = List.first(Plug.Conn.get_req_header(conn, "x-forwarded-for"))

    if forwarded_for do
      forwarded_for
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> List.first()
    else
      to_string(:inet_parse.ntoa(conn.remote_ip))
    end
  end
end
