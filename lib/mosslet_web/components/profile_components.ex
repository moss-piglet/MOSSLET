defmodule MossletWeb.ProfileComponents do
  @moduledoc """
  Function components for the user profile page (`MossletWeb.UserHomeLive`).

  The profile page renders one of three real variants depending on *who is
  viewing whom*, surfaced as `@profile.access` on the
  `MossletWeb.UserHomeLive.ProfileViewModel`:

    * `:own`         — the owner viewing their own profile. Identity is decrypted
                       server-side (fast path) while profile detail fields are
                       sealed for the browser-side `DecryptProfileFields` /
                       `DecryptAvatar` ZK hooks.
    * `:connections` — a connection viewing a `:connections`-visibility profile.
                       Identity + detail fields are sealed with the viewer's
                       per-connection key for browser-side decryption.
    * `:public`      — anyone viewing a `:public` profile. Identity + detail
                       fields are decrypted server-side (intentionally public),
                       so **no** browser-side decrypt hooks are emitted.

  These components are deliberately variant-aware (they branch on
  `@profile.access`) rather than a naive merge: the zero-knowledge paths and the
  user record driving identity genuinely differ per variant. They are kept
  composable/standalone so the Phase 5 dashboard can reuse the hero/header/cards
  for a compact profile summary.
  """
  use Phoenix.Component
  use MossletWeb, :verified_routes

  import MossletWeb.CoreComponents, only: [phx_icon: 1]

  import MossletWeb.DesignSystem,
    only: [
      liquid_avatar: 1,
      liquid_badge: 1,
      liquid_button: 1,
      liquid_card: 1
    ]

  import MossletWeb.MediaComponents, only: [website_url_preview: 1]

  import MossletWeb.Helpers,
    only: [get_banner_image_for_connection: 1, get_encrypted_avatar_data: 2]

  import MossletWeb.Helpers.StatusHelpers,
    only: [
      can_view_status?: 3,
      get_encrypted_status_data: 3,
      get_user_status_message: 3
    ]

  alias MossletWeb.Helpers.URLPreviewHelpers

  # ── Hero / banner ──────────────────────────────────────────────────────────

  @doc """
  Renders the profile hero banner (the gradient banner block).

  Intended to be placed as the first child of a `relative overflow-hidden`
  wrapper that also holds `profile_header/1` (whose negative top margin overlaps
  the banner).

  For the owner (`:own`) this supports a custom, browser-decrypted banner image
  (via the `DecryptAvatar` ZK hook and the `@custom_banner_src` async result),
  falling back to a static profile banner. Connection/public variants render the
  static profile banner only.
  """
  attr :access, :atom, required: true
  attr :connection, :map, required: true, doc: "the profile owner's connection record"
  attr :custom_banner_src, :any, default: nil, doc: "AsyncResult for the owner's custom banner"

  def profile_hero(assigns) do
    ~H"""
    <%!-- Banner/Cover Image Section --%>
    <div class="relative h-48 sm:h-64 lg:h-80 bg-gradient-to-br from-teal-100 via-emerald-50 to-cyan-100 dark:from-teal-900/40 dark:via-emerald-900/30 dark:to-cyan-900/40">
      <%= if @access == :own do %>
        <% banner_data = async_banner_data(@custom_banner_src) %>
        <%= cond do %>
          <% @custom_banner_src && @custom_banner_src.loading -> %>
            <div class="absolute inset-0 flex items-center justify-center">
              <div class="w-10 h-10 border-3 border-purple-400 border-t-transparent rounded-full animate-spin">
              </div>
            </div>
          <% banner_data -> %>
            <div
              id="profile-banner-img"
              phx-hook="DecryptAvatar"
              data-encrypted-blob={banner_data[:encrypted_blob_b64]}
              data-sealed-key={banner_data[:sealed_key]}
              data-mime="image/webp"
              class="absolute inset-0"
            >
              <div class="absolute inset-0 bg-gradient-to-t from-black/30 to-transparent"></div>
            </div>
          <% get_banner_image_for_connection(@connection) != "" -> %>
            <div
              class="absolute inset-0 bg-cover bg-center bg-no-repeat"
              style={"background-image: url('/images/profile/#{get_banner_image_for_connection(@connection)}')"}
            >
              <div class="absolute inset-0 bg-gradient-to-t from-black/30 to-transparent"></div>
            </div>
          <% true -> %>
        <% end %>
      <% else %>
        <div
          :if={get_banner_image_for_connection(@connection) != ""}
          class="absolute inset-0 bg-cover bg-center bg-no-repeat"
          style={"background-image: url('/images/profile/#{get_banner_image_for_connection(@connection)}')"}
        >
          <div class="absolute inset-0 bg-gradient-to-t from-black/30 to-transparent"></div>
        </div>
      <% end %>

      <%!-- Liquid metal overlay pattern --%>
      <div class="absolute inset-0 opacity-20">
        <div class="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent transform -skew-x-12 animate-pulse">
        </div>
      </div>
    </div>
    """
  end

  # ── Header (avatar + name + badges + actions) ────────────────────────────────

  @doc """
  Renders the profile header: avatar, name, identity badges, and action buttons.

  Branches on `@profile.access`: the owner/connection variants drive identity +
  status from the encrypted user/connection records (browser-side ZK), while the
  public variant decrypts identity server-side.
  """
  attr :profile, :map, required: true, doc: "the ProfileViewModel struct"
  attr :profile_user, :map, required: true
  attr :current_scope, :map, required: true
  attr :user_connection, :any, default: nil

  def profile_header(assigns) do
    ~H"""
    <div class="relative px-4 sm:px-6 lg:px-8 -mt-8 sm:-mt-12 lg:-mt-16">
      <div class="mx-auto max-w-7xl">
        <div class="relative pb-8">
          <%!-- Avatar and Basic Info --%>
          <div class="flex flex-col sm:flex-row items-center sm:items-start gap-6">
            <%= case @profile.access do %>
              <% :own -> %>
                <.own_header
                  profile={@profile}
                  profile_user={@profile_user}
                  current_scope={@current_scope}
                />
              <% :connections -> %>
                <.connections_header
                  profile={@profile}
                  profile_user={@profile_user}
                  current_scope={@current_scope}
                  user_connection={@user_connection}
                />
              <% _ -> %>
                <.public_header
                  profile={@profile}
                  profile_user={@profile_user}
                  current_scope={@current_scope}
                  user_connection={@user_connection}
                />
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :profile, :map, required: true
  attr :profile_user, :map, required: true
  attr :current_scope, :map, required: true

  defp own_header(assigns) do
    ~H"""
    <%!-- Enhanced Avatar with built-in status support --%>
    <div class="relative flex-shrink-0">
      <.liquid_avatar
        src={if not @profile.show_avatar?, do: nil}
        encrypted_avatar_data={
          if @profile.show_avatar?,
            do: get_encrypted_avatar_data(@current_scope.user, @current_scope.key)
        }
        name={@profile.identity.name}
        size="xxl"
        status={to_string(@current_scope.user.status)}
        status_message={
          get_user_status_message(@current_scope.user, @current_scope.user, @current_scope.key)
        }
        show_status={can_view_status?(@current_scope.user, @current_scope.user, @current_scope.key)}
        user_id={@current_scope.user.id}
        id="user-home-profile-avatar"
        verified={@current_scope.user.connection.profile.visibility == "public"}
      />
    </div>

    <%!-- Name, username, and actions --%>
    <div class="flex-1 text-center sm:text-left space-y-4">
      <%!-- Name and username --%>
      <div class="space-y-1">
        <h1
          :if={@profile.show_name?}
          class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-950 dark:text-white sm:text-white sm:dark:text-white"
        >
          {@profile.identity.name}
        </h1>

        <h1
          :if={!@profile.show_name?}
          class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-950 dark:text-white sm:text-white sm:dark:text-white"
        >
          {"Profile 🌿"}
        </h1>
        <div class="flex items-center justify-center sm:justify-start gap-2 flex-wrap text-lg text-emerald-600 dark:text-emerald-400">
          <%!-- username badge --%>
          <.liquid_badge variant="soft" color={visibility_badge_color(@profile.visibility)} size="sm">
            @<span data-decrypt-field="username">{@current_scope.user.decrypted[:username]}</span>
          </.liquid_badge>

          <%!-- Email badge if show_email? is true --%>
          <.liquid_badge
            :if={@profile.show_email?}
            variant="soft"
            color={visibility_badge_color(@profile.visibility)}
            size="sm"
          >
            <.phx_icon name="hero-envelope" class="size-3 mr-1" />
            <span data-decrypt-field="email">
              {@current_scope.user.decrypted[:email]}
            </span>
          </.liquid_badge>

          <%!-- Visibility badge --%>
          <.liquid_badge variant="soft" color={visibility_badge_color(@profile.visibility)} size="sm">
            <.phx_icon
              name={
                if(@profile.visibility == :public, do: "hero-globe-alt", else: "hero-lock-closed")
              }
              class="size-3 mr-1"
            />
            {String.capitalize(to_string(@profile.visibility))}
          </.liquid_badge>
        </div>
      </div>

      <%!-- Action buttons --%>
      <div class="flex flex-col sm:flex-row items-center gap-3">
        <%!-- Edit Profile --%>
        <.liquid_button
          navigate={~p"/app/users/edit-profile"}
          variant="primary"
          color="teal"
          icon="hero-pencil-square"
          class="w-full sm:w-auto"
        >
          Edit Profile
        </.liquid_button>

        <%!-- Status Settings --%>
        <.liquid_button
          navigate={~p"/app/users/edit-status"}
          variant="secondary"
          color="blue"
          icon="hero-face-smile"
          size="md"
          class="w-full sm:w-auto"
        >
          Status Settings
        </.liquid_button>
      </div>
    </div>
    """
  end

  attr :profile, :map, required: true
  attr :profile_user, :map, required: true
  attr :current_scope, :map, required: true
  attr :user_connection, :any, default: nil

  defp connections_header(assigns) do
    ~H"""
    <%!-- Enhanced Avatar --%>
    <div class="relative flex-shrink-0">
      <.liquid_avatar
        encrypted_avatar_data={
          if @profile.show_avatar?,
            do: get_encrypted_avatar_data(@user_connection, @current_scope.key)
        }
        id={"profile-user-avatar-#{@profile_user.id}"}
        name={@profile.identity.name || "..."}
        size="xxl"
        status={to_string(@profile_user.status)}
        encrypted_status_data={
          get_encrypted_status_data(@profile_user, @current_scope.user, @current_scope.key)
        }
        show_status={can_view_status?(@profile_user, @current_scope.user, @current_scope.key)}
        user_id={@profile_user.id}
        verified={false}
      />
    </div>

    <%!-- Name, username, and info --%>
    <div class="flex-1 text-center sm:text-left space-y-4">
      <%!-- Name and username --%>
      <div class="space-y-1">
        <h1
          :if={@profile.show_name?}
          class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-950 dark:text-white sm:text-white sm:dark:text-white"
          data-decrypt-profile="name"
        >
          {@profile.identity.name || "..."}
        </h1>
        <h1
          :if={!@profile.show_name?}
          class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-950 dark:text-white sm:text-white sm:dark:text-white"
        >
          {"Profile 🌿"}
        </h1>
        <div class="flex items-center justify-center sm:justify-start gap-2 flex-wrap text-lg text-slate-600 dark:text-slate-400">
          <%!-- username badge --%>
          <.liquid_badge variant="soft" color={visibility_badge_color(@profile.visibility)} size="sm">
            @<span data-decrypt-profile="username">{@profile.identity.username || "..."}</span>
          </.liquid_badge>

          <%!-- Email badge if show_email? is true --%>
          <.liquid_badge
            :if={@profile.show_email? && @profile_user.connection.email}
            variant="soft"
            color={visibility_badge_color(@profile.visibility)}
            size="sm"
          >
            <.phx_icon name="hero-envelope" class="size-3 mr-1" />
            <span data-decrypt-profile="email">
              {@profile.identity.email || "..."}
            </span>
          </.liquid_badge>

          <%!-- Connection badge --%>
          <.liquid_badge variant="soft" color="emerald" size="sm">
            <.phx_icon name="hero-user-group" class="size-3 mr-1" /> Connection
          </.liquid_badge>
        </div>
      </div>
    </div>
    """
  end

  attr :profile, :map, required: true
  attr :profile_user, :map, required: true
  attr :current_scope, :map, required: true
  attr :user_connection, :any, default: nil

  defp public_header(assigns) do
    ~H"""
    <div class="relative flex-shrink-0">
      <.liquid_avatar
        src={if @profile.show_avatar?, do: nil}
        name={
          decrypt_public_field(
            @profile_user.connection.profile.name,
            @profile_user.connection.profile.profile_key
          )
        }
        size="xxl"
        status={public_status(@profile_user)}
        status_message={public_status_message(@profile_user)}
        show_status={can_view_status?(@profile_user, @current_scope.user, @current_scope.key)}
        user_id={@profile_user.id}
        verified={false}
      />
    </div>

    <div class="flex-1 text-center sm:text-left space-y-4">
      <div class="space-y-1">
        <h1
          :if={@profile.show_name?}
          class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-950 dark:text-white sm:text-white sm:dark:text-white"
        >
          {decrypt_public_field(
            @profile_user.connection.profile.name,
            @profile_user.connection.profile.profile_key
          )}
        </h1>

        <h1
          :if={!@profile.show_name?}
          class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-950 dark:text-white sm:text-white sm:dark:text-white"
        >
          {"Profile 🌿"}
        </h1>

        <div class="flex items-center justify-center sm:justify-start gap-2 flex-wrap text-lg text-emerald-600 dark:text-emerald-400">
          <.liquid_badge variant="soft" color="cyan" size="sm">
            @{decrypt_public_field(
              @profile_user.connection.profile.username,
              @profile_user.connection.profile.profile_key
            )}
          </.liquid_badge>

          <.liquid_badge
            :if={@profile.show_email? && @profile_user.connection.profile.email}
            variant="soft"
            color="cyan"
            size="sm"
          >
            <.phx_icon name="hero-envelope" class="size-3 mr-1" />
            {decrypt_public_field(
              @profile_user.connection.profile.email,
              @profile_user.connection.profile.profile_key
            )}
          </.liquid_badge>

          <.liquid_badge variant="soft" color="cyan" size="sm">
            <.phx_icon name="hero-globe-alt" class="size-3 mr-1" /> Public
          </.liquid_badge>
        </div>
      </div>

      <div
        :if={@current_scope.user && !@profile.owner? && !@user_connection}
        class="flex flex-col sm:flex-row items-center gap-3"
      >
        <.liquid_button
          navigate={~p"/app/users/connections"}
          variant="primary"
          color="teal"
          icon="hero-user-plus"
          class="w-full sm:w-auto"
        >
          Connect
        </.liquid_button>
      </div>
    </div>
    """
  end

  # ── DecryptProfileFields ZK hook (owner + connection only) ───────────────────

  @doc """
  Emits the hidden `DecryptProfileFields` ZK hook element for browser-side
  decryption of the sealed profile detail fields. Only rendered when the
  view-model carries sealed fields (`browser_decrypt?`), i.e. for the owner and
  connection variants — never for public profiles (which decrypt server-side).
  """
  attr :profile, :map, required: true
  attr :id, :string, required: true
  attr :profile_id, :string, required: true

  def profile_decrypt_fields(assigns) do
    ~H"""
    <div
      :if={@profile.fields && @profile.fields[:browser_decrypt?]}
      id={@id}
      phx-hook="DecryptProfileFields"
      phx-update="ignore"
      data-profile-id={@profile_id}
      data-sealed-profile-key={@profile.fields[:sealed_profile_key]}
      data-encrypted-about={@profile.fields[:encrypted_about]}
      data-encrypted-alternate-email={@profile.fields[:encrypted_alternate_email]}
      data-encrypted-website-url={@profile.fields[:encrypted_website_url]}
      data-encrypted-website-label={@profile.fields[:encrypted_website_label]}
      data-encrypted-name={@profile.fields[:encrypted_name]}
      data-encrypted-username={@profile.fields[:encrypted_username]}
      data-encrypted-email={@profile.fields[:encrypted_email]}
      class="hidden"
    >
    </div>
    """
  end

  # ── Contact & Links card ─────────────────────────────────────────────────────

  @doc """
  Renders the "Contact & Links" card (alternate email + website preview).

  Owner/connection variants tag the values with `data-decrypt-profile` targets
  for browser-side ZK decryption (with a pulsing placeholder); the public
  variant renders the server-decrypted values directly.
  """
  attr :profile, :map, required: true
  attr :profile_user, :map, required: true
  attr :current_scope, :map, required: true
  attr :website_url_preview, :any, default: nil
  attr :website_url_preview_loading, :boolean, default: false

  def profile_contact_card(assigns) do
    assigns = assign(assigns, :profile_record, profile_record(assigns))

    ~H"""
    <.liquid_card :if={has_contact_links?(@profile_record)} heading_level={2}>
      <:title>
        <div class="flex items-center gap-2">
          <.phx_icon name="hero-link" class="size-5 text-violet-600 dark:text-violet-400" />
          Contact & Links
        </div>
      </:title>
      <div class="space-y-4">
        <div :if={@profile_record.alternate_email} class="flex items-center gap-3">
          <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/30 dark:to-emerald-900/30">
            <.phx_icon name="hero-envelope" class="size-5 text-teal-600 dark:text-teal-400" />
          </div>
          <div>
            <p class="text-sm text-slate-500 dark:text-slate-400">Contact Email</p>
            <a
              data-decrypt-profile={if @profile.access != :public, do: "alternate_email"}
              href={
                if @profile.fields && @profile.fields[:alternate_email],
                  do: "mailto:#{@profile.fields[:alternate_email]}",
                  else: "#"
              }
              class={[
                "text-slate-900 dark:text-white hover:text-teal-600 dark:hover:text-teal-400 transition-colors",
                @profile.access != :public && @profile.fields && @profile.fields[:browser_decrypt?] &&
                  "animate-pulse"
              ]}
            >
              {contact_value(@profile, :alternate_email)}
            </a>
          </div>
        </div>

        <.website_url_preview
          :if={@profile_record.website_url}
          preview={@website_url_preview}
          loading={@website_url_preview_loading}
          url={if @profile.fields, do: @profile.fields[:website_url]}
          label={website_label(@profile, @profile_record)}
        />
      </div>
    </.liquid_card>
    """
  end

  # ── About card ───────────────────────────────────────────────────────────────

  @doc """
  Renders the "About" card. Owner/connection variants tag the bio with a
  `data-decrypt-profile="about"` target (pulsing placeholder); public renders
  the server-decrypted bio. Each variant has its own empty state.
  """
  attr :profile, :map, required: true
  attr :profile_user, :map, required: true
  attr :current_scope, :map, required: true

  def profile_about(assigns) do
    assigns = assign(assigns, :profile_record, profile_record(assigns))

    ~H"""
    <.liquid_card heading_level={2}>
      <:title>
        <div class="flex items-center gap-2">
          <.phx_icon name="hero-user" class="size-5 text-teal-600 dark:text-teal-400" /> About
        </div>
      </:title>
      <div :if={@profile_record.about} class="prose prose-slate dark:prose-invert max-w-none">
        <p
          data-decrypt-profile={if @profile.access != :public, do: "about"}
          class={[
            "text-slate-700 dark:text-slate-300 leading-relaxed",
            @profile.access != :public && @profile.fields && @profile.fields[:browser_decrypt?] &&
              "animate-pulse"
          ]}
        >
          {contact_value(@profile, :about)}
        </p>
      </div>
      <%= if !@profile_record.about do %>
        <%= case @profile.access do %>
          <% :own -> %>
            <div class="text-center py-8">
              <div class="mb-4">
                <.phx_icon
                  name="hero-chat-bubble-left-right"
                  class="size-12 mx-auto mb-3 text-slate-300 dark:text-slate-600"
                />
                <p class="text-sm text-slate-600 dark:text-slate-400">
                  Share something about yourself!
                </p>
              </div>
              <.liquid_button
                navigate={~p"/app/users/edit-profile"}
                variant="secondary"
                color="teal"
                size="sm"
                icon="hero-plus"
              >
                Add Bio
              </.liquid_button>
            </div>
          <% :connections -> %>
            <div class="text-center py-8">
              <div class="text-slate-400 dark:text-slate-500 mb-4">
                <.phx_icon name="hero-chat-bubble-left-right" class="size-12 mx-auto mb-3 opacity-50" />
                <p class="text-sm">This connection hasn't shared a bio yet.</p>
              </div>
            </div>
          <% _ -> %>
            <div class="text-center py-8">
              <div class="text-slate-400 dark:text-slate-500 mb-4">
                <.phx_icon name="hero-chat-bubble-left-right" class="size-12 mx-auto mb-3 opacity-50" />
                <p class="text-sm">No bio available.</p>
              </div>
            </div>
        <% end %>
      <% end %>
    </.liquid_card>
    """
  end

  # ── Private helpers ──────────────────────────────────────────────────────────

  # The profile record whose ciphertext-presence drives `:if` guards. For the
  # owner this is the session user's profile; otherwise the viewed user's.
  defp profile_record(%{profile: %{access: :own}, current_scope: current_scope}),
    do: current_scope.user.connection.profile

  defp profile_record(%{profile_user: profile_user}),
    do: profile_user.connection.profile

  # Placeholder ("...") while sealed fields await browser-side decryption; the
  # public variant has no placeholder (values are already decrypted).
  defp contact_value(%{fields: fields}, key) when is_map(fields), do: fields[key]
  defp contact_value(%{access: :public}, _key), do: nil
  defp contact_value(_profile, _key), do: "..."

  # Owner/connection variants show "..." while the real label decrypts in the
  # browser; the public variant shows nil (no placeholder needed).
  defp website_label(profile, profile_record) do
    cond do
      profile.fields && profile.fields[:website_label] ->
        profile.fields[:website_label]

      profile_record.website_label ->
        if profile.access == :public, do: nil, else: "..."

      true ->
        "Website"
    end
  end

  defp has_contact_links?(profile), do: profile.alternate_email || profile.website_url

  defp decrypt_public_field(encrypted_value, encrypted_profile_key),
    do: URLPreviewHelpers.decrypt_public_field(encrypted_value, encrypted_profile_key)

  # Public profile avatars are encrypted with profile_key, not conn_key; ZK
  # browser-side decryption for public profiles is a future task.
  defp public_status(profile_user) do
    if can_view_status?(profile_user, nil, nil) && profile_user.status do
      to_string(profile_user.status)
    end
  end

  defp public_status_message(profile_user) do
    if can_view_status?(profile_user, nil, nil) && profile_user.status_message do
      decrypt_public_field(
        profile_user.status_message,
        profile_user.connection.profile.profile_key
      )
    end
  end

  defp visibility_badge_color(:public), do: "cyan"
  defp visibility_badge_color("public"), do: "cyan"
  defp visibility_badge_color(_visibility), do: "emerald"

  defp async_banner_data(%Phoenix.LiveView.AsyncResult{ok?: true, result: result}),
    do: if(is_map(result), do: result, else: nil)

  defp async_banner_data(_), do: nil
end
