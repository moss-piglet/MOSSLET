defmodule MossletWeb.ConnectionComponents do
  @moduledoc """
  Connection, circle, and group components for the connections interface.

  Extracted from `MossletWeb.DesignSystem` as part of the design system
  modularization (Phase 1).
  """
  use Phoenix.Component
  use MossletWeb, :verified_routes

  import MossletWeb.CoreComponents,
    only: [phx_icon: 1, local_time_ago: 1, phx_modal: 1, phx_show_modal: 2]

  import MossletWeb.DesignSystem,
    only: [
      liquid_avatar: 1,
      liquid_badge: 1,
      liquid_button: 1
    ]

  import MossletWeb.ReplyComponents,
    only: [
      get_shared_connection: 2,
      show_profile?: 1
    ]

  import MossletWeb.Helpers,
    only: [
      decr: 3,
      decr_uconn: 4
    ]

  alias Phoenix.LiveView.JS

  # ── Private helpers duplicated from DesignSystem (needed by extracted components) ──

  # Used by liquid_shared_users_dropdown
  defp visibility_badge_color(visibility) do
    case visibility do
      :private -> "slate"
      :connections -> "emerald"
      :public -> "blue"
      :specific_groups -> "purple"
      :specific_users -> "amber"
      _ -> "slate"
    end
  end

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

  # Used by liquid_empty_state, liquid_connection_card, liquid_arrival_card
  attr :level, :integer, required: true
  attr :class, :any, default: ""
  slot :inner_block, required: true

  defp dynamic_heading(%{level: 1} = assigns) do
    ~H"""
    <h1 class={@class}>{render_slot(@inner_block)}</h1>
    """
  end

  defp dynamic_heading(%{level: 2} = assigns) do
    ~H"""
    <h2 class={@class}>{render_slot(@inner_block)}</h2>
    """
  end

  defp dynamic_heading(%{level: 3} = assigns) do
    ~H"""
    <h3 class={@class}>{render_slot(@inner_block)}</h3>
    """
  end

  defp dynamic_heading(%{level: 4} = assigns) do
    ~H"""
    <h4 class={@class}>{render_slot(@inner_block)}</h4>
    """
  end

  defp dynamic_heading(%{level: 5} = assigns) do
    ~H"""
    <h5 class={@class}>{render_slot(@inner_block)}</h5>
    """
  end

  defp dynamic_heading(%{level: 6} = assigns) do
    ~H"""
    <h6 class={@class}>{render_slot(@inner_block)}</h6>
    """
  end

  # ── Extracted components ──

  @doc """
  Shared users dropdown with profile links, remove functionality, and add user UI.
  """
  attr :post, :map, required: true
  attr :post_shared_users, :list, required: true
  attr :removing_shared_user_id, :string, default: nil
  attr :adding_shared_user, :map, default: nil

  def liquid_shared_users_dropdown(assigns) do
    ~H"""
    <div
      id={"post-shared-users-menu-#{@post.id}"}
      class="relative"
      phx-click-away={JS.hide(to: "#post-shared-users-menu-#{@post.id}-menu")}
    >
      <button
        type="button"
        phx-click={JS.toggle(to: "#post-shared-users-menu-#{@post.id}-menu")}
        class="p-2 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100/50 dark:hover:bg-slate-700/50 transition-all duration-200 ease-out"
        id={"post-shared-users-menu-trigger-#{@post.id}"}
        phx-hook="TippyHook"
        data-tippy-content="Manage who you shared with"
      >
        <.liquid_badge variant="soft" color={visibility_badge_color(@post.visibility)} size="sm">
          {visibility_badge_text(@post.visibility)}
        </.liquid_badge>
      </button>

      <div
        id={"post-shared-users-menu-#{@post.id}-menu"}
        class={[
          "absolute z-[200] mt-2 w-72 origin-top-right hidden right-0",
          "rounded-xl border border-slate-200/60 dark:border-slate-700/60",
          "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
          "shadow-xl shadow-slate-900/10 dark:shadow-slate-900/30",
          "ring-1 ring-slate-200/60 dark:ring-slate-700/60",
          "animate-in fade-in slide-in-from-top-2 duration-200"
        ]}
      >
        <div class="absolute inset-0 rounded-xl bg-gradient-to-br from-teal-50/20 via-emerald-50/10 to-cyan-50/20 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10 opacity-50">
        </div>

        <div class="relative">
          <div class="px-4 py-3 border-b border-slate-200/60 dark:border-slate-700/60">
            <h4 class="text-sm font-semibold text-slate-900 dark:text-slate-100">
              Shared with
            </h4>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
              {length(@post.shared_users)} {if length(@post.shared_users) == 1,
                do: "person",
                else: "people"}
            </p>
          </div>

          <div class="max-h-[14rem] overflow-y-auto py-2">
            <div
              :for={shared_user <- @post.shared_users}
              :if={!Enum.empty?(@post.shared_users)}
              class="group"
            >
              <% shared_post_user = get_shared_connection(shared_user.user_id, @post_shared_users) %>
              <% is_removing = @removing_shared_user_id == shared_user.user_id %>
              <div class={[
                "flex items-center gap-3 px-2 py-1.5 transition-all duration-200",
                is_removing && "opacity-50 pointer-events-none"
              ]}>
                <%= if shared_post_user do %>
                  <.link
                    :if={show_profile?(shared_post_user)}
                    id={"profile-link-#{@post.id}-person-#{shared_user.user_id}"}
                    navigate={~p"/app/profile/#{shared_post_user.profile_slug}"}
                    phx-hook="TippyHook"
                    data-tippy-content="View profile"
                    class="flex items-center gap-3 flex-1 min-w-0 px-2 py-1.5 -mx-2 -my-1.5 rounded-lg hover:bg-slate-100/80 dark:hover:bg-slate-700/50 transition-all duration-200"
                  >
                    <div class={[
                      "flex h-9 w-9 shrink-0 items-center justify-center rounded-lg",
                      "bg-gradient-to-br transition-all duration-200",
                      get_post_shared_user_classes(shared_post_user.color)
                    ]}>
                      <span class={[
                        "text-sm font-semibold",
                        get_post_shared_user_text_classes(shared_post_user.color)
                      ]}>
                        {String.first(shared_post_user.username || "?") |> String.upcase()}
                      </span>
                    </div>
                    <div class="flex-1 min-w-0">
                      <span class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate block">
                        {shared_post_user.username}
                      </span>
                      <span class="text-xs text-slate-500 dark:text-slate-400">
                        Connection
                      </span>
                    </div>
                  </.link>
                  <div
                    :if={!show_profile?(shared_post_user)}
                    class="flex items-center gap-3 flex-1 min-w-0"
                  >
                    <div class={[
                      "flex h-9 w-9 shrink-0 items-center justify-center rounded-lg",
                      "bg-gradient-to-br transition-all duration-200",
                      get_post_shared_user_classes(shared_post_user.color)
                    ]}>
                      <span class={[
                        "text-sm font-semibold",
                        get_post_shared_user_text_classes(shared_post_user.color)
                      ]}>
                        {String.first(shared_post_user.username || "?") |> String.upcase()}
                      </span>
                    </div>
                    <div class="flex-1 min-w-0">
                      <span class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate block">
                        {shared_post_user.username}
                      </span>
                      <span class="text-xs text-slate-500 dark:text-slate-400">
                        Connection
                      </span>
                    </div>
                  </div>
                  <button
                    type="button"
                    phx-click="remove_shared_user"
                    phx-value-post-id={@post.id}
                    phx-value-user-id={shared_user.user_id}
                    phx-value-shared-username={shared_post_user.username}
                    class="p-2 rounded-lg text-slate-400 dark:text-slate-500 hover:text-rose-600 dark:hover:text-rose-400 bg-slate-100/60 dark:bg-slate-700/40 hover:bg-rose-50 dark:hover:bg-rose-900/30 transition-all duration-200 shrink-0"
                    phx-hook="TippyHook"
                    data-tippy-content="Remove access"
                    id={"remove-access-#{@post.id}-person-#{shared_user.user_id}"}
                  >
                    <%= if is_removing do %>
                      <.phx_icon name="hero-arrow-path-mini" class="w-4 h-4 animate-spin" />
                    <% else %>
                      <.phx_icon name="hero-x-mark-mini" class="w-4 h-4" />
                    <% end %>
                  </button>
                <% else %>
                  <div class="flex items-center gap-3 flex-1 min-w-0">
                    <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-slate-200 dark:bg-slate-700">
                      <.phx_icon
                        name="hero-user-minus"
                        class="w-4 h-4 text-slate-400 dark:text-slate-500"
                      />
                    </div>
                    <div class="flex-1 min-w-0">
                      <span class="text-sm font-medium text-slate-500 dark:text-slate-400 truncate italic block">
                        Former connection
                      </span>
                      <span class="text-xs text-slate-400 dark:text-slate-500">
                        No longer connected
                      </span>
                    </div>
                  </div>
                  <button
                    type="button"
                    phx-click="remove_shared_user"
                    phx-value-post-id={@post.id}
                    phx-value-user-id={shared_user.user_id}
                    phx-value-shared-username=""
                    class="p-2 rounded-lg text-slate-400 dark:text-slate-500 hover:text-rose-600 dark:hover:text-rose-400 bg-slate-100/60 dark:bg-slate-700/40 hover:bg-rose-50 dark:hover:bg-rose-900/30 transition-all duration-200 shrink-0"
                    title="Remove"
                  >
                    <%= if is_removing do %>
                      <.phx_icon name="hero-arrow-path-mini" class="w-4 h-4 animate-spin" />
                    <% else %>
                      <.phx_icon name="hero-x-mark-mini" class="w-4 h-4" />
                    <% end %>
                  </button>
                <% end %>
              </div>
            </div>

            <div :if={Enum.empty?(@post.shared_users)} class="px-4 py-6 text-center">
              <div class="inline-flex items-center justify-center w-12 h-12 mb-3 rounded-full bg-slate-100 dark:bg-slate-700">
                <.phx_icon name="hero-user-group" class="w-6 h-6 text-slate-400 dark:text-slate-500" />
              </div>
              <p class="text-sm text-slate-500 dark:text-slate-400">
                Not shared with anyone yet
              </p>
            </div>
          </div>

          <div class="px-4 py-3 border-t border-slate-200/60 dark:border-slate-700/60">
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
                <div class="relative" id={"add-shared-user-#{@post.id}"}>
                  <button
                    type="button"
                    phx-click={JS.toggle(to: "#add-shared-user-list-#{@post.id}")}
                    class="w-full flex items-center justify-center gap-2 px-3 py-2 text-sm font-medium text-emerald-600 dark:text-emerald-400 rounded-lg border border-dashed border-emerald-300 dark:border-emerald-700 hover:bg-emerald-50 dark:hover:bg-emerald-900/20 transition-all duration-200"
                  >
                    <.phx_icon name="hero-plus-mini" class="w-4 h-4" /> Add someone
                  </button>

                  <div
                    id={"add-shared-user-list-#{@post.id}"}
                    phx-click-away={JS.hide(to: "#add-shared-user-list-#{@post.id}")}
                    phx-key="escape"
                    phx-window-keydown={JS.hide(to: "#add-shared-user-list-#{@post.id}")}
                    class="hidden absolute bottom-full left-0 right-0 mb-2 max-h-40 overflow-y-auto rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 shadow-lg animate-in fade-in slide-in-from-bottom-2 duration-150"
                  >
                    <div
                      :for={conn <- available_connections}
                      id={"add-shared-user-list-item-#{@post.id}-#{conn.user_id}"}
                      phx-click={
                        JS.hide(to: "#add-shared-user-list-#{@post.id}")
                        |> JS.push("add_shared_user")
                      }
                      phx-value-post-id={@post.id}
                      phx-value-user-id={conn.user_id}
                      phx-value-username={conn.username}
                      class={[
                        "flex items-center gap-3 px-3 py-2 cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors duration-150",
                        @adding_shared_user && @adding_shared_user.post_id == @post.id &&
                          @adding_shared_user.username == conn.username &&
                          "opacity-50 pointer-events-none"
                      ]}
                    >
                      <%= if @adding_shared_user && @adding_shared_user.post_id == @post.id && @adding_shared_user.username == conn.username do %>
                        <div class="flex h-7 w-7 shrink-0 items-center justify-center rounded-md bg-emerald-100 dark:bg-emerald-900/30">
                          <.phx_icon
                            name="hero-arrow-path"
                            class="w-4 h-4 text-emerald-600 dark:text-emerald-400 animate-spin"
                          />
                        </div>
                        <span class="text-sm text-emerald-600 dark:text-emerald-400">
                          Adding...
                        </span>
                      <% else %>
                        <div class={[
                          "flex h-7 w-7 shrink-0 items-center justify-center rounded-md",
                          "bg-gradient-to-br",
                          get_post_shared_user_classes(conn.color)
                        ]}>
                          <span class={[
                            "text-xs font-semibold",
                            get_post_shared_user_text_classes(conn.color)
                          ]}>
                            {String.first(conn.username || "?") |> String.upcase()}
                          </span>
                        </div>
                        <span class="text-sm text-slate-700 dark:text-slate-300 truncate">
                          {conn.username}
                        </span>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Compact liquid filter select for admin interfaces.
  Follows the same liquid metal design patterns as liquid_select but optimized for filter forms.
  """
  attr :name, :string, required: true
  attr :value, :string, required: true
  attr :options, :list, required: true
  attr :label, :string, default: nil
  attr :class, :any, default: ""
  attr :rest, :global

  def liquid_filter_select(assigns) do
    assigns = assign_new(assigns, :id, fn -> assigns.name end)

    ~H"""
    <div class={["group relative", @class]}>
      <label :if={@label} for={@id} class="sr-only">{@label}</label>
      <%!-- Enhanced liquid background effect on focus (matching main liquid_select) --%>
      <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-br from-emerald-50/30 via-teal-50/40 to-emerald-50/30 dark:from-emerald-900/15 dark:via-teal-900/20 dark:to-emerald-900/15 group-focus-within:opacity-100 rounded-xl pointer-events-none">
      </div>

      <%!-- Enhanced shimmer effect on focus (matching main liquid_select) --%>
      <div class="absolute inset-0 opacity-0 transition-all duration-700 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 group-focus-within:opacity-100 group-focus-within:translate-x-full -translate-x-full rounded-xl pointer-events-none">
      </div>

      <%!-- Focus ring with liquid metal styling (matching main liquid_select) --%>
      <div class="absolute -inset-1 opacity-0 transition-all duration-200 ease-out rounded-xl bg-gradient-to-r from-teal-500 via-emerald-500 to-teal-500 dark:from-teal-400 dark:via-emerald-400 dark:to-teal-400 group-focus-within:opacity-100 blur-sm pointer-events-none">
      </div>

      <%!-- Secondary focus ring for better definition (matching main liquid_select) --%>
      <div class="absolute -inset-0.5 opacity-0 transition-all duration-200 ease-out rounded-xl border-2 border-emerald-500 dark:border-emerald-400 group-focus-within:opacity-100 pointer-events-none">
      </div>

      <%!-- Select field with enhanced contrast (matching main liquid_select styling) --%>
      <select
        id={@id}
        name={@name}
        class={[
          "relative z-10 block w-full rounded-xl px-4 py-3 pr-10 text-slate-900 dark:text-slate-100",
          "bg-slate-50 dark:bg-slate-900",
          "border-2 border-slate-200 dark:border-slate-700",
          "hover:border-slate-300 dark:hover:border-slate-600",
          "focus:border-emerald-500 dark:focus:border-emerald-400",
          "focus:outline-none focus:ring-0",
          "transition-all duration-200 ease-out",
          "sm:text-sm sm:leading-6",
          "shadow-sm focus:shadow-lg focus:shadow-emerald-500/10",
          "focus:bg-white dark:focus:bg-slate-800",
          "appearance-none cursor-pointer bg-none",
          "bg-no-repeat bg-right",
          "[background-image:none]"
        ]}
        {@rest}
      >
        <option :for={{value, label} <- @options} value={value} selected={value == @value}>
          {label}
        </option>
      </select>

      <%!-- Custom dropdown arrow with liquid styling (matching main liquid_select) --%>
      <div class="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none z-20">
        <svg
          class="h-5 w-5 text-slate-400 dark:text-slate-500 group-focus-within:text-emerald-500 dark:group-focus-within:text-emerald-400 transition-colors duration-200"
          viewBox="0 0 20 20"
          fill="currentColor"
        >
          <path
            fill-rule="evenodd"
            d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z"
            clip-rule="evenodd"
          />
        </svg>
      </div>
    </div>
    """
  end

  @doc """
  Header component for circles page - minimal design focusing on content.
  """
  attr :class, :any, default: ""
  attr :id, :string, default: nil

  def liquid_circles_header(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "flex items-center gap-3 pb-2",
        @class
      ]}
    >
      <div class="flex items-center justify-center w-10 h-10 rounded-xl bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/30 dark:to-emerald-900/30 shadow-sm">
        <.phx_icon name="hero-circle-stack" class="w-5 h-5 text-teal-600 dark:text-teal-400" />
      </div>
      <div>
        <h1 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
          Circles
        </h1>
        <p class="text-sm text-slate-500 dark:text-slate-400">
          Your private groups
        </p>
      </div>
    </div>
    """
  end

  @doc """
  Header component for connections page - minimal design focusing on content.
  """
  attr :class, :any, default: ""
  attr :id, :string, default: nil

  def liquid_connections_header(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "flex items-center gap-3 pb-2",
        @class
      ]}
    >
      <div class="flex items-center justify-center w-10 h-10 rounded-xl bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/30 dark:to-emerald-900/30 shadow-sm">
        <.phx_icon name="hero-users" class="w-5 h-5 text-teal-600 dark:text-teal-400" />
      </div>
      <div>
        <h1 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
          Connections
        </h1>
        <p class="text-sm text-slate-500 dark:text-slate-400">
          Your trusted network
        </p>
      </div>
    </div>
    """
  end

  @doc """
  Search input component with liquid metal styling.
  """
  attr :placeholder, :string, default: "Search..."
  attr :value, :string, default: ""
  attr :class, :any, default: ""
  attr :phx_change, :string
  attr :id, :string
  attr :rest, :global, include: ~w(id name)

  def liquid_search_input(assigns) do
    ~H"""
    <.form id={@id} for={%{}} phx-change={@phx_change}>
      <div class={["relative", @class]}>
        <%!-- Liquid background effect --%>
        <div class="absolute inset-0 rounded-xl bg-gradient-to-r from-slate-100/80 via-white/60 to-slate-100/80 dark:from-slate-700/80 dark:via-slate-600/60 dark:to-slate-700/80 opacity-100 transition-opacity duration-200 ease-out focus-within:opacity-100">
        </div>

        <%!-- Search icon --%>
        <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none z-10">
          <.phx_icon name="hero-magnifying-glass" class="h-5 w-5 text-slate-400 dark:text-slate-500" />
        </div>

        <%!-- Input field --%>
        <input
          type="text"
          name="search_query"
          placeholder={@placeholder}
          phx-debounce={500}
          value={@value}
          class="relative z-10 block w-full pl-10 pr-4 py-3 text-sm text-slate-900 dark:text-slate-100 placeholder-slate-500 dark:placeholder-slate-400 bg-transparent border border-slate-200/60 dark:border-slate-600/60 rounded-xl shadow-sm focus:outline-none focus:ring-2 focus:ring-teal-500/50 focus:border-teal-500/50 dark:focus:ring-teal-400/50 dark:focus:border-teal-400/50 transition-all duration-200 ease-out"
          {@rest}
        />
      </div>
    </.form>
    """
  end

  @doc """
  Empty state component with liquid metal styling and semantic colors.
  """
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :action_label, :string, default: nil
  attr :action_navigate, :string, default: nil
  attr :action_patch, :string, default: nil
  attr :action_click, :string, default: nil
  attr :color, :string, default: "teal", values: ~w(teal emerald cyan purple indigo blue)
  attr :heading_level, :integer, default: 2, values: 1..6
  attr :class, :any, default: ""

  def liquid_empty_state(assigns) do
    ~H"""
    <div class={["text-center py-6 sm:py-8", @class]}>
      <div class={[
        "mx-auto w-12 h-12 sm:w-14 sm:h-14 rounded-xl border flex items-center justify-center mb-4 relative overflow-hidden group transition-all duration-300",
        get_empty_state_icon_styles(@color)
      ]}>
        <div class={[
          "absolute inset-0 translate-x-[-100%] group-hover:translate-x-[100%] transition-transform duration-1000 ease-out",
          get_empty_state_shimmer(@color)
        ]}>
        </div>

        <.phx_icon
          name={@icon}
          class={[
            "w-6 h-6 sm:w-7 sm:h-7 relative z-10 transition-transform duration-300 group-hover:scale-110",
            get_empty_state_icon_color(@color)
          ]}
        />
      </div>

      <div class="space-y-1.5 mb-4">
        <.dynamic_heading
          level={@heading_level}
          class={[
            "text-base sm:text-lg font-semibold",
            get_empty_state_title_color(@color)
          ]}
        >
          {@title}
        </.dynamic_heading>
        <p class={[
          "text-sm max-w-sm mx-auto leading-relaxed",
          get_empty_state_description_color(@color)
        ]}>
          {@description}
        </p>
      </div>

      <div :if={@action_label}>
        <.liquid_button
          navigate={@action_navigate}
          patch={@action_patch}
          phx-click={@action_click}
          icon="hero-plus"
          color={@color}
          size="sm"
          class="justify-center"
        >
          {@action_label}
        </.liquid_button>
      </div>
    </div>
    """
  end

  # Helper functions for semantic empty state styling
  defp get_empty_state_icon_styles(color) do
    case color do
      "teal" ->
        "bg-gradient-to-br from-teal-100/80 via-teal-50/60 to-teal-100/80 dark:from-teal-900/30 dark:via-teal-800/20 dark:to-teal-900/30 border-teal-200/40 dark:border-teal-700/40"

      "emerald" ->
        "bg-gradient-to-br from-emerald-100/80 via-emerald-50/60 to-emerald-100/80 dark:from-emerald-900/30 dark:via-emerald-800/20 dark:to-emerald-900/30 border-emerald-200/40 dark:border-emerald-700/40"

      "cyan" ->
        "bg-gradient-to-br from-cyan-100/80 via-cyan-50/60 to-cyan-100/80 dark:from-cyan-900/30 dark:via-cyan-800/20 dark:to-cyan-900/30 border-cyan-200/40 dark:border-cyan-700/40"

      "purple" ->
        "bg-gradient-to-br from-purple-100/80 via-purple-50/60 to-purple-100/80 dark:from-purple-900/30 dark:via-purple-800/20 dark:to-purple-900/30 border-purple-200/40 dark:border-purple-700/40"

      "indigo" ->
        "bg-gradient-to-br from-indigo-100/80 via-indigo-50/60 to-indigo-100/80 dark:from-indigo-900/30 dark:via-indigo-800/20 dark:to-indigo-900/30 border-indigo-200/40 dark:border-indigo-700/40"

      "blue" ->
        "bg-gradient-to-br from-blue-100/80 via-blue-50/60 to-blue-100/80 dark:from-blue-900/30 dark:via-blue-800/20 dark:to-blue-900/30 border-blue-200/40 dark:border-blue-700/40"

      _ ->
        "bg-gradient-to-br from-teal-100/80 via-teal-50/60 to-teal-100/80 dark:from-teal-900/30 dark:via-teal-800/20 dark:to-teal-900/30 border-teal-200/40 dark:border-teal-700/40"
    end
  end

  defp get_empty_state_shimmer(color) do
    case color do
      "teal" ->
        "bg-gradient-to-r from-transparent via-teal-200/30 dark:via-teal-400/20 to-transparent"

      "emerald" ->
        "bg-gradient-to-r from-transparent via-emerald-200/30 dark:via-emerald-400/20 to-transparent"

      "cyan" ->
        "bg-gradient-to-r from-transparent via-cyan-200/30 dark:via-cyan-400/20 to-transparent"

      "purple" ->
        "bg-gradient-to-r from-transparent via-purple-200/30 dark:via-purple-400/20 to-transparent"

      "indigo" ->
        "bg-gradient-to-r from-transparent via-indigo-200/30 dark:via-indigo-400/20 to-transparent"

      "blue" ->
        "bg-gradient-to-r from-transparent via-blue-200/30 dark:via-blue-400/20 to-transparent"

      _ ->
        "bg-gradient-to-r from-transparent via-teal-200/30 dark:via-teal-400/20 to-transparent"
    end
  end

  defp get_empty_state_icon_color(color) do
    case color do
      "teal" -> "text-teal-600 dark:text-teal-400"
      "emerald" -> "text-emerald-600 dark:text-emerald-400"
      "cyan" -> "text-cyan-600 dark:text-cyan-400"
      "purple" -> "text-purple-600 dark:text-purple-400"
      "indigo" -> "text-indigo-600 dark:text-indigo-400"
      "blue" -> "text-blue-600 dark:text-blue-400"
      _ -> "text-teal-600 dark:text-teal-400"
    end
  end

  defp get_empty_state_title_color(color) do
    case color do
      "teal" -> "text-teal-900 dark:text-teal-100"
      "emerald" -> "text-emerald-900 dark:text-emerald-100"
      "cyan" -> "text-cyan-900 dark:text-cyan-100"
      "purple" -> "text-purple-900 dark:text-purple-100"
      "indigo" -> "text-indigo-900 dark:text-indigo-100"
      "blue" -> "text-blue-900 dark:text-blue-100"
      _ -> "text-teal-900 dark:text-teal-100"
    end
  end

  defp get_empty_state_description_color(color) do
    case color do
      "teal" -> "text-teal-700 dark:text-teal-300"
      "emerald" -> "text-emerald-700 dark:text-emerald-300"
      "cyan" -> "text-cyan-700 dark:text-cyan-300"
      "purple" -> "text-purple-700 dark:text-purple-300"
      "indigo" -> "text-indigo-700 dark:text-indigo-300"
      "blue" -> "text-blue-700 dark:text-blue-300"
      _ -> "text-teal-700 dark:text-teal-300"
    end
  end

  @doc """
  Connection card component with liquid metal styling.
  Browser-side ZK decryption via DecryptConnectionCard hook when encrypted fields are provided.
  """
  attr :name, :string, default: "", doc: "Fallback for avatar alt text when not using ZK"
  attr :username, :string, default: "", doc: "Fallback when not using ZK"
  attr :label, :string, default: "", doc: "Fallback when not using ZK"
  attr :encrypted_name, :string, default: nil, doc: "ZK encrypted connection name"
  attr :encrypted_username, :string, default: nil, doc: "ZK encrypted connection username"
  attr :encrypted_label, :string, default: nil, doc: "ZK encrypted connection label"

  attr :sealed_uconn_key, :string,
    default: nil,
    doc: "ZK sealed connection key for browser unseal"

  attr :peer_user_id, :string,
    default: nil,
    doc: "Peer user id — the key the unified TOFU pin is stored under"

  attr :peer_public_key, :string,
    default: nil,
    doc: "Peer's X25519 public key (base64) for TOFU fingerprint compute"

  attr :peer_pq_public_key, :string,
    default: nil,
    doc: "Peer's ML-KEM public key (base64) for TOFU fingerprint compute"

  attr :sealed_peer_pin, :string,
    default: nil,
    doc: "Viewer-sealed TOFU pin of the peer fingerprint, or nil if not yet pinned"

  attr :key_history, :string,
    default: nil,
    doc:
      "Peer's serialized signed key-history chain (JSON array, #315), or nil — the monitor chain-validates it against the pinned root signing key"

  attr :color, :atom, required: true
  attr :avatar_src, :string, default: nil
  attr :encrypted_avatar_data, :map, default: nil, doc: "ZK encrypted avatar blob + sealed key"
  attr :connected_at, :any, required: true
  attr :connection_id, :string, required: true
  attr :zen?, :boolean, default: false
  attr :photos?, :boolean, default: false
  attr :show_interactions?, :boolean, default: true
  attr :show_profile?, :boolean, default: false
  attr :profile_slug, :string, default: nil, doc: "Plaintext profile slug for profile link"
  attr :status, :string, default: nil
  attr :status_message, :string, default: nil
  attr :encrypted_status_data, :map, default: nil, doc: "ZK encrypted status message + sealed key"
  attr :heading_level, :integer, default: 2, values: 1..6
  attr :class, :any, default: ""

  def liquid_connection_card(assigns) do
    ~H"""
    <div class="relative">
      <article class={[
        "group/card relative rounded-2xl overflow-hidden transition-all duration-300 ease-out",
        "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
        "border border-slate-200/60 dark:border-slate-700/60",
        "shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20",
        "hover:shadow-xl hover:shadow-slate-900/10 dark:hover:shadow-slate-900/30",
        "hover:border-slate-300/60 dark:hover:border-slate-600/60",
        "transform-gpu hover:will-change-transform cursor-pointer",
        @class
      ]}>
        <%!-- DecryptConnectionCard hook for browser-side ZK decryption --%>
        <div
          :if={@sealed_uconn_key}
          id={"decrypt-conn-card-#{@connection_id}"}
          phx-hook="DecryptConnectionCard"
          data-sealed-uconn-key={@sealed_uconn_key}
          data-encrypted-conn-name={@encrypted_name}
          data-encrypted-conn-username={@encrypted_username}
          data-encrypted-conn-label={@encrypted_label}
          data-peer-user-id={@peer_user_id}
          data-peer-public-key={@peer_public_key}
          data-peer-pq-public-key={@peer_pq_public_key}
          data-sealed-peer-pin={@sealed_peer_pin}
          data-key-history={@key_history}
          class="hidden"
        >
        </div>

        <%!-- Liquid background effect on hover --%>
        <div class="absolute inset-0 opacity-0 transition-all duration-500 ease-out group-hover/card:opacity-100 bg-gradient-to-br from-teal-50/20 via-emerald-50/10 to-cyan-50/20 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10">
        </div>

        <%!-- Shimmer effect --%>
        <div class="absolute inset-0 opacity-0 transition-all duration-700 ease-out group-hover/card:opacity-100 bg-gradient-to-r from-transparent via-emerald-200/20 dark:via-emerald-400/10 to-transparent group-hover/card:translate-x-full -translate-x-full">
        </div>

        <%!-- Card content --%>
        <div class="relative p-6">
          <%!-- Header with avatar and name --%>
          <div class="flex items-start gap-4 mb-4">
            <%!-- Avatar --%>
            <div class="relative flex-shrink-0">
              <.liquid_avatar
                id={"liquid-avatar-#{@connection_id}"}
                src={@avatar_src}
                encrypted_avatar_data={@encrypted_avatar_data}
                name={@name}
                size="lg"
                status={@status}
                status_message={@status_message}
                encrypted_status_data={@encrypted_status_data}
                clickable={true}
              />

              <%!-- Status indicator now handled by liquid_avatar component --%>
            </div>

            <%!-- User info --%>
            <div class="flex-1 min-w-0">
              <div class="flex items-start justify-between gap-2">
                <div class="min-w-0 flex-1">
                  <.dynamic_heading
                    level={@heading_level}
                    class="text-lg font-semibold text-slate-900 dark:text-slate-100 truncate group-hover:text-teal-700 dark:group-hover:text-teal-300 transition-colors duration-200"
                  >
                    <span
                      id={"conn-name-#{@connection_id}"}
                      phx-update={if @sealed_uconn_key, do: "ignore"}
                      data-decrypt-conn-name
                    >
                      {if @sealed_uconn_key, do: "", else: @name}
                    </span>
                  </.dynamic_heading>
                  <div class="flex items-center gap-1">
                    <p class="text-sm text-slate-600 dark:text-slate-400 truncate min-w-0">
                      @<span
                        id={"conn-username-#{@connection_id}"}
                        phx-update={if @sealed_uconn_key, do: "ignore"}
                        data-decrypt-conn-username
                      >{if @sealed_uconn_key, do: "", else: @username}</span>
                    </p>
                    <%!-- Verified key badge (#295) — toggled client-side by DecryptConnectionCard --%>
                    <span
                      :if={@peer_user_id}
                      id={"conn-verified-#{@connection_id}"}
                      data-conn-verified-badge={@peer_user_id}
                      hidden
                      class="shrink-0 inline-flex items-center text-emerald-600 dark:text-emerald-400"
                      data-tippy-content="Encryption key verified"
                      phx-hook="TippyHook"
                    >
                      <.phx_icon name="hero-check-badge" class="h-4 w-4" />
                    </span>
                    <%!-- Key-changed badge (#296) — toggled client-side on a TOFU
                         mismatch. Mutually exclusive with the verified badge. --%>
                    <span
                      :if={@peer_user_id}
                      id={"conn-keychanged-#{@connection_id}"}
                      data-conn-keychanged-badge={@peer_user_id}
                      hidden
                      class="shrink-0 inline-flex items-center text-amber-600 dark:text-amber-400"
                      data-tippy-content="Encryption key changed — re-verify this contact"
                      phx-hook="TippyHook"
                    >
                      <.phx_icon name="hero-exclamation-triangle" class="h-4 w-4" />
                    </span>
                  </div>

                  <%!-- Connection indicators (similar to timeline post indicators) --%>
                  <div :if={@zen? || @photos?} class="flex items-center gap-1 mt-1">
                    <%!-- Muted indicator --%>
                    <.phx_icon
                      :if={@zen?}
                      id={"zen-muted-#{@connection_id}"}
                      name="hero-speaker-x-mark"
                      class="h-3 w-3 text-amber-500 dark:text-amber-400"
                      phx_hook="TippyHook"
                      data_tippy_content="Muted"
                    />

                    <%!-- Photos enabled indicator --%>
                    <.phx_icon
                      :if={@photos?}
                      id={"photos-enabled-#{@connection_id}"}
                      name="hero-photo"
                      class="h-3 w-3 text-emerald-500 dark:text-emerald-400"
                      phx_hook="TippyHook"
                      data_tippy_content="Photo downloads enabled"
                    />
                  </div>
                </div>

                <%!-- Connection label badge --%>
                <.liquid_badge
                  variant="soft"
                  color={connection_badge_color(@color)}
                  size="sm"
                >
                  <span
                    id={"conn-label-#{@connection_id}"}
                    phx-update={if @sealed_uconn_key, do: "ignore"}
                    data-decrypt-conn-label
                  >
                    {if @sealed_uconn_key, do: "", else: @label}
                  </span>
                </.liquid_badge>
              </div>

              <%!-- Status or last activity --%>
              <p class="text-xs text-slate-500 dark:text-slate-400 mt-2">
                Connected <.local_time_ago id={@connection_id} at={@connected_at} />
              </p>
            </div>
          </div>

          <%!-- Quick actions --%>
          <div class="flex items-center justify-between pt-4 border-t border-slate-200/60 dark:border-slate-600/60">
            <%!-- Action buttons --%>
            <div :if={@show_interactions?} class="flex items-center gap-2">
              <.link
                id={"message-button-#{@connection_id}"}
                phx-hook="TippyHook"
                data-tippy-content="Send encrypted message"
                phx-click="start_conversation"
                phx-value-connection-id={@connection_id}
                class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-teal-600 dark:text-teal-400 bg-teal-50/50 dark:bg-teal-900/20 hover:bg-teal-100/50 dark:hover:bg-teal-900/30 border border-teal-200/40 dark:border-teal-700/40 rounded-full transition-all duration-200 ease-out hover:scale-105 cursor-pointer"
              >
                <.phx_icon name="hero-chat-bubble-left" class="h-3.5 w-3.5" /> Message
              </.link>

              <%!-- View profile button --%>

              <.link
                :if={@show_profile? && @profile_slug}
                id={"profile-button-#{@connection_id}"}
                phx-hook="TippyHook"
                navigate={~p"/app/profile/#{@profile_slug}"}
                data-tippy-content="View profile"
                type="button"
                class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-slate-600 dark:text-slate-400 bg-slate-50/50 dark:bg-slate-700/20 hover:bg-slate-100/50 dark:hover:bg-slate-600/30 border border-slate-200/40 dark:border-slate-600/40 rounded-full transition-all duration-200 ease-out hover:scale-105"
              >
                <.phx_icon name="hero-user" class="h-3.5 w-3.5" /> Profile
              </.link>
            </div>

            <%!-- Placeholder when interactions are hidden (to maintain layout) --%>
            <div :if={!@show_interactions?} class="flex items-center gap-2">
              <div class="text-xs text-slate-400 dark:text-slate-500 italic">
                Profile not available
              </div>
            </div>

            <%!-- Dropdown trigger only (menu will be positioned outside) --%>
            <button
              type="button"
              phx-click={JS.toggle(to: "#connection-menu-#{@connection_id}-menu")}
              class="p-1.5 text-slate-400 dark:text-slate-500 hover:text-slate-600 dark:hover:text-slate-400 rounded-full hover:bg-slate-100/50 dark:hover:bg-slate-700/30 transition-all duration-200 ease-out"
              title="More options"
            >
              <.phx_icon
                name="hero-ellipsis-horizontal"
                class="h-4 w-4"
              />
            </button>
          </div>
        </div>
      </article>

      <%!-- Dropdown menu positioned outside the card to avoid clipping --%>
      <div
        id={"connection-menu-#{@connection_id}-menu"}
        class="absolute z-[200] mt-2 w-48 origin-top-right hidden right-0 top-full rounded-xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-xl shadow-slate-900/10 dark:shadow-slate-900/30 transition-all duration-200 ease-out ring-1 ring-slate-200/60 dark:ring-slate-700/60"
        role="menu"
        aria-orientation="vertical"
        phx-click-away={JS.hide(to: "#connection-menu-#{@connection_id}-menu")}
      >
        <%!-- Liquid background effect --%>
        <div class="absolute inset-0 rounded-xl bg-gradient-to-br from-teal-50/20 via-emerald-50/10 to-cyan-50/20 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10 opacity-50">
        </div>

        <div class="relative py-2">
          <div
            :if={@peer_user_id}
            class="group flex items-center gap-3 px-4 py-2.5 text-sm transition-all duration-200 ease-out cursor-pointer hover:bg-slate-100/80 dark:hover:bg-slate-700/80 first:rounded-t-lg last:rounded-b-lg text-slate-700 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100"
            role="menuitem"
            phx-click={
              JS.hide(to: "#connection-menu-#{@connection_id}-menu")
              |> phx_show_modal("verify-connection-modal-#{@connection_id}")
              |> JS.dispatch("verification:open", to: "#kv-panel-#{@connection_id}")
            }
          >
            <.phx_icon name="hero-finger-print" class="h-4 w-4" /> Verify Contact
          </div>

          <div
            class="group flex items-center gap-3 px-4 py-2.5 text-sm transition-all duration-200 ease-out cursor-pointer hover:bg-slate-100/80 dark:hover:bg-slate-700/80 first:rounded-t-lg last:rounded-b-lg text-slate-700 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100"
            role="menuitem"
            phx-click="edit_connection"
            phx-value-id={@connection_id}
          >
            <.phx_icon name="hero-pencil" class="h-4 w-4" /> Edit Label
          </div>

          <div
            class="group flex items-center gap-3 px-4 py-2.5 text-sm transition-all duration-200 ease-out cursor-pointer hover:bg-slate-100/80 dark:hover:bg-slate-700/80 first:rounded-t-lg last:rounded-b-lg text-slate-700 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100"
            role="menuitem"
            phx-click="toggle_mute"
            phx-value-id={@connection_id}
            id={"toggle-mute-button-#{@connection_id}"}
          >
            <.phx_icon
              name={if @zen?, do: "hero-speaker-wave", else: "hero-speaker-x-mark"}
              class="h-4 w-4"
            />
            {if @zen?, do: "Unmute", else: "Mute"}
          </div>

          <div
            class="group flex items-center gap-3 px-4 py-2.5 text-sm transition-all duration-200 ease-out cursor-pointer hover:bg-slate-100/80 dark:hover:bg-slate-700/80 first:rounded-t-lg last:rounded-b-lg text-slate-700 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100"
            role="menuitem"
            phx-click="toggle_photos"
            phx-value-id={@connection_id}
          >
            <.phx_icon name={if @photos?, do: "hero-photo-solid", else: "hero-photo"} class="h-4 w-4" />
            {if @photos?, do: "Disable Photo Downloads", else: "Enable Photo Downloads"}
          </div>

          <div
            class="group flex items-center gap-3 px-4 py-2.5 text-sm transition-all duration-200 ease-out cursor-pointer hover:bg-slate-100/80 dark:hover:bg-slate-700/80 first:rounded-t-lg last:rounded-b-lg text-amber-700 dark:text-amber-300 hover:text-amber-900 dark:hover:text-amber-100"
            role="menuitem"
            phx-click="block_user"
            phx-value-id={@connection_id}
            phx-value-name={@name}
          >
            <.phx_icon name="hero-no-symbol" class="h-4 w-4" /> Block Author
          </div>

          <div
            class="group flex items-center gap-3 px-4 py-2.5 text-sm transition-all duration-200 ease-out cursor-pointer hover:bg-slate-100/80 dark:hover:bg-slate-700/80 first:rounded-t-lg last:rounded-b-lg text-red-700 dark:text-red-300 hover:text-red-900 dark:hover:text-red-100"
            role="menuitem"
            phx-click="delete_connection"
            phx-value-id={@connection_id}
            data-confirm="Are you sure you want to delete this connection? This action cannot be undone."
          >
            <.phx_icon name="hero-trash" class="h-4 w-4" /> Delete Connection
          </div>
        </div>
      </div>

      <%!-- Key-verification modal (#302). Lazy panel computes only when opened,
           so a page of cards doesn't run N fingerprint computations on load. --%>
      <.phx_modal
        :if={@peer_user_id}
        id={"verify-connection-modal-#{@connection_id}"}
        on_cancel={JS.dispatch("verification:close", to: "#kv-panel-#{@connection_id}")}
      >
        <div class="w-[20rem] sm:w-[34rem] max-w-full pt-3 pr-10">
          <.key_verification_panel
            id={"kv-panel-#{@connection_id}"}
            peer_user_id={@peer_user_id}
            peer_public_key={@peer_public_key}
            peer_pq_public_key={@peer_pq_public_key}
            sealed_peer_pin={@sealed_peer_pin}
            lazy={true}
            flat={true}
          />
        </div>
      </.phx_modal>
    </div>
    """
  end

  @doc """
  Arrivals section for pending connection requests.
  Expects decrypted arrival data from the LiveView.
  """
  attr :arrivals, :list, required: true
  attr :arrivals_count, :integer, required: true
  attr :class, :any, default: ""

  def liquid_arrivals_section(assigns) do
    ~H"""
    <div class={["space-y-6", @class]}>
      <%!-- Section header --%>
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <div class="p-2 rounded-xl bg-gradient-to-br from-emerald-100 via-emerald-50 to-emerald-100 dark:from-emerald-900/30 dark:via-emerald-800/20 dark:to-emerald-900/30 border border-emerald-200/40 dark:border-emerald-700/40">
            <.phx_icon
              name="hero-inbox-arrow-down"
              class="h-5 w-5 text-emerald-600 dark:text-emerald-400"
            />
          </div>
          <div>
            <h2 class="text-xl font-semibold text-slate-900 dark:text-slate-100">
              Pending Connections
            </h2>
            <p class="text-sm text-slate-600 dark:text-slate-400">
              {@arrivals_count} people want to connect with you
            </p>
          </div>
        </div>
      </div>

      <%!-- Arrivals list --%>
      <div class="space-y-4">
        <%!-- Empty state for arrivals --%>
        <div :if={Enum.empty?(@arrivals)} class="text-center py-8">
          <div class="mx-auto w-12 h-12 rounded-full bg-emerald-100 dark:bg-emerald-900/30 flex items-center justify-center mb-4">
            <.phx_icon name="hero-check" class="w-6 h-6 text-emerald-600 dark:text-emerald-400" />
          </div>
          <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100 mb-2">
            All caught up!
          </h3>
          <p class="text-slate-600 dark:text-slate-300">
            You have no pending connection requests.
          </p>
        </div>

        <%!-- Arrival cards --%>
        <div :for={arrival <- @arrivals} class="arrival-card-container">
          <.liquid_arrival_card
            name={arrival.name}
            email={arrival.email}
            label={arrival.label}
            color={arrival.color}
            avatar_src={arrival.avatar_src}
            requested_at={arrival.requested_at}
            arrival_id={arrival.id}
            class="transition-all duration-300"
          />
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Individual arrival card for connection requests.
  Browser-side ZK decryption via DecryptConnectionCard hook when encrypted fields are provided.
  """
  attr :name, :string, default: "", doc: "Fallback for avatar alt text when not using ZK"
  attr :email, :string, default: "", doc: "Fallback when not using ZK"
  attr :label, :string, default: "", doc: "Fallback when not using ZK"
  attr :encrypted_name, :string, default: nil, doc: "ZK encrypted arrival request_username"
  attr :encrypted_email, :string, default: nil, doc: "ZK encrypted arrival request_email"
  attr :encrypted_label, :string, default: nil, doc: "ZK encrypted arrival label"

  attr :sealed_uconn_key, :string,
    default: nil,
    doc: "ZK sealed connection key for browser unseal"

  attr :color, :atom, required: true
  attr :avatar_src, :string, default: nil
  attr :encrypted_avatar_data, :map, default: nil, doc: "ZK encrypted avatar blob + sealed key"
  attr :requested_at, :any, required: true
  attr :arrival_id, :string, required: true
  attr :status, :string, default: nil
  attr :status_message, :string, default: nil
  attr :encrypted_status_data, :map, default: nil, doc: "ZK encrypted status message + sealed key"
  attr :heading_level, :integer, default: 2, values: 1..6
  attr :class, :any, default: ""

  def liquid_arrival_card(assigns) do
    ~H"""
    <article class={[
      "group relative rounded-2xl overflow-hidden transition-all duration-300 ease-out",
      "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
      "border border-slate-200/60 dark:border-slate-700/60",
      "shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20",
      "hover:shadow-xl hover:shadow-slate-900/10 dark:hover:shadow-slate-900/30",
      "hover:border-slate-300/60 dark:hover:border-slate-600/60",
      @class
    ]}>
      <%!-- DecryptConnectionCard hook for browser-side ZK decryption --%>
      <div
        :if={@sealed_uconn_key}
        id={"decrypt-arrival-card-#{@arrival_id}"}
        phx-hook="DecryptConnectionCard"
        data-sealed-uconn-key={@sealed_uconn_key}
        data-encrypted-arrival-name={@encrypted_name}
        data-encrypted-arrival-email={@encrypted_email}
        data-encrypted-arrival-label={@encrypted_label}
        class="hidden"
      >
      </div>

      <%!-- Enhanced liquid background with emerald/teal gradient --%>
      <div class="absolute inset-0 opacity-0 transition-all duration-500 ease-out group-hover:opacity-100 bg-gradient-to-br from-emerald-50/20 via-teal-50/10 to-emerald-50/20 dark:from-emerald-900/10 dark:via-teal-900/5 dark:to-emerald-900/10">
      </div>

      <%!-- Shimmer effect for enhanced interaction feedback --%>
      <div class="absolute inset-0 opacity-0 transition-all duration-700 ease-out group-hover:opacity-100 bg-gradient-to-r from-transparent via-emerald-200/20 dark:via-emerald-400/10 to-transparent group-hover:translate-x-full -translate-x-full">
      </div>

      <%!-- Card content with enhanced responsive padding and spacing --%>
      <div class="relative p-5 sm:p-7 lg:p-8">
        <%!-- Enhanced mobile-first layout with better spacing --%>
        <div class="flex flex-col gap-5 sm:gap-6 lg:flex-row lg:items-center lg:justify-between lg:gap-8">
          <%!-- User info section with refined mobile layout --%>
          <div class="flex items-start gap-4 sm:gap-5 flex-1 min-w-0">
            <%!-- Avatar with better mobile sizing --%>
            <div class="flex-shrink-0">
              <.liquid_avatar
                id={"liquid-avatar-#{@arrival_id}"}
                src={@avatar_src}
                encrypted_avatar_data={@encrypted_avatar_data}
                name={@name}
                size="lg"
                clickable={false}
                status={@status}
                status_message={@status_message}
                encrypted_status_data={@encrypted_status_data}
              />
            </div>

            <%!-- User details with enhanced typography hierarchy --%>
            <div class="flex-1 min-w-0">
              <%!-- Name and badge row with improved spacing --%>
              <div class="flex items-start justify-between gap-3 mb-3">
                <div class="min-w-0 flex-1">
                  <.dynamic_heading
                    level={@heading_level}
                    class="text-xl sm:text-2xl font-bold text-slate-900 dark:text-slate-100 truncate group-hover:text-emerald-700 dark:group-hover:text-emerald-300 transition-colors duration-200 leading-tight"
                  >
                    <span
                      id={"arrival-name-#{@arrival_id}"}
                      phx-update={if @sealed_uconn_key, do: "ignore"}
                      data-decrypt-arrival-name
                    >
                      {if @sealed_uconn_key, do: "", else: @name}
                    </span>
                  </.dynamic_heading>
                </div>

                <%!-- Badge with enhanced visual weight --%>
                <div class="flex-shrink-0">
                  <.liquid_badge
                    variant="soft"
                    color={connection_badge_color(@color)}
                    size="md"
                  >
                    <span
                      id={"arrival-label-#{@arrival_id}"}
                      phx-update={if @sealed_uconn_key, do: "ignore"}
                      data-decrypt-arrival-label
                    >
                      {if @sealed_uconn_key, do: "", else: @label}
                    </span>
                  </.liquid_badge>
                </div>
              </div>

              <%!-- Email with improved secondary hierarchy --%>
              <p class="text-base sm:text-lg text-slate-600 dark:text-slate-400 truncate mb-3 font-medium">
                <span
                  id={"arrival-email-#{@arrival_id}"}
                  phx-update={if @sealed_uconn_key, do: "ignore"}
                  data-decrypt-arrival-email
                >
                  {if @sealed_uconn_key, do: "", else: @email}
                </span>
              </p>

              <%!-- Timestamp with enhanced visual treatment --%>
              <div class="flex items-center gap-2 text-sm sm:text-base text-slate-500 dark:text-slate-400">
                <div class="flex items-center justify-center w-5 h-5 rounded-full bg-emerald-100 dark:bg-emerald-900/30">
                  <.phx_icon name="hero-clock" class="h-3 w-3 text-emerald-600 dark:text-emerald-400" />
                </div>
                <span class="font-medium">
                  Requested <.local_time_ago id={@arrival_id} at={@requested_at} />
                </span>
              </div>
            </div>
          </div>

          <%!-- Enhanced action buttons with clear visual hierarchy --%>
          <div class="flex flex-col sm:flex-row items-stretch sm:items-center gap-3 sm:gap-4 flex-shrink-0 min-w-0 sm:min-w-[180px]">
            <%!-- Primary Accept button with enhanced prominence --%>
            <.liquid_button
              size="md"
              color="emerald"
              icon="hero-check"
              phx-click="accept_uconn"
              phx-value-id={@arrival_id}
              shimmer="card"
              class="flex-1 sm:flex-initial min-h-[48px] justify-center order-1 font-semibold shadow-lg shadow-emerald-500/25 dark:shadow-emerald-400/20 hover:shadow-xl hover:shadow-emerald-500/30 dark:hover:shadow-emerald-400/25 transform transition-all duration-200 hover:scale-105"
            >
              <span class="sm:hidden">Accept</span>
              <span class="hidden sm:inline">Accept Request</span>
            </.liquid_button>

            <%!-- Secondary Decline button with subtle styling --%>
            <.liquid_button
              size="md"
              variant="secondary"
              color="slate"
              icon="hero-x-mark"
              phx-click="decline_uconn"
              phx-value-id={@arrival_id}
              data-confirm="Are you sure you wish to decline this connection request?"
              class="flex-1 sm:flex-initial min-h-[48px] justify-center order-2 font-medium hover:bg-rose-50 dark:hover:bg-rose-900/20 hover:text-rose-600 dark:hover:text-rose-400 hover:border-rose-200 dark:hover:border-rose-700 transition-all duration-200"
            >
              <span class="sm:hidden">Decline</span>
              <span class="hidden sm:inline">Decline</span>
            </.liquid_button>
          </div>
        </div>
      </div>
    </article>
    """
  end

  @doc """
  Tab navigation component for connections page with fixed responsive behavior.
  """
  attr :tabs, :list, required: true
  attr :active_tab, :string, required: true
  attr :class, :any, default: ""

  def liquid_connections_tabs(assigns) do
    ~H"""
    <div class={["flex items-center gap-2 md:gap-3", @class]}>
      <div :for={tab <- @tabs} class="relative overflow-visible">
        <button
          type="button"
          phx-click="switch_tab"
          phx-value-tab={tab.key}
          class={[
            "group relative flex items-center justify-center gap-2 px-4 py-3 md:px-5 md:py-3 xl:px-6 xl:py-3.5 rounded-xl text-sm md:text-base font-medium transition-all duration-200 ease-out overflow-visible backdrop-blur-sm min-h-[44px] whitespace-nowrap",
            get_tab_styles(@active_tab, tab)
          ]}
        >
          <%!-- Enhanced liquid background for active tab with semantic colors --%>
          <div
            :if={@active_tab == tab.key}
            class={[
              "absolute inset-0 transition-all duration-300 ease-out",
              get_tab_background(tab)
            ]}
          >
          </div>

          <%!-- Tab icon with consistent sizing --%>
          <div class="relative z-10">
            <.phx_icon name={tab.icon} class="h-4 w-4 md:h-5 md:w-5" />
          </div>

          <%!-- Tab label only (removing count badge to match timeline pattern) --%>
          <div class="relative z-10 flex items-center gap-2">
            <span class="font-medium">{tab.label}</span>
          </div>

          <%!-- Enhanced unread badge indicator with count (following timeline pattern) --%>
          <span
            :if={Map.get(tab, :unread, 0) > 0}
            class={[
              "absolute -top-1 -right-1 z-20",
              "flex items-center justify-center",
              "min-w-[1.25rem] h-5 px-1.5 text-xs font-bold rounded-full",
              "bg-gradient-to-r from-teal-400 to-cyan-400 text-white",
              "shadow-lg shadow-teal-500/50 dark:shadow-cyan-400/40",
              "ring-2 ring-white dark:ring-slate-800",
              "animate-pulse"
            ]}
          >
            {Map.get(tab, :unread, 0)}
          </span>
        </button>
      </div>
    </div>
    """
  end

  # Helper functions for semantic tab styling
  defp get_tab_styles(active_tab, tab) when active_tab == tab.key do
    case Map.get(tab, :color, "teal") do
      "teal" ->
        "bg-gradient-to-r from-teal-100 via-emerald-50 to-teal-100 dark:from-teal-900/40 dark:via-emerald-900/30 dark:to-teal-900/40 text-teal-700 dark:text-teal-300 border border-teal-200/60 dark:border-teal-700/60 shadow-sm shadow-teal-500/20"

      "emerald" ->
        "bg-gradient-to-r from-emerald-100 via-teal-50 to-emerald-100 dark:from-emerald-900/40 dark:via-teal-900/30 dark:to-emerald-900/40 text-emerald-700 dark:text-emerald-300 border border-emerald-200/60 dark:border-emerald-700/60 shadow-sm shadow-emerald-500/20"

      "purple" ->
        "bg-gradient-to-r from-purple-100 via-indigo-50 to-purple-100 dark:from-purple-900/40 dark:via-indigo-900/30 dark:to-purple-900/40 text-purple-700 dark:text-purple-300 border border-purple-200/60 dark:border-purple-700/60 shadow-sm shadow-purple-500/20"

      _ ->
        "bg-gradient-to-r from-teal-100 via-emerald-50 to-teal-100 dark:from-teal-900/40 dark:via-emerald-900/30 dark:to-teal-900/40 text-teal-700 dark:text-teal-300 border border-teal-200/60 dark:border-teal-700/60 shadow-sm shadow-teal-500/20"
    end
  end

  defp get_tab_styles(_active_tab, _tab) do
    "text-slate-600 dark:text-slate-400 hover:text-teal-600 dark:hover:text-teal-400 hover:bg-slate-100/50 dark:hover:bg-slate-700/30 border border-transparent"
  end

  defp get_tab_background(tab) do
    case Map.get(tab, :color, "teal") do
      "teal" ->
        "bg-gradient-to-r from-teal-50/60 via-emerald-50/40 to-teal-50/60 dark:from-teal-900/20 dark:via-emerald-900/15 dark:to-teal-900/20"

      "emerald" ->
        "bg-gradient-to-r from-emerald-50/60 via-teal-50/40 to-emerald-50/60 dark:from-emerald-900/20 dark:via-teal-900/15 dark:to-emerald-900/20"

      "purple" ->
        "bg-gradient-to-r from-purple-50/60 via-indigo-50/40 to-purple-50/60 dark:from-purple-900/20 dark:via-indigo-900/15 dark:to-purple-900/20"

      _ ->
        "bg-gradient-to-r from-teal-50/60 via-emerald-50/40 to-teal-50/60 dark:from-teal-900/20 dark:via-emerald-900/15 dark:to-teal-900/20"
    end
  end

  # Helper functions for connection-related styling
  def connection_badge_color(:emerald), do: "emerald"
  def connection_badge_color(:orange), do: "orange"
  def connection_badge_color(:amber), do: "amber"
  def connection_badge_color(:pink), do: "rose"
  def connection_badge_color(:purple), do: "purple"
  def connection_badge_color(:rose), do: "rose"
  def connection_badge_color(:yellow), do: "amber"
  def connection_badge_color(:zinc), do: "slate"
  def connection_badge_color(:cyan), do: "cyan"
  def connection_badge_color(:indigo), do: "indigo"
  def connection_badge_color(:teal), do: "teal"
  def connection_badge_color(_), do: "purple"

  def connection_username_color_classes(:emerald),
    do: "text-emerald-600/80 dark:text-emerald-400/70"

  def connection_username_color_classes(:orange),
    do: "text-orange-600/80 dark:text-orange-400/70"

  def connection_username_color_classes(:amber), do: "text-amber-600/80 dark:text-amber-400/70"
  def connection_username_color_classes(:pink), do: "text-rose-600/80 dark:text-rose-400/70"
  def connection_username_color_classes(:purple), do: "text-purple-600/80 dark:text-purple-400/70"
  def connection_username_color_classes(:rose), do: "text-rose-600/80 dark:text-rose-400/70"
  def connection_username_color_classes(:yellow), do: "text-amber-600/80 dark:text-amber-400/70"
  def connection_username_color_classes(:zinc), do: "text-slate-600/80 dark:text-slate-400/70"
  def connection_username_color_classes(:cyan), do: "text-cyan-600/80 dark:text-cyan-400/70"
  def connection_username_color_classes(:indigo), do: "text-indigo-600/80 dark:text-indigo-400/70"
  def connection_username_color_classes(:teal), do: "text-teal-600/80 dark:text-teal-400/70"
  def connection_username_color_classes(_), do: "text-purple-600/80 dark:text-purple-400/70"

  # Helper functions for decrypting connection data (using pattern matching)

  def get_connection_avatar_src(_connection, _current_user, _key) do
    # Legacy function — avatar display now uses get_encrypted_avatar_data + DecryptAvatar hook.
    # Returns logo fallback; callers should migrate to encrypted_avatar_data attr.
    "/images/logo.svg"
  end

  def get_decrypted_connection_name(connection, current_user, key) do
    case decr_uconn(connection.connection.name, current_user, connection.key, key) do
      result when is_binary(result) -> result
      _ -> "[Encrypted]"
    end
  end

  def get_decrypted_connection_username(connection, current_user, key) do
    case decr_uconn(connection.connection.username, current_user, connection.key, key) do
      result when is_binary(result) -> result
      _ -> "[encrypted]"
    end
  end

  def get_decrypted_connection_label(connection, current_user, key) do
    case decr_uconn(connection.label, current_user, connection.key, key) do
      result when is_binary(result) -> result
      _ -> "[Encrypted]"
    end
  end

  # Helper functions for visibility groups with liquid metal design consistency

  def get_decrypted_group_name(group_data, current_user, key) do
    group =
      case group_data do
        %{group: g} -> g
        g -> g
      end

    case decr(group.name, current_user, key) do
      result when is_binary(result) -> result
      _ -> "[Encrypted Group]"
    end
  end

  def get_decrypted_group_description(group_data, current_user, key) do
    group =
      case group_data do
        %{group: g} -> g
        g -> g
      end

    case decr(group.description, current_user, key) do
      result when is_binary(result) -> result
      _ -> ""
    end
  end

  def get_connection_other_user_id(connection, current_user) do
    if connection.user_id == current_user.id do
      connection.reverse_user_id
    else
      connection.user_id
    end
  end

  def get_post_shared_user_classes(color) do
    case color do
      :emerald ->
        "from-emerald-100 to-emerald-200 dark:from-emerald-900/30 dark:to-emerald-800/30"

      :teal ->
        "from-teal-100 to-teal-200 dark:from-teal-900/30 dark:to-teal-800/30"

      :orange ->
        "from-orange-100 to-orange-200 dark:from-orange-900/30 dark:to-orange-800/30"

      :purple ->
        "from-purple-100 to-purple-200 dark:from-purple-900/30 dark:to-purple-800/30"

      :rose ->
        "from-rose-100 to-rose-200 dark:from-rose-900/30 dark:to-rose-800/30"

      :amber ->
        "from-amber-100 to-amber-200 dark:from-amber-900/30 dark:to-amber-800/30"

      :yellow ->
        "from-yellow-100 to-yellow-200 dark:from-yellow-900/30 dark:to-yellow-800/30"

      :cyan ->
        "from-cyan-100 to-cyan-200 dark:from-cyan-900/30 dark:to-cyan-800/30"

      :indigo ->
        "from-indigo-100 to-indigo-200 dark:from-indigo-900/30 dark:to-indigo-800/30"

      :pink ->
        "from-pink-100 to-pink-200 dark:from-pink-900/30 dark:to-pink-800/30"

      _ ->
        "from-slate-100 to-slate-200 dark:from-slate-700 dark:to-slate-600"
    end
  end

  def get_post_shared_user_text_classes(color) do
    case color do
      :emerald -> "text-emerald-600 dark:text-emerald-400"
      :teal -> "text-teal-600 dark:text-teal-400"
      :orange -> "text-orange-600 dark:text-orange-400"
      :purple -> "text-purple-600 dark:text-purple-400"
      :rose -> "text-rose-600 dark:text-rose-400"
      :amber -> "text-amber-600 dark:text-amber-400"
      :yellow -> "text-yellow-600 dark:text-yellow-400"
      :cyan -> "text-cyan-600 dark:text-cyan-400"
      :indigo -> "text-indigo-600 dark:text-indigo-400"
      :pink -> "text-pink-600 dark:text-pink-400"
      _ -> "text-slate-600 dark:text-slate-400"
    end
  end

  def get_connection_color_badge_classes(color) do
    case color do
      :teal ->
        "bg-teal-100/80 dark:bg-teal-900/30 text-teal-700 dark:text-teal-300"

      :emerald ->
        "bg-emerald-100/80 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-300"

      :cyan ->
        "bg-cyan-100/80 dark:bg-cyan-900/30 text-cyan-700 dark:text-cyan-300"

      :purple ->
        "bg-purple-100/80 dark:bg-purple-900/30 text-purple-700 dark:text-purple-300"

      :pink ->
        "bg-pink-100/80 dark:bg-pink-900/30 text-pink-700 dark:text-pink-300"

      :rose ->
        "bg-rose-100/80 dark:bg-rose-900/30 text-rose-700 dark:text-rose-300"

      :amber ->
        "bg-amber-100/80 dark:bg-amber-900/30 text-amber-700 dark:text-amber-300"

      :yellow ->
        "bg-yellow-100/80 dark:bg-yellow-900/30 text-yellow-700 dark:text-yellow-300"

      :orange ->
        "bg-orange-100/80 dark:bg-orange-900/30 text-orange-700 dark:text-orange-300"

      :indigo ->
        "bg-indigo-100/80 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300"

      _ ->
        "bg-slate-100/80 dark:bg-slate-900/30 text-slate-700 dark:text-slate-300"
    end
  end

  # Card background and border classes following the liquid metal aesthetic
  def get_group_card_classes(color) do
    base_classes = "bg-white/95 dark:bg-slate-800/95"

    case color do
      :teal ->
        "#{base_classes} border-teal-200/40 dark:border-teal-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-teal-300/60 dark:hover:border-teal-600/60 hover:shadow-teal-500/10"

      :emerald ->
        "#{base_classes} border-emerald-200/40 dark:border-emerald-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-emerald-300/60 dark:hover:border-emerald-600/60 hover:shadow-emerald-500/10"

      :cyan ->
        "#{base_classes} border-cyan-200/40 dark:border-cyan-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-cyan-300/60 dark:hover:border-cyan-600/60 hover:shadow-cyan-500/10"

      :purple ->
        "#{base_classes} border-purple-200/40 dark:border-purple-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-purple-300/60 dark:hover:border-purple-600/60 hover:shadow-purple-500/10"

      :rose ->
        "#{base_classes} border-rose-200/40 dark:border-rose-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-rose-300/60 dark:hover:border-rose-600/60 hover:shadow-rose-500/10"

      :amber ->
        "#{base_classes} border-amber-200/40 dark:border-amber-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-amber-300/60 dark:hover:border-amber-600/60 hover:shadow-amber-500/10"

      :orange ->
        "#{base_classes} border-orange-200/40 dark:border-orange-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-orange-300/60 dark:hover:border-orange-600/60 hover:shadow-orange-500/10"

      :indigo ->
        "#{base_classes} border-indigo-200/40 dark:border-indigo-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-indigo-300/60 dark:hover:border-indigo-600/60 hover:shadow-indigo-500/10"

      :pink ->
        "#{base_classes} border-pink-200/40 dark:border-pink-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-pink-300/60 dark:hover:border-pink-600/60 hover:shadow-pink-500/10"

      _ ->
        "#{base_classes} border-slate-200/40 dark:border-slate-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-slate-300/60 dark:hover:border-slate-600/60 hover:shadow-slate-500/10"
    end
  end

  # Edit button classes with color-coordinated hover states
  def get_group_edit_button_classes(color) do
    base_classes = "text-slate-400 dark:text-slate-500"

    case color do
      :teal ->
        "#{base_classes} hover:text-teal-600 hover:bg-teal-50 dark:hover:text-teal-400 dark:hover:bg-teal-900/20"

      :emerald ->
        "#{base_classes} hover:text-emerald-600 hover:bg-emerald-50 dark:hover:text-emerald-400 dark:hover:bg-emerald-900/20"

      :cyan ->
        "#{base_classes} hover:text-cyan-600 hover:bg-cyan-50 dark:hover:text-cyan-400 dark:hover:bg-cyan-900/20"

      :purple ->
        "#{base_classes} hover:text-purple-600 hover:bg-purple-50 dark:hover:text-purple-400 dark:hover:bg-purple-900/20"

      :rose ->
        "#{base_classes} hover:text-rose-600 hover:bg-rose-50 dark:hover:text-rose-400 dark:hover:bg-rose-900/20"

      :amber ->
        "#{base_classes} hover:text-amber-600 hover:bg-amber-50 dark:hover:text-amber-400 dark:hover:bg-amber-900/20"

      :orange ->
        "#{base_classes} hover:text-orange-600 hover:bg-orange-50 dark:hover:text-orange-400 dark:hover:bg-orange-900/20"

      :indigo ->
        "#{base_classes} hover:text-indigo-600 hover:bg-indigo-50 dark:hover:text-indigo-400 dark:hover:bg-indigo-900/20"

      :pink ->
        "#{base_classes} hover:text-pink-600 hover:bg-pink-50 dark:hover:text-pink-400 dark:hover:bg-pink-900/20"

      _ ->
        "#{base_classes} hover:text-slate-600 hover:bg-slate-50 dark:hover:text-slate-400 dark:hover:bg-slate-900/20"
    end
  end

  # Color indicator with gradient and ring following liquid metal patterns
  def get_group_color_indicator_classes(color) do
    case color do
      :teal ->
        "bg-gradient-to-br from-teal-400 to-teal-500 ring-2 ring-teal-500/20"

      :emerald ->
        "bg-gradient-to-br from-emerald-400 to-emerald-500 ring-2 ring-emerald-500/20"

      :cyan ->
        "bg-gradient-to-br from-cyan-400 to-cyan-500 ring-2 ring-cyan-500/20"

      :purple ->
        "bg-gradient-to-br from-purple-400 to-purple-500 ring-2 ring-purple-500/20"

      :rose ->
        "bg-gradient-to-br from-rose-400 to-rose-500 ring-2 ring-rose-500/20"

      :amber ->
        "bg-gradient-to-br from-amber-400 to-amber-500 ring-2 ring-amber-500/20"

      :orange ->
        "bg-gradient-to-br from-orange-400 to-orange-500 ring-2 ring-orange-500/20"

      :indigo ->
        "bg-gradient-to-br from-indigo-400 to-indigo-500 ring-2 ring-indigo-500/20"

      :pink ->
        "bg-gradient-to-br from-pink-400 to-pink-500 ring-2 ring-pink-500/20"

      _ ->
        "bg-gradient-to-br from-slate-400 to-slate-500 ring-2 ring-slate-500/20"
    end
  end

  # Badge classes with subtle background and matching text colors
  def get_group_badge_classes(color) do
    case color do
      :teal ->
        "bg-teal-100/80 dark:bg-teal-900/30 text-teal-700 dark:text-teal-300"

      :emerald ->
        "bg-emerald-100/80 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-300"

      :cyan ->
        "bg-cyan-100/80 dark:bg-cyan-900/30 text-cyan-700 dark:text-cyan-300"

      :purple ->
        "bg-purple-100/80 dark:bg-purple-900/30 text-purple-700 dark:text-purple-300"

      :rose ->
        "bg-rose-100/80 dark:bg-rose-900/30 text-rose-700 dark:text-rose-300"

      :amber ->
        "bg-amber-100/80 dark:bg-amber-900/30 text-amber-700 dark:text-amber-300"

      :orange ->
        "bg-orange-100/80 dark:bg-orange-900/30 text-orange-700 dark:text-orange-300"

      :indigo ->
        "bg-indigo-100/80 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300"

      _ ->
        "bg-slate-100/80 dark:bg-slate-900/30 text-slate-700 dark:text-slate-300"
    end
  end

  @doc """
  Public group card with liquid metal styling for discovery/join UI.

  ## Examples

      <.liquid_group_card
        name="My Group"
        member_count={5}
        require_password={false}
        group_id="123"
      />
  """
  attr :name, :string, required: true
  attr :member_count, :integer, required: true
  attr :require_password, :boolean, default: false
  attr :group_id, :string, required: true
  attr :visible_members, :integer, default: 3
  attr :class, :any, default: ""
  attr :rest, :global

  def liquid_group_card(assigns) do
    assigns = assign(assigns, :avatar_count, min(assigns.member_count, assigns.visible_members))

    assigns =
      assign(assigns, :overflow_count, max(0, assigns.member_count - assigns.visible_members))

    ~H"""
    <div
      class={[
        "group/card relative rounded-2xl overflow-hidden",
        "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
        "border border-slate-200/60 dark:border-slate-700/60",
        "hover:border-cyan-300/50 dark:hover:border-cyan-600/50",
        "shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20",
        "hover:shadow-xl hover:shadow-cyan-500/10 dark:hover:shadow-cyan-400/10",
        "transition-all duration-300 ease-out transform-gpu hover:will-change-transform",
        "hover:-translate-y-0.5",
        @class
      ]}
      {@rest}
    >
      <div class="absolute inset-0 opacity-0 group-hover/card:opacity-100 transition-all duration-300 ease-out bg-gradient-to-r from-cyan-50/60 via-teal-50/80 to-emerald-50/60 dark:from-cyan-900/15 dark:via-teal-900/20 dark:to-emerald-900/15 transform-gpu">
      </div>
      <div class="absolute inset-0 opacity-0 group-hover/card:opacity-100 transition-all duration-500 ease-out bg-gradient-to-r from-transparent via-cyan-200/30 to-transparent dark:via-cyan-400/15 transform-gpu group-hover/card:translate-x-full -translate-x-full">
      </div>

      <div class="relative p-4 sm:p-5">
        <div class="flex gap-4">
          <div class="relative flex h-12 w-12 shrink-0 items-center justify-center rounded-xl overflow-hidden transition-all duration-200 ease-out transform-gpu hover:will-change-transform bg-gradient-to-br from-slate-100 via-slate-50 to-slate-100 dark:from-slate-700 dark:via-slate-600 dark:to-slate-700 group-hover/card:from-cyan-100 group-hover/card:via-teal-50 group-hover/card:to-emerald-100 dark:group-hover/card:from-cyan-900/30 dark:group-hover/card:via-teal-900/25 dark:group-hover/card:to-emerald-900/30 shadow-sm">
            <.phx_icon
              name="hero-globe-alt"
              class={[
                "h-6 w-6 transition-colors duration-200",
                "text-slate-500 dark:text-slate-400",
                "group-hover/card:text-cyan-600 dark:group-hover/card:text-cyan-400"
              ]}
            />
          </div>

          <div class="flex-1 min-w-0 pt-0.5">
            <div class="flex items-start justify-between gap-3 mb-1.5">
              <div class="flex items-center gap-2 flex-wrap min-w-0">
                <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100 truncate group-hover/card:text-cyan-700 dark:group-hover/card:text-cyan-300 transition-colors duration-200">
                  {@name}
                </h2>
                <span
                  :if={@require_password}
                  class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-gradient-to-r from-amber-100 to-orange-100 text-amber-700 dark:from-amber-900/40 dark:to-orange-900/40 dark:text-amber-300 shrink-0"
                >
                  <.phx_icon name="hero-lock-closed" class="h-3 w-3" /> Protected
                </span>
              </div>

              <div :if={@avatar_count > 0} class="isolate flex -space-x-2 shrink-0">
                <div
                  :for={_ <- 1..@avatar_count}
                  class="w-7 h-7 rounded-full bg-gradient-to-br from-cyan-100 to-teal-100 dark:from-cyan-900/40 dark:to-teal-900/40 border-2 border-white dark:border-slate-800 flex items-center justify-center"
                >
                  <.phx_icon name="hero-user" class="w-3.5 h-3.5 text-cyan-600 dark:text-cyan-400" />
                </div>
                <div
                  :if={@overflow_count > 0}
                  class="w-7 h-7 rounded-full bg-slate-100 dark:bg-slate-700 border-2 border-white dark:border-slate-800 flex items-center justify-center text-xs font-medium text-slate-600 dark:text-slate-400"
                >
                  +{@overflow_count}
                </div>
              </div>
            </div>

            <p class="text-sm text-slate-600 dark:text-slate-400">
              {@member_count} {if @member_count == 1, do: "member", else: "members"}
            </p>
          </div>
        </div>

        <div class="relative mt-4 pt-3 border-t border-slate-100 dark:border-slate-700/50 flex items-center justify-end">
          <.liquid_button
            phx-click="join_public_group"
            phx-value-id={@group_id}
            size="sm"
            color="cyan"
            icon={if @require_password, do: "hero-lock-closed", else: "hero-arrow-right"}
          >
            Join Circle
          </.liquid_button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Liquid tab bar component with consistent styling across the app.

  ## Examples

      <.liquid_tab_bar>
        <:tab id="my_groups" icon="hero-user-group" active={@active_tab == "my_groups"} count={5}>
          My Groups
        </:tab>
        <:tab id="discover" icon="hero-globe-alt" active={@active_tab == "discover"} color="cyan">
          Discover
        </:tab>
      </.liquid_tab_bar>
  """
  attr :class, :any, default: ""

  slot :tab, required: true do
    attr :id, :string, required: true
    attr :icon, :string
    attr :active, :boolean
    attr :count, :integer
    attr :color, :string
  end

  attr :rest, :global, include: ~w(phx-click)

  def liquid_tab_bar(assigns) do
    ~H"""
    <div class={["border-b border-slate-200/60 dark:border-slate-700/60", @class]}>
      <nav class="flex" aria-label="Tabs">
        <button
          :for={tab <- @tab}
          type="button"
          phx-click="switch_tab"
          phx-value-tab={tab.id}
          class={[
            "flex-1 sm:flex-none px-4 sm:px-6 py-3 sm:py-4 text-sm font-medium border-b-2 transition-all duration-200 focus:outline-none touch-manipulation",
            tab_active_classes(tab[:active], tab[:color] || "teal")
          ]}
        >
          <span class="flex items-center justify-center sm:justify-start gap-2">
            <.phx_icon :if={tab[:icon]} name={tab.icon} class="w-4 h-4" />
            <span class="truncate">{render_slot(tab)}</span>
            <span
              :if={tab[:count] && tab[:count] > 0}
              class={[
                "ml-1 px-2 py-0.5 rounded-full text-xs",
                tab_count_classes(tab[:active], tab[:color] || "teal")
              ]}
            >
              {tab.count}
            </span>
          </span>
        </button>
      </nav>
    </div>
    """
  end

  defp tab_active_classes(true, color) do
    case color do
      "cyan" ->
        "border-cyan-500 text-cyan-600 dark:text-cyan-400 bg-cyan-50/50 dark:bg-cyan-900/20"

      "emerald" ->
        "border-emerald-500 text-emerald-600 dark:text-emerald-400 bg-emerald-50/50 dark:bg-emerald-900/20"

      _ ->
        "border-teal-500 text-teal-600 dark:text-teal-400 bg-teal-50/50 dark:bg-teal-900/20"
    end
  end

  defp tab_active_classes(_, _color) do
    "border-transparent text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300 hover:border-slate-300 dark:hover:border-slate-600"
  end

  defp tab_count_classes(true, color) do
    case color do
      "cyan" -> "bg-cyan-100 text-cyan-700 dark:bg-cyan-900/50 dark:text-cyan-300"
      "emerald" -> "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/50 dark:text-emerald-300"
      _ -> "bg-teal-100 text-teal-700 dark:bg-teal-900/50 dark:text-teal-300"
    end
  end

  defp tab_count_classes(_, _color) do
    "bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-400"
  end

  @doc """
  My Groups card for responsive display (card on mobile, row-like on desktop).

  ## Examples

      <.liquid_my_group_card
        id="group-123"
        name="My Group"
        description="Group description"
        is_public={false}
        can_edit={true}
        can_delete={true}
        group_id="123"
        navigate_url="/app/circles/123"
        edit_url="/app/circles/123/edit"
      >
        <:members>
          <.group_avatar ... />
        </:members>
      </.liquid_my_group_card>
  """
  attr :id, :string, required: true
  attr :name, :string, default: nil
  attr :description, :string, default: nil
  attr :is_public, :boolean, default: false
  attr :can_edit, :boolean, default: false
  attr :can_delete, :boolean, default: false
  attr :group_id, :string, required: true
  attr :navigate_url, :string, required: true
  attr :edit_url, :string, default: nil
  attr :class, :any, default: ""
  attr :unread_mention_count, :integer, default: 0
  attr :browser_decrypt, :boolean, default: false
  attr :member_count, :integer, default: 0
  attr :business?, :boolean, default: false
  slot :members

  def liquid_my_group_card(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "group/card relative rounded-2xl overflow-visible",
        "z-0 has-[[role=menu]:not(.hidden)]:z-50",
        "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
        "border",
        if(@is_public,
          do:
            "border-cyan-200/60 dark:border-cyan-800/40 hover:border-cyan-300/60 dark:hover:border-cyan-600/50",
          else:
            "border-slate-200/60 dark:border-slate-700/60 hover:border-teal-300/50 dark:hover:border-teal-600/50"
        ),
        "shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20",
        "hover:shadow-xl hover:shadow-teal-500/10 dark:hover:shadow-teal-400/10",
        "transition-all duration-300 ease-out transform-gpu hover:will-change-transform",
        "hover:-translate-y-0.5",
        @class
      ]}
    >
      <div class="absolute inset-0 rounded-2xl overflow-hidden pointer-events-none">
        <div class="absolute inset-0 opacity-0 group-hover/card:opacity-100 transition-all duration-300 ease-out bg-gradient-to-r from-teal-50/60 via-emerald-50/80 to-cyan-50/60 dark:from-teal-900/15 dark:via-emerald-900/20 dark:to-cyan-900/15 transform-gpu">
        </div>
        <div class="absolute inset-0 opacity-0 group-hover/card:opacity-100 transition-all duration-500 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 transform-gpu group-hover/card:translate-x-full -translate-x-full">
        </div>
      </div>

      <%!-- Stretched navigation link: covers the whole card so it stays clickable,
           while the menu/actions sit above it via z-index and remain interactive. --%>
      <.link
        navigate={@navigate_url}
        class="absolute inset-0 z-0 rounded-2xl"
        aria-label={"Open circle #{@name}"}
      >
        <span class="sr-only">Open circle</span>
      </.link>

      <div class="relative z-10 p-4 sm:p-5 pointer-events-none">
        <div class="flex gap-4">
          <div class={[
            "relative flex h-12 w-12 shrink-0 items-center justify-center rounded-xl overflow-visible transition-all duration-200 ease-out transform-gpu hover:will-change-transform shadow-sm",
            cond do
              @business? ->
                "bg-gradient-to-br from-teal-100 via-emerald-50 to-emerald-100 dark:from-teal-900/40 dark:via-emerald-900/25 dark:to-emerald-900/40"

              @is_public ->
                "bg-gradient-to-br from-cyan-100 via-cyan-50 to-teal-100 dark:from-cyan-900/30 dark:via-cyan-900/20 dark:to-teal-900/30"

              true ->
                "bg-gradient-to-br from-slate-100 via-slate-50 to-slate-100 dark:from-slate-700 dark:via-slate-600 dark:to-slate-700 group-hover/card:from-teal-100 group-hover/card:via-emerald-50 group-hover/card:to-cyan-100 dark:group-hover/card:from-teal-900/30 dark:group-hover/card:via-emerald-900/25 dark:group-hover/card:to-cyan-900/30"
            end
          ]}>
            <.phx_icon
              name={
                cond do
                  @business? -> "hero-building-office-2"
                  @is_public -> "hero-globe-alt"
                  true -> "hero-lock-closed"
                end
              }
              class={[
                "h-6 w-6 transition-colors duration-200",
                cond do
                  @business? ->
                    "text-teal-600 dark:text-teal-400"

                  @is_public ->
                    "text-cyan-600 dark:text-cyan-400"

                  true ->
                    "text-slate-500 dark:text-slate-400 group-hover/card:text-teal-600 dark:group-hover/card:text-teal-400"
                end
              ]}
            />
            <span
              :if={@unread_mention_count > 0}
              class="absolute -top-1 -right-1 flex h-5 w-5 items-center justify-center rounded-full bg-gradient-to-br from-teal-500 to-emerald-500 text-[10px] font-bold text-white shadow-lg shadow-teal-500/30 ring-2 ring-white dark:ring-slate-800"
            >
              {if @unread_mention_count > 9, do: "9+", else: @unread_mention_count}
            </span>
          </div>

          <div class="flex-1 min-w-0 pt-0.5">
            <div class="flex items-start justify-between gap-3 mb-1.5">
              <div class="flex items-center gap-2 flex-wrap min-w-0">
                <h2
                  class="text-base font-semibold text-slate-900 dark:text-slate-100 truncate group-hover/card:text-teal-700 dark:group-hover/card:text-teal-300 transition-colors duration-200"
                  phx-update={if @browser_decrypt, do: "ignore"}
                  id={"my-group-card-name-#{@group_id}"}
                  data-decrypt-group-name
                >
                  {if @browser_decrypt, do: "Decrypting...", else: @name}
                </h2>
                <span
                  :if={@is_public}
                  class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-gradient-to-r from-cyan-100 to-teal-100 text-cyan-700 dark:from-cyan-900/40 dark:to-teal-900/40 dark:text-cyan-300 shrink-0"
                >
                  <.phx_icon name="hero-globe-alt" class="h-3 w-3 mr-1" /> Public
                </span>
                <span
                  :if={!@is_public}
                  class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-emerald-100/70 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-300 shrink-0"
                  title="End-to-end encrypted — only members can read this circle"
                >
                  <.phx_icon name="hero-lock-closed" class="h-3 w-3 mr-1" /> Encrypted
                </span>
                <span
                  :if={@business?}
                  class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-gradient-to-r from-teal-100 to-emerald-100 text-teal-700 dark:from-teal-900/40 dark:to-emerald-900/40 dark:text-teal-300 shrink-0 ring-1 ring-inset ring-teal-200/60 dark:ring-teal-700/40"
                  title="A business circle — members are restricted to this organization"
                >
                  <.phx_icon name="hero-building-office-2" class="h-3 w-3 mr-1" /> Business
                </span>
              </div>

              <div class="flex items-center gap-2 shrink-0">
                <div :if={render_slot(@members) != []} class="isolate flex -space-x-2">
                  {render_slot(@members)}
                </div>

                <%!-- Edit/Delete tucked behind a "..." menu --%>
                <div :if={@can_edit || @can_delete} class="relative pointer-events-auto">
                  <button
                    type="button"
                    phx-click={JS.toggle_class("hidden", to: "#my-group-menu-#{@group_id}")}
                    class="p-1.5 text-slate-400 dark:text-slate-500 hover:text-slate-600 dark:hover:text-slate-300 rounded-full hover:bg-slate-100/70 dark:hover:bg-slate-700/50 transition-all duration-200 ease-out"
                    title="More options"
                    aria-label="Circle options"
                  >
                    <.phx_icon name="hero-ellipsis-horizontal" class="h-5 w-5" />
                  </button>

                  <div
                    id={"my-group-menu-#{@group_id}"}
                    class="absolute right-0 top-full z-[200] mt-2 w-40 origin-top-right hidden rounded-xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-xl shadow-slate-900/10 dark:shadow-slate-900/30 ring-1 ring-slate-200/60 dark:ring-slate-700/60"
                    role="menu"
                    aria-orientation="vertical"
                    phx-click-away={JS.add_class("hidden", to: "#my-group-menu-#{@group_id}")}
                  >
                    <div class="relative py-1.5">
                      <.link
                        :if={@can_edit && @edit_url}
                        patch={@edit_url}
                        phx-click={JS.add_class("hidden", to: "#my-group-menu-#{@group_id}")}
                        class="group flex items-center gap-3 px-4 py-2.5 text-sm transition-all duration-200 ease-out cursor-pointer hover:bg-slate-100/80 dark:hover:bg-slate-700/80 text-slate-700 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100"
                        role="menuitem"
                      >
                        <.phx_icon name="hero-pencil-square" class="h-4 w-4" /> Edit
                      </.link>
                      <div
                        :if={@can_delete}
                        phx-click={
                          JS.push("delete", value: %{id: @group_id})
                          |> JS.hide(to: "##{@id}")
                          |> JS.add_class("hidden", to: "#my-group-menu-#{@group_id}")
                        }
                        data-confirm="Are you sure you want to delete this circle? This action cannot be undone."
                        class="group flex items-center gap-3 px-4 py-2.5 text-sm transition-all duration-200 ease-out cursor-pointer hover:bg-rose-100/80 dark:hover:bg-rose-900/30 text-rose-600 dark:text-rose-300 hover:text-rose-700 dark:hover:text-rose-100"
                        role="menuitem"
                      >
                        <.phx_icon name="hero-trash" class="h-4 w-4" /> Delete
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <p
              :if={@description || @browser_decrypt}
              class="text-sm text-slate-600 dark:text-slate-400 line-clamp-2 leading-relaxed"
              phx-update={if @browser_decrypt, do: "ignore"}
              id={"my-group-card-desc-#{@group_id}"}
              data-decrypt-group-description
            >
              {if @browser_decrypt, do: "Decrypting...", else: @description}
            </p>
            <p
              :if={!@description && !@browser_decrypt}
              class="text-sm text-slate-400 dark:text-slate-500 italic"
            >
              No description
            </p>

            <p
              :if={@member_count > 0}
              class="mt-2 text-xs font-medium text-slate-500 dark:text-slate-400"
            >
              {@member_count} {if @member_count == 1, do: "member", else: "members"}
            </p>
          </div>
        </div>
      </div>

      <div class="absolute right-4 bottom-3 opacity-0 group-hover/card:opacity-100 transition-all duration-200 pointer-events-none">
        <.phx_icon
          name="hero-chevron-right"
          class="h-5 w-5 text-teal-500/60 dark:text-teal-400/60"
        />
      </div>
    </div>
    """
  end

  @doc """
  Card component for pending group invitations with liquid metal styling.

  ## Examples

      <.liquid_pending_group_card
        id="pending-group-123"
        name="My Awesome Group"
        description="A group for awesome people"
        encrypted_inviter_data={%{sealed_uconn_key: "...", encrypted_username: "..."}}
        inserted_at={~U[2024-01-01 12:00:00Z]}
        requires_password={false}
      >
        <:members>
          <.avatar src="/avatar.jpg" />
        </:members>
        <:actions>
          <.liquid_button>Join</.liquid_button>
        </:actions>
      </.liquid_pending_group_card>
  """
  attr :id, :string, required: true
  attr :name, :string, default: nil
  attr :description, :string, default: nil
  attr :encrypted_inviter_data, :map, default: nil
  attr :inserted_at, :any, required: true
  attr :requires_password, :boolean, default: false
  attr :browser_decrypt, :boolean, default: false
  attr :class, :any, default: ""
  attr :business?, :boolean, default: false
  slot :members
  slot :actions

  def liquid_pending_group_card(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "group/card relative rounded-2xl overflow-hidden",
        "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
        "border border-slate-200/60 dark:border-slate-700/60",
        "hover:border-emerald-300/50 dark:hover:border-emerald-600/50",
        "shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20",
        "hover:shadow-xl hover:shadow-emerald-500/10 dark:hover:shadow-emerald-400/10",
        "transition-all duration-300 ease-out transform-gpu hover:will-change-transform",
        "hover:-translate-y-0.5",
        @class
      ]}
    >
      <div class="absolute inset-0 opacity-0 group-hover/card:opacity-100 transition-all duration-300 ease-out bg-gradient-to-r from-emerald-50/60 via-teal-50/80 to-cyan-50/60 dark:from-emerald-900/15 dark:via-teal-900/20 dark:to-cyan-900/15 transform-gpu">
      </div>
      <div class="absolute inset-0 opacity-0 group-hover/card:opacity-100 transition-all duration-500 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 transform-gpu group-hover/card:translate-x-full -translate-x-full">
      </div>

      <div class="relative p-4 sm:p-5">
        <div class="flex flex-col sm:flex-row gap-4">
          <div class="relative flex h-12 w-12 shrink-0 items-center justify-center rounded-xl overflow-hidden transition-all duration-200 ease-out transform-gpu hover:will-change-transform bg-gradient-to-br from-emerald-100 via-teal-50 to-emerald-100 dark:from-emerald-900/30 dark:via-teal-900/25 dark:to-emerald-900/30 shadow-sm">
            <.phx_icon
              name="hero-gift"
              class="h-6 w-6 text-emerald-600 dark:text-emerald-400 transition-transform duration-200 group-hover/card:scale-110"
            />
          </div>

          <div class="flex-1 min-w-0">
            <div class="flex items-start justify-between gap-3 mb-2">
              <div class="flex items-center gap-2 flex-wrap min-w-0">
                <h2
                  class="text-base font-semibold text-slate-900 dark:text-slate-100 truncate group-hover/card:text-emerald-700 dark:group-hover/card:text-emerald-300 transition-colors duration-200"
                  phx-update={if @browser_decrypt, do: "ignore"}
                  id={"pending-card-name-#{@id}"}
                  data-decrypt-group-name
                >
                  {if @browser_decrypt, do: "Decrypting...", else: @name}
                </h2>
                <span
                  :if={@requires_password}
                  class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-gradient-to-r from-amber-100 to-orange-100 text-amber-700 dark:from-amber-900/40 dark:to-orange-900/40 dark:text-amber-300 shrink-0"
                >
                  <.phx_icon name="hero-lock-closed" class="h-3 w-3" /> Password
                </span>
                <span
                  :if={@business?}
                  class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-gradient-to-r from-teal-100 to-emerald-100 text-teal-700 dark:from-teal-900/40 dark:to-emerald-900/40 dark:text-teal-300 shrink-0 ring-1 ring-inset ring-teal-200/60 dark:ring-teal-700/40"
                  title="A business circle — members are restricted to this organization"
                >
                  <.phx_icon name="hero-building-office-2" class="h-3 w-3" /> Business
                </span>
              </div>

              <div :if={render_slot(@members) != []} class="isolate flex -space-x-2 shrink-0">
                {render_slot(@members)}
              </div>
            </div>

            <p
              :if={@description || @browser_decrypt}
              class="text-sm text-slate-600 dark:text-slate-400 line-clamp-2 leading-relaxed mb-3"
              phx-update={if @browser_decrypt, do: "ignore"}
              id={"pending-card-desc-#{@id}"}
              data-decrypt-group-description
            >
              {if @browser_decrypt, do: "Decrypting...", else: @description}
            </p>
            <p
              :if={!@description && !@browser_decrypt}
              class="text-sm text-slate-400 dark:text-slate-500 italic mb-3"
            >
              No description
            </p>

            <div class="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-slate-500 dark:text-slate-400">
              <div class="flex items-center gap-1.5">
                <.phx_icon name="hero-user" class="w-3.5 h-3.5" />
                <%!-- DecryptInviterName hook for browser-side ZK decryption --%>
                <div
                  :if={@encrypted_inviter_data}
                  id={"decrypt-inviter-#{@id}"}
                  phx-hook="DecryptInviterName"
                  data-sealed-uconn-key={@encrypted_inviter_data[:sealed_uconn_key]}
                  data-encrypted-conn-username={@encrypted_inviter_data[:encrypted_username]}
                  data-target-id={"inviter-name-#{@id}"}
                >
                </div>
                <span
                  id={"inviter-name-#{@id}"}
                  phx-update={if @encrypted_inviter_data, do: "ignore"}
                  class="font-medium text-emerald-700 dark:text-emerald-300"
                >
                  {if @encrypted_inviter_data, do: "Decrypting...", else: "@unknown"}
                </span>
                <span>invited you</span>
              </div>
              <span class="text-slate-300 dark:text-slate-600">•</span>
              <time datetime={@inserted_at}>
                <.local_time_ago id={"time-created-#{@id}"} at={@inserted_at} />
              </time>
            </div>
          </div>
        </div>

        <div
          :if={render_slot(@actions) != []}
          class="relative mt-4 pt-3 border-t border-slate-100 dark:border-slate-700/50 flex flex-wrap items-center justify-end gap-2"
        >
          {render_slot(@actions)}
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Load more indicator for groups with liquid metal styling.
  Reuses the same pattern as timeline scroll indicator.

  ## Examples

      <.liquid_load_more_groups
        remaining_count={15}
        load_count={10}
        loading={false}
        color="teal"
        phx-click="load_more_groups"
      />
  """
  attr :remaining_count, :integer, default: 0
  attr :load_count, :integer, default: 10
  attr :loading, :boolean, default: false
  attr :color, :string, default: "teal"
  attr :item_label, :string, default: "groups"
  attr :class, :any, default: ""
  attr :rest, :global, include: ~w(phx-click)

  def liquid_load_more_groups(assigns) do
    assigns = assign(assigns, :color_classes, get_load_more_color_classes(assigns.color))

    ~H"""
    <div class={["text-center py-6", @class]}>
      <div
        :if={@loading}
        class="inline-flex items-center gap-3 px-6 py-3 rounded-xl bg-slate-50/80 dark:bg-slate-800/80 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 text-slate-600 dark:text-slate-400"
      >
        <div class={["w-2 h-2 rounded-full animate-pulse", @color_classes.indicator]}></div>
        <span class="text-sm font-medium">Loading more {@item_label}...</span>
      </div>

      <button
        :if={!@loading && @remaining_count > 0}
        class={[
          "inline-flex items-center gap-3 px-6 py-3 rounded-xl backdrop-blur-sm transition-all duration-200 ease-out cursor-pointer group text-sm font-medium",
          @color_classes.button
        ]}
        {@rest}
      >
        <div class={["w-2 h-2 rounded-full animate-pulse", @color_classes.indicator]}></div>
        <span>
          Load {min(@load_count, @remaining_count)} more {@item_label} ({@remaining_count} remaining)
        </span>
      </button>
    </div>
    """
  end

  defp get_load_more_color_classes(color) do
    case color do
      "teal" ->
        %{
          button:
            "bg-gradient-to-r from-teal-500 to-emerald-500 text-white shadow-md hover:from-teal-600 hover:to-emerald-600",
          indicator: "bg-white/80"
        }

      "cyan" ->
        %{
          button:
            "bg-gradient-to-r from-cyan-500 to-teal-500 text-white shadow-md hover:from-cyan-600 hover:to-teal-600",
          indicator: "bg-white/80"
        }

      "emerald" ->
        %{
          button:
            "bg-gradient-to-r from-emerald-500 to-teal-500 text-white shadow-md hover:from-emerald-600 hover:to-teal-600",
          indicator: "bg-white/80"
        }

      _ ->
        %{
          button:
            "bg-slate-50/80 dark:bg-slate-800/80 border border-slate-200/60 dark:border-slate-700/60 text-slate-600 dark:text-slate-400 hover:bg-slate-100/80 dark:hover:bg-slate-700/80",
          indicator: "bg-gradient-to-r from-slate-400 to-slate-500"
        }
    end
  end

  @doc """
  Key verification panel (EPIC #291 / Phase 3 / #295).

  Renders the Signal-style safety number for the (viewer, peer) pair plus the
  TOFU pin state, driven entirely client-side by the `KeySafetyNumber` hook. The
  server can neither read nor forge the viewer-sealed pin record, so it cannot
  fake a "verified" badge. States: unverified (pinned, not yet compared),
  verified (out-of-band confirmed), mismatch (served key changed), unavailable
  (legacy peer with no PQ key yet).

  Used on every surface where a viewer can verify a confirmed connection's key:
  the connection show page, the connection's public profile, and the DM. Pass a
  context-unique `id`, the `peer_user` (%Accounts.User{}), and the viewer-sealed
  `sealed_peer_pin` blob (or nil). Renders nothing when `peer_user` is nil.

  The verify/repin actions push `verify_peer_key` / `repin_peer_key` events
  (`%{peer_user_id, sealed_pin}`); the host LiveView persists them via
  `MossletWeb.Helpers.verify_connection_peer_pin/3`.
  """
  attr :id, :string, required: true
  attr :peer_user, :map, default: nil

  attr :peer_user_id, :string,
    default: nil,
    doc: "Explicit peer user id (alternative to passing peer_user)"

  attr :peer_public_key, :string,
    default: nil,
    doc: "Explicit peer X25519 public key (alternative to peer_user)"

  attr :peer_pq_public_key, :string,
    default: nil,
    doc: "Explicit peer ML-KEM public key (alternative to peer_user)"

  attr :sealed_peer_pin, :string, default: nil

  attr :lazy, :boolean,
    default: false,
    doc: "Defer fingerprint compute until a verification:open event (modal usage)"

  attr :flat, :boolean,
    default: false,
    doc: "Drop the card chrome (bg/border/shadow/rounding) when nested in a modal"

  def key_verification_panel(assigns) do
    peer = assigns[:peer_user]

    assigns =
      assigns
      |> assign(:resolved_peer_user_id, assigns[:peer_user_id] || (peer && peer.id))
      |> assign(:peer_public_key, assigns[:peer_public_key] || kv_peer_public_key(peer))
      |> assign(:peer_pq_public_key, assigns[:peer_pq_public_key] || kv_peer_pq_public_key(peer))

    ~H"""
    <div
      :if={@resolved_peer_user_id}
      id={@id}
      phx-hook="KeySafetyNumber"
      data-peer-user-id={@resolved_peer_user_id}
      data-peer-public-key={@peer_public_key}
      data-peer-pq-public-key={@peer_pq_public_key}
      data-sealed-pin={@sealed_peer_pin}
      data-lazy={to_string(@lazy)}
      class={[
        !@flat &&
          "bg-white dark:bg-slate-800 px-4 py-5 shadow dark:shadow-emerald-500/30 sm:rounded-2xl sm:px-6 border border-slate-200/60 dark:border-slate-700/60"
      ]}
    >
      <.kv_panel_body />
    </div>
    """
  end

  @doc false
  # Inner body of the key-verification panel, split out so it can be reused both
  # by `key_verification_panel/1` (standalone card) and inside the modal rendered
  # by `key_verification_compact/1`. Contains only the `data-state`/`data-action`/
  # `data-qr*`/`data-safety-number` markup the `KeySafetyNumber` hook drives — it
  # carries no hook attrs itself, so it must always live inside a hook element.
  def kv_panel_body(assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between gap-3">
        <h2 class="text-lg font-medium text-slate-900 dark:text-slate-100 inline-flex items-center gap-2">
          <.phx_icon name="hero-finger-print" class="h-5 w-5 text-teal-500 dark:text-teal-400" />
          Key verification
        </h2>

        <%!-- Verified badge --%>
        <span
          data-state="verified"
          hidden
          class="inline-flex items-center gap-1 rounded-full bg-emerald-50 dark:bg-emerald-900/30 px-2.5 py-1 text-xs font-semibold text-emerald-700 dark:text-emerald-300 ring-1 ring-inset ring-emerald-600/20 dark:ring-emerald-400/30"
        >
          <.phx_icon name="hero-check-badge" class="h-4 w-4" /> Verified
        </span>

        <%!-- Pinned, not verified --%>
        <span
          data-state="unverified"
          hidden
          class="inline-flex items-center gap-1 rounded-full bg-slate-100 dark:bg-slate-700 px-2.5 py-1 text-xs font-semibold text-slate-600 dark:text-slate-300 ring-1 ring-inset ring-slate-500/20"
        >
          <.phx_icon name="hero-lock-closed" class="h-4 w-4" /> Pinned · not verified
        </span>

        <%!-- Key changed --%>
        <span
          data-state="mismatch"
          hidden
          class="inline-flex items-center gap-1 rounded-full bg-amber-50 dark:bg-amber-900/30 px-2.5 py-1 text-xs font-semibold text-amber-700 dark:text-amber-300 ring-1 ring-inset ring-amber-600/30"
        >
          <.phx_icon name="hero-exclamation-triangle" class="h-4 w-4" /> Key changed
        </span>
      </div>

      <%!-- Loading --%>
      <div data-state="loading" class="mt-4 text-sm text-slate-500 dark:text-slate-400">
        <div class="flex items-center gap-2">
          <div class="h-2 w-2 rounded-full bg-teal-400 animate-pulse"></div>
          Computing safety number…
        </div>
      </div>

      <%!-- Unavailable (legacy peer, no PQ key) --%>
      <div data-state="unavailable" hidden class="mt-4">
        <p class="text-sm text-slate-500 dark:text-slate-400">
          This contact hasn't upgraded to a post-quantum key yet, so their key can't be
          verified. Verification will become available once they sign in again.
        </p>
      </div>

      <%!-- Shared safety-number display (visible for unverified/verified/mismatch) --%>
      <div class="mt-4">
        <p class="text-sm text-slate-600 dark:text-slate-400">
          Compare these digits with
          <span class="font-medium text-slate-900 dark:text-slate-100">your contact in person</span>
          or over a channel you already trust. If they match on both devices, this contact's
          encryption key is authentic.
        </p>
        <p
          data-safety-number
          phx-no-curly-interpolation
          class="mt-3 font-mono text-base sm:text-lg leading-relaxed tracking-wide text-slate-900 dark:text-slate-100 break-words select-all"
        >
        </p>
      </div>

      <%!-- Unverified actions --%>
      <div data-state="unverified" hidden class="mt-4 flex flex-wrap items-center gap-3">
        <button
          type="button"
          data-action="verify"
          class="inline-flex items-center justify-center gap-2 rounded-full bg-gradient-to-r from-teal-500 to-emerald-500 px-5 py-2.5 text-sm font-semibold text-white shadow-md hover:from-teal-600 hover:to-emerald-600 transition-all duration-200"
        >
          <.phx_icon name="hero-check-badge" class="h-4 w-4" /> Mark as verified
        </button>
        <button
          type="button"
          data-action="qr-toggle"
          class="inline-flex items-center justify-center gap-2 rounded-full border border-teal-300/60 dark:border-teal-600/40 bg-teal-50/60 dark:bg-teal-900/20 px-5 py-2.5 text-sm font-semibold text-teal-700 dark:text-teal-300 hover:bg-teal-100/60 dark:hover:bg-teal-900/30 transition-all duration-200"
        >
          <.phx_icon name="hero-qr-code" class="h-4 w-4" /> Verify by QR
        </button>
      </div>

      <%!-- Verified footer --%>
      <div data-state="verified" hidden class="mt-4">
        <p class="text-sm text-emerald-700 dark:text-emerald-300 inline-flex items-center gap-1">
          <.phx_icon name="hero-shield-check" class="h-4 w-4" />
          Verified on <span data-verified-at class="font-medium"></span>.
        </p>
      </div>

      <%!-- Mismatch alert --%>
      <div
        data-state="mismatch"
        hidden
        class="mt-4 rounded-xl border border-amber-300/60 dark:border-amber-600/40 bg-amber-50 dark:bg-amber-900/20 p-4"
      >
        <div class="flex items-start gap-3">
          <.phx_icon
            name="hero-exclamation-triangle"
            class="h-5 w-5 shrink-0 text-amber-600 dark:text-amber-400 mt-0.5"
          />
          <div class="text-sm text-amber-800 dark:text-amber-200 space-y-2">
            <p class="font-semibold">This contact's encryption key has changed.</p>
            <p>
              This can happen for an innocent reason — they reinstalled the app or set up a new
              device. But it can <span class="font-medium">also</span>
              mean someone is trying to intercept your encrypted content. To stay safe, sealing
              new content to this contact is paused until you confirm the new key.
            </p>
            <p>
              Compare the safety number above out-of-band. If it matches on both devices, choose
              "Re-verify &amp; re-pin" to trust the new key.
            </p>
            <div class="mt-1 flex flex-wrap items-center gap-3">
              <button
                type="button"
                data-action="repin"
                data-confirm="Only do this after comparing the new safety number with your contact over a trusted channel. Re-verify and re-pin this contact's new key?"
                class="inline-flex items-center justify-center gap-2 rounded-full bg-gradient-to-r from-amber-500 to-orange-500 px-5 py-2.5 text-sm font-semibold text-white shadow-md hover:from-amber-600 hover:to-orange-600 transition-all duration-200"
              >
                <.phx_icon name="hero-arrow-path" class="h-4 w-4" /> Re-verify &amp; re-pin
              </button>
              <button
                type="button"
                data-action="qr-toggle"
                class="inline-flex items-center justify-center gap-2 rounded-full border border-amber-300/60 dark:border-amber-600/40 bg-amber-50/60 dark:bg-amber-900/20 px-5 py-2.5 text-sm font-semibold text-amber-700 dark:text-amber-300 hover:bg-amber-100/60 dark:hover:bg-amber-900/30 transition-all duration-200"
              >
                <.phx_icon name="hero-qr-code" class="h-4 w-4" /> Verify by QR
              </button>
            </div>
          </div>
        </div>
      </div>

      <%!-- QR show / scan-to-verify region (toggled by the hook). Encodes ONLY
           the viewer's locally-computed safety number (public-key-derived). --%>
      <div
        data-qr-region
        hidden
        class="mt-4 rounded-xl border border-slate-200/60 dark:border-slate-700/60 bg-slate-50/60 dark:bg-slate-900/30 p-4"
      >
        <div class="grid gap-5 sm:grid-cols-2">
          <%!-- Show my code --%>
          <div>
            <h3 class="text-sm font-semibold text-slate-900 dark:text-slate-100 inline-flex items-center gap-2">
              <.phx_icon name="hero-qr-code" class="h-4 w-4 text-teal-500 dark:text-teal-400" />
              Your safety code
            </h3>
            <p class="mt-1 text-xs text-slate-500 dark:text-slate-400">
              Have your contact scan this with their MOSSLET app, in person or over a video call
              you trust.
            </p>
            <div
              data-qr-target
              class="mt-3 mx-auto w-44 h-44 rounded-lg bg-white p-2 shadow-inner [&>svg]:w-full [&>svg]:h-full"
            >
            </div>
          </div>

          <%!-- Scan their code --%>
          <div>
            <h3 class="text-sm font-semibold text-slate-900 dark:text-slate-100 inline-flex items-center gap-2">
              <.phx_icon name="hero-camera" class="h-4 w-4 text-teal-500 dark:text-teal-400" />
              Scan their code
            </h3>

            <%!-- Supported: camera scanner --%>
            <div data-scan-supported hidden>
              <p class="mt-1 text-xs text-slate-500 dark:text-slate-400">
                Point your camera at your contact's safety code to compare automatically.
              </p>

              <div data-scan-state="idle" class="mt-3">
                <button
                  type="button"
                  data-action="scan-start"
                  class="inline-flex items-center justify-center gap-2 rounded-full bg-gradient-to-r from-teal-500 to-emerald-500 px-5 py-2.5 text-sm font-semibold text-white shadow-md hover:from-teal-600 hover:to-emerald-600 transition-all duration-200"
                >
                  <.phx_icon name="hero-camera" class="h-4 w-4" /> Start camera
                </button>
              </div>

              <div data-scan-state="scanning" hidden class="mt-3 space-y-2">
                <video
                  data-qr-video
                  muted
                  playsinline
                  class="w-full max-w-xs rounded-lg bg-black aspect-square object-cover"
                ></video>
                <button
                  type="button"
                  data-action="scan-stop"
                  class="inline-flex items-center justify-center gap-2 rounded-full border border-slate-300/60 dark:border-slate-600/40 px-4 py-2 text-sm font-medium text-slate-600 dark:text-slate-300 hover:bg-slate-100/60 dark:hover:bg-slate-700/40 transition-all duration-200"
                >
                  <.phx_icon name="hero-x-mark" class="h-4 w-4" /> Stop
                </button>
              </div>

              <div data-scan-state="match" hidden class="mt-3">
                <p class="text-sm text-emerald-700 dark:text-emerald-300 inline-flex items-center gap-1">
                  <.phx_icon name="hero-check-badge" class="h-4 w-4" /> Codes match — verifying…
                </p>
              </div>

              <div data-scan-state="mismatch" hidden class="mt-3">
                <p class="text-sm text-amber-700 dark:text-amber-300 inline-flex items-center gap-1">
                  <.phx_icon name="hero-exclamation-triangle" class="h-4 w-4" /> Codes do not match
                </p>
                <button
                  type="button"
                  data-action="scan-start"
                  class="mt-2 inline-flex items-center justify-center gap-2 rounded-full border border-slate-300/60 dark:border-slate-600/40 px-4 py-2 text-sm font-medium text-slate-600 dark:text-slate-300 hover:bg-slate-100/60 dark:hover:bg-slate-700/40 transition-all duration-200"
                >
                  <.phx_icon name="hero-arrow-path" class="h-4 w-4" /> Scan again
                </button>
              </div>

              <div data-scan-state="error" hidden class="mt-3">
                <button
                  type="button"
                  data-action="scan-start"
                  class="inline-flex items-center justify-center gap-2 rounded-full border border-slate-300/60 dark:border-slate-600/40 px-4 py-2 text-sm font-medium text-slate-600 dark:text-slate-300 hover:bg-slate-100/60 dark:hover:bg-slate-700/40 transition-all duration-200"
                >
                  <.phx_icon name="hero-arrow-path" class="h-4 w-4" /> Try again
                </button>
              </div>

              <p data-scan-status class="mt-2 text-xs text-slate-500 dark:text-slate-400"></p>
            </div>

            <%!-- Unsupported: graceful fallback to manual compare --%>
            <p data-scan-unsupported hidden class="mt-1 text-xs text-slate-500 dark:text-slate-400">
              Your browser can't scan QR codes here. Compare the digits above with your contact
              instead — it's just as secure.
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp kv_peer_public_key(%Mosslet.Accounts.User{} = peer), do: get_in(peer.key_pair, ["public"])
  defp kv_peer_public_key(_), do: nil

  defp kv_peer_pq_public_key(%Mosslet.Accounts.User{} = peer), do: peer.pq_public_key
  defp kv_peer_pq_public_key(_), do: nil

  @doc """
  Compact key-verification trigger + modal (EPIC #291 / #302 follow-up).

  Designed for dense surfaces like the profile header where the full
  `key_verification_panel/1` card is too heavy. Renders a single
  `KeySafetyNumber` hook element (NON-lazy, so it computes state on mount and the
  inline verified badge is correct on page load WITHOUT opening the modal). The
  hook's subtree contains BOTH the inline controls (a "View verification" button,
  a verified badge, and a key-changed chip) and a `<.phx_modal>` wrapping
  `kv_panel_body/1`. Because the hook toggles every `[data-state]` within its
  element, the inline badge and the modal body stay in sync. The button opens the
  modal and (idempotently) dispatches `verification:open`; closing dispatches
  `verification:close` (stopping the camera).

  Accepts the same peer inputs as `key_verification_panel/1`. Renders nothing
  when no peer is resolved.
  """
  attr :id, :string, required: true
  attr :peer_user, :map, default: nil
  attr :peer_user_id, :string, default: nil
  attr :peer_public_key, :string, default: nil
  attr :peer_pq_public_key, :string, default: nil
  attr :sealed_peer_pin, :string, default: nil

  def key_verification_compact(assigns) do
    peer = assigns[:peer_user]

    assigns =
      assigns
      |> assign(:resolved_peer_user_id, assigns[:peer_user_id] || (peer && peer.id))
      |> assign(:peer_public_key, assigns[:peer_public_key] || kv_peer_public_key(peer))
      |> assign(:peer_pq_public_key, assigns[:peer_pq_public_key] || kv_peer_pq_public_key(peer))
      |> assign(:modal_id, "#{assigns.id}-modal")

    ~H"""
    <span
      :if={@resolved_peer_user_id}
      id={@id}
      phx-hook="KeySafetyNumber"
      data-peer-user-id={@resolved_peer_user_id}
      data-peer-public-key={@peer_public_key}
      data-peer-pq-public-key={@peer_pq_public_key}
      data-sealed-pin={@sealed_peer_pin}
      data-lazy="false"
      class="inline-flex items-center gap-1.5"
    >
      <span
        data-state="verified"
        hidden
        class="inline-flex items-center gap-1 rounded-full bg-emerald-50 dark:bg-emerald-900/30 px-2.5 py-1 text-xs font-semibold text-emerald-700 dark:text-emerald-300 ring-1 ring-inset ring-emerald-600/20 dark:ring-emerald-400/30"
      >
        <.phx_icon name="hero-check-badge" class="h-3.5 w-3.5" /> Verified
      </span>

      <span
        data-state="mismatch"
        hidden
        class="inline-flex items-center gap-1 rounded-full bg-amber-50 dark:bg-amber-900/30 px-2.5 py-1 text-xs font-semibold text-amber-700 dark:text-amber-300 ring-1 ring-inset ring-amber-600/30"
      >
        <.phx_icon name="hero-exclamation-triangle" class="h-3.5 w-3.5" /> Key changed
      </span>

      <button
        type="button"
        phx-click={
          phx_show_modal(%JS{}, @modal_id) |> JS.dispatch("verification:open", to: "##{@id}")
        }
        class="inline-flex items-center gap-1 rounded-full border border-teal-300/60 dark:border-teal-600/40 bg-teal-50/60 dark:bg-teal-900/20 px-2.5 py-1 text-xs font-semibold text-teal-700 dark:text-teal-300 hover:bg-teal-100/60 dark:hover:bg-teal-900/30 transition-all duration-200"
      >
        <.phx_icon name="hero-finger-print" class="h-3.5 w-3.5" /> View verification
      </button>

      <.phx_modal id={@modal_id} on_cancel={JS.dispatch("verification:close", to: "##{@id}")}>
        <div class="w-[20rem] sm:w-[34rem] max-w-full pt-3 pr-10">
          <.kv_panel_body />
        </div>
      </.phx_modal>
    </span>
    """
  end
end
