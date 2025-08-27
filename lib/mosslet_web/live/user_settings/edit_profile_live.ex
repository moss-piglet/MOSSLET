defmodule MossletWeb.EditProfileLive do
  @moduledoc false
  use MossletWeb, :live_view

  import MossletWeb.UserSettingsLayoutComponent

  alias Mosslet.Accounts
  alias Mosslet.Accounts.Connection
  alias Mosslet.Encrypted
  alias Mosslet.FileUploads.Storj

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    profile = Map.get(current_user.connection, :profile)
    banner_image = if is_nil(profile), do: "", else: Map.get(profile, :banner_image)

    socket =
      socket
      |> assign(%{
        page_title: "Settings",
        uploaded_files: []
      })
      |> assign(:banner_image, banner_image)
      |> assign_profile_about(current_user, socket.assigns.key)
      |> assign_profile_form(current_user)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.settings_layout current_page={:edit_profile} current_user={@current_user} key={@key}>
      <.form
        :if={@current_user.confirmed_at}
        for={@profile_form}
        id="profile_form"
        phx-change="validate_profile"
        phx-submit={
          if Map.get(@current_user.connection, :profile),
            do: "update_profile",
            else: "create_profile"
        }
        class="max-w-lg"
      >
        <.input field={@profile_form[:id]} type="hidden" value={@current_user.connection.id} />
        <.inputs_for :let={f_nested} field={@profile_form[:profile]}>
          <div class="pb-12">
            <h2 class="text-base font-semibold leading-7 text-gray-900 dark:text-white">
              Profile
              <span
                :if={Map.get(@current_user.connection, :profile)}
                id="profile-visibility"
                data-tippy-content="Your current profile visibility"
                phx-hook="TippyHook"
                class="inline-flex items-center rounded-md cursor-help bg-emerald-100 px-2 py-1 ml-2 text-xs font-medium text-emerald-800"
              >
                {String.capitalize(Atom.to_string(@current_user.connection.profile.visibility))}
              </span>
              <span
                :if={!Map.get(@current_user.connection, :profile)}
                id="profile-visibility"
                data-tippy-content="You do not have a profile yet. This is your current account visibility."
                phx-hook="TippyHook"
                class="inline-flex items-center rounded-md cursor-help bg-pink-100 px-2 py-1 ml-2 text-xs font-medium text-pink-800"
              >
                {String.capitalize(Atom.to_string(@current_user.visibility))}
              </span>
            </h2>
            <.p class="pt-4">
              Your profile is your place to share your story.
            </.p>
            <.p>
              Check the badge above to know who you are currently allowing to view your profile, and hit "Update Profile" if you wish to realign it with your account's visiblity setting.
            </.p>

            <.field
              :if={@current_user.connection.avatar_url}
              field={f_nested[:avatar_url]}
              type="hidden"
              value={
                decr_avatar(
                  @current_user.connection.avatar_url,
                  @current_user,
                  @current_user.conn_key,
                  @key
                )
              }
            />
            <.field
              field={f_nested[:email]}
              type="hidden"
              value={decr(@current_user.email, @current_user, @key)}
            />
            <.field
              :if={@current_user.name}
              field={f_nested[:name]}
              type="hidden"
              value={decr(@current_user.name, @current_user, @key)}
            />

            <div class="mt-10">
              <div class="">
                <label
                  for="username"
                  class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
                >
                  Profile URL
                </label>
                <div class="mt-2 pb-4">
                  <div class="flex rounded-md shadow-sm ring-1 ring-inset ring-gray-300 dark:ring-gray-600 focus-within:ring-2 focus-within:ring-inset focus-within:ring-emerald-600 sm:max-w-md">
                    <span
                      id="mosslet-profile-url"
                      class="flex-1 border-0 bg-transparent py-1.5 ml-3 text-gray-800 dark:text-gray-200 placeholder:text-gray-500 dark:placeholder:text-gray-300 focus:ring-0 sm:text-sm sm:leading-6"
                    >
                      https://mosslet.com/app/profile/{decr(
                        @current_user.username,
                        @current_user,
                        @key
                      )}
                    </span>
                    <span
                      id="mossle-profile-url-copy"
                      class="inline-flex py-1.5 mr-1 cursor-pointer"
                      phx-hook="TippyHook"
                      data-clipboard-copy={JS.push("clipcopy")}
                      data-tippy-content="Copy to cliboard"
                      phx-click={JS.dispatch("phx:clipcopy", to: "#mosslet-profile-url")}
                    >
                      <.phx_icon name="hero-clipboard" />
                    </span>

                    <.input
                      field={f_nested[:username]}
                      type="hidden"
                      value={decr(@current_user.username, @current_user, @key)}
                    />
                    <.input
                      field={f_nested[:temp_username]}
                      type="hidden"
                      value={decr(@current_user.username, @current_user, @key)}
                    />
                    <.input
                      field={f_nested[:visibility]}
                      type="hidden"
                      value={@current_user.visibility}
                    />
                    <.input field={f_nested[:user_id]} type="hidden" value={@current_user.id} />
                  </div>
                </div>

                <div id="banner-image-select" class="py-4">
                  <.field
                    field={f_nested[:banner_image]}
                    type="select"
                    options={Ecto.Enum.values(Connection.ConnectionProfile, :banner_image)}
                    label="Select your banner image"
                  />

                  <img
                    :if={@banner_image}
                    id="forest"
                    src={~p"/images/profile/#{get_banner_image(@banner_image)}"}
                    class="h-20 w-40 rounded-md"
                  />
                </div>

                <div class="sharing-selections" class="py-4">
                  <label
                    for="profile_settings"
                    class="block py-4 text-sm font-medium leading-6 text-gray-900 dark:text-white"
                  >
                    Select all that you would like to share
                  </label>

                  <.field
                    :if={@current_user.connection.avatar_url}
                    field={f_nested[:show_avatar?]}
                    type="checkbox"
                    label="Show your avatar?"
                  />

                  <.field field={f_nested[:show_email?]} type="checkbox" label="Show your email?" />

                  <.field field={f_nested[:show_name?]} type="checkbox" label="Show your name?" />
                  <.field
                    field={f_nested[:show_public_memories?]}
                    type="checkbox"
                    label="Show your public Memories?"
                    help_text="Public Memories are a potential feature in the future (TBD)."
                  />
                  <.field
                    field={f_nested[:show_public_posts?]}
                    type="checkbox"
                    label="Show your public Posts?"
                    help_text="Public Posts are a potential feature in the future (TBD)."
                  />
                </div>
              </div>

              <div class="col-span-full">
                <label
                  for="connection[about]"
                  class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
                >
                  About you
                </label>
                <div class="mt-2">
                  <.phx_input
                    field={f_nested[:about]}
                    value={@profile_about}
                    type="textarea"
                    rows="3"
                    apply_classes?={true}
                    placeholder="Share your story here."
                    classes="block w-full rounded-md border-0 py-1.5 text-gray-900 dark:text-white shadow-sm ring-2 ring-inset ring-gray-300 placeholder:text-zinc-400 focus:ring-2 focus:ring-inset focus:ring-emerald-600 sm:text-sm sm:leading-6 dark:bg-gray-800"
                  />
                </div>
              </div>
            </div>
          </div>
        </.inputs_for>
          <div class="flex justify-between">
          <.link
            :if={@current_user.connection.profile}
            phx-disable-with="Deleting..."
            data-confirm="Are you sure you want to delete your profile?"
            class="rounded-full bg-rose-600 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-rose-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-rose-600"
            phx-click="delete_profile"
            phx-value-id={@current_user.connection.id}
          >
            Delete Profile
          </.link>
          <.button
            :if={@current_user.connection.profile}
            phx-disable-with="Updating..."
            class="rounded-full"
          >
            Update Profile
          </.button>
          <.button
            :if={is_nil(@current_user.connection.profile)}
            phx-disable-with="Creating..."
            class="rounded-full"
          >
            Create Profile
          </.button>
          </div>
      </.form>
      <.alert
        :if={!@current_user.confirmed_at}
        color="warning"
        class="my-5"
        heading={gettext("🤫 Unconfirmed account")}
      >
        {gettext(
          "Please check your email for a confirmation link or click the button below to enter your email and send another. Once your email has been confirmed then you can get started creating your profile! 🥳"
        )}
        <.button
          type="button"
          color="secondary"
          class="block mt-4"
          phx-click={JS.patch(~p"/auth/confirm")}
        >
          Confirm my account
        </.button>
      </.alert>
    </.settings_layout>
    """
  end

  def handle_event("clipcopy", _params, socket) do
    {:noreply, Toast.put_toast(socket, :success, "Profile URL copied to clipboard successfully.")}
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
       |> assign(banner_image: banner_image_atoms(profile_params["profile"]["banner_image"]))
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
       |> assign(banner_image: banner_image_atoms(profile_params["profile"]["banner_image"]))
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
           |> push_navigate(to: ~p"/app/users/edit-profile")}
      end
    else
      info = "Woops, you need to confirm your account first."

      {:noreply,
       socket
       |> put_flash(:error, info)
       |> push_navigate(to: ~p"/app/users/edit-profile")}
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
           |> push_navigate(to: ~p"/app/users/edit-profile")}
      end
    else
      info = "Woops, you need to confirm your account first."

      {:noreply,
       socket
       |> put_flash(:error, info)
       |> push_navigate(to: ~p"/app/users/edit-profile")}
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
            Storj.make_async_aws_requests(avatars_bucket, avatar_url, nil, nil)

            info =
              "Your profile has been deleted successfully."

            {:noreply,
             socket
             |> put_flash(:success, info)
             |> assign(profile_form: profile_form)
             |> push_navigate(to: ~p"/app/users/edit-profile")}
          else
            info = "Your profile has been deleted successfully."

            {:noreply,
             socket
             |> put_flash(:success, info)
             |> assign(profile_form: profile_form)
             |> push_navigate(to: ~p"/app/users/edit-profile")}
          end
      end
    else
      info = "You don't have permission to do this."

      {:noreply,
       socket |> put_flash(:warning, info) |> push_navigate(to: "/app/users/edit-profile")}
    end
  end

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

  def valid_banner_image_atoms do
    [:geranium, :lupin, :mountains, :shoreline, :waves]
  end

  defp banner_image_atoms(value) when is_binary(value) do
    String.to_existing_atom(value)
  end

  defp assign_profile_about(socket, user, key) do
    assign(socket, profile_about: maybe_decrypt_profile_about(user, key))
  end

  defp assign_profile_form(socket, user) do
    assign(socket, profile_form: to_form(Accounts.change_user_profile(user.connection)))
  end
end
