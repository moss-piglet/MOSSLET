defmodule MossletWeb.TimelineContentFilter do
  @moduledoc """
  Timeline content filtering components with liquid metal design integration.

  Provides keyword filtering, content warnings, and post hiding functionality
  that integrates with the existing caching system for performance.
  """

  use MossletWeb, :html

  @doc """
  Renders the main content filter interface.

  Integrates with timeline caching and provides smooth liquid metal UI.
  """
  attr :filters, :map, required: true, doc: "current filter settings"
  attr :class, :string, default: ""
  attr :mobile_friendly, :boolean, default: true

  def liquid_content_filter(assigns) do
    ~H"""
    <div class={[
      "group relative rounded-2xl overflow-hidden transition-all duration-300 ease-out",
      "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
      "border border-slate-200/60 dark:border-slate-700/60",
      "shadow-xl shadow-slate-900/10 dark:shadow-slate-900/25",
      "hover:shadow-2xl hover:shadow-emerald-500/10 dark:hover:shadow-emerald-500/5",
      "hover:border-emerald-200/70 dark:hover:border-emerald-700/50",
      @class
    ]}>
      <%!-- Enhanced liquid background on hover --%>
      <div class="absolute inset-0 opacity-0 transition-all duration-500 ease-out bg-gradient-to-br from-emerald-50/30 via-teal-50/20 to-cyan-50/30 dark:from-emerald-900/15 dark:via-teal-900/10 dark:to-cyan-900/15 group-hover:opacity-100">
      </div>

      <%!-- Subtle shimmer effect --%>
      <div class="absolute inset-0 opacity-0 transition-all duration-700 ease-out bg-gradient-to-r from-transparent via-emerald-200/20 to-transparent dark:via-emerald-400/10 group-hover:opacity-100 group-hover:translate-x-full -translate-x-full">
      </div>

      <div class="relative p-6 space-y-6">
        <%!-- Enhanced Filter Header with liquid styling --%>
        <div class="flex items-center justify-between pb-4 border-b border-slate-200/50 dark:border-slate-700/50">
          <div class="flex items-center gap-3">
            <div class="relative flex h-8 w-8 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-emerald-100 via-teal-50 to-cyan-100 dark:from-emerald-900/30 dark:via-teal-900/25 dark:to-cyan-900/30">
              <.phx_icon name="hero-funnel" class="h-4 w-4 text-emerald-700 dark:text-emerald-300" />
            </div>
            <div>
              <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
                Content Filters
              </h3>
              <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
                Customize your timeline experience
              </p>
            </div>
          </div>

          <button
            type="button"
            class={[
              "inline-flex items-center gap-2 px-3 py-2 text-sm font-medium rounded-lg",
              "text-slate-500 dark:text-slate-400",
              "hover:text-emerald-600 dark:hover:text-emerald-400",
              "hover:bg-emerald-50/50 dark:hover:bg-emerald-900/20",
              "transition-all duration-200 ease-out",
              "focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-2"
            ]}
            phx-click="clear_all_filters"
          >
            <.phx_icon name="hero-arrow-path" class="h-4 w-4" /> Reset
          </button>
        </div>

        <%!-- Keyword Filter --%>
        <.filter_section title="Keywords" icon="hero-hashtag">
          <.keyword_filter_input
            current_keywords={@filters.keywords || []}
            mobile_friendly={@mobile_friendly}
          />
        </.filter_section>

        <%!-- Content Warning Filter --%>
        <.filter_section title="Content Warnings" icon="hero-hand-raised">
          <.content_warning_toggles
            current_settings={@filters.content_warnings || %{}}
            mobile_friendly={@mobile_friendly}
          />
        </.filter_section>

        <%!-- Hidden Users Filter --%>
        <.filter_section title="Hidden Users" icon="hero-eye-slash">
          <.hidden_users_list
            hidden_users={@filters.hidden_users || []}
            mobile_friendly={@mobile_friendly}
          />
        </.filter_section>
      </div>
    </div>
    """
  end

  @doc """
  Individual filter section with liquid metal styling.
  """
  attr :title, :string, required: true
  attr :icon, :string, required: true
  slot :inner_block, required: true

  def filter_section(assigns) do
    ~H"""
    <div class="relative group/section">
      <%!-- Section background with liquid styling --%>
      <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-r from-slate-50/30 via-transparent to-slate-50/30 dark:from-slate-700/20 dark:via-transparent dark:to-slate-700/20 group-hover/section:opacity-100 rounded-xl">
      </div>

      <div class="relative p-4 space-y-4">
        <div class="flex items-center gap-3">
          <div class="relative flex h-6 w-6 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-slate-100 via-slate-50 to-slate-100 dark:from-slate-700 dark:via-slate-600 dark:to-slate-700 group-hover/section:from-teal-100 group-hover/section:via-emerald-50 group-hover/section:to-cyan-100 dark:group-hover/section:from-teal-900/30 dark:group-hover/section:via-emerald-900/25 dark:group-hover/section:to-cyan-900/30 transition-all duration-200">
            <.phx_icon
              name={@icon}
              class="h-3.5 w-3.5 text-slate-600 dark:text-slate-400 group-hover/section:text-emerald-700 dark:group-hover/section:text-emerald-300 transition-colors duration-200"
            />
          </div>
          <h4 class="text-sm font-semibold text-slate-800 dark:text-slate-200 group-hover/section:text-slate-900 dark:group-hover/section:text-slate-100 transition-colors duration-200">
            {@title}
          </h4>
        </div>

        <div class="pl-0">
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Keyword filter input with tag-style interface.
  """
  attr :current_keywords, :list, default: []
  attr :mobile_friendly, :boolean, default: true

  def keyword_filter_input(assigns) do
    ~H"""
    <div class="space-y-3">
      <%!-- Enhanced keyword input with liquid styling --%>
      <div class="relative group/input">
        <div class="absolute inset-0 opacity-0 group-focus-within/input:opacity-100 transition-all duration-300 bg-gradient-to-r from-emerald-50/50 via-teal-50/30 to-cyan-50/50 dark:from-emerald-900/20 dark:via-teal-900/10 dark:to-cyan-900/20 rounded-xl blur-sm">
        </div>
        <input
          type="text"
          placeholder="Type keyword and press Enter..."
          class={[
            "relative w-full px-4 py-3 text-sm",
            "bg-white/80 dark:bg-slate-800/80 backdrop-blur-sm",
            "border border-slate-200/60 dark:border-slate-600/60",
            "rounded-xl transition-all duration-200",
            "focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:border-emerald-500/60",
            "focus:bg-white/95 dark:focus:bg-slate-800/95",
            "placeholder:text-slate-500 dark:placeholder:text-slate-400",
            "hover:border-emerald-300/50 dark:hover:border-emerald-600/50"
          ]}
          phx-keydown="add_keyword_filter"
          phx-key="Enter"
          phx-value-input-id="keyword-filter-input"
        />
      </div>

      <%!-- Enhanced keyword tags with liquid styling --%>
      <div :if={@current_keywords != []} class="flex flex-wrap gap-2.5">
        <div
          :for={keyword <- @current_keywords}
          class={[
            "group relative inline-flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-full",
            "bg-gradient-to-r from-emerald-100 via-teal-50 to-emerald-100",
            "dark:from-emerald-900/30 dark:via-teal-900/20 dark:to-emerald-900/30",
            "text-emerald-800 dark:text-emerald-200",
            "border border-emerald-200/60 dark:border-emerald-700/40",
            "hover:from-emerald-200 hover:via-teal-100 hover:to-emerald-200",
            "dark:hover:from-emerald-800/40 dark:hover:via-teal-800/30 dark:hover:to-emerald-800/40",
            "transition-all duration-200 ease-out",
            "shadow-sm hover:shadow-md hover:shadow-emerald-500/20"
          ]}
        >
          <span class="font-medium">{keyword}</span>
          <button
            type="button"
            class={[
              "ml-1 p-1 rounded-full transition-all duration-200",
              "text-emerald-600 dark:text-emerald-400",
              "hover:text-emerald-800 dark:hover:text-emerald-200",
              "hover:bg-emerald-200/50 dark:hover:bg-emerald-700/30"
            ]}
            phx-click="remove_keyword_filter"
            phx-value-keyword={keyword}
          >
            <.phx_icon name="hero-x-mark" class="h-3 w-3" />
          </button>
        </div>
      </div>

      <p class="text-xs text-slate-500 dark:text-slate-400">
        Posts containing these keywords will be hidden from your timeline
      </p>
    </div>
    """
  end

  @doc """
  Content warning filter toggles.
  """
  attr :current_settings, :map, default: %{}
  attr :mobile_friendly, :boolean, default: true

  def content_warning_toggles(assigns) do
    ~H"""
    <div class="space-y-4">
      <.liquid_toggle
        name="hide_all_warnings"
        label="Hide all content warnings"
        checked={@current_settings[:hide_all] || false}
        phx_click="toggle_content_warning_filter"
        phx_value_type="hide_all"
      />

      <p class="text-xs text-slate-500 dark:text-slate-400 mt-3">
        Posts with content warnings will be completely hidden from your timeline
      </p>
    </div>
    """
  end

  @doc """
  Hidden users management interface.
  """
  attr :hidden_users, :list, default: []
  attr :mobile_friendly, :boolean, default: true

  def hidden_users_list(assigns) do
    ~H"""
    <div class="space-y-3">
      <div
        :if={@hidden_users == []}
        class="text-sm text-slate-500 dark:text-slate-400 py-4 text-center"
      >
        No hidden users
      </div>

      <div :if={@hidden_users != []} class="space-y-2">
        <div
          :for={user <- @hidden_users}
          class="flex items-center justify-between py-2 px-3 bg-slate-50/80 dark:bg-slate-700/80 rounded-lg"
        >
          <div class="flex items-center gap-2">
            <div class="w-6 h-6 bg-slate-300 dark:bg-slate-600 rounded-full"></div>
            <span class="text-sm font-medium text-slate-700 dark:text-slate-300">
              {user.username}
            </span>
          </div>

          <button
            type="button"
            class="p-1 rounded text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 transition-colors"
            phx-click="unhide_user"
            phx-value-user_id={user.id}
          >
            <.phx_icon name="hero-eye" class="h-4 w-4" />
          </button>
        </div>
      </div>

      <p class="text-xs text-slate-500 dark:text-slate-400">
        Posts from hidden users won't appear in your timeline
      </p>
    </div>
    """
  end

  @doc """
  Liquid metal toggle switch component.
  """
  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :checked, :boolean, default: false
  attr :phx_click, :string, required: true
  attr :phx_value_type, :string, default: nil

  def liquid_toggle(assigns) do
    ~H"""
    <label class="flex items-center justify-between cursor-pointer group/toggle p-3 rounded-xl hover:bg-slate-50/50 dark:hover:bg-slate-700/30 transition-all duration-200">
      <div class="flex-1">
        <span class="text-sm font-medium text-slate-800 dark:text-slate-200 group-hover/toggle:text-slate-900 dark:group-hover/toggle:text-slate-100 transition-colors">
          {@label}
        </span>
      </div>

      <button
        type="button"
        class={[
          "relative inline-flex h-6 w-11 shrink-0 rounded-full transition-all duration-300 ease-out",
          "focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-2 focus:ring-offset-white dark:focus:ring-offset-slate-800",
          "shadow-inner",
          if(@checked,
            do: "bg-gradient-to-r from-emerald-500 to-teal-500 shadow-emerald-500/30",
            else: "bg-gradient-to-r from-slate-200 to-slate-300 dark:from-slate-600 dark:to-slate-500"
          )
        ]}
        phx-click={@phx_click}
        phx-value-type={@phx_value_type}
        role="switch"
        aria-checked={@checked}
      >
        <span class={[
          "pointer-events-none inline-block h-4 w-4 transform rounded-full shadow-lg transition-all duration-300 ease-out",
          "bg-white dark:bg-slate-100",
          "border-2 my-1",
          if(@checked,
            do: "border-emerald-100 dark:border-emerald-200 translate-x-6",
            else: "border-slate-300 dark:border-slate-400 translate-x-1"
          )
        ]}>
        </span>
      </button>
    </label>
    """
  end
end
