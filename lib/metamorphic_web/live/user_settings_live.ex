defmodule MetamorphicWeb.UserSettingsLive do
  use MetamorphicWeb, :live_view

  alias Metamorphic.Accounts
  alias Metamorphic.Encrypted
  alias Metamorphic.Encrypted.Users.Utils
  alias Metamorphic.Extensions.AvatarProcessor

  def mount(%{"token" => token}, %{"key" => key} = _session, socket) do
    user = socket.assigns.current_user
    email = Utils.decrypt_user_data(user.email, user, key)

    socket =
      case Accounts.update_user_email(user, email, token, key) do
        :ok ->
          put_flash(socket, :success, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password(user)
    name_changeset = Accounts.change_user_name(user)
    username_changeset = Accounts.change_user_username(user)
    visibility_changeset = Accounts.change_user_visibility(user)
    forgot_password_changeset = Accounts.change_user_forgot_password(user)
    delete_account_changeset = Accounts.change_user_delete_account(user)
    avatar_changeset = Accounts.change_user_avatar(user)
    profile_changeset = Accounts.change_user_profile(user.connection)
    profile_about = maybe_decrypt_profile_about(user, socket.assigns.key)

    socket =
      socket
      |> assign(:page_title, "Settings")
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:profile_about, profile_about)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:name_form, to_form(name_changeset))
      |> assign(:username_form, to_form(username_changeset))
      |> assign(:visibility_form, to_form(visibility_changeset))
      |> assign(:forgot_password_form, to_form(forgot_password_changeset))
      |> assign(:delete_account_form, to_form(delete_account_changeset))
      |> assign(:avatar_form, to_form(avatar_changeset))
      |> assign(:profile_form, to_form(profile_changeset))
      |> assign(:trigger_submit, false)
      |> allow_upload(:avatar,
        accept: ~w(.png .jpeg .jpg),
        max_file_size: 10_000_000,
        auto_upload: true,
        temporary_assigns: [uploaded_files: []]
      )

    {:ok, socket}
  end

  def handle_params(%{} = _params, _url, socket) do
    # Handle the task.async return
    {:noreply, socket}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  def handle_info(
        {_ref, {:ok, :avatar_deleted_from_storj, info}},
        socket
      ) do
    socket = put_flash(socket, :success, info)
    {:noreply, redirect(socket, to: "/users/settings")}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  def handle_event("validate_avatar", params, socket) do
    avatar_form =
      socket.assigns.current_user
      |> Accounts.change_user_avatar(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, avatar_form: avatar_form)}
  end

  def handle_event("update_avatar", _params, socket) do
    user = socket.assigns.current_user
    key = socket.assigns.key
    avatars_bucket = Encrypted.Session.avatars_bucket()

    avatar_url_tuple_list =
      consume_uploaded_entries(
        socket,
        :avatar,
        fn %{path: path} = _meta, entry ->
          # Check the mime_type to avoid malicious file naming
          mime_type = ExMarcel.MimeType.for({:path, path})

          cond do
            mime_type in ["image/jpeg", "image/jpg", "image/png"] ->
              with {:ok, blob} <-
                     Image.open!(path)
                     |> Image.avatar!()
                     |> Image.write(:memory,
                       suffix: ".#{file_ext(entry)}",
                       minimize_file_size: true
                     ),
                   {:ok, e_blob} <- prepare_encrypted_blob(blob, user, key),
                   {:ok, file_path} <- prepare_file_path(entry, user.id) do
                make_aws_requests(entry, avatars_bucket, file_path, e_blob, user, key)
              end

            true ->
              {:postpone, :error}
          end
        end
      )

    cond do
      :error in avatar_url_tuple_list ->
        err_msg = "Incorrect file type."
        {:noreply, put_flash(socket, :error, err_msg)}

      :error not in avatar_url_tuple_list ->
        # Get the file path & e_blob from the tuple.
        [{_entry, file_path, e_blob}] = avatar_url_tuple_list

        avatar_params = %{avatar_url: file_path}

        case Accounts.update_user_avatar(user, avatar_params, user: user, key: key) do
          {:ok, _user, conn} ->
            # Put the encrypted avatar blob in ets under the
            # user's connection id.
            AvatarProcessor.put_ets_avatar(conn.id, e_blob)
            info = "Your avatar has been updated successfully."

            avatar_form =
              user
              |> Accounts.change_user_avatar(avatar_params)
              |> to_form()

            {:noreply,
             socket
             |> put_flash(:success, info)
             |> assign(avatar_form: avatar_form)
             |> push_navigate(to: ~p"/users/settings")}

          _rest ->
            {:noreply, socket}
        end
    end
  end

  def handle_event("cancel", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :avatar, ref)}
  end

  @doc """
  Deletes the avatar in ETS and object storage.
  """
  def handle_event("delete_avatar", %{"url" => url}, socket) do
    avatars_bucket = Encrypted.Session.avatars_bucket()
    user = socket.assigns.current_user
    key = socket.assigns.key

    profile = Map.get(user.connection, :profile)

    if profile && Map.get(profile, :avatar_url) do
      profile_avatar_url = decr_avatar(profile.avatar_url, user, user.conn_key, key)

      with {:ok, _user, conn} <-
             Accounts.update_user_avatar(user, %{avatar_url: nil}, delete_avatar: true),
           true <- AvatarProcessor.delete_ets_avatar(conn.id),
           true <- AvatarProcessor.delete_ets_avatar("profile-#{conn.id}") do
        make_async_aws_requests(avatars_bucket, url, profile_avatar_url, user, key)

        info =
          "Your avatar has been deleted successfully. Sit back and relax while we delete it from the private cloud."

        socket =
          socket
          |> put_flash(:info, info)

        {:noreply, push_patch(socket, to: "/users/settings")}
      else
        {:error, :make_async_aws_requests} ->
          {:noreply, socket}

        _rest ->
          {:noreply, socket}
      end
    else
      with {:ok, _user, conn} <-
             Accounts.update_user_avatar(user, %{avatar_url: nil}, delete_avatar: true),
           true <- AvatarProcessor.delete_ets_avatar(conn.id) do
        make_async_aws_requests(avatars_bucket, url, user, key)

        info =
          "Your avatar has been deleted successfully. Sit back and relax while we delete it from the private cloud."

        socket =
          socket
          |> put_flash(:success, info)

        {:noreply, socket}
      else
        _rest ->
          {:noreply, socket}
      end
    end
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user
    key = socket.assigns.key
    d_email = Utils.decrypt_user_data(user.email, user, key)

    case Accounts.apply_user_email(user, password, user_params,
           key: key,
           user: user,
           d_email: d_email
         ) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          d_email,
          user_params["email"],
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."

        {:noreply,
         socket |> put_flash(:success, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(user_params, change_password: true)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user
    key = socket.assigns.key

    case Accounts.update_user_password(user, password, user_params,
           change_password: true,
           key: key,
           user: user
         ) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  def handle_event("validate_name", params, socket) do
    %{"user" => user_params} = params

    name_form =
      socket.assigns.current_user
      |> Accounts.change_user_name(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, name_form: name_form)}
  end

  def handle_event("update_name", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_user
    key = socket.assigns.key

    case Accounts.update_user_name(user, user_params,
           change_name: true,
           key: key,
           user: user
         ) do
      {:ok, user} ->
        name_form =
          user
          |> Accounts.change_user_name(user_params)
          |> to_form()

        info = "Your name has been updated successfully."

        {:noreply,
         socket
         |> put_flash(:success, info)
         |> assign(name_form: name_form)
         |> redirect(to: ~p"/users/settings")}
    end
  end

  def handle_event("validate_username", params, socket) do
    %{"user" => user_params} = params

    username_form =
      socket.assigns.current_user
      |> Accounts.change_user_username(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, username_form: username_form)}
  end

  def handle_event("update_username", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_user
    key = socket.assigns.key

    case Accounts.update_user_username(user, user_params,
           validate_username: true,
           key: key,
           user: user
         ) do
      {:ok, user} ->
        username_form =
          user
          |> Accounts.change_user_username(user_params)
          |> to_form()

        info = "Your username has been updated successfully."

        {:noreply,
         socket
         |> put_flash(:success, info)
         |> assign(username_form: username_form)
         |> redirect(to: ~p"/users/settings")}

      {:error, changeset} ->
        info = "That username may already be taken."

        {:noreply,
         socket
         |> put_flash(:error, info)
         |> assign(username_form: to_form(changeset))
         |> redirect(to: ~p"/users/settings")}
    end
  end

  def handle_event("validate_visibility", params, socket) do
    %{"user" => user_params} = params

    username_form =
      socket.assigns.current_user
      |> Accounts.change_user_visibility(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, username_form: username_form)}
  end

  def handle_event("update_visibility", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.update_user_visibility(user, user_params) do
      {:ok, user} ->
        visibility_form =
          user
          |> Accounts.change_user_username(user_params)
          |> to_form()

        info = "Your visibility has been updated successfully."

        {:noreply,
         socket
         |> put_flash(:success, info)
         |> assign(visibility_form: visibility_form)
         |> redirect(to: ~p"/users/settings")}

      {:error, changeset} ->
        info = "Visibility did not change."

        {:noreply,
         socket
         |> put_flash(:info, info)
         |> assign(visibility_form: to_form(changeset))
         |> push_patch(to: ~p"/users/settings")}
    end
  end

  def handle_event("validate_forgot_password", params, socket) do
    %{"user" => user_params} = params

    forgot_password_form =
      socket.assigns.current_user
      |> Accounts.change_user_forgot_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, forgot_password_form: forgot_password_form)}
  end

  def handle_event("update_forgot_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_user
    key = socket.assigns.key

    if user && user.confirmed_at do
      case Accounts.update_user_forgot_password(user, user_params,
             change_forgot_password: true,
             key: key,
             user: user
           ) do
        {:ok, user} ->
          forgot_password_form =
            user
            |> Accounts.change_user_forgot_password(user_params)
            |> to_form()

          info = "Your forgot password setting has been updated successfully."

          {:noreply,
           socket
           |> put_flash(:success, info)
           |> assign(forgot_password_form: forgot_password_form)
           |> redirect(to: ~p"/users/settings")}
      end
    else
      info = "Woops, you need to confirm your account first."

      {:noreply,
       socket
       |> put_flash(:error, info)
       |> redirect(to: ~p"/users/settings")}
    end
  end

  def handle_event("validate_delete_account", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    delete_account_form =
      socket.assigns.current_user
      |> Accounts.change_user_delete_account(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply,
     assign(socket,
       delete_account_form: delete_account_form,
       delete_account_form_current_password: password
     )}
  end

  def handle_event("validate_profile", params, socket) do
    %{"connection" => profile_params} = params
    user = socket.assigns.current_user

    if Map.get(user.connection, :profile) do
      profile_params =
        profile_params
        |> Map.put(
          "profile",
          Map.put(profile_params["profile"], "opts_map", %{
            user: socket.assigns.current_user,
            key: socket.assigns.key,
            update_profile: true
          })
        )

      profile_form =
        socket.assigns.current_user.connection
        |> Accounts.change_user_profile(profile_params)
        |> Map.put(:action, :validate)
        |> to_form()

      {:noreply,
       socket
       |> assign(profile_about: profile_params["profile"]["about"])
       |> assign(profile_form: profile_form)}
    else
      profile_params =
        profile_params
        |> Map.put(
          "profile",
          Map.put(profile_params["profile"], "opts_map", %{
            user: socket.assigns.current_user,
            key: socket.assigns.key
          })
        )

      profile_form =
        socket.assigns.current_user.connection
        |> Accounts.change_user_profile(profile_params)
        |> Map.put(:action, :validate)
        |> to_form()

      {:noreply,
       socket
       |> assign(profile_about: profile_params["profile"]["about"])
       |> assign(profile_form: profile_form)}
    end
  end

  def handle_event("update_profile", params, socket) do
    %{"connection" => profile_params} = params
    user = socket.assigns.current_user
    key = socket.assigns.key

    profile_params =
      profile_params
      |> Map.put(
        "profile",
        Map.put(profile_params["profile"], "opts_map", %{
          user: socket.assigns.current_user,
          key: socket.assigns.key,
          update_profile: true,
          encrypt: true
        })
      )

    if user && user.confirmed_at do
      case Accounts.update_user_profile(user, profile_params,
             key: key,
             user: user,
             update_profile: true,
             encrypt: true
           ) do
        {:ok, connection} ->
          profile_form =
            connection
            |> Accounts.change_user_profile(profile_params)
            |> to_form()

          info = "Your profile has been updated successfully."

          {:noreply,
           socket
           |> put_flash(:success, info)
           |> assign(profile_form: profile_form)
           |> redirect(to: ~p"/users/settings")}
      end
    else
      info = "Woops, you need to confirm your account first."

      {:noreply,
       socket
       |> put_flash(:error, info)
       |> redirect(to: ~p"/users/settings")}
    end
  end

  def handle_event("create_profile", params, socket) do
    %{"connection" => profile_params} = params
    user = socket.assigns.current_user
    key = socket.assigns.key

    profile_params =
      profile_params
      |> Map.put(
        "profile",
        Map.put(profile_params["profile"], "opts_map", %{
          user: socket.assigns.current_user,
          key: socket.assigns.key,
          encrypt: true
        })
      )

    if user && user.confirmed_at do
      case Accounts.create_user_profile(user, profile_params,
             key: key,
             user: user,
             encrypt: true
           ) do
        {:ok, conn} ->
          profile_form =
            conn
            |> Accounts.change_user_profile(profile_params)
            |> to_form()

          info = "Your profile has been created successfully."

          {:noreply,
           socket
           |> put_flash(:success, info)
           |> assign(profile_form: profile_form)
           |> redirect(to: ~p"/users/settings")}
      end
    else
      info = "Woops, you need to confirm your account first."

      {:noreply,
       socket
       |> put_flash(:error, info)
       |> redirect(to: ~p"/users/settings")}
    end
  end

  def handle_event("delete_profile", %{"id" => id}, socket) do
    conn = Accounts.get_connection!(id)
    user = socket.assigns.current_user
    key = socket.assigns.key

    if user.connection.id == conn.id do
      case Accounts.delete_user_profile(user, conn) do
        {:ok, conn} ->
          profile_form =
            conn
            |> Accounts.change_user_profile()
            |> to_form()

          if Map.get(user.connection.profile, :avatar_url) do
            avatars_bucket = Encrypted.Session.avatars_bucket()

            avatar_url =
              decr_avatar(
                user.connection.profile.avatar_url,
                user,
                user.conn_key,
                key
              )

            # Handle deleting the object storage avatar async.
            make_async_aws_requests(avatars_bucket, avatar_url, nil, nil)

            info =
              "Your profile has been deleted successfully. Sit back and relax while we delete your profile avatar from the private cloud."

            {:noreply,
             socket
             |> put_flash(:info, info)
             |> assign(profile_form: profile_form)}
          else
            info = "Your profile has been deleted successfully."

            {:noreply,
             socket
             |> put_flash(:success, info)
             |> assign(profile_form: profile_form)
             |> redirect(to: ~p"/users/settings")}
          end
      end
    else
      info = "You don't have permission to do this."

      {:noreply, socket |> put_flash(:warning, info) |> push_navigate(to: "/users/settings")}
    end
  end

  def handle_event("delete_account", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user
    key = socket.assigns.key

    # Cancel Stripe subscription.
    if Bling.Customers.subscribed?(user) do
      subscription = Bling.Customers.subscription(user)
      Bling.Subscriptions.cancel_now(subscription)
    end

    case Accounts.delete_user_account(user, password, user_params) do
      {:ok, user} ->
        if Map.get(user, :avatar_url) do
          avatars_bucket = Encrypted.Session.avatars_bucket()
          memories_bucket = Encrypted.Session.memories_bucket()
          d_url = decr_avatar(user.connection.avatar_url, user, user.conn_key, key)
          profile = Map.get(user.connection, :profile)

          # Handle deleting the object storage avatar and memories async.
          if profile do
            profile_avatar_url = decr_avatar(profile.avatar_url, user, profile.profile_key, key)

            with {:ok, _resp} <-
                   ex_aws_delete_request(memories_bucket, "uploads/user/#{user.id}/memories/**"),
                 {:ok, _resp} <-
                   ex_aws_delete_request(avatars_bucket, d_url),
                 {:ok, _resp} <- ex_aws_delete_request(avatars_bucket, profile_avatar_url) do
              socket =
                socket
                |> put_flash(:success, "Account deleted successfully.")
                |> redirect(to: ~p"/")

              {:noreply, socket}
            else
              _rest ->
                ex_aws_delete_request(memories_bucket, "uploads/user/#{user.id}/memories/**")
                ex_aws_delete_request(avatars_bucket, d_url)
                ex_aws_delete_request(avatars_bucket, profile_avatar_url)

                socket =
                  socket
                  |> put_flash(:success, "Account deleted successfully.")
                  |> redirect(to: ~p"/")

                {:noreply, socket}
            end
          else
            with {:ok, _resp} <-
                   ex_aws_delete_request(memories_bucket, "uploads/user/#{user.id}/memories/**"),
                 {:ok, _resp} <-
                   ex_aws_delete_request(avatars_bucket, d_url) do
              socket =
                socket
                |> put_flash(:success, "Account deleted successfully.")
                |> redirect(to: ~p"/")

              {:noreply, socket}
            else
              _rest ->
                ex_aws_delete_request(memories_bucket, "uploads/user/#{user.id}/memories/**")
                ex_aws_delete_request(avatars_bucket, d_url)

                socket =
                  socket
                  |> put_flash(:success, "Account deleted successfully.")
                  |> redirect(to: ~p"/")

                {:noreply, socket}
            end
          end
        else
          # No user avatar
          socket =
            socket
            |> put_flash(:success, "Account deleted successfully.")
            |> redirect(to: ~p"/")

          {:noreply, socket}
        end

      {:error, changeset} ->
        {:noreply, assign(socket, delete_account_form: to_form(changeset))}
    end
  end

  ## PRIVATE & AWS

  defp maybe_decrypt_profile_about(user, key) do
    profile = Map.get(user.connection, :profile)

    cond do
      profile && not is_nil(profile.about) ->
        cond do
          profile.visibility == :public ->
            decr_public_item(profile.about, profile.profile_key)

          profile.visibility == :private ->
            decr_item(profile.about, user, profile.profile_key, key, profile)

          profile.visibility == :connections ->
            decr_item(
              profile.about,
              user,
              profile.profile_key,
              key,
              profile
            )

          true ->
            profile.about
        end

      true ->
        nil
    end
  end

  defp file_ext(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    "#{ext}"
  end

  defp filename(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    "#{entry.uuid}.#{ext}"
  end

  defp prepare_file_path(entry, user_id) do
    {:ok, "uploads/user/#{user_id}/avatars/#{filename(entry)}"}
  end

  defp prepare_encrypted_blob(blob, user, key) do
    {:ok, d_conn_key} =
      Encrypted.Users.Utils.decrypt_user_attrs_key(user.conn_key, user, key)

    encrypted_avatar_blob = Encrypted.Utils.encrypt(%{key: d_conn_key, payload: blob})

    cond do
      is_binary(encrypted_avatar_blob) ->
        {:ok, encrypted_avatar_blob}

      true ->
        {:error, encrypted_avatar_blob}
    end
  end

  defp make_aws_requests(entry, avatars_bucket, file_path, e_blob, user, key) do
    with {:ok, _resp} <- maybe_delete_old_avatar(avatars_bucket, user, key),
         {:ok, _resp} <- ex_aws_put_request(avatars_bucket, file_path, e_blob) do
      # Return the encrypted_blob in the tuple for putting
      # the encrypted avatar into ets.
      {:ok, {entry, file_path, e_blob}}
    else
      _rest ->
        ex_aws_put_request(avatars_bucket, file_path, e_blob)
    end
  end

  defp ex_aws_delete_request(avatars_bucket, url) do
    ExAws.S3.delete_object(avatars_bucket, url)
    |> ExAws.request()
  end

  defp ex_aws_put_request(avatars_bucket, file_path, e_blob) do
    ExAws.S3.put_object(avatars_bucket, file_path, e_blob)
    |> ExAws.request()
  end

  defp maybe_delete_old_avatar(avatars_bucket, user, key) do
    case user.connection.avatar_url do
      nil ->
        {:ok, "no avatar"}

      _rest ->
        d_url = decr_avatar(user.connection.avatar_url, user, user.conn_key, key)

        with {:ok, resp} <- ex_aws_delete_request(avatars_bucket, d_url) do
          {:ok, resp}
        else
          _rest -> ex_aws_delete_request(avatars_bucket, d_url)
        end
    end
  end

  defp make_async_aws_requests(avatars_bucket, url, _user, _key) do
    # delete only the user avatar because the
    # profile has already been deleted
    Task.Supervisor.async_nolink(Metamorphic.StorjTask, fn ->
      with {:ok, _resp} <- ex_aws_delete_request(avatars_bucket, url) do
        {:ok, :avatar_deleted_from_storj, "Avatar successfully deleted from the private cloud."}
      else
        _rest ->
          ex_aws_delete_request(avatars_bucket, url)
          {:error, :make_async_aws_requests}
      end
    end)
  end

  defp make_async_aws_requests(avatars_bucket, url, profile_avatar_url, user, key) do
    Task.Supervisor.async_nolink(Metamorphic.StorjTask, fn ->
      profile_attrs =
        %{
          "profile" => %{
            "avatar_url" => nil,
            "show_avatar?" => false,
            "opts_map" => %{"user" => user, "key" => key, "update_profile" => true}
          }
        }

      # delete both the profile and the user avatar
      with {:ok, _resp} <- ex_aws_delete_request(avatars_bucket, url),
           {:ok, _resp} <- ex_aws_delete_request(avatars_bucket, profile_avatar_url),
           {:ok, _user} <- Accounts.update_user_profile(user, profile_attrs) do
        {:ok, :avatar_deleted_from_storj, "Avatar successfully deleted from the private cloud."}
      else
        _rest ->
          ex_aws_delete_request(avatars_bucket, url)
          ex_aws_delete_request(avatars_bucket, profile_avatar_url)
          {:error, :make_async_aws_requests}
      end
    end)
  end
end
