defmodule MossletWeb.EditDetailsLive do
  @moduledoc false
  use MossletWeb, :live_view

  require Logger

  alias Mosslet.Accounts
  alias Mosslet.Encrypted
  alias Mosslet.Extensions.AvatarProcessor
  alias Mosslet.FileUploads.Storj
  alias MossletWeb.DesignSystem

  @upload_provider Mosslet.FileUploads.Storj

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      current_user={@current_user}
      current_page={:edit_details}
      sidebar_current_page={:edit_details}
      key={@key}
      type="sidebar"
    >
      <DesignSystem.liquid_container max_width="lg" class="py-16">
        <div class="mb-12">
          <div class="mb-8">
            <h1 class="text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              Profile Details
            </h1>
            <p class="mt-4 text-lg text-slate-600 dark:text-slate-400">
              Update your avatar, name, and username to personalize your MOSSLET profile.
            </p>
          </div>
          <div class="h-1 w-24 rounded-full bg-gradient-to-r from-teal-400 via-emerald-400 to-cyan-400 shadow-sm shadow-emerald-500/30">
          </div>
        </div>

        <div class="space-y-8 max-w-2xl">
          <DesignSystem.liquid_card>
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-teal-100 via-emerald-50 to-cyan-100 dark:from-teal-900/30 dark:via-emerald-900/25 dark:to-cyan-900/30">
                  <.phx_icon
                    name="hero-user-circle"
                    class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
                  />
                </div>
                Avatar
              </div>
            </:title>

            <.form
              id="update_avatar_form"
              for={@avatar_form}
              phx-submit="update_avatar"
              phx-change="validate"
              class="space-y-6"
            >
              <DesignSystem.liquid_avatar_upload
                upload={@uploads.avatar}
                upload_stage={@avatar_upload_stage}
                current_avatar_src={maybe_get_user_avatar(@current_user, @key)}
                user={@current_user}
                encryption_key={@key}
                on_delete="delete_avatar"
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

              <div class="flex flex-col sm:flex-row gap-3">
                <DesignSystem.liquid_button
                  :if={Enum.any?(@uploads.avatar.entries) && !is_processing?(@avatar_upload_stage)}
                  type="submit"
                  phx-disable-with="Updating..."
                  disabled={!@uploads.avatar.entries || is_processing?(@avatar_upload_stage)}
                  icon="hero-photo"
                >
                  {gettext("Update avatar")}
                </DesignSystem.liquid_button>

                <DesignSystem.liquid_button
                  :if={is_processing?(@avatar_upload_stage)}
                  type="button"
                  disabled
                  variant="secondary"
                  icon="hero-cog-6-tooth"
                  class="animate-pulse"
                >
                  {gettext("Processing...")}
                </DesignSystem.liquid_button>

                <DesignSystem.liquid_button
                  :if={@uploads.avatar.entries == [] && !is_processing?(@avatar_upload_stage)}
                  type="button"
                  disabled
                  variant="secondary"
                  icon="hero-photo"
                >
                  {gettext("Choose photo to upload")}
                </DesignSystem.liquid_button>
              </div>
            </.form>
          </DesignSystem.liquid_card>

          <DesignSystem.liquid_card>
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
                  <.phx_icon
                    name="hero-identification"
                    class="h-4 w-4 text-blue-600 dark:text-blue-400"
                  />
                </div>
                Display Name
              </div>
            </:title>

            <div id="name-change-form">
              <.form
                for={@name_form}
                id="update_name_form"
                phx-submit="update_name"
                phx-change="validate_name"
                class="space-y-6"
              >
                <DesignSystem.liquid_input
                  field={@name_form[:name]}
                  label={gettext("Name")}
                  placeholder={gettext("eg. Isabella")}
                  value={@current_name}
                />

                <DesignSystem.liquid_button
                  type="submit"
                  color="blue"
                  phx-disable-with="Updating..."
                  disabled={!@name_change_valid?}
                  icon="hero-check"
                >
                  {gettext("Update name")}
                </DesignSystem.liquid_button>
              </.form>
            </div>
          </DesignSystem.liquid_card>

          <DesignSystem.liquid_card>
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-purple-100 via-violet-50 to-purple-100 dark:from-purple-900/30 dark:via-violet-900/25 dark:to-purple-900/30">
                  <.phx_icon
                    name="hero-at-symbol"
                    class="h-4 w-4 text-purple-600 dark:text-purple-400"
                  />
                </div>
                Username
              </div>
            </:title>

            <div id="username-change-form">
              <.form
                for={@username_form}
                id="update_username_form"
                phx-submit="update_username"
                phx-change="validate_username"
                class="space-y-6"
              >
                <DesignSystem.liquid_input
                  field={@username_form[:username]}
                  label={gettext("Username")}
                  placeholder={gettext("eg. isabella")}
                  value={@current_username}
                />

                <DesignSystem.liquid_button
                  type="submit"
                  color="purple"
                  phx-disable-with="Updating..."
                  disabled={!@username_change_valid?}
                  icon="hero-check"
                >
                  {gettext("Update username")}
                </DesignSystem.liquid_button>
              </.form>
            </div>
          </DesignSystem.liquid_card>
        </div>
      </DesignSystem.liquid_container>
    </.layout>
    """
  end

  defp is_processing?(nil), do: false
  defp is_processing?({:ready, _}), do: false
  defp is_processing?({:error, _}), do: false
  defp is_processing?(_), do: true

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    socket =
      socket
      |> assign(%{
        page_title: "Settings",
        uploaded_files: [],
        avatar_upload_stage: nil
      })
      |> assign(:name_change_valid?, false)
      |> assign(:username_change_valid?, false)
      |> assign(
        :current_username,
        decr(
          current_user.username,
          current_user,
          key
        )
      )
      |> assign(
        :current_name,
        decr(current_user.name, current_user, key)
      )
      |> assign_avatar_form(current_user)
      |> assign_name_form(current_user)
      |> assign_username_form(current_user)
      |> allow_upload(:avatar,
        accept: ~w(.jpg .jpeg .png .webp .heic .heif),
        auto_upload: false,
        max_entries: 1,
        progress: &handle_progress/3
      )

    {:ok, socket}
  end

  defp handle_progress(:avatar, entry, socket) do
    if entry.done? do
      process_avatar_upload(socket)
    else
      {:noreply, socket}
    end
  end

  defp process_avatar_upload(socket) do
    lv_pid = self()
    user = socket.assigns.current_user
    key = socket.assigns.key
    avatars_bucket = Encrypted.Session.avatars_bucket()

    socket = assign(socket, :avatar_upload_stage, {:receiving, 10})

    avatar_url_tuple_list =
      consume_uploaded_entries(
        socket,
        :avatar,
        fn meta, entry ->
          case meta do
            %{error: error} ->
              send(lv_pid, {:avatar_upload_stage, {:error, error}})
              {:postpone, {:error, error}}

            %{path: path} ->
              send(lv_pid, {:avatar_upload_stage, {:receiving, 30}})
              mime_type = ExMarcel.MimeType.for({:path, path})

              cond do
                mime_type in [
                  "image/jpeg",
                  "image/jpg",
                  "image/png",
                  "image/webp",
                  "image/heic",
                  "image/heif"
                ] ->
                  send(lv_pid, {:avatar_upload_stage, {:converting, 40}})

                  with {:ok, image} <- load_image_for_avatar(path, mime_type),
                       {:ok, image} <- autorotate_image(image),
                       _ <- send(lv_pid, {:avatar_upload_stage, {:checking, 50}}),
                       {:ok, safe_image} <- check_for_safety(image),
                       _ <- send(lv_pid, {:avatar_upload_stage, {:resizing, 60}}),
                       {:ok, vix_image} <-
                         Image.avatar(safe_image,
                           crop: :attention,
                           shape: :square,
                           size: 360
                         ),
                       {:ok, blob} <-
                         Image.write(vix_image, :memory,
                           suffix: ".webp",
                           minimize_file_size: true
                         ),
                       _ <- send(lv_pid, {:avatar_upload_stage, {:encrypting, 75}}),
                       {:ok, e_blob} <- @upload_provider.prepare_encrypted_blob(blob, user, key),
                       {:ok, file_path} <-
                         @upload_provider.prepare_file_path(entry, user.connection.id),
                       _ <- send(lv_pid, {:avatar_upload_stage, {:uploading, 85}}) do
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
                      send(lv_pid, {:avatar_upload_stage, {:error, message}})
                      {:postpone, {:nsfw, message}}

                    {:error, message} ->
                      send(lv_pid, {:avatar_upload_stage, {:error, message}})
                      {:postpone, {:error, message}}
                  end

                true ->
                  send(lv_pid, {:avatar_upload_stage, {:error, "Incorrect file type."}})
                  {:postpone, :error}
              end
          end
        end
      )

    case avatar_url_tuple_list do
      [nsfw: message] ->
        {:noreply,
         socket
         |> assign(:avatar_upload_stage, {:error, message})
         |> put_flash(:warning, message)}

      [error: message] ->
        {:noreply,
         socket
         |> assign(:avatar_upload_stage, {:error, message})
         |> put_flash(:warning, message)}

      [:error] ->
        {:noreply,
         socket
         |> assign(:avatar_upload_stage, {:error, "Incorrect file type."})
         |> put_flash(:warning, "Incorrect file type.")}

      [{_entry, file_path, e_blob}] ->
        user_params = %{avatar_url: file_path}
        send(lv_pid, {:avatar_upload_complete, {:ok, {e_blob, user_params}}})
        {:noreply, assign(socket, :avatar_upload_stage, {:uploading, 95})}

      _rest ->
        error_msg =
          "There was an error trying to upload your image, please try a different image."

        {:noreply,
         socket
         |> assign(:avatar_upload_stage, {:error, error_msg})
         |> put_flash(:warning, error_msg)}
    end
  end

  @impl true
  def handle_info({:avatar_upload_stage, stage}, socket) do
    {:noreply, assign(socket, :avatar_upload_stage, stage)}
  end

  @impl true
  def handle_info({:avatar_upload_complete, {:ok, {e_blob, user_params}}}, socket) do
    user = socket.assigns.current_user
    key = socket.assigns.key

    case Accounts.update_user_avatar(user, user_params, user: user, key: key) do
      {:ok, user, conn} ->
        AvatarProcessor.delete_ets_avatar(conn.id)
        AvatarProcessor.delete_ets_avatar("profile-#{conn.id}")
        AvatarProcessor.put_ets_avatar("profile-#{conn.id}", e_blob)
        AvatarProcessor.mark_avatar_recently_updated(conn.id)

        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "avatar_cache_global",
          {:avatar_updated, conn.id, e_blob}
        )

        Accounts.user_lifecycle_action("after_update_profile", user)

        {:noreply,
         socket
         |> assign(:avatar_upload_stage, {:ready, 100})
         |> put_flash(:success, gettext("Your avatar has been updated successfully."))
         |> assign_avatar_form(user)
         |> push_navigate(to: ~p"/app/users/edit-details")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:avatar_upload_stage, {:error, "Update failed"})
         |> put_flash(:error, gettext("Update failed. Please check the form for issues"))
         |> assign(form: to_form(changeset))}
    end
  end

  @impl true
  def handle_info({:avatar_upload_complete, {:error, error}}, socket) do
    {:noreply,
     socket
     |> assign(:avatar_upload_stage, {:error, error})
     |> put_flash(:warning, error)}
  end

  @impl true
  def handle_info({_ref, {_type, _result}}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    {:noreply, socket}
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
    {:noreply,
     socket
     |> cancel_upload(:avatar, ref)
     |> assign(:avatar_upload_stage, nil)}
  end

  @impl true
  def handle_event("clear_avatar", _params, socket) do
    {:noreply, assign(socket, :avatar, nil)}
  end

  @impl true
  def handle_event("update_avatar", _user_params, socket) do
    lv_pid = self()
    user = socket.assigns.current_user
    key = socket.assigns.key
    avatars_bucket = Encrypted.Session.avatars_bucket()

    socket = assign(socket, :avatar_upload_stage, {:receiving, 10})

    avatar_url_tuple_list =
      consume_uploaded_entries(
        socket,
        :avatar,
        fn meta, entry ->
          case meta do
            %{error: error} ->
              send(lv_pid, {:avatar_upload_stage, {:error, error}})
              {:postpone, {:error, error}}

            %{path: path} ->
              send(lv_pid, {:avatar_upload_stage, {:receiving, 30}})
              mime_type = ExMarcel.MimeType.for({:path, path})

              cond do
                mime_type in [
                  "image/jpeg",
                  "image/jpg",
                  "image/png",
                  "image/webp",
                  "image/heic",
                  "image/heif"
                ] ->
                  send(lv_pid, {:avatar_upload_stage, {:converting, 40}})

                  with {:ok, image} <- load_image_for_avatar(path, mime_type),
                       {:ok, image} <- autorotate_image(image),
                       _ <- send(lv_pid, {:avatar_upload_stage, {:checking, 50}}),
                       {:ok, safe_image} <- check_for_safety(image),
                       _ <- send(lv_pid, {:avatar_upload_stage, {:resizing, 60}}),
                       {:ok, vix_image} <-
                         Image.avatar(safe_image,
                           crop: :attention,
                           shape: :square,
                           size: 360
                         ),
                       {:ok, blob} <-
                         Image.write(vix_image, :memory,
                           suffix: ".webp",
                           minimize_file_size: true
                         ),
                       _ <- send(lv_pid, {:avatar_upload_stage, {:encrypting, 75}}),
                       {:ok, e_blob} <- @upload_provider.prepare_encrypted_blob(blob, user, key),
                       {:ok, file_path} <-
                         @upload_provider.prepare_file_path(entry, user.connection.id),
                       _ <- send(lv_pid, {:avatar_upload_stage, {:uploading, 85}}) do
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
                      send(lv_pid, {:avatar_upload_stage, {:error, message}})
                      {:postpone, {:nsfw, message}}

                    {:error, message} ->
                      send(lv_pid, {:avatar_upload_stage, {:error, message}})
                      {:postpone, {:error, message}}
                  end

                true ->
                  send(lv_pid, {:avatar_upload_stage, {:error, "Incorrect file type."}})
                  {:postpone, :error}
              end
          end
        end
      )

    case avatar_url_tuple_list do
      [nsfw: message] ->
        {:noreply,
         socket
         |> assign(:avatar_upload_stage, {:error, message})
         |> put_flash(:warning, message)}

      [error: message] ->
        {:noreply,
         socket
         |> assign(:avatar_upload_stage, {:error, message})
         |> put_flash(:warning, message)}

      [:error] ->
        {:noreply,
         socket
         |> assign(:avatar_upload_stage, {:error, "Incorrect file type."})
         |> put_flash(:warning, "Incorrect file type.")}

      [{_entry, file_path, e_blob}] ->
        user_params = %{avatar_url: file_path}
        send(lv_pid, {:avatar_upload_complete, {:ok, {e_blob, user_params}}})
        {:noreply, assign(socket, :avatar_upload_stage, {:uploading, 95})}

      _rest ->
        error_msg =
          "There was an error trying to upload your image, please try a different image."

        {:noreply,
         socket
         |> assign(:avatar_upload_stage, {:error, error_msg})
         |> put_flash(:warning, error_msg)}
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
             Accounts.update_user_avatar(user, %{avatar_url: nil}, delete_avatar: true) do
        AvatarProcessor.delete_ets_avatar(conn.id)
        AvatarProcessor.delete_ets_avatar("profile-#{conn.id}")

        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "avatar_cache_global",
          {:avatar_deleted, conn.id}
        )

        Storj.make_async_aws_requests(avatars_bucket, url, profile_avatar_url, user, key)

        Accounts.user_lifecycle_action("after_update_profile", user)

        {:noreply,
         socket
         |> put_flash(:success, gettext("Your avatar has been deleted successfully."))
         |> assign_avatar_form(user)
         |> push_navigate(to: ~p"/app/users/edit-details")}
      else
        {:error, :make_async_aws_requests} ->
          {:noreply, socket}

        {:error, changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, gettext("Update failed. Please check the form for issues"))
           |> assign(form: to_form(changeset))}
      end
    else
      with {:ok, _user, conn} <-
             Accounts.update_user_avatar(user, %{avatar_url: nil}, delete_avatar: true) do
        AvatarProcessor.delete_ets_avatar(conn.id)
        AvatarProcessor.delete_ets_avatar("profile-#{conn.id}")

        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "avatar_cache_global",
          {:avatar_deleted, conn.id}
        )

        Storj.make_async_aws_requests(avatars_bucket, url, user, key)

        Accounts.user_lifecycle_action("after_update_profile", user)

        {:noreply,
         socket
         |> put_flash(:success, gettext("Your avatar has been deleted successfully."))
         |> assign_avatar_form(user)
         |> push_navigate(to: ~p"/app/users/edit-details")}
      else
        {:error, changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, gettext("Update failed. Please check the form for issues"))
           |> assign(avatar_form: to_form(changeset))}
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
          {:noreply,
           socket
           |> put_flash(:success, gettext("Your name has been updated successfully."))
           |> assign_name_form(user)}

        {:error, changeset} ->
          {:noreply,
           socket
           |> put_flash(:info, gettext("There was an error when trying to update your name."))
           |> assign(name_form: to_form(changeset))}
      end
    else
      {:noreply,
       socket
       |> put_flash(:info, gettext("Your name can't be blank."))
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
          {:noreply,
           socket
           |> put_flash(:success, gettext("Your username has been updated successfully."))
           |> assign_username_form(user)
           |> push_navigate(to: ~p"/app/users/edit-details")}

        {:error, changeset} ->
          {:noreply,
           socket
           |> put_flash(:info, gettext("That username may already be taken."))
           |> assign(username_form: to_form(changeset))}
      end
    else
      {:noreply,
       socket
       |> put_flash(:info, gettext("Your username can't be blank."))
       |> assign_username_form(user)
       |> push_navigate(to: ~p"/app/users/edit-details")}
    end
  end

  defp load_image_for_avatar(path, mime_type) when mime_type in ["image/heic", "image/heif"] do
    binary = File.read!(path)

    with {:ok, {heic_image, _metadata}} <- Vix.Vips.Operation.heifload_buffer(binary),
         {:ok, materialized} <- materialize_heic(heic_image) do
      {:ok, materialized}
    else
      {:error, _reason} ->
        load_heic_with_sips(path)
    end
  end

  defp load_image_for_avatar(path, _mime_type) do
    case Image.open(path) do
      {:ok, image} -> {:ok, image}
      {:error, reason} -> {:error, "Failed to load image: #{inspect(reason)}"}
    end
  end

  defp materialize_heic(image) do
    case Image.to_colorspace(image, :srgb) do
      {:ok, srgb_image} ->
        case Image.write(srgb_image, :memory, suffix: ".png") do
          {:ok, png_binary} -> Image.from_binary(png_binary)
          {:error, _} -> fallback_heic_materialization(srgb_image)
        end

      {:error, _} ->
        fallback_heic_materialization(image)
    end
  end

  defp fallback_heic_materialization(image) do
    case Image.write(image, :memory, suffix: ".png") do
      {:ok, png_binary} ->
        Image.from_binary(png_binary)

      {:error, _} ->
        case Image.write(image, :memory, suffix: ".jpg") do
          {:ok, jpg_binary} -> Image.from_binary(jpg_binary)
          {:error, reason} -> {:error, "Failed to materialize HEIC image: #{inspect(reason)}"}
        end
    end
  end

  defp load_heic_with_sips(path) do
    tmp_png = Path.join(System.tmp_dir!(), "heic_#{:erlang.unique_integer([:positive])}.png")

    result =
      case :os.type() do
        {:unix, :darwin} ->
          case System.cmd("sips", ["-s", "format", "png", path, "--out", tmp_png],
                 stderr_to_stdout: true
               ) do
            {_output, 0} ->
              png_binary = File.read!(tmp_png)
              Image.from_binary(png_binary)

            {_output, _code} ->
              {:error, "HEIC/HEIF files are not supported. Please convert to JPEG or PNG."}
          end

        {:unix, _linux} ->
          case System.cmd("heif-convert", [path, tmp_png], stderr_to_stdout: true) do
            {_output, 0} ->
              png_binary = File.read!(tmp_png)
              Image.from_binary(png_binary)

            {_output, _code} ->
              {:error, "HEIC/HEIF files are not supported. Please convert to JPEG or PNG."}
          end

        _ ->
          {:error, "HEIC/HEIF files are not supported on this platform."}
      end

    File.rm(tmp_png)
    result
  end

  defp check_for_safety(image_binary) do
    Mosslet.AI.Images.check_for_safety(image_binary)
  end

  defp autorotate_image(image) do
    case Image.autorotate(image) do
      {:ok, {rotated_image, _flags}} -> {:ok, rotated_image}
      {:error, reason} -> {:error, "Failed to autorotate: #{inspect(reason)}"}
    end
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
