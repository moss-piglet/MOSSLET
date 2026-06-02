defmodule MossletWeb.PrivacyComponents do
  @moduledoc """
  Privacy and visibility control components.

  Extracted from `MossletWeb.DesignSystem` as part of the design system
  modularization (Phase 1).
  """
  use Phoenix.Component
  use MossletWeb, :verified_routes

  import MossletWeb.CoreComponents, only: [phx_icon: 1]

  import MossletWeb.Helpers,
    only: [
      get_encrypted_avatar_data: 2
    ]

  alias Phoenix.LiveView.JS

  @doc """
  Privacy level selector for posts with responsive design.
  Now keeps full text and chevron on both mobile and desktop since we have good responsive spacing.
  """
  attr :selected, :string, default: "connections"
  attr :compact, :boolean, default: false
  attr :class, :any, default: ""
  attr :rest, :global, include: ~w(phx-click phx-value-privacy)

  def liquid_privacy_selector(assigns) do
    ~H"""
    <div
      id={"privacy-selector-#{@selected}"}
      class={[
        "relative inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-sm",
        "bg-slate-100/80 dark:bg-slate-700/80 backdrop-blur-sm",
        "border border-slate-200/60 dark:border-slate-600/60",
        "hover:bg-slate-200/80 dark:hover:bg-slate-600/80",
        "transition-all duration-200 ease-out cursor-pointer",
        @class
      ]}
      phx-hook="TippyHook"
      data-tippy-content="Click to toggle privacy level"
      {@rest}
    >
      <.phx_icon
        name={privacy_icon(@selected)}
        class="h-4 w-4 text-slate-600 dark:text-slate-300 flex-shrink-0"
      />
      <%!-- Keep text but remove chevron for cleaner toggle UI --%>
      <span class="font-medium text-slate-700 dark:text-slate-200">
        {privacy_label(@selected)}
      </span>
    </div>
    """
  end

  @doc """
  Maps a privacy level string to its corresponding hero icon name.
  """
  def privacy_icon("public"), do: "hero-globe-alt"
  def privacy_icon("connections"), do: "hero-user-group"
  def privacy_icon("private"), do: "hero-lock-closed"
  def privacy_icon("specific_groups"), do: "hero-squares-2x2"
  def privacy_icon("specific_users"), do: "hero-user-plus"
  def privacy_icon(_), do: "hero-lock-closed"

  @doc """
  Maps a privacy level string to its display label.
  """
  def privacy_label("public"), do: "Public"
  def privacy_label("connections"), do: "Connections"
  def privacy_label("private"), do: "Private"
  def privacy_label("specific_groups"), do: "Groups"
  def privacy_label("specific_users"), do: "Specific"
  def privacy_label(_), do: "Private"

  @doc """
  Enhanced privacy controls component for composer with progressive disclosure.
  Follows existing patterns like content warning section with emerald theming.
  """
  attr :form, :any, required: true
  attr :selector, :string, required: true
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"
  attr :current_user, :any, default: nil, doc: "deprecated: use current_scope instead"
  attr :key, :any, default: nil, doc: "deprecated: use current_scope instead"
  attr :class, :any, default: ""

  def liquid_enhanced_privacy_controls(assigns) do
    assigns = MossletWeb.DesignSystem.assign_scope_fields(assigns)
    # Get visibility groups from current user if available
    visibility_groups =
      if is_map_key(assigns, :current_user) and is_map_key(assigns, :key) do
        Mosslet.Accounts.get_user_visibility_groups_with_connections(assigns.current_user)
      else
        []
      end

    # Get connections for specific user selection if available
    user_connections =
      if is_map_key(assigns, :current_user) do
        Mosslet.Accounts.filter_user_connections(%{}, assigns.current_user)
      else
        []
      end

    assigns =
      assign(assigns, visibility_groups: visibility_groups, user_connections: user_connections)

    ~H"""
    <div class={[
      "p-4 rounded-xl border transition-all duration-300 ease-out",
      "bg-emerald-50/50 dark:bg-emerald-900/20",
      "border-emerald-200/60 dark:border-emerald-700/50",
      @class
    ]}>
      <div class="flex items-center gap-2 mb-4">
        <.phx_icon
          name="hero-shield-check"
          class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
        />
        <span class="text-sm font-medium text-emerald-700 dark:text-emerald-300">
          Privacy Controls
        </span>
      </div>

      <div class="space-y-4">
        <%!-- Quick Visibility Options (Level 2) --%>
        <div class="space-y-3">
          <p class="text-xs font-medium text-emerald-700 dark:text-emerald-300 uppercase tracking-wide">
            Who can see this?
          </p>

          <div class="grid grid-cols-1 sm:grid-cols-3 gap-2">
            <%!-- Private Option --%>
            <.liquid_privacy_radio_option
              name="visibility"
              value="private"
              current_value={@selector}
              icon="hero-lock-closed"
              label="Private"
              description="Only you"
            />

            <%!-- Connections Option --%>
            <.liquid_privacy_radio_option
              name="visibility"
              value="connections"
              current_value={@selector}
              icon="hero-user-group"
              label="Connections"
              description="Your network"
            />

            <%!-- Public Option --%>
            <.liquid_privacy_radio_option
              name="visibility"
              value="public"
              current_value={@selector}
              icon="hero-globe-alt"
              label="Public"
              description="Everyone"
            />
          </div>

          <%!-- Advanced granular options (Level 3) --%>
          <div class="pt-2 border-t border-emerald-200/60 dark:border-emerald-700/30">
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
              <%!-- Specific Groups Option --%>
              <.liquid_privacy_radio_option
                name="visibility"
                value="specific_groups"
                current_value={@selector}
                icon="hero-squares-2x2"
                label="Specific Groups"
                description="Select groups"
              />

              <%!-- Specific Users Option --%>
              <.liquid_privacy_radio_option
                name="visibility"
                value="specific_users"
                current_value={@selector}
                icon="hero-user-plus"
                label="Specific People"
                description="Select individuals"
              />
            </div>

            <%!-- Group/User selection UI (when specific visibility is selected) --%>
            <div :if={@selector in ["specific_groups", "specific_users"]} class="mt-4">
              <%= if @selector == "specific_groups" do %>
                <%!-- Group selection interface with purple theme (groups = organization) --%>
                <div class="p-4 rounded-xl bg-gradient-to-br from-purple-50/80 via-violet-50/60 to-purple-50/80 dark:from-purple-900/25 dark:via-violet-900/20 dark:to-purple-900/25 border border-purple-200/60 dark:border-purple-700/40 shadow-sm shadow-purple-500/10 dark:shadow-purple-400/15">
                  <div class="flex items-center gap-3 mb-4">
                    <div class="p-2 rounded-lg bg-purple-100/80 dark:bg-purple-800/40 border border-purple-200/60 dark:border-purple-700/50">
                      <.phx_icon
                        name="hero-squares-2x2"
                        class="h-5 w-5 text-purple-600 dark:text-purple-400"
                      />
                    </div>
                    <div>
                      <p class="text-sm font-semibold text-purple-800 dark:text-purple-200">
                        Select Connection Groups
                      </p>
                      <p class="text-xs text-purple-600 dark:text-purple-400">
                        Share with organized groups of your connections
                      </p>
                    </div>
                  </div>
                  <div class="space-y-3">
                    <p class="text-sm text-purple-700 dark:text-purple-300 leading-relaxed">
                      Choose which of your connection groups can see this post. Groups help organize your connections by context like work colleagues, family members, or friend circles.
                    </p>
                    <%!-- Real group selection UI --%>
                    <%= if @visibility_groups != [] do %>
                      <div class="space-y-3">
                        <%= for group_data <- @visibility_groups do %>
                          <% group = group_data.group %>
                          <% decrypted_name =
                            MossletWeb.ConnectionComponents.get_decrypted_group_name(
                              group_data,
                              @current_user,
                              @key
                            ) %>
                          <% decrypted_description =
                            MossletWeb.ConnectionComponents.get_decrypted_group_description(
                              group_data,
                              @current_user,
                              @key
                            ) %>
                          <% connection_count = length(group_data.group.connection_ids || []) %>

                          <label class={[
                            "flex items-start gap-3 p-3 rounded-lg border transition-all duration-200 cursor-pointer",
                            MossletWeb.ConnectionComponents.get_group_card_classes(group.color)
                          ]}>
                            <input
                              type="checkbox"
                              name="post[visibility_groups][]"
                              value={group.id}
                              checked={group.id in (@form[:visibility_groups].value || [])}
                              class={[
                                "mt-1 h-4 w-4 rounded focus:ring-2 focus:ring-offset-2",
                                "text-#{MossletWeb.ConnectionComponents.connection_badge_color(group.color)}-600",
                                "focus:ring-#{MossletWeb.ConnectionComponents.connection_badge_color(group.color)}-500",
                                "border-#{MossletWeb.ConnectionComponents.connection_badge_color(group.color)}-300"
                              ]}
                            />
                            <div class="flex-1 min-w-0">
                              <div class="flex items-center gap-2 mb-1">
                                <!-- Group color indicator - preserve the user's chosen color -->
                                <div class={[
                                  "w-3 h-3 rounded-full flex-shrink-0",
                                  MossletWeb.ConnectionComponents.get_group_color_indicator_classes(
                                    group.color
                                  )
                                ]}>
                                </div>
                                <h5 class={[
                                  "text-sm font-medium truncate",
                                  "text-#{MossletWeb.ConnectionComponents.connection_badge_color(group.color)}-800 dark:text-#{MossletWeb.ConnectionComponents.connection_badge_color(group.color)}-200"
                                ]}>
                                  {decrypted_name}
                                </h5>
                                <!-- Group badge with group colors -->
                                <span class={[
                                  "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium flex-shrink-0",
                                  MossletWeb.ConnectionComponents.get_group_badge_classes(group.color)
                                ]}>
                                  {connection_count} {if connection_count == 1,
                                    do: "person",
                                    else: "people"}
                                </span>
                              </div>
                              <%= if decrypted_description != "" do %>
                                <p class={[
                                  "text-xs leading-relaxed",
                                  "text-#{MossletWeb.ConnectionComponents.connection_badge_color(group.color)}-600 dark:text-#{MossletWeb.ConnectionComponents.connection_badge_color(group.color)}-400"
                                ]}>
                                  {decrypted_description}
                                </p>
                              <% end %>
                            </div>
                          </label>
                        <% end %>
                      </div>
                    <% else %>
                      <div class="p-3 rounded-lg bg-purple-100/50 dark:bg-purple-800/30 border border-purple-200/60 dark:border-purple-700/40">
                        <div class="flex items-center gap-2 mb-2">
                          <.phx_icon
                            name="hero-plus-circle"
                            class="h-4 w-4 text-purple-600 dark:text-purple-400"
                          />
                          <span class="text-sm font-medium text-purple-700 dark:text-purple-300">
                            No Groups Created
                          </span>
                        </div>
                        <p class="text-sm text-purple-600 dark:text-purple-400 mb-3">
                          Create connection groups to organize your network and share with specific groups.
                        </p>
                        <a
                          href="/app/users/connections"
                          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium transition-all duration-200 bg-purple-600 text-white hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500/20"
                        >
                          <.phx_icon name="hero-plus" class="h-4 w-4" /> Create Groups
                        </a>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% else %>
                <%!-- User selection interface with amber theme (specific people = selective/exclusive) --%>
                <div class="p-4 rounded-xl bg-gradient-to-br from-amber-50/80 via-orange-50/60 to-amber-50/80 dark:from-amber-900/25 dark:via-orange-900/20 dark:to-amber-900/25 border border-amber-200/60 dark:border-amber-700/40 shadow-sm shadow-amber-500/10 dark:shadow-amber-400/15">
                  <div class="flex items-center gap-3 mb-4">
                    <div class="p-2 rounded-lg bg-amber-100/80 dark:bg-amber-800/40 border border-amber-200/60 dark:border-amber-700/50">
                      <.phx_icon
                        name="hero-user-plus"
                        class="h-5 w-5 text-amber-600 dark:text-amber-400"
                      />
                    </div>
                    <div>
                      <p class="text-sm font-semibold text-amber-800 dark:text-amber-200">
                        Select Specific People
                      </p>
                      <p class="text-xs text-amber-600 dark:text-amber-400">
                        Share with carefully chosen individuals
                      </p>
                    </div>
                  </div>
                  <div class="space-y-3">
                    <p class="text-sm text-amber-700 dark:text-amber-300 leading-relaxed">
                      Choose specific individuals from your connections who can see this post. Perfect for sharing personal content with just a select few people you trust.
                    </p>
                    <%!-- Real user selection UI --%>
                    <%= if @user_connections != [] do %>
                      <div class="space-y-3">
                        <div class="max-h-48 overflow-y-auto space-y-2">
                          <%= for connection <- @user_connections do %>
                            <% decrypted_name =
                              MossletWeb.ConnectionComponents.get_decrypted_connection_name(
                                connection,
                                @current_user,
                                @key
                              ) %>
                            <% decrypted_username =
                              MossletWeb.ConnectionComponents.get_decrypted_connection_username(
                                connection,
                                @current_user,
                                @key
                              ) %>
                            <% decrypted_label =
                              MossletWeb.ConnectionComponents.get_decrypted_connection_label(
                                connection,
                                @current_user,
                                @key
                              ) %>

                            <label class="flex items-center gap-3 p-3 rounded-lg border transition-all duration-200 cursor-pointer hover:bg-amber-50/50 dark:hover:bg-amber-900/30 border-amber-200/60 dark:border-amber-700/50">
                              <input
                                type="checkbox"
                                name="post[visibility_users][]"
                                value={
                                  MossletWeb.ConnectionComponents.get_connection_other_user_id(
                                    connection,
                                    @current_user
                                  )
                                }
                                checked={
                                  MossletWeb.ConnectionComponents.get_connection_other_user_id(
                                    connection,
                                    @current_user
                                  ) in (@form[
                                          :visibility_users
                                        ].value ||
                                          [])
                                }
                                class="h-4 w-4 text-amber-600 focus:ring-amber-500 border-amber-300 rounded"
                              />
                              <div class="flex-shrink-0">
                                <MossletWeb.CoreComponents.phx_avatar
                                  encrypted_avatar_data={get_encrypted_avatar_data(connection, @key)}
                                  id={"vis-user-#{connection.id}"}
                                  alt={decrypted_name}
                                  class="w-8 h-8 rounded-full border border-amber-200 dark:border-amber-700"
                                />
                              </div>
                              <div class="flex-1 min-w-0">
                                <div class="flex flex-col">
                                  <div class="flex items-center gap-2">
                                    <span class="text-sm font-medium text-amber-800 dark:text-amber-200 truncate">
                                      {decrypted_name}
                                    </span>
                                    <%= if decrypted_label != "" do %>
                                      <span class={[
                                        "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium flex-shrink-0",
                                        MossletWeb.ConnectionComponents.get_connection_color_badge_classes(
                                          connection.color
                                        )
                                      ]}>
                                        {decrypted_label}
                                      </span>
                                    <% end %>
                                  </div>
                                  <%= if decrypted_username && decrypted_username != "" do %>
                                    <span class={[
                                      "text-xs truncate",
                                      MossletWeb.ConnectionComponents.connection_username_color_classes(
                                        connection.color
                                      )
                                    ]}>
                                      @{decrypted_username}
                                    </span>
                                  <% end %>
                                </div>
                              </div>
                            </label>
                          <% end %>
                        </div>
                      </div>
                    <% else %>
                      <div class="p-3 rounded-lg bg-amber-100/50 dark:bg-amber-800/30 border border-amber-200/60 dark:border-amber-700/40">
                        <div class="flex items-center gap-2 mb-2">
                          <.phx_icon
                            name="hero-user-plus"
                            class="h-4 w-4 text-amber-600 dark:text-amber-400"
                          />
                          <span class="text-sm font-medium text-amber-700 dark:text-amber-300">
                            No Connections
                          </span>
                        </div>
                        <p class="text-sm text-amber-600 dark:text-amber-400 mb-3">
                          Connect with other users to share posts with specific people.
                        </p>
                        <a
                          href="/app/users/connections"
                          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium transition-all duration-200 bg-amber-600 text-white hover:bg-amber-700 focus:outline-none focus:ring-2 focus:ring-amber-500/20"
                        >
                          <.phx_icon name="hero-plus" class="h-4 w-4" /> Find Connections
                        </a>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <%!-- Interaction Controls (Level 2) --%>
        <div class="space-y-3">
          <p class="text-xs font-medium text-emerald-700 dark:text-emerald-300 uppercase tracking-wide">
            Interaction Controls
          </p>

          <div class="grid grid-cols-2 sm:grid-cols-3 gap-3">
            <%!-- Allow Replies --%>
            <MossletWeb.DesignSystem.liquid_checkbox
              field={@form[:allow_replies]}
              label="Replies"
              help="Others can reply"
            />

            <%!-- Allow Shares --%>
            <MossletWeb.DesignSystem.liquid_checkbox
              :if={@form[:is_ephemeral].value == false or @form[:is_ephemeral].value == "false"}
              field={@form[:allow_shares]}
              label="Sharing"
              help="Others can repost"
            />

            <%!-- Allow Bookmarks (with warning for ephemeral posts) --%>
            <div class="space-y-2">
              <MossletWeb.DesignSystem.liquid_checkbox
                field={@form[:allow_bookmarks]}
                label="Bookmarks"
                help="Others can save"
              />

              <%!-- Educational note for ephemeral + bookmarks --%>
              <div
                :if={
                  (@form[:is_ephemeral].value == true or @form[:is_ephemeral].value == "true") and
                    (@form[:allow_bookmarks].value == true or @form[:allow_bookmarks].value == "true")
                }
                class="ml-6 p-2 rounded-lg bg-amber-50/50 dark:bg-amber-900/20 border border-amber-200/60 dark:border-amber-700/30"
              >
                <div class="flex items-start gap-2">
                  <.phx_icon
                    name="hero-information-circle"
                    class="h-3 w-3 text-amber-600 dark:text-amber-400 mt-0.5 flex-shrink-0"
                  />
                  <p class="text-xs text-amber-700 dark:text-amber-300">
                    Bookmarks of this post will automatically be removed when the post expires.
                  </p>
                </div>
              </div>
            </div>
          </div>

          <%!-- Require Connection to Reply (only shown for public posts) --%>
          <div
            :if={@selector == "public"}
            class="mt-3 p-3 rounded-lg bg-emerald-100/60 dark:bg-emerald-800/30 border border-emerald-300/60 dark:border-emerald-600/40"
          >
            <div class="flex items-center gap-2 mb-2">
              <.phx_icon
                name="hero-shield-check"
                class="h-4 w-4 text-emerald-700 dark:text-emerald-300"
              />
              <span class="text-xs font-medium text-emerald-800 dark:text-emerald-200 uppercase tracking-wide">
                Public Post Security
              </span>
            </div>
            <MossletWeb.DesignSystem.liquid_checkbox
              field={@form[:require_follow_to_reply]}
              label="Require connection to reply"
              help="Only your confirmed connections can reply to this public post"
            />
          </div>
        </div>

        <%!-- Additional Controls (Level 2) --%>
        <div class="space-y-3">
          <p class="text-xs font-medium text-emerald-700 dark:text-emerald-300 uppercase tracking-wide">
            Additional Options
          </p>

          <div class="grid grid-cols-1 gap-3">
            <%!-- Temporary Post --%>
            <MossletWeb.DesignSystem.liquid_checkbox
              field={@form[:is_ephemeral]}
              label="Ephemeral post"
              help="Auto-delete after time limit"
            />

            <%!-- Mature Content Toggle (available independent of content warnings) --%>
            <MossletWeb.DesignSystem.liquid_checkbox
              field={@form[:mature_content]}
              label="Mature content (18+)"
              help="Mark this content as mature/adult content"
            />
          </div>

          <%!-- Expiration Controls (when ephemeral is enabled) --%>
          <div
            :if={@form[:is_ephemeral].value == true or @form[:is_ephemeral].value == "true"}
            class="mt-3 p-3 rounded-lg bg-amber-50/50 dark:bg-amber-900/20 border border-amber-200/60 dark:border-amber-700/30"
          >
            <div class="flex items-center gap-2 mb-3">
              <.phx_icon
                name="hero-clock"
                class="h-4 w-4 text-amber-600 dark:text-amber-400"
              />
              <span class="text-xs font-medium text-amber-700 dark:text-amber-300 uppercase tracking-wide">
                Auto-deletion Settings
              </span>
            </div>

            <%!-- Educational prompt for public ephemeral posts --%>
            <div
              :if={@selector == "public"}
              class="mb-4 p-3 rounded-lg bg-emerald-100/60 dark:bg-emerald-800/30 border border-emerald-300/60 dark:border-emerald-600/40"
            >
              <div class="flex items-start gap-2">
                <.phx_icon
                  name="hero-information-circle"
                  class="h-4 w-4 text-emerald-700 dark:text-emerald-300 mt-0.5 flex-shrink-0"
                />
                <div class="text-sm text-emerald-800 dark:text-emerald-200">
                  <strong>Public ephemeral post:</strong>
                  This will appear in public feeds but automatically delete.
                  Others may still screenshot or save the content before deletion. Minimum 24 hours for public accountability.
                </div>
              </div>
            </div>

            <MossletWeb.DesignSystem.liquid_select_custom
              field={@form[:expires_at_option]}
              label="Delete after"
              prompt="Select timeframe..."
              color="amber"
              class="text-sm"
              options={
                if @selector == "public" do
                  [
                    {"24 hours", "24_hours"},
                    {"7 days", "7_days"},
                    {"30 days", "30_days"}
                  ]
                else
                  [
                    {"1 hour", "1_hour"},
                    {"6 hours", "6_hours"},
                    {"24 hours", "24_hours"},
                    {"7 days", "7_days"},
                    {"30 days", "30_days"}
                  ]
                end
              }
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Radio option component for privacy selection.
  Follows existing liquid metal patterns with compact design for composer.
  """
  attr :name, :string, required: true
  attr :value, :string, required: true
  attr :current_value, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :description, :string, required: true

  def liquid_privacy_radio_option(assigns) do
    assigns = assign(assigns, :checked, assigns.value == assigns.current_value)

    ~H"""
    <label class={[
      "group relative cursor-pointer overflow-hidden rounded-lg p-3 transition-all duration-200 ease-out",
      "border-2 hover:scale-[1.02] focus-within:scale-[1.02]",
      if(@checked,
        do: "border-emerald-300 dark:border-emerald-600 bg-emerald-50/50 dark:bg-emerald-900/20",
        else:
          "border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800/50 hover:border-emerald-200 dark:hover:border-emerald-700"
      )
    ]}>
      <%!-- Liquid background effect --%>
      <div class={[
        "absolute inset-0 opacity-0 transition-all duration-300 ease-out",
        "bg-gradient-to-br from-emerald-50/30 via-emerald-100/20 to-emerald-50/30",
        "dark:from-emerald-900/15 dark:via-emerald-800/10 dark:to-emerald-900/15",
        if(@checked, do: "opacity-100 group-hover:opacity-100", else: "group-hover:opacity-100")
      ]}>
      </div>

      <%!-- Shimmer effect --%>
      <div class={[
        "absolute inset-0 opacity-0 transition-all duration-500 ease-out",
        "bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent",
        "dark:via-emerald-400/15 group-hover:opacity-100 group-hover:translate-x-full -translate-x-full"
      ]}>
      </div>

      <div class="relative flex flex-col items-center text-center gap-2">
        <%!-- Radio input --%>
        <input
          type="radio"
          name={@name}
          value={@value}
          checked={@checked}
          class="sr-only"
          phx-click="update_privacy_visibility"
          phx-value-visibility={@value}
        />

        <%!-- Icon --%>
        <div class={[
          "p-2 rounded-lg transition-all duration-200 ease-out",
          if(@checked,
            do: "bg-emerald-100 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400",
            else:
              "bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-400 group-hover:bg-emerald-100 dark:group-hover:bg-emerald-900/30 group-hover:text-emerald-600 dark:group-hover:text-emerald-400"
          )
        ]}>
          <.phx_icon name={@icon} class="h-4 w-4" />
        </div>

        <%!-- Label --%>
        <div>
          <div class={[
            "text-sm font-medium transition-colors duration-200 ease-out",
            if(@checked,
              do: "text-emerald-700 dark:text-emerald-300",
              else:
                "text-slate-900 dark:text-slate-100 group-hover:text-emerald-700 dark:group-hover:text-emerald-300"
            )
          ]}>
            {@label}
          </div>
          <div class={[
            "text-xs transition-colors duration-200 ease-out",
            if(@checked,
              do: "text-emerald-600 dark:text-emerald-400",
              else: "text-slate-500 dark:text-slate-400"
            )
          ]}>
            {@description}
          </div>
        </div>
      </div>
    </label>
    """
  end

  @doc """
  Compact privacy controls with horizontal pill selector and inline options.
  More space-efficient than liquid_enhanced_privacy_controls.
  """
  attr :form, :any, required: true
  attr :selector, :string, required: true
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"
  attr :class, :any, default: ""

  def liquid_compact_privacy_controls(assigns) do
    assigns = MossletWeb.DesignSystem.assign_scope_fields(assigns)

    visibility_groups =
      if is_map_key(assigns, :current_user) and is_map_key(assigns, :key) do
        Mosslet.Accounts.get_user_visibility_groups_with_connections(assigns.current_user)
      else
        []
      end

    user_connections =
      if is_map_key(assigns, :current_user) do
        Mosslet.Accounts.filter_user_connections(%{}, assigns.current_user)
      else
        []
      end

    assigns =
      assign(assigns, visibility_groups: visibility_groups, user_connections: user_connections)

    ~H"""
    <div class={[
      "p-3 rounded-lg border transition-all duration-200",
      "bg-emerald-50/30 dark:bg-emerald-900/15",
      "border-emerald-200/50 dark:border-emerald-700/40",
      @class
    ]}>
      <div class="space-y-3">
        <%!-- Visibility Pills --%>
        <div class="space-y-1.5">
          <div class="flex items-center gap-1.5">
            <.phx_icon name="hero-eye" class="h-3.5 w-3.5 text-emerald-600 dark:text-emerald-400" />
            <span class="text-xs font-medium text-emerald-700 dark:text-emerald-300">Visibility</span>
          </div>
          <div class="flex flex-wrap gap-1">
            <.privacy_pill
              value="private"
              current={@selector}
              icon="hero-lock-closed"
              label="Private"
            />
            <.privacy_pill
              value="connections"
              current={@selector}
              icon="hero-user-group"
              label="Connections"
            />
            <.privacy_pill value="public" current={@selector} icon="hero-globe-alt" label="Public" />
            <.privacy_pill
              value="specific_groups"
              current={@selector}
              icon="hero-squares-2x2"
              label="Groups"
            />
            <.privacy_pill
              value="specific_users"
              current={@selector}
              icon="hero-users"
              label="People"
            />
          </div>
        </div>

        <%!-- Group/User Selection (collapsible) --%>
        <div
          :if={@selector in ["specific_groups", "specific_users"]}
          class="pt-2 border-t border-emerald-200/40 dark:border-emerald-700/30"
        >
          <%= if @selector == "specific_groups" do %>
            <.compact_group_selector
              groups={@visibility_groups}
              form={@form}
              current_scope={@current_scope}
            />
          <% else %>
            <.compact_user_selector
              connections={@user_connections}
              form={@form}
              current_scope={@current_scope}
            />
          <% end %>
        </div>

        <%!-- Inline Options Row --%>
        <div class="pt-2 border-t border-emerald-200/40 dark:border-emerald-700/30">
          <div class="flex flex-wrap items-center gap-x-4 gap-y-2">
            <.compact_toggle
              field={@form[:allow_replies]}
              label="Replies"
              icon="hero-chat-bubble-left"
            />
            <.compact_toggle
              :if={@form[:is_ephemeral].value == false or @form[:is_ephemeral].value == "false"}
              field={@form[:allow_shares]}
              label="Shares"
              icon="hero-arrow-path-rounded-square"
            />
            <.compact_toggle field={@form[:allow_bookmarks]} label="Saves" icon="hero-bookmark" />
            <.compact_toggle
              field={@form[:is_ephemeral]}
              label="Ephemeral"
              icon="hero-clock"
              color="amber"
            />
          </div>
        </div>

        <%!-- Public post security --%>
        <div
          :if={@selector == "public"}
          class="pt-2 border-t border-emerald-200/40 dark:border-emerald-700/30"
        >
          <.compact_toggle
            field={@form[:require_follow_to_reply]}
            label="Require connection to reply"
            icon="hero-shield-check"
          />
        </div>

        <%!-- Ephemeral settings --%>
        <div
          :if={@form[:is_ephemeral].value == true or @form[:is_ephemeral].value == "true"}
          class="pt-2 border-t border-amber-200/40 dark:border-amber-700/30"
        >
          <div class="flex items-center gap-2">
            <.phx_icon name="hero-clock" class="h-3.5 w-3.5 text-amber-600 dark:text-amber-400" />
            <span class="text-xs text-amber-700 dark:text-amber-300">Delete after:</span>
            <select
              name={@form[:expires_at_option].name}
              id={@form[:expires_at_option].id}
              aria-label="Delete after"
              class="text-xs py-1 pl-2 pr-6 rounded border border-amber-200 dark:border-amber-700 bg-amber-50 dark:bg-amber-900/30 text-amber-800 dark:text-amber-200 focus:ring-1 focus:ring-amber-400"
            >
              <%= if @selector == "public" do %>
                <option
                  value="24_hours"
                  selected={
                    @form[:expires_at_option].value in [nil, "", "24_hours", "1_hour", "6_hours"]
                  }
                >
                  24 hours
                </option>
                <option value="7_days" selected={@form[:expires_at_option].value == "7_days"}>
                  7 days
                </option>
                <option value="30_days" selected={@form[:expires_at_option].value == "30_days"}>
                  30 days
                </option>
              <% else %>
                <option
                  value="1_hour"
                  selected={@form[:expires_at_option].value in [nil, "", "1_hour"]}
                >
                  1 hour
                </option>
                <option value="6_hours" selected={@form[:expires_at_option].value == "6_hours"}>
                  6 hours
                </option>
                <option value="24_hours" selected={@form[:expires_at_option].value == "24_hours"}>
                  24 hours
                </option>
                <option value="7_days" selected={@form[:expires_at_option].value == "7_days"}>
                  7 days
                </option>
                <option value="30_days" selected={@form[:expires_at_option].value == "30_days"}>
                  30 days
                </option>
              <% end %>
            </select>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :value, :string, required: true
  attr :current, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true

  defp privacy_pill(assigns) do
    assigns = assign(assigns, :selected, assigns.value == assigns.current)

    ~H"""
    <label class={[
      "inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium cursor-pointer transition-all duration-150",
      if(@selected,
        do: "bg-emerald-600 text-white shadow-sm",
        else:
          "bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300 border border-slate-200 dark:border-slate-600 hover:border-emerald-300 dark:hover:border-emerald-600"
      )
    ]}>
      <input
        type="radio"
        name="visibility"
        value={@value}
        checked={@selected}
        class="sr-only"
        phx-click="update_privacy_visibility"
        phx-value-visibility={@value}
      />
      <.phx_icon name={@icon} class="h-3 w-3" />
      <span>{@label}</span>
    </label>
    """
  end

  attr :field, :any, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :color, :string, default: "emerald"

  defp compact_toggle(assigns) do
    value = assigns.field.value
    checked = value == true or value == "true" or value == "on"
    assigns = assign(assigns, :checked, checked)

    ~H"""
    <label class={[
      "inline-flex items-center gap-1.5 px-2 py-1 rounded-md text-xs cursor-pointer transition-all duration-150",
      if(@checked,
        do: [
          "bg-#{@color}-100 dark:bg-#{@color}-900/40 text-#{@color}-700 dark:text-#{@color}-300",
          "border border-#{@color}-300 dark:border-#{@color}-600"
        ],
        else:
          "text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800"
      )
    ]}>
      <input type="hidden" name={@field.name} value="false" />
      <input
        type="checkbox"
        name={@field.name}
        value="true"
        checked={@checked}
        class="sr-only"
      />
      <.phx_icon name={@icon} class="h-3 w-3" />
      <span>{@label}</span>
    </label>
    """
  end

  attr :field, :any, required: true

  def mature_content_toggle(assigns) do
    value = assigns.field.value
    checked = value == true or value == "true" or value == "on"
    assigns = assign(assigns, :checked, checked)

    ~H"""
    <label class={[
      "flex items-center gap-2.5 w-full px-3 py-2.5 rounded-lg cursor-pointer transition-all duration-200",
      "border-2",
      if(@checked,
        do: [
          "bg-gradient-to-r from-amber-50 to-orange-50 dark:from-amber-900/30 dark:to-orange-900/30",
          "border-amber-400 dark:border-amber-500",
          "shadow-md shadow-amber-500/20"
        ],
        else: [
          "bg-slate-50/50 dark:bg-slate-800/50 hover:bg-amber-50/50 dark:hover:bg-amber-900/20",
          "border-slate-200 dark:border-slate-700 hover:border-amber-300 dark:hover:border-amber-600"
        ]
      )
    ]}>
      <input type="hidden" name={@field.name} value="false" />
      <input
        type="checkbox"
        name={@field.name}
        value="true"
        checked={@checked}
        class="sr-only"
      />
      <div class={[
        "flex items-center justify-center w-8 h-8 rounded-full transition-all duration-200",
        if(@checked,
          do: "bg-amber-500 text-white shadow-sm",
          else: "bg-slate-200 dark:bg-slate-700 text-slate-500 dark:text-slate-400"
        )
      ]}>
        <.phx_icon name="hero-exclamation-triangle" class="h-4 w-4" />
      </div>
      <div class="flex flex-col">
        <span class={[
          "text-sm font-semibold transition-colors",
          if(@checked,
            do: "text-amber-700 dark:text-amber-300",
            else: "text-slate-700 dark:text-slate-300"
          )
        ]}>
          18+ Mature Content
        </span>
        <span class="text-[11px] text-slate-500 dark:text-slate-400">
          Mark as adult-only content
        </span>
      </div>
      <div class={[
        "ml-auto flex items-center justify-center w-6 h-6 rounded-full transition-all duration-200",
        if(@checked,
          do: "bg-amber-500 text-white",
          else: "bg-slate-200 dark:bg-slate-700"
        )
      ]}>
        <.phx_icon
          name={if(@checked, do: "hero-check", else: "hero-plus")}
          class="h-3.5 w-3.5"
        />
      </div>
    </label>
    """
  end

  attr :groups, :list, required: true
  attr :form, :any, required: true
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"

  defp compact_group_selector(assigns) do
    assigns = MossletWeb.DesignSystem.assign_scope_fields(assigns)

    ~H"""
    <div class="space-y-2">
      <p class="text-xs text-purple-700 dark:text-purple-300">Select groups:</p>
      <%= if @groups != [] do %>
        <div class="flex flex-wrap gap-1.5 max-h-32 overflow-y-auto">
          <%= for group_data <- @groups do %>
            <% group = group_data.group %>
            <% decrypted_name =
              MossletWeb.ConnectionComponents.get_decrypted_group_name(
                group_data,
                @current_scope.user,
                @current_scope.key
              ) %>
            <% selected = group.id in (@form[:visibility_groups].value || []) %>
            <label class={[
              "inline-flex items-center gap-1.5 px-2 py-1 rounded-full text-xs cursor-pointer transition-all",
              if(selected,
                do: "bg-purple-600 text-white",
                else:
                  "bg-purple-50 dark:bg-purple-900/30 text-purple-700 dark:text-purple-300 border border-purple-200 dark:border-purple-700 hover:bg-purple-100"
              )
            ]}>
              <input
                type="checkbox"
                name="post[visibility_groups][]"
                value={group.id}
                checked={selected}
                class="sr-only"
              />
              <div class={[
                "w-2 h-2 rounded-full",
                MossletWeb.ConnectionComponents.get_group_color_indicator_classes(group.color)
              ]}>
              </div>
              <span>{decrypted_name}</span>
            </label>
          <% end %>
        </div>
      <% else %>
        <p class="text-xs text-purple-600 dark:text-purple-400">
          <a href="/app/users/connections" class="underline hover:no-underline">Create groups</a>
          to share with specific groups.
        </p>
      <% end %>
    </div>
    """
  end

  attr :connections, :list, required: true
  attr :form, :any, required: true
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"

  defp compact_user_selector(assigns) do
    assigns = MossletWeb.DesignSystem.assign_scope_fields(assigns)

    ~H"""
    <div class="space-y-2">
      <p class="text-xs text-amber-700 dark:text-amber-300">Select people:</p>
      <%= if @connections != [] do %>
        <div class="flex flex-wrap gap-1.5 max-h-32 overflow-y-auto">
          <%= for connection <- @connections do %>
            <% decrypted_name =
              MossletWeb.ConnectionComponents.get_decrypted_connection_name(
                connection,
                @current_scope.user,
                @current_scope.key
              ) %>
            <% user_id =
              MossletWeb.ConnectionComponents.get_connection_other_user_id(
                connection,
                @current_scope.user
              ) %>
            <% selected = user_id in (@form[:visibility_users].value || []) %>
            <label class={[
              "inline-flex items-center gap-1.5 px-2 py-1 rounded-full text-xs cursor-pointer transition-all",
              if(selected,
                do: "bg-amber-600 text-white",
                else:
                  "bg-amber-50 dark:bg-amber-900/30 text-amber-700 dark:text-amber-300 border border-amber-200 dark:border-amber-700 hover:bg-amber-100"
              )
            ]}>
              <input
                type="checkbox"
                name="post[visibility_users][]"
                value={user_id}
                checked={selected}
                class="sr-only"
              />
              <MossletWeb.CoreComponents.phx_avatar
                encrypted_avatar_data={get_encrypted_avatar_data(connection, @current_scope.key)}
                id={"compact-vis-#{connection.id}"}
                alt={decrypted_name}
                class="w-4 h-4 rounded-full"
                size="w-4 h-4"
              />
              <span>{decrypted_name}</span>
            </label>
          <% end %>
        </div>
      <% else %>
        <p class="text-xs text-amber-600 dark:text-amber-400">
          <a href="/app/users/connections" class="underline hover:no-underline">Add connections</a>
          to share with specific people.
        </p>
      <% end %>
    </div>
    """
  end

  attr :active, :boolean, required: true
  attr :countdown, :integer, default: 0
  attr :needs_password, :boolean, default: false
  attr :on_activate, :string, default: "activate_privacy"
  attr :on_reveal, :string, default: "reveal_content"
  attr :on_password_submit, :string, default: "verify_privacy_password"
  attr :privacy_form, Phoenix.HTML.Form, default: nil

  def privacy_screen(assigns) do
    ~H"""
    <div
      :if={@active}
      id="privacy-screen"
      phx-hook="LockBodyScroll"
      class="fixed inset-0 z-50 flex items-center justify-center overflow-y-auto overscroll-contain bg-gradient-to-br from-slate-50 via-stone-50 to-slate-100 dark:from-slate-900 dark:via-slate-900 dark:to-slate-800"
    >
      <div class="absolute inset-0 overflow-hidden pointer-events-none">
        <div class="absolute top-1/4 left-1/4 w-96 h-96 rounded-full bg-gradient-to-br from-teal-200/20 to-emerald-200/20 dark:from-teal-800/10 dark:to-emerald-800/10 blur-3xl animate-pulse" />
        <div class="absolute bottom-1/4 right-1/4 w-80 h-80 rounded-full bg-gradient-to-br from-emerald-200/20 to-cyan-200/20 dark:from-emerald-800/10 dark:to-cyan-800/10 blur-3xl animate-pulse [animation-delay:1s]" />
        <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-64 h-64 rounded-full bg-gradient-to-br from-slate-200/30 to-slate-300/30 dark:from-slate-700/20 dark:to-slate-600/20 blur-2xl" />
      </div>

      <div class="relative text-center px-6 py-6 sm:py-8 max-w-md my-auto">
        <div class="mb-4 sm:mb-8">
          <div class="relative inline-flex items-center justify-center w-16 h-16 sm:w-24 sm:h-24 rounded-2xl sm:rounded-3xl bg-gradient-to-br from-slate-100 via-slate-50 to-slate-100 dark:from-slate-800 dark:via-slate-700 dark:to-slate-800 shadow-lg border border-slate-200/50 dark:border-slate-700/50">
            <div class="absolute inset-0 rounded-2xl sm:rounded-3xl bg-gradient-to-br from-teal-500/5 to-emerald-500/5 dark:from-teal-400/10 dark:to-emerald-400/10" />
            <MossletWeb.CoreComponents.phx_icon
              name="hero-eye-slash"
              class="h-8 w-8 sm:h-12 sm:w-12 text-slate-400 dark:text-slate-500"
            />
          </div>
        </div>

        <h2 class="text-xl sm:text-2xl font-semibold text-slate-800 dark:text-slate-200 mb-2 sm:mb-3">
          Privacy Mode Active
        </h2>
        <p class="text-sm sm:text-base text-slate-600 dark:text-slate-400 mb-6 sm:mb-8 leading-relaxed">
          Your journal content is hidden for your privacy. Click the button below when you're ready to continue journaling.
        </p>

        <%= if @needs_password do %>
          <.privacy_password_form on_submit={@on_password_submit} form={@privacy_form} />
        <% else %>
          <button
            type="button"
            phx-click={@on_reveal}
            class="inline-flex items-center justify-center gap-3 px-8 py-4 text-base font-medium rounded-2xl transition-all duration-300 bg-gradient-to-r from-teal-500 to-emerald-500 text-white shadow-lg hover:shadow-xl hover:from-teal-600 hover:to-emerald-600 transform hover:scale-[1.02]"
          >
            <MossletWeb.CoreComponents.phx_icon name="hero-eye" class="h-5 w-5" />
            <%= if @countdown > 0 do %>
              <span>Reveal Content</span>
              <span class="tabular-nums font-mono text-white/80">
                ({format_countdown(@countdown)})
              </span>
            <% else %>
              <span>Reveal Content</span>
            <% end %>
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  attr :on_submit, :string, required: true
  attr :form, Phoenix.HTML.Form, required: true

  defp privacy_password_form(assigns) do
    ~H"""
    <div class="bg-white dark:bg-slate-800/80 rounded-2xl p-6 border border-slate-200 dark:border-slate-700 shadow-lg">
      <div class="flex items-center gap-2 mb-4">
        <MossletWeb.CoreComponents.phx_icon
          name="hero-lock-closed"
          class="h-5 w-5 text-amber-500"
        />
        <span class="text-sm font-medium text-slate-700 dark:text-slate-300">
          Enter your password to continue<span class="text-red-500">*</span>
        </span>
      </div>
      <.form for={@form} id="privacy-unlock-form" phx-submit={@on_submit} class="space-y-4">
        <div>
          <input
            type="password"
            name={@form[:password].name}
            id={@form[:password].id}
            placeholder="Your password"
            autocomplete="current-password"
            required
            class="w-full px-4 py-3 text-sm text-slate-900 dark:text-slate-100 bg-slate-50 dark:bg-slate-900/50 border border-slate-200 dark:border-slate-600 rounded-xl focus:ring-2 focus:ring-teal-500 focus:border-teal-500 transition-colors"
          />
        </div>
        <button
          type="submit"
          class="w-full px-6 py-3 text-sm font-medium text-white bg-gradient-to-r from-teal-500 to-emerald-500 rounded-xl shadow-sm hover:from-teal-600 hover:to-emerald-600 transition-all duration-200 cursor-pointer touch-manipulation active:scale-[0.98]"
        >
          Unlock Journal
        </button>
      </.form>
    </div>
    """
  end

  defp format_countdown(seconds) when seconds > 0 do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)

    "#{String.pad_leading(Integer.to_string(minutes), 2, "0")}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end

  defp format_countdown(_), do: "00:00"

  @doc """
  A markdown guide modal showing available markdown syntax and previews.

  ## Examples

      <.liquid_markdown_guide_modal
        id="markdown-guide-modal"
        show={@show_markdown_guide}
        on_cancel={JS.push("close_markdown_guide")}
      />
  """
  attr :id, :string, default: "markdown-guide-modal"
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}

  def liquid_markdown_guide_modal(assigns) do
    ~H"""
    <MossletWeb.DesignSystem.liquid_modal
      id={@id}
      show={@show}
      on_cancel={@on_cancel}
      size="lg"
    >
      <:title>
        <div class="flex items-center gap-3">
          <div class="p-2.5 rounded-xl bg-gradient-to-br from-emerald-100 to-teal-100 dark:from-emerald-900/30 dark:to-teal-900/30">
            <.phx_icon
              name="hero-document-text"
              class="h-5 w-5 text-emerald-600 dark:text-emerald-400"
            />
          </div>
          <div>
            <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
              Markdown Guide
            </h3>
            <p class="text-sm text-slate-600 dark:text-slate-400">
              Format your posts with style
            </p>
          </div>
        </div>
      </:title>

      <div class="space-y-5">
        <p class="text-sm text-slate-600 dark:text-slate-400">
          You can use markdown to format your posts. Here's a quick reference:
        </p>

        <div class="grid gap-4 sm:grid-cols-2">
          <.markdown_guide_section
            title="Text Formatting"
            items={[
              {"**bold**", "<strong>bold</strong>"},
              {"*italic*", "<em>italic</em>"},
              {"~~strike~~", "<s>strikethrough</s>"},
              {"^super^", "super<sup>script</sup>"}
            ]}
          />

          <.markdown_guide_section
            title="Headers"
            items={[
              {"# H1", "<span class='font-bold'>Heading 1</span>"},
              {"## H2", "<span class='font-semibold'>Heading 2</span>"},
              {"### H3", "<span class='font-medium'>Heading 3</span>"}
            ]}
          />

          <.markdown_guide_section
            title="Lists"
            items={[
              {"- item", "• bullet list"},
              {"1. item", "1. numbered list"},
              {"- [x] done", "☑ task list"}
            ]}
          />

          <.markdown_guide_section
            title="Links & Images"
            items={[
              {"[text](url)",
               "<span class='text-emerald-600 dark:text-emerald-400 underline'>link</span>"},
              {"![alt](url)", "🖼️ image"},
              {"auto-links",
               "<span class='text-emerald-600 dark:text-emerald-400'>urls → links</span>"}
            ]}
          />

          <.markdown_guide_section
            title="Code"
            items={[
              {"`code`",
               "<code class='px-1 py-0.5 rounded bg-slate-200 dark:bg-slate-600 text-xs'>inline</code>"},
              {"```lang block```",
               "<code class='px-1 py-0.5 rounded bg-slate-200 dark:bg-slate-600 text-xs'>syntax hl block</code>"}
            ]}
          />

          <.markdown_guide_section
            title="Other"
            items={[
              {"> quote",
               "<span class='border-l-2 border-emerald-400 pl-2 italic text-slate-600 dark:text-slate-400'>quote</span>"},
              {"---", "<span class='text-slate-400'>───</span> divider"},
              {"| table |", "📊 tables"}
            ]}
          />
        </div>

        <div class="pt-3 border-t border-slate-200/60 dark:border-slate-700/60">
          <p class="text-xs text-slate-500 dark:text-slate-400">
            <span class="font-medium text-emerald-600 dark:text-emerald-400">Tip:</span>
            URLs auto-link and code blocks have syntax highlighting.
          </p>
        </div>
      </div>
    </MossletWeb.DesignSystem.liquid_modal>
    """
  end

  attr :title, :string, required: true
  attr :items, :list, required: true

  defp markdown_guide_section(assigns) do
    ~H"""
    <div class="rounded-xl border border-slate-200/60 dark:border-slate-700/60 overflow-hidden">
      <div class="px-3 py-2 bg-gradient-to-r from-slate-50 to-slate-100/50 dark:from-slate-800/80 dark:to-slate-800/40 border-b border-slate-200/60 dark:border-slate-700/60">
        <h4 class="text-sm font-semibold text-slate-700 dark:text-slate-300">{@title}</h4>
      </div>
      <div class="divide-y divide-slate-100 dark:divide-slate-700/50 bg-white/50 dark:bg-slate-800/30">
        <div
          :for={{syntax, preview} <- @items}
          class="px-3 py-2 flex items-center justify-between gap-4"
        >
          <code class="text-xs font-mono text-emerald-700 dark:text-emerald-300 bg-emerald-50 dark:bg-emerald-900/30 px-1.5 py-0.5 rounded flex-shrink-0">
            {syntax}
          </code>
          <div class="text-sm text-slate-600 dark:text-slate-400 text-right">
            {Phoenix.HTML.raw(preview)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  A small icon button to trigger the markdown guide modal.

  ## Examples

      <.liquid_markdown_guide_trigger on_click={JS.push("open_markdown_guide")} />
      <.liquid_markdown_guide_trigger on_click={JS.push("open_markdown_guide")} size="sm" />
  """
  attr :id, :string, default: "markdown-guide-trigger"
  attr :on_click, JS, default: %JS{}
  attr :size, :string, default: "md", values: ~w(sm md)
  attr :class, :any, default: ""

  def liquid_markdown_guide_trigger(assigns) do
    ~H"""
    <button
      type="button"
      id={@id}
      phx-click={@on_click}
      phx-hook="TippyHook"
      data-tippy-content="Markdown formatting guide"
      aria-label="Markdown formatting guide"
      class={[
        "rounded-lg text-slate-500 dark:text-slate-400",
        "hover:text-emerald-600 dark:hover:text-emerald-400",
        "hover:bg-emerald-50/50 dark:hover:bg-emerald-900/20",
        "transition-all duration-200 ease-out group",
        if(@size == "sm", do: "p-1.5", else: "p-2"),
        @class
      ]}
    >
      <.phx_icon
        name="hero-document-text"
        class={[
          "transition-transform duration-200 group-hover:scale-110",
          if(@size == "sm", do: "h-4 w-4", else: "h-5 w-5")
        ]}
      />
    </button>
    """
  end

  attr :active, :boolean, required: true
  attr :countdown, :integer, default: 0
  attr :on_click, :string, default: "activate_privacy"

  def privacy_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={@on_click}
      id="privacy-button"
      phx-hook="TippyHook"
      data-tippy-content={if @active, do: "Privacy mode active", else: "Hide content quickly"}
      class={[
        "inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium rounded-xl border shadow-sm transition-all duration-200",
        if(@active,
          do:
            "text-amber-700 dark:text-amber-300 bg-amber-50 dark:bg-amber-900/30 border-amber-200 dark:border-amber-700",
          else:
            "text-slate-500 dark:text-slate-400 bg-white dark:bg-slate-800 border-slate-200 dark:border-slate-700 hover:text-teal-600 dark:hover:text-teal-400 hover:border-teal-300 dark:hover:border-teal-600"
        )
      ]}
    >
      <MossletWeb.CoreComponents.phx_icon
        name={if @active, do: "hero-eye-slash", else: "hero-eye-slash"}
        class="h-5 w-5"
      />
      <span class="sr-only">
        {if @active, do: "Privacy mode active", else: "Hide content quickly"}
      </span>
      <%= if @active && @countdown > 0 do %>
        <span class="tabular-nums text-xs font-mono">{format_countdown(@countdown)}</span>
      <% end %>
    </button>
    """
  end
end
