defmodule MetamorphicWeb.UserAuth do
  use MetamorphicWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Metamorphic.Accounts
  alias Metamorphic.Memories
  alias Metamorphic.Timeline

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in UserToken.
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_Metamorphic_web_user_remember_me"
  @metamorphic_key_cookie "__Host-_metamorphic_key"
  @remember_me_options [encrypt: true, max_age: @max_age, secure: true, same_site: "Lax"]

  # Checking the route for public routes for the
  # ensure_session_key live_session mount
  @public_list ["Public", "PublicShow", "UserProfileLive", "About", "Privacy"]

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
    token = Accounts.generate_user_session_token(user)
    key = Accounts.User.valid_key_hash?(user, params["password"])
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> put_key_in_session(key)
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect(to: user_return_to || signed_in_path(conn))
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
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
    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      MetamorphicWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/")
  end

  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    user = user_token && Accounts.get_user_by_session_token(user_token)
    assign(conn, :current_user, user)
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, encrypted: [@remember_me_cookie, @metamorphic_key_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, put_token_in_session(conn, token)}
      else
        {nil, conn}
      end
    end
  end

  @doc """
  Handles mounting and authenticating the current_user in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_user` - Assigns current_user
      to socket assigns based on user_token, or nil if
      there's no user_token or no matching user.

    * `:ensure_authenticated` - Authenticates the user from the session,
      and assigns the current_user to socket assigns based
      on user_token.
      Redirects to login page if there's no logged user.

    * `:redirect_if_user_is_authenticated` - Authenticates the user from the session.
      Redirects to signed_in_path if there's a logged user.

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the current_user:

      defmodule MetamorphicWeb.PageLive do
        use MetamorphicWeb, :live_view

        on_mount {MetamorphicWeb.UserAuth, :mount_current_user}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{MetamorphicWeb.UserAuth, :ensure_authenticated}] do
        live "/profile", ProfileLive, :index
      end
  """
  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  def on_mount(:mount_current_user_session_key, _params, session, socket) do
    {:cont, mount_current_user_session_key(socket, session)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket =
      socket
      |> mount_current_user(session)
      |> mount_current_user_session_key(session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/users/log_in")

      {:halt, socket}
    end
  end

  def on_mount(:ensure_confirmed, _params, session, socket) do
    socket =
      socket
      |> mount_current_user(session)
      |> mount_current_user_session_key(session)

    if socket.assigns.current_user.confirmed_at do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(
          :info,
          "Please check your email to confirm your account before accessing this page."
        )
        |> Phoenix.LiveView.redirect(to: ~p"/users/confirm")

      {:halt, socket}
    end
  end

  def on_mount(:ensure_session_key, _params, session, socket) do
    socket =
      socket
      |> mount_current_user(session)
      |> mount_current_user_session_key(session)

    view_list = Atom.to_string(socket.view) |> String.split(".")

    if socket.assigns.current_user && socket.assigns.key do
      {:cont, socket}
    else
      if socket.assigns.current_user do
        socket =
          socket
          |> Phoenix.LiveView.put_flash(
            :info,
            "Your session key has expired, please log in again."
          )
          |> Phoenix.LiveView.redirect(to: ~p"/users/log_in")

        {:halt, socket}
      else
        if Enum.any?(@public_list, fn view -> view in view_list end) do
          {:cont, socket}
        else
          socket =
            socket
            |> Phoenix.LiveView.put_flash(
              :info,
              "Your session key has expired, please log in again."
            )
            |> Phoenix.LiveView.redirect(to: ~p"/users/log_in")

          {:halt, socket}
        end
      end
    end
  end

  def on_mount(:ensure_admin_user, _params, session, socket) do
    socket =
      socket
      |> mount_current_user(session)
      |> mount_current_user_session_key(session)

    if socket.assigns.current_user.is_admin? do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(
          :info,
          "You are not authorized to access this page or it does not exist."
        )
        |> Phoenix.LiveView.redirect(to: ~p"/users/dash")

      {:halt, socket}
    end
  end

  def on_mount(:maybe_ensure_connection, params, session, socket) do
    socket =
      socket
      |> mount_current_user(session)
      |> mount_current_user_session_key(session)

    if params["id"] do
      if socket.assigns.current_user.id == params["id"] do
        {:cont, socket}
      else
        if Accounts.get_user_connection_between_users!(
             params["id"],
             socket.assigns.current_user.id
           ) do
          {:cont, socket}
        else
          socket =
            socket
            |> Phoenix.LiveView.put_flash(
              :info,
              "You do not have permission to view this page or it does not exist."
            )
            |> Phoenix.LiveView.redirect(to: ~p"/users/dash")

          {:halt, socket}
        end
      end
    else
      {:cont, socket}
    end
  end

  def on_mount(:maybe_ensure_private_posts, params, session, socket) do
    socket =
      socket
      |> mount_current_user(session)
      |> mount_current_user_session_key(session)

    info = "You do not have permission to view this page or it does not exist."

    if String.to_atom("Elixir.MetamorphicWeb.PostLive.Show") == socket.view do
      with %Timeline.Post{} = post <- Timeline.get_post(params["id"]),
           true <- post.user_id == socket.assigns.current_user.id do
        {:cont, socket}
      else
        nil ->
          socket =
            socket
            |> Phoenix.LiveView.put_flash(
              :info,
              info
            )
            |> Phoenix.LiveView.redirect(to: ~p"/posts")

          {:halt, socket}

        false ->
          post = Timeline.get_post!(params["id"])

          cond do
            post.visibility == :connections &&
                MetamorphicWeb.Helpers.has_user_connection?(post, socket.assigns.current_user) ->
              {:cont, socket}

            true ->
              socket =
                socket
                |> Phoenix.LiveView.put_flash(
                  :info,
                  info
                )
                |> Phoenix.LiveView.redirect(to: ~p"/posts")

              {:halt, socket}
          end
      end
    else
      {:cont, socket}
    end
  end

  def on_mount(:maybe_ensure_private_memories, params, session, socket) do
    socket =
      socket
      |> mount_current_user(session)
      |> mount_current_user_session_key(session)

    info = "You do not have permission to view this page or it does not exist."

    if String.to_atom("Elixir.MetamorphicWeb.MemoryLive.Show") == socket.view do
      with %Memories.Memory{} = memory <- Memories.get_memory(params["id"]),
           true <- memory.user_id == socket.assigns.current_user.id do
        {:cont, socket}
      else
        nil ->
          socket =
            socket
            |> Phoenix.LiveView.put_flash(
              :info,
              info
            )
            |> Phoenix.LiveView.redirect(to: ~p"/memories")

          {:halt, socket}

        false ->
          memory = Memories.get_memory!(params["id"])

          cond do
            memory.visibility == :connections &&
                MetamorphicWeb.Helpers.has_user_connection?(memory, socket.assigns.current_user) ->
              {:cont, socket}

            true ->
              socket =
                socket
                |> Phoenix.LiveView.put_flash(
                  :info,
                  info
                )
                |> Phoenix.LiveView.redirect(to: ~p"/memories")

              {:halt, socket}
          end
      end
    else
      {:cont, socket}
    end
  end

  def on_mount(:maybe_ensure_private_profile, params, session, socket) do
    socket =
      socket
      |> mount_current_user(session)
      |> mount_current_user_session_key(session)

    info = "You do not have permission to view this page or it does not exist."

    current_user = socket.assigns.current_user

    if String.to_atom("Elixir.MetamorphicWeb.UserProfileLive") == socket.view do
      with %Accounts.User{} = user <- Accounts.get_user_from_profile_slug(params["slug"]),
           %Accounts.Connection.ConnectionProfile{} = profile <-
             Map.get(user.connection, :profile) do
        cond do
          current_user && profile.visibility == :connections &&
              MetamorphicWeb.Helpers.get_uconn_for_users(user, current_user) ->
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

  def on_mount(:ensure_paid_subscription, _params, session, socket) do
    socket =
      socket
      |> mount_current_user(session)
      |> mount_current_user_session_key(session)

    if paid_plan?(socket.assigns.current_user) do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(
          :info,
          "Woops, looks like you need a paid subscription first."
        )
        |> Phoenix.LiveView.redirect(to: ~p"/users/settings")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket =
      socket
      |> mount_current_user(session)
      |> mount_current_user_session_key(session)

    if socket.assigns.current_user do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  defp mount_current_user(socket, session) do
    Phoenix.Component.assign_new(socket, :current_user, fn ->
      if user_token = session["user_token"] do
        Accounts.get_user_by_session_token(user_token)
      end
    end)
  end

  defp mount_current_user_session_key(socket, session) do
    Phoenix.Component.assign_new(socket, :key, fn ->
      if key = session["key"] do
        key
      end
    end)
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/log_in")
      |> halt()
    end
  end

  def require_session_key(conn, _opts) do
    if (conn.assigns[:current_user] && conn.assigns[:key]) || conn.private.plug_session["key"] do
      conn
    else
      conn
      |> put_flash(:info, "Your session key has expired, please log in again.")
      |> log_out_user()
    end
  end

  def maybe_require_connection(conn, _opts) do
    if conn.path_params["id"] do
      if conn.path_params["id"] == conn.assigns.current_user.id do
        conn
      else
        if Accounts.get_user_connection_between_users!(
             conn.path_params["id"],
             conn.assigns.current_user.id
           ) do
          conn
        else
          conn
          |> put_flash(
            :info,
            "You do not have permission to view this page or it does not exist."
          )
          |> redirect(to: ~p"/users/dash")
          |> halt()
        end
      end
    else
      conn
    end
  end

  def maybe_require_private_posts(conn, _opts) do
    info = "You do not have permission to view this page or it does not exist."

    case conn.path_info do
      ["posts", id] ->
        with %Timeline.Post{} = post <- Timeline.get_post(id),
             true <- post.user_id == conn.assigns.current_user.id do
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
              |> redirect(to: ~p"/posts")
              |> halt()
            end

          false ->
            post = Timeline.get_post!(id)

            cond do
              post.visibility == :connections &&
                  MetamorphicWeb.Helpers.has_user_connection?(post, conn.assigns.current_user) ->
                conn

              true ->
                conn
                |> put_flash(
                  :info,
                  info
                )
                |> maybe_store_return_to()
                |> redirect(to: ~p"/posts")
                |> halt()
            end
        end

      _rest ->
        conn
    end
  end

  def require_confirmed_user(conn, _opts) do
    if conn.assigns[:current_user].confirmed_at do
      conn
    else
      conn
      |> put_flash(
        :info,
        "Please check your email to confirm your account before accessing this page."
      )
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/confirm")
      |> halt()
    end
  end

  def require_admin_user(conn, _opts) do
    if conn.assigns[:current_user].is_admin? do
      conn
    else
      conn
      |> put_flash(
        :info,
        "You are not authorized to access this page or it does not exist."
      )
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/dash")
      |> halt()
    end
  end

  def require_paid_subscription(conn, _opts) do
    if paid_plan?(conn.assigns[:current_user]) do
      conn
    else
      conn
      |> put_flash(
        :info,
        "Woops, looks like you need a paid subscription first."
      )
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/settings")
      |> halt()
    end
  end

  defp paid_plan?(current_user) do
    case Bling.Customers.subscribed?(current_user) do
      true ->
        subscription =
          Bling.Customers.subscription(current_user)
          |> Metamorphic.Repo.preload(:subscription_items)

        plan = get_plan_map(subscription)

        cond do
          plan.title == "Starter" ->
            false

          true ->
            true
        end

      false ->
        false
    end
  end

  defp get_plan_map(subscription) do
    subscription_items = Bling.Subscriptions.subscription_items(subscription)

    case Enum.count(subscription_items) do
      1 ->
        Bankroll.plan_from_price_id(List.first(subscription_items).stripe_price_id)

      _rest ->
        nil
    end
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

  defp signed_in_path(_conn), do: ~p"/users/dash"
end
