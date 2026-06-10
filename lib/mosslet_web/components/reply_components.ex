defmodule MossletWeb.ReplyComponents do
  @moduledoc """
  Reply thread and nested reply components.

  Extracted from `MossletWeb.DesignSystem` as part of the design system
  modularization (Phase 1).
  """
  use Phoenix.Component
  use MossletWeb, :verified_routes

  import MossletWeb.CoreComponents, only: [phx_icon: 1, phx_input: 1]

  import MossletWeb.DesignSystem,
    only: [
      liquid_avatar: 1,
      liquid_button: 1,
      liquid_dropdown: 1,
      liquid_modal: 1
    ]

  import MossletWeb.TimelineComponents, only: [liquid_timeline_action: 1]

  import MossletWeb.Helpers,
    only: [
      format_decrypted_content: 1,
      decr_item: 6,
      get_encrypted_avatar_data: 2,
      get_reply_post_key: 2,
      get_safe_reply_author_name: 3,
      get_reply_author_name_placeholder: 2,
      is_connected_to_reply_author?: 2,
      show_avatar?: 1,
      get_uconn_for_shared_item: 2,
      mosslet_logo_for_theme: 0,
      soft_like_text: 2
    ]

  import MossletWeb.Helpers.StatusHelpers,
    only: [
      get_user_status_info: 3,
      get_user_status_message: 3
    ]

  alias Mosslet.Accounts
  alias Mosslet.Timeline
  alias Phoenix.LiveView.JS

  @doc """
  Collapsible reply thread display component.

  ## Examples

      <.liquid_collapsible_reply_thread
        post_id={@post.id}
        replies={@post.replies || []}
        reply_count={Map.get(@stats, :replies, 0)}
        show={true}
        current_scope={@current_scope}
        class="mt-3"
      />
  """
  attr :post_id, :string, required: true
  attr :replies, :list, default: []
  attr :show, :boolean, default: false
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"
  attr :reply_count, :integer, default: 0
  attr :unread_nested_replies_by_parent, :map, default: %{}
  attr :calm_notifications, :boolean, default: false
  attr :class, :any, default: ""

  attr :browser_decrypt, :boolean, default: false
  attr :sealed_post_key, :string, default: nil

  def liquid_collapsible_reply_thread(assigns) do
    assigns = MossletWeb.DesignSystem.assign_scope_fields(assigns)

    ~H"""
    <div
      id={"reply-thread-#{@post_id}"}
      data-browser-decrypt={if @browser_decrypt, do: "true"}
      data-sealed-post-key={@sealed_post_key}
      data-show-js={
        JS.show(
          to: "#reply-thread-#{@post_id}",
          transition: {"nested-reply-expand-enter", "", ""},
          time: 300
        )
      }
      class={[
        "hidden",
        @class
      ]}
    >
      <div class="pt-4 border-t border-slate-200/50 dark:border-slate-700/50">
        <%!-- Thread header --%>
        <div class="flex items-center gap-2 mb-4 pl-4">
          <div class="w-6 h-px bg-gradient-to-r from-emerald-300 to-teal-300 dark:from-emerald-600 dark:to-teal-600">
          </div>
          <.phx_icon
            name="hero-chat-bubble-left-ellipsis"
            class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
          />
          <span class="text-sm font-medium text-emerald-700 dark:text-emerald-300">
            {if @reply_count == 1, do: "1 reply", else: "#{@reply_count} replies"}
          </span>
        </div>

        <%!-- Reply list with proper nested threading (only top-level replies) --%>
        <div class="space-y-4 pl-4 sm:pl-6 relative">
          <%!-- Main thread connection line --%>
          <div class="absolute left-0 sm:left-2 top-0 bottom-0 w-px bg-gradient-to-b from-emerald-300/60 via-teal-400/40 to-transparent dark:from-emerald-400/60 dark:via-teal-500/40">
          </div>

          <%!-- Render only top-level replies (those without a parent) --%>
          <div
            :for={reply <- filter_top_level_replies(@replies)}
            class="reply-item relative"
            data-user-id={reply.user_id}
          >
            <%!-- Individual reply connection --%>
            <div class="absolute -left-4 sm:-left-6 top-6 w-3 sm:w-4 h-px bg-gradient-to-r from-emerald-300/60 to-transparent dark:from-emerald-400/60">
            </div>

            <.liquid_nested_reply_item
              reply={reply}
              current_scope={@current_scope}
              depth={0}
              max_depth={3}
              post_id={@post_id}
              browser_decrypt={@browser_decrypt}
              sealed_post_key={@sealed_post_key}
              unread_nested_replies_by_parent={@unread_nested_replies_by_parent}
              calm_notifications={@calm_notifications}
            />
          </div>

          <%!-- Load more replies if needed --%>
          <div :if={@reply_count > count_loaded_replies(@replies)} class="pt-2">
            <.liquid_button
              variant="ghost"
              size="sm"
              color="emerald"
              phx-click="load_more_replies"
              phx-value-post-id={@post_id}
              class="text-emerald-600 dark:text-emerald-400"
            >
              Load {min(@reply_count - count_loaded_replies(@replies), 5)} more replies
            </.liquid_button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Nested reply item with recursive rendering for threading.
  """
  attr :reply, :map, required: true
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"
  attr :depth, :integer, default: 0
  attr :max_depth, :integer, default: 3
  attr :post_id, :string, default: nil
  attr :browser_decrypt, :boolean, default: false
  attr :sealed_post_key, :string, default: nil
  attr :unread_nested_replies_by_parent, :map, default: %{}
  attr :calm_notifications, :boolean, default: false
  attr :class, :any, default: ""

  def liquid_nested_reply_item(assigns) do
    assigns = MossletWeb.DesignSystem.assign_scope_fields(assigns)

    ~H"""
    <div class={[
      "nested-reply-container",
      @class
    ]}>
      <%!-- Render the current reply --%>
      <.liquid_reply_item
        reply={@reply}
        current_scope={@current_scope}
        depth={@depth}
        post_id={@post_id}
        browser_decrypt={@browser_decrypt}
        sealed_post_key={@sealed_post_key}
      />

      <%!-- Collapse/Expand toggle for nested replies --%>
      <div :if={@depth < @max_depth and has_child_replies?(@reply)} class="mt-2">
        <button
          type="button"
          id={"nested-toggle-#{@reply.id}"}
          phx-click={
            toggle_nested_replies(
              @reply.id,
              @post_id,
              if(@calm_notifications,
                do: Map.get(@unread_nested_replies_by_parent, @reply.id, 0),
                else: 0
              )
            )
          }
          phx-click-away-mark-read={
            if @calm_notifications && Map.get(@unread_nested_replies_by_parent, @reply.id, 0) > 0,
              do: "mark_nested_replies_read"
          }
          phx-value-reply-id={@reply.id}
          phx-value-post-id={@post_id}
          class="group flex items-center gap-1.5 text-xs font-medium text-slate-500 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors duration-200"
          aria-expanded="false"
          aria-controls={"nested-children-#{@reply.id}"}
        >
          <span
            id={"collapse-indicator-#{@reply.id}"}
            class={[
              "flex items-center justify-center w-5 h-5 rounded-full transition-colors duration-200",
              if(@calm_notifications && Map.get(@unread_nested_replies_by_parent, @reply.id, 0) > 0,
                do: "bg-emerald-500 text-white",
                else:
                  "bg-slate-100 dark:bg-slate-700/50 group-hover:bg-emerald-100 dark:group-hover:bg-emerald-900/30"
              )
            ]}
          >
            <.phx_icon
              name="hero-chevron-down"
              class={[
                "w-3 h-3 transition-transform duration-200 -rotate-90",
                @calm_notifications && Map.get(@unread_nested_replies_by_parent, @reply.id, 0) > 0 &&
                  "hidden"
              ]}
              id={"collapse-icon-#{@reply.id}"}
            />
            <span
              id={"unread-badge-#{@reply.id}"}
              class={[
                "text-[10px] font-bold",
                (!@calm_notifications || Map.get(@unread_nested_replies_by_parent, @reply.id, 0) == 0) &&
                  "hidden"
              ]}
            >
              {Map.get(@unread_nested_replies_by_parent, @reply.id, 0)}
            </span>
          </span>
          <span id={"collapse-text-#{@reply.id}"} class="hidden">
            Hide {length(get_child_replies(@reply))} {if length(get_child_replies(@reply)) == 1,
              do: "reply",
              else: "replies"}
          </span>
          <span id={"expand-text-#{@reply.id}"}>
            <span
              id={"expand-unread-text-#{@reply.id}"}
              class={[
                (!@calm_notifications || Map.get(@unread_nested_replies_by_parent, @reply.id, 0) == 0) &&
                  "hidden"
              ]}
            >
              {Map.get(@unread_nested_replies_by_parent, @reply.id, 0)} new
            </span>
            <span
              id={"expand-normal-text-#{@reply.id}"}
              class={[
                @calm_notifications && Map.get(@unread_nested_replies_by_parent, @reply.id, 0) > 0 &&
                  "hidden"
              ]}
            >
              Show {length(get_child_replies(@reply))}
            </span>
            {if length(get_child_replies(@reply)) == 1, do: "reply", else: "replies"}
          </span>
        </button>
      </div>

      <%!-- Render nested child replies with improved visual hierarchy --%>
      <div
        :if={@depth < @max_depth and has_child_replies?(@reply)}
        id={"nested-children-#{@reply.id}"}
        class={[
          "nested-children mt-3 relative overflow-hidden transition-all duration-300 ease-out hidden",
          if(@depth == 0, do: "ml-6 sm:ml-8", else: "ml-4 sm:ml-6"),
          "border-l-2 border-emerald-200/40 dark:border-emerald-700/40 pl-4 sm:pl-6"
        ]}
      >
        <%!-- Enhanced nested thread connection --%>
        <div class="absolute -left-0.5 top-0 bottom-0 w-0.5 bg-gradient-to-b from-emerald-300/60 via-teal-400/40 to-transparent dark:from-emerald-400/60 dark:via-teal-500/40">
        </div>

        <%!-- Child replies with better spacing --%>
        <div class="space-y-3">
          <div :for={child_reply <- get_child_replies(@reply)} class="nested-reply-item relative">
            <%!-- Connection line to child --%>
            <div class="absolute -left-4 sm:-left-6 top-6 w-3 sm:w-4 h-px bg-gradient-to-r from-emerald-300/50 to-transparent dark:from-emerald-400/50">
            </div>

            <.liquid_nested_reply_item
              reply={child_reply}
              current_scope={@current_scope}
              depth={@depth + 1}
              max_depth={@max_depth}
              post_id={@post_id}
              browser_decrypt={@browser_decrypt}
              sealed_post_key={@sealed_post_key}
              unread_nested_replies_by_parent={@unread_nested_replies_by_parent}
              calm_notifications={@calm_notifications}
            />
          </div>
        </div>
      </div>

      <%!-- Show "Load more replies" for deeply nested threads --%>
      <div
        :if={@depth >= @max_depth and has_child_replies?(@reply)}
        class="ml-4 sm:ml-6 mt-2"
      >
        <.liquid_button
          variant="ghost"
          size="sm"
          color="emerald"
          phx-click="expand_nested_replies"
          phx-value-reply-id={@reply.id}
          phx-value-post-id={@post_id}
          class="text-xs text-emerald-600 dark:text-emerald-400"
        >
          View {length(get_child_replies(@reply))} more replies
        </.liquid_button>
      </div>

      <%!-- Nested reply composer LiveComponent (hidden by default, toggled by JS) --%>
      <div
        :if={@current_scope.user}
        id={"nested-composer-#{@reply.id}"}
        class="ml-4 sm:ml-6 mt-3 hidden"
        data-hide-js={
          JS.hide(
            to: "#nested-composer-#{@reply.id}",
            transition: {"nested-reply-expand-leave", "", ""},
            time: 300
          )
          |> JS.remove_class("text-emerald-600 dark:text-emerald-400",
            to: "#reply-button-#{@reply.id}"
          )
          |> JS.set_attribute({"data-composer-open", "false"},
            to: "#reply-button-#{@reply.id}"
          )
        }
      >
        <.live_component
          module={MossletWeb.TimelineLive.NestedReplyComposerComponent}
          id={"nested-composer-component-#{@reply.id}"}
          parent_reply={@reply}
          post_id={@post_id}
          current_scope={@current_scope}
          author_name={
            if @browser_decrypt,
              do: get_reply_author_name_placeholder(@reply, @current_scope.user),
              else: get_safe_reply_author_name(@reply, @current_scope.user, @current_scope.key)
          }
          class=""
        />
      </div>
    </div>
    """
  end

  @doc """
  Individual reply item with liquid styling (updated for nesting support).
  """
  attr :reply, :map, required: true
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"
  attr :depth, :integer, default: 0
  attr :post_id, :string, default: nil
  attr :browser_decrypt, :boolean, default: false
  attr :sealed_post_key, :string, default: nil
  attr :class, :any, default: ""

  def liquid_reply_item(assigns) do
    assigns = MossletWeb.DesignSystem.assign_scope_fields(assigns)

    # When browser_decrypt is true, use a no-decrypt placeholder for the reply
    # author name. The DecryptReply hook will populate actual names into
    # [data-decrypt-reply-author] DOM targets browser-side.
    reply_author_name =
      if assigns.browser_decrypt do
        get_reply_author_name_placeholder(assigns.reply, assigns.current_scope.user)
      else
        get_safe_reply_author_name(
          assigns.reply,
          assigns.current_scope.user,
          assigns.current_scope.key
        )
      end

    assigns = assign(assigns, :reply_author_name, reply_author_name)

    ~H"""
    <div
      class={[
        "relative rounded-xl transition-all duration-200 ease-out",
        reply_background_classes(@depth),
        reply_border_classes(@depth),
        reply_hover_classes(@depth),
        "shadow-sm hover:shadow-md dark:shadow-slate-900/20",
        @class
      ]}
      data-reply-scope={@reply.id}
    >
      <%!-- Depth-aware reply accent (top bar) --%>
      <div class={[
        "absolute left-3 right-3 top-0 rounded-b-full",
        reply_top_accent_classes(@depth)
      ]}>
      </div>

      <div class={[
        "p-4 sm:p-4",
        reply_padding_classes(@depth)
      ]}>
        <div class="flex items-start gap-3">
          <%!-- Reply author avatar (small) - conditionally linked to author profile --%>
          <.link
            :if={
              show_author_profile?(
                get_reply_author_profile_slug(@reply, @current_scope.user, @current_scope.key),
                get_reply_author_profile_visibility(@reply, @current_scope.user)
              )
            }
            navigate={
              ~p"/app/profile/#{get_reply_author_profile_slug(@reply, @current_scope.user, @current_scope.key)}"
            }
            class="flex-shrink-0"
          >
            <.liquid_avatar
              id={"liquid-avatar-#{@post_id}-#{@reply.id}-#{@current_scope.user.id}"}
              src={get_reply_author_avatar_fallback(@reply, @current_scope.user)}
              encrypted_avatar_data={
                get_encrypted_reply_author_avatar_data(@reply, @current_scope.user)
              }
              name={@reply_author_name}
              status={get_reply_author_status(@reply, @current_scope.user, @current_scope.key)}
              status_message={
                get_reply_author_status_message(@reply, @current_scope.user, @current_scope.key)
              }
              show_status={
                get_reply_author_show_status(@reply, @current_scope.user, @current_scope.key)
              }
              user_id={@reply.user_id}
              size="sm"
              clickable={true}
              class="mt-0.5"
            />
          </.link>
          <.liquid_avatar
            :if={
              !show_author_profile?(
                get_reply_author_profile_slug(@reply, @current_scope.user, @current_scope.key),
                get_reply_author_profile_visibility(@reply, @current_scope.user)
              )
            }
            id={"liquid-avatar-noprofile-#{@post_id}-#{@reply.id}-#{@current_scope.user.id}"}
            src={get_reply_author_avatar_fallback(@reply, @current_scope.user)}
            encrypted_avatar_data={
              get_encrypted_reply_author_avatar_data(@reply, @current_scope.user)
            }
            name={@reply_author_name}
            status={get_reply_author_status(@reply, @current_scope.user, @current_scope.key)}
            status_message={
              get_reply_author_status_message(@reply, @current_scope.user, @current_scope.key)
            }
            show_status={
              get_reply_author_show_status(@reply, @current_scope.user, @current_scope.key)
            }
            user_id={@reply.user_id}
            size="sm"
            class="flex-shrink-0 mt-0.5"
          />

          <div class="flex-1 min-w-0">
            <%!-- Reply header - author name also linked when profile is viewable --%>
            <div class="flex items-center gap-2 mb-2">
              <.link
                :if={
                  show_author_profile?(
                    get_reply_author_profile_slug(@reply, @current_scope.user, @current_scope.key),
                    get_reply_author_profile_visibility(@reply, @current_scope.user)
                  )
                }
                navigate={
                  ~p"/app/profile/#{get_reply_author_profile_slug(@reply, @current_scope.user, @current_scope.key)}"
                }
                class="text-sm font-semibold text-slate-900 dark:text-slate-100 hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors"
              >
                <span data-decrypt-reply-author>{@reply_author_name}</span>
              </.link>
              <span
                :if={
                  !show_author_profile?(
                    get_reply_author_profile_slug(@reply, @current_scope.user, @current_scope.key),
                    get_reply_author_profile_visibility(@reply, @current_scope.user)
                  )
                }
                class="text-sm font-semibold text-slate-900 dark:text-slate-100"
              >
                <span data-decrypt-reply-author>{@reply_author_name}</span>
              </span>
              <span class="text-xs text-slate-500 dark:text-slate-400">
                {format_reply_timestamp(@reply.inserted_at)}
              </span>
            </div>

            <%!-- Reply content with markdown support --%>
            <%= if @browser_decrypt do %>
              <div
                id={"decrypt-reply-#{@reply.id}"}
                phx-hook="DecryptReply"
                phx-update="ignore"
                data-post-id={@post_id}
                data-sealed-post-key={@sealed_post_key}
                data-encrypted-body={@reply.body}
                data-encrypted-username={@reply.username}
                data-reply-id={@reply.id}
                data-current-user-id={@current_scope.user.id}
                data-encrypted-favs-list={Jason.encode!(@reply.favs_list || [])}
                class="prose prose-slate dark:prose-invert prose-sm max-w-none"
              >
                <div data-decrypt-reply-body>
                  <div class="animate-pulse h-4 w-3/4 bg-slate-200 dark:bg-slate-700 rounded"></div>
                </div>
                <span data-decrypt-reply-handle class="hidden"></span>
              </div>
            <% else %>
              <div class="prose prose-slate dark:prose-invert prose-sm max-w-none prose-p:my-1 prose-headings:mt-2 prose-headings:mb-1 prose-ul:my-1 prose-ol:my-1 prose-li:my-0.5 prose-pre:my-1.5 prose-code:text-emerald-600 dark:prose-code:text-emerald-400 prose-a:text-emerald-600 dark:prose-a:text-emerald-400 prose-a:no-underline hover:prose-a:underline [&_pre_code]:text-inherit [&_pre_*]:text-inherit">
                {format_decrypted_content(
                  get_decrypted_reply_content(@reply, @current_scope.user, @current_scope.key)
                )}
              </div>
            <% end %>

            <%!-- Reply actions (mobile-optimized) - only show for connected users or own replies --%>
            <div class="flex items-center justify-between mt-3 sm:mt-2">
              <div class="flex items-center gap-3 sm:gap-4">
                <.liquid_timeline_action
                  :if={can_interact_with_reply?(@reply, @current_scope.user)}
                  id={
                    if !@browser_decrypt && @current_scope.user.id in (@reply.favs_list || []),
                      do: "hero-heart-solid-reply-button-#{@reply.id}",
                      else: "hero-heart-reply-button-#{@reply.id}"
                  }
                  icon_id={
                    if !@browser_decrypt && @current_scope.user.id in (@reply.favs_list || []),
                      do: "hero-heart-solid-reply-icon-#{@reply.id}",
                      else: "hero-heart-reply-icon-#{@reply.id}"
                  }
                  icon={
                    if !@browser_decrypt && @current_scope.user.id in (@reply.favs_list || []),
                      do: "hero-heart-solid",
                      else: "hero-heart"
                  }
                  soft_text={
                    if @browser_decrypt,
                      do: soft_like_text(@reply.favs_count, false),
                      else:
                        soft_like_text(
                          @reply.favs_count,
                          @current_scope.user.id in (@reply.favs_list || [])
                        )
                  }
                  label={
                    if !@browser_decrypt && @current_scope.user.id in (@reply.favs_list || []),
                      do: "Unlike",
                      else: "Love"
                  }
                  color="rose"
                  active={!@browser_decrypt && @current_scope.user.id in (@reply.favs_list || [])}
                  reply_id={@reply.id}
                  phx-click={
                    if !@browser_decrypt && @current_scope.user.id in (@reply.favs_list || []),
                      do: "unfav_reply",
                      else: "fav_reply"
                  }
                  phx-value-id={@reply.id}
                  phx-hook="TippyHook"
                  data-tippy-content={
                    if !@browser_decrypt && @current_scope.user.id in (@reply.favs_list || []),
                      do: "Remove love",
                      else: "Show love"
                  }
                  class="text-xs sm:scale-75 sm:origin-left min-h-[44px] sm:min-h-0"
                />
                <button
                  :if={can_interact_with_reply?(@reply, @current_scope.user)}
                  id={"reply-button-#{@reply.id}"}
                  phx-click={
                    JS.toggle(
                      to: "#nested-composer-#{@reply.id}",
                      in: {"nested-reply-expand-enter", "", ""},
                      out: {"nested-reply-expand-leave", "", ""},
                      time: 300
                    )
                    |> JS.toggle_class("text-emerald-600 dark:text-emerald-400",
                      to: "#reply-button-#{@reply.id}"
                    )
                    |> JS.toggle_attribute({"data-composer-open", "true", "false"},
                      to: "#reply-button-#{@reply.id}"
                    )
                  }
                  data-composer-open="false"
                  class="min-h-[44px] sm:min-h-0 px-3 py-2 sm:px-0 sm:py-0 text-xs text-slate-500 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors duration-200 rounded-lg sm:rounded-none focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-1"
                  phx-hook="TippyHook"
                  data-tippy-content="Reply to this comment"
                >
                  <.phx_icon name="hero-arrow-uturn-left" class="h-3 w-3 mr-1 inline" /> Reply
                </button>
              </div>

              <%!-- Reply dropdown menu (only show if user has permissions) --%>
              <div
                :if={
                  can_manage_reply?(@reply, @current_scope.user, @post_id) or
                    can_moderate_reply?(@reply, @current_scope.user)
                }
                class="flex-shrink-0 relative z-10"
              >
                <.liquid_dropdown
                  id={"reply-#{@reply.id}-dropdown"}
                  placement="top-end"
                  trigger_class="p-2 rounded-lg hover:bg-slate-100/50 dark:hover:bg-slate-700/50 transition-colors duration-200"
                  class=""
                >
                  <:trigger>
                    <.phx_icon
                      name="hero-ellipsis-horizontal"
                      class="h-4 w-4 text-slate-400 dark:text-slate-500 hover:text-slate-600 dark:hover:text-slate-300"
                    />
                  </:trigger>

                  <%!-- Report option (for others' replies) --%>
                  <:item
                    :if={
                      can_moderate_reply?(@reply, @current_scope.user) and
                        @reply.user_id != @current_scope.user.id
                    }
                    color="amber"
                    phx_click="report_reply"
                    phx_value_id={@reply.id}
                    phx_value_reported_user_id={@reply.user_id}
                  >
                    <.phx_icon name="hero-flag" class="h-4 w-4" />
                    <span>Report Reply</span>
                  </:item>

                  <%!-- Block option (for others' replies) --%>
                  <:item
                    :if={
                      can_moderate_reply?(@reply, @current_scope.user) and
                        @reply.user_id != @current_scope.user.id
                    }
                    color="rose"
                    phx_click="block_user_from_reply"
                    phx_value_id={@reply.user_id}
                    phx_value_user_name={@reply_author_name}
                    phx_value_reply_id={@reply.id}
                  >
                    <.phx_icon name="hero-no-symbol" class="h-4 w-4" />
                    <span>Block Author</span>
                  </:item>

                  <%!-- Delete option for reply owner or post owner --%>
                  <:item
                    :if={can_manage_reply?(@reply, @current_scope.user, @post_id)}
                    color="rose"
                    phx_click="delete_reply"
                    phx_value_id={@reply.id}
                    data_confirm="Are you sure you want to delete this reply?"
                  >
                    <.phx_icon name="hero-trash" class="h-4 w-4" />
                    <span>Delete Reply</span>
                  </:item>
                </.liquid_dropdown>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper function for mapping post.shared_users (user_ids) to list of post_shared_users
  # returns the matching %Post.SharedUser{} mapped from current_user's user_connections
  # in handle_params of our timline index
  def get_shared_connection(user_id, post_shared_users_list) do
    Enum.find(post_shared_users_list, nil, fn post_shared_user ->
      post_shared_user.user_id === user_id
    end)
  end

  def show_profile?(shared_post_user) do
    shared_post_user.profile_slug &&
      shared_post_user.profile_visibility in [:connections, :public]
  end

  def show_author_profile?(author_profile_slug, author_profile_visibility) do
    author_profile_slug &&
      author_profile_visibility in [:connections, :public]
  end

  def connection_has_user_post?(post_id, user_id) do
    case get_user_post_for_user_id(post_id, user_id) do
      %Timeline.UserPost{} = _user_post -> true
      _rest -> false
    end
  end

  defp get_user_post_for_user_id(post_id, user_id) do
    Timeline.get_user_post_by_post_id_and_user_id(post_id, user_id)
  end

  # Returns encrypted avatar data for browser-side ZK decryption on reply avatars.
  # For current user: uses conn_key sealed key.
  # For other users: uses UserConnection.key sealed key.
  # Returns nil when avatar is hidden or data unavailable (component falls back to logo).
  defp get_encrypted_reply_author_avatar_data(reply, current_user) do
    cond do
      reply.user_id == current_user.id ->
        if show_avatar?(current_user),
          do: get_encrypted_avatar_data(current_user, nil),
          else: nil

      not is_connected_to_reply_author?(reply, current_user) ->
        nil

      true ->
        user_connection = get_uconn_for_shared_item(reply, current_user)

        if show_avatar?(user_connection),
          do: get_encrypted_avatar_data(user_connection, nil),
          else: nil
    end
  end

  # Fallback avatar URL for reply avatars when ZK data is nil (avatar hidden or unavailable).
  defp get_reply_author_avatar_fallback(reply, current_user) do
    cond do
      reply.user_id == current_user.id ->
        if show_avatar?(current_user), do: mosslet_logo_for_theme(), else: "/images/logo.svg"

      not is_connected_to_reply_author?(reply, current_user) ->
        "/images/logo.svg"

      true ->
        user_connection = get_uconn_for_shared_item(reply, current_user)

        if show_avatar?(user_connection), do: mosslet_logo_for_theme(), else: "/images/logo.svg"
    end
  end

  defp get_decrypted_reply_content(reply, current_user, key) do
    cond do
      reply.user_id == current_user.id ->
        case get_reply_post_key(reply, current_user) do
          {:ok, post_key} ->
            case decr_item(reply.body, current_user, post_key, key, reply, "body") do
              content when is_binary(content) -> content
              :failed_verification -> "[Could not decrypt reply]"
              _ -> "[Could not decrypt reply]"
            end

          _ ->
            "[Could not decrypt reply]"
        end

      not is_connected_to_reply_author?(reply, current_user) ->
        "[Reply from non-connected user]"

      true ->
        case get_reply_post_key(reply, current_user) do
          {:ok, post_key} ->
            case decr_item(reply.body, current_user, post_key, key, reply, "body") do
              content when is_binary(content) -> content
              :failed_verification -> "[Could not decrypt reply]"
              _ -> "[Could not decrypt reply]"
            end

          _ ->
            "[Could not decrypt reply]"
        end
    end
  end

  # Helper function to get the reply author's status if visible to current user
  # Similar to get_post_author_status but for replies
  def get_reply_author_status(reply, current_user, key) do
    case Accounts.get_user_with_preloads(reply.user_id) do
      %{} = reply_author ->
        case get_user_status_info(reply_author, current_user, key) do
          %{status: status} when is_binary(status) -> status
          _ -> "offline"
        end

      nil ->
        # User account not found
        "offline"
    end
  end

  # Helper function to get the reply author's status message if visible to current user
  # Similar to get_post_author_status_message but for replies
  def get_reply_author_status_message(reply, current_user, key) do
    case Accounts.get_user_with_preloads(reply.user_id) do
      %{} = reply_author ->
        get_user_status_message(reply_author, current_user, key)

      nil ->
        # User account not found
        nil
    end
  end

  def get_reply_author_show_status(reply, current_user, key) do
    case Accounts.get_user_with_preloads(reply.user_id) do
      %{} = reply_author ->
        MossletWeb.Helpers.StatusHelpers.can_view_status?(reply_author, current_user, key)

      nil ->
        false
    end
  end

  def get_reply_author_profile_slug(reply, current_user, _key) do
    cond do
      reply.user_id == current_user.id ->
        case current_user.connection do
          %{profile: %{slug: slug}} when is_binary(slug) -> slug
          _ -> nil
        end

      not is_connected_to_reply_author?(reply, current_user) ->
        nil

      true ->
        case Accounts.get_user_with_preloads(reply.user_id) do
          %{connection: %{profile: %{slug: slug}}} when is_binary(slug) -> slug
          _ -> nil
        end
    end
  end

  def get_reply_author_profile_visibility(reply, current_user) do
    cond do
      reply.user_id == current_user.id ->
        case current_user.connection do
          %{profile: %{visibility: visibility}} -> visibility
          _ -> nil
        end

      not is_connected_to_reply_author?(reply, current_user) ->
        nil

      true ->
        case Accounts.get_user_with_preloads(reply.user_id) do
          %{connection: %{profile: %{visibility: visibility}}} -> visibility
          _ -> nil
        end
    end
  end

  # Helper function to check if user can manage a reply (delete)
  # Post owners can delete any replies to their posts
  # Reply owners can delete their own replies
  defp can_manage_reply?(reply, current_user, post_id) do
    # Reply owner can always delete their own reply
    if reply.user_id == current_user.id do
      true
    else
      # Check if current user owns the post this reply belongs to
      case Mosslet.Timeline.get_post(post_id) do
        %{user_id: post_user_id} -> post_user_id == current_user.id
        _ -> false
      end
    end
  end

  # Helper function to check if user can moderate a reply (report/block)
  # Any user can report/block others' replies (but not their own)
  defp can_moderate_reply?(reply, current_user) do
    reply.user_id != current_user.id
  end

  # Helper function to check if user can interact with a reply (fav/reply)
  # User can interact if they are the reply author OR connected to the reply author
  defp can_interact_with_reply?(reply, current_user) do
    reply.user_id == current_user.id or is_connected_to_reply_author?(reply, current_user)
  end

  defp format_reply_timestamp(timestamp) do
    # Use same formatting as posts for consistency
    case timestamp do
      %NaiveDateTime{} ->
        # Import the format_post_timestamp function or use a simple relative time
        relative_time = NaiveDateTime.diff(NaiveDateTime.utc_now(), timestamp)

        cond do
          relative_time < 60 -> "now"
          relative_time < 3_600 -> "#{div(relative_time, 60)}m"
          relative_time < 86_400 -> "#{div(relative_time, 3_600)}h"
          relative_time < 2_592_000 -> "#{div(relative_time, 86_400)}d"
          true -> "#{div(relative_time, 2_592_000)}mo"
        end

      _ ->
        "Unknown time"
    end
  end

  # Helper functions for depth-based reply styling
  defp reply_background_classes(depth) do
    case depth do
      0 -> "bg-white/70 dark:bg-slate-800/70 backdrop-blur-sm"
      1 -> "bg-white/60 dark:bg-slate-800/60 backdrop-blur-sm"
      2 -> "bg-white/50 dark:bg-slate-800/50 backdrop-blur-sm"
      _ -> "bg-white/40 dark:bg-slate-800/40 backdrop-blur-sm"
    end
  end

  defp reply_border_classes(depth) do
    case depth do
      0 -> "border border-slate-200/50 dark:border-slate-700/50"
      1 -> "border border-slate-200/40 dark:border-slate-700/40"
      2 -> "border border-slate-200/30 dark:border-slate-700/30"
      _ -> "border border-slate-200/20 dark:border-slate-700/20"
    end
  end

  defp reply_hover_classes(depth) do
    case depth do
      0 ->
        "hover:border-emerald-200/70 dark:hover:border-emerald-700/70 hover:bg-emerald-50/40 dark:hover:bg-emerald-900/15"

      1 ->
        "hover:border-emerald-200/60 dark:hover:border-emerald-700/60 hover:bg-emerald-50/30 dark:hover:bg-emerald-900/12"

      2 ->
        "hover:border-emerald-200/50 dark:hover:border-emerald-700/50 hover:bg-emerald-50/20 dark:hover:bg-emerald-900/10"

      _ ->
        "hover:border-emerald-200/40 dark:hover:border-emerald-700/40 hover:bg-emerald-50/15 dark:hover:bg-emerald-900/8"
    end
  end

  defp reply_top_accent_classes(depth) do
    case depth do
      0 ->
        "h-1 bg-gradient-to-r from-emerald-400/80 via-teal-400/60 to-emerald-300/40 dark:from-emerald-500/80 dark:via-teal-500/60 dark:to-emerald-400/40"

      1 ->
        "h-0.5 bg-gradient-to-r from-teal-400/70 via-emerald-400/50 to-teal-300/30 dark:from-teal-500/70 dark:via-emerald-500/50 dark:to-teal-400/30"

      2 ->
        "h-0.5 bg-gradient-to-r from-cyan-400/60 via-teal-400/40 to-cyan-300/20 dark:from-cyan-500/60 dark:via-teal-500/40 dark:to-cyan-400/20"

      _ ->
        "h-px bg-gradient-to-r from-slate-400/50 via-slate-300/30 to-transparent dark:from-slate-500/50 dark:via-slate-400/30"
    end
  end

  defp reply_padding_classes(depth) do
    case depth do
      0 -> "pt-5 sm:pt-6"
      1 -> "pt-4 sm:pt-5"
      2 -> "pt-3 sm:pt-4"
      _ -> "pt-2 sm:pt-3"
    end
  end

  # Filter to show only top-level replies (not nested replies)
  defp filter_top_level_replies(replies) do
    Enum.filter(replies, fn reply ->
      # Top-level replies have no parent_reply_id
      is_nil(reply.parent_reply_id)
    end)
  end

  # Helper functions to safely handle child_replies association
  defp has_child_replies?(reply) do
    case Map.get(reply, :child_replies) do
      %Ecto.Association.NotLoaded{} -> false
      nil -> false
      [] -> false
      list when is_list(list) -> true
      _ -> false
    end
  end

  defp get_child_replies(reply) do
    case Map.get(reply, :child_replies) do
      %Ecto.Association.NotLoaded{} -> []
      nil -> []
      list when is_list(list) -> list
      _ -> []
    end
  end

  def toggle_reply_section(post_id, mark_replies_read?) do
    js =
      JS.toggle(
        to: "#reply-composer-#{post_id}",
        in: {"nested-reply-expand-enter", "", ""},
        out: {"nested-reply-expand-leave", "", ""},
        time: 300
      )
      |> JS.toggle(
        to: "#reply-thread-#{post_id}",
        in: {"nested-reply-expand-enter", "", ""},
        out: {"nested-reply-expand-leave", "", ""},
        time: 300
      )
      |> JS.toggle_class("ring-2 ring-emerald-300", to: "#timeline-card-#{post_id}")
      |> JS.toggle_class("reply-expanded", to: "#reply-button-#{post_id}")
      |> JS.toggle_attribute({"data-expanded", "true", "false"}, to: "#reply-button-#{post_id}")

    if mark_replies_read? do
      js
      |> JS.push("mark_replies_read", value: %{post_id: post_id})
    else
      js
    end
  end

  defp toggle_nested_replies(reply_id, post_id, unread_count) do
    js =
      JS.toggle(
        to: "#nested-children-#{reply_id}",
        in: {"nested-reply-expand-enter", "", ""},
        out: {"nested-reply-expand-leave", "", ""},
        time: 300
      )
      |> JS.toggle_class("hidden", to: "#collapse-text-#{reply_id}")
      |> JS.toggle_class("hidden", to: "#expand-text-#{reply_id}")
      |> JS.toggle_class("-rotate-90", to: "#collapse-icon-#{reply_id}")
      |> JS.toggle_attribute({"aria-expanded", "true", "false"}, to: "#nested-toggle-#{reply_id}")

    js =
      if unread_count > 0 do
        js
        |> JS.hide(to: "#unread-badge-#{reply_id}")
        |> JS.show(to: "#collapse-icon-#{reply_id}")
        |> JS.remove_class("bg-emerald-500 text-white",
          to: "#collapse-indicator-#{reply_id}"
        )
        |> JS.add_class(
          "bg-slate-100 dark:bg-slate-700/50 group-hover:bg-emerald-100 dark:group-hover:bg-emerald-900/30",
          to: "#collapse-indicator-#{reply_id}"
        )
        |> JS.hide(to: "#expand-unread-text-#{reply_id}")
        |> JS.show(to: "#expand-normal-text-#{reply_id}")
        |> JS.push("mark_nested_replies_read",
          value: %{reply_id: reply_id, post_id: post_id, unread_count: unread_count}
        )
        |> JS.dispatch("mosslet:decrement-badge",
          to: "#notification-badge-reply-button-#{post_id}",
          detail: %{decrement: unread_count}
        )
      else
        js
      end

    js
  end

  defp count_loaded_replies(replies) when is_list(replies) do
    Enum.reduce(replies, 0, fn reply, acc ->
      child_count = count_loaded_replies(get_child_replies(reply))
      acc + 1 + child_count
    end)
  end

  defp count_loaded_replies(_), do: 0

  @doc """
  Nested reply composer for replying to specific replies
  """
  attr :form, :map, required: true
  attr :parent_reply, :map, required: true
  attr :post, :map, required: true
  attr :author_name, :string, required: true
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"
  attr :current_user, :map, required: true, doc: "deprecated: use current_scope instead"
  attr :class, :any, default: ""

  def liquid_nested_reply_composer(assigns) do
    assigns = MossletWeb.DesignSystem.assign_scope_fields(assigns)

    ~H"""
    <div class={[
      "nested-reply-composer relative",
      "bg-gradient-to-br from-emerald-50/80 via-teal-50/60 to-cyan-50/40",
      "dark:from-emerald-900/20 dark:via-teal-900/15 dark:to-cyan-900/10",
      "border border-emerald-200/60 dark:border-emerald-700/40",
      "rounded-xl p-4 backdrop-blur-sm",
      "shadow-sm hover:shadow-md transition-all duration-200",
      @class
    ]}>
      <%!-- Reply context header --%>
      <div class="flex items-center gap-2 mb-3 pb-2 border-b border-emerald-200/40 dark:border-emerald-700/30">
        <.phx_icon
          name="hero-arrow-uturn-left"
          class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
        />
        <span class="text-sm text-emerald-700 dark:text-emerald-300 font-medium">
          Replying to {"@#{@author_name}"}
        </span>
        <button
          phx-click="cancel_nested_reply"
          class="ml-auto p-1 rounded-lg hover:bg-emerald-100 dark:hover:bg-emerald-800/50 text-emerald-600 dark:text-emerald-400 transition-colors duration-200"
        >
          <.phx_icon name="hero-x-mark" class="h-4 w-4" />
        </button>
      </div>

      <%!-- Nested reply form --%>
      <.form
        for={@form}
        id="nested-reply-form"
        phx-submit="submit_nested_reply"
        phx-change="validate_nested_reply"
        class="space-y-3"
      >
        <%!-- Hidden fields --%>
        <input type="hidden" name="nested_reply[parent_reply_id]" value={@parent_reply.id} />
        <input type="hidden" name="nested_reply[post_id]" value={@post.id} />
        <input type="hidden" name="nested_reply[visibility]" value={@post.visibility} />

        <%!-- Reply textarea --%>
        <div class="relative">
          <.phx_input
            field={@form[:body]}
            type="textarea"
            placeholder="Write your reply..."
            rows="3"
            class="resize-none border-emerald-200/60 dark:border-emerald-700/40 focus:border-emerald-400 dark:focus:border-emerald-500 focus:ring-emerald-500/30 bg-white/80 dark:bg-slate-800/80"
          />
        </div>

        <%!-- Action buttons --%>
        <div class="flex items-center justify-between pt-2">
          <div class="flex items-center gap-2 text-xs text-emerald-600 dark:text-emerald-400">
            <.phx_icon name="hero-lock-closed" class="h-3 w-3" />
            <span>Reply inherits post's visibility</span>
          </div>

          <div class="flex items-center gap-2">
            <.liquid_button
              type="button"
              variant="ghost"
              size="sm"
              color="slate"
              phx-click="cancel_nested_reply"
              class="text-xs"
            >
              Cancel
            </.liquid_button>

            <.liquid_button
              type="submit"
              size="sm"
              color="emerald"
              class="text-xs px-4"
            >
              <.phx_icon name="hero-paper-airplane" class="h-3 w-3 mr-1" /> Reply
            </.liquid_button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  @doc """
  A liquid metal report post modal for content moderation.

  ## Examples

      <.liquid_report_modal
        show={@show_report_modal}
        post_id={@reported_post_id}
        reported_user_id={@reported_user_id}
        on_close="close_report_modal"
      />
  """
  attr :show, :boolean, default: false
  attr :post_id, :string, required: true
  attr :reported_user_id, :string, required: true
  attr :on_close, :string, default: "close_report_modal"
  attr :class, :any, default: ""

  def liquid_report_modal(assigns) do
    ~H"""
    <.liquid_modal
      :if={@show}
      id="report-post-modal"
      show={@show}
      on_cancel={JS.push(@on_close)}
      size="lg"
    >
      <:title>
        <div class="flex items-center gap-3">
          <div class="p-2.5 rounded-xl bg-gradient-to-br from-amber-100 to-orange-100 dark:from-amber-900/30 dark:to-orange-900/30">
            <.phx_icon name="hero-flag" class="h-5 w-5 text-amber-600 dark:text-amber-400" />
          </div>
          <div>
            <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
              Report this post
            </h3>
            <p class="text-sm text-slate-600 dark:text-slate-400">
              Help us keep the community safe
            </p>
          </div>
        </div>
      </:title>

      <div class="space-y-6">
        <.form
          for={%{}}
          as={:report}
          phx-submit="submit_report"
          phx-change="validate_report"
          id="report-form"
          class="space-y-6"
        >
          <input type="hidden" name="report[post_id]" value={@post_id} />
          <input type="hidden" name="report[reported_user_id]" value={@reported_user_id} />

          <%!-- Report type selection --%>
          <div class="space-y-3">
            <label class="block text-sm font-medium text-slate-900 dark:text-slate-100">
              What's the issue?
            </label>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <label class="relative flex items-start p-4 border border-slate-200 dark:border-slate-700 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800/50 cursor-pointer transition-all duration-200">
                <input
                  type="radio"
                  name="report[report_type]"
                  value="harassment"
                  class="mt-1 h-4 w-4 text-amber-600 focus:ring-amber-500 border-slate-300 dark:border-slate-600"
                />
                <div class="ml-3">
                  <div class="font-medium text-slate-900 dark:text-slate-100">Harassment</div>
                  <div class="text-sm text-slate-600 dark:text-slate-400">
                    Threats, bullying, or abuse
                  </div>
                </div>
              </label>

              <label class="relative flex items-start p-4 border border-slate-200 dark:border-slate-700 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800/50 cursor-pointer transition-all duration-200">
                <input
                  type="radio"
                  name="report[report_type]"
                  value="spam"
                  class="mt-1 h-4 w-4 text-amber-600 focus:ring-amber-500 border-slate-300 dark:border-slate-600"
                />
                <div class="ml-3">
                  <div class="font-medium text-slate-900 dark:text-slate-100">Spam</div>
                  <div class="text-sm text-slate-600 dark:text-slate-400">
                    Unwanted or repetitive content
                  </div>
                </div>
              </label>

              <label class="relative flex items-start p-4 border border-slate-200 dark:border-slate-700 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800/50 cursor-pointer transition-all duration-200">
                <input
                  type="radio"
                  name="report[report_type]"
                  value="content"
                  class="mt-1 h-4 w-4 text-amber-600 focus:ring-amber-500 border-slate-300 dark:border-slate-600"
                />
                <div class="ml-3">
                  <div class="font-medium text-slate-900 dark:text-slate-100">
                    Inappropriate Content
                  </div>
                  <div class="text-sm text-slate-600 dark:text-slate-400">
                    Violates community guidelines
                  </div>
                </div>
              </label>

              <label class="relative flex items-start p-4 border border-slate-200 dark:border-slate-700 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800/50 cursor-pointer transition-all duration-200">
                <input
                  type="radio"
                  name="report[report_type]"
                  value="other"
                  class="mt-1 h-4 w-4 text-amber-600 focus:ring-amber-500 border-slate-300 dark:border-slate-600"
                />
                <div class="ml-3">
                  <div class="font-medium text-slate-900 dark:text-slate-100">Other</div>
                  <div class="text-sm text-slate-600 dark:text-slate-400">
                    Something else
                  </div>
                </div>
              </label>
            </div>
          </div>

          <%!-- Severity selection --%>
          <div class="space-y-3">
            <label class="block text-sm font-medium text-slate-900 dark:text-slate-100">
              How serious is this issue?
            </label>
            <div class="flex flex-wrap gap-2">
              <label class="flex items-center px-4 py-2 border border-slate-200 dark:border-slate-700 rounded-full hover:bg-slate-50 dark:hover:bg-slate-800/50 cursor-pointer transition-all duration-200">
                <input
                  type="radio"
                  name="report[severity]"
                  value="low"
                  class="mr-2 h-4 w-4 text-amber-600 focus:ring-amber-500 border-slate-300 dark:border-slate-600"
                />
                <span class="text-sm text-slate-700 dark:text-slate-300">Minor</span>
              </label>
              <label class="flex items-center px-4 py-2 border border-slate-200 dark:border-slate-700 rounded-full hover:bg-slate-50 dark:hover:bg-slate-800/50 cursor-pointer transition-all duration-200">
                <input
                  type="radio"
                  name="report[severity]"
                  value="medium"
                  class="mr-2 h-4 w-4 text-amber-600 focus:ring-amber-500 border-slate-300 dark:border-slate-600"
                />
                <span class="text-sm text-slate-700 dark:text-slate-300">Moderate</span>
              </label>
              <label class="flex items-center px-4 py-2 border border-slate-200 dark:border-slate-700 rounded-full hover:bg-slate-50 dark:hover:bg-slate-800/50 cursor-pointer transition-all duration-200">
                <input
                  type="radio"
                  name="report[severity]"
                  value="high"
                  class="mr-2 h-4 w-4 text-amber-600 focus:ring-amber-500 border-slate-300 dark:border-slate-600"
                />
                <span class="text-sm text-slate-700 dark:text-slate-300">Serious</span>
              </label>
              <label class="flex items-center px-4 py-2 border border-slate-200 dark:border-slate-700 rounded-full hover:bg-slate-50 dark:hover:bg-slate-800/50 cursor-pointer transition-all duration-200">
                <input
                  type="radio"
                  name="report[severity]"
                  value="critical"
                  class="mr-2 h-4 w-4 text-amber-600 focus:ring-amber-500 border-slate-300 dark:border-slate-600"
                />
                <span class="text-sm text-slate-700 dark:text-slate-300">Critical</span>
              </label>
            </div>
          </div>

          <%!-- Reason field --%>
          <div class="space-y-2">
            <label
              for="report_reason"
              class="block text-sm font-medium text-slate-900 dark:text-slate-100"
            >
              Brief reason
            </label>
            <input
              type="text"
              name="report[reason]"
              id="report_reason"
              class="w-full px-4 py-3 border border-slate-300 dark:border-slate-600 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 placeholder-slate-500 focus:ring-2 focus:ring-amber-500 focus:border-amber-500 transition-all duration-200"
              placeholder="Why are you reporting this post?"
              maxlength="100"
            />
          </div>

          <%!-- Details field --%>
          <div class="space-y-2">
            <label
              for="report_details"
              class="block text-sm font-medium text-slate-900 dark:text-slate-100"
            >
              Additional details (optional)
            </label>
            <textarea
              name="report[details]"
              id="report_details"
              rows="3"
              class="w-full px-4 py-3 border border-slate-300 dark:border-slate-600 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 placeholder-slate-500 focus:ring-2 focus:ring-amber-500 focus:border-amber-500 transition-all duration-200 resize-none"
              placeholder="Provide any additional context that might help our moderation team..."
              maxlength="1000"
            ></textarea>
          </div>

          <%!-- Privacy notice --%>
          <div class="p-4 bg-slate-50 dark:bg-slate-800/50 rounded-xl border border-slate-200 dark:border-slate-700">
            <div class="flex gap-3">
              <.phx_icon
                name="hero-shield-check"
                class="h-5 w-5 text-slate-600 dark:text-slate-400 flex-shrink-0 mt-0.5"
              />
              <div class="text-sm text-slate-700 dark:text-slate-300">
                <p class="font-medium mb-1">Your report is confidential</p>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  The reported user won't know who submitted this report. We'll review it according to our community guidelines and take appropriate action.
                </p>
              </div>
            </div>
          </div>

          <%!-- Action buttons --%>
          <div class="flex justify-end gap-3 pt-2">
            <.liquid_button
              type="button"
              variant="ghost"
              color="slate"
              phx-click={@on_close}
            >
              Cancel
            </.liquid_button>
            <.liquid_button
              type="submit"
              color="amber"
              icon="hero-flag"
            >
              Submit Report
            </.liquid_button>
          </div>
        </.form>
      </div>
    </.liquid_modal>
    """
  end
end
