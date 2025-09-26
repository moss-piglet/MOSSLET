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
      "relative rounded-2xl overflow-hidden transition-all duration-300 ease-out",
      "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
      "border border-slate-200/60 dark:border-slate-700/60",
      "shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20",
      @class
    ]}>
      <%!-- Liquid background on focus --%>
      <div class="absolute inset-0 opacity-0 transition-all duration-500 ease-out bg-gradient-to-br from-emerald-50/20 via-teal-50/10 to-cyan-50/20 dark:from-emerald-900/10 dark:via-teal-900/5 dark:to-cyan-900/10 group-focus-within:opacity-100">
      </div>

      <div class="relative p-4 space-y-4">
        <%!-- Filter Header --%>
        <div class="flex items-center justify-between">
          <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100 flex items-center gap-2">
            <.phx_icon name="hero-funnel" class="h-5 w-5 text-emerald-600 dark:text-emerald-400" />
            Content Filters
          </h3>

          <button
            type="button"
            class="p-2 rounded-lg text-slate-500 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50/50 dark:hover:bg-emerald-900/20 transition-all duration-200"
            phx-click="clear_all_filters"
          >
            <.phx_icon name="hero-x-mark" class="h-4 w-4" />
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
    <div class="space-y-3">
      <div class="flex items-center gap-2">
        <.phx_icon
          name={@icon}
          class="h-4 w-4 text-slate-600 dark:text-slate-400"
        />
        <h4 class="text-sm font-medium text-slate-700 dark:text-slate-300">
          {@title}
        </h4>
      </div>

      <div class="pl-6">
        {render_slot(@inner_block)}
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
      <%!-- Add keyword input --%>
      <div class="relative">
        <input
          type="text"
          placeholder="Add keyword to filter..."
          class={[
            "w-full px-3 py-2 text-sm",
            "bg-slate-50/80 dark:bg-slate-700/80",
            "border border-slate-200/60 dark:border-slate-600/60",
            "rounded-lg transition-all duration-200",
            "focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:border-emerald-500/60",
            "placeholder:text-slate-500 dark:placeholder:text-slate-400"
          ]}
          phx-keydown="add_keyword_filter"
          phx-key="Enter"
          phx-value-input-id="keyword-filter-input"
        />
      </div>

      <%!-- Current keywords --%>
      <div :if={@current_keywords != []} class="flex flex-wrap gap-2">
        <div
          :for={keyword <- @current_keywords}
          class="inline-flex items-center gap-2 px-3 py-1 bg-emerald-100 dark:bg-emerald-900/30 text-emerald-800 dark:text-emerald-200 text-sm rounded-full"
        >
          <span>{keyword}</span>
          <button
            type="button"
            class="hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors"
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
    <div class="space-y-3">
      <div class="space-y-2">
        <.liquid_toggle
          name="hide_all_warnings"
          label="Hide all content warnings"
          checked={@current_settings[:hide_all] || false}
          phx_click="toggle_content_warning_filter"
          phx_value_type="hide_all"
        />

        <.liquid_toggle
          name="auto_expand_warnings"
          label="Always show content behind warnings"
          checked={@current_settings[:auto_expand] || false}
          phx_click="toggle_content_warning_filter"
          phx_value_type="auto_expand"
        />
      </div>

      <p class="text-xs text-slate-500 dark:text-slate-400">
        Control how content warnings are displayed in your timeline
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
    <label class="flex items-center justify-between cursor-pointer group">
      <span class="text-sm text-slate-700 dark:text-slate-300">
        {@label}
      </span>

      <button
        type="button"
        class={[
          "relative inline-flex h-5 w-9 shrink-0 rounded-full transition-colors duration-200 ease-in-out",
          "focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-2",
          if(@checked,
            do: "bg-emerald-600 dark:bg-emerald-500",
            else: "bg-slate-200 dark:bg-slate-600"
          )
        ]}
        phx-click={@phx_click}
        phx-value-type={@phx_value_type}
        role="switch"
        aria-checked={@checked}
      >
        <span class={[
          "pointer-events-none inline-block h-4 w-4 transform rounded-full shadow-lg ring-0 transition duration-200 ease-in-out",
          "bg-white dark:bg-slate-100",
          if(@checked, do: "translate-x-4", else: "translate-x-0")
        ]}>
        </span>
      </button>
    </label>
    """
  end
end
