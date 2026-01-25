defmodule MossletWeb.EditProfileLive do
  @moduledoc false
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Accounts.Connection
  alias Mosslet.Encrypted
  alias Mosslet.FileUploads.Storj
  alias MossletWeb.DesignSystem
  alias Phoenix.LiveView.AsyncResult

  @upload_provider Mosslet.FileUploads.Storj

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    profile = Map.get(current_user.connection, :profile)
    banner_image = if is_nil(profile), do: :waves, else: Map.get(profile, :banner_image, :waves)

    socket =
      socket
      |> assign(%{
        page_title: "Settings",
        uploaded_files: [],
        profile: profile,
        banner_upload_stage: nil
      })
      |> assign(:banner_image, banner_image)
      |> assign(:banner_alt_text, nil)
      |> assign(:banner_crop, nil)
      |> assign(:banner_preview_data_url, nil)
      |> assign(:banner_original_preview_data_url, nil)
      |> assign(:banner_temp_path, nil)
      |> assign(:banner_alt_text_modal_open, false)
      |> assign(:banner_edit_modal_open, false)
      |> assign(:banner_editing_ref, nil)
      |> assign_profile_about(current_user, socket.assigns.key)
      |> assign_profile_alternate_email(current_user, socket.assigns.key)
      |> assign_profile_website_url(current_user, socket.assigns.key)
      |> assign_profile_website_label(current_user, socket.assigns.key)
      |> assign_profile_form(current_user)
      |> allow_upload(:banner,
        accept: ~w(.jpg .jpeg .png .webp .heic .heif),
        auto_upload: true,
        max_entries: 1,
        max_file_size: 10_000_000,
        writer: fn _name, entry, _socket ->
          {Mosslet.FileUploads.BannerUploadWriter,
           %{
             lv_pid: self(),
             entry_ref: entry.ref,
             expected_size: entry.client_size
           }}
        end
      )
      |> maybe_load_custom_banner_async(current_user, banner_image, profile)

    {:ok, socket}
  end

  defp maybe_load_custom_banner_async(socket, current_user, :custom, profile) do
    if profile && Map.get(profile, :custom_banner_url) do
      key = socket.assigns.key

      assign_async(socket, :custom_banner_src, fn ->
        result = load_custom_banner(current_user, key)
        {:ok, %{custom_banner_src: result}}
      end)
    else
      assign(socket, :custom_banner_src, %AsyncResult{ok?: true, result: nil})
    end
  end

  defp maybe_load_custom_banner_async(socket, _current_user, _banner_image, _profile) do
    assign(socket, :custom_banner_src, %AsyncResult{ok?: true, result: nil})
  end

  defp load_custom_banner(user, key) do
    profile = Map.get(user.connection, :profile)

    if profile && Map.get(profile, :custom_banner_url) do
      d_banner_url =
        decr_banner(
          profile.custom_banner_url,
          user,
          user.conn_key,
          key
        )

      if is_valid_banner_url?(d_banner_url) do
        case fetch_and_decrypt_banner(d_banner_url, user, key) do
          {:ok, decrypted_binary} ->
            "data:image/webp;base64,#{Base.encode64(decrypted_binary)}"

          {:error, _reason} ->
            nil
        end
      else
        nil
      end
    else
      nil
    end
  end

  def render(assigns) do
    ~H"""
    <.layout
      current_scope={@current_scope}
      current_page={:edit_profile}
      sidebar_current_page={:edit_profile}
      type="sidebar"
    >
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
                    <DesignSystem.liquid_badge
                      :if={Map.get(@current_user.connection, :profile)}
                      id="profile-visibility"
                      variant="soft"
                      color={visibility_badge_color(@current_user.connection.profile.visibility)}
                      size="sm"
                      class="cursor-help"
                      phx-hook="TippyHook"
                      data-tippy-content="Your current profile visibility"
                    >
                      {String.capitalize(Atom.to_string(@current_user.connection.profile.visibility))}
                    </DesignSystem.liquid_badge>
                    <DesignSystem.liquid_badge
                      :if={!Map.get(@current_user.connection, :profile)}
                      id="profile-visibility"
                      variant="soft"
                      color={visibility_badge_color(@current_user.visibility)}
                      size="sm"
                      class="cursor-help"
                      phx-hook="TippyHook"
                      data-tippy-content="You do not have a profile yet. This is your current account visibility."
                    >
                      {String.capitalize(Atom.to_string(@current_user.visibility))}
                    </DesignSystem.liquid_badge>
                  </div>
                </:title>

                <div class="space-y-6">
                  <div class="space-y-4">
                    <p class="text-base text-slate-600 dark:text-slate-400">
                      Your profile is your place to share your story.
                    </p>
                    <p class="text-sm text-slate-600 dark:text-slate-400">
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
                    <div
                      :if={@profile}
                      class="flex rounded-xl overflow-hidden bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700"
                    >
                      <span
                        id="mosslet-profile-url"
                        class="flex-1 px-4 py-3 text-sm text-slate-700 dark:text-slate-300 bg-transparent"
                      >
                        {MossletWeb.Endpoint.url() <>
                          "/app/profile/" <>
                          decr(
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
                        <span class="sr-only">Copy to clipboard</span>
                      </button>
                    </div>
                    <div
                      :if={!@profile}
                      class="flex items-center gap-3 rounded-xl px-4 py-3 bg-slate-50 dark:bg-slate-800 border border-dashed border-slate-300 dark:border-slate-600"
                    >
                      <.phx_icon
                        name="hero-link"
                        class="h-5 w-5 text-slate-400 dark:text-slate-500"
                      />
                      <span class="text-sm text-slate-500 dark:text-slate-400">
                        Your profile URL will appear here once you create your profile
                      </span>
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

                <div id="banner-image-select" class="space-y-6">
                  <div class="space-y-4">
                    <label class="block text-sm font-medium text-slate-900 dark:text-slate-100">
                      Choose a preset banner or upload your own
                    </label>
                    <div class="max-h-80 sm:max-h-96 overflow-y-auto rounded-xl border border-slate-200 dark:border-slate-700 p-3 bg-slate-50/50 dark:bg-slate-800/50">
                      <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
                        <%= for banner <- Ecto.Enum.values(Connection.ConnectionProfile, :banner_image) |> Enum.reject(&(&1 == :custom)) do %>
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
                  </div>

                  <div class="border-t border-slate-200 dark:border-slate-700 pt-6">
                    <p :if={is_nil(@profile)} class="text-sm text-slate-500 dark:text-slate-400">
                      Create your profile to upload a custom banner.
                    </p>

                    <div :if={@profile} class="flex items-center gap-3 mb-4">
                      <label class="relative cursor-pointer group flex items-center gap-3">
                        <input
                          type="radio"
                          name={f_nested[:banner_image].name}
                          value="custom"
                          checked={@banner_image == :custom}
                          class="sr-only peer"
                        />
                        <div class={[
                          "w-5 h-5 rounded-full border-2 flex items-center justify-center transition-all duration-200",
                          if(@banner_image == :custom,
                            do: "border-purple-500 bg-purple-500",
                            else: "border-slate-300 dark:border-slate-600"
                          )
                        ]}>
                          <div
                            :if={@banner_image == :custom}
                            class="w-2 h-2 rounded-full bg-white"
                          >
                          </div>
                        </div>
                        <span class="text-sm font-medium text-slate-900 dark:text-slate-100">
                          Use custom banner image
                        </span>
                      </label>
                    </div>

                    <div :if={@banner_image == :custom && @profile} class="space-y-4">
                      <DesignSystem.liquid_banner_upload
                        upload={@uploads.banner}
                        upload_stage={@banner_upload_stage}
                        current_banner_src={get_async_banner_src(@custom_banner_src)}
                        banner_loading={@custom_banner_src.loading}
                        user={@current_user}
                        encryption_key={@key}
                        on_delete="delete_banner"
                        url={
                          if @profile && Map.get(@profile, :custom_banner_url),
                            do:
                              decr_banner(
                                @profile.custom_banner_url,
                                @current_user,
                                @current_user.conn_key,
                                @key
                              ),
                            else: nil
                        }
                        alt_text={@banner_alt_text}
                        crop={@banner_crop}
                        preview_data_url={@banner_preview_data_url}
                      />
                      <div
                        :if={
                          Enum.any?(@uploads.banner.entries) && !is_processing?(@banner_upload_stage)
                        }
                        class="flex justify-end"
                      >
                        <DesignSystem.liquid_button
                          type="button"
                          phx-click="upload_banner"
                          phx-disable-with="Uploading..."
                          color="purple"
                          icon="hero-cloud-arrow-up"
                        >
                          Upload Banner
                        </DesignSystem.liquid_button>
                      </div>
                    </div>

                    <p
                      :if={@banner_image != :custom && @profile}
                      class="text-sm text-slate-500 dark:text-slate-400 mt-2"
                    >
                      Select "Use custom banner image" to upload your own banner.
                    </p>
                  </div>
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
                    <h2 class="text-sm font-medium text-slate-900 dark:text-slate-100 mb-4">
                      Select all that you would like to share
                    </h2>
                    <div class="space-y-4">
                      <DesignSystem.liquid_checkbox
                        :if={@current_user.connection.avatar_url}
                        field={f_nested[:show_avatar?]}
                        label="Show your avatar?"
                        help="Display your avatar on your profile and posts (deleting your avatar will disable this)."
                      />
                      <DesignSystem.liquid_checkbox
                        field={f_nested[:show_email?]}
                        label="Show your email?"
                        help="Your email may be personal, choose whether you want to display it."
                      />
                      <DesignSystem.liquid_checkbox
                        field={f_nested[:show_name?]}
                        label="Show your name?"
                        help="Display your name on your profile and posts"
                      />
                    </div>
                  </div>
                </div>
              </DesignSystem.liquid_card>

              <%!-- Contact & Links Card --%>
              <DesignSystem.liquid_card>
                <:title>
                  <div class="flex items-center gap-3">
                    <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-violet-100 via-purple-50 to-violet-100 dark:from-violet-900/30 dark:via-purple-900/25 dark:to-violet-900/30">
                      <.phx_icon
                        name="hero-link"
                        class="h-4 w-4 text-violet-600 dark:text-violet-400"
                      />
                    </div>
                    Contact & Links
                  </div>
                </:title>

                <div class="space-y-6">
                  <div class="space-y-3">
                    <DesignSystem.liquid_input
                      field={f_nested[:alternate_email]}
                      type="email"
                      label="Contact Email"
                      value={@profile_alternate_email}
                      placeholder="contact@example.com"
                    />
                    <p class="text-sm text-slate-500 dark:text-slate-400">
                      Add an alternative email for others to reach you. This keeps your account email private.
                    </p>
                  </div>

                  <div class="space-y-3">
                    <DesignSystem.liquid_input
                      field={f_nested[:website_url]}
                      type="url"
                      label="Website URL"
                      value={@profile_website_url}
                      placeholder="https://yourwebsite.com"
                      phx_debounce="500"
                    />
                    <p class="text-sm text-slate-500 dark:text-slate-400">
                      Share a link to your website, portfolio, or something else.
                    </p>
                  </div>

                  <div class="space-y-3">
                    <DesignSystem.liquid_input
                      field={f_nested[:website_label]}
                      type="text"
                      label="Link Label"
                      value={@profile_website_label}
                      placeholder="My Portfolio"
                    />
                    <p class="text-sm text-slate-500 dark:text-slate-400">
                      Add a short label to describe your link (e.g., "My Blog", "GitHub", "Portfolio").
                    </p>
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
                  disabled={not @profile_form.source.valid?}
                >
                  Update Profile
                </DesignSystem.liquid_button>

                <DesignSystem.liquid_button
                  :if={is_nil(@current_user.connection.profile)}
                  type="submit"
                  phx-disable-with="Creating..."
                  shimmer="page"
                  icon="hero-plus"
                  disabled={not @profile_form.source.valid?}
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

      <DesignSystem.liquid_alt_text_modal
        show={@banner_alt_text_modal_open}
        upload={
          build_banner_upload_map(
            List.first(@uploads.banner.entries),
            @banner_alt_text,
            @banner_preview_data_url
          )
        }
        alt_text={@banner_alt_text || ""}
        id="banner-alt-text-modal"
      />

      <DesignSystem.liquid_image_edit_modal
        show={@banner_edit_modal_open}
        upload={
          build_banner_upload_map(
            List.first(@uploads.banner.entries),
            @banner_alt_text,
            @banner_preview_data_url
          )
        }
        crop={@banner_crop || %{}}
        id="banner-image-edit-modal"
      />
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
    user = socket.assigns.current_scope.user

    if Map.get(user.connection, :profile) do
      profile_params =
        profile_params
        |> Map.put(
          "profile",
          Map.put(profile_params["profile"], "opts_map", %{
            user: user,
            key: socket.assigns.current_scope.key,
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
        user.connection
        |> Accounts.change_user_profile(corrected_profile_params)
        |> Map.put(:action, :validate)
        |> to_form()

      {:noreply,
       socket
       |> assign(
         banner_image: corrected_profile_params["profile"]["banner_image"] |> banner_image_atoms()
       )
       |> assign(profile_about: corrected_profile_params["profile"]["about"])
       |> assign(profile_alternate_email: corrected_profile_params["profile"]["alternate_email"])
       |> assign(profile_website_url: corrected_profile_params["profile"]["website_url"])
       |> assign(profile_website_label: corrected_profile_params["profile"]["website_label"])
       |> assign(profile_form: profile_form)}
    else
      profile_params =
        profile_params
        |> Map.put(
          "profile",
          Map.put(profile_params["profile"], "opts_map", %{
            user: user,
            key: socket.assigns.current_scope.key
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
        user.connection
        |> Accounts.change_user_profile(corrected_profile_params)
        |> Map.put(:action, :validate)
        |> to_form()

      {:noreply,
       socket
       |> assign(
         banner_image: corrected_profile_params["profile"]["banner_image"] |> banner_image_atoms()
       )
       |> assign(profile_about: corrected_profile_params["profile"]["about"])
       |> assign(profile_alternate_email: corrected_profile_params["profile"]["alternate_email"])
       |> assign(profile_website_url: corrected_profile_params["profile"]["website_url"])
       |> assign(profile_website_label: corrected_profile_params["profile"]["website_label"])
       |> assign(profile_form: profile_form)}
    end
  end

  def handle_event("update_profile", params, socket) do
    %{"connection" => profile_params} = params
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key
    profile = user.connection.profile

    old_banner_image = if profile, do: Map.get(profile, :banner_image), else: nil
    old_custom_banner_url = if profile, do: Map.get(profile, :custom_banner_url), else: nil

    new_banner_image =
      profile_params
      |> get_in(["profile", "banner_image"])
      |> banner_image_atoms()

    profile_params =
      profile_params
      |> Map.put(
        "profile",
        Map.put(profile_params["profile"], "opts_map", %{
          user: user,
          key: key,
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
          if old_banner_image == :custom and old_custom_banner_url != nil and
               new_banner_image != :custom do
            delete_old_custom_banner(user, key, old_custom_banner_url)
          end

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
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    profile_params =
      profile_params
      |> Map.put(
        "profile",
        Map.put(profile_params["profile"], "opts_map", %{
          user: user,
          key: key,
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
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

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

  def handle_event("cancel-banner-upload", %{"ref" => ref}, socket) do
    {:noreply,
     socket
     |> cancel_upload(:banner, ref)
     |> assign(:banner_upload_stage, nil)
     |> assign(:banner_alt_text, nil)
     |> assign(:banner_crop, nil)
     |> assign(:banner_preview_data_url, nil)
     |> assign(:banner_temp_path, nil)}
  end

  def handle_event("open_banner_alt_text_modal", %{"ref" => ref}, socket) do
    {:noreply,
     socket
     |> assign(:banner_alt_text_modal_open, true)
     |> assign(:banner_editing_ref, ref)}
  end

  def handle_event("close_alt_text_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:banner_alt_text_modal_open, false)
     |> assign(:banner_editing_ref, nil)}
  end

  def handle_event("save_alt_text", %{"alt_text" => alt_text}, socket) do
    {:noreply,
     socket
     |> assign(:banner_alt_text, String.trim(alt_text))
     |> assign(:banner_alt_text_modal_open, false)
     |> assign(:banner_editing_ref, nil)}
  end

  def handle_event("open_banner_edit_modal", %{"ref" => ref}, socket) do
    {:noreply,
     socket
     |> assign(:banner_edit_modal_open, true)
     |> assign(:banner_editing_ref, ref)}
  end

  def handle_event("close_image_edit_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:banner_edit_modal_open, false)
     |> assign(:banner_editing_ref, nil)}
  end

  def handle_event("save_image_crop", %{"crop" => crop}, socket) do
    crop_map =
      case crop do
        %{"x" => x, "y" => y, "width" => w, "height" => h} ->
          %{x: x, y: y, width: w, height: h}

        _ ->
          %{}
      end

    socket =
      if crop_map != %{} && socket.assigns.banner_temp_path do
        case generate_cropped_preview(socket.assigns.banner_temp_path, crop_map) do
          {:ok, cropped_preview} ->
            socket
            |> assign(:banner_crop, crop_map)
            |> assign(:banner_preview_data_url, cropped_preview)

          _ ->
            assign(socket, :banner_crop, crop_map)
        end
      else
        assign(socket, :banner_crop, crop_map)
      end

    {:noreply,
     socket
     |> assign(:banner_edit_modal_open, false)
     |> assign(:banner_editing_ref, nil)}
  end

  def handle_event("upload_banner", _params, socket) do
    entries = socket.assigns.uploads.banner.entries
    in_progress? = Enum.any?(entries, &(&1.progress < 100))

    if entries == [] or in_progress? do
      {:noreply, socket}
    else
      do_upload_banner(socket)
    end
  end

  def handle_event("delete_banner", %{"url" => url}, socket) do
    banners_bucket = Encrypted.Session.banners_bucket()
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    profile_attrs =
      %{
        "profile" => %{
          "custom_banner_url" => nil,
          "banner_image" => "waves"
        }
      }

    case Accounts.update_user_profile(user, profile_attrs,
           key: key,
           user: user,
           update_profile: true
         ) do
      {:ok, _conn} ->
        Storj.make_async_banner_delete_request(banners_bucket, url)
        Mosslet.Extensions.BannerProcessor.delete_banner(user.connection.id)

        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "banner_cache_global",
          {:banner_deleted, user.connection.id}
        )

        {:noreply,
         socket
         |> put_flash(:success, gettext("Your custom banner has been deleted successfully."))
         |> assign(:banner_image, :waves)
         |> push_navigate(to: ~p"/app/users/edit-profile")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Failed to delete banner. Please try again."))}
    end
  end

  def handle_info({:banner_upload_progress, _ref, stage, percent}, socket) do
    {:noreply, assign(socket, :banner_upload_stage, {stage, percent})}
  end

  def handle_info(
        {:banner_upload_ready, _ref, %{temp_path: temp_path, preview_data_url: preview}},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:banner_temp_path, temp_path)
     |> assign(:banner_preview_data_url, preview)
     |> assign(:banner_original_preview_data_url, preview)
     |> assign(:banner_upload_stage, nil)}
  end

  def handle_info({:banner_upload_error, _ref, reason}, socket) do
    {:noreply,
     socket
     |> assign(:banner_upload_stage, {:error, reason})
     |> put_flash(:warning, to_string(reason))}
  end

  def handle_info({:banner_upload_stage, stage}, socket) do
    {:noreply, assign(socket, :banner_upload_stage, stage)}
  end

  def handle_info(
        {:banner_upload_complete, {:ok, {e_blob, file_path, encrypted_alt_text}}},
        socket
      ) do
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key
    profile = Map.get(user.connection, :profile)

    if is_nil(profile) do
      {:noreply,
       socket
       |> assign(:banner_upload_stage, {:error, "Please create your profile first"})
       |> put_flash(
         :warning,
         gettext(
           "Please create your profile first by clicking 'Create Profile', then you can upload a custom banner."
         )
       )}
    else
      {:ok, d_conn_key} =
        Encrypted.Users.Utils.decrypt_user_attrs_key(user.conn_key, user, key)

      encrypted_file_path = Encrypted.Utils.encrypt(%{key: d_conn_key, payload: file_path})

      profile_attrs =
        %{
          "profile" => %{
            "custom_banner_url" => encrypted_file_path,
            "custom_banner_alt_text" => encrypted_alt_text,
            "banner_image" => "custom"
          }
        }

      case Accounts.update_user_profile(user, profile_attrs,
             key: key,
             user: user,
             update_profile: true
           ) do
        {:ok, _conn} ->
          Mosslet.Extensions.BannerProcessor.put_banner(user.connection.id, e_blob)

          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "banner_cache_global",
            {:banner_updated, user.connection.id, e_blob}
          )

          {:noreply,
           socket
           |> assign(:banner_upload_stage, {:ready, 100})
           |> put_flash(:success, gettext("Your custom banner has been uploaded successfully."))
           |> push_navigate(to: ~p"/app/users/edit-profile")}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> assign(:banner_upload_stage, {:error, "Update failed"})
           |> put_flash(:error, gettext("Failed to save banner. Please try again."))}
      end
    end
  end

  def handle_info({:banner_upload_complete, {:error, error}}, socket) do
    {:noreply,
     socket
     |> assign(:banner_upload_stage, {:error, error})
     |> put_flash(:warning, error)}
  end

  defp do_upload_banner(socket) do
    temp_path = socket.assigns.banner_temp_path
    crop = socket.assigns.banner_crop

    if is_nil(temp_path) do
      {:noreply,
       socket
       |> put_flash(:warning, "No image selected. Please choose an image first.")}
    else
      process_and_upload_banner(socket, temp_path, crop)
    end
  end

  defp process_and_upload_banner(socket, temp_path, crop) do
    lv_pid = self()
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key
    banners_bucket = Encrypted.Session.banners_bucket()
    entry = List.first(socket.assigns.uploads.banner.entries)

    socket = assign(socket, :banner_upload_stage, {:receiving, 10})

    Task.start(fn ->
      result =
        with {:ok, image} <- Image.open(temp_path),
             send(lv_pid, {:banner_upload_stage, {:converting, 30}}),
             {:ok, image} <- maybe_apply_crop(image, crop),
             send(lv_pid, {:banner_upload_stage, {:checking, 50}}),
             {:ok, safe_image} <- check_for_safety(image),
             send(lv_pid, {:banner_upload_stage, {:resizing, 60}}),
             {:ok, resized_image} <- resize_banner_image(safe_image),
             {:ok, blob} <-
               Image.write(resized_image, :memory,
                 suffix: ".webp",
                 minimize_file_size: true
               ),
             send(lv_pid, {:banner_upload_stage, {:encrypting, 75}}),
             {:ok, e_blob} <- @upload_provider.prepare_encrypted_blob(blob, user, key),
             {:ok, file_path} <-
               @upload_provider.prepare_banner_file_path(entry, user.connection.id),
             send(lv_pid, {:banner_upload_stage, {:uploading, 85}}),
             {:ok, _} <-
               @upload_provider.make_banner_aws_requests(
                 entry,
                 banners_bucket,
                 file_path,
                 e_blob,
                 user,
                 key
               ) do
          Mosslet.FileUploads.TempStorage.cleanup(temp_path)
          {:ok, file_path, e_blob}
        else
          {:nsfw, message} ->
            {:error, message}

          {:error, message} ->
            {:error, message}
        end

      case result do
        {:ok, file_path, e_blob} ->
          banner_alt_text = socket.assigns.banner_alt_text
          encrypted_alt_text = maybe_encrypt_banner_alt_text(banner_alt_text, user, key)
          send(lv_pid, {:banner_upload_complete, {:ok, {e_blob, file_path, encrypted_alt_text}}})

        {:error, message} ->
          send(lv_pid, {:banner_upload_complete, {:error, message}})
      end
    end)

    {:noreply, socket}
  end

  defp maybe_apply_crop(image, nil), do: {:ok, image}
  defp maybe_apply_crop(image, crop) when crop == %{}, do: {:ok, image}

  defp maybe_apply_crop(image, %{x: x, y: y, width: w, height: h}) do
    Image.crop(image, x, y, w, h)
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

  defp assign_profile_alternate_email(socket, user, key) do
    assign(socket,
      profile_alternate_email: maybe_decrypt_profile_field(user, key, :alternate_email)
    )
  end

  defp assign_profile_website_url(socket, user, key) do
    assign(socket, profile_website_url: maybe_decrypt_profile_field(user, key, :website_url))
  end

  defp assign_profile_website_label(socket, user, key) do
    assign(socket, profile_website_label: maybe_decrypt_profile_field(user, key, :website_label))
  end

  defp maybe_decrypt_profile_field(user, key, field) do
    profile = Map.get(user.connection, :profile)

    cond do
      profile && not is_nil(Map.get(profile, field)) ->
        field_value = Map.get(profile, field)

        cond do
          profile.visibility == :public ->
            decr_public_item(field_value, profile.profile_key)

          profile.visibility == :private ->
            decr_item(field_value, user, profile.profile_key, key, profile)

          profile.visibility == :connections ->
            decr_item(field_value, user, profile.profile_key, key, profile)

          true ->
            field_value
        end

      true ->
        nil
    end
  end

  defp assign_profile_form(socket, user) do
    assign(socket, profile_form: to_form(Accounts.change_user_profile(user.connection)))
  end

  defp visibility_badge_color(visibility) do
    case visibility do
      :public -> "blue"
      :connections -> "emerald"
      :private -> "rose"
      _ -> "slate"
    end
  end

  defp is_processing?(nil), do: false
  defp is_processing?({:ready, _}), do: false
  defp is_processing?({:error, _}), do: false
  defp is_processing?(_), do: true

  defp get_async_banner_src(%AsyncResult{ok?: true, result: result}), do: result
  defp get_async_banner_src(_), do: nil

  defp is_valid_banner_url?(nil), do: false
  defp is_valid_banner_url?(""), do: false
  defp is_valid_banner_url?("failed_verification"), do: false
  defp is_valid_banner_url?(url) when is_binary(url), do: String.starts_with?(url, "uploads/")
  defp is_valid_banner_url?(_), do: false

  defp fetch_and_decrypt_banner(banner_url, user, key) do
    banners_bucket = Encrypted.Session.banners_bucket()
    host = Encrypted.Session.s3_host()
    host_name = "https://#{banners_bucket}.#{host}"

    config = %{
      region: Encrypted.Session.s3_region(),
      access_key_id: Encrypted.Session.s3_access_key_id(),
      secret_access_key: Encrypted.Session.s3_secret_key_access()
    }

    options = [
      virtual_host: true,
      bucket_as_host: true,
      expires_in: 600
    ]

    {:ok, presigned_url} = ExAws.S3.presigned_url(config, :get, host_name, banner_url, options)

    case Req.get(presigned_url,
           retry: :transient,
           retry_delay: fn n -> n * 500 end,
           receive_timeout: 15_000
         ) do
      {:ok, %{status: 200, body: encrypted_binary}} ->
        {:ok, d_conn_key} =
          Encrypted.Users.Utils.decrypt_user_attrs_key(user.conn_key, user, key)

        case Encrypted.Utils.decrypt(%{key: d_conn_key, payload: encrypted_binary}) do
          {:ok, decrypted} -> {:ok, decrypted}
          error -> error
        end

      {:ok, %{status: status}} ->
        {:error, "Failed to fetch banner: HTTP #{status}"}

      {:error, reason} ->
        {:error, "Failed to fetch banner: #{inspect(reason)}"}
    end
  end

  defp check_for_safety(image_binary) do
    Mosslet.AI.Images.check_for_safety(image_binary)
  end

  defp resize_banner_image(image) do
    {width, height, _bands} = Image.shape(image)

    cond do
      width >= 1500 && height >= 500 ->
        Image.thumbnail(image, 1500, height: 500, crop: :attention)

      width >= 1200 ->
        target_height = round(width / 3)
        Image.thumbnail(image, width, height: target_height, crop: :attention)

      true ->
        {:ok, image}
    end
  end

  defp delete_old_custom_banner(user, key, encrypted_banner_url) do
    banners_bucket = Encrypted.Session.banners_bucket()

    banner_url =
      decr_banner(
        encrypted_banner_url,
        user,
        user.conn_key,
        key
      )

    if is_valid_banner_url?(banner_url) do
      Storj.make_async_banner_delete_request(banners_bucket, banner_url)
      Mosslet.Extensions.BannerProcessor.delete_banner(user.connection.id)

      Phoenix.PubSub.broadcast(
        Mosslet.PubSub,
        "banner_cache_global",
        {:banner_deleted, user.connection.id}
      )
    end
  end

  defp build_banner_upload_map(nil, _alt_text, _preview_url), do: nil

  defp build_banner_upload_map(entry, alt_text, preview_url) do
    %{
      ref: entry.ref,
      alt_text: alt_text,
      preview_data_url: preview_url,
      entry: entry
    }
  end

  defp generate_cropped_preview(nil, _crop), do: {:error, :no_path}

  defp generate_cropped_preview(path, %{x: x, y: y, width: w, height: h}) do
    with {:ok, image} <- Image.open(path),
         {:ok, cropped} <- Image.crop(image, x, y, w, h),
         {:ok, binary} <- Image.write(cropped, :memory, suffix: ".jpg", quality: 90) do
      {:ok, "data:image/jpeg;base64,#{Base.encode64(binary)}"}
    end
  end

  defp generate_cropped_preview(_path, _crop), do: {:error, :invalid_crop}

  defp maybe_encrypt_banner_alt_text(nil, _user, _key), do: nil
  defp maybe_encrypt_banner_alt_text("", _user, _key), do: nil

  defp maybe_encrypt_banner_alt_text(alt_text, user, key) do
    {:ok, d_conn_key} = Encrypted.Users.Utils.decrypt_user_attrs_key(user.conn_key, user, key)
    Encrypted.Utils.encrypt(%{key: d_conn_key, payload: alt_text})
  end
end
