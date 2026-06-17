defmodule MossletWeb.TimelineComponents do
  @moduledoc """
  Timeline post display, composition, and navigation components.

  Extracted from `MossletWeb.DesignSystem` as part of the design system
  modularization (Phase 1).
  """
  use Phoenix.Component
  use MossletWeb, :verified_routes

  import MossletWeb.CoreComponents, only: [phx_icon: 1, phx_input: 1, local_time_ago: 1]

  # Import media components
  import MossletWeb.MediaComponents,
    only: [liquid_photo_upload_preview: 1, liquid_post_photo_gallery: 1]

  # Import privacy helper functions
  import MossletWeb.PrivacyComponents,
    only: [
      privacy_icon: 1,
      privacy_label: 1,
      liquid_compact_privacy_controls: 1,
      liquid_markdown_guide_trigger: 1,
      mature_content_toggle: 1
    ]

  import MossletWeb.Helpers,
    only: [
      alpine_autofocus: 0,
      contains_html?: 1,
      format_decrypted_content: 1,
      html_block: 1,
      is_shared_recipient?: 2,
      photos?: 1,
      username: 2,
      user_name: 2,
      get_encrypted_avatar_data: 2,
      show_avatar?: 1,
      soft_like_text: 2
    ]

  import MossletWeb.Helpers.StatusHelpers,
    only: [
      can_view_status?: 3,
      get_status_fallback_message: 1,
      get_user_status_message: 3
    ]

  import MossletWeb.DesignSystem,
    only: [
      liquid_avatar: 1,
      liquid_button: 1,
      liquid_dropdown: 1,
      liquid_select_custom: 1
    ]

  alias Phoenix.LiveView.JS

  @doc """
  Timeline infinite scroll indicator with transparency about remaining content.
  Simple, elegant design that shows exactly what will happen on click.
  """
  attr :remaining_count, :integer, default: 0
  attr :load_count, :integer, default: 10
  attr :loading, :boolean, default: false
  attr :tab_color, :string, default: "slate"
  attr :class, :any, default: ""
  attr :rest, :global, include: ~w(phx-click)

  def liquid_timeline_scroll_indicator(assigns) do
    assigns =
      assign(assigns, :color_classes, get_tab_color_classes(assigns.tab_color))

    ~H"""
    <div class={["relative py-6 max-w-2xl mx-auto", @class]}>
      <div class="absolute inset-0 flex items-center" aria-hidden="true">
        <div class={[
          "w-full h-px bg-gradient-to-r from-transparent to-transparent",
          @color_classes.divider_line
        ]} />
      </div>

      <div class="relative flex justify-center">
        <button
          type="button"
          class={[
            "group inline-flex items-center gap-2.5 px-5 py-2.5 rounded-full",
            "bg-white dark:bg-slate-800",
            "border",
            @color_classes.border,
            "shadow-lg shadow-slate-900/5 dark:shadow-black/20",
            "hover:shadow-xl hover:shadow-slate-900/10 dark:hover:shadow-black/30",
            @color_classes.hover_border,
            "focus:outline-none focus:ring-2 focus:ring-offset-2 dark:focus:ring-offset-slate-900",
            @color_classes.focus_ring,
            "transition-all duration-300 ease-out",
            "transform hover:scale-[1.02] active:scale-[0.98]",
            "phx-click-loading:cursor-wait phx-click-loading:opacity-90",
            @loading && "cursor-wait opacity-80"
          ]}
          disabled={@loading}
          {@rest}
        >
          <div class="phx-click-loading:flex hidden items-center gap-2">
            <div class={[
              "h-4 w-4 animate-spin rounded-full border-2",
              @color_classes.spinner
            ]} />
            <span class="text-sm font-medium text-slate-600 dark:text-slate-300">
              Loading...
            </span>
          </div>

          <div :if={@loading} class="phx-click-loading:hidden flex items-center gap-2">
            <div class={[
              "h-4 w-4 animate-spin rounded-full border-2",
              @color_classes.spinner
            ]} />
            <span class="text-sm font-medium text-slate-600 dark:text-slate-300">
              Loading more posts...
            </span>
          </div>

          <div :if={!@loading} class="phx-click-loading:hidden flex items-center gap-2.5">
            <div class={[
              "flex items-center justify-center w-6 h-6 rounded-full",
              "bg-gradient-to-br from-slate-100 to-slate-50 dark:from-slate-700 dark:to-slate-800",
              @color_classes.icon_bg_hover,
              "transition-all duration-300"
            ]}>
              <.phx_icon
                name="hero-arrow-down"
                class={[
                  "w-3.5 h-3.5 text-slate-500 dark:text-slate-400",
                  @color_classes.icon_hover,
                  "transition-all duration-300"
                ]}
              />
            </div>

            <span class="text-sm font-medium text-slate-600 dark:text-slate-300 group-hover:text-slate-800 dark:group-hover:text-slate-100 transition-colors">
              <span class="text-slate-500 dark:text-slate-400">Load</span>
              <span class={[
                "inline-flex items-center justify-center min-w-[1.5rem] px-1.5 py-0.5 mx-1",
                "text-xs font-semibold rounded-full",
                "text-white shadow-sm",
                @color_classes.badge
              ]}>
                {@load_count}
              </span>
              <span class="text-slate-500 dark:text-slate-400">more</span>
              <span class="text-slate-500 dark:text-slate-400 ml-1">({@remaining_count} left)</span>
            </span>

            <div class={[
              "flex items-center justify-center w-6 h-6 rounded-full",
              "bg-gradient-to-br from-slate-100 to-slate-50 dark:from-slate-700 dark:to-slate-800",
              @color_classes.icon_bg_hover,
              "transition-all duration-300"
            ]}>
              <.phx_icon
                name="hero-plus"
                class={[
                  "w-3.5 h-3.5 text-slate-400 dark:text-slate-500",
                  @color_classes.icon_hover,
                  "transition-colors duration-300"
                ]}
              />
            </div>
          </div>
        </button>
      </div>
    </div>
    """
  end

  # Helper function to get tab color for the load more button
  def get_tab_color(active_tab) do
    case active_tab do
      "home" -> "emerald"
      # This maps to blue-cyan gradient
      "connections" -> "teal"
      # This maps to purple-violet gradient
      "groups" -> "blue"
      # This maps to amber-orange gradient
      "bookmarks" -> "orange"
      # This maps to indigo-blue gradient
      "discover" -> "purple"
      _ -> "slate"
    end
  end

  # Helper function to get color classes for different tabs
  def get_tab_color_classes(tab_color) do
    case tab_color do
      "emerald" ->
        %{
          badge: "bg-gradient-to-br from-emerald-500 to-teal-600 shadow-emerald-500/30",
          focus_ring: "focus:ring-emerald-500/50",
          icon_hover: "group-hover:text-emerald-600 dark:group-hover:text-emerald-400",
          icon_bg_hover:
            "group-hover:from-emerald-100 group-hover:to-teal-50 dark:group-hover:from-emerald-900/40 dark:group-hover:to-teal-900/30",
          spinner: "border-emerald-500/30 border-t-emerald-500",
          divider_line: "via-emerald-300/40 dark:via-emerald-600/40",
          button:
            "bg-gradient-to-r from-emerald-500 to-teal-600 text-white focus:ring-emerald-500/50",
          indicator: "bg-emerald-400",
          border: "border-emerald-200/80 dark:border-emerald-700/80",
          hover_border: "hover:border-emerald-300 dark:hover:border-emerald-600"
        }

      "teal" ->
        %{
          badge: "bg-gradient-to-br from-blue-500 to-cyan-600 shadow-blue-500/30",
          focus_ring: "focus:ring-blue-500/50",
          icon_hover: "group-hover:text-blue-600 dark:group-hover:text-blue-400",
          icon_bg_hover:
            "group-hover:from-blue-100 group-hover:to-cyan-50 dark:group-hover:from-blue-900/40 dark:group-hover:to-cyan-900/30",
          spinner: "border-blue-500/30 border-t-blue-500",
          divider_line: "via-blue-300/40 dark:via-blue-600/40",
          button: "bg-gradient-to-r from-blue-500 to-cyan-600 text-white focus:ring-blue-500/50",
          indicator: "bg-blue-400",
          border: "border-blue-200/80 dark:border-blue-700/80",
          hover_border: "hover:border-blue-300 dark:hover:border-blue-600"
        }

      "blue" ->
        %{
          badge: "bg-gradient-to-br from-purple-500 to-violet-600 shadow-purple-500/30",
          focus_ring: "focus:ring-purple-500/50",
          icon_hover: "group-hover:text-purple-600 dark:group-hover:text-purple-400",
          icon_bg_hover:
            "group-hover:from-purple-100 group-hover:to-violet-50 dark:group-hover:from-purple-900/40 dark:group-hover:to-violet-900/30",
          spinner: "border-purple-500/30 border-t-purple-500",
          divider_line: "via-purple-300/40 dark:via-purple-600/40",
          button:
            "bg-gradient-to-r from-purple-500 to-violet-600 text-white focus:ring-purple-500/50",
          indicator: "bg-purple-400",
          border: "border-purple-200/80 dark:border-purple-700/80",
          hover_border: "hover:border-purple-300 dark:hover:border-purple-600"
        }

      "purple" ->
        %{
          badge: "bg-gradient-to-br from-indigo-500 to-blue-600 shadow-indigo-500/30",
          focus_ring: "focus:ring-indigo-500/50",
          icon_hover: "group-hover:text-indigo-600 dark:group-hover:text-indigo-400",
          icon_bg_hover:
            "group-hover:from-indigo-100 group-hover:to-blue-50 dark:group-hover:from-indigo-900/40 dark:group-hover:to-blue-900/30",
          spinner: "border-indigo-500/30 border-t-indigo-500",
          divider_line: "via-indigo-300/40 dark:via-indigo-600/40",
          button:
            "bg-gradient-to-r from-indigo-500 to-blue-600 text-white focus:ring-indigo-500/50",
          indicator: "bg-indigo-400",
          border: "border-indigo-200/80 dark:border-indigo-700/80",
          hover_border: "hover:border-indigo-300 dark:hover:border-indigo-600"
        }

      "orange" ->
        %{
          badge: "bg-gradient-to-br from-amber-500 to-orange-600 shadow-amber-500/30",
          focus_ring: "focus:ring-amber-500/50",
          icon_hover: "group-hover:text-amber-600 dark:group-hover:text-amber-400",
          icon_bg_hover:
            "group-hover:from-amber-100 group-hover:to-orange-50 dark:group-hover:from-amber-900/40 dark:group-hover:to-orange-900/30",
          spinner: "border-amber-500/30 border-t-amber-500",
          divider_line: "via-amber-300/40 dark:via-amber-600/40",
          button:
            "bg-gradient-to-r from-amber-500 to-orange-600 text-white focus:ring-amber-500/50",
          indicator: "bg-amber-400",
          border: "border-amber-200/80 dark:border-amber-700/80",
          hover_border: "hover:border-amber-300 dark:hover:border-amber-600"
        }

      "cyan" ->
        %{
          badge: "bg-gradient-to-br from-cyan-500 to-teal-600 shadow-cyan-500/30",
          focus_ring: "focus:ring-cyan-500/50",
          icon_hover: "group-hover:text-cyan-600 dark:group-hover:text-cyan-400",
          icon_bg_hover:
            "group-hover:from-cyan-100 group-hover:to-teal-50 dark:group-hover:from-cyan-900/40 dark:group-hover:to-teal-900/30",
          spinner: "border-cyan-500/30 border-t-cyan-500",
          divider_line: "via-cyan-300/40 dark:via-cyan-600/40",
          button: "bg-gradient-to-r from-cyan-500 to-teal-600 text-white focus:ring-cyan-500/50",
          indicator: "bg-cyan-400",
          border: "border-cyan-200/80 dark:border-cyan-700/80",
          hover_border: "hover:border-cyan-300 dark:hover:border-cyan-600"
        }

      "indigo" ->
        %{
          badge: "bg-gradient-to-br from-indigo-500 to-blue-600 shadow-indigo-500/30",
          focus_ring: "focus:ring-indigo-500/50",
          icon_hover: "group-hover:text-indigo-600 dark:group-hover:text-indigo-400",
          icon_bg_hover:
            "group-hover:from-indigo-100 group-hover:to-blue-50 dark:group-hover:from-indigo-900/40 dark:group-hover:to-blue-900/30",
          spinner: "border-indigo-500/30 border-t-indigo-500",
          divider_line: "via-indigo-300/40 dark:via-indigo-600/40",
          button:
            "bg-gradient-to-r from-indigo-500 to-blue-600 text-white focus:ring-indigo-500/50",
          indicator: "bg-indigo-400",
          border: "border-indigo-200/80 dark:border-indigo-700/80",
          hover_border: "hover:border-indigo-300 dark:hover:border-indigo-600"
        }

      _ ->
        %{
          badge: "bg-gradient-to-br from-slate-500 to-slate-600 shadow-slate-500/30",
          focus_ring: "focus:ring-slate-500/50",
          icon_hover: "group-hover:text-slate-600 dark:group-hover:text-slate-400",
          icon_bg_hover:
            "group-hover:from-slate-200 group-hover:to-slate-100 dark:group-hover:from-slate-700 dark:group-hover:to-slate-600",
          spinner: "border-slate-500/30 border-t-slate-500",
          divider_line: "via-slate-300/40 dark:via-slate-600/40",
          button:
            "bg-gradient-to-r from-slate-500 to-slate-600 text-white focus:ring-slate-500/50",
          indicator: "bg-slate-400",
          border: "border-slate-200/80 dark:border-slate-700/80",
          hover_border: "hover:border-slate-300 dark:hover:border-slate-600"
        }
    end
  end

  @doc """
  Timeline realtime update indicator for PubSub notifications.
  Positioned below the topbar to avoid mobile sidebar collision.
  """
  attr :new_posts_count, :integer, default: 0
  attr :active_tab, :string, default: "home"
  attr :class, :any, default: ""

  def liquid_timeline_realtime_indicator(assigns) do
    # Define tab-specific icons and colors
    assigns = assign(assigns, :tab_icon, get_tab_icon(assigns.active_tab))

    assigns =
      assign(assigns, :color_classes, get_tab_color_classes(get_tab_color(assigns.active_tab)))

    ~H"""
    <div
      :if={@new_posts_count > 0}
      id="timeline-realtime-indicator"
      class={[
        "text-center",
        @class
      ]}
    >
      <button
        class={[
          "group inline-flex items-center gap-3 px-4 py-2.5 rounded-full shadow-lg hover:shadow-xl transition-all duration-200 ease-out hover:scale-105 focus:outline-none focus:ring-2 focus:ring-offset-2",
          @color_classes.button
        ]}
        phx-click={JS.dispatch("phx:scroll-to-top", to: "body")}
        title="Scroll to top of page"
      >
        <%!-- Gentle pulse indicator --%>
        <div class="relative">
          <div class={["w-2 h-2 rounded-full", @color_classes.indicator]}></div>
          <div class={[
            "absolute inset-0 w-2 h-2 rounded-full animate-ping opacity-75",
            @color_classes.indicator
          ]}>
          </div>
        </div>

        <%!-- Tab-specific icon --%>
        <.phx_icon
          name={@tab_icon}
          class="h-4 w-4 opacity-90"
        />

        <span class="text-sm font-medium">
          {@new_posts_count} unread post{if(@new_posts_count == 1, do: "", else: "s")}
        </span>
      </button>
    </div>
    """
  end

  # Helper function to get tab-specific icons
  defp get_tab_icon(tab) do
    case tab do
      "home" -> "hero-home"
      "connections" -> "hero-user-group"
      "groups" -> "hero-squares-2x2"
      "bookmarks" -> "hero-bookmark"
      "discover" -> "hero-globe-alt"
      _ -> "hero-home"
    end
  end

  @doc """
  A beautiful, calm "New Post" prompt card that navigates to the timeline composer.
  Perfect for profile pages and dashboards.
  """
  attr :user_name, :string, required: true
  attr :user_avatar, :string, default: nil
  attr :placeholder, :string, default: "Share something meaningful..."
  attr :class, :any, default: ""
  attr :id, :string, default: "new-post-prompt"
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"
  attr :show_status, :boolean, default: false
  attr :status_message, :string, default: nil

  attr :encrypted_avatar_data, :map,
    default: nil,
    doc: "ZK mode: encrypted avatar data for browser-side decryption"

  def liquid_new_post_prompt(assigns) do
    assigns = assign_scope_fields(assigns)

    ~H"""
    <.link
      navigate={~p"/app/timeline"}
      id={@id}
      class={[
        "block relative rounded-2xl transition-all duration-300 ease-out",
        "bg-white/95 dark:bg-slate-800/95 backdrop-blur-xl",
        "border border-slate-200/80 dark:border-slate-700/80",
        "shadow-lg shadow-slate-900/5 dark:shadow-black/30",
        "ring-1 ring-slate-900/5 dark:ring-white/5",
        "hover:shadow-xl hover:shadow-emerald-500/10 dark:hover:shadow-emerald-500/5",
        "hover:border-emerald-400/60 dark:hover:border-emerald-500/40",
        "hover:scale-[1.01] active:scale-[0.99]",
        "focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-500/60",
        "group cursor-pointer",
        @class
      ]}
    >
      <%!-- Subtle liquid gradient background on hover --%>
      <div class="absolute inset-0 opacity-0 group-hover:opacity-100 transition-all duration-500 ease-out bg-gradient-to-br from-emerald-50/30 via-teal-50/20 to-cyan-50/30 dark:from-emerald-900/10 dark:via-teal-900/5 dark:to-cyan-900/10">
      </div>

      <%!-- Content --%>
      <div class="relative p-4 sm:p-5">
        <div class="flex items-center gap-3 sm:gap-4">
          <%!-- User avatar --%>
          <div class="flex-shrink-0">
            <.liquid_avatar
              src={@user_avatar}
              name={@user_name}
              size="md"
              status={
                if @current_scope.user,
                  do: to_string(@current_scope.user.status || "offline"),
                  else: "offline"
              }
              status_message={@status_message}
              user_id={if @current_scope.user, do: @current_scope.user.id}
              show_status={@show_status}
              encrypted_avatar_data={@encrypted_avatar_data}
              id={"#{@id}-avatar"}
            />
          </div>

          <%!-- Prompt text area simulation --%>
          <div class="flex-1 min-w-0">
            <div class={[
              "w-full px-4 py-3 rounded-xl",
              "bg-slate-50/80 dark:bg-slate-700/50",
              "border border-slate-200/60 dark:border-slate-600/40",
              "group-hover:bg-emerald-50/50 dark:group-hover:bg-emerald-900/20",
              "group-hover:border-emerald-200/60 dark:group-hover:border-emerald-700/40",
              "transition-all duration-200"
            ]}>
              <span class="text-slate-500 dark:text-slate-400 text-sm sm:text-base group-hover:text-emerald-600 dark:group-hover:text-emerald-400 transition-colors duration-200">
                {@placeholder}
              </span>
            </div>
          </div>

          <%!-- Action icons (visible on larger screens) --%>
          <div class="hidden sm:flex items-center gap-2">
            <div class="p-2 rounded-lg text-slate-400 dark:text-slate-500 group-hover:text-emerald-500 dark:group-hover:text-emerald-400 transition-colors duration-200">
              <.phx_icon name="hero-photo" class="h-5 w-5" />
            </div>
            <div class="p-2 rounded-lg text-slate-400 dark:text-slate-500 group-hover:text-emerald-500 dark:group-hover:text-emerald-400 transition-colors duration-200">
              <.phx_icon name="hero-face-smile" class="h-5 w-5" />
            </div>
          </div>

          <%!-- Arrow indicator --%>
          <div class="flex-shrink-0 p-2 rounded-full bg-emerald-100/80 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400 group-hover:bg-emerald-500 dark:group-hover:bg-emerald-500 group-hover:text-white transition-all duration-200">
            <.phx_icon
              name="hero-arrow-right"
              class="h-4 w-4 sm:h-5 sm:w-5 transition-transform duration-200 group-hover:translate-x-0.5"
            />
          </div>
        </div>

        <%!-- Mobile hint --%>
        <div class="sm:hidden mt-3 flex items-center justify-center gap-4 text-xs text-slate-600 dark:text-slate-400">
          <div class="flex items-center gap-1">
            <.phx_icon name="hero-photo" class="h-3.5 w-3.5" />
            <span>Photos</span>
          </div>
          <div class="flex items-center gap-1">
            <.phx_icon name="hero-face-smile" class="h-3.5 w-3.5" />
            <span>Emoji</span>
          </div>
          <div class="flex items-center gap-1">
            <.phx_icon name="hero-lock-closed" class="h-3.5 w-3.5" />
            <span>Privacy</span>
          </div>
        </div>
      </div>
    </.link>
    """
  end

  @doc """
  Timeline composer with enhanced liquid metal avatar and calm design focus.
  """
  attr :user_name, :string, required: true
  attr :user_avatar, :string, default: nil
  attr :placeholder, :string, default: "What's on your mind?"
  attr :word_limit, :integer, default: 500
  attr :privacy_level, :string, default: "connections", values: ~w(public connections private)
  attr :selector, :string, default: "connections"
  attr :form, :any, required: true
  attr :uploads, :any, default: nil
  attr :upload_stages, :map, default: %{}
  attr :completed_uploads, :list, default: []
  attr :class, :any, default: ""
  attr :privacy_controls_expanded, :boolean, default: false
  attr :content_warning_enabled?, :boolean, default: false
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"
  attr :id, :string, default: nil
  attr :url_preview, :map, default: nil
  attr :url_preview_loading, :boolean, default: false
  attr :collapsed, :boolean, default: false
  attr :bluesky_sync_enabled, :boolean, default: false

  attr :guardian_names, :list,
    default: [],
    doc: "active guardian display names that will co-read this post (I2 transparency chip)"

  attr :encrypted_avatar_data, :map,
    default: nil,
    doc: "ZK mode: encrypted avatar data for browser-side decryption"

  def liquid_timeline_composer_enhanced(assigns) do
    assigns = assign_scope_fields(assigns)

    ~H"""
    <div
      :if={!@collapsed}
      id={@id}
      phx-window-keydown="collapse_composer_esc"
      phx-key="Escape"
      phx-remove={
        JS.transition(
          {"ease-out duration-150", "opacity-100 scale-100", "opacity-0 scale-[0.97]"},
          time: 150
        )
      }
      class={[
        "relative rounded-2xl overflow-hidden transition-all duration-300 ease-out",
        "bg-white dark:bg-slate-800 backdrop-blur-xl",
        "border border-emerald-200/60 dark:border-emerald-700/40",
        "shadow-lg shadow-slate-900/10 dark:shadow-slate-900/30",
        "focus-within:border-emerald-300 dark:focus-within:border-emerald-600",
        "focus-within:shadow-xl focus-within:shadow-emerald-500/10",
        @class
      ]}
    >
      <button
        type="button"
        id={"collapse-composer-btn-#{@id}"}
        phx-click="toggle_composer_collapsed"
        class={[
          "absolute top-3 right-3 z-20 p-2 rounded-full",
          "bg-slate-100/80 dark:bg-slate-700/80 backdrop-blur-sm",
          "text-slate-500 dark:text-slate-400",
          "hover:bg-slate-200/90 dark:hover:bg-slate-600/90",
          "hover:text-slate-700 dark:hover:text-slate-200",
          "hover:scale-110 active:scale-95",
          "transition-all duration-200 ease-out",
          "focus:outline-none focus:ring-2 focus:ring-slate-400/40",
          "shadow-sm hover:shadow-md"
        ]}
        title="Collapse composer"
        phx-hook="TippyHook"
        data-tippy-content="Collapse composer"
      >
        <.phx_icon name="hero-x-mark" class="h-3.5 w-3.5" />
      </button>

      <div class="absolute inset-0 opacity-0 transition-all duration-500 ease-out bg-gradient-to-br from-emerald-50/30 via-teal-50/20 to-cyan-50/30 dark:from-emerald-900/20 dark:via-teal-900/10 dark:to-cyan-900/20 focus-within:opacity-100">
      </div>

      <div class="relative p-6 animate-in fade-in duration-200 overflow-auto max-h-[calc(100vh-10rem)]">
        <%!-- User section with enhanced liquid avatar --%>
        <div class="flex items-start gap-4 mb-4">
          <%!-- Enhanced liquid metal avatar --%>
          <.liquid_avatar
            src={@user_avatar}
            name={@user_name}
            size="md"
            status={to_string(@current_scope.user.status || "offline")}
            user_id={@current_scope.user.id}
            status_message={
              get_user_status_message(@current_scope.user, @current_scope.user, @current_scope.key)
            }
            show_status={
              can_view_status?(@current_scope.user, @current_scope.user, @current_scope.key)
            }
            encrypted_avatar_data={@encrypted_avatar_data}
            id={"composer-avatar-#{@id}"}
          />

          <%!-- Compose area with character counter --%>
          <div class="flex-1 min-w-0">
            <%!-- Guardianship transparency chip (I2): show when a guardian will co-read --%>
            <MossletWeb.FamilyComponents.composer_guardian_chip
              :if={@selector != "public" && @guardian_names != []}
              guardian_names={@guardian_names}
              class="mb-2"
            />
            <div class="relative group">
              <%!-- Hidden fields required for post creation --%>
              <.phx_input
                field={@form[:user_id]}
                type="hidden"
                name={@form[:user_id].name}
                value={@form[:user_id].value}
              />
              <.phx_input
                field={@form[:username]}
                type="hidden"
                name={@form[:username].name}
                value={@form[:username].value}
              />
              <.phx_input
                field={@form[:visibility]}
                type="hidden"
                name={@form[:visibility].name}
                value={@selector}
              />

              <%!-- Custom textarea without phx_input wrapper to maintain our styling --%>
              <textarea
                id="new-timeline-composer-textarea"
                name={@form[:body].name}
                placeholder={@placeholder}
                rows="3"
                class="w-full resize-none border-0 bg-transparent text-slate-900 dark:text-slate-100 placeholder:text-slate-500 dark:placeholder:text-slate-400 text-lg leading-relaxed focus:outline-none focus:ring-0"
                phx-hook="WordCounter"
                phx-debounce="500"
                data-limit={@word_limit}
                value={@form[:body].value}
                {alpine_autofocus()}
              >{@form[:body].value}</textarea>

              <%!-- Word counter (shows when textarea has content) --%>
              <div
                class={[
                  "absolute bottom-2 right-2 transition-all duration-300 ease-out",
                  (@form[:body].value && String.trim(@form[:body].value) != "" && "opacity-100") ||
                    "opacity-0"
                ]}
                id={"word-counter-#{@word_limit}"}
              >
                <span class="text-xs text-slate-500 dark:text-slate-400 bg-white/95 dark:bg-slate-800/95 px-3 py-1.5 rounded-full backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-lg">
                  <span class="js-word-count">{word_count(@form[:body].value)}</span>/{@word_limit} words
                </span>
              </div>
            </div>
          </div>
        </div>

        <%!-- Photo upload preview section --%>
        <.liquid_photo_upload_preview
          :if={@uploads}
          uploads={@uploads}
          upload_stages={@upload_stages}
          completed_uploads={@completed_uploads}
          class=""
        />
        <%!-- URL Preview Section --%>
        <div :if={assigns[:url_preview_loading]} class="mt-4 animate-pulse">
          <div class="flex gap-3 p-2 rounded-xl border border-slate-200/60 dark:border-slate-700/40 bg-slate-50/50 dark:bg-slate-800/50">
            <div class="w-20 h-14 shrink-0 rounded-lg bg-slate-200 dark:bg-slate-700"></div>
            <div class="flex-1 space-y-2 py-0.5">
              <div class="h-4 w-3/4 rounded bg-slate-200 dark:bg-slate-700"></div>
              <div class="h-3 w-full rounded bg-slate-200 dark:bg-slate-700"></div>
            </div>
          </div>
        </div>

        <div :if={assigns[:url_preview] && !assigns[:url_preview_loading]} class="mt-4">
          <div class="relative group">
            <button
              type="button"
              phx-click="remove_url_preview"
              class="absolute -top-2 -right-2 z-10 p-1 rounded-full bg-slate-900/80 text-white hover:bg-slate-900 transition-all opacity-0 group-hover:opacity-100"
            >
              <.phx_icon name="hero-x-mark" class="w-4 h-4" />
            </button>

            <div class="flex gap-3 p-2 rounded-xl border border-slate-200 dark:border-slate-700 bg-white/95 dark:bg-slate-800/95 hover:border-emerald-400 dark:hover:border-emerald-500 transition-all duration-200">
              <div
                :if={@url_preview["image"] && @url_preview["image"] != ""}
                class="w-20 h-14 shrink-0 overflow-hidden rounded-lg"
                phx-hook="ImageErrorHook"
                id={"url-preview-image-#{@id}"}
              >
                <img
                  src={@url_preview["image"]}
                  alt={@url_preview["title"] || "Preview image"}
                  class="w-full h-full object-cover"
                />
              </div>

              <div class="flex-1 min-w-0 py-0.5">
                <div class="flex items-center gap-1.5 mb-0.5">
                  <.phx_icon name="hero-link" class="h-3 w-3 text-emerald-500" />
                  <span class="text-xs text-slate-500 dark:text-slate-400 truncate">
                    {@url_preview["site_name"]}
                  </span>
                </div>

                <p
                  :if={@url_preview["title"]}
                  class="font-medium text-sm text-slate-900 dark:text-slate-100 line-clamp-1"
                >
                  {@url_preview["title"]}
                </p>

                <p
                  :if={@url_preview["description"]}
                  class="text-xs text-slate-600 dark:text-slate-400 line-clamp-2 mt-0.5"
                >
                  {@url_preview["description"]}
                </p>
              </div>
            </div>
          </div>
        </div>

        <%!-- Actions row with responsive layout --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between pt-4 border-t border-slate-200/50 dark:border-slate-700/50 gap-3 sm:gap-0">
          <%!-- Media and formatting actions --%>
          <div class="flex items-center gap-2">
            <%!-- Photo upload button --%>
            <label
              for={@uploads.photos.ref}
              id="photo-upload-trigger"
              class="p-2 rounded-lg text-slate-500 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50/50 dark:hover:bg-emerald-900/20 transition-all duration-200 ease-out group cursor-pointer"
              phx-hook="TippyHook"
              data-tippy-content="Add photos (GIF, JPG, PNG up to 10MB each)"
            >
              <.phx_icon
                name="hero-photo"
                class="h-5 w-5 transition-transform duration-200 group-hover:scale-110"
              />
            </label>

            <%!-- Hidden file input for photo uploads --%>
            <.live_file_input
              upload={@uploads.photos}
              class="hidden"
            />

            <button
              id="liquid-timeline-composer-emoji-button"
              type="button"
              class="p-2 rounded-lg text-slate-500 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50/50 dark:hover:bg-emerald-900/20 transition-all duration-200 ease-out group"
              phx-hook="ComposerEmojiPicker"
              title="Add emoji"
            >
              <.phx_icon
                name="hero-face-smile"
                class="h-5 w-5 transition-transform duration-200 group-hover:scale-110"
              />
            </button>
            <%!-- Content warning toggle --%>
            <button
              id={
                if @content_warning_enabled?,
                  do: "remove-content-warning-composer-button",
                  else: "add-content-warning-composer-button"
              }
              type="button"
              aria-label={
                if @content_warning_enabled?,
                  do: "Remove content warning",
                  else: "Add content warning"
              }
              class={[
                "p-2 rounded-lg transition-all duration-200 ease-out group",
                if(@content_warning_enabled?,
                  do:
                    "text-teal-600 dark:text-teal-400 bg-teal-50 dark:bg-teal-900/30 border border-teal-200 dark:border-teal-700",
                  else:
                    "text-slate-500 dark:text-slate-400 hover:text-teal-600 dark:hover:text-teal-400 hover:bg-teal-50/50 dark:hover:bg-teal-900/20"
                )
              ]}
              phx-hook="TippyHook"
              data-tippy-content={
                if @content_warning_enabled?,
                  do: "Remove content warning",
                  else: "Add content warning"
              }
              phx-click="composer_toggle_content_warning"
            >
              <.phx_icon
                name={
                  if @content_warning_enabled?, do: "hero-hand-raised-solid", else: "hero-hand-raised"
                }
                class={[
                  "h-5 w-5 transition-transform duration-200 group-hover:scale-110",
                  @content_warning_enabled? && "fill-current"
                ]}
              />
            </button>

            <.liquid_markdown_guide_trigger
              id="composer-markdown-guide-trigger"
              on_click={JS.push("open_markdown_guide")}
            />
          </div>

          <%!-- Privacy controls and post button with improved mobile stacking --%>
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-end gap-3">
            <%!-- Hidden field for form data integrity --%>
            <input
              type="hidden"
              name={@form[:visibility].name}
              value={@selector}
              id="privacy-hidden-field"
            />

            <%!-- Bluesky sync indicator (shows when public + sync enabled) --%>
            <div
              :if={@selector == "public" && @bluesky_sync_enabled}
              class="flex items-center justify-center p-2 rounded-full bg-sky-50/80 dark:bg-sky-900/30 border border-sky-200/60 dark:border-sky-700/50 text-sky-500 dark:text-sky-400"
              phx-hook="TippyHook"
              data-tippy-content="This post will sync to your connected Bluesky account"
              id="bluesky-sync-indicator"
            >
              <svg class="h-4 w-4" viewBox="0 0 568 501" fill="currentColor">
                <path d="M123.121 33.6637C188.241 82.5526 258.281 181.681 284 234.873C309.719 181.681 379.759 82.5526 444.879 33.6637C491.866 -1.61183 568 -28.9064 568 57.9464C568 75.2916 558.055 203.659 552.222 224.501C531.947 296.954 458.067 315.434 392.347 304.249C507.222 323.8 536.444 388.56 473.333 453.32C353.473 576.312 301.061 422.461 287.631 383.36C286.267 378.309 284.737 377.78 284 377.78C283.263 377.78 281.733 378.309 280.369 383.36C266.939 422.461 214.527 576.312 94.6667 453.32C31.5556 388.56 60.7778 323.8 175.653 304.249C109.933 315.434 36.0533 296.954 15.7778 224.501C9.94445 203.659 0 75.2916 0 57.9464C0 -28.9064 76.1345 -1.61183 123.121 33.6637Z" />
              </svg>
            </div>

            <%!-- Enhanced privacy selector with mobile-friendly full width --%>
            <div
              id={"privacy-selector-#{@selector}"}
              class={[
                "relative inline-flex items-center gap-2 px-3 py-2.5 rounded-full text-sm",
                "w-full sm:w-auto justify-center sm:justify-start",
                "bg-slate-100/80 dark:bg-slate-700/80 backdrop-blur-sm",
                "border border-slate-200/60 dark:border-slate-600/60",
                "hover:bg-slate-200/80 dark:hover:bg-slate-600/80",
                "transition-all duration-200 ease-out cursor-pointer group"
              ]}
              phx-click="toggle_privacy_controls"
              phx-hook="TippyHook"
              data-tippy-content="Click to expand privacy controls"
            >
              <.phx_icon
                name={privacy_icon(@selector)}
                class="h-4 w-4 text-slate-600 dark:text-slate-300 flex-shrink-0"
              />
              <span class="font-medium text-slate-700 dark:text-slate-200 privacy-label">
                {privacy_label(@selector)}
              </span>
              <%!-- Chevron indicates expandable --%>
              <.phx_icon
                name={if @privacy_controls_expanded, do: "hero-chevron-up", else: "hero-chevron-down"}
                class="h-3 w-3 text-slate-500 dark:text-slate-400 transition-transform duration-200 group-hover:scale-110"
              />
            </div>

            <%!-- Post button with mobile-friendly full width --%>
            <.liquid_button
              size="md"
              type="submit"
              class="w-full sm:w-auto sm:flex-shrink-0"
              phx-disable-with="Sharing..."
              disabled={true}
            >
              Share thoughtfully
            </.liquid_button>
          </div>
        </div>

        <%!-- Compact Privacy Controls Section (conditionally shown) --%>
        <%= if @privacy_controls_expanded do %>
          <div class="mt-3 nested-reply-expand-enter">
            <.liquid_compact_privacy_controls
              form={@form}
              selector={@selector}
              current_scope={@current_scope}
            />
          </div>
        <% end %>

        <%!-- Content Warning Section (conditionally shown) --%>
        <%= if @content_warning_enabled? do %>
          <div class="mt-3 p-3 rounded-lg bg-teal-50/50 dark:bg-teal-900/20 border border-teal-200/60 dark:border-teal-700/50">
            <div class="flex items-center gap-1.5 mb-2">
              <.phx_icon
                name="hero-hand-raised"
                class="h-3.5 w-3.5 text-teal-600 dark:text-teal-400"
              />
              <span class="text-xs font-medium text-teal-700 dark:text-teal-300">
                Content Warning
              </span>
            </div>

            <div class="space-y-2.5">
              <div class="relative">
                <textarea
                  id="content-warning-textarea"
                  name={@form[:content_warning].name}
                  placeholder="e.g., Discussion of mental health, sensitive content..."
                  rows="2"
                  maxlength="100"
                  class="w-full resize-none text-sm leading-relaxed rounded-lg px-3 py-2 bg-white dark:bg-slate-800 border border-teal-200 dark:border-teal-700 hover:border-teal-300 dark:hover:border-teal-600 focus:border-teal-500 dark:focus:border-teal-400 focus:ring-1 focus:ring-teal-500/20 text-slate-900 dark:text-slate-100 placeholder:text-teal-600/60 dark:placeholder:text-teal-400/60 transition-colors duration-200"
                  phx-hook="CharacterCounter"
                  phx-debounce="300"
                  data-limit="100"
                  value={@form[:content_warning].value}
                >{@form[:content_warning].value}</textarea>

                <div
                  class={[
                    "absolute bottom-1.5 right-1.5 transition-opacity duration-200",
                    (@form[:content_warning].value && String.trim(@form[:content_warning].value) != "" &&
                       "opacity-100") ||
                      "opacity-0"
                  ]}
                  id="char-counter-100"
                >
                  <span class="text-[10px] text-teal-600 dark:text-teal-400 bg-teal-50/90 dark:bg-teal-900/90 px-1.5 py-0.5 rounded-full">
                    <span class="js-char-count">{String.length(@form[:content_warning].value || "")}</span>/100
                  </span>
                </div>
              </div>

              <.liquid_select_custom
                field={@form[:content_warning_category]}
                label="Category (optional)"
                prompt="Select category..."
                color="teal"
                class="text-xs"
                options={[
                  {"Violence", "violence"},
                  {"Graphic Content", "graphic"},
                  {"Mental Health", "mental_health"},
                  {"Substance Use", "substance_use"},
                  {"Sexual Content", "sexual"},
                  {"Spoilers", "spoilers"},
                  {"Politics", "politics"},
                  {"News", "news"},
                  {"Flashing/Strobing", "flashing"},
                  {"Personal/Sensitive", "personal"},
                  {"Other", "other"}
                ]}
              />

              <%!-- 18+ Mature Content Toggle - Styled as a prominent button --%>
              <div class="pt-3 mt-3 border-t border-teal-200/40 dark:border-teal-700/30">
                <.mature_content_toggle field={@form[:mature_content]} />
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Word count helper (also in DesignSystem)
  defp word_count(nil), do: 0
  defp word_count(""), do: 0

  defp word_count(text) when is_binary(text) do
    text |> String.split(~r/\s+/, trim: true) |> length()
  end

  # Delegate to DesignSystem.assign_scope_fields/1
  defp assign_scope_fields(assigns), do: MossletWeb.DesignSystem.assign_scope_fields(assigns)

  # Format content warning category for display (also in DesignSystem)
  defp format_content_warning_category(category) when is_binary(category) do
    case category do
      "mental_health" -> "Mental Health"
      "violence" -> "Violence"
      "substance_use" -> "Substance Use"
      "politics" -> "Politics"
      "personal" -> "Personal/Sensitive"
      "other" -> "Other"
      _ -> String.capitalize(category)
    end
  end

  defp format_content_warning_category(_), do: "Sensitive Content"

  # Helper function to get or create a reply form for a specific post

  @doc """
  Liquid metal timeline post card with calm, privacy-focused design.

  ## Examples

      <.liquid_timeline_post
        user_name="Jane Doe"
        user_handle="@jane"
        user_avatar="/images/avatars/jane.jpg"
        timestamp="2 hours ago"
        content="This is a thoughtful post about connecting with others..."
        images={["/uploads/image1.jpg", "/uploads/image2.jpg"]}
        stats={%{replies: 3, shares: 1, likes: 12}}
      />
  """
  attr :user_name, :string, required: true
  attr :user_handle, :string, required: true
  attr :user_avatar, :string, default: nil

  attr :encrypted_author_name_data, :map,
    default: nil,
    doc:
      "ZK mode: map with :sealed_uconn_key, :encrypted_name, :encrypted_username, :show_name for browser-side author name decryption"

  attr :encrypted_avatar_data, :map,
    default: nil,
    doc:
      "ZK mode: map with :encrypted_blob_b64 and :sealed_key for browser-side avatar decryption"

  attr :user_status, :string, default: nil
  attr :user_status_message, :string, default: nil
  attr :encrypted_status_data, :map, default: nil, doc: "ZK encrypted status message + sealed key"
  attr :timestamp, :string, required: true
  attr :content, :string, required: true
  attr :images, :list, default: []
  attr :stats, :map, default: %{}
  attr :verified, :boolean, default: false
  attr :current_user_id, :string, required: true
  attr :liked, :boolean, default: false
  attr :bookmarked, :boolean, default: false
  attr :can_repost, :boolean, default: false
  attr :can_reply?, :boolean, default: false
  attr :can_bookmark?, :boolean, default: false
  attr :post, :map, required: true

  attr :post_shared_users, :list,
    default: [],
    doc: "the list of Post.SharedUser structs mapped from the current_user's user_connections"

  attr :removing_shared_user_id, :string,
    default: nil,
    doc: "the user_id of the shared user currently being removed"

  attr :adding_shared_user, :map,
    default: nil,
    doc: "map with post_id and username of user being added"

  attr :post_id, :string, default: nil
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"
  attr :is_repost, :boolean, default: false
  attr :share_note, :any, default: nil, doc: "Personal note from the sender when sharing"

  attr :bookmark_notes, :any,
    default: nil,
    doc: "Decrypted bookmark notes (public posts) or nil (ZK posts)"

  attr :encrypted_bookmark_notes, :any,
    default: nil,
    doc: "Encrypted bookmark notes blob for browser-side ZK decryption"

  # New: unread state
  attr :unread?, :boolean, default: false
  attr :unread_replies_count, :integer, default: 0
  attr :unread_nested_replies_by_parent, :map, default: %{}
  attr :calm_notifications, :boolean, default: false
  attr :class, :any, default: ""
  # Content warning
  attr :content_warning?, :boolean, default: false

  attr :content_warning, :any,
    default: nil,
    doc: "type :string but we default to nil so we use :any type"

  attr :content_warning_category, :any,
    default: nil,
    doc: "type :string but we default to nil so we use :any type"

  attr :decrypted_url_preview, :any,
    default: nil,
    doc: "type :map but we default to nil so we use :any type"

  # Report modal state
  attr :show_report_modal?, :boolean, default: false

  attr :show_post_author_status, :boolean,
    default: true,
    doc: "Whether to show the status indicator (based on privacy settings)"

  attr :author_profile_slug, :string,
    default: nil,
    doc: "The profile slug of the post author (for linking to their profile)"

  attr :author_profile_visibility, :atom,
    default: nil,
    doc: "The profile visibility of the post author (:private, :connections, :public)"

  def liquid_timeline_post(assigns) do
    assigns = assign_scope_fields(assigns)

    ~H"""
    <article
      id={"timeline-card-#{@post.id}"}
      phx-hook="PostExpandHook"
      class={[
        "group relative rounded-3xl transition-all duration-300 ease-out flex flex-col",
        "w-full max-w-2xl mx-auto",
        "bg-white/90 dark:bg-slate-800/90 backdrop-blur-sm",
        "border border-slate-200/40 dark:border-slate-700/40",
        "shadow-sm shadow-slate-900/5 dark:shadow-slate-900/15",
        "hover:shadow-md hover:shadow-slate-900/8 dark:hover:shadow-slate-900/25",
        "hover:border-slate-200/60 dark:hover:border-slate-600/50",
        "transform-gpu will-change-transform",
        if(@unread?,
          do:
            "ring-1 ring-teal-400/30 dark:ring-cyan-500/40 shadow-md shadow-teal-500/15 dark:shadow-cyan-400/20 border-teal-200/50 dark:border-cyan-700/50",
          else: ""
        ),
        @class
      ]}
    >
      <%!-- Enhanced liquid background on hover with subtle styling --%>
      <div class={[
        "absolute inset-0 opacity-0 transition-all duration-500 ease-out",
        "group-hover:opacity-100 touch-hover:opacity-100",
        "bg-gradient-to-br from-teal-50/20 via-emerald-50/10 to-cyan-50/20 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10"
      ]}>
      </div>

      <.liquid_post_indicators post={@post} current_user_id={@current_user_id} is_repost={@is_repost} />

      <.liquid_post_overlays
        post={@post}
        current_user_id={@current_user_id}
        is_repost={@is_repost}
        user_name={@user_name}
        share_note={@share_note}
        post_shared_users={@post_shared_users}
        removing_shared_user_id={@removing_shared_user_id}
        adding_shared_user={@adding_shared_user}
      />

      <.liquid_post_content_warning
        post={@post}
        content_warning?={@content_warning?}
        content_warning={@content_warning}
        content_warning_category={@content_warning_category}
      />

      <%!-- Post content --%>
      <div class="relative p-6 flex-1 flex flex-col">
        <.liquid_post_header
          post={@post}
          current_user_id={@current_user_id}
          user_name={@user_name}
          user_handle={@user_handle}
          user_avatar={@user_avatar}
          encrypted_avatar_data={@encrypted_avatar_data}
          encrypted_author_name_data={@encrypted_author_name_data}
          user_status={@user_status}
          user_status_message={@user_status_message}
          encrypted_status_data={@encrypted_status_data}
          show_post_author_status={@show_post_author_status}
          author_profile_slug={@author_profile_slug}
          author_profile_visibility={@author_profile_visibility}
          timestamp={@timestamp}
          verified={@verified}
        />

        <.liquid_post_content_warning_bar
          post={@post}
          content_warning?={@content_warning?}
          content_warning={@content_warning}
        />

        <%!-- Post content with markdown support --%>
        <div class="mb-4 flex-1">
          <.liquid_post_body
            post={@post}
            content={@content}
            current_user_id={@current_user_id}
            encrypted_author_name_data={@encrypted_author_name_data}
          />

          <.liquid_post_media
            post={@post}
            current_scope={@current_scope}
            decrypted_url_preview={@decrypted_url_preview}
          />
        </div>

        <.liquid_post_actions
          post={@post}
          post_id={@post_id}
          content={@content}
          user_handle={@user_handle}
          current_scope={@current_scope}
          current_user_id={@current_user_id}
          stats={@stats}
          liked={@liked}
          bookmarked={@bookmarked}
          can_repost={@can_repost}
          can_reply?={@can_reply?}
          can_bookmark?={@can_bookmark?}
          unread?={@unread?}
          unread_replies_count={@unread_replies_count}
          calm_notifications={@calm_notifications}
          bookmark_notes={@bookmark_notes}
          encrypted_bookmark_notes={@encrypted_bookmark_notes}
        />
      </div>
    </article>
    <%!-- Collapsible reply composer LiveComponent (hidden by default, toggled by JS) --%>
    <.live_component
      :if={@can_reply?}
      module={MossletWeb.TimelineLive.ReplyComposerComponent}
      id={"reply-composer-#{@post.id}"}
      post_id={@post.id}
      visibility={@post.visibility}
      current_scope={@current_scope}
      user_name={user_name(@current_scope.user, @current_scope.key) || "You"}
      user_avatar={
        if show_avatar?(@current_scope.user),
          do: nil,
          else: "/images/logo.svg"
      }
      encrypted_avatar_data={
        if show_avatar?(@current_scope.user),
          do: get_encrypted_avatar_data(@current_scope.user, @current_scope.key)
      }
      word_limit={500}
      username={username(@current_scope.user, @current_scope.key)}
      class=""
    />

    <%!-- Collapsible reply thread (uses existing liquid components) --%>
    <MossletWeb.ReplyComponents.liquid_collapsible_reply_thread
      post_id={@post.id}
      replies={@post.replies || []}
      reply_count={Map.get(@stats, :replies, 0)}
      show={true}
      current_scope={@current_scope}
      browser_decrypt={@post.decrypted[:browser_decrypt?] || false}
      sealed_post_key={@post.decrypted[:sealed_post_key]}
      unread_nested_replies_by_parent={@unread_nested_replies_by_parent}
      calm_notifications={@calm_notifications}
      class="mt-3"
    />
    """
  end

  @doc false
  attr :post, :map, required: true
  attr :current_user_id, :string, required: true
  attr :is_repost, :boolean, default: false

  def liquid_post_indicators(assigns) do
    ~H"""
    <%!-- Subtle left-side shared indicator for posts shared WITH you --%>
    <button
      :if={@is_repost && @current_user_id != @post.user_id}
      type="button"
      phx-click={
        JS.show(
          to: "#share-overlay-#{@post.id}",
          transition:
            {"ease-out duration-200", "opacity-0 -translate-x-4", "opacity-100 translate-x-0"}
        )
      }
      class="absolute left-0 top-4 bottom-4 w-1 bg-gradient-to-b from-emerald-400 via-teal-400 to-emerald-400 dark:from-emerald-500 dark:via-teal-500 dark:to-emerald-500 rounded-r-full opacity-70 hover:opacity-100 hover:w-1.5 transition-all duration-200 cursor-pointer group z-10"
      aria-label="View shared message"
    >
      <span class="absolute left-3 top-1/2 -translate-y-1/2 opacity-0 group-hover:opacity-100 touch-hover:opacity-100 transition-opacity duration-200 whitespace-nowrap text-xs font-medium text-emerald-600 dark:text-emerald-400 bg-white/90 dark:bg-slate-800/90 px-2 py-1 rounded-md shadow-sm border border-emerald-200/50 dark:border-emerald-700/50">
        Shared with you
      </span>
    </button>

    <%!-- Subtle left-side indicator for posts YOU shared with others (reposts only) --%>
    <button
      :if={@is_repost && @current_user_id == @post.user_id && !Enum.empty?(@post.shared_users)}
      type="button"
      phx-click={
        JS.show(
          to: "#shared-by-you-overlay-#{@post.id}",
          transition:
            {"ease-out duration-200", "opacity-0 -translate-x-4", "opacity-100 translate-x-0"}
        )
      }
      class="absolute left-0 top-4 bottom-4 w-1 bg-gradient-to-b from-sky-400 via-blue-400 to-sky-400 dark:from-sky-500 dark:via-blue-500 dark:to-sky-500 rounded-r-full opacity-70 hover:opacity-100 hover:w-1.5 transition-all duration-200 cursor-pointer group z-10"
      aria-label="View who you shared with"
    >
      <span class="absolute left-3 top-1/2 -translate-y-1/2 opacity-0 group-hover:opacity-100 touch-hover:opacity-100 transition-opacity duration-200 whitespace-nowrap text-xs font-medium text-sky-600 dark:text-sky-400 bg-white/90 dark:bg-slate-800/90 px-2 py-1 rounded-md shadow-sm border border-sky-200/50 dark:border-sky-700/50">
        You shared this
      </span>
    </button>

    <%!-- Right-side visibility indicator for post owner (non-public posts) --%>
    <button
      :if={@current_user_id == @post.user_id && @post.visibility != :public}
      type="button"
      phx-click={
        JS.show(
          to: "#visibility-overlay-#{@post.id}",
          transition:
            {"ease-out duration-200", "opacity-0 translate-x-4", "opacity-100 translate-x-0"}
        )
      }
      class={"absolute right-0 top-4 bottom-4 w-1 bg-gradient-to-b #{visibility_indicator_gradient(@post.visibility)} rounded-l-full opacity-70 hover:opacity-100 hover:w-1.5 transition-all duration-200 cursor-pointer group z-10"}
      aria-label="View visibility settings"
      id={"visibility-indicator-#{@post.id}"}
    >
      <span class={"absolute right-3 top-1/2 -translate-y-1/2 opacity-0 group-hover:opacity-100 touch-hover:opacity-100 transition-opacity duration-200 whitespace-nowrap text-xs font-medium px-2 py-1 rounded-md shadow-sm border #{visibility_indicator_hover_text_classes(@post.visibility)}"}>
        {visibility_badge_text(@post.visibility)}
      </span>
    </button>

    <%!-- Right-side visibility indicator for non-owner or public posts (non-interactive) --%>
    <div
      :if={@current_user_id != @post.user_id || @post.visibility == :public}
      class={"absolute right-0 top-4 bottom-4 w-1 bg-gradient-to-b #{visibility_indicator_gradient(@post.visibility)} rounded-l-full opacity-50 group z-10"}
      aria-label={visibility_badge_text(@post.visibility)}
    >
      <span class={"absolute right-3 top-1/2 -translate-y-1/2 opacity-0 group-hover:opacity-100 touch-hover:opacity-100 transition-opacity duration-200 whitespace-nowrap text-xs font-medium px-2 py-1 rounded-md shadow-sm border #{visibility_indicator_hover_text_classes(@post.visibility)}"}>
        {visibility_badge_text(@post.visibility)}
      </span>
    </div>
    """
  end

  @doc false
  attr :post, :map, required: true
  attr :current_user_id, :string, required: true
  attr :is_repost, :boolean, default: false
  attr :user_name, :string, required: true
  attr :share_note, :any, default: nil
  attr :post_shared_users, :list, default: []
  attr :removing_shared_user_id, :string, default: nil
  attr :adding_shared_user, :map, default: nil

  def liquid_post_overlays(assigns) do
    ~H"""
    <%!-- Share note overlay modal for posts shared WITH you --%>
    <div
      :if={@is_repost && @current_user_id != @post.user_id}
      id={"share-overlay-#{@post.id}"}
      class="hidden absolute inset-0 z-20 bg-white/98 dark:bg-slate-800/98 backdrop-blur-sm rounded-2xl overflow-hidden"
      phx-window-keydown={
        JS.hide(
          to: "#share-overlay-#{@post.id}",
          transition:
            {"ease-in duration-150", "opacity-100 translate-x-0", "opacity-0 -translate-x-4"}
        )
      }
      phx-key="Escape"
    >
      <div class="absolute left-0 top-0 bottom-0 w-1.5 bg-gradient-to-b from-emerald-400 via-teal-400 to-emerald-400 dark:from-emerald-500 dark:via-teal-500 dark:to-emerald-500 rounded-r-full shadow-[0_0_8px_rgba(52,211,153,0.4)] dark:shadow-[0_0_8px_rgba(52,211,153,0.3)]">
      </div>
      <div class="h-full flex flex-col p-4 pl-5 overflow-hidden">
        <div class="flex items-center gap-3 mb-3 shrink-0">
          <div class="flex items-center justify-center w-9 h-9 rounded-full bg-gradient-to-br from-emerald-100 to-teal-100 dark:from-emerald-900/50 dark:to-teal-900/50 shadow-sm">
            <.phx_icon
              name="hero-paper-airplane-solid"
              class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
            />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-semibold text-slate-900 dark:text-slate-100">
              Shared by {@user_name}
            </p>
          </div>
          <button
            type="button"
            phx-click={
              JS.hide(
                to: "#share-overlay-#{@post.id}",
                transition:
                  {"ease-in duration-150", "opacity-100 translate-x-0", "opacity-0 -translate-x-4"}
              )
            }
            class="p-1.5 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg transition-colors duration-200"
            aria-label="Close"
          >
            <.phx_icon name="hero-x-mark" class="h-4 w-4" />
          </button>
        </div>
        <%= if @share_note do %>
          <div class="flex-1 min-h-0 overflow-y-auto">
            <p class="text-sm text-slate-700 dark:text-slate-300 leading-relaxed break-words whitespace-pre-wrap">
              {@share_note}
            </p>
          </div>
        <% else %>
          <p
            data-decrypt-share-note-target={@post.id}
            class="text-sm text-slate-500 dark:text-slate-400"
          >
            No message included
          </p>
        <% end %>
        <button
          type="button"
          phx-click={
            JS.hide(
              to: "#share-overlay-#{@post.id}",
              transition:
                {"ease-in duration-150", "opacity-100 translate-x-0", "opacity-0 -translate-x-4"}
            )
          }
          class="mt-3 inline-flex items-center gap-1.5 self-start text-xs font-medium text-emerald-600 dark:text-emerald-400 bg-emerald-50/80 dark:bg-emerald-900/30 hover:bg-emerald-100 dark:hover:bg-emerald-900/50 px-3 py-1.5 rounded-lg border border-emerald-200/50 dark:border-emerald-700/50 transition-colors duration-200 shrink-0"
        >
          <.phx_icon name="hero-arrow-left-mini" class="h-3.5 w-3.5" /> Back to post
        </button>
      </div>
    </div>

    <%!-- Overlay modal for posts YOU shared with others --%>
    <div
      :if={@current_user_id == @post.user_id && !Enum.empty?(@post.shared_users)}
      id={"shared-by-you-overlay-#{@post.id}"}
      class="hidden absolute inset-0 z-20 bg-white/98 dark:bg-slate-800/98 backdrop-blur-sm rounded-2xl overflow-hidden"
      phx-window-keydown={
        JS.hide(
          to: "#shared-by-you-overlay-#{@post.id}",
          transition:
            {"ease-in duration-150", "opacity-100 translate-x-0", "opacity-0 -translate-x-4"}
        )
      }
      phx-key="Escape"
    >
      <div class="absolute left-0 top-0 bottom-0 w-1.5 bg-gradient-to-b from-sky-400 via-blue-400 to-sky-400 dark:from-sky-500 dark:via-blue-500 dark:to-sky-500 rounded-r-full shadow-[0_0_8px_rgba(56,189,248,0.4)] dark:shadow-[0_0_8px_rgba(56,189,248,0.3)]">
      </div>
      <div class="h-full flex flex-col p-4 pl-5 overflow-hidden">
        <div class="flex items-center gap-3 mb-3 shrink-0">
          <div class="flex items-center justify-center w-9 h-9 rounded-full bg-gradient-to-br from-sky-100 to-blue-100 dark:from-sky-900/50 dark:to-blue-900/50 shadow-sm">
            <.phx_icon
              name="hero-share-solid"
              class="h-4 w-4 text-sky-600 dark:text-sky-400"
            />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-semibold text-slate-900 dark:text-slate-100">
              You shared this
            </p>
          </div>
          <button
            type="button"
            phx-click={
              JS.hide(
                to: "#shared-by-you-overlay-#{@post.id}",
                transition:
                  {"ease-in duration-150", "opacity-100 translate-x-0", "opacity-0 -translate-x-4"}
              )
            }
            class="p-1.5 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg transition-colors duration-200"
            aria-label="Close"
          >
            <.phx_icon name="hero-x-mark" class="h-4 w-4" />
          </button>
        </div>
        <p class="text-xs text-slate-500 dark:text-slate-400 mb-3 shrink-0">
          Shared with {length(@post.shared_users)} {if length(@post.shared_users) == 1,
            do: "person",
            else: "people"}
        </p>
        <div class="flex-1 min-h-0 overflow-y-auto space-y-1.5">
          <%= for shared_user <- @post.shared_users do %>
            <% shared_post_user =
              MossletWeb.ReplyComponents.get_shared_connection(
                shared_user.user_id,
                @post_shared_users
              ) %>
            <div class="flex items-center gap-3 p-2 bg-slate-50/80 dark:bg-slate-700/50 rounded-lg">
              <%= if shared_post_user do %>
                <div class={[
                  "flex h-8 w-8 shrink-0 items-center justify-center rounded-lg",
                  "bg-gradient-to-br transition-all duration-200",
                  MossletWeb.ConnectionComponents.get_post_shared_user_classes(shared_post_user.color)
                ]}>
                  <span class={[
                    "text-sm font-semibold",
                    MossletWeb.ConnectionComponents.get_post_shared_user_text_classes(
                      shared_post_user.color
                    )
                  ]}>
                    {String.first(shared_post_user.username || "?") |> String.upcase()}
                  </span>
                </div>
                <span class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate">
                  {shared_post_user.username}
                </span>
              <% else %>
                <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-slate-200 dark:bg-slate-700">
                  <.phx_icon
                    name="hero-user-minus"
                    class="w-4 h-4 text-slate-400 dark:text-slate-500"
                  />
                </div>
                <span class="text-sm font-medium text-slate-500 dark:text-slate-400 truncate italic">
                  Former connection
                </span>
              <% end %>
            </div>
          <% end %>
        </div>
        <button
          type="button"
          phx-click={
            JS.hide(
              to: "#shared-by-you-overlay-#{@post.id}",
              transition:
                {"ease-in duration-150", "opacity-100 translate-x-0", "opacity-0 -translate-x-4"}
            )
          }
          class="mt-3 inline-flex items-center gap-1.5 self-start text-xs font-medium text-sky-600 dark:text-sky-400 bg-sky-50/80 dark:bg-sky-900/30 hover:bg-sky-100 dark:hover:bg-sky-900/50 px-3 py-1.5 rounded-lg border border-sky-200/50 dark:border-sky-700/50 transition-colors duration-200 shrink-0"
        >
          <.phx_icon name="hero-arrow-left-mini" class="h-3.5 w-3.5" /> Back to post
        </button>
      </div>
    </div>

    <%!-- Visibility/Shared users overlay for post owner --%>
    <div
      :if={@current_user_id == @post.user_id && @post.visibility != :public}
      id={"visibility-overlay-#{@post.id}"}
      class="hidden absolute inset-0 z-20 bg-white/98 dark:bg-slate-800/98 backdrop-blur-sm rounded-2xl overflow-hidden"
      phx-window-keydown={
        JS.hide(
          to: "#visibility-overlay-#{@post.id}",
          transition: {"ease-in duration-150", "opacity-100 translate-x-0", "opacity-0 translate-x-4"}
        )
      }
      phx-key="Escape"
    >
      <div class={"absolute right-0 top-0 bottom-0 w-1.5 bg-gradient-to-b #{visibility_overlay_gradient(@post.visibility)} rounded-l-full shadow-[0_0_8px_rgba(168,85,247,0.4)] dark:shadow-[0_0_8px_rgba(168,85,247,0.3)]"}>
      </div>
      <div class="h-full flex flex-col p-4 pr-5 overflow-hidden">
        <div class="flex items-center gap-3 mb-3 shrink-0">
          <div class={"flex items-center justify-center w-9 h-9 rounded-full bg-gradient-to-br #{visibility_overlay_icon_bg(@post.visibility)} shadow-sm"}>
            <.phx_icon
              name={visibility_overlay_icon(@post.visibility)}
              class={"h-4 w-4 #{visibility_overlay_icon_color(@post.visibility)}"}
            />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-semibold text-slate-900 dark:text-slate-100">
              {visibility_badge_text(@post.visibility)}
            </p>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
              <%= if @post.visibility == :private do %>
                Only visible to you
              <% else %>
                {length(@post.shared_users)} {if length(@post.shared_users) == 1,
                  do: "person",
                  else: "people"}
              <% end %>
            </p>
          </div>
          <button
            type="button"
            phx-click={
              JS.hide(
                to: "#visibility-overlay-#{@post.id}",
                transition:
                  {"ease-in duration-150", "opacity-100 translate-x-0", "opacity-0 translate-x-4"}
              )
            }
            class="p-1.5 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg transition-colors duration-200"
            aria-label="Close"
          >
            <.phx_icon name="hero-x-mark" class="h-4 w-4" />
          </button>
        </div>

        <%= if @post.visibility == :private do %>
          <div class="flex-1 flex flex-col items-center justify-center text-center">
            <div class="inline-flex items-center justify-center w-12 h-12 mb-3 rounded-full bg-gradient-to-br from-slate-100 to-slate-200 dark:from-slate-700 dark:to-slate-600">
              <.phx_icon name="hero-lock-closed" class="w-6 h-6 text-slate-500 dark:text-slate-400" />
            </div>
            <p class="text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
              Private post
            </p>
            <p class="text-xs text-slate-500 dark:text-slate-400 max-w-[200px]">
              This post is only visible to you.
            </p>
          </div>
          <div class="pt-3 mt-3 border-t border-slate-200/60 dark:border-slate-700/60 shrink-0 flex justify-end">
            <button
              type="button"
              phx-click={
                JS.hide(
                  to: "#visibility-overlay-#{@post.id}",
                  transition:
                    {"ease-in duration-150", "opacity-100 translate-x-0", "opacity-0 translate-x-4"}
                )
              }
              class={"inline-flex items-center gap-1.5 text-xs font-medium #{visibility_overlay_back_button_classes(@post.visibility)} px-3 py-1.5 rounded-lg border transition-colors duration-200"}
            >
              Back to post <.phx_icon name="hero-arrow-right-mini" class="h-3.5 w-3.5" />
            </button>
          </div>
        <% else %>
          <div class="flex-1 min-h-0 overflow-y-auto">
            <div class="grid grid-cols-2 gap-1.5">
              <%= for shared_user <- @post.shared_users do %>
                <% shared_post_user =
                  MossletWeb.ReplyComponents.get_shared_connection(
                    shared_user.user_id,
                    @post_shared_users
                  ) %>
                <% shared_user_id_str =
                  if is_binary(shared_user.user_id),
                    do: Ecto.UUID.cast!(shared_user.user_id),
                    else: shared_user.user_id %>
                <% is_removing = @removing_shared_user_id == shared_user_id_str %>
                <div class={[
                  "relative flex items-center gap-2 p-1.5 bg-slate-50/80 dark:bg-slate-700/50 rounded-lg transition-all duration-200",
                  is_removing && "opacity-50 pointer-events-none"
                ]}>
                  <%= if shared_post_user do %>
                    <.link
                      :if={MossletWeb.ReplyComponents.show_profile?(shared_post_user)}
                      id={"profile-link-#{@post.id}-person-#{shared_user.user_id}"}
                      phx-hook="TippyHook"
                      data-tippy-content="View profile"
                      navigate={~p"/app/profile/#{shared_post_user.profile_slug}"}
                      class="flex items-center gap-2 flex-1 min-w-0"
                    >
                      <div class={[
                        "flex h-6 w-6 shrink-0 items-center justify-center rounded",
                        "bg-gradient-to-br transition-all duration-200",
                        MossletWeb.ConnectionComponents.get_post_shared_user_classes(
                          shared_post_user.color
                        )
                      ]}>
                        <span class={[
                          "text-xs font-semibold",
                          MossletWeb.ConnectionComponents.get_post_shared_user_text_classes(
                            shared_post_user.color
                          )
                        ]}>
                          {String.first(shared_post_user.username || "?") |> String.upcase()}
                        </span>
                      </div>
                      <span class="text-xs font-medium text-slate-900 dark:text-slate-100 truncate">
                        {shared_post_user.username}
                      </span>
                    </.link>
                    <div
                      :if={!MossletWeb.ReplyComponents.show_profile?(shared_post_user)}
                      class="flex items-center gap-2 flex-1 min-w-0"
                    >
                      <div class={[
                        "flex h-6 w-6 shrink-0 items-center justify-center rounded",
                        "bg-gradient-to-br transition-all duration-200",
                        MossletWeb.ConnectionComponents.get_post_shared_user_classes(
                          shared_post_user.color
                        )
                      ]}>
                        <span class={[
                          "text-xs font-semibold",
                          MossletWeb.ConnectionComponents.get_post_shared_user_text_classes(
                            shared_post_user.color
                          )
                        ]}>
                          {String.first(shared_post_user.username || "?") |> String.upcase()}
                        </span>
                      </div>
                      <span class="text-xs font-medium text-slate-900 dark:text-slate-100 truncate">
                        {shared_post_user.username}
                      </span>
                    </div>
                    <button
                      type="button"
                      phx-click="remove_shared_user"
                      phx-value-post-id={@post.id}
                      phx-value-user-id={shared_user.user_id}
                      phx-value-shared-username={shared_post_user.username}
                      class="p-0.5 rounded text-slate-400 dark:text-slate-500 hover:text-rose-600 dark:hover:text-rose-400 hover:bg-rose-50 dark:hover:bg-rose-900/30 transition-all duration-200 shrink-0"
                      phx-hook="TippyHook"
                      data-tippy-content="Remove access"
                      id={"remove-access-#{@post.id}-person-#{shared_user.user_id}"}
                    >
                      <span class="sr-only">Remove access for {shared_post_user.username}</span>
                      <%= if is_removing do %>
                        <.phx_icon name="hero-arrow-path-mini" class="w-3.5 h-3.5 animate-spin" />
                      <% else %>
                        <.phx_icon name="hero-trash-mini" class="w-3.5 h-3.5" />
                      <% end %>
                    </button>
                  <% else %>
                    <div class="flex items-center gap-2 flex-1 min-w-0">
                      <div class="flex h-6 w-6 shrink-0 items-center justify-center rounded bg-slate-200 dark:bg-slate-700">
                        <.phx_icon
                          name="hero-user-minus"
                          class="w-3 h-3 text-slate-400 dark:text-slate-500"
                        />
                      </div>
                      <span class="text-xs font-medium text-slate-500 dark:text-slate-400 truncate italic">
                        Former
                      </span>
                    </div>
                    <button
                      type="button"
                      phx-click="remove_shared_user"
                      phx-value-post-id={@post.id}
                      phx-value-user-id={shared_user.user_id}
                      phx-value-shared-username=""
                      class="p-0.5 rounded text-slate-400 dark:text-slate-500 hover:text-rose-600 dark:hover:text-rose-400 hover:bg-rose-50 dark:hover:bg-rose-900/30 transition-all duration-200 shrink-0"
                      title="Remove"
                    >
                      <%= if is_removing do %>
                        <.phx_icon name="hero-arrow-path-mini" class="w-3.5 h-3.5 animate-spin" />
                      <% else %>
                        <.phx_icon name="hero-trash-mini" class="w-3.5 h-3.5" />
                      <% end %>
                    </button>
                  <% end %>
                </div>
              <% end %>
            </div>

            <div :if={Enum.empty?(@post.shared_users)} class="py-2 text-center">
              <div class="inline-flex items-center justify-center w-8 h-8 mb-1.5 rounded-full bg-slate-100 dark:bg-slate-700">
                <.phx_icon
                  name="hero-user-group"
                  class="w-4 h-4 text-slate-400 dark:text-slate-500"
                />
              </div>
              <p class="text-xs text-slate-500 dark:text-slate-400">
                Not shared with anyone yet
              </p>
            </div>
          </div>

          <div class="pt-3 mt-3 border-t border-slate-200/60 dark:border-slate-700/60 shrink-0">
            <% available_connections =
              Enum.reject(@post_shared_users, fn psu ->
                Enum.any?(@post.shared_users, &(&1.user_id == psu.user_id))
              end) %>

            <%= if @adding_shared_user && @adding_shared_user.post_id == @post.id do %>
              <div class="flex items-center gap-2 p-2 rounded-lg bg-emerald-50 dark:bg-emerald-900/20 animate-pulse">
                <.phx_icon
                  name="hero-arrow-path"
                  class="w-4 h-4 text-emerald-600 dark:text-emerald-400 animate-spin"
                />
                <span class="text-sm text-emerald-700 dark:text-emerald-300">
                  Adding {@adding_shared_user.username}...
                </span>
              </div>
            <% else %>
              <%= if Enum.empty?(available_connections) do %>
                <p class="text-xs text-slate-400 dark:text-slate-500 text-center py-1">
                  All connections have access
                </p>
              <% else %>
                <div class="relative" id={"add-shared-user-overlay-#{@post.id}"}>
                  <button
                    type="button"
                    phx-click={JS.toggle(to: "#add-shared-user-overlay-list-#{@post.id}")}
                    class={"w-full flex items-center justify-center gap-2 px-3 py-2 text-sm font-medium rounded-lg border border-dashed transition-all duration-200 #{visibility_add_button_classes(@post.visibility)}"}
                  >
                    <.phx_icon name="hero-plus-mini" class="w-4 h-4" /> Add someone
                  </button>

                  <div
                    id={"add-shared-user-overlay-list-#{@post.id}"}
                    phx-click-away={JS.hide(to: "#add-shared-user-overlay-list-#{@post.id}")}
                    phx-key="escape"
                    phx-window-keydown={JS.hide(to: "#add-shared-user-overlay-list-#{@post.id}")}
                    class="hidden absolute bottom-full left-0 right-0 mb-2 max-h-48 overflow-y-auto rounded-xl border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-800 shadow-xl ring-1 ring-black/5 dark:ring-white/10 backdrop-blur-sm animate-in fade-in slide-in-from-bottom-2 duration-150"
                  >
                    <div class="p-1.5 space-y-0.5">
                      <div
                        :for={conn <- available_connections}
                        id={"add-shared-user-item-#{@post.id}-#{conn.user_id}"}
                        phx-click={
                          JS.hide(to: "#add-shared-user-overlay-list-#{@post.id}")
                          |> JS.push("add_shared_user")
                        }
                        phx-value-post-id={@post.id}
                        phx-value-user-id={conn.user_id}
                        phx-value-username={conn.username}
                        class={[
                          "flex items-center gap-3 px-3 py-2.5 cursor-pointer rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700/60 active:bg-slate-200 dark:active:bg-slate-600/60 transition-colors duration-150",
                          @adding_shared_user && @adding_shared_user.post_id == @post.id &&
                            @adding_shared_user.username == conn.username &&
                            "opacity-50 pointer-events-none"
                        ]}
                      >
                        <%= if @adding_shared_user && @adding_shared_user.post_id == @post.id && @adding_shared_user.username == conn.username do %>
                          <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-emerald-100 dark:bg-emerald-900/30">
                            <.phx_icon
                              name="hero-arrow-path"
                              class="w-4 h-4 text-emerald-600 dark:text-emerald-400 animate-spin"
                            />
                          </div>
                          <span class="text-sm font-medium text-emerald-600 dark:text-emerald-400">
                            Adding...
                          </span>
                        <% else %>
                          <div class={[
                            "flex h-8 w-8 shrink-0 items-center justify-center rounded-lg shadow-sm",
                            "bg-gradient-to-br",
                            MossletWeb.ConnectionComponents.get_post_shared_user_classes(conn.color)
                          ]}>
                            <span class={[
                              "text-xs font-bold",
                              MossletWeb.ConnectionComponents.get_post_shared_user_text_classes(
                                conn.color
                              )
                            ]}>
                              {String.first(conn.username || "?") |> String.upcase()}
                            </span>
                          </div>
                          <span class={[
                            "text-sm font-medium truncate",
                            MossletWeb.ConnectionComponents.get_post_shared_user_text_classes(
                              conn.color
                            )
                          ]}>
                            {conn.username}
                          </span>
                        <% end %>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
          <button
            type="button"
            phx-click={
              JS.hide(
                to: "#visibility-overlay-#{@post.id}",
                transition:
                  {"ease-in duration-150", "opacity-100 translate-x-0", "opacity-0 translate-x-4"}
              )
            }
            class={"mt-3 inline-flex items-center gap-1.5 self-end text-xs font-medium #{visibility_overlay_back_button_classes(@post.visibility)} px-3 py-1.5 rounded-lg border transition-colors duration-200 shrink-0"}
          >
            Back to post <.phx_icon name="hero-arrow-right-mini" class="h-3.5 w-3.5" />
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  @doc false
  attr :post, :map, required: true
  attr :content_warning?, :boolean, default: false
  attr :content_warning, :any, default: nil
  attr :content_warning_category, :any, default: nil

  def liquid_post_content_warning(assigns) do
    ~H"""
    <%!-- Content Warning Overlay (covers entire post) --%>
    <div
      :if={(@content_warning? && @content_warning) || @post.mature_content}
      id={"content-warning-#{@post.id}"}
      class={[
        "content-warning-overlay absolute inset-0 z-20 rounded-2xl backdrop-blur-sm transition-all duration-300 ease-out overflow-hidden",
        if(@post.mature_content && !(@content_warning? && @content_warning),
          do: "bg-amber-50/95 dark:bg-slate-800/98",
          else: "bg-teal-50/95 dark:bg-slate-800/98"
        )
      ]}
    >
      <div class={[
        "absolute inset-0",
        if(@post.mature_content && !(@content_warning? && @content_warning),
          do:
            "bg-gradient-to-b from-amber-100/50 via-amber-50/30 to-amber-100/50 dark:from-amber-900/40 dark:via-slate-800/20 dark:to-amber-900/40",
          else:
            "bg-gradient-to-b from-teal-100/50 via-teal-50/30 to-teal-100/50 dark:from-teal-900/40 dark:via-slate-800/20 dark:to-teal-900/40"
        )
      ]}>
      </div>
      <div class={[
        "absolute top-0 left-0 right-0 h-1 opacity-60",
        if(@post.mature_content && !(@content_warning? && @content_warning),
          do:
            "bg-gradient-to-r from-amber-400 via-orange-400 to-amber-400 dark:from-amber-500 dark:via-orange-500 dark:to-amber-500",
          else:
            "bg-gradient-to-r from-teal-400 via-cyan-400 to-teal-400 dark:from-teal-500 dark:via-cyan-500 dark:to-teal-500"
        )
      ]}>
      </div>
      <div class="relative h-full flex flex-col justify-center p-4 sm:p-6">
        <div class="flex items-start gap-4">
          <div class={[
            "flex-shrink-0 flex items-center justify-center w-10 h-10 sm:w-12 sm:h-12 rounded-full border shadow-sm",
            if(@post.mature_content && !(@content_warning? && @content_warning),
              do:
                "bg-gradient-to-br from-amber-100 to-orange-100 dark:from-amber-800/60 dark:to-orange-800/60 border-amber-200 dark:border-amber-700",
              else:
                "bg-gradient-to-br from-teal-100 to-cyan-100 dark:from-teal-800/60 dark:to-cyan-800/60 border-teal-200 dark:border-teal-700"
            )
          ]}>
            <.phx_icon
              name={
                if @post.mature_content && !(@content_warning? && @content_warning),
                  do: "hero-exclamation-triangle",
                  else: "hero-hand-raised"
              }
              class={[
                "h-5 w-5 sm:h-6 sm:w-6",
                if(@post.mature_content && !(@content_warning? && @content_warning),
                  do: "text-amber-600 dark:text-amber-400",
                  else: "text-teal-600 dark:text-teal-400"
                )
              ]}
            />
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex flex-wrap items-center gap-2 mb-1">
              <span class={[
                "text-base sm:text-lg font-semibold",
                if(@post.mature_content && !(@content_warning? && @content_warning),
                  do: "text-amber-700 dark:text-amber-300",
                  else: "text-teal-700 dark:text-teal-300"
                )
              ]}>
                <%= if @post.mature_content && !(@content_warning? && @content_warning) do %>
                  18+ Mature Content
                <% else %>
                  Content Warning
                <% end %>
              </span>
              <%= if @content_warning_category do %>
                <span
                  data-decrypt-cw-category-target={@post.id}
                  class={[
                    "text-xs px-2 py-0.5 rounded-full border",
                    if(@post.mature_content && !(@content_warning? && @content_warning),
                      do:
                        "bg-amber-100 dark:bg-amber-800/50 text-amber-700 dark:text-amber-300 border-amber-200 dark:border-amber-700",
                      else:
                        "bg-teal-100 dark:bg-teal-800/50 text-teal-700 dark:text-teal-300 border-teal-200 dark:border-teal-700"
                    )
                  ]}
                >
                  {format_content_warning_category(@content_warning_category)}
                </span>
              <% else %>
                <%!-- For browser_decrypt? posts, show placeholder badge that the hook will fill --%>
                <span
                  :if={@post.decrypted[:browser_decrypt?] && @content_warning?}
                  data-decrypt-cw-category-target={@post.id}
                  class={[
                    "text-xs px-2 py-0.5 rounded-full border",
                    "bg-teal-100 dark:bg-teal-800/50 text-teal-700 dark:text-teal-300 border-teal-200 dark:border-teal-700"
                  ]}
                ></span>
              <% end %>
              <%= if @post.mature_content && !@content_warning_category do %>
                <span class="text-xs px-2 py-0.5 rounded-full bg-amber-100 dark:bg-amber-800/50 text-amber-700 dark:text-amber-300 border border-amber-200 dark:border-amber-700">
                  Age Restricted
                </span>
              <% end %>
            </div>
            <%= if @content_warning? && @content_warning do %>
              <p
                data-decrypt-cw-text-target={@post.id}
                class={[
                  "text-sm leading-relaxed line-clamp-2",
                  if(@post.mature_content,
                    do: "text-amber-600 dark:text-amber-400",
                    else: "text-teal-600 dark:text-teal-400"
                  )
                ]}
              >
                {@content_warning}
              </p>
            <% else %>
              <%!-- For browser_decrypt? posts with CW, show placeholder for hook --%>
              <p
                :if={@post.decrypted[:browser_decrypt?] && @content_warning?}
                data-decrypt-cw-text-target={@post.id}
                class="text-sm leading-relaxed line-clamp-2 text-teal-600 dark:text-teal-400"
              >
              </p>
              <p
                :if={
                  !(@post.decrypted[:browser_decrypt?] && @content_warning?) && @post.mature_content
                }
                class="text-sm text-amber-600 dark:text-amber-400 leading-relaxed"
              >
                This post contains mature content.
              </p>
            <% end %>
          </div>
          <button
            type="button"
            id={"content-warning-button-#{@post.id}"}
            aria-label="Show content"
            phx-click={
              JS.hide(
                to: "#content-warning-#{@post.id}",
                transition:
                  {"ease-in duration-200", "opacity-100 translate-y-0", "opacity-0 -translate-y-4"}
              )
              |> JS.show(
                to: "#content-warning-bar-#{@post.id}",
                transition:
                  {"ease-out duration-200", "opacity-0 translate-y-4", "opacity-100 translate-y-0"}
              )
            }
            class={[
              "flex-shrink-0 inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium text-white rounded-lg shadow-lg transition-all duration-200 ease-out transform hover:scale-105 active:scale-95",
              if(@post.mature_content && !(@content_warning? && @content_warning),
                do:
                  "bg-gradient-to-r from-amber-500 to-orange-500 hover:from-amber-600 hover:to-orange-600 dark:from-amber-600 dark:to-orange-600 dark:hover:from-amber-500 dark:hover:to-orange-500 shadow-amber-500/25 dark:shadow-amber-900/40",
                else:
                  "bg-gradient-to-r from-teal-500 to-cyan-500 hover:from-teal-600 hover:to-cyan-600 dark:from-teal-600 dark:to-cyan-600 dark:hover:from-teal-500 dark:hover:to-cyan-500 shadow-teal-500/25 dark:shadow-teal-900/40"
              )
            ]}
          >
            <.phx_icon name="hero-eye" class="h-4 w-4" />
            <span class="hidden sm:inline">Show</span>
          </button>
        </div>
      </div>
    </div>
    """
  end

  @doc false
  attr :post, :map, required: true
  attr :content_warning?, :boolean, default: false
  attr :content_warning, :any, default: nil

  def liquid_post_content_warning_bar(assigns) do
    ~H"""
    <%!-- Content Warning Bar (shown after reveal - click to hide content again) --%>
    <button
      :if={(@content_warning? && @content_warning) || @post.mature_content}
      type="button"
      id={"content-warning-bar-#{@post.id}"}
      phx-click={
        JS.hide(
          to: "#content-warning-bar-#{@post.id}",
          transition:
            {"ease-in duration-150", "opacity-100 translate-y-0", "opacity-0 -translate-y-4"}
        )
        |> JS.show(
          to: "#content-warning-#{@post.id}",
          transition:
            {"ease-out duration-200", "opacity-0 translate-y-4", "opacity-100 translate-y-0"}
        )
      }
      class={[
        "content-warning-bar hidden absolute left-4 right-4 top-0 h-1 rounded-b-lg opacity-70 hover:opacity-100 hover:h-1.5 transition-all duration-200 cursor-pointer group/cw z-30",
        if(@post.mature_content && !(@content_warning? && @content_warning),
          do:
            "bg-gradient-to-r from-amber-400 via-orange-400 to-amber-400 dark:from-amber-500 dark:via-orange-500 dark:to-amber-500",
          else:
            "bg-gradient-to-r from-teal-400 via-cyan-400 to-teal-400 dark:from-teal-500 dark:via-cyan-500 dark:to-teal-500"
        )
      ]}
      aria-label="Hide content"
    >
      <span class={[
        "absolute left-1/2 -translate-x-1/2 top-3 opacity-60 group-hover/cw:opacity-100 transition-opacity duration-200 whitespace-nowrap text-xs font-medium bg-white/90 dark:bg-slate-800/90 px-2 py-1 rounded-md shadow-sm border",
        if(@post.mature_content && !(@content_warning? && @content_warning),
          do: "text-amber-600 dark:text-amber-400 border-amber-200/50 dark:border-amber-700/50",
          else: "text-teal-600 dark:text-teal-400 border-teal-200/50 dark:border-teal-700/50"
        )
      ]}>
        Hide content
      </span>
    </button>
    """
  end

  @doc false
  attr :post, :map, required: true
  attr :current_user_id, :string, required: true
  attr :user_name, :string, required: true
  attr :user_handle, :string, required: true
  attr :user_avatar, :string, default: nil
  attr :encrypted_avatar_data, :map, default: nil
  attr :encrypted_author_name_data, :map, default: nil
  attr :user_status, :string, default: nil
  attr :user_status_message, :string, default: nil
  attr :encrypted_status_data, :map, default: nil
  attr :show_post_author_status, :boolean, default: true
  attr :author_profile_slug, :string, default: nil
  attr :author_profile_visibility, :atom, default: nil
  attr :timestamp, :string, required: true
  attr :verified, :boolean, default: false

  def liquid_post_header(assigns) do
    ~H"""
    <%!-- User header --%>
    <div class="flex items-start gap-4 mb-4">
      <%!-- Enhanced liquid metal avatar - conditionally linked to author profile --%>
      <.link
        :if={
          MossletWeb.ReplyComponents.show_author_profile?(
            @author_profile_slug,
            @author_profile_visibility
          )
        }
        navigate={~p"/app/profile/#{@author_profile_slug}"}
        class="flex-shrink-0"
      >
        <.liquid_avatar
          src={@user_avatar}
          encrypted_avatar_data={@encrypted_avatar_data}
          name={@user_name}
          size="md"
          verified={@verified}
          clickable={true}
          status={@user_status}
          status_message={@user_status_message}
          encrypted_status_data={@encrypted_status_data}
          show_status={@show_post_author_status}
          user_id={@post.user_id}
          id={"avatar-#{@post.id}"}
        />
      </.link>
      <.liquid_avatar
        :if={
          !MossletWeb.ReplyComponents.show_author_profile?(
            @author_profile_slug,
            @author_profile_visibility
          )
        }
        src={@user_avatar}
        encrypted_avatar_data={@encrypted_avatar_data}
        name={@user_name}
        size="md"
        verified={@verified}
        clickable={true}
        status={@user_status}
        status_message={@user_status_message}
        encrypted_status_data={@encrypted_status_data}
        show_status={@show_post_author_status}
        user_id={@post.user_id}
        id={"avatar-noprofile-#{@post.id}"}
      />

      <%!-- User info --%>
      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-2 mb-1">
          <.link
            :if={
              MossletWeb.ReplyComponents.show_author_profile?(
                @author_profile_slug,
                @author_profile_visibility
              )
            }
            navigate={~p"/app/profile/#{@author_profile_slug}"}
            class="text-base font-semibold text-slate-900 dark:text-slate-100 truncate hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors"
            data-decrypt-author-name-target={@post.id}
          >
            {@user_name}
          </.link>
          <span
            :if={
              !MossletWeb.ReplyComponents.show_author_profile?(
                @author_profile_slug,
                @author_profile_visibility
              )
            }
            class="text-base font-semibold text-slate-900 dark:text-slate-100 truncate"
            data-decrypt-author-name-target={@post.id}
          >
            {@user_name}
          </span>
          <.phx_icon
            :if={@verified}
            name="hero-check-badge"
            class="h-5 w-5 text-emerald-500 flex-shrink-0"
          />
          <%!-- Interaction controls indicators --%>
          <div class="flex items-center gap-1 ml-2">
            <%!-- Ephemeral indicator with countdown --%>
            <.phx_icon
              :if={@post.is_ephemeral}
              id={"ephemeral-indicator-#{@post.id}"}
              name="hero-clock"
              class="h-3 w-3 text-amber-500 dark:text-amber-400"
              phx_hook="TippyHook"
              data_tippy_content={
                if @post.expires_at do
                  expires_in = MossletWeb.Helpers.get_expiration_time_remaining(@post)

                  if expires_in do
                    "Ephemeral post - expires in #{expires_in}"
                  else
                    "Ephemeral post - expired"
                  end
                else
                  "Ephemeral post - will auto-delete"
                end
              }
            />

            <%!-- Mature content indicator --%>
            <.phx_icon
              :if={@post.mature_content}
              id={"mature-content-indicator-#{@post.id}"}
              name="hero-exclamation-triangle"
              class="h-3 w-3 text-orange-500 dark:text-orange-400"
              phx_hook="TippyHook"
              data_tippy_content="Mature content (18+)"
            />

            <%!-- No replies indicator --%>
            <.phx_icon
              :if={!@post.allow_replies}
              id={"allow-replies-indicator-#{@post.id}"}
              name="hero-chat-bubble-oval-left-ellipsis"
              class="h-3 w-3 text-slate-400 dark:text-slate-500 line-through"
              phx_hook="TippyHook"
              data_tippy_content="Replies disabled"
            />

            <%!-- No shares indicator --%>
            <.phx_icon
              :if={!@post.allow_shares}
              id={"allow-shares-indicator-#{@post.id}"}
              name="hero-arrow-path"
              class="h-3 w-3 text-slate-400 dark:text-slate-500 line-through"
              phx_hook="TippyHook"
              data_tippy_content="Sharing disabled"
            />

            <%!-- No bookmarks indicator --%>
            <.phx_icon
              :if={!@post.allow_bookmarks}
              id={"allow-bookmarks-indicator-#{@post.id}"}
              name="hero-bookmark"
              class="h-3 w-3 text-slate-400 dark:text-slate-500 line-through"
              phx_hook="TippyHook"
              data_tippy_content="Bookmarking disabled"
            />

            <%!-- Connection required for replies indicator --%>
            <.phx_icon
              :if={@post.require_follow_to_reply && @post.visibility == :public}
              id={"connection-required-reply-indicator-#{@post.id}"}
              name="hero-shield-check"
              class="h-3 w-3 text-emerald-500 dark:text-emerald-400"
              phx_hook="TippyHook"
              data_tippy_content="Connection required to reply"
            />
          </div>
        </div>
        <div class="flex items-center gap-2 text-sm text-slate-500 dark:text-slate-400">
          <span class="truncate" data-decrypt-handle-target={@post.id}>
            {if(@post.decrypted[:browser_decrypt?], do: "@...", else: @user_handle)}
          </span>
          <span class="text-slate-400 dark:text-slate-500">•</span>
          <time class="flex-shrink-0">{@timestamp}</time>
          <.bluesky_badge
            :if={
              @post.external_uri && @post.source == :mosslet &&
                @post.bluesky_link_verified != false
            }
            id={"bluesky-badge-#{@post.id}"}
            external_uri={@post.external_uri}
            type={:synced}
          />
          <.bluesky_badge
            :if={@post.source == :bluesky && @post.external_uri}
            id={"bluesky-import-badge-#{@post.id}"}
            external_uri={@post.external_uri}
            type={:imported}
          />
        </div>
      </div>

      <%!-- Post menu with liquid dropdown - show for both owned and other posts --%>
      <.liquid_dropdown
        :if={@current_user_id == @post.user_id or @current_user_id != @post.user_id}
        id={"post-menu-#{@post.id}"}
        trigger_class="p-2 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100/50 dark:hover:bg-slate-700/50 transition-all duration-200 ease-out"
        placement="bottom-end"
      >
        <:trigger>
          <.phx_icon name="hero-ellipsis-horizontal" class="h-5 w-5" />
        </:trigger>

        <%!-- Own post actions --%>
        <:item
          :if={@current_user_id == @post.user_id}
          phx_click="delete_post"
          phx_value_id={@post.id}
          data_confirm="Are you sure you want to delete this post?"
          color="red"
        >
          <.phx_icon name="hero-trash" class="h-4 w-4" /> Delete Post
        </:item>

        <%!-- Other user's post actions --%>
        <:item
          :if={@current_user_id != @post.user_id}
          phx_click="report_post"
          phx_value_id={@post.id}
          color="amber"
        >
          <.phx_icon name="hero-flag" class="h-4 w-4" /> Report Post
        </:item>

        <:item
          :if={@current_user_id != @post.user_id}
          phx_click="block_user"
          phx_value_id={@post.user_id}
          phx_value_user_name={@user_name}
          phx_value_item_id={@post.id}
          color="red"
        >
          <.phx_icon name="hero-no-symbol" class="h-4 w-4" /> Block Author
        </:item>

        <:item
          :if={@current_user_id != @post.user_id && is_shared_recipient?(@post, @current_user_id)}
          phx_click="remove_self_from_post"
          phx_value_post_id={@post.id}
          data_confirm="Are you sure you want to remove yourself from this post? You will no longer be able to see it."
          color="slate"
        >
          <.phx_icon name="hero-x-circle" class="h-4 w-4" /> Remove Post
        </:item>
      </.liquid_dropdown>
    </div>
    """
  end

  @doc false
  attr :post, :map, required: true
  attr :content, :string, required: true
  attr :current_user_id, :string, required: true
  attr :encrypted_author_name_data, :map, default: nil

  def liquid_post_body(assigns) do
    ~H"""
    <%!-- Collapsible text content wrapper --%>
    <div class="relative">
      <div
        data-post-content
        class="max-h-40 overflow-hidden transition-[max-height] duration-300 ease-out"
      >
        <%= if @post.decrypted[:browser_decrypt?] do %>
          <%!-- Non-public post: browser-side decryption via DecryptPost hook --%>
          <div
            id={"decrypt-post-#{@post.id}"}
            phx-hook="DecryptPost"
            phx-update="ignore"
            data-post-id={@post.id}
            data-current-user-id={@current_user_id}
            data-sealed-post-key={@post.decrypted[:sealed_post_key]}
            data-encrypted-body={@post.decrypted[:encrypted_body]}
            data-encrypted-username={@post.decrypted[:encrypted_username]}
            data-encrypted-content-warning={@post.decrypted[:encrypted_content_warning]}
            data-encrypted-content-warning-category={
              @post.decrypted[:encrypted_content_warning_category]
            }
            data-encrypted-url-preview={
              if(@post.decrypted[:encrypted_url_preview],
                do: Jason.encode!(@post.decrypted[:encrypted_url_preview])
              )
            }
            data-encrypted-favs-list={
              if(@post.decrypted[:encrypted_favs_list],
                do: Jason.encode!(@post.decrypted[:encrypted_favs_list])
              )
            }
            data-encrypted-reposts-list={
              if(@post.decrypted[:encrypted_reposts_list],
                do: Jason.encode!(@post.decrypted[:encrypted_reposts_list])
              )
            }
            data-encrypted-share-note={@post.decrypted[:encrypted_share_note]}
            data-encrypted-image-alt-texts={
              if(@post.decrypted[:encrypted_image_alt_texts],
                do: Jason.encode!(@post.decrypted[:encrypted_image_alt_texts])
              )
            }
            data-post-user-id={@post.user_id}
            data-allow-shares={to_string(@post.allow_shares)}
            data-is-ephemeral={to_string(@post.is_ephemeral || false)}
            data-sealed-uconn-key={
              @encrypted_author_name_data && @encrypted_author_name_data[:sealed_uconn_key]
            }
            data-encrypted-author-name={
              @encrypted_author_name_data && @encrypted_author_name_data[:encrypted_name]
            }
            data-encrypted-author-username={
              @encrypted_author_name_data && @encrypted_author_name_data[:encrypted_username]
            }
            data-author-show-name={
              @encrypted_author_name_data && to_string(@encrypted_author_name_data[:show_name])
            }
          >
            <div
              data-decrypt-target
              class="prose prose-slate dark:prose-invert prose-base prose-p:leading-relaxed prose-p:my-2 prose-headings:mt-4 prose-headings:mb-2 prose-ul:my-2 prose-ol:my-2 prose-li:my-1 prose-pre:my-3 prose-code:text-emerald-600 dark:prose-code:text-emerald-400 prose-a:text-emerald-600 dark:prose-a:text-emerald-400 prose-a:no-underline hover:prose-a:underline [&_pre_code]:text-inherit [&_pre_*]:text-inherit"
            >
              <%!-- Loading skeleton shown until JS decrypts --%>
              <div class="animate-pulse space-y-2">
                <div class="h-4 bg-slate-200 dark:bg-slate-700 rounded w-3/4"></div>
                <div class="h-4 bg-slate-200 dark:bg-slate-700 rounded w-1/2"></div>
              </div>
            </div>
          </div>
        <% else %>
          <%!-- Public post: server-decrypted content rendered directly --%>
          <p
            :if={contains_html?(@content)}
            class="text-slate-900 dark:text-slate-100 leading-loose whitespace-pre-wrap text-base"
          >
            {html_block(@content)}
          </p>
          <div
            :if={!contains_html?(@content)}
            class="prose prose-slate dark:prose-invert prose-base prose-p:leading-relaxed prose-p:my-2 prose-headings:mt-4 prose-headings:mb-2 prose-ul:my-2 prose-ol:my-2 prose-li:my-1 prose-pre:my-3 prose-code:text-emerald-600 dark:prose-code:text-emerald-400 prose-a:text-emerald-600 dark:prose-a:text-emerald-400 prose-a:no-underline hover:prose-a:underline [&_pre_code]:text-inherit [&_pre_*]:text-inherit"
          >
            {format_decrypted_content(@content)}
          </div>
        <% end %>
      </div>

      <%!-- Gradient fade overlay --%>
      <div
        data-post-gradient
        class="hidden absolute bottom-0 left-0 right-0 h-12 bg-gradient-to-t from-white/95 via-white/80 to-transparent dark:from-slate-800/95 dark:via-slate-800/80 pointer-events-none"
      >
      </div>
    </div>

    <%!-- Show more/less toggle button --%>
    <button
      type="button"
      data-post-toggle
      class="mt-2 items-center gap-1 text-sm font-medium text-teal-600 dark:text-teal-400 hover:text-teal-700 dark:hover:text-teal-300 transition-colors duration-200"
      style="display: none;"
    >
      <span data-expand-text class="flex items-center gap-1">
        <.phx_icon name="hero-chevron-down-mini" class="h-4 w-4" /> Show more
      </span>
      <span data-collapse-text class="hidden flex items-center gap-1">
        <.phx_icon name="hero-chevron-up-mini" class="h-4 w-4" /> Show less
      </span>
    </button>
    """
  end

  @doc false
  attr :post, :map, required: true
  attr :current_scope, :map, default: nil
  attr :decrypted_url_preview, :any, default: nil

  def liquid_post_media(assigns) do
    ~H"""
    <%!-- Images with enhanced encrypted display system --%>
    <div :if={@post && photos?(@post.image_urls)} class="mt-4">
      <.liquid_post_photo_gallery post={@post} current_scope={@current_scope} class="" />
    </div>

    <%!-- URL Preview Card (if available) --%>
    <div :if={@decrypted_url_preview} class="mt-4">
      <a
        href={@decrypted_url_preview["url"]}
        target="_blank"
        rel="noopener noreferrer"
        class="flex gap-3 p-2 rounded-xl border border-slate-200 dark:border-slate-700 bg-white/95 dark:bg-slate-800/95 hover:border-emerald-400 dark:hover:border-emerald-500 transition-all duration-200 group"
      >
        <div
          :if={@decrypted_url_preview["image"] && @decrypted_url_preview["image"] != ""}
          class="w-20 h-14 shrink-0 overflow-hidden rounded-lg"
          phx-hook="URLPreviewHook"
          id={"url-preview-#{@post.id}"}
          data-post-id={@post.id}
          data-image-hash={@decrypted_url_preview["image_hash"]}
          data-url-preview-fetched-at={@post.url_preview_fetched_at}
          data-presigned-url={@decrypted_url_preview["image"]}
        >
          <img
            alt={@decrypted_url_preview["title"] || "Preview image"}
            class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
          />
        </div>

        <div class="flex-1 min-w-0 py-0.5">
          <div class="flex items-center gap-1.5 mb-0.5">
            <.phx_icon name="hero-link" class="h-3 w-3 text-slate-400" />
            <span class="text-xs text-slate-500 dark:text-slate-400 truncate">
              {@decrypted_url_preview["site_name"] || "External Link"}
            </span>
          </div>

          <p
            :if={@decrypted_url_preview["title"]}
            class="font-medium text-sm text-slate-900 dark:text-slate-100 line-clamp-1 group-hover:text-emerald-600 dark:group-hover:text-emerald-400 transition-colors"
          >
            {@decrypted_url_preview["title"]}
          </p>

          <p
            :if={@decrypted_url_preview["description"]}
            class="text-xs text-slate-600 dark:text-slate-400 line-clamp-2 mt-0.5"
          >
            {@decrypted_url_preview["description"]}
          </p>
        </div>
      </a>
    </div>
    <%!-- URL Preview placeholder for ZK browser-decrypted posts --%>
    <div
      :if={!@decrypted_url_preview && @post.decrypted[:encrypted_url_preview]}
      data-decrypt-url-preview-target={@post.id}
      class="mt-4 hidden"
    >
    </div>
    """
  end

  @doc false
  attr :post, :map, required: true
  attr :post_id, :string, default: nil
  attr :content, :string, required: true
  attr :user_handle, :string, required: true
  attr :current_scope, :map, default: nil
  attr :current_user_id, :string, required: true
  attr :stats, :map, default: %{}
  attr :liked, :boolean, default: false
  attr :bookmarked, :boolean, default: false
  attr :can_repost, :boolean, default: false
  attr :can_reply?, :boolean, default: false
  attr :can_bookmark?, :boolean, default: false
  attr :unread?, :boolean, default: false
  attr :unread_replies_count, :integer, default: 0
  attr :calm_notifications, :boolean, default: false
  attr :bookmark_notes, :any, default: nil
  attr :encrypted_bookmark_notes, :any, default: nil

  def liquid_post_actions(assigns) do
    ~H"""
    <%!-- Bookmark notes display — shown when this post has notes attached --%>
    <%= if @bookmark_notes do %>
      <%!-- Public post: server-decrypted bookmark notes --%>
      <div class="mx-1 mb-2">
        <div class="px-3 py-2 rounded-xl bg-amber-50/60 dark:bg-amber-900/15 border border-amber-200/40 dark:border-amber-700/30">
          <div class="flex items-start gap-2">
            <.phx_icon
              name="hero-bookmark-solid"
              class="h-3.5 w-3.5 mt-0.5 text-amber-500 dark:text-amber-400 shrink-0"
            />
            <p class="text-xs text-amber-800 dark:text-amber-200 leading-relaxed break-words whitespace-pre-wrap">
              {@bookmark_notes}
            </p>
          </div>
        </div>
      </div>
    <% end %>
    <%= if @encrypted_bookmark_notes do %>
      <%!-- Non-public post: browser-side ZK decryption of bookmark notes --%>
      <div
        id={"decrypt-bookmark-notes-#{@post.id}"}
        phx-hook="DecryptBookmarkNote"
        phx-update="ignore"
        data-post-id={@post.id}
        data-encrypted-notes={@encrypted_bookmark_notes}
        class="mx-1 mb-2 hidden"
      >
        <div class="px-3 py-2 rounded-xl bg-amber-50/60 dark:bg-amber-900/15 border border-amber-200/40 dark:border-amber-700/30">
          <div class="flex items-start gap-2">
            <.phx_icon
              name="hero-bookmark-solid"
              class="h-3.5 w-3.5 mt-0.5 text-amber-500 dark:text-amber-400 shrink-0"
            />
            <p
              data-decrypt-notes-target
              class="text-xs text-amber-800 dark:text-amber-200 leading-relaxed break-words whitespace-pre-wrap"
            >
            </p>
          </div>
        </div>
      </div>
    <% end %>

    <div class="flex items-center justify-between pt-2.5 border-t border-slate-200/40 dark:border-slate-700/40">
      <div class="flex items-center gap-0.5">
        <button
          id={
            if @unread?,
              do: "mark-read-button-#{@post_id}",
              else: "mark-as-unread-button-#{@post_id}"
          }
          class={[
            "p-1.5 sm:p-2 rounded-lg transition-all duration-200 ease-out group/read active:scale-95 focus:outline-none focus:ring-2 focus:ring-teal-500/50 focus:ring-offset-1 sm:focus:ring-offset-2",
            "phx-click-loading:opacity-60 phx-click-loading:cursor-wait phx-click-loading:pointer-events-none",
            if(@unread?,
              do: "text-teal-600 dark:text-cyan-400 bg-teal-50/50 dark:bg-teal-900/20",
              else:
                "text-slate-400 hover:text-teal-600 dark:hover:text-cyan-400 hover:bg-teal-50/50 dark:hover:bg-teal-900/20"
            )
          ]}
          phx-hook="TippyHook"
          data-tippy-content={if @unread?, do: "Mark post as read.", else: "Mark post as unread."}
          phx-click="toggle-read-status"
          phx-value-id={@post_id}
        >
          <.phx_icon
            name={if @unread?, do: "hero-eye-solid", else: "hero-eye-slash"}
            class="h-4 w-4 transition-transform duration-200 group-hover/read:scale-110 phx-click-loading:hidden"
          />
          <svg
            class="hidden phx-click-loading:block h-4 w-4 animate-spin text-teal-500"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
          >
            <circle
              class="opacity-25"
              cx="12"
              cy="12"
              r="10"
              stroke="currentColor"
              stroke-width="4"
            >
            </circle>
            <path
              class="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
            >
            </path>
          </svg>
          <span class="sr-only">{if @unread?, do: "Mark as read", else: "Mark as unread"}</span>
        </button>

        <.liquid_timeline_action
          :if={@can_reply?}
          icon="hero-chat-bubble-oval-left"
          active_icon="hero-chat-bubble-oval-left-solid"
          count={Map.get(@stats, :replies, 0)}
          notification_count={
            if @calm_notifications && @post.user_id == @current_scope.user.id,
              do: @unread_replies_count,
              else: 0
          }
          label="Reply"
          color="emerald"
          icon_id={"reply-icon-#{@post_id}"}
          id={"reply-button-#{@post_id}"}
          phx-hook="TippyHook"
          data-tippy-content="Toggle reply composer"
          phx-click={
            MossletWeb.ReplyComponents.toggle_reply_section(
              @post_id,
              (@calm_notifications && @post.user_id == @current_scope.user.id) and
                @unread_replies_count > 0
            )
          }
        />
        <.liquid_timeline_action
          :if={@can_repost}
          icon="hero-paper-airplane"
          id={"share-button-#{@post.id}"}
          icon_id={"share-icon-#{@post.id}"}
          count={Map.get(@stats, :shares, 0)}
          soft_text={if Map.get(@stats, :shares, 0) > 0, do: "People are sharing"}
          label="Share"
          color="emerald"
          repost_post_id={@post.id}
          phx-hook="TippyHook"
          data-tippy-content="Share with someone"
          phx-click="open_share_modal"
          phx-value-id={@post_id}
          phx-value-body={@content}
          phx-value-username={@user_handle}
        />
        <.liquid_timeline_action
          :if={!@can_repost && @post.user_id == @current_scope.user.id && @post.allow_shares}
          icon="hero-paper-airplane"
          id={"share-button-disabled-#{@post.id}"}
          icon_id={"share-icon-disabled-#{@post.id}"}
          count={Map.get(@stats, :shares, 0)}
          soft_text={if Map.get(@stats, :shares, 0) > 0, do: "People are sharing"}
          label="Share"
          color="emerald"
          repost_post_id={@post.id}
          phx-hook="TippyHook"
          class="cursor-not-allowed"
          data-tippy-content="You cannot share your own post"
          phx-click={nil}
          phx-value-id={nil}
          phx-value-body={nil}
          phx-value-username={nil}
        />
        <.liquid_timeline_action
          :if={!@can_repost && @post.user_id != @current_scope.user.id}
          icon="hero-paper-airplane-solid"
          id={"share-button-disabled-#{@post.id}"}
          icon_id={"share-icon-disabled-#{@post.id}"}
          count={Map.get(@stats, :shares, 0)}
          soft_text="You shared"
          label="Share"
          color="emerald"
          repost_post_id={@post.id}
          phx-hook="TippyHook"
          class="cursor-not-allowed"
          data-tippy-content="You have already shared this"
          phx-click={nil}
          phx-value-id={nil}
          phx-value-body={nil}
          phx-value-username={nil}
        />
        <.liquid_timeline_action
          id={
            if @liked,
              do: "hero-heart-solid-button-#{@post_id}",
              else: "hero-heart-button-#{@post_id}"
          }
          icon_id={
            if @liked,
              do: "hero-heart-solid-icon-#{@post_id}",
              else: "hero-heart-icon-#{@post_id}"
          }
          icon={if @liked, do: "hero-heart-solid", else: "hero-heart"}
          count={Map.get(@stats, :likes, 0)}
          soft_text={soft_like_text(Map.get(@stats, :likes, 0), @liked)}
          label={if @liked, do: "Unlike", else: "Like"}
          color="rose"
          active={@liked}
          post_id={@post_id}
          phx-hook="TippyHook"
          data-tippy-content={if @liked, do: "Remove love", else: "Show love"}
          phx-click={if @liked, do: "unfav", else: "fav"}
          phx-value-id={@post_id}
        />
      </div>

      <button
        :if={@can_bookmark?}
        id={
          if @bookmarked,
            do: "hero-bookmark-solid-button-#{@post_id}",
            else: "hero-bookmark-button-#{@post_id}"
        }
        class={[
          "p-1.5 sm:p-2 rounded-lg transition-all duration-200 ease-out group/bookmark active:scale-95 focus:outline-none focus:ring-2 focus:ring-amber-500/50 focus:ring-offset-1 sm:focus:ring-offset-2",
          "phx-click-loading:opacity-60 phx-click-loading:cursor-wait phx-click-loading:pointer-events-none",
          if(@bookmarked,
            do: "text-amber-600 dark:text-amber-400 bg-amber-50/50 dark:bg-amber-900/20",
            else:
              "text-slate-400 hover:text-amber-600 dark:hover:text-amber-400 hover:bg-amber-50/50 dark:hover:bg-amber-900/20"
          )
        ]}
        phx-click={if(@bookmarked, do: "bookmark_post")}
        phx-value-id={@post_id}
        phx-hook={if(@bookmarked, do: "TippyHook", else: "BookmarkNoteHook")}
        data-tippy-content={if @bookmarked, do: "Remove bookmark", else: "Bookmark this post"}
        data-post-id={@post_id}
        data-bookmarked={to_string(@bookmarked)}
        data-is-public={to_string(@post.visibility == :public)}
      >
        <.phx_icon
          id={
            if @bookmarked,
              do: "hero-bookmark-solid-icon-#{@post_id}",
              else: "hero-bookmark-icon-#{@post_id}"
          }
          name={if @bookmarked, do: "hero-bookmark-solid", else: "hero-bookmark"}
          class="h-4 w-4 transition-transform duration-200 group-hover/bookmark:scale-110 phx-click-loading:hidden"
        />
        <svg
          class="hidden phx-click-loading:block h-4 w-4 animate-spin text-amber-500"
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
        >
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4">
          </circle>
          <path
            class="opacity-75"
            fill="currentColor"
            d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
          >
          </path>
        </svg>
        <span class="sr-only">
          {if @bookmarked, do: "Remove bookmark", else: "Bookmark this post"}
        </span>
      </button>
    </div>
    """
  end

  # Helper functions for post visibility badges
  defp visibility_badge_text(visibility) do
    case visibility do
      :private -> "Private"
      :connections -> "Connections"
      :public -> "Public"
      :specific_groups -> "Groups"
      :specific_users -> "Specific"
      _ -> "Private"
    end
  end

  defp visibility_overlay_gradient(visibility) do
    case visibility do
      :private ->
        "from-slate-400 via-slate-500 to-slate-400 dark:from-slate-500 dark:via-slate-600 dark:to-slate-500"

      :connections ->
        "from-emerald-400 via-teal-400 to-emerald-400 dark:from-emerald-500 dark:via-teal-500 dark:to-emerald-500"

      :specific_groups ->
        "from-purple-400 via-violet-400 to-purple-400 dark:from-purple-500 dark:via-violet-500 dark:to-purple-500"

      :specific_users ->
        "from-amber-400 via-yellow-400 to-amber-400 dark:from-amber-500 dark:via-yellow-500 dark:to-amber-500"

      _ ->
        "from-slate-400 via-slate-500 to-slate-400 dark:from-slate-500 dark:via-slate-600 dark:to-slate-500"
    end
  end

  defp visibility_overlay_icon_bg(visibility) do
    case visibility do
      :private ->
        "from-slate-100 to-slate-200 dark:from-slate-800/50 dark:to-slate-700/50"

      :connections ->
        "from-emerald-100 to-teal-100 dark:from-emerald-900/50 dark:to-teal-900/50"

      :specific_groups ->
        "from-purple-100 to-violet-100 dark:from-purple-900/50 dark:to-violet-900/50"

      :specific_users ->
        "from-amber-100 to-yellow-100 dark:from-amber-900/50 dark:to-yellow-900/50"

      _ ->
        "from-slate-100 to-slate-200 dark:from-slate-800/50 dark:to-slate-700/50"
    end
  end

  defp visibility_overlay_icon(visibility) do
    case visibility do
      :private -> "hero-lock-closed-solid"
      :connections -> "hero-user-group-solid"
      :specific_groups -> "hero-user-group-solid"
      :specific_users -> "hero-users-solid"
      _ -> "hero-lock-closed-solid"
    end
  end

  defp visibility_overlay_icon_color(visibility) do
    case visibility do
      :private -> "text-slate-600 dark:text-slate-400"
      :connections -> "text-emerald-600 dark:text-emerald-400"
      :specific_groups -> "text-purple-600 dark:text-purple-400"
      :specific_users -> "text-amber-600 dark:text-amber-400"
      _ -> "text-slate-600 dark:text-slate-400"
    end
  end

  defp visibility_overlay_back_button_classes(visibility) do
    case visibility do
      :private ->
        "text-slate-600 dark:text-slate-400 bg-slate-50/80 dark:bg-slate-900/30 hover:bg-slate-100 dark:hover:bg-slate-900/50 border-slate-200/50 dark:border-slate-700/50"

      :connections ->
        "text-emerald-600 dark:text-emerald-400 bg-emerald-50/80 dark:bg-emerald-900/30 hover:bg-emerald-100 dark:hover:bg-emerald-900/50 border-emerald-200/50 dark:border-emerald-700/50"

      :specific_groups ->
        "text-purple-600 dark:text-purple-400 bg-purple-50/80 dark:bg-purple-900/30 hover:bg-purple-100 dark:hover:bg-purple-900/50 border-purple-200/50 dark:border-purple-700/50"

      :specific_users ->
        "text-amber-600 dark:text-amber-400 bg-amber-50/80 dark:bg-amber-900/30 hover:bg-amber-100 dark:hover:bg-amber-900/50 border-amber-200/50 dark:border-amber-700/50"

      _ ->
        "text-slate-600 dark:text-slate-400 bg-slate-50/80 dark:bg-slate-900/30 hover:bg-slate-100 dark:hover:bg-slate-900/50 border-slate-200/50 dark:border-slate-700/50"
    end
  end

  defp visibility_add_button_classes(visibility) do
    case visibility do
      :private ->
        "text-slate-600 dark:text-slate-400 border-slate-300 dark:border-slate-600 hover:bg-slate-50 dark:hover:bg-slate-800/50"

      :connections ->
        "text-emerald-600 dark:text-emerald-400 border-emerald-300 dark:border-emerald-700 hover:bg-emerald-50 dark:hover:bg-emerald-900/20"

      :public ->
        "text-blue-600 dark:text-blue-400 border-blue-300 dark:border-blue-700 hover:bg-blue-50 dark:hover:bg-blue-900/20"

      :specific_groups ->
        "text-purple-600 dark:text-purple-400 border-purple-300 dark:border-purple-700 hover:bg-purple-50 dark:hover:bg-purple-900/20"

      :specific_users ->
        "text-amber-600 dark:text-amber-400 border-amber-300 dark:border-amber-700 hover:bg-amber-50 dark:hover:bg-amber-900/20"

      _ ->
        "text-slate-600 dark:text-slate-400 border-slate-300 dark:border-slate-600 hover:bg-slate-50 dark:hover:bg-slate-800/50"
    end
  end

  defp visibility_indicator_hover_text_classes(visibility) do
    case visibility do
      :private ->
        "text-slate-600 dark:text-slate-400 bg-white/90 dark:bg-slate-800/90 border-slate-200/50 dark:border-slate-700/50"

      :connections ->
        "text-emerald-600 dark:text-emerald-400 bg-white/90 dark:bg-slate-800/90 border-emerald-200/50 dark:border-emerald-700/50"

      :public ->
        "text-blue-600 dark:text-blue-400 bg-white/90 dark:bg-slate-800/90 border-blue-200/50 dark:border-blue-700/50"

      :specific_groups ->
        "text-purple-600 dark:text-purple-400 bg-white/90 dark:bg-slate-800/90 border-purple-200/50 dark:border-purple-700/50"

      :specific_users ->
        "text-amber-600 dark:text-amber-400 bg-white/90 dark:bg-slate-800/90 border-amber-200/50 dark:border-amber-700/50"

      _ ->
        "text-slate-600 dark:text-slate-400 bg-white/90 dark:bg-slate-800/90 border-slate-200/50 dark:border-slate-700/50"
    end
  end

  defp visibility_indicator_gradient(visibility) do
    case visibility do
      :private ->
        "from-slate-400 via-slate-500 to-slate-400 dark:from-slate-500 dark:via-slate-600 dark:to-slate-500"

      :connections ->
        "from-emerald-400 via-teal-400 to-emerald-400 dark:from-emerald-500 dark:via-teal-500 dark:to-emerald-500"

      :public ->
        "from-blue-400 via-sky-400 to-blue-400 dark:from-blue-500 dark:via-sky-500 dark:to-blue-500"

      :specific_groups ->
        "from-purple-400 via-violet-400 to-purple-400 dark:from-purple-500 dark:via-violet-500 dark:to-purple-500"

      :specific_users ->
        "from-amber-400 via-yellow-400 to-amber-400 dark:from-amber-500 dark:via-yellow-500 dark:to-amber-500"

      _ ->
        "from-slate-400 via-slate-500 to-slate-400 dark:from-slate-500 dark:via-slate-600 dark:to-slate-500"
    end
  end

  @doc """
  Timeline post images with smart layout based on count.
  """
  attr :images, :list, required: true
  attr :class, :any, default: ""

  def liquid_timeline_images(assigns) do
    assigns = assign(assigns, :image_count, length(assigns.images))

    ~H"""
    <div class={[
      "relative rounded-xl overflow-hidden",
      "border border-slate-200/60 dark:border-slate-700/60",
      @class
    ]}>
      <%!-- Single image --%>
      <img
        :if={@image_count == 1}
        src={hd(@images)}
        alt="Post image"
        class="w-full max-h-96 object-cover transition-transform duration-300 ease-out hover:scale-105"
      />

      <%!-- Two images side by side --%>
      <div :if={@image_count == 2} class="grid grid-cols-2 gap-1">
        <img
          :for={image <- @images}
          src={image}
          alt="Post image"
          class="aspect-square object-cover transition-transform duration-300 ease-out hover:scale-105"
        />
      </div>

      <%!-- Three images: 1 large, 2 small --%>
      <div :if={@image_count == 3} class="grid grid-cols-2 gap-1 h-64">
        <img
          src={Enum.at(@images, 0)}
          alt="Post image"
          class="row-span-2 w-full h-full object-cover transition-transform duration-300 ease-out hover:scale-105"
        />
        <div class="grid grid-rows-2 gap-1">
          <img
            :for={image <- Enum.slice(@images, 1, 2)}
            src={image}
            alt="Post image"
            class="w-full h-full object-cover transition-transform duration-300 ease-out hover:scale-105"
          />
        </div>
      </div>

      <%!-- Four or more images: 2x2 grid with overflow indicator --%>
      <div :if={@image_count >= 4} class="grid grid-cols-2 gap-1 h-64">
        <img
          :for={{image, index} <- Enum.with_index(Enum.slice(@images, 0, 3))}
          src={image}
          alt="Post image"
          class="aspect-square object-cover transition-transform duration-300 ease-out hover:scale-105"
        />
        <div class="relative">
          <img
            src={Enum.at(@images, 3)}
            alt="Post image"
            class="aspect-square object-cover transition-transform duration-300 ease-out hover:scale-105"
          />
          <%!-- Overlay for additional images --%>
          <div
            :if={@image_count > 4}
            class="absolute inset-0 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center transition-all duration-200 ease-out hover:bg-slate-900/40"
          >
            <span class="text-white font-semibold text-lg">
              +{@image_count - 4}
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Timeline action button (reply, share, like, bookmark) with calm interaction design.
  """
  attr :icon, :string, required: true
  attr :active_icon, :string, default: nil
  attr :count, :integer, default: 0
  attr :soft_text, :string, default: nil, doc: "If set, displays this text instead of the count"
  attr :notification_count, :integer, default: 0
  attr :label, :string, required: true
  attr :active, :boolean, default: false
  attr :color, :string, default: "slate", values: ~w(slate emerald amber rose)
  attr :class, :any, default: ""
  attr :post_id, :string, default: nil
  attr :reply_id, :string, default: nil
  attr :current_user_id, :string, default: nil
  attr :icon_id, :string, default: nil
  attr :repost_post_id, :string, default: nil

  attr :id, :string, default: nil

  attr :rest, :global,
    include:
      ~w(phx-click phx-value-id phx-value-url data-confirm data-composer-open data-expanded phx-hook data-tippy-content)

  def liquid_timeline_action(assigns) do
    assigns = assign_new(assigns, :has_active_icon, fn -> assigns[:active_icon] != nil end)

    ~H"""
    <button
      id={@id}
      class={[
        "group/action relative flex items-center gap-1.5 sm:gap-2 px-2 py-1.5 sm:px-3 sm:py-2 rounded-lg sm:rounded-xl",
        "transition-all duration-200 ease-out active:scale-95",
        "focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-1 sm:focus:ring-offset-2",
        "phx-click-loading:opacity-60 phx-click-loading:cursor-wait phx-click-loading:pointer-events-none",
        timeline_action_classes(@active, @color),
        @class
      ]}
      data-expanded="false"
      {@rest}
    >
      <div class={[
        "absolute inset-0 opacity-0 transition-all duration-300 ease-out rounded-lg sm:rounded-xl",
        "group-hover/action:opacity-100",
        "[.reply-expanded_&]:opacity-100",
        timeline_action_bg_classes(@color)
      ]}>
      </div>

      <div class="relative flex items-center gap-2">
        <%!-- Notification badge for unread replies --%>
        <span
          :if={@notification_count > 0}
          id={"notification-badge-#{@id}"}
          class={[
            "absolute -top-1.5 -right-1.5 z-10 flex items-center justify-center",
            "min-w-[18px] h-[18px] px-1 rounded-full text-[10px] font-bold",
            "bg-gradient-to-r from-emerald-500 to-teal-500 text-white",
            "shadow-sm shadow-emerald-500/30",
            "animate-pulse"
          ]}
        >
          {if @notification_count > 99, do: "99+", else: @notification_count}
        </span>
        <%!-- Default icon (shown when not expanded) --%>
        <.phx_icon
          name={@icon}
          id={@icon_id}
          class={[
            "h-3.5 w-3.5 sm:h-4 sm:w-4 transition-all duration-200 ease-out group-hover/action:scale-110",
            "phx-click-loading:hidden",
            @has_active_icon && "[.reply-expanded_&]:hidden"
          ]}
        />
        <%!-- Active/filled icon (shown when expanded, only if active_icon is provided) --%>
        <.phx_icon
          :if={@has_active_icon}
          name={@active_icon}
          id={"#{@icon_id}-active"}
          class={[
            "h-3.5 w-3.5 sm:h-4 sm:w-4 transition-all duration-200 ease-out scale-110",
            "phx-click-loading:hidden",
            "hidden [.reply-expanded_&]:block"
          ]}
        />
        <%!-- Loading spinner --%>
        <svg
          class="hidden phx-click-loading:block h-3.5 w-3.5 sm:h-4 sm:w-4 animate-spin"
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
        >
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4">
          </circle>
          <path
            class="opacity-75"
            fill="currentColor"
            d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
          >
          </path>
        </svg>

        <span
          :if={
            @soft_text || @count > 0 || (@color == "rose" && (@post_id || @reply_id)) ||
              @repost_post_id
          }
          id={if @color == "rose" && @post_id, do: "fav-text-#{@post_id}", else: nil}
          class="text-xs sm:text-sm font-medium"
          data-post-fav-count={if @color == "rose" && @post_id, do: @post_id, else: nil}
          data-reply-fav-count={if @color == "rose" && @reply_id, do: @reply_id, else: nil}
          data-post-repost-count={@repost_post_id}
        >
          {cond do
            @soft_text -> @soft_text
            @count > 0 -> @count
            true -> ""
          end}
        </span>
      </div>
      <span class="sr-only">{@label}</span>
    </button>
    """
  end

  @doc """
  Timeline compose/new post component with calm, focused design.
  """
  attr :user_name, :string, required: true
  attr :user_avatar, :string, default: nil
  attr :placeholder, :string, default: "What's on your mind?"
  attr :class, :any, default: ""

  def liquid_timeline_composer(assigns) do
    ~H"""
    <div class={[
      "relative rounded-2xl overflow-hidden transition-all duration-300 ease-out",
      "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
      "border border-slate-200/60 dark:border-slate-700/60",
      "shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20",
      "hover:shadow-xl hover:shadow-slate-900/10 dark:hover:shadow-slate-900/30",
      "focus-within:border-emerald-500/60 dark:focus-within:border-emerald-400/60",
      "focus-within:shadow-xl focus-within:shadow-emerald-500/10",
      @class
    ]}>
      <%!-- Liquid background on focus --%>
      <div class="absolute inset-0 opacity-0 transition-all duration-500 ease-out bg-gradient-to-br from-emerald-50/20 via-teal-50/10 to-cyan-50/20 dark:from-emerald-900/10 dark:via-teal-900/5 dark:to-cyan-900/10 focus-within:opacity-100">
      </div>

      <div class="relative p-6">
        <%!-- User section --%>
        <div class="flex items-start gap-4 mb-4">
          <%!-- Avatar --%>
          <div class="relative flex-shrink-0">
            <div class="relative overflow-hidden rounded-xl">
              <div class="absolute inset-0 bg-gradient-to-br from-teal-100 via-emerald-50 to-cyan-100 dark:from-teal-900/30 dark:via-emerald-900/20 dark:to-cyan-900/30">
              </div>
              <img
                src={@user_avatar || "/images/default-avatar.svg"}
                alt={"#{@user_name} avatar"}
                class="relative h-12 w-12 object-cover"
              />
            </div>
          </div>

          <%!-- Compose area --%>
          <div class="flex-1 min-w-0">
            <textarea
              placeholder={@placeholder}
              rows="3"
              class="w-full resize-none border-0 bg-transparent text-slate-900 dark:text-slate-100 placeholder:text-slate-500 dark:placeholder:text-slate-400 text-lg leading-relaxed focus:outline-none focus:ring-0"
            ></textarea>
          </div>
        </div>

        <%!-- Actions row --%>
        <div class="flex items-center justify-between pt-4 border-t border-slate-200/50 dark:border-slate-700/50">
          <%!-- Media actions --%>
          <div class="flex items-center gap-2">
            <button class="p-2 rounded-lg text-slate-500 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50/50 dark:hover:bg-emerald-900/20 transition-all duration-200 ease-out">
              <.phx_icon name="hero-photo" class="h-5 w-5" />
            </button>
            <button class="p-2 rounded-lg text-slate-500 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50/50 dark:hover:bg-emerald-900/20 transition-all duration-200 ease-out">
              <.phx_icon name="hero-face-smile" class="h-5 w-5" />
            </button>
          </div>

          <%!-- Privacy indicator and post button --%>
          <div class="flex items-center gap-3">
            <%!-- Privacy indicator --%>
            <div class="flex items-center gap-2 text-sm text-slate-500 dark:text-slate-400">
              <.phx_icon name="hero-lock-closed" class="h-4 w-4" />
              <span>Private</span>
            </div>

            <%!-- Post button --%>
            <.liquid_button size="sm" disabled>
              Share
            </.liquid_button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Timeline status indicator showing online/calm status.
  """
  attr :status, :string, default: "calm", values: ~w(online calm away active busy offline)
  attr :message, :string, default: nil

  attr :show_status, :boolean,
    default: true,
    doc: "Whether to show the status indicator (based on privacy settings)"

  attr :class, :any, default: ""

  def liquid_timeline_status(assigns) do
    ~H"""
    <div
      :if={@show_status}
      class={[
        "inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-sm",
        "border transition-all duration-200 ease-out",
        timeline_status_classes(@status),
        @class
      ]}
    >
      <%!-- Status indicator --%>
      <div class={[
        "relative flex-shrink-0 rounded-full transition-all duration-300 ease-out",
        timeline_status_dot_size(@status),
        timeline_status_dot_classes(@status)
      ]}>
        <%!-- Pulse animation for certain statuses --%>
        <div
          :if={@status in ["online", "calm", "active", "busy", "away"]}
          class={[
            "absolute inset-0 rounded-full animate-ping opacity-75",
            timeline_status_ping_classes(@status)
          ]}
        >
        </div>
      </div>

      <span class="font-medium">
        {@message || get_status_fallback_message(String.to_existing_atom(@status))}
      </span>
    </div>

    <div
      :if={!@show_status}
      class={[
        "inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-sm",
        "border transition-all duration-200 ease-out",
        timeline_status_classes("offline"),
        @class
      ]}
    >
      <%!-- Status indicator --%>
      <div class={[
        "relative flex-shrink-0 rounded-full transition-all duration-300 ease-out",
        timeline_status_dot_size("offline"),
        timeline_status_dot_classes("offline")
      ]}>
      </div>

      <span class="font-medium">
        {"Not sharing status"}
      </span>
    </div>
    """
  end

  @doc """
  Timeline filter/tab component for switching views with enhanced desktop and mobile design.
  Improved colors for semantic meaning and visual hierarchy while remaining calm.
  """
  attr :tabs, :list, required: true
  attr :active_tab, :string, required: true
  attr :loading_tab, :string, default: nil
  attr :class, :any, default: ""

  def liquid_timeline_tabs(assigns) do
    ~H"""
    <div class={[
      "relative flex-1 min-w-0",
      @class
    ]}>
      <div
        id="timeline-tabs-scroll"
        phx-hook="ScrollableTabs"
        class="overflow-x-auto scrollbar-hide xs:overflow-visible"
      >
        <div class="flex items-center gap-1 xs:justify-between">
          <button
            :for={tab <- @tabs}
            data-active={to_string(tab.key == @active_tab)}
            disabled={@loading_tab != nil}
            class={[
              "relative flex items-center justify-center gap-1 sm:gap-1.5 transition-all duration-200 ease-out",
              "focus:outline-none focus:ring-2 focus:ring-emerald-500/50",
              "flex-shrink-0 xs:flex-1",
              "px-3 py-1.5 sm:py-2 text-xs sm:text-sm font-medium rounded-lg",
              timeline_tab_classes(tab.key, tab.key == @active_tab),
              @loading_tab != nil && "cursor-wait"
            ]}
            phx-click="switch_tab"
            phx-value-tab={tab.key}
          >
            <%!-- Active tab background --%>
            <div
              :if={tab.key == @active_tab}
              class={[
                "absolute inset-0 rounded-lg transition-all duration-300 ease-out",
                timeline_tab_active_bg(tab.key)
              ]}
            >
            </div>

            <%!-- Loading spinner for the tab being loaded --%>
            <div
              :if={tab.key == @loading_tab}
              class="h-4 w-4 flex-shrink-0 relative z-10 animate-spin"
            >
              <svg class="h-4 w-4" viewBox="0 0 24 24" fill="none">
                <circle
                  class="opacity-25"
                  cx="12"
                  cy="12"
                  r="10"
                  stroke="currentColor"
                  stroke-width="3"
                />
                <path
                  class="opacity-75"
                  fill="currentColor"
                  d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                />
              </svg>
            </div>

            <%!-- Tab icon (hide when loading this tab) --%>
            <.phx_icon
              :if={tab_icon(tab.key) && tab.key != @loading_tab}
              name={tab_icon(tab.key)}
              class="h-4 w-4 flex-shrink-0 relative z-10"
            />

            <%!-- Tab label --%>
            <span class="relative z-10">
              {tab.label}
            </span>

            <%!-- Unread badge (inline flow, never clipped) --%>
            <span
              :if={tab[:unread] && tab.unread > 0 && tab.key != @loading_tab}
              class={[
                "flex-shrink-0 relative z-10",
                "flex items-center justify-center",
                "min-w-[1.25rem] h-5 px-1.5 text-[10px] font-bold rounded-full",
                "bg-gradient-to-r from-teal-400 to-cyan-400 text-white",
                "shadow-sm animate-pulse"
              ]}
            >
              {tab.unread}
            </span>
          </button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Timeline header - beautiful banner with user customization support.

  Shows the user's chosen banner image if they have a profile set up,
  otherwise displays an elegant default gradient design.
  """
  attr :class, :any, default: ""
  attr :id, :string, default: nil
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"
  attr :custom_banner_src, :any, default: nil, doc: "async result for custom banner data URL"
  attr :banner_loading, :boolean, default: false, doc: "whether custom banner is loading"

  attr :encrypted_banner_data, :map,
    default: nil,
    doc: "ZK mode: encrypted banner data for browser-side decryption via DecryptAvatar hook"

  def liquid_timeline_header(assigns) do
    assigns = assign_scope_fields(assigns)
    banner_image = get_user_banner_image(assigns[:current_scope].user)
    assigns = assign(assigns, :banner_image, banner_image)

    ~H"""
    <div
      id={@id}
      class={[
        "relative overflow-hidden rounded-2xl",
        @class
      ]}
    >
      <%= cond do %>
        <% @banner_loading -> %>
          <div class="relative h-32 sm:h-40 lg:h-48 bg-gradient-to-br from-slate-100 to-slate-50 dark:from-slate-800 dark:to-slate-700">
            <div class="absolute inset-0 flex items-center justify-center">
              <div class="w-10 h-10 border-3 border-purple-400 border-t-transparent rounded-full animate-spin">
              </div>
            </div>
          </div>
        <% @encrypted_banner_data -> %>
          <div class="relative h-32 sm:h-40 lg:h-48">
            <img
              id={"#{@id}-banner-img"}
              phx-hook="DecryptAvatar"
              data-encrypted-blob={@encrypted_banner_data[:encrypted_blob_b64]}
              data-sealed-key={@encrypted_banner_data[:sealed_key]}
              alt=""
              class="absolute inset-0 w-full h-full object-cover"
            />
            <div class="absolute inset-0 bg-gradient-to-t from-black/60 via-black/20 to-transparent" />
            <div class="absolute inset-0 bg-gradient-to-r from-emerald-500/10 via-transparent to-teal-500/10" />
            <div class="absolute bottom-0 left-0 right-0 p-4 sm:p-6">
              <div class="flex items-center gap-3">
                <div class="flex items-center justify-center w-10 h-10 sm:w-12 sm:h-12 rounded-xl bg-white/20 backdrop-blur-md shadow-lg border border-white/30">
                  <.phx_icon
                    name="hero-book-open"
                    class="w-5 h-5 sm:w-6 sm:h-6 text-white drop-shadow-sm"
                  />
                </div>
                <div>
                  <h1 class="text-lg sm:text-xl font-semibold text-white drop-shadow-sm">
                    Timeline
                  </h1>
                  <p class="text-sm text-white/80 drop-shadow-sm">
                    Your private feed
                  </p>
                </div>
              </div>
            </div>
          </div>
        <% @custom_banner_src -> %>
          <div class="relative h-32 sm:h-40 lg:h-48">
            <img
              src={@custom_banner_src}
              alt=""
              class="absolute inset-0 w-full h-full object-cover"
            />
            <div class="absolute inset-0 bg-gradient-to-t from-black/60 via-black/20 to-transparent" />
            <div class="absolute inset-0 bg-gradient-to-r from-emerald-500/10 via-transparent to-teal-500/10" />
            <div class="absolute bottom-0 left-0 right-0 p-4 sm:p-6">
              <div class="flex items-center gap-3">
                <div class="flex items-center justify-center w-10 h-10 sm:w-12 sm:h-12 rounded-xl bg-white/20 backdrop-blur-md shadow-lg border border-white/30">
                  <.phx_icon
                    name="hero-book-open"
                    class="w-5 h-5 sm:w-6 sm:h-6 text-white drop-shadow-sm"
                  />
                </div>
                <div>
                  <h1 class="text-lg sm:text-xl font-semibold text-white drop-shadow-sm">
                    Timeline
                  </h1>
                  <p class="text-sm text-white/80 drop-shadow-sm">
                    Your private feed
                  </p>
                </div>
              </div>
            </div>
          </div>
        <% @banner_image -> %>
          <div class="relative h-32 sm:h-40 lg:h-48">
            <img
              src={~p"/images/profile/#{@banner_image}"}
              alt=""
              class="absolute inset-0 w-full h-full object-cover"
            />
            <div class="absolute inset-0 bg-gradient-to-t from-black/60 via-black/20 to-transparent" />
            <div class="absolute inset-0 bg-gradient-to-r from-emerald-500/10 via-transparent to-teal-500/10" />
            <div class="absolute bottom-0 left-0 right-0 p-4 sm:p-6">
              <div class="flex items-center gap-3">
                <div class="flex items-center justify-center w-10 h-10 sm:w-12 sm:h-12 rounded-xl bg-white/20 backdrop-blur-md shadow-lg border border-white/30">
                  <.phx_icon
                    name="hero-book-open"
                    class="w-5 h-5 sm:w-6 sm:h-6 text-white drop-shadow-sm"
                  />
                </div>
                <div>
                  <h1 class="text-lg sm:text-xl font-semibold text-white drop-shadow-sm">
                    Timeline
                  </h1>
                  <p class="text-sm text-white/80 drop-shadow-sm">
                    Your private feed
                  </p>
                </div>
              </div>
            </div>
          </div>
        <% true -> %>
          <div class="relative h-32 sm:h-40 lg:h-48 bg-gradient-to-br from-emerald-500/90 via-teal-500/80 to-cyan-500/90 dark:from-emerald-600/80 dark:via-teal-600/70 dark:to-cyan-600/80">
            <div class="absolute inset-0 overflow-hidden">
              <div class="absolute -top-24 -right-24 w-64 h-64 bg-white/10 rounded-full blur-3xl animate-pulse" />
              <div class="absolute -bottom-16 -left-16 w-48 h-48 bg-emerald-300/20 rounded-full blur-2xl" />
              <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-96 h-32 bg-teal-200/10 rounded-full blur-3xl rotate-12" />
              <svg
                class="absolute inset-0 w-full h-full"
                viewBox="0 0 800 200"
                preserveAspectRatio="none"
              >
                <path
                  d="M0 120 Q200 80 400 120 T800 100"
                  fill="none"
                  stroke="white"
                  stroke-width="1"
                  opacity="0.2"
                />
                <path
                  d="M0 150 Q250 110 500 150 T800 130"
                  fill="none"
                  stroke="white"
                  stroke-width="0.8"
                  opacity="0.15"
                />
                <path
                  d="M0 80 Q150 50 350 80 T800 60"
                  fill="none"
                  stroke="white"
                  stroke-width="0.6"
                  opacity="0.1"
                />
              </svg>
            </div>

            <div class="absolute inset-0 bg-gradient-to-t from-black/30 via-transparent to-transparent" />

            <div class="absolute bottom-0 left-0 right-0 p-4 sm:p-6">
              <div class="flex items-center gap-3">
                <div class="flex items-center justify-center w-10 h-10 sm:w-12 sm:h-12 rounded-xl bg-white/20 backdrop-blur-md shadow-lg border border-white/30">
                  <.phx_icon
                    name="hero-book-open"
                    class="w-5 h-5 sm:w-6 sm:h-6 text-white drop-shadow-sm"
                  />
                </div>
                <div>
                  <h1 class="text-lg sm:text-xl font-semibold text-white drop-shadow-sm">
                    Timeline
                  </h1>
                  <p class="text-sm text-white/80 drop-shadow-sm">
                    Your private feed
                  </p>
                </div>
              </div>
            </div>
          </div>
      <% end %>
    </div>
    """
  end

  defp get_user_banner_image(nil), do: nil

  defp get_user_banner_image(user) do
    with %{connection: %{profile: %{banner_image: banner}}}
         when not is_nil(banner) and banner != :custom <- user do
      "#{banner}.jpg"
    else
      _ -> nil
    end
  rescue
    _ -> nil
  end

  # Helper function for tab icons (mobile optimization)
  defp tab_icon("home"), do: "hero-home"
  defp tab_icon("connections"), do: "hero-user-group"
  defp tab_icon("groups"), do: "hero-users"
  defp tab_icon("bookmarks"), do: "hero-bookmark"
  defp tab_icon("discover"), do: "hero-magnifying-glass"
  defp tab_icon(_), do: nil

  # Semantic colors for different tab types (calm but meaningful)
  defp timeline_tab_classes("home", true) do
    [
      "bg-gradient-to-r from-emerald-500 to-teal-500 text-white shadow-md",
      "hover:from-emerald-600 hover:to-teal-600"
    ]
  end

  defp timeline_tab_classes("connections", true) do
    [
      "bg-gradient-to-r from-blue-500 to-cyan-500 text-white shadow-md",
      "hover:from-blue-600 hover:to-cyan-600"
    ]
  end

  defp timeline_tab_classes("groups", true) do
    [
      "bg-gradient-to-r from-purple-500 to-violet-500 text-white shadow-md",
      "hover:from-purple-600 hover:to-violet-600"
    ]
  end

  defp timeline_tab_classes("bookmarks", true) do
    [
      "bg-gradient-to-r from-amber-500 to-orange-500 text-white shadow-md",
      "hover:from-amber-600 hover:to-orange-600"
    ]
  end

  defp timeline_tab_classes("discover", true) do
    [
      "bg-gradient-to-r from-indigo-500 to-blue-500 text-white shadow-md",
      "hover:from-indigo-600 hover:to-blue-600"
    ]
  end

  # Inactive states with subtle semantic tinting
  defp timeline_tab_classes("home", false) do
    [
      "text-emerald-600 dark:text-emerald-400 hover:text-emerald-700 dark:hover:text-emerald-300",
      "hover:bg-emerald-50/50 dark:hover:bg-emerald-900/20"
    ]
  end

  defp timeline_tab_classes("connections", false) do
    [
      "text-blue-600 dark:text-blue-400 hover:text-blue-700 dark:hover:text-blue-300",
      "hover:bg-blue-50/50 dark:hover:bg-blue-900/20"
    ]
  end

  defp timeline_tab_classes("groups", false) do
    [
      "text-purple-600 dark:text-purple-400 hover:text-purple-700 dark:hover:text-purple-300",
      "hover:bg-purple-50/50 dark:hover:bg-purple-900/20"
    ]
  end

  defp timeline_tab_classes("bookmarks", false) do
    [
      "text-amber-600 dark:text-amber-400 hover:text-amber-700 dark:hover:text-amber-300",
      "hover:bg-amber-50/50 dark:hover:bg-amber-900/20"
    ]
  end

  defp timeline_tab_classes("discover", false) do
    [
      "text-indigo-600 dark:text-indigo-400 hover:text-indigo-700 dark:hover:text-indigo-300",
      "hover:bg-indigo-50/50 dark:hover:bg-indigo-900/20"
    ]
  end

  # Fallback
  defp timeline_tab_classes(_, true) do
    [
      "bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100",
      "shadow-md border border-slate-200/60 dark:border-slate-600/60"
    ]
  end

  defp timeline_tab_classes(_, false) do
    [
      "text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100",
      "hover:bg-white/50 dark:hover:bg-slate-700/50"
    ]
  end

  # Active tab background gradients for semantic meaning
  defp timeline_tab_active_bg("home"),
    do:
      "bg-gradient-to-r from-emerald-50/40 via-teal-50/30 to-emerald-50/40 dark:from-emerald-900/20 dark:via-teal-900/15 dark:to-emerald-900/20"

  defp timeline_tab_active_bg("connections"),
    do:
      "bg-gradient-to-r from-blue-50/40 via-cyan-50/30 to-blue-50/40 dark:from-blue-900/20 dark:via-cyan-900/15 dark:to-blue-900/20"

  defp timeline_tab_active_bg("groups"),
    do:
      "bg-gradient-to-r from-purple-50/40 via-violet-50/30 to-purple-50/40 dark:from-purple-900/20 dark:via-violet-900/15 dark:to-purple-900/20"

  defp timeline_tab_active_bg("bookmarks"),
    do:
      "bg-gradient-to-r from-amber-50/40 via-orange-50/30 to-amber-50/40 dark:from-amber-900/20 dark:via-orange-900/15 dark:to-amber-900/20"

  defp timeline_tab_active_bg("discover"),
    do:
      "bg-gradient-to-r from-indigo-50/40 via-blue-50/30 to-indigo-50/40 dark:from-indigo-900/20 dark:via-blue-900/15 dark:to-indigo-900/20"

  defp timeline_tab_active_bg(_),
    do:
      "bg-gradient-to-r from-teal-50/30 via-emerald-50/20 to-cyan-50/30 dark:from-teal-900/20 dark:via-emerald-900/10 dark:to-cyan-900/20"

  # Count badge colors to match tab semantics
  # Unused for now because that is a calmer UX
  # defp timeline_tab_count_classes("home", true),
  #  do: "bg-emerald-100 dark:bg-emerald-800 text-emerald-800 dark:text-emerald-200"

  # defp timeline_tab_count_classes("connections", true),
  #  do: "bg-blue-100 dark:bg-blue-800 text-blue-800 dark:text-blue-200"

  # defp timeline_tab_count_classes("groups", true),
  #  do: "bg-purple-100 dark:bg-purple-800 text-purple-800 dark:text-purple-200"

  # defp timeline_tab_count_classes("bookmarks", true),
  #  do: "bg-amber-100 dark:bg-amber-800 text-amber-800 dark:text-amber-200"

  # defp timeline_tab_count_classes("discover", true),
  #  do: "bg-indigo-100 dark:bg-indigo-800 text-indigo-800 dark:text-indigo-200"

  # defp timeline_tab_count_classes(_, false),
  #  do: "bg-slate-200 dark:bg-slate-600 text-slate-600 dark:text-slate-300"

  # defp timeline_tab_count_classes(_, true),
  #  do: "bg-slate-200 dark:bg-slate-600 text-slate-600 dark:text-slate-300"

  # Helper functions for timeline action components

  # Action button color and state classes
  defp timeline_action_classes(false, "slate") do
    [
      "text-slate-500 dark:text-slate-400",
      "hover:text-emerald-600 dark:hover:text-emerald-400"
    ]
  end

  defp timeline_action_classes(false, "emerald") do
    [
      "text-slate-500 dark:text-slate-400",
      "hover:text-emerald-600 dark:hover:text-emerald-400",
      "[&.reply-expanded]:text-emerald-600 [&.reply-expanded]:dark:text-emerald-400",
      "[&.reply-expanded]:bg-emerald-50/50 [&.reply-expanded]:dark:bg-emerald-900/20"
    ]
  end

  defp timeline_action_classes(false, "amber") do
    [
      "text-slate-500 dark:text-slate-400",
      "hover:text-amber-600 dark:hover:text-amber-400"
    ]
  end

  defp timeline_action_classes(false, "rose") do
    [
      "text-slate-500 dark:text-slate-400",
      "hover:text-rose-600 dark:hover:text-rose-400"
    ]
  end

  # Active states
  defp timeline_action_classes(true, "emerald") do
    [
      "text-emerald-600 dark:text-emerald-400",
      "bg-emerald-50/50 dark:bg-emerald-900/20"
    ]
  end

  defp timeline_action_classes(true, "amber") do
    [
      "text-amber-600 dark:text-amber-400",
      "bg-amber-50/50 dark:bg-amber-900/20"
    ]
  end

  defp timeline_action_classes(true, "rose") do
    [
      "text-rose-600 dark:text-rose-400",
      "bg-rose-50/50 dark:bg-rose-900/20"
    ]
  end

  defp timeline_action_classes(true, _) do
    [
      "text-emerald-600 dark:text-emerald-400",
      "bg-emerald-50/50 dark:bg-emerald-900/20"
    ]
  end

  # Background hover effects for different actions
  defp timeline_action_bg_classes("emerald") do
    "bg-gradient-to-r from-emerald-50/30 via-teal-50/40 to-emerald-50/30 dark:from-emerald-900/15 dark:via-teal-900/20 dark:to-emerald-900/15"
  end

  defp timeline_action_bg_classes("amber") do
    "bg-gradient-to-r from-amber-50/30 via-yellow-50/40 to-amber-50/30 dark:from-amber-900/15 dark:via-yellow-900/20 dark:to-amber-900/15"
  end

  defp timeline_action_bg_classes("rose") do
    "bg-gradient-to-r from-rose-50/30 via-pink-50/40 to-rose-50/30 dark:from-rose-900/15 dark:via-pink-900/20 dark:to-rose-900/15"
  end

  defp timeline_action_bg_classes(_) do
    "bg-gradient-to-r from-emerald-50/30 via-teal-50/40 to-emerald-50/30 dark:from-emerald-900/15 dark:via-teal-900/20 dark:to-emerald-900/15"
  end

  # Helper functions for timeline components

  # Timeline status styling
  defp timeline_status_classes("online") do
    [
      "bg-emerald-50/80 dark:bg-emerald-900/20 text-emerald-700 dark:text-emerald-300",
      "border-emerald-200/60 dark:border-emerald-700/60"
    ]
  end

  defp timeline_status_classes("calm") do
    [
      "bg-teal-50/80 dark:bg-teal-900/20 text-teal-700 dark:text-teal-300",
      "border-teal-200/60 dark:border-teal-700/60"
    ]
  end

  defp timeline_status_classes("active") do
    [
      "bg-blue-50/80 dark:bg-blue-900/20 text-blue-700 dark:text-blue-300",
      "border-blue-200/60 dark:border-blue-700/60"
    ]
  end

  defp timeline_status_classes("away") do
    [
      "bg-amber-50/80 dark:bg-amber-900/20 text-amber-700 dark:text-amber-300",
      "border-amber-200/60 dark:border-amber-700/60"
    ]
  end

  defp timeline_status_classes("busy") do
    [
      "bg-rose-50/80 dark:bg-rose-900/20 text-rose-700 dark:text-rose-300",
      "border-rose-200/60 dark:border-rose-700/60"
    ]
  end

  defp timeline_status_classes("offline") do
    [
      "bg-slate-50/80 dark:bg-slate-800/20 text-slate-600 dark:text-slate-400",
      "border-slate-200/60 dark:border-slate-600/60"
    ]
  end

  defp timeline_status_dot_size("online"), do: "w-2 h-2"
  defp timeline_status_dot_size("active"), do: "w-2.5 h-2.5"
  defp timeline_status_dot_size("calm"), do: "w-2.5 h-2.5"
  defp timeline_status_dot_size("away"), do: "w-2 h-2"
  defp timeline_status_dot_size("busy"), do: "w-2 h-2"
  defp timeline_status_dot_size("offline"), do: "w-1.5 h-1.5"

  defp timeline_status_dot_classes("online"), do: "bg-gradient-to-br from-emerald-400 to-teal-500"
  defp timeline_status_dot_classes("active"), do: "bg-gradient-to-br from-blue-400 to-emerald-500"
  defp timeline_status_dot_classes("calm"), do: "bg-gradient-to-br from-teal-400 to-emerald-500"
  defp timeline_status_dot_classes("away"), do: "bg-gradient-to-br from-amber-400 to-orange-500"
  defp timeline_status_dot_classes("busy"), do: "bg-gradient-to-br from-rose-400 to-pink-500"
  defp timeline_status_dot_classes("offline"), do: "bg-gradient-to-br from-slate-400 to-gray-500"

  defp timeline_status_ping_classes("online"), do: "bg-emerald-400"
  defp timeline_status_ping_classes("active"), do: "bg-blue-400"
  defp timeline_status_ping_classes("away"), do: "bg-amber-400"
  defp timeline_status_ping_classes("busy"), do: "bg-rose-400"
  defp timeline_status_ping_classes("calm"), do: "bg-teal-400"
  defp timeline_status_ping_classes("offline"), do: "bg-slate-400"
  defp timeline_status_ping_classes(_), do: ""

  @doc """
  Timeline date separator with enhanced visual design.

  A visually prominent date separator for timeline posts with subtle animation
  and improved readability.

  ## Examples

      <.liquid_timeline_date_separator id="sep-123" datetime={~U[2024-01-15 12:00:00Z]} />
      <.liquid_timeline_date_separator id="sep-456" datetime={~U[2024-01-15 12:00:00Z]} color="orange" />
  """
  attr :id, :string, required: true
  attr :datetime, :any, required: true, doc: "DateTime or NaiveDateTime for the separator"
  attr :class, :any, default: ""
  attr :first, :boolean, default: false, doc: "Whether this is the first separator (no top line)"
  attr :color, :string, default: "emerald", doc: "Color theme: emerald or orange"

  def liquid_timeline_date_separator(assigns) do
    color_classes =
      case assigns.color do
        "orange" ->
          %{
            line_top: "bg-gradient-to-b from-transparent to-orange-400/50 dark:to-orange-500/40",
            dot: "bg-orange-500 dark:bg-orange-400 shadow-orange-500/30",
            line_bottom:
              "bg-gradient-to-b from-orange-400/50 to-transparent dark:from-orange-500/40",
            text: "text-orange-600 dark:text-orange-400"
          }

        _ ->
          %{
            line_top:
              "bg-gradient-to-b from-transparent to-emerald-400/50 dark:to-emerald-500/40",
            dot: "bg-emerald-500 dark:bg-emerald-400 shadow-emerald-500/30",
            line_bottom:
              "bg-gradient-to-b from-emerald-400/50 to-transparent dark:from-emerald-500/40",
            text: "text-emerald-600 dark:text-emerald-400"
          }
      end

    assigns = assign(assigns, :color_classes, color_classes)

    ~H"""
    <div class={["max-w-2xl mx-auto flex items-center py-1", @class]}>
      <div class="flex items-center gap-2.5 pl-1">
        <div class="flex flex-col items-center">
          <div class={[
            "w-px h-3",
            !@first && @color_classes.line_top,
            @first && "bg-transparent"
          ]} />
          <div class={[
            "w-2.5 h-2.5 rounded-full shadow-sm ring-2 ring-white dark:ring-slate-900",
            @color_classes.dot
          ]} />
          <div class={["w-px h-3", @color_classes.line_bottom]} />
        </div>
        <div class={["flex items-center gap-1.5 text-xs font-medium", @color_classes.text]}>
          <.phx_icon name="hero-calendar-days-mini" class="w-3.5 h-3.5" />
          <span
            id={@id}
            phx-hook="LocalDateSeparator"
            data-datetime={format_datetime_for_hook(@datetime)}
            class="opacity-0 transition-opacity duration-200"
          ></span>
        </div>
      </div>
    </div>
    """
  end

  defp format_datetime_for_hook(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_datetime_for_hook(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  defp format_datetime_for_hook(other), do: to_string(other)

  @doc """
  Timeline read posts divider with expand/collapse functionality.

  A beautiful animated divider that separates unread posts from read posts,
  with smooth animations and loading states.

  ## Examples

      <.liquid_read_posts_divider
        count={5}
        expanded={false}
        loading={false}
        tab_color="emerald"
      />
  """
  attr :count, :integer, required: true
  attr :expanded, :boolean, default: false
  attr :loading, :boolean, default: false
  attr :tab_color, :string, default: "emerald"
  attr :class, :any, default: ""

  def liquid_read_posts_divider(assigns) do
    assigns = assign(assigns, :color_classes, get_tab_color_classes(assigns.tab_color))

    ~H"""
    <div class={["relative py-6 max-w-2xl mx-auto", @class]}>
      <div class="absolute inset-0 flex items-center" aria-hidden="true">
        <div class={[
          "w-full h-px bg-gradient-to-r from-transparent to-transparent",
          @color_classes.divider_line
        ]} />
      </div>

      <div class="relative flex justify-center">
        <button
          type="button"
          phx-click="toggle_read_posts"
          disabled={@loading}
          class={[
            "group inline-flex items-center gap-2.5 px-5 py-2.5 rounded-full",
            "bg-white dark:bg-slate-800",
            "border",
            @color_classes.border,
            "shadow-lg shadow-slate-900/5 dark:shadow-black/20",
            "hover:shadow-xl hover:shadow-slate-900/10 dark:hover:shadow-black/30",
            @color_classes.hover_border,
            "focus:outline-none focus:ring-2 focus:ring-offset-2 dark:focus:ring-offset-slate-900",
            @color_classes.focus_ring,
            "transition-all duration-300 ease-out",
            "transform hover:scale-[1.02] active:scale-[0.98]",
            "phx-click-loading:cursor-wait phx-click-loading:opacity-90",
            @loading && "cursor-wait opacity-80"
          ]}
        >
          <div class="phx-click-loading:flex hidden items-center gap-2">
            <div class={[
              "h-4 w-4 animate-spin rounded-full border-2",
              @color_classes.spinner
            ]} />
            <span class="text-sm font-medium text-slate-600 dark:text-slate-300">
              {if @expanded, do: "Hiding...", else: "Loading..."}
            </span>
          </div>

          <div :if={@loading} class="phx-click-loading:hidden flex items-center gap-2">
            <div class={[
              "h-4 w-4 animate-spin rounded-full border-2",
              @color_classes.spinner
            ]} />
            <span class="text-sm font-medium text-slate-600 dark:text-slate-300">
              Loading posts...
            </span>
          </div>

          <div :if={!@loading} class="phx-click-loading:hidden flex items-center gap-2.5">
            <div class={[
              "flex items-center justify-center w-6 h-6 rounded-full",
              "bg-gradient-to-br from-slate-100 to-slate-50 dark:from-slate-700 dark:to-slate-800",
              @color_classes.icon_bg_hover,
              "transition-all duration-300"
            ]}>
              <.phx_icon
                name={if @expanded, do: "hero-chevron-up", else: "hero-chevron-down"}
                class={[
                  "w-3.5 h-3.5 text-slate-500 dark:text-slate-400",
                  @color_classes.icon_hover,
                  "transition-all duration-300",
                  @expanded && "rotate-180"
                ]}
              />
            </div>

            <span class="text-sm font-medium text-slate-600 dark:text-slate-300 group-hover:text-slate-800 dark:group-hover:text-slate-100 transition-colors">
              <%= if @expanded do %>
                Hide read posts
              <% else %>
                <span class="text-slate-500 dark:text-slate-400">Show</span>
                <span class={[
                  "inline-flex items-center justify-center min-w-[1.5rem] px-1.5 py-0.5 mx-1",
                  "text-xs font-semibold rounded-full",
                  "text-white shadow-sm",
                  @color_classes.badge
                ]}>
                  {@count}
                </span>
                <span class="text-slate-500 dark:text-slate-400">read posts</span>
              <% end %>
            </span>

            <div
              :if={!@expanded}
              class={[
                "flex items-center justify-center w-6 h-6 rounded-full",
                "bg-gradient-to-br from-slate-100 to-slate-50 dark:from-slate-700 dark:to-slate-800",
                @color_classes.icon_bg_hover,
                "transition-all duration-300"
              ]}
            >
              <.phx_icon
                name="hero-eye"
                class={[
                  "w-3.5 h-3.5 text-slate-400 dark:text-slate-500",
                  @color_classes.icon_hover,
                  "transition-colors duration-300"
                ]}
              />
            </div>
          </div>
        </button>
      </div>

      <div
        :if={@expanded && !@loading}
        class="absolute left-0 right-0 bottom-0 flex items-center hidden"
        aria-hidden="true"
      >
        <div class="w-full h-px bg-gradient-to-r from-transparent via-emerald-300/40 to-transparent dark:via-emerald-600/40 animate-pulse" />
      </div>
    </div>
    """
  end

  @doc """
  Sync status indicator for native apps showing online/offline state, sync progress, and last synced time.

  Only displayed when running on native platforms (desktop/mobile).

  ## Examples

      <.liquid_sync_status
        online={true}
        syncing={false}
        last_sync={~U[2025-01-01 12:00:00Z]}
        pending_count={0}
      />
  """
  attr :online, :boolean, default: true
  attr :syncing, :boolean, default: false
  attr :last_sync, :any, default: nil
  attr :pending_count, :integer, default: 0
  attr :class, :string, default: nil

  def liquid_sync_status(assigns) do
    ~H"""
    <div
      id="sync-status-indicator"
      class={[
        "group relative flex items-center gap-2 px-3 py-1.5 rounded-full text-sm",
        "transition-all duration-300 ease-out cursor-default",
        cond do
          @syncing ->
            "bg-gradient-to-r from-blue-50/80 to-cyan-50/80 dark:from-blue-900/30 dark:to-cyan-900/30 border border-blue-200/60 dark:border-blue-700/60"

          not @online ->
            "bg-gradient-to-r from-amber-50/80 to-orange-50/80 dark:from-amber-900/30 dark:to-orange-900/30 border border-amber-200/60 dark:border-amber-700/60"

          true ->
            "bg-gradient-to-r from-emerald-50/60 to-teal-50/60 dark:from-emerald-900/20 dark:to-teal-900/20 border border-emerald-200/40 dark:border-emerald-700/40"
        end,
        @class
      ]}
    >
      <div class="flex items-center gap-1.5">
        <%= cond do %>
          <% @syncing -> %>
            <div class="relative">
              <.phx_icon
                name="hero-arrow-path"
                class="h-4 w-4 text-blue-500 dark:text-blue-400 animate-spin"
              />
            </div>
            <span class="text-xs font-medium text-blue-700 dark:text-blue-300">
              Syncing{if @pending_count > 0, do: " (#{@pending_count})"}
            </span>
          <% not @online -> %>
            <div class="relative flex items-center justify-center">
              <span class="absolute w-2 h-2 bg-amber-400 dark:bg-amber-500 rounded-full animate-ping opacity-75" />
              <span class="relative w-2 h-2 bg-amber-500 dark:bg-amber-400 rounded-full" />
            </div>
            <span class="text-xs font-medium text-amber-700 dark:text-amber-300">
              Offline
            </span>
          <% true -> %>
            <div class="relative flex items-center justify-center">
              <span class="w-2 h-2 bg-emerald-500 dark:bg-emerald-400 rounded-full" />
            </div>
            <span class="text-xs font-medium text-emerald-700 dark:text-emerald-300">
              Synced
            </span>
        <% end %>
      </div>

      <div
        :if={@last_sync && @online && !@syncing}
        class="text-xs text-slate-500 dark:text-slate-400 pl-1.5 border-l border-slate-200/60 dark:border-slate-700/60"
      >
        <.local_time_ago id="sync-last-sync-time" at={@last_sync} />
      </div>

      <div
        :if={@pending_count > 0 && !@syncing}
        class="flex items-center gap-1 text-xs text-amber-600 dark:text-amber-400 pl-1.5 border-l border-slate-200/60 dark:border-slate-700/60"
      >
        <.phx_icon name="hero-clock" class="h-3 w-3" />
        <span>{@pending_count} pending</span>
      </div>
    </div>
    """
  end

  @doc """
  A simplified timeline card for public/discover pages with orange/amber theme.

  ## Examples

      <.public_timeline_card
        user_name="Jane Doe"
        user_handle="@jane"
        timestamp="2 hours ago"
        content="This is a public post..."
        images={["/uploads/image1.jpg"]}
        stats={%{replies: 3, likes: 12}}
      />
  """
  attr :id, :string, required: true
  attr :user_name, :string, required: true
  attr :user_handle, :string, required: true
  attr :user_avatar, :string, default: nil
  attr :author_profile_slug, :string, default: nil
  attr :author_profile_visibility, :atom, default: nil
  attr :timestamp, :string, required: true
  attr :content, :string, required: true
  attr :images, :list, default: []
  attr :stats, :map, default: %{}
  attr :content_warning?, :boolean, default: false
  attr :content_warning, :any, default: nil
  attr :content_warning_category, :any, default: nil
  attr :decrypted_url_preview, :any, default: nil
  attr :url_preview_fetched_at, :any, default: nil
  attr :external_uri, :any, default: nil
  attr :source, :atom, default: :mosslet
  attr :bluesky_link_verified, :boolean, default: true
  attr :class, :any, default: ""

  def public_timeline_card(assigns) do
    ~H"""
    <article
      id={@id}
      phx-hook="TouchHoverHook"
      class={[
        "group relative rounded-2xl transition-all duration-300 ease-out",
        "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
        "border border-orange-200/60 dark:border-orange-800/40",
        "shadow-lg shadow-orange-900/5 dark:shadow-orange-900/20",
        "hover:shadow-xl hover:shadow-orange-900/10 dark:hover:shadow-orange-900/30",
        "hover:border-orange-300/60 dark:hover:border-orange-700/60",
        "transform-gpu will-change-transform",
        @class
      ]}
    >
      <div class={[
        "absolute inset-0 rounded-2xl opacity-0 transition-all duration-500 ease-out",
        "group-hover:opacity-100 touch-hover:opacity-100",
        "bg-gradient-to-br from-orange-50/30 via-amber-50/20 to-yellow-50/30 dark:from-orange-900/10 dark:via-amber-900/5 dark:to-yellow-900/10"
      ]}>
      </div>

      <div class="absolute right-0 top-4 bottom-4 w-1 bg-gradient-to-b from-orange-400 via-amber-400 to-orange-400 dark:from-orange-500 dark:via-amber-500 dark:to-orange-500 rounded-l-full opacity-50">
      </div>

      <div class="relative p-4 sm:p-5">
        <div class="flex items-start gap-3 sm:gap-4">
          <%= if can_view_profile?(@author_profile_visibility) && @author_profile_slug do %>
            <.link navigate={~p"/profile/#{@author_profile_slug}"} class="shrink-0 group/avatar">
              <div class="relative">
                <%= if @user_avatar do %>
                  <img
                    src={@user_avatar}
                    alt={@user_name}
                    class="w-10 h-10 sm:w-11 sm:h-11 rounded-xl object-cover ring-2 ring-orange-200/50 dark:ring-orange-700/50 group-hover/avatar:ring-orange-300 dark:group-hover/avatar:ring-orange-600 transition-all duration-200"
                  />
                <% else %>
                  <div class="w-10 h-10 sm:w-11 sm:h-11 rounded-xl bg-gradient-to-br from-orange-400 to-amber-500 flex items-center justify-center ring-2 ring-orange-200/50 dark:ring-orange-700/50 group-hover/avatar:ring-orange-300 dark:group-hover/avatar:ring-orange-600 transition-all duration-200">
                    <span class="text-white font-semibold text-sm sm:text-base">
                      {String.first(@user_name) |> String.upcase()}
                    </span>
                  </div>
                <% end %>
              </div>
            </.link>
          <% else %>
            <div class="shrink-0">
              <div class="relative">
                <%= if @user_avatar do %>
                  <img
                    src={@user_avatar}
                    alt={@user_name}
                    class="w-10 h-10 sm:w-11 sm:h-11 rounded-xl object-cover ring-2 ring-orange-200/50 dark:ring-orange-700/50"
                  />
                <% else %>
                  <div class="w-10 h-10 sm:w-11 sm:h-11 rounded-xl bg-gradient-to-br from-orange-400 to-amber-500 flex items-center justify-center ring-2 ring-orange-200/50 dark:ring-orange-700/50">
                    <span class="text-white font-semibold text-sm sm:text-base">
                      {String.first(@user_name) |> String.upcase()}
                    </span>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>

          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 flex-wrap">
              <%= if can_view_profile?(@author_profile_visibility) && @author_profile_slug do %>
                <.link
                  navigate={~p"/profile/#{@author_profile_slug}"}
                  class="font-semibold text-slate-900 dark:text-slate-100 hover:text-orange-600 dark:hover:text-orange-400 transition-colors truncate"
                >
                  {@user_name}
                </.link>
              <% else %>
                <span class="font-semibold text-slate-900 dark:text-slate-100 truncate">
                  {@user_name}
                </span>
              <% end %>
              <span class="text-slate-500 dark:text-slate-400 text-sm truncate">{@user_handle}</span>
              <span class="text-slate-400 dark:text-slate-500">·</span>
              <span class="text-slate-500 dark:text-slate-400 text-sm whitespace-nowrap">
                {@timestamp}
              </span>
              <.bluesky_badge
                :if={@external_uri && @source == :mosslet && @bluesky_link_verified != false}
                id={"bluesky-badge-#{@id}"}
                external_uri={@external_uri}
                type={:synced}
              />
              <.bluesky_badge
                :if={@source == :bluesky && @external_uri}
                id={"bluesky-import-badge-#{@id}"}
                external_uri={@external_uri}
                type={:imported}
              />
            </div>

            <div class="mt-2 sm:mt-3">
              <%= if @content_warning? do %>
                <.public_content_warning_wrapper
                  id={@id}
                  content_warning={@content_warning}
                  content_warning_category={@content_warning_category}
                >
                  <.public_post_content
                    content={@content}
                    images={@images}
                    url_preview={@decrypted_url_preview}
                    post_id={@id}
                    url_preview_fetched_at={@url_preview_fetched_at}
                  />
                </.public_content_warning_wrapper>
              <% else %>
                <.public_post_content
                  content={@content}
                  images={@images}
                  url_preview={@decrypted_url_preview}
                  post_id={@id}
                  url_preview_fetched_at={@url_preview_fetched_at}
                />
              <% end %>
            </div>

            <div class="mt-3 sm:mt-4 flex items-center gap-4 sm:gap-6 text-slate-500 dark:text-slate-400">
              <div class="flex items-center gap-1.5 text-sm">
                <.phx_icon name="hero-chat-bubble-oval-left" class="h-4 w-4" />
                <span>{Map.get(@stats, :replies, 0)}</span>
              </div>
              <div :if={Map.get(@stats, :likes, 0) > 0} class="flex items-center gap-1.5 text-sm">
                <.phx_icon name="hero-heart" class="h-4 w-4" />
                <span>{soft_like_text(Map.get(@stats, :likes, 0), false)}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </article>
    """
  end

  attr :id, :string, required: true
  attr :external_uri, :any, required: true
  attr :type, :atom, values: [:synced, :imported], required: true

  defp bluesky_badge(assigns) do
    web_url = Mosslet.Bluesky.Client.at_uri_to_web_url(assigns.external_uri)
    assigns = assign(assigns, :web_url, web_url)

    ~H"""
    <a
      :if={@web_url}
      href={@web_url}
      target="_blank"
      rel="noopener noreferrer"
      class={[
        "inline-flex items-center gap-1 px-1.5 py-0.5 rounded-full text-[10px] font-medium border transition-all duration-150",
        if(@type == :synced,
          do:
            "bg-sky-50 dark:bg-sky-900/30 text-sky-600 dark:text-sky-400 border-sky-200/50 dark:border-sky-700/40 hover:bg-sky-100 dark:hover:bg-sky-900/50 hover:border-sky-300 dark:hover:border-sky-600",
          else:
            "bg-slate-100 dark:bg-slate-700/50 text-slate-500 dark:text-slate-400 border-slate-200/50 dark:border-slate-600/40 hover:bg-slate-200 dark:hover:bg-slate-700 hover:border-slate-300 dark:hover:border-slate-500"
        )
      ]}
      phx-hook="TippyHook"
      data-tippy-content={if @type == :synced, do: "View on Bluesky", else: "View on Bluesky"}
      id={@id}
    >
      <svg class="h-2.5 w-2.5" viewBox="0 0 568 501" fill="currentColor">
        <path d="M123.121 33.6637C188.241 82.5526 258.281 181.681 284 234.873C309.719 181.681 379.759 82.5526 444.879 33.6637C491.866 -1.61183 568 -28.9064 568 57.9464C568 75.2916 558.055 203.659 552.222 224.501C531.947 296.954 458.067 315.434 392.347 304.249C507.222 323.8 536.444 388.56 473.333 453.32C353.473 576.312 301.061 422.461 287.631 383.36C286.267 378.309 284.737 377.78 284 377.78C283.263 377.78 281.733 378.309 280.369 383.36C266.939 422.461 214.527 576.312 94.6667 453.32C31.5556 388.56 60.7778 323.8 175.653 304.249C109.933 315.434 36.0533 296.954 15.7778 224.501C9.94445 203.659 0 75.2916 0 57.9464C0 -28.9064 76.1345 -1.61183 123.121 33.6637Z" />
      </svg>
    </a>
    """
  end

  attr :id, :string, required: true
  attr :content_warning, :string, default: nil
  attr :content_warning_category, :string, default: nil
  slot :inner_block, required: true

  defp public_content_warning_wrapper(assigns) do
    ~H"""
    <div id={"cw-wrapper-#{@id}"}>
      <div
        id={"cw-overlay-#{@id}"}
        class="relative p-4 bg-gradient-to-br from-amber-50/80 to-orange-50/80 dark:from-amber-900/20 dark:to-orange-900/20 rounded-xl border border-amber-200/60 dark:border-amber-700/40"
      >
        <div class="flex items-start gap-3">
          <div class="shrink-0 p-2 rounded-lg bg-amber-100 dark:bg-amber-900/40">
            <.phx_icon name="hero-eye-slash" class="h-5 w-5 text-amber-600 dark:text-amber-400" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="font-medium text-amber-800 dark:text-amber-200 text-sm">
              Content Warning
            </p>
            <p :if={@content_warning} class="text-amber-700 dark:text-amber-300 text-sm mt-1">
              {@content_warning}
            </p>
            <p
              :if={@content_warning_category}
              class="text-amber-600/80 dark:text-amber-400/80 text-xs mt-1"
            >
              Category: {@content_warning_category}
            </p>
            <button
              type="button"
              phx-click={
                JS.hide(to: "#cw-overlay-#{@id}")
                |> JS.show(to: "#cw-content-#{@id}")
              }
              class="mt-3 inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-amber-700 dark:text-amber-300 bg-amber-100 dark:bg-amber-900/40 hover:bg-amber-200 dark:hover:bg-amber-800/50 rounded-lg transition-colors"
            >
              <.phx_icon name="hero-eye" class="h-3.5 w-3.5" /> Show Content
            </button>
          </div>
        </div>
      </div>
      <div id={"cw-content-#{@id}"} class="hidden">
        {render_slot(@inner_block)}
        <button
          type="button"
          phx-click={
            JS.show(to: "#cw-overlay-#{@id}")
            |> JS.hide(to: "#cw-content-#{@id}")
          }
          class="mt-3 inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-amber-700 dark:text-amber-300 bg-amber-100/80 dark:bg-amber-900/30 hover:bg-amber-200 dark:hover:bg-amber-800/50 rounded-lg transition-colors"
        >
          <.phx_icon name="hero-eye-slash" class="h-3.5 w-3.5" /> Hide Content
        </button>
      </div>
    </div>
    """
  end

  attr :content, :string, required: true
  attr :images, :list, default: []
  attr :url_preview, :any, default: nil
  attr :post_id, :string, required: true
  attr :url_preview_fetched_at, :any, default: nil

  defp public_post_content(assigns) do
    assigns = assign(assigns, :image_count, length(assigns.images))

    ~H"""
    <div class="space-y-3">
      <div class="prose prose-slate dark:prose-invert prose-sm max-w-none prose-p:my-1.5 prose-headings:mt-3 prose-headings:mb-1.5 prose-ul:my-1.5 prose-ol:my-1.5 prose-li:my-0.5 prose-pre:my-2 prose-code:text-orange-600 dark:prose-code:text-orange-400 prose-a:text-orange-600 dark:prose-a:text-orange-400 prose-a:no-underline hover:prose-a:underline">
        {format_decrypted_content(@content)}
      </div>

      <div
        :if={@image_count > 0}
        id={"public-post-images-#{@post_id}"}
        phx-hook="PublicPostImagesHook"
        data-post-id={@post_id}
        data-image-count={@image_count}
        class="relative rounded-xl overflow-hidden border border-slate-200/60 dark:border-slate-700/60 mt-3"
      >
        <div class="w-full h-24 sm:h-32 flex items-center justify-center bg-slate-100 dark:bg-slate-800">
          <div class="flex flex-col items-center gap-2">
            <div class="w-6 h-6 rounded-full border-2 border-orange-500/30 border-t-orange-500 animate-spin">
            </div>
            <span class="text-xs text-slate-500 dark:text-slate-400">Loading photos...</span>
          </div>
        </div>
      </div>

      <%= if @url_preview do %>
        <.public_url_preview
          preview={@url_preview}
          post_id={@post_id}
          url_preview_fetched_at={@url_preview_fetched_at}
        />
      <% end %>
    </div>
    """
  end

  attr :preview, :map, required: true
  attr :post_id, :string, required: true
  attr :url_preview_fetched_at, :any, default: nil

  defp public_url_preview(assigns) do
    ~H"""
    <a
      :if={@preview["url"]}
      href={@preview["url"]}
      target="_blank"
      rel="noopener noreferrer"
      class="flex gap-3 p-2 mt-3 rounded-xl border border-slate-200/60 dark:border-slate-700/60 bg-slate-50/50 dark:bg-slate-800/50 hover:border-orange-300/60 dark:hover:border-orange-600/60 transition-all duration-200 group/preview"
    >
      <div
        :if={@preview["image"] && @preview["image"] != ""}
        class="w-20 h-14 shrink-0 overflow-hidden rounded-lg bg-slate-100 dark:bg-slate-700"
        phx-hook="URLPreviewHook"
        id={"url-preview-#{@post_id}"}
        data-post-id={@post_id}
        data-image-hash={@preview["image_hash"]}
        data-url-preview-fetched-at={@url_preview_fetched_at}
        data-presigned-url={@preview["image"]}
      >
        <img
          alt={@preview["title"] || "Preview image"}
          class="w-full h-full object-cover group-hover/preview:scale-105 transition-transform duration-300"
        />
      </div>
      <div class="flex-1 min-w-0 py-0.5">
        <div class="flex items-center gap-1.5 mb-0.5">
          <.phx_icon name="hero-link" class="h-3 w-3 text-slate-400" />
          <span class="text-xs text-slate-500 dark:text-slate-400 truncate">
            {@preview["site_name"] || URI.parse(@preview["url"]).host}
          </span>
        </div>
        <p
          :if={@preview["title"]}
          class="font-medium text-sm text-slate-900 dark:text-slate-100 line-clamp-1 group-hover/preview:text-orange-600 dark:group-hover/preview:text-orange-400 transition-colors"
        >
          {@preview["title"]}
        </p>
        <p
          :if={@preview["description"]}
          class="text-xs text-slate-600 dark:text-slate-400 line-clamp-2 mt-0.5"
        >
          {@preview["description"]}
        </p>
      </div>
    </a>
    """
  end

  defp can_view_profile?(:public), do: true
  defp can_view_profile?(_), do: false

  @doc """
  Renders a sync status indicator for native apps.

  Shows online/offline status, syncing state, and pending changes count.
  Hidden by default when online with no pending changes.

  ## Examples

      <.sync_status_indicator sync_status={@sync_status} />

  """
  attr :sync_status, :map, default: nil
  attr :class, :string, default: nil

  def sync_status_indicator(assigns) do
    ~H"""
    <div
      :if={@sync_status}
      id="sync-status-indicator"
      phx-hook="SyncStatusHook"
      class={[
        "flex items-center gap-2 px-3 py-1.5 rounded-full text-xs font-medium transition-all duration-300",
        sync_status_classes(@sync_status),
        @class,
        @sync_status.online && !@sync_status.syncing && @sync_status.pending_count == 0 && "hidden"
      ]}
    >
      <span
        data-status-dot
        class={[
          "w-2 h-2 rounded-full transition-colors duration-300",
          sync_dot_classes(@sync_status)
        ]}
      ></span>
      <span data-status-text>{sync_status_text(@sync_status)}</span>
      <span
        :if={@sync_status.pending_count > 0}
        data-pending-badge
        class="inline-flex items-center justify-center min-w-[1.25rem] h-5 px-1.5 text-[10px] font-semibold rounded-full bg-amber-100 text-amber-800 dark:bg-amber-900/50 dark:text-amber-200"
      >
        {@sync_status.pending_count}
      </span>
    </div>
    """
  end

  defp sync_status_classes(%{online: false}) do
    "bg-red-50 text-red-700 dark:bg-red-900/30 dark:text-red-300 border border-red-200 dark:border-red-800"
  end

  defp sync_status_classes(%{syncing: true}) do
    "bg-amber-50 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300 border border-amber-200 dark:border-amber-800"
  end

  defp sync_status_classes(%{pending_count: count}) when count > 0 do
    "bg-amber-50 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300 border border-amber-200 dark:border-amber-800"
  end

  defp sync_status_classes(_) do
    "bg-emerald-50 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-300 border border-emerald-200 dark:border-emerald-800"
  end

  defp sync_dot_classes(%{online: false}), do: "bg-red-500"
  defp sync_dot_classes(%{syncing: true}), do: "bg-amber-500 animate-pulse"
  defp sync_dot_classes(%{pending_count: count}) when count > 0, do: "bg-amber-500"
  defp sync_dot_classes(_), do: "bg-emerald-500"

  defp sync_status_text(%{online: false}), do: "Offline"
  defp sync_status_text(%{syncing: true}), do: "Syncing..."
  defp sync_status_text(%{pending_count: count}) when count > 0, do: "#{count} pending"
  defp sync_status_text(_), do: "Synced"

  @doc """
  Renders an offline banner that displays prominently when the app is offline.

  This is a larger, more visible indicator meant to be shown at the top of the page.

  ## Examples

      <.offline_banner sync_status={@sync_status} />

  """
  attr :sync_status, :map, default: nil

  def offline_banner(assigns) do
    ~H"""
    <div
      :if={@sync_status && !@sync_status.online}
      class="bg-gradient-to-r from-red-500 via-red-600 to-red-500 text-white px-4 py-2 text-center text-sm font-medium shadow-lg"
      role="alert"
    >
      <div class="flex items-center justify-center gap-2">
        <.phx_icon name="hero-signal-slash" class="w-4 h-4" />
        <span>You're offline. Changes will sync when you're back online.</span>
        <span
          :if={@sync_status.pending_count > 0}
          class="inline-flex items-center justify-center min-w-[1.5rem] h-5 px-2 text-xs font-bold rounded-full bg-white/20"
        >
          {@sync_status.pending_count} pending
        </span>
      </div>
    </div>
    """
  end
end
