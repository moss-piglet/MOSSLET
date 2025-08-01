defmodule MossletWeb.EditDetailsLive do
  @moduledoc false
  use MossletWeb, :live_view

  import MossletWeb.UserSettingsLayoutComponent

  alias Mosslet.Accounts
  alias Mosslet.Encrypted
  alias Mosslet.Extensions.AvatarProcessor
  alias MossletWeb.FileUploadComponents
  alias Mosslet.FileUploads.Storj

  # SETUP_TODO: pick a storage option for images below.
  # Cloudinary setup info: /lib/petal_pro/file_uploads/cloudinary.ex
  # S3 setup info: /lib/petal_pro/file_uploads/s3.ex
  # We recommend cloudinary due to its ability to optimize and transform images based on URL parameters
  # For non-image files, we recommend S3

  @upload_provider Mosslet.FileUploads.Storj
  # @upload_provider Mosslet.FileUploads.Cloudinary
  # @upload_provider Mosslet.FileUploads.S3

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    key = socket.assigns.key
    AvatarProcessor.delete_ets_avatar("profile-#{user.connection.id}")

    socket =
      socket
      |> assign(%{
        page_title: "Settings",
        uploaded_files: []
      })
      |> assign(:name_change_valid?, false)
      |> assign(:username_change_valid?, false)
      |> assign(
        :current_username,
        decr(
          user.username,
          user,
          key
        )
      )
      |> assign(
        :current_name,
        decr(user.name, user, key)
      )
      |> assign_avatar_form(user)
      |> assign_name_form(user)
      |> assign_username_form(user)
      |> allow_upload(:avatar,
        # SETUP_TODO: Uncomment the line below if using an external provider (Cloudinary or S3)
        # external: &@upload_provider.presign_upload/2,
        accept: ~w(.jpg .jpeg .png),
        max_entries: 1
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.settings_layout current_page={:edit_details} current_user={@current_user} key={@key}>
      <.form
        id="update_avatar_form"
        for={@avatar_form}
        phx-submit="update_avatar"
        phx-change="validate"
      >
        <FileUploadComponents.image_input
          upload={@uploads.avatar}
          label={gettext("Avatar")}
          current_image_src={maybe_get_user_avatar(@current_user, @key)}
          user={@current_user}
          key={@key}
          placeholder_icon={:user}
          on_delete="delete_avatar"
          automatic_help_text
          url={
            if @current_user.connection.avatar_url,
              do:
                decr_avatar(
                  @current_user.connection.avatar_url,
                  @current_user,
                  @current_user.conn_key,
                  @key
                ),
              else: nil
          }
        />

        <div class="flex justify-end">
          <.button
            :if={@uploads.avatar.entries != []}
            class="rounded-full"
            phx-disable-with="Updating..."
          >
            {gettext("Update avatar")}
          </.button>
          <.button
            :if={@uploads.avatar.entries == []}
            class="rounded-full"
            phx-disable-with="Updating..."
            disabled
          >
            {gettext("Choose photo to upload")}
          </.button>
        </div>
      </.form>

      <div id="name-change-form">
        <.simple_form
          for={@name_form}
          id="update_name_form"
          phx-submit="update_name"
          phx-change="validate_name"
        >
          <.field
            field={@name_form[:name]}
            label={gettext("Name")}
            placeholder={gettext("eg. Isabella")}
            value={@current_name}
          />
          <:actions>
            <.button
              class="rounded-full"
              phx-disable-with="Updating..."
              disabled={!@name_change_valid?}
            >
              {gettext("Update name")}
            </.button>
          </:actions>
        </.simple_form>
      </div>

      <div id="username-change-form">
        <.simple_form
          for={@username_form}
          id="update_username_form"
          phx-submit="update_username"
          phx-change="validate_username"
        >
          <.field
            field={@username_form[:username]}
            label={gettext("Username")}
            placeholder={gettext("eg. isabella")}
            value={@current_username}
          />
          <:actions>
            <.button
              class="rounded-full"
              phx-disable-with="Updating..."
              disabled={!@username_change_valid?}
            >
              {gettext("Update username")}
            </.button>
          </:actions>
        </.simple_form>
      </div>
    </.settings_layout>
    """
  end

  @impl true
  def handle_info({_ref, {"get_user_avatar", user_id}}, socket) do
    user = Accounts.get_user_with_preloads(user_id)
    {:noreply, assign(socket, :current_user, user)}
  end

  @impl true
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("validate_name", params, socket) do
    %{"user" => user_params} = params

    name_form =
      socket.assigns.current_user
      |> Accounts.change_user_name(user_params, validate_name: true)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply,
     socket
     |> assign(:current_name, name_form[:name].value)
     |> assign(name_change_valid?: name_form.source.valid?)
     |> assign(name_form: name_form)}
  end

  def handle_event("validate_username", params, socket) do
    %{"user" => user_params} = params

    username_form =
      socket.assigns.current_user
      |> Accounts.change_user_username(user_params, validate_username: true)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply,
     socket
     |> assign(:current_username, username_form[:username].value)
     |> assign(username_change_valid?: username_form.source.valid?)
     |> assign(username_form: username_form)}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :avatar, ref)}
  end

  @impl true
  def handle_event("clear_avatar", _params, socket) do
    {:noreply, assign(socket, :avatar, nil)}
  end

  @impl true
  def handle_event("update_avatar", user_params, socket) do
    user = socket.assigns.current_user
    key = socket.assigns.key

    case maybe_add_avatar(user_params, socket) do
      {:postpone, {:nsfw, message}} ->
        {:noreply,
         socket |> put_flash(:warning, message) |> push_navigate(to: ~p"/app/users/edit-details")}

      {:postpone, {:error, message}} ->
        {:noreply,
         socket |> put_flash(:warning, message) |> push_navigate(to: ~p"/app/users/edit-details")}

      {:ok, {e_blob, user_params}} ->
        case Accounts.update_user_avatar(user, user_params, user: user, key: key) do
          {:ok, user, conn} ->
            # Put the encrypted avatar blob in ets under the
            # user's connection id.
            Accounts.user_lifecycle_action("after_update_profile", user)
            AvatarProcessor.delete_ets_avatar("profile-#{conn.id}")
            AvatarProcessor.put_ets_avatar("profile-#{conn.id}", e_blob)
            info = "Your avatar has been updated successfully."

            {:noreply,
             socket
             |> put_flash(:success, Gettext.gettext(MossletWeb.Gettext, info))
             |> assign_avatar_form(user)
             |> push_navigate(to: ~p"/app/users/edit-details")}

          {:error, changeset} ->
            socket =
              socket
              |> put_flash(:error, gettext("Update failed. Please check the form for issues"))
              |> assign(form: to_form(changeset))

            {:noreply, socket}
        end
    end
  end

  @doc """
  Deletes the avatar in ETS and object storage.
  """
  @impl true
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
        Storj.make_async_aws_requests(avatars_bucket, url, profile_avatar_url, user, key)

        Accounts.user_lifecycle_action("after_update_profile", user)

        info =
          "Your avatar has been deleted successfully."

        {:noreply,
         socket
         |> put_flash(:success, Gettext.gettext(MossletWeb.Gettext, info))
         |> assign_avatar_form(user)
         |> push_navigate(to: ~p"/app/users/edit-details")}
      else
        {:error, :make_async_aws_requests} ->
          {:noreply, socket}

        {:error, changeset} ->
          socket =
            socket
            |> put_flash(:error, gettext("Update failed. Please check the form for issues"))
            |> assign(form: to_form(changeset))

          {:noreply, socket}
      end
    else
      with {:ok, _user, conn} <-
             Accounts.update_user_avatar(user, %{avatar_url: nil}, delete_avatar: true),
           true <- AvatarProcessor.delete_ets_avatar(conn.id),
           true <- AvatarProcessor.delete_ets_avatar("profile-#{conn.id}") do
        Storj.make_async_aws_requests(avatars_bucket, url, user, key)

        Accounts.user_lifecycle_action("after_update_profile", user)

        info =
          "Your avatar has been deleted successfully."

        {:noreply,
         socket
         |> put_flash(:success, Gettext.gettext(MossletWeb.Gettext, info))
         |> assign_avatar_form(user)
         |> push_navigate(to: ~p"/app/users/edit-details")}
      else
        {:error, changeset} ->
          socket =
            socket
            |> put_flash(:error, gettext("Update failed. Please check the form for issues"))
            |> assign(avatar_form: to_form(changeset))

          {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("update_name", %{"user" => user_params}, socket) do
    user = socket.assigns.current_user
    key = socket.assigns.key

    if user_params["name"] && user_params["name"] != "" do
      case Accounts.update_user_name(user, user_params,
             change_name: true,
             key: key,
             user: user
           ) do
        {:ok, user} ->
          info = "Your name has been updated successfully."

          {:noreply,
           socket
           |> put_flash(:success, Gettext.gettext(MossletWeb.Gettext, info))
           |> assign_name_form(user)}

        {:error, changeset} ->
          info = "There was an error when trying to update your name."

          {:noreply,
           socket
           |> put_flash(:info, Gettext.gettext(MossletWeb.Gettext, info))
           |> assign(name_form: to_form(changeset))}
      end
    else
      info = "Your name can't be blank."

      {:noreply,
       socket
       |> put_flash(:info, Gettext.gettext(MossletWeb.Gettext, info))
       |> assign_name_form(user)
       |> push_navigate(to: ~p"/app/users/edit-details")}
    end
  end

  def handle_event("update_username", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_user
    key = socket.assigns.key

    if user_params["username"] && user_params["username"] != "" do
      case Accounts.update_user_username(user, user_params,
             validate_username: true,
             key: key,
             user: user
           ) do
        {:ok, user} ->
          info = "Your username has been updated successfully."

          {:noreply,
           socket
           |> put_flash(:success, Gettext.gettext(MossletWeb.Gettext, info))
           |> assign_username_form(user)
           |> push_navigate(to: ~p"/app/users/edit-details")}

        {:error, changeset} ->
          info = "That username may already be taken."

          {:noreply,
           socket
           |> put_flash(:info, Gettext.gettext(MossletWeb.Gettext, info))
           |> assign(username_form: to_form(changeset))}
      end
    else
      info = "Your username can't be blank."

      {:noreply,
       socket
       |> put_flash(:info, Gettext.gettext(MossletWeb.Gettext, info))
       |> assign_username_form(user)
       |> push_navigate(to: ~p"/app/users/edit-details")}
    end
  end

  defp maybe_add_avatar(user_params, socket) do
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
              with {:ok, image_binary} <-
                     Image.open!(path)
                     |> check_for_safety(),
                   {:ok, vix_image} <-
                     Image.avatar(image_binary,
                       crop: :attention,
                       shape: :square,
                       size: 360
                     ),
                   {:ok, blob} <-
                     Image.write(vix_image, :memory,
                       suffix: ".#{@upload_provider.file_ext(entry)}",
                       minimize_file_size: true
                     ),
                   {:ok, e_blob} <- @upload_provider.prepare_encrypted_blob(blob, user, key),
                   {:ok, file_path} <-
                     @upload_provider.prepare_file_path(entry, user.connection.id) do
                @upload_provider.make_aws_requests(
                  entry,
                  avatars_bucket,
                  file_path,
                  e_blob,
                  user,
                  key
                )
              else
                {:nsfw, message} ->
                  {:postpone, {:nsfw, message}}

                {:error, message} ->
                  {:postpone, {:error, message}}
              end

            true ->
              {:postpone, :error}
          end
        end
      )

    case avatar_url_tuple_list do
      [nsfw: message] ->
        {:postpone, {:nsfw, message}}

      [error: message] ->
        {:postpone, {:error, message}}

      [:error] ->
        {:postpone, {:error, "Incorrect file type."}}

      [{_entry, file_path, e_blob}] ->
        # Return the encrypted blob and user_params map
        user_params = Map.put(user_params, :avatar_url, file_path)
        {:ok, {e_blob, user_params}}

      _rest ->
        {:postpone,
         {:error, "There was an error trying to upload your image, please try a different image."}}
    end
  end

  defp check_for_safety(image_binary) do
    Mosslet.AI.Images.check_for_safety(image_binary)
  end

  defp assign_avatar_form(socket, user) do
    assign(socket, avatar_form: to_form(Accounts.change_user_avatar(user)))
  end

  defp assign_name_form(socket, user) do
    assign(socket, name_form: to_form(Accounts.change_user_name(user)))
  end

  defp assign_username_form(socket, user) do
    assign(socket, username_form: to_form(Accounts.change_user_username(user)))
  end
end
