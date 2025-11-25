defmodule MossletWeb.EditProfileLive do
  @moduledoc false
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Accounts.Connection
  alias Mosslet.Encrypted
  alias Mosslet.FileUploads.Storj
  alias MossletWeb.DesignSystem

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    profile = Map.get(current_user.connection, :profile)
    banner_image = if is_nil(profile), do: :waves, else: Map.get(profile, :banner_image, :waves)

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
    <.layout current_user={@current_user} current_page={:edit_profile} key={@key} type="sidebar">
      <DesignSystem.liquid_container max_width="lg" class="py-16">
        <%!-- Page header with liquid metal styling --%>
        <div class="mb-12">
          <div class="mb-8">
            <h1 class="text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              Profile
            </h1>
            <p class="mt-4 text-lg text-slate-600 dark:text-slate-400">
              Create and manage your public profile to share your story with the MOSSLET community.
            </p>
          </div>
          <%!-- Decorative accent line --%>
          <div class="h-1 w-24 rounded-full bg-gradient-to-r from-teal-400 via-emerald-400 to-cyan-400 shadow-sm shadow-emerald-500/30">
          </div>
        </div>

        <div class="space-y-8 max-w-3xl">
          <%!-- Profile form with liquid card --%>
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
            class="space-y-8"
          >
            <DesignSystem.liquid_input
              field={@profile_form[:id]}
              type="hidden"
              value={@current_user.connection.id}
            />
            <.inputs_for :let={f_nested} field={@profile_form[:profile]}>
              <%!-- Profile Settings Card --%>
              <DesignSystem.liquid_card>
                <:title>
                  <div class="flex items-center gap-3">
                    <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-teal-100 via-emerald-50 to-cyan-100 dark:from-teal-900/30 dark:via-emerald-900/25 dark:to-cyan-900/30">
                      <.phx_icon
                        name="hero-user"
                        class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
                      />
                    </div>
                    <span>Profile Settings</span>
                    <span
                      :if={Map.get(@current_user.connection, :profile)}
                      id="profile-visibility"
                      data-tippy-content="Your current profile visibility"
                      phx-hook="TippyHook"
                      class="inline-flex px-2.5 py-0.5 text-xs rounded-lg font-medium bg-gradient-to-r from-emerald-100 to-teal-200 text-emerald-800 dark:from-emerald-800 dark:to-teal-700 dark:text-emerald-200 border border-emerald-300 dark:border-emerald-600 cursor-help"
                    >
                      {String.capitalize(Atom.to_string(@current_user.connection.profile.visibility))}
                    </span>
                    <span
                      :if={!Map.get(@current_user.connection, :profile)}
                      id="profile-visibility"
                      data-tippy-content="You do not have a profile yet. This is your current account visibility."
                      phx-hook="TippyHook"
                      class="inline-flex px-2.5 py-0.5 text-xs rounded-lg font-medium bg-gradient-to-r from-rose-100 to-pink-200 text-rose-800 dark:from-rose-800 dark:to-pink-700 dark:text-rose-200 border border-rose-300 dark:border-rose-600 cursor-help"
                    >
                      {String.capitalize(Atom.to_string(@current_user.visibility))}
                    </span>
                  </div>
                </:title>

                <div class="space-y-6">
                  <div class="space-y-4">
                    <p class="text-base text-slate-600 dark:text-slate-400">
                      Your profile is your place to share your story.
                    </p>
                    <p class="text-sm text-slate-500 dark:text-slate-500">
                      Check the badge above to know who you are currently allowing to view your profile, and hit "Update Profile" if you wish to realign it with your account's visibility setting.
                    </p>
                  </div>

                  <%!-- Hidden fields --%>
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
                  <.input
                    field={f_nested[:email]}
                    type="hidden"
                    value={decr(@current_user.email, @current_user, @key)}
                  />
                  <.input
                    :if={@current_user.name}
                    field={f_nested[:name]}
                    type="hidden"
                    value={decr(@current_user.name, @current_user, @key)}
                  />
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

                  <%!-- Profile URL Section --%>
                  <div class="space-y-3">
                    <label class="block text-sm font-medium text-slate-900 dark:text-slate-100">
                      Profile URL
                    </label>
                    <div class="flex rounded-xl overflow-hidden bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700">
                      <span
                        id="mosslet-profile-url"
                        class="flex-1 px-4 py-3 text-sm text-slate-700 dark:text-slate-300 bg-transparent"
                      >
                        https://mosslet.com/app/profile/{decr(
                          @current_user.username,
                          @current_user,
                          @key
                        )}
                      </span>
                      <button
                        type="button"
                        id="mossle-profile-url-copy"
                        class="group relative px-4 py-3 text-slate-500 hover:text-emerald-600 dark:text-slate-400 dark:hover:text-emerald-400 transition-colors duration-200 border-l border-slate-200 dark:border-slate-700 hover:bg-emerald-50 dark:hover:bg-emerald-900/20"
                        phx-hook="TippyHook"
                        data-clipboard-copy={JS.push("clipcopy")}
                        data-tippy-content="Copy to clipboard"
                        phx-click={JS.dispatch("phx:clipcopy", to: "#mosslet-profile-url")}
                      >
                        <.phx_icon name="hero-clipboard" class="h-5 w-5" />
                      </button>
                    </div>
                  </div>
                </div>
              </DesignSystem.liquid_card>

              <%!-- Banner & Appearance Card --%>
              <DesignSystem.liquid_card>
                <:title>
                  <div class="flex items-center gap-3">
                    <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-purple-100 via-violet-50 to-purple-100 dark:from-purple-900/30 dark:via-violet-900/25 dark:to-purple-900/30">
                      <.phx_icon
                        name="hero-photo"
                        class="h-4 w-4 text-purple-600 dark:text-purple-400"
                      />
                    </div>
                    Banner & Appearance
                  </div>
                </:title>

                <div id="banner-image-select" class="space-y-4">
                  <label class="block text-sm font-medium text-slate-900 dark:text-slate-100">
                    Select your banner image
                  </label>
                  <div class="max-h-80 sm:max-h-96 overflow-y-auto rounded-xl border border-slate-200 dark:border-slate-700 p-3 bg-slate-50/50 dark:bg-slate-800/50">
                    <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
                      <%= for banner <- Ecto.Enum.values(Connection.ConnectionProfile, :banner_image) do %>
                        <label class="relative cursor-pointer group">
                          <input
                            type="radio"
                            name={f_nested[:banner_image].name}
                            value={banner}
                            checked={@banner_image == banner}
                            class="sr-only peer"
                          />
                          <div class={[
                            "relative overflow-hidden rounded-xl border-2 transition-all duration-200",
                            if(@banner_image == banner,
                              do: "border-purple-400 ring-2 ring-purple-400/30",
                              else:
                                "border-slate-200 dark:border-slate-600 hover:border-purple-300 dark:hover:border-purple-500"
                            )
                          ]}>
                            <img
                              src={~p"/images/profile/#{get_banner_image(banner)}"}
                              class="w-full h-16 sm:h-20 object-cover group-hover:scale-105 transition-transform duration-300"
                              alt={"#{banner} banner"}
                            />
                            <div
                              :if={@banner_image == banner}
                              class="absolute inset-0 bg-purple-500/20 transition-opacity duration-200"
                            >
                            </div>
                            <div
                              :if={@banner_image == banner}
                              class="absolute top-1 right-1"
                            >
                              <div class="w-5 h-5 rounded-full bg-purple-500 flex items-center justify-center">
                                <.phx_icon name="hero-check" class="w-3 h-3 text-white" />
                              </div>
                            </div>
                          </div>
                          <span class="text-xs text-center mt-1.5 block capitalize text-slate-600 dark:text-slate-400 truncate">
                            {banner |> Atom.to_string() |> String.replace("_", " ")}
                          </span>
                        </label>
                      <% end %>
                    </div>
                  </div>
                  <p class="text-sm text-slate-500 dark:text-slate-400">
                    Choose a banner image that represents your personality.
                  </p>
                </div>
              </DesignSystem.liquid_card>

              <%!-- Privacy & Sharing Card --%>
              <DesignSystem.liquid_card>
                <:title>
                  <div class="flex items-center gap-3">
                    <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
                      <.phx_icon name="hero-eye" class="h-4 w-4 text-blue-600 dark:text-blue-400" />
                    </div>
                    Privacy & Sharing
                  </div>
                </:title>

                <div class="space-y-6">
                  <div>
                    <h4 class="text-sm font-medium text-slate-900 dark:text-slate-100 mb-4">
                      Select all that you would like to share
                    </h4>
                    <div class="space-y-4">
                      <DesignSystem.liquid_checkbox
                        :if={@current_user.connection.avatar_url}
                        field={f_nested[:show_avatar?]}
                        label="Show your avatar?"
                        help="Display your avatar on your profile page (deleting your avatar will disable this)."
                      />
                      <DesignSystem.liquid_checkbox
                        field={f_nested[:show_email?]}
                        label="Show your email?"
                        help="Your email may be personal, choose whether you want to display it."
                      />
                      <DesignSystem.liquid_checkbox
                        field={f_nested[:show_name?]}
                        label="Show your name?"
                        help="Display your name for future profile verification badge (TBD)."
                      />
                    </div>
                  </div>
                </div>
              </DesignSystem.liquid_card>

              <%!-- About You Card --%>
              <DesignSystem.liquid_card>
                <:title>
                  <div class="flex items-center gap-3">
                    <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-amber-100 via-orange-50 to-amber-100 dark:from-amber-900/30 dark:via-orange-900/25 dark:to-amber-900/30">
                      <.phx_icon
                        name="hero-document-text"
                        class="h-4 w-4 text-amber-600 dark:text-amber-400"
                      />
                    </div>
                    About You
                  </div>
                </:title>

                <div class="space-y-3">
                  <DesignSystem.liquid_textarea
                    field={f_nested[:about]}
                    value={@profile_about}
                    placeholder="Share your story here..."
                    rows={4}
                  />
                </div>
              </DesignSystem.liquid_card>
            </.inputs_for>

            <%!-- Action buttons --%>
            <div class="flex flex-col sm:flex-row justify-between gap-4 pt-6">
              <DesignSystem.liquid_button
                :if={@current_user.connection.profile}
                type="button"
                color="rose"
                variant="secondary"
                shimmer="page"
                phx-click="delete_profile"
                phx-value-id={@current_user.connection.id}
                data-confirm="Are you sure you want to delete your profile?"
                icon="hero-trash"
              >
                Delete Profile
              </DesignSystem.liquid_button>

              <div class="flex gap-3">
                <DesignSystem.liquid_button
                  :if={@current_user.connection.profile}
                  type="submit"
                  phx-disable-with="Updating..."
                  shimmer="page"
                  icon="hero-check"
                >
                  Update Profile
                </DesignSystem.liquid_button>

                <DesignSystem.liquid_button
                  :if={is_nil(@current_user.connection.profile)}
                  type="submit"
                  phx-disable-with="Creating..."
                  shimmer="page"
                  icon="hero-plus"
                >
                  Create Profile
                </DesignSystem.liquid_button>
              </div>
            </div>
          </.form>

          <%!-- Unconfirmed account alert --%>
          <DesignSystem.liquid_card
            :if={!@current_user.confirmed_at}
            class="border-amber-200 dark:border-amber-700 bg-gradient-to-br from-amber-50/50 to-orange-50/30 dark:from-amber-900/20 dark:to-orange-900/10"
          >
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-amber-200 to-orange-300">
                  <.phx_icon name="hero-exclamation-triangle" class="h-4 w-4 text-amber-800" />
                </div>
                <span class="text-amber-800 dark:text-amber-200">🤫 Unconfirmed account</span>
              </div>
            </:title>

            <div class="space-y-4">
              <p class="text-amber-700 dark:text-amber-300">
                {gettext(
                  "Please check your email for a confirmation link or click the button below to enter your email and send another. Once your email has been confirmed then you can get started creating your profile! 🥳"
                )}
              </p>
              <DesignSystem.liquid_button
                type="button"
                color="amber"
                variant="secondary"
                patch={~p"/auth/confirm"}
                icon="hero-envelope"
              >
                Confirm my account
              </DesignSystem.liquid_button>
            </div>
          </DesignSystem.liquid_card>
        </div>
      </DesignSystem.liquid_container>
    </.layout>
    """
  end

  def handle_event("clipcopy", _params, socket) do
    fun_emojis = ["🎉", "✨", "🚀", "💫", "⭐", "🌟", "🎊", "🎈", "🔥", "💯"]
    emoji = Enum.random(fun_emojis)

    {:noreply,
     socket
     |> put_flash(:success, "Profile URL copied to clipboard successfully! #{emoji}")}
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

      # Create the changeset with the corrected banner_image value
      corrected_profile_params =
        if params["_target"] != ["connection", "profile", "banner_image"] do
          put_in(
            profile_params,
            ["profile", "banner_image"],
            to_string(socket.assigns.banner_image)
          )
        else
          profile_params
        end

      profile_form =
        socket.assigns.current_user.connection
        |> Accounts.change_user_profile(corrected_profile_params)
        |> Map.put(:action, :validate)
        |> to_form()

      {:noreply,
       socket
       |> assign(
         banner_image: corrected_profile_params["profile"]["banner_image"] |> banner_image_atoms()
       )
       |> assign(profile_about: corrected_profile_params["profile"]["about"])
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

      # Create the changeset with the corrected banner_image value
      corrected_profile_params =
        if params["_target"] != ["connection", "profile", "banner_image"] do
          put_in(
            profile_params,
            ["profile", "banner_image"],
            to_string(socket.assigns.banner_image)
          )
        else
          profile_params
        end

      profile_form =
        socket.assigns.current_user.connection
        |> Accounts.change_user_profile(corrected_profile_params)
        |> Map.put(:action, :validate)
        |> to_form()

      {:noreply,
       socket
       |> assign(
         banner_image: corrected_profile_params["profile"]["banner_image"] |> banner_image_atoms()
       )
       |> assign(profile_about: corrected_profile_params["profile"]["about"])
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
           |> assign(profile_form: profile_form)}
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
