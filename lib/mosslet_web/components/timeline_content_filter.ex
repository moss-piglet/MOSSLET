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
      "hover:shadow-2xl hover:shadow-teal-500/10 dark:hover:shadow-teal-500/5",
      "hover:border-teal-200/70 dark:hover:border-teal-700/50",
      @class
    ]}>
      <%!-- Enhanced liquid background on hover --%>
      <div class="absolute inset-0 opacity-0 transition-all duration-500 ease-out bg-gradient-to-br from-teal-50/30 via-cyan-50/20 to-teal-50/30 dark:from-teal-900/15 dark:via-cyan-900/10 dark:to-teal-900/15 group-hover:opacity-100">
      </div>

      <%!-- Subtle shimmer effect --%>
      <div class="absolute inset-0 opacity-0 transition-all duration-700 ease-out bg-gradient-to-r from-transparent via-teal-200/20 to-transparent dark:via-teal-400/10 group-hover:opacity-100 group-hover:translate-x-full -translate-x-full">
      </div>

      <div class="relative p-6 space-y-8">
        <%!-- Enhanced Filter Header with improved hierarchy --%>
        <div class="flex items-start justify-between pb-6 border-b border-slate-200/60 dark:border-slate-700/60">
          <div class="flex items-center gap-4">
            <div class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-teal-100 via-cyan-50 to-teal-100 dark:from-teal-900/30 dark:via-cyan-900/25 dark:to-teal-900/30 shadow-sm">
              <.phx_icon name="hero-funnel" class="h-5 w-5 text-teal-700 dark:text-teal-300" />
            </div>
            <div class="space-y-1">
              <h3 class="text-xl font-bold text-slate-900 dark:text-slate-100 tracking-tight">
                Content Filters
              </h3>
              <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                Customize your timeline experience with smart filtering
              </p>
            </div>
          </div>

          <div class="flex flex-col sm:flex-row gap-2">
            <.liquid_button
              variant="secondary"
              size="sm"
              color="teal"
              icon="hero-arrow-path"
              phx-click="clear_all_filters"
              class="w-full sm:w-auto shadow-sm hover:shadow-md transition-shadow duration-200"
            >
              <span class="sm:hidden">Reset Filters</span>
              <span class="hidden sm:inline">Reset All</span>
            </.liquid_button>
          </div>
        </div>

        <%!-- Filter sections with improved spacing --%>
        <div class="space-y-6">
          <%!-- Priority: Keywords (most common use case) --%>
          <.filter_section
            title="Keywords"
            icon="hero-hashtag"
            description="Hide posts containing specific content categories"
          >
            <.keyword_filter_input
              current_keywords={@filters.keywords || []}
              mobile_friendly={@mobile_friendly}
              form={@filters.keyword_form}
            />
          </.filter_section>

          <%!-- Content Warnings (moderate complexity) --%>
          <.filter_section
            title="Content Warnings"
            icon="hero-hand-raised"
            description="Control visibility of sensitive content"
          >
            <.content_warning_toggles
              current_settings={@filters.content_warnings || %{}}
              mobile_friendly={@mobile_friendly}
            />
          </.filter_section>

          <%!-- Muted Users (least common, but important) --%>
          <.filter_section
            title="Muted Users"
            icon="hero-bell-slash"
            description="Manage blocked or hidden user content"
          >
            <.muted_users_list
              muted_users={@filters.muted_users || []}
              mobile_friendly={@mobile_friendly}
            />
          </.filter_section>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Individual filter section with improved visual hierarchy and liquid metal styling.
  """
  attr :title, :string, required: true
  attr :icon, :string, required: true
  attr :description, :string, default: nil
  slot :inner_block, required: true

  def filter_section(assigns) do
    ~H"""
    <div class="relative group/section">
      <%!-- Enhanced section background with better visual separation --%>
      <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-r from-slate-50/40 via-transparent to-slate-50/40 dark:from-slate-700/25 dark:via-transparent dark:to-slate-700/25 group-hover/section:opacity-100 rounded-2xl">
      </div>

      <div class="relative p-5 space-y-5 rounded-2xl border border-slate-200/40 dark:border-slate-700/40 bg-slate-50/20 dark:bg-slate-800/20">
        <%!-- Section header with better hierarchy --%>
        <div class="space-y-2">
          <div class="flex items-center gap-3">
            <div class="relative flex h-8 w-8 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-slate-100 via-slate-50 to-slate-100 dark:from-slate-700 dark:via-slate-600 dark:to-slate-700 group-hover/section:from-teal-100 group-hover/section:via-cyan-50 group-hover/section:to-teal-100 dark:group-hover/section:from-teal-900/30 dark:group-hover/section:via-cyan-900/25 dark:group-hover/section:to-teal-900/30 transition-all duration-200 shadow-sm">
              <.phx_icon
                name={@icon}
                class="h-4 w-4 text-slate-600 dark:text-slate-400 group-hover/section:text-teal-700 dark:group-hover/section:text-teal-300 transition-colors duration-200"
              />
            </div>
            <h4 class="text-base font-bold text-slate-900 dark:text-slate-100 group-hover/section:text-slate-900 dark:group-hover/section:text-slate-50 transition-colors duration-200">
              {@title}
            </h4>
          </div>
          <p
            :if={@description}
            class="text-sm text-slate-600 dark:text-slate-400 ml-11 leading-relaxed"
          >
            {@description}
          </p>
        </div>

        <%!-- Section content with proper spacing --%>
        <div class="ml-0">
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Keyword filter using form-based liquid_select_custom component for proper sanitization.
  """
  attr :current_keywords, :list, default: []
  attr :mobile_friendly, :boolean, default: true
  attr :form, :any, required: true

  def keyword_filter_input(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Form for adding keywords with improved layout --%>
      <div class="bg-white/50 dark:bg-slate-800/30 rounded-xl p-4 border border-slate-200/50 dark:border-slate-700/30">
        <.form
          for={@form}
          id="keyword-filter-form"
          phx-submit="add_keyword_filter"
          phx-change="validate_keyword_filter"
          class="space-y-4"
        >
          <.liquid_select_custom
            field={@form[:mute_keywords]}
            label="Add Content Filter"
            prompt="Choose a content category to filter..."
            color="teal"
            class="text-sm"
            options={[
              {"Mental Health", "mental_health"},
              {"Violence & Graphic Content", "violence"},
              {"Substance Use", "substance_use"},
              {"Politics & Controversial", "politics"},
              {"Personal & Sensitive", "personal"},
              {"Other", "other"}
            ]}
            help="Choose categories you'd like to hide from your timeline"
          />

          <div class="flex justify-end">
            <.liquid_button
              type="submit"
              size="sm"
              color="teal"
              icon="hero-plus"
              disabled={is_nil(@form[:mute_keywords].value) || @form[:mute_keywords].value == ""}
            >
              Add Filter
            </.liquid_button>
          </div>
        </.form>
      </div>

      <%!-- Active filters display with improved organization --%>
      <div :if={@current_keywords != []} class="space-y-3">
        <div class="flex items-center gap-2">
          <h5 class="text-sm font-semibold text-slate-700 dark:text-slate-300">Active Filters:</h5>
          <span class="px-2 py-1 text-xs font-medium bg-teal-100 dark:bg-teal-900/30 text-teal-800 dark:text-teal-200 rounded-full">
            {length(@current_keywords)}
          </span>
        </div>

        <div class="flex flex-wrap gap-2">
          <div
            :for={keyword <- @current_keywords}
            class={[
              "group relative inline-flex items-center gap-2 px-3 py-2 text-sm font-medium rounded-xl",
              "bg-gradient-to-r from-teal-100 via-cyan-50 to-teal-100",
              "dark:from-teal-900/30 dark:via-cyan-900/20 dark:to-teal-900/30",
              "text-teal-800 dark:text-teal-200",
              "border border-teal-200/60 dark:border-teal-700/40",
              "hover:from-teal-200 hover:via-cyan-100 hover:to-teal-200",
              "dark:hover:from-teal-800/40 dark:hover:via-cyan-800/30 dark:hover:to-teal-800/40",
              "transition-all duration-200 ease-out",
              "shadow-sm hover:shadow-md hover:shadow-teal-500/20"
            ]}
          >
            <.phx_icon name="hero-hashtag" class="h-3 w-3 opacity-70" />
            <span class="font-medium">{format_keyword_label(keyword)}</span>
            <button
              type="button"
              class={[
                "ml-1 p-1 rounded-full transition-all duration-200",
                "text-teal-600 dark:text-teal-400",
                "hover:text-red-600 dark:hover:text-red-400",
                "hover:bg-red-100/80 dark:hover:bg-red-900/30"
              ]}
              phx-click="remove_keyword_filter"
              phx-value-keyword={keyword}
            >
              <.phx_icon name="hero-x-mark" class="h-3 w-3" />
            </button>
          </div>
        </div>
      </div>

      <%!-- Help text with better positioning --%>
      <div class="pt-2 border-t border-slate-200/50 dark:border-slate-700/30">
        <p class="text-xs text-slate-600 dark:text-slate-400 leading-relaxed">
          <.phx_icon name="hero-information-circle" class="h-3 w-3 inline mr-1 opacity-70" />
          Posts containing content in these categories will be automatically hidden from your timeline
        </p>
      </div>
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
        color="teal"
      />

      <p class="text-xs text-slate-500 dark:text-slate-400 mt-3">
        Posts with content warnings will be completely hidden from your timeline
      </p>
    </div>
    """
  end

  @doc """
  Muted users management interface.
  """
  attr :muted_users, :list, default: []
  attr :mobile_friendly, :boolean, default: true

  def muted_users_list(assigns) do
    ~H"""
    <div class="space-y-3">
      <div
        :if={@muted_users == []}
        class="text-sm text-slate-500 dark:text-slate-400 py-4 text-center"
      >
        No muted users
      </div>

      <div :if={@muted_users != []} class="space-y-2">
        <div
          :for={user <- @muted_users}
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
        Posts from muted users won't appear in your timeline
      </p>
    </div>
    """
  end

  @doc """
  Liquid metal toggle switch component with configurable colors.
  """
  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :checked, :boolean, default: false
  attr :phx_click, :string, required: true
  attr :phx_value_type, :string, default: nil

  attr :color, :string,
    default: "emerald",
    values: ~w(teal emerald blue purple amber rose cyan indigo slate)

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
          "focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-white dark:focus:ring-offset-slate-800",
          "shadow-inner",
          if(@checked,
            do: toggle_checked_classes(@color),
            else: "bg-gradient-to-r from-slate-200 to-slate-300 dark:from-slate-600 dark:to-slate-500"
          ),
          "focus:ring-#{@color}-500/50"
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
            do: "border-#{@color}-100 dark:border-#{@color}-200 translate-x-6",
            else: "border-slate-300 dark:border-slate-400 translate-x-1"
          )
        ]}>
        </span>
      </button>
    </label>
    """
  end

  # Helper function to format keyword labels for display.
  # Uses the same categories as content warning functionality.
  defp format_keyword_label(keyword) when is_binary(keyword) do
    case keyword do
      "mental_health" -> "Mental Health"
      "violence" -> "Violence"
      "substance_use" -> "Substance Use"
      "politics" -> "Politics"
      "personal" -> "Personal/Sensitive"
      "other" -> "Other"
      _ -> String.capitalize(keyword)
    end
  end

  # Helper function for toggle checked state styling based on color
  defp toggle_checked_classes(color) do
    case color do
      "teal" -> "bg-gradient-to-r from-teal-500 to-cyan-500 shadow-teal-500/30"
      "emerald" -> "bg-gradient-to-r from-emerald-500 to-teal-500 shadow-emerald-500/30"
      "blue" -> "bg-gradient-to-r from-blue-500 to-cyan-500 shadow-blue-500/30"
      "purple" -> "bg-gradient-to-r from-purple-500 to-violet-500 shadow-purple-500/30"
      "amber" -> "bg-gradient-to-r from-amber-500 to-orange-500 shadow-amber-500/30"
      "rose" -> "bg-gradient-to-r from-rose-500 to-pink-500 shadow-rose-500/30"
      "cyan" -> "bg-gradient-to-r from-cyan-500 to-teal-500 shadow-cyan-500/30"
      "indigo" -> "bg-gradient-to-r from-indigo-500 to-blue-500 shadow-indigo-500/30"
      "slate" -> "bg-gradient-to-r from-slate-500 to-slate-600 shadow-slate-500/30"
      _ -> "bg-gradient-to-r from-emerald-500 to-teal-500 shadow-emerald-500/30"
    end
  end

  defp format_keyword_label(_), do: "Unknown Category"
end
