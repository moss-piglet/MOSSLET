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
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key"

  def liquid_content_filter(assigns) do
    assigns =
      assigns
      |> assign_new(:current_user, fn ->
        case assigns[:current_scope] do
          %{user: user} -> user
          _ -> nil
        end
      end)
      |> assign_new(:key, fn ->
        case assigns[:current_scope] do
          %{key: k} -> k
          _ -> nil
        end
      end)

    ~H"""
    <div class={[
      "relative overflow-hidden transition-all duration-300 ease-out",
      "bg-white/90 dark:bg-slate-800/90 backdrop-blur-md",
      "border border-slate-200/50 dark:border-slate-700/50",
      "rounded-2xl",
      "shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20",
      @class
    ]}>
      <div class="p-4 sm:p-5 space-y-4">
        <%!-- Compact Header --%>
        <div class="flex items-center justify-between gap-3">
          <div class="flex items-center gap-2.5">
            <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br from-teal-100 to-cyan-100 dark:from-teal-900/40 dark:to-cyan-900/40">
              <.phx_icon name="hero-funnel" class="h-4 w-4 text-teal-600 dark:text-teal-400" />
            </div>
            <div>
              <h2 class="text-sm font-semibold text-slate-900 dark:text-slate-100">
                Content Filters
              </h2>
              <p class="text-xs text-slate-500 dark:text-slate-400 hidden sm:block">
                Customize what appears in your timeline
              </p>
            </div>
          </div>

          <.liquid_button
            variant="ghost"
            size="sm"
            color="slate"
            icon="hero-arrow-path"
            phx-click="clear_all_filters"
            aria-label="Reset filters"
          >
            <span class="hidden sm:inline">Reset</span>
          </.liquid_button>
        </div>

        <%!-- Collapsible Filter Sections --%>
        <div class="space-y-3">
          <%!-- Author Filter Section --%>
          <.compact_filter_section
            id="author-section"
            title="Show Posts From"
            icon="hero-users"
            badge_count={if @filters.author_filter && @filters.author_filter != :all, do: 1, else: 0}
          >
            <.author_filter_toggles current_filter={@filters.author_filter || :all} />
          </.compact_filter_section>

          <%!-- Keywords Section --%>
          <.compact_filter_section
            id="keywords-section"
            title="Keywords"
            icon="hero-hashtag"
            badge_count={length(@filters.keywords || [])}
          >
            <.keyword_filter_input
              current_keywords={@filters.keywords || []}
              mobile_friendly={@mobile_friendly}
              form={@filters.keyword_form}
            />
          </.compact_filter_section>

          <%!-- Content Warnings Section --%>
          <.compact_filter_section
            id="warnings-section"
            title="Content Warnings"
            icon="hero-hand-raised"
            badge_count={count_active_warnings(@filters.content_warnings)}
          >
            <.content_warning_toggles
              current_settings={@filters.content_warnings || %{}}
              mobile_friendly={@mobile_friendly}
            />
          </.compact_filter_section>

          <%!-- Muted Users Section --%>
          <.compact_filter_section
            id="muted-section"
            title="Muted Authors"
            icon="hero-bell-slash"
            badge_count={length(@filters.muted_users || [])}
          >
            <.muted_users_list
              muted_users={@filters.muted_users || []}
              mobile_friendly={@mobile_friendly}
              current_user={@current_user}
              key={@key}
            />
          </.compact_filter_section>
        </div>
      </div>
    </div>
    """
  end

  defp count_active_warnings(nil), do: 0

  defp count_active_warnings(warnings) do
    Enum.count(warnings, fn {_k, v} -> v == true end)
  end

  @doc """
  Compact collapsible filter section.
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :icon, :string, required: true
  attr :badge_count, :integer, default: 0
  slot :inner_block, required: true

  def compact_filter_section(assigns) do
    ~H"""
    <div
      id={@id}
      class="group/section rounded-xl border border-slate-200/60 dark:border-slate-700/50 overflow-hidden transition-all duration-200"
    >
      <button
        type="button"
        phx-click={toggle_section(@id)}
        class="w-full flex items-center justify-between gap-2 px-3 py-2.5 bg-slate-50/50 dark:bg-slate-800/50 hover:bg-slate-100/60 dark:hover:bg-slate-700/40 transition-colors duration-150"
      >
        <div class="flex items-center gap-2">
          <div class="flex h-6 w-6 items-center justify-center rounded-md bg-slate-100 dark:bg-slate-700/60 group-hover/section:bg-teal-100 dark:group-hover/section:bg-teal-900/40 transition-colors duration-150">
            <.phx_icon
              name={@icon}
              class="h-3.5 w-3.5 text-slate-500 dark:text-slate-400 group-hover/section:text-teal-600 dark:group-hover/section:text-teal-400 transition-colors duration-150"
            />
          </div>
          <span class="text-sm font-medium text-slate-700 dark:text-slate-300">
            {@title}
          </span>
          <span
            :if={@badge_count > 0}
            class="px-1.5 py-0.5 text-[10px] font-semibold bg-teal-100 dark:bg-teal-900/50 text-teal-700 dark:text-teal-300 rounded-full"
          >
            {@badge_count}
          </span>
        </div>
        <.phx_icon
          name="hero-chevron-down"
          class="h-4 w-4 text-slate-400 dark:text-slate-500 transition-transform duration-200"
          id={"#{@id}-chevron"}
        />
      </button>

      <div
        id={"#{@id}-content"}
        class="hidden px-3 pb-3 pt-2 bg-white/50 dark:bg-slate-800/30"
      >
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  defp toggle_section(id) do
    %Phoenix.LiveView.JS{}
    |> Phoenix.LiveView.JS.toggle(to: "##{id}-content")
    |> Phoenix.LiveView.JS.toggle_class("rotate-180", to: "##{id}-chevron")
  end

  @doc """
  Keyword filter using form-based liquid_select_custom component for proper sanitization.
  """
  attr :current_keywords, :list, default: []
  attr :mobile_friendly, :boolean, default: true
  attr :form, :any, required: true

  def keyword_filter_input(assigns) do
    ~H"""
    <div class="space-y-3">
      <%!-- Compact form --%>
      <.form
        for={@form}
        id="keyword-filter-form"
        phx-submit="add_keyword_filter"
        phx-change="validate_keyword_filter"
        class="flex gap-2"
      >
        <div class="flex-1">
          <.liquid_select_custom
            field={@form[:mute_keywords]}
            label=""
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
        </div>
        <.liquid_button
          type="submit"
          size="sm"
          color="teal"
          icon="hero-plus"
          disabled={is_nil(@form[:mute_keywords].value) || @form[:mute_keywords].value == ""}
        >
          Add
        </.liquid_button>
      </.form>

      <%!-- Active filters as chips --%>
      <div :if={@current_keywords != []} class="flex flex-wrap gap-1.5">
        <div
          :for={keyword <- @current_keywords}
          class={[
            "inline-flex items-center gap-1 px-2 py-1 text-xs font-medium rounded-full",
            "bg-teal-50 dark:bg-teal-900/30 text-teal-700 dark:text-teal-300",
            "border border-teal-200/60 dark:border-teal-700/40"
          ]}
        >
          <span>{format_keyword_label(keyword)}</span>
          <button
            type="button"
            aria-label={"Remove #{format_keyword_label(keyword)}"}
            class="p-0.5 rounded-full hover:bg-teal-200/60 dark:hover:bg-teal-800/50 transition-colors"
            phx-click="remove_keyword_filter"
            phx-value-keyword={keyword}
          >
            <.phx_icon name="hero-x-mark" class="h-3 w-3" />
          </button>
        </div>
      </div>

      <p
        :if={@current_keywords == []}
        class="text-xs text-slate-500 dark:text-slate-400"
      >
        No filters active. Posts with selected categories will be hidden.
      </p>
    </div>
    """
  end

  @doc """
  Author filter toggles for filtering by post source (your posts vs connections).
  """
  attr :current_filter, :atom, default: :all

  def author_filter_toggles(assigns) do
    ~H"""
    <div class="space-y-2">
      <.author_filter_option
        name="author_all"
        label="All posts"
        sublabel="Show posts from you and your connections"
        checked={@current_filter == :all}
        value="all"
      />

      <.author_filter_option
        name="author_mine"
        label="Your posts"
        sublabel="Only show posts you've created"
        checked={@current_filter == :mine}
        value="mine"
      />

      <.author_filter_option
        name="author_connections"
        label="Connections' posts"
        sublabel="Only show posts from your connections"
        checked={@current_filter == :connections}
        value="connections"
      />
    </div>
    """
  end

  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :sublabel, :string, default: nil
  attr :checked, :boolean, default: false
  attr :value, :string, required: true

  def author_filter_option(assigns) do
    ~H"""
    <label
      class={[
        "flex items-center gap-3 py-2 px-3 rounded-xl cursor-pointer transition-all duration-200",
        "border-2",
        if(@checked,
          do: "bg-emerald-50/80 dark:bg-emerald-900/30 border-emerald-300 dark:border-emerald-600",
          else:
            "bg-slate-50/50 dark:bg-slate-700/30 border-transparent hover:bg-slate-100/60 dark:hover:bg-slate-700/50"
        )
      ]}
      phx-click="set_author_filter"
      phx-value-filter={@value}
    >
      <input
        type="radio"
        name="author_filter"
        value={@value}
        checked={@checked}
        class="sr-only"
      />
      <div class={[
        "w-4 h-4 rounded-full border-2 flex items-center justify-center transition-all duration-200",
        if(@checked,
          do: "border-emerald-500 bg-emerald-500",
          else: "border-slate-300 dark:border-slate-500"
        )
      ]}>
        <div :if={@checked} class="w-1.5 h-1.5 rounded-full bg-white"></div>
      </div>
      <div class="flex-1 min-w-0">
        <span class={[
          "block text-sm font-medium transition-colors",
          if(@checked,
            do: "text-emerald-800 dark:text-emerald-200",
            else: "text-slate-700 dark:text-slate-300"
          )
        ]}>
          {@label}
        </span>
        <span
          :if={@sublabel}
          class="block text-[11px] text-slate-500 dark:text-slate-400 truncate"
        >
          {@sublabel}
        </span>
      </div>
    </label>
    """
  end

  @doc """
  Content warning filter toggles.
  """
  attr :current_settings, :map, default: %{}
  attr :mobile_friendly, :boolean, default: true

  def content_warning_toggles(assigns) do
    ~H"""
    <div class="space-y-2">
      <.compact_toggle
        name="hide_all_warnings"
        label="Hide all content warnings"
        sublabel="Completely hide posts with any content warning"
        checked={@current_settings[:hide_all] || false}
        phx_click="toggle_content_warning_filter"
        phx_value_type="hide_all"
      />

      <.compact_toggle
        name="hide_mature_content"
        label="Hide mature content (18+)"
        sublabel="Hide posts marked as mature or adult content"
        checked={@current_settings[:hide_mature] || false}
        phx_click="toggle_content_warning_filter"
        phx_value_type="hide_mature"
      />
    </div>
    """
  end

  @doc """
  Muted users management interface.
  """
  attr :muted_users, :list, default: []
  attr :mobile_friendly, :boolean, default: true
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key"
  attr :current_user, :any, default: nil, doc: "deprecated: use current_scope instead"
  attr :key, :any, default: nil, doc: "deprecated: use current_scope instead"

  def muted_users_list(assigns) do
    assigns =
      assigns
      |> assign_new(:current_user, fn ->
        case assigns[:current_scope] do
          %{user: user} -> user
          _ -> assigns[:current_user]
        end
      end)
      |> assign_new(:key, fn ->
        case assigns[:current_scope] do
          %{key: k} -> k
          _ -> assigns[:key]
        end
      end)

    ~H"""
    <div class="space-y-3">
      <div
        :if={@muted_users == []}
        class="flex items-center gap-2 py-3 px-3 rounded-lg bg-slate-50/50 dark:bg-slate-700/30"
      >
        <.phx_icon name="hero-check-circle" class="h-4 w-4 text-slate-400 dark:text-slate-500" />
        <span class="text-xs text-slate-500 dark:text-slate-400">
          No muted authors. Mute from any post menu.
        </span>
      </div>

      <div :if={@muted_users != []} class="space-y-1.5">
        <div
          :for={user <- @muted_users}
          class="flex items-center gap-2.5 p-2 rounded-lg bg-slate-50/50 dark:bg-slate-700/30 hover:bg-slate-100/60 dark:hover:bg-slate-700/50 transition-colors"
        >
          <MossletWeb.DesignSystem.liquid_avatar
            size="xs"
            name={user.username || "Unknown"}
            src={
              get_connection_avatar_src(
                get_uconn_for_muted_users(user, @current_user),
                @current_user,
                @key
              )
            }
            class="ring-1 ring-slate-200/60 dark:ring-slate-600/60"
          />
          <span class="flex-1 text-xs font-medium text-slate-700 dark:text-slate-300 truncate">
            {user.username || "Unknown User"}
          </span>
          <.phx_icon
            name="hero-bell-slash"
            class="h-3 w-3 text-slate-400 dark:text-slate-500"
          />
        </div>
      </div>

      <%!-- Manage link --%>
      <.link
        navigate="/app/users/connections"
        class="inline-flex items-center gap-1 text-xs font-medium text-teal-600 dark:text-teal-400 hover:text-teal-700 dark:hover:text-teal-300 transition-colors"
      >
        <.phx_icon name="hero-cog-6-tooth" class="h-3 w-3" />
        <span>Manage in Connections</span>
      </.link>
    </div>
    """
  end

  @doc """
  Compact toggle switch for filter sections.
  """
  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :sublabel, :string, default: nil
  attr :checked, :boolean, default: false
  attr :phx_click, :string, required: true
  attr :phx_value_type, :string, default: nil

  def compact_toggle(assigns) do
    ~H"""
    <label class="flex items-center justify-between gap-3 py-2 px-2 rounded-lg cursor-pointer hover:bg-slate-50/50 dark:hover:bg-slate-700/30 transition-colors group/toggle">
      <div class="flex-1 min-w-0">
        <span class="block text-sm font-medium text-slate-700 dark:text-slate-300 group-hover/toggle:text-slate-900 dark:group-hover/toggle:text-slate-100 transition-colors">
          {@label}
        </span>
        <span
          :if={@sublabel}
          class="block text-[11px] text-slate-500 dark:text-slate-400 truncate"
        >
          {@sublabel}
        </span>
      </div>

      <button
        type="button"
        class={[
          "relative inline-flex h-5 w-9 shrink-0 rounded-full transition-all duration-200",
          "focus:outline-none focus:ring-2 focus:ring-teal-500/40 focus:ring-offset-1 focus:ring-offset-white dark:focus:ring-offset-slate-800",
          if(@checked,
            do: "bg-gradient-to-r from-teal-500 to-cyan-500",
            else: "bg-slate-200 dark:bg-slate-600"
          )
        ]}
        phx-click={@phx_click}
        phx-value-type={@phx_value_type}
        role="switch"
        aria-checked={to_string(@checked)}
      >
        <span class={[
          "pointer-events-none inline-block h-3.5 w-3.5 transform rounded-full bg-white shadow transition-transform duration-200",
          "my-[3px]",
          if(@checked, do: "translate-x-[18px]", else: "translate-x-[3px]")
        ]}>
        </span>
      </button>
    </label>
    """
  end

  defp format_keyword_label(keyword) when is_binary(keyword) do
    case keyword do
      "violence" -> "Violence"
      "graphic" -> "Graphic Content"
      "mental_health" -> "Mental Health"
      "substance_use" -> "Substance Use"
      "sexual" -> "Sexual Content"
      "spoilers" -> "Spoilers"
      "politics" -> "Politics"
      "news" -> "News"
      "flashing" -> "Flashing/Strobing"
      "personal" -> "Personal/Sensitive"
      "other" -> "Other"
      _ -> String.capitalize(keyword)
    end
  end

  defp format_keyword_label(_), do: "Unknown"
end
