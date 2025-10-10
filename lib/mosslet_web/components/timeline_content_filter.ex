defmodule MossletWeb.TimelineContentFilter do
  @moduledoc """
  Timeline content filtering components with liquid metal design integration.

  Provides keyword filtering, content warnings, and post hiding functionality
  that integrates with the existing caching system for performance.
  """

  use MossletWeb, :html

  import MossletWeb.Helpers, only: [get_uconn_for_muted_users: 2]

  @doc """
  Renders the main content filter interface.

  Integrates with timeline caching and provides smooth liquid metal UI.
  """
  attr :filters, :map, required: true, doc: "current filter settings"
  attr :class, :string, default: ""
  attr :mobile_friendly, :boolean, default: true
  attr :current_user, :map
  attr :key, :string

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
            title="Muted Authors"
            icon="hero-bell-slash"
            description="Authors currently hidden from your timeline - their posts won't appear in any tab"
          >
            <.muted_users_list
              muted_users={@filters.muted_users || []}
              mobile_friendly={@mobile_friendly}
              current_user={@current_user}
              key={@key}
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

      <p class="text-xs text-slate-500 dark:text-slate-400 mt-3 mb-4">
        Posts with content warnings will be completely hidden from your timeline
      </p>

      <.liquid_toggle
        name="hide_mature_content"
        label="Hide mature content (18+)"
        checked={@current_settings[:hide_mature] || false}
        phx_click="toggle_content_warning_filter"
        phx_value_type="hide_mature"
        color="teal"
      />

      <p class="text-xs text-slate-500 dark:text-slate-400 mt-3">
        Posts marked as mature content will be hidden from your timeline
      </p>
    </div>
    """
  end

  @doc """
  Muted users management interface.
  """
  attr :muted_users, :list, default: []
  attr :mobile_friendly, :boolean, default: true
  attr :current_user, :map
  attr :key, :string

  def muted_users_list(assigns) do
    ~H"""
    <div class="space-y-4">
      <div
        :if={@muted_users == []}
        class="flex items-center justify-center py-8 px-4 rounded-xl bg-gradient-to-br from-slate-50/50 via-slate-25/30 to-slate-50/50 dark:from-slate-800/50 dark:via-slate-750/30 dark:to-slate-800/50 border border-slate-200/30 dark:border-slate-700/30"
      >
        <div class="text-center space-y-2">
          <div class="flex h-10 w-10 mx-auto items-center justify-center rounded-xl bg-gradient-to-br from-slate-100 via-slate-50 to-slate-100 dark:from-slate-700 dark:via-slate-600 dark:to-slate-700 shadow-sm">
            <.phx_icon name="hero-users" class="h-5 w-5 text-slate-500 dark:text-slate-400" />
          </div>
          <p class="text-sm font-medium text-slate-600 dark:text-slate-400">
            No muted users
          </p>
          <p class="text-xs text-slate-500 dark:text-slate-500">
            Authors you mute will appear here
          </p>
        </div>
      </div>

      <div :if={@muted_users != []} class="space-y-3">
        <div
          :for={user <- @muted_users}
          class="group/user relative flex items-center gap-3 p-3 rounded-xl bg-gradient-to-r from-slate-50/80 via-slate-50/40 to-slate-50/80 dark:from-slate-700/60 dark:via-slate-700/30 dark:to-slate-700/60 border border-slate-200/40 dark:border-slate-600/40 transition-all duration-200 ease-out hover:from-teal-50/60 hover:via-cyan-50/40 hover:to-teal-50/60 dark:hover:from-teal-900/20 dark:hover:via-cyan-900/15 dark:hover:to-teal-900/20 hover:border-teal-200/50 dark:hover:border-teal-700/40"
        >
          <%!-- Subtle hover background --%>
          <div class="absolute inset-0 opacity-0 group-hover/user:opacity-100 transition-opacity duration-200 bg-gradient-to-r from-teal-50/20 via-transparent to-cyan-50/20 dark:from-teal-900/10 dark:via-transparent dark:to-cyan-900/10 rounded-xl">
          </div>

          <div class="relative flex-shrink-0">
            <MossletWeb.DesignSystem.liquid_avatar
              size="sm"
              name={user.username || "Unknown"}
              src={
                get_connection_avatar_src(
                  get_uconn_for_muted_users(user, @current_user),
                  @current_user,
                  @key
                )
              }
              class="ring-2 ring-slate-200/40 dark:ring-slate-600/40 group-hover/user:ring-teal-200/60 dark:group-hover/user:ring-teal-700/40 transition-all duration-200"
            />
          </div>

          <div class="relative flex-1 min-w-0">
            <div class="flex items-center gap-2">
              <span class="text-sm font-semibold text-slate-700 dark:text-slate-300 truncate group-hover/user:text-slate-900 dark:group-hover/user:text-slate-100 transition-colors duration-200">
                {user.username || "Unknown User"}
              </span>
              <div class="flex h-5 w-5 items-center justify-center rounded-full bg-slate-200/60 dark:bg-slate-600/60 group-hover/user:bg-teal-100 dark:group-hover/user:bg-teal-900/40 transition-colors duration-200">
                <.phx_icon
                  name="hero-bell-slash"
                  class="h-3 w-3 text-slate-500 dark:text-slate-400 group-hover/user:text-teal-600 dark:group-hover/user:text-teal-400"
                />
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Enhanced informational callout --%>
      <div class="relative mt-6 p-4 rounded-xl bg-gradient-to-br from-blue-50/60 via-cyan-50/40 to-blue-50/60 dark:from-blue-900/20 dark:via-cyan-900/15 dark:to-blue-900/20 border border-blue-200/40 dark:border-blue-700/30 group/info hover:from-blue-50/80 hover:via-cyan-50/60 hover:to-blue-50/80 dark:hover:from-blue-900/30 dark:hover:via-cyan-900/25 dark:hover:to-blue-900/30 transition-all duration-200">
        <%!-- Subtle background shimmer on hover --%>
        <div class="absolute inset-0 opacity-0 group-hover/info:opacity-100 transition-opacity duration-300 bg-gradient-to-r from-transparent via-blue-100/30 to-transparent dark:via-blue-400/10 rounded-xl">
        </div>

        <div class="relative flex items-start gap-3">
          <div class="flex h-6 w-6 shrink-0 items-center justify-center rounded-lg bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/40 dark:via-cyan-900/30 dark:to-blue-900/40 shadow-sm">
            <.phx_icon
              name="hero-information-circle"
              class="h-3.5 w-3.5 text-blue-600 dark:text-blue-400"
            />
          </div>
          <div class="space-y-1">
            <p class="text-sm font-medium text-blue-700 dark:text-blue-300 leading-relaxed">
              Manage Muted Authors
            </p>
            <p class="text-xs text-blue-600/80 dark:text-blue-400/80 leading-relaxed">
              Visit your <.link
                phx-no-format
                navigate="/app/users/connections"
                class="font-semibold underline decoration-1 underline-offset-2 hover:decoration-2 hover:text-blue-700 dark:hover:text-blue-300 transition-all duration-150"
              >
                Connections</.link> page to mute or unmute authors. Posts from muted authors won't appear in your timeline.
            </p>
          </div>
        </div>
      </div>
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

  defp format_keyword_label(_), do: "Unknown Category"
end
