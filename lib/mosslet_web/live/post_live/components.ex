defmodule MossletWeb.PostLive.Components do
  @moduledoc """
  Components for posts.
  """
  use MossletWeb, :component
  use MossletWeb, :verified_routes

  alias Phoenix.LiveView.JS
  alias Mosslet.Accounts

  import MossletWeb.CoreComponents, only: [phx_avatar: 1, phx_icon: 1, local_time_ago: 1]
  import MossletWeb.Helpers

  attr :id, :string, required: true
  attr :stream, :list, required: true
  attr :card_click, :any, default: nil, doc: "the function for handling phx-click on each card"
  attr :current_user, :string, required: true
  attr :options, :map, doc: "the pagination options map"
  attr :post_count, :integer, doc: "the total count of current_user's posts"
  attr :key, :string, required: true
  attr :post_loading, :boolean, required: true, doc: "whether a post is loading or not"
  attr :group, Mosslet.Groups.Group, default: nil, doc: "the optional group struct"

  attr :loading_list, :list,
    default: [],
    doc: "the list of indexed posts to match to the stream for loading"

  attr :finished_loading_list, :list,
    default: [],
    doc: "the list of post_ids that have finished being loaded"

  attr :post_loading_count, :integer,
    required: true,
    doc: "the integer for the post to be loaded"

  slot :action, doc: "the slot for showing user actions in the last table column"

  def cards(assigns) do
    ~H"""
    <div class="flex-1 max-w-prose justify-center items-center">
      <div id={@id} phx-update="stream" class="py-10 sm:px-4 space-y-4">
        <div
          :for={{id, item} <- @stream}
          id={id}
          class={[
            "group flex gap-x-4 py-5 px-2 border-2 border-primary-400 shadow-lg shadow-primary-500/50 rounded-2xl dark:bg-gray-800",
            @card_click &&
              "transition hover:bg-primary-50 hover:border-emerald-400 dark:hover:bg-gray-700  sm:hover:scale-105"
          ]}
        >
          <.post
            :if={item}
            post={item}
            current_user={@current_user}
            key={@key}
            color={get_uconn_color_for_shared_item(item, @current_user) || :purple}
            id={"post-card-#{id}"}
            post_index={id}
            options={@options}
            post_loading_count={@post_loading_count}
            post_loading={@post_loading}
            post_list={@loading_list}
            card_click={@card_click}
            loading_id={
              Enum.find_index(@loading_list, fn {_index, element} ->
                Kernel.to_string(element.id) == String.trim(id, "posts-")
              end)
            }
            finished_loading_list={@finished_loading_list}
          />
        </div>
      </div>
    </div>
    <%!-- pagination --%>
    <nav
      :if={@post_count > 0}
      id="post-pagination"
      class="flex items-center justify-between border-t border-gray-200 px-4 sm:px-0"
    >
      <div class="-mt-px flex w-0 flex-1">
        <.link
          :if={@options.page > 1}
          patch={
            if @group,
              do: ~p"/app/groups/#{@group}?#{%{@options | page: @options.page - 1}}",
              else: ~p"/app/timeline?#{%{@options | page: @options.page - 1}}"
          }
          class="inline-flex items-center group border-t-2 border-transparent pl-1 pt-4 text-sm font-medium text-gray-400 dark:text-gray-500 hover:border-gray-300 hover:text-gray-700 dark:hover:text-gray-200"
        >
          <svg
            class="mr-3 h-5 w-5 text-gray-400 dark:text-gray-500 group-hover:text-gray-700 dark:group-hover:text-gray-200"
            viewBox="0 0 20 20"
            fill="currentColor"
            aria-hidden="true"
          >
            <path
              fill-rule="evenodd"
              d="M18 10a.75.75 0 01-.75.75H4.66l2.1 1.95a.75.75 0 11-1.02 1.1l-3.5-3.25a.75.75 0 010-1.1l3.5-3.25a.75.75 0 111.02 1.1l-2.1 1.95h12.59A.75.75 0 0118 10z"
              clip-rule="evenodd"
            />
          </svg>
          Previous
        </.link>
      </div>
      <div class="-mt-px md:flex">
        <.link
          :for={{page_number, current_page?} <- pages(@options, @post_count)}
          class={
            if current_page?,
              do:
                "inline-flex items-center border-t-2 border-primary-500 px-4 pt-4 text-sm font-medium text-primary-600 dark:text-primary-400",
              else:
                "inline-flex items-center border-t-2 border-transparent pl-1 pt-4 text-sm font-medium text-gray-400 dark:text-gray-500 hover:border-gray-300 hover:text-gray-700 dark:hover:text-gray-200"
          }
          patch={
            if @group,
              do: ~p"/app/groups/#{@group}?#{%{@options | page: page_number}}",
              else: ~p"/app/timeline?#{%{@options | page: page_number}}"
          }
          aria-current="page"
        >
          {page_number}
        </.link>
      </div>
      <div class="-mt-px flex w-0 flex-1 justify-end">
        <.link
          :if={more_pages?(@options, @post_count)}
          patch={
            if @group,
              do: ~p"/app/groups/#{@group}?#{%{@options | page: @options.page + 1}}",
              else: ~p"/app/timeline?#{%{@options | page: @options.page + 1}}"
          }
          class="inline-flex items-center group border-t-2 border-transparent pl-1 pt-4 text-sm font-medium text-gray-400 dark:text-gray-500 hover:border-gray-300 hover:text-gray-700 dark:hover:text-gray-200"
        >
          Next
          <svg
            class="ml-3 h-5 w-5 text-gray-400 dark:text-gray-500 group-hover:text-gray-700 dark:group-hover:text-gray-200"
            viewBox="0 0 20 20"
            fill="currentColor"
            aria-hidden="true"
          >
            <path
              fill-rule="evenodd"
              d="M2 10a.75.75 0 01.75-.75h12.59l-2.1-1.95a.75.75 0 111.02-1.1l3.5 3.25a.75.75 0 010 1.1l-3.5 3.25a.75.75 0 11-1.02-1.1l2.1-1.95H2.75A.75.75 0 012 10z"
              clip-rule="evenodd"
            />
          </svg>
        </.link>
      </div>
    </nav>
    """
  end

  attr :id, :string, doc: "the html id of the post card"
  attr :current_user, :string, required: true
  attr :key, :string, required: true
  attr :post, Mosslet.Timeline.Post, required: true

  attr :color, :atom,
    default: :purple,
    values: [:emerald, :orange, :pink, :purple, :rose, :yellow, :zinc]

  attr :loading_id, :integer,
    required: true,
    doc: "the integer id of the post being loaded (matched from indexed list)"

  attr :options, :map, doc: "the pagination options map"
  attr :post_loading, :boolean, required: true, doc: "whether the post is being loaded or not"
  attr :post_list, :list, doc: "the list of posts in the stream"
  attr :src, :string, default: "", doc: "the src image string"
  attr :card_click, :any, default: nil, doc: "the function for handling phx-click on each card"

  attr :post_loading_count, :integer,
    required: true,
    doc: "the integer for the post to be loaded"

  attr :finished_loading_list, :list,
    default: [],
    doc: "the list of post_ids that have finished being loaded"

  attr :post_index, :string, doc: "the index of the post loading (typically the post id)"

  def post(assigns) do
    assigns =
      assign(
        assigns,
        :src,
        maybe_get_avatar_src(assigns.post, assigns.current_user, assigns.key, assigns.post_list)
      )

    ~H"""
    <div
      :if={not is_nil(@current_user)}
      id={"post-avatar-#{@post.id}"}
      class="flex flex-col flex-shrink-0 space-y-1 items-center"
    >
      <div
        :if={
          (not @post_loading && @src != "") ||
            @post.id in @finished_loading_list
        }
        id={"post-[#{@loading_id}]-#{@post.id}"}
      >
        <.phx_avatar src={@src} />
      </div>
      <div
        :if={
          (@post_loading && @src == "" && not is_nil(get_user_from_post(@post).connection.avatar_url)) ||
            (@post.id not in @finished_loading_list && @src == "" &&
               not is_nil(get_user_from_post(@post).connection.avatar_url))
        }
        id={"post-[#{@loading_id}]-#{@post.id}"}
        class="inline-block rounded-md h-12 w-12"
      >
        <.spinner size="md" class="text-primary-500" />
      </div>
      <div
        :if={!@post_loading && @src == "" && is_nil(get_user_from_post(@post).connection.avatar_url)}
        id={"post-[#{@loading_id}]-#{@post.id}"}
        class="inline-block rounded-md h-12 w-12"
      >
        <.phx_avatar src={@src} />
      </div>
      <span
        :if={@post.repost}
        class="inline-flex items-center rounded-md bg-purple-50 dark:bg-purple-950 px-2 py-1 text-xs font-light text-purple-700 dark:text-purple-300 ring-1 ring-inset ring-purple-700/10 dark:ring-purple-300/50"
      >
        repost
      </span>
      <%!-- sharing with group badge --%>
      <span
        :if={not is_nil(@post.group_id)}
        class="group-hover:hidden inline-flex items-center rounded-md bg-green-50 dark:bg-green-950 px-2 py-1 text-xs font-light text-green-700 dark:text-green-300 ring-1 ring-inset ring-green-700/10 dark:ring-green-300/50"
      >
        Group
      </span>
      <span
        :if={not is_nil(@post.group_id)}
        class="hidden group-hover:inline-flex items-center rounded-md bg-green-50 dark:bg-green-950 px-2 py-1 text-xs font-light text-green-700 dark:text-green-300 ring-1 ring-inset ring-green-700/10 dark:ring-green-300/50"
      >
        <.link
          id={"link-#{@post.id}-group-#{@post.group_id}"}
          navigate={~p"/app/groups/#{@post.group_id}"}
          data-tippy-content="Go to Group"
          phx-hook="TippyHook"
        >
          Group
        </.link>
      </span>
    </div>

    <div
      :if={is_nil(@current_user)}
      id={"post-avatar-#{@post.id}-no-user"}
      class="flex flex-col flex-shrink-0 space-y-1 items-center"
    >
      <image
        :if={is_nil(@current_user)}
        src={~p"/images/logo.svg"}
        class="inline-block h-12 w-12 rounded-md bg-zinc-100 dark:bg-gray-800"
      />
      <span
        :if={@post.repost}
        class="inline-flex items-center rounded-md bg-purple-50 dark:bg-purple-950 px-2 py-1 text-xs font-light text-purple-700 dark:text-purple-300 ring-1 ring-inset ring-purple-700/10 dark:ring-purple-300/50"
      >
        repost
      </span>
    </div>

    <div class="relative flex-auto">
      <div class="flex items-baseline justify-between gap-x-4">
        <%!-- username --%>

        <p
          :if={my_post?(@post, @current_user) && @post.visibility == :private}
          class="text-sm font-semibold leading-6 text-gray-900 dark:text-gray-100"
        >
          {decr_item(
            @post.username,
            @current_user,
            get_post_key(@post, @current_user),
            @key,
            @post,
            "username"
          )}
        </p>

        <p
          :if={@post.visibility == :connections && my_post?(@post, @current_user)}
          class="text-sm font-semibold leading-6 text-gray-900 dark:text-gray-100"
        >
          {decr_item(
            @post.username,
            @current_user,
            get_post_key(@post, @current_user),
            @key,
            @post,
            "username"
          )}
        </p>
        <p
          :if={@post.visibility == :connections && !my_post?(@post, @current_user)}
          class="text-sm font-semibold leading-6 text-gray-900 dark:text-gray-100"
        >
          {decr_item(
            @post.username,
            @current_user,
            get_post_key(@post, @current_user),
            @key,
            @post
          )}
        </p>

        <%!-- sharing with users badge --%>
        <div
          :if={
            get_shared_item_identity_atom(@post, @current_user) == :self &&
              !Enum.empty?(@post.shared_users)
          }
          class="absolute right-2 -bottom-2 group space-x-1"
        >
          <span
            :for={uconn <- get_shared_item_user_connection(@post, @current_user)}
            :if={uconn}
            class={"inline-flex items-center rounded-full group-hover:bg-purple-100 dark:group-hover:bg-purple-900 group-hover:px-2 group-hover:py-1 group-hover:text-xs group-hover:font-medium #{if uconn, do: badge_group_hover_color(uconn.color)} group-hover:space-x-1"}
          >
            <svg
              class={"h-1.5 w-1.5 #{if uconn, do: badge_svg_fill_color(uconn.color)}"}
              viewBox="0 0 6 6"
              aria-hidden="true"
            >
              <circle cx="3" cy="3" r="3" />
            </svg>
            <span class="hidden group-hover:flex">
              {get_username_for_uconn(uconn, @current_user, @key)}
            </span>
          </span>
        </div>
        <%!-- timestamp && label badge --%>
        <p class="flex-none text-xs text-gray-600 dark:text-gray-400">
          <span class="inline-flex items-center space-x-1">
            <span
              :if={get_shared_item_identity_atom(@post, @current_user) == :self}
              class="inline-flex items-center rounded-full"
            >
              <svg class="h-1.5 w-1.5 fill-primary-500" viewBox="0 0 6 6" aria-hidden="true">
                <circle cx="3" cy="3" r="3" />
              </svg>
            </span>

            <span
              :if={get_shared_item_identity_atom(@post, @current_user) == :connection}
              class={"inline-flex items-center rounded-full group group-hover:bg-purple-100 dark:group-hover:bg-purple-900 group-hover:px-2 group-hover:py-1 group-hover:text-xs group-hover:font-medium #{badge_group_hover_color(@color)} group-hover:space-x-1"}
            >
              <svg
                class={"h-1.5 w-1.5 #{badge_svg_fill_color(@color)}"}
                viewBox="0 0 6 6"
                aria-hidden="true"
              >
                <circle cx="3" cy="3" r="3" />
              </svg>
              <span class="hidden group-hover:flex">
                {get_shared_post_label(@post, @current_user, @key)}
              </span>
            </span>

            <.local_time_ago id={@post.id} at={@post.inserted_at} />

            <span
              :if={@post.image_urls_updated_at}
              id={"timestamp-#{@post.id}-updated"}
              class="invisible inline-flex text-xs text-gray-500 dark:text-gray-400 align-middle"
            >
              <time datetime={@post.updated_at}>
                <.local_time_ago id={"#{@post.id}-updated"} at={@post.image_urls_updated_at} />
              </time>
            </span>
          </span>
        </p>
      </div>

      <p class="mt-1 text-sm leading-6 text-gray-600 dark:text-gray-400 max-w-prose">
        {decr_item(
          @post.body,
          @current_user,
          get_post_key(@post, @current_user),
          @key,
          @post,
          "body"
        )}
      </p>
      <%!-- actions --%>
      <div class="inline-flex space-x-2 align-middle">
        <%!-- favorite --%>
        <div
          :if={@current_user && can_fav?(@current_user, @post)}
          id={"post-#{@post.id}-fav-#{@current_user.id}"}
          class="inline-flex align-middle hover:text-emerald-600 dark:hover:text-emerald-400 hover:cursor-pointer"
          phx-click="fav"
          phx-value-id={@post.id}
          data-tippy-content="Add favorite"
          phx-hook="TippyHook"
        >
          <.phx_icon name="hero-star" class="h-4 w-4" />
          <span class="ml-1 text-xs">{@post.favs_count}</span>
        </div>

        <div
          :if={@current_user && !can_fav?(@current_user, @post)}
          id={"post-#{@post.id}-unfav-#{@current_user.id}"}
          class="inline-flex align-middle text-emerald-600 dark:text-emerald-400 hover:cursor-pointer"
          phx-click="unfav"
          phx-value-id={@post.id}
          data-tippy-content="Remove favorite"
          phx-hook="TippyHook"
        >
          <.phx_icon name="hero-star-solid" class="h-4 w-4" />
          <span class="ml-1 text-xs">{@post.favs_count}</span>
        </div>

        <div
          :if={!@current_user && @post.favs_count > 0}
          class="inline-flex align-middle text-emerald-600 dark:text-emerald-400"
        >
          <.phx_icon name="hero-star-solid" class="h-4 w-4" />
          <span class="ml-1 text-xs">{@post.favs_count}</span>
        </div>
        <div class="inline-flex space-x-2 ml-1 text-xs align-middle">
          <%!-- Reply --%>
          <div
            :if={@current_user}
            id={"post-#{@post.id}-reply-#{@current_user.id}"}
            class="inline-flex align-middle hover:text-emerald-600 dark:hover:text-emerald-400 hover:cursor-pointer"
            phx-click="reply"
            phx-value-id={@post.id}
            data-tippy-content="Reply"
            phx-hook="TippyHook"
          >
            <.phx_icon name="hero-chat-bubble-left-right" class="h-4 w-4" />
          </div>
        </div>
        <%!-- repost button --%>
        <div
          :if={@current_user && can_repost?(@current_user, @post) && is_nil(@post.group_id)}
          id={"post-#{@post.id}-repost-#{@current_user.id}"}
          class="inline-flex align-middle hover:text-purple-600 dark:hover:text-purple-400 hover:cursor-pointer"
          phx-click="repost"
          phx-value-id={@post.id}
          phx-value-body={
            decr_item(
              @post.body,
              @current_user,
              get_post_key(@post, @current_user),
              @key,
              @post,
              "body"
            )
          }
          phx-value-username={decr(@current_user.username, @current_user, @key)}
          data-tippy-content="Repost this post"
          phx-hook="TippyHook"
        >
          <.phx_icon name="hero-arrow-path-rounded-square" class="h-4 w-4" />
          <span class="ml-1 text-xs">{@post.reposts_count}</span>
        </div>

        <div
          :if={@current_user && (@post.reposts_count > 0 && !can_repost?(@current_user, @post))}
          class="inline-flex align-middle text-yellow-600 dark:text-yellow-400 cursor-default"
        >
          <.phx_icon name="hero-arrow-path-rounded-square" class="h-4 w-4" />
          <span class="ml-1 text-xs">{@post.reposts_count}</span>
        </div>

        <div
          :if={!@current_user && @post.reposts_count > 0}
          class="inline-flex align-middle text-yellow-600 dark:text-yellow-400 cursor-default"
        >
          <.phx_icon name="hero-arrow-path-rounded-square" class="h-4 w-4" />
          <span class="ml-1 text-xs">{@post.reposts_count}</span>
        </div>
      </div>
      <%!-- show / edit / delete --%>
      <div class="inline-flex space-x-2 ml-1 text-xs align-middle">
        <.link
          :if={@current_user && @post.user_id == @current_user.id}
          phx-click={JS.push("delete", value: %{id: @post.id})}
          data-confirm="Are you sure you want to delete this post?"
          class="dark:hover:text-red-400 hover:text-red-600"
          id={"delete-#{@post.id}-button"}
          data-tippy-content="Delete post"
          phx-hook="TippyHook"
        >
          Delete
        </.link>
      </div>
      <%!-- first reply --%>
      <div :if={!Enum.empty?(@post.replies)} id={"first-reply-#{@post.id}"} class="pt-4">
        <% reply = Mosslet.Timeline.first_reply(@post, assigns.options) %>
        <div :if={reply} id={"container-reply-#{reply.id}"} class="flow-root">
          <ul role="list" class="-mb-8">
            <li id={"reply-#{reply.id}"}>
              <div class="relative pb-8">
                <div class="relative flex items-start space-x-3">
                  <div :if={reply.user_id == @current_user.id} class="relative">
                    <.phx_avatar
                      src={
                        if !show_avatar?(@current_user),
                          do: "",
                          else:
                            maybe_get_avatar_src(
                              reply,
                              assigns.current_user,
                              assigns.key,
                              assigns.post_list
                            )
                      }
                      class="h-8 w-8 rounded-full"
                    />
                    <span class="absolute -bottom-0.5 -right-1 rounded-tl bg-gray-50 group-hover:bg-primary-50 dark:bg-gray-900 dark:group-hover:bg-gray-700 px-0.5 py-px">
                      <svg
                        class="h-4 w-4 text-gray-500 dark:text-gray-400"
                        viewBox="0 0 20 20"
                        fill="currentColor"
                        aria-hidden="true"
                      >
                        <path
                          fill-rule="evenodd"
                          d="M10 2c-2.236 0-4.43.18-6.57.524C1.993 2.755 1 4.014 1 5.426v5.148c0 1.413.993 2.67 2.43 2.902.848.137 1.705.248 2.57.331v3.443a.75.75 0 001.28.53l3.58-3.579a.78.78 0 01.527-.224 41.202 41.202 0 005.183-.5c1.437-.232 2.43-1.49 2.43-2.903V5.426c0-1.413-.993-2.67-2.43-2.902A41.289 41.289 0 0010 2zm0 7a1 1 0 100-2 1 1 0 000 2zM8 8a1 1 0 11-2 0 1 1 0 012 0zm5 1a1 1 0 100-2 1 1 0 000 2z"
                          clip-rule="evenodd"
                        />
                      </svg>
                    </span>
                  </div>
                  <div :if={reply.user_id != @current_user.id} class="relative">
                    <% user_connection =
                      Accounts.get_user_connection_for_reply_shared_users(
                        reply.user_id,
                        @current_user.id
                      ) %>
                    <.phx_avatar
                      src={
                        if user_connection && !show_avatar?(user_connection),
                          do: "",
                          else:
                            maybe_get_avatar_src(
                              reply,
                              assigns.current_user,
                              assigns.key,
                              assigns.post_list
                            )
                      }
                      class="h-8 w-8 rounded-full"
                    />
                    <span class="absolute -bottom-0.5 -right-1 rounded-tl bg-gray-50 group-hover:bg-primary-50 dark:bg-gray-900 dark:group-hover:bg-gray-700 px-0.5 py-px">
                      <svg
                        class="h-4 w-4 text-gray-500 dark:text-gray-400"
                        viewBox="0 0 20 20"
                        fill="currentColor"
                        aria-hidden="true"
                      >
                        <path
                          fill-rule="evenodd"
                          d="M10 2c-2.236 0-4.43.18-6.57.524C1.993 2.755 1 4.014 1 5.426v5.148c0 1.413.993 2.67 2.43 2.902.848.137 1.705.248 2.57.331v3.443a.75.75 0 001.28.53l3.58-3.579a.78.78 0 01.527-.224 41.202 41.202 0 005.183-.5c1.437-.232 2.43-1.49 2.43-2.903V5.426c0-1.413-.993-2.67-2.43-2.902A41.289 41.289 0 0010 2zm0 7a1 1 0 100-2 1 1 0 000 2zM8 8a1 1 0 11-2 0 1 1 0 012 0zm5 1a1 1 0 100-2 1 1 0 000 2z"
                          clip-rule="evenodd"
                        />
                      </svg>
                    </span>
                  </div>
                  <div class="min-w-0 flex-1">
                    <div>
                      <div class="inline-flex text-sm">
                        <%!-- Reply username --%>
                        <%!-- username --%>

                        <p
                          :if={reply.visibility == :private && my_post?(reply, @current_user)}
                          class="text-sm font-semibold leading-6 text-gray-900 dark:text-gray-100"
                        >
                          {decr_uconn_item(
                            get_item_connection(reply, @current_user).username,
                            @current_user,
                            get_uconn_for_shared_item(reply, @current_user),
                            @key
                          )}
                        </p>

                        <p
                          :if={reply.visibility == :connections}
                          class="text-sm font-semibold leading-6 text-gray-900 dark:text-gray-100"
                        >
                          {decr_item(
                            reply.username,
                            @current_user,
                            get_post_key(@post, @current_user),
                            @key,
                            reply,
                            "username"
                          )}
                        </p>

                        <span :if={@current_user} class="inline-flex justify-end text-sm space-x-2">
                          <%!--
                          <.link
                            :if={@current_user && @current_user.id == reply.user_id}
                            phx-click={JS.push("edit-reply", value: %{id: reply.id})}
                            id={"edit-#{reply.id}-button"}
                            data-tippy-content="Edit reply"
                            phx-hook="TippyHook"
                            class="ml-4"
                          >
                            <.phx_icon
                              name="hero-pencil"
                              class="h-5 w-5 hover:text-green-600 dark:hover:text-green-400"
                            />
                          </.link>
                          --%>
                          <.link
                            :if={
                              @current_user &&
                                (@current_user.id == reply.user_id ||
                                   @current_user.id == @post.user_id)
                            }
                            phx-click={JS.push("delete-reply", value: %{id: reply.id})}
                            data-confirm="Are you sure you want to delete this reply?"
                            id={"delete-#{reply.id}-button"}
                            data-tippy-content="Delete reply"
                            phx-hook="TippyHook"
                            class="ml-4"
                          >
                            <.phx_icon
                              name="hero-trash"
                              class="h-5 w-5 hover:text-red-600 dark:hover:text-red-400"
                            />
                          </.link>
                        </span>
                      </div>

                      <p class="mt-0.5 text-xs text-gray-500 dark:text-gray-400">
                        Replied <.local_time_ago at={reply.inserted_at} id={reply.id} />
                      </p>

                      <span
                        :if={reply.image_urls_updated_at}
                        id={"timestamp-#{reply.id}-updated"}
                        class="invisible inline-flex text-xs text-gray-500 dark:text-gray-400 align-middle"
                      >
                        <time datetime={reply.updated_at}>
                          <.local_time_ago
                            id={"#{reply.id}-updated"}
                            at={reply.image_urls_updated_at}
                          />
                        </time>
                      </span>
                    </div>
                    <div class="mt-2 text-sm text-gray-600 dark:text-gray-400">
                      <p>
                        {decr_item(
                          reply.body,
                          @current_user,
                          get_post_key(@post, @current_user),
                          @key,
                          reply,
                          "body"
                        )}
                      </p>
                    </div>
                    <div
                      :if={!Enum.empty?(@post.replies) && Enum.count(@post.replies) > 1}
                      class="flex justify-start"
                    >
                      <.link
                        navigate={~p"/app/posts/#{@post}"}
                        class="whitespace-nowrap text-sm font-light text-primary-700 dark:text-primary-200 hover:text-primary-600 dark:hover:text-primary-400"
                      >
                        See more replies <span aria-hidden="true"> &rarr;</span>
                      </.link>
                    </div>
                  </div>
                </div>
              </div>
            </li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  attr :id, :string, doc: "the html id of the post"
  attr :current_user, :string, required: true
  attr :key, :string, required: true
  attr :post, Mosslet.Timeline.Post, required: true
  attr :reply_count, :integer, doc: "the total count of post's replies"

  attr :color, :atom,
    default: :purple,
    values: [:emerald, :orange, :pink, :purple, :rose, :yellow, :zinc]

  attr :options, :map, doc: "the pagination options map"
  attr :reply_loading, :boolean, required: true, doc: "whether the post is being loaded or not"
  attr :reply_list, :list, doc: "the list of posts in the stream"
  attr :src, :string, default: "", doc: "the src image string"

  attr :reply_loading_count, :integer,
    required: true,
    doc: "the integer for the post to be loaded"

  attr :finished_loading_list, :list,
    default: [],
    doc: "the list of post_ids that have finished being loaded"

  attr :group, Mosslet.Groups.Group, default: nil, doc: "the optional group struct"

  attr :stream, :list,
    default: [],
    doc: "the list of items in the stream (typically replies in this case)"

  attr :loading_list, :list,
    default: [],
    doc: "the list of items that may be loading"

  attr :reply_index, :string,
    default: "",
    doc: "the index of the reply in the list of replies (typically the associated post's id)"

  def single_post(assigns) do
    assigns =
      assign(
        assigns,
        :src,
        maybe_get_avatar_src(assigns.post, assigns.current_user, assigns.key, nil)
      )

    ~H"""
    <div class="flex-1 max-w-full mt-4 justify-center items-center">
      <div
        id={@id}
        class="pt-4 sm:px-4 bg-background-100 text-gray-900 dark:text-gray-200 border border-yellow-600 dark:border-yellow-400 rounded-lg dark:bg-gray-900"
      >
        <div class="group flex gap-x-4 pb-5 px-2 transition border-none">
          <div
            :if={not is_nil(@current_user)}
            id={"post-avatar-#{@post.id}"}
            class="flex flex-col flex-shrink-0 space-y-1 items-center"
          >
            <div
              :if={
                (not @reply_loading && @src != "") ||
                  @post.id in @finished_loading_list
              }
              id={"post-show-#{@post.id}"}
            >
              <% user_connection =
                Accounts.get_user_connection_for_reply_shared_users(@post.user_id, @current_user.id) %>
              <.phx_avatar src={
                if user_connection && !show_avatar?(user_connection), do: "", else: @src
              } />
              <.phx_avatar
                :if={@post.user_id == @current_user.id}
                src={if !show_avatar?(@current_user), do: "", else: @src}
              />
            </div>
            <div
              :if={
                (@reply_loading && @src == "" &&
                   not is_nil(get_user_from_post(@post).connection.avatar_url)) ||
                  (@post.id not in @finished_loading_list && @src == "" &&
                     not is_nil(get_user_from_post(@post).connection.avatar_url))
              }
              id={"post-show-#{@post.id}"}
              class="inline-block rounded-md h-12 w-12"
            >
              <.spinner size="md" class="text-primary-500" />
            </div>
            <div
              :if={
                !@reply_loading && @src == "" &&
                  is_nil(get_user_from_post(@post).connection.avatar_url)
              }
              id={"post-show-#{@post.id}"}
              class="inline-block rounded-md h-12 w-12"
            >
              <% user_connection =
                Accounts.get_user_connection_for_reply_shared_users(@post.user_id, @current_user.id) %>
              <.phx_avatar src={
                if user_connection && !show_avatar?(user_connection), do: "", else: @src
              } />
            </div>
            <span
              :if={@post.repost}
              class="inline-flex items-center rounded-md bg-purple-100 px-2 py-1 text-xs font-medium text-purple-700"
            >
              repost
            </span>
            <%!-- sharing with group badge --%>
            <span
              :if={not is_nil(@post.group_id)}
              class="group-hover:hidden inline-flex items-center rounded-md bg-green-50 dark:bg-green-950 px-2 py-1 text-xs font-light text-green-700 dark:text-green-300 ring-1 ring-inset ring-green-700/10 dark:ring-green-300/50"
            >
              Group
            </span>
            <span
              :if={not is_nil(@post.group_id)}
              class="hidden group-hover:inline-flex items-center rounded-md bg-green-50 dark:bg-green-950 px-2 py-1 text-xs font-light text-green-700 dark:text-green-300 ring-1 ring-inset ring-green-700/10 dark:ring-green-300/50"
            >
              <.link
                id={"link-#{@post.id}-group-#{@post.group_id}"}
                navigate={~p"/app/groups/#{@post.group_id}"}
                data-tippy-content="Go to Group"
                phx-hook="TippyHook"
              >
                Group
              </.link>
            </span>
          </div>

          <div
            :if={is_nil(@current_user)}
            id={"post-avatar-#{@post.id}-no-user"}
            class="flex flex-col flex-shrink-0 space-y-1 items-center"
          >
            <image
              :if={is_nil(@current_user)}
              src={~p"/images/logo.svg"}
              class="inline-block h-12 w-12 rounded-md bg-zinc-100 dark:bg-gray-800"
            />
            <span
              :if={@post.repost}
              class="inline-flex items-center rounded-md bg-purple-100 px-2 py-1 text-xs font-medium text-purple-700"
            >
              repost
            </span>
          </div>

          <div class="relative flex-auto">
            <div class="flex items-baseline justify-between gap-x-4">
              <%!-- username --%>

              <p
                :if={@post.visibility == :private}
                class="text-sm font-semibold leading-6 text-gray-900 dark:text-gray-100"
              >
                {decr_uconn_item(
                  get_item_connection(@post, @current_user).username,
                  @current_user,
                  get_uconn_for_shared_item(@post, @current_user),
                  @key
                )}
              </p>

              <p
                :if={@post.visibility == :connections}
                class="text-sm font-semibold leading-6 text-gray-900 dark:text-gray-100"
              >
                {decr_item(
                  @post.username,
                  @current_user,
                  get_post_key(@post, @current_user),
                  @key,
                  @post,
                  "username"
                )}
              </p>

              <%!-- sharing with users badge --%>
              <div
                :if={
                  get_shared_item_identity_atom(@post, @current_user) == :self &&
                    !Enum.empty?(@post.shared_users)
                }
                class="absolute right-2 -bottom-2 group space-x-1"
              >
                <span
                  :for={uconn <- get_shared_item_user_connection(@post, @current_user)}
                  :if={uconn}
                  class={"inline-flex items-center rounded-full group-hover:bg-purple-100 dark:group-hover:bg-purple-900 group-hover:px-2 group-hover:py-1 group-hover:text-xs group-hover:font-medium #{if uconn, do: badge_group_hover_color(uconn.color)} group-hover:space-x-1"}
                >
                  <svg
                    class={"h-1.5 w-1.5 #{if uconn, do: badge_svg_fill_color(uconn.color)}"}
                    viewBox="0 0 6 6"
                    aria-hidden="true"
                  >
                    <circle cx="3" cy="3" r="3" />
                  </svg>
                  <span class="hidden group-hover:flex">
                    {get_username_for_uconn(uconn, @current_user, @key)}
                  </span>
                </span>
              </div>
              <%!-- timestamp && label badge --%>
              <p class="flex-none text-xs text-gray-600 dark:text-gray-400">
                <span class="inline-flex items-center space-x-1">
                  <span
                    :if={get_shared_item_identity_atom(@post, @current_user) == :self}
                    class="inline-flex items-center rounded-full"
                  >
                    <svg class="h-1.5 w-1.5 fill-primary-500" viewBox="0 0 6 6" aria-hidden="true">
                      <circle cx="3" cy="3" r="3" />
                    </svg>
                  </span>

                  <span
                    :if={get_shared_item_identity_atom(@post, @current_user) == :connection}
                    class={"inline-flex items-center rounded-full group group-hover:bg-purple-100 dark:group-hover:bg-purple-900 group-hover:px-2 group-hover:py-1 group-hover:text-xs group-hover:font-medium #{badge_group_hover_color(@color)} group-hover:space-x-1"}
                  >
                    <svg
                      class={"h-1.5 w-1.5 #{badge_svg_fill_color(@color)}"}
                      viewBox="0 0 6 6"
                      aria-hidden="true"
                    >
                      <circle cx="3" cy="3" r="3" />
                    </svg>
                    <span class="hidden group-hover:flex">
                      {get_shared_post_label(@post, @current_user, @key)}
                    </span>
                  </span>

                  <.local_time_ago id={@post.id} at={@post.inserted_at} />

                  <span
                    :if={@post.image_urls_updated_at}
                    id={"timestamp-#{@post.id}-updated"}
                    class="invisible inline-flex text-xs text-gray-500 dark:text-gray-400 align-middle"
                  >
                    <time datetime={@post.updated_at}>
                      <.local_time_ago id={"#{@post.id}-updated"} at={@post.image_urls_updated_at} />
                    </time>
                  </span>
                </span>
              </p>
            </div>

            <div id={"post-body-#{@post.id}"} phx-hook="TrixContentPostHook" class="post-body">
              {html_block(
                decr_item(
                  @post.body,
                  @current_user,
                  get_post_key(@post, @current_user),
                  @key,
                  @post,
                  "body"
                )
              )}
            </div>
            <%!-- actions --%>
            <div class="inline-flex mt-6 space-x-2 align-middle">
              <.post_show_photos_icon
                post={@post}
                current_user={@current_user}
              />
              <%!-- favorite --%>
              <div
                :if={@current_user && can_fav?(@current_user, @post)}
                id={"post-#{@post.id}-fav-#{@current_user.id}"}
                class="inline-flex align-middle hover:text-emerald-600 dark:hover:text-emerald-400 hover:cursor-pointer"
                phx-click="fav"
                phx-value-id={@post.id}
                data-tippy-content="Add favorite"
                phx-hook="TippyHook"
              >
                <.phx_icon name="hero-star" class="h-4 w-4" />
                <span class="ml-1 text-xs">{@post.favs_count}</span>
              </div>

              <div
                :if={@current_user && !can_fav?(@current_user, @post)}
                id={"post-#{@post.id}-unfav-#{@current_user.id}"}
                class="inline-flex align-middle text-emerald-600 dark:text-emerald-400 hover:cursor-pointer"
                phx-click="unfav"
                phx-value-id={@post.id}
                data-tippy-content="Remove favorite"
                phx-hook="TippyHook"
              >
                <.phx_icon name="hero-star-solid" class="h-4 w-4" />
                <span class="ml-1 text-xs">{@post.favs_count}</span>
              </div>

              <div
                :if={!@current_user && @post.favs_count > 0}
                class="inline-flex align-middle text-emerald-600 dark:text-emerald-400"
              >
                <.phx_icon name="hero-star-solid" class="h-4 w-4" />
                <span class="ml-1 text-xs">{@post.favs_count}</span>
              </div>
              <div class="inline-flex space-x-2 ml-1 text-xs align-middle">
                <%!-- Reply --%>
                <div
                  :if={@current_user}
                  id={"post-#{@post.id}-reply-#{@current_user.id}"}
                  class="inline-flex align-middle hover:text-emerald-600 dark:hover:text-emerald-400 hover:cursor-pointer"
                  phx-click="reply"
                  phx-value-id={@post.id}
                  data-tippy-content="Reply"
                  phx-hook="TippyHook"
                >
                  <.phx_icon name="hero-chat-bubble-left-right" class="h-4 w-4" />
                </div>
              </div>
              <%!-- repost button --%>
              <div
                :if={@current_user && can_repost?(@current_user, @post) && is_nil(@post.group_id)}
                id={"post-#{@post.id}-repost-#{@current_user.id}"}
                class="inline-flex align-middle hover:text-purple-600 dark:hover:text-purple-400 hover:cursor-pointer"
                phx-click="repost"
                phx-value-id={@post.id}
                phx-value-body={
                  decr_item(
                    @post.body,
                    @current_user,
                    get_post_key(@post, @current_user),
                    @key,
                    @post,
                    "body"
                  )
                }
                phx-value-username={decr(@current_user.username, @current_user, @key)}
                data-tippy-content="Repost this post"
                phx-hook="TippyHook"
              >
                <.phx_icon name="hero-arrow-path-rounded-square" class="h-4 w-4" />
                <span class="ml-1 text-xs">{@post.reposts_count}</span>
              </div>

              <div
                :if={@current_user && (@post.reposts_count > 0 && !can_repost?(@current_user, @post))}
                class="inline-flex align-middle text-yellow-600 dark:text-yellow-400 cursor-default"
              >
                <.phx_icon name="hero-arrow-path-rounded-square" class="h-4 w-4" />
                <span class="ml-1 text-xs">{@post.reposts_count}</span>
              </div>

              <div
                :if={!@current_user && @post.reposts_count > 0}
                class="inline-flex align-middle text-yellow-600 dark:text-yellow-400 cursor-default"
              >
                <.phx_icon name="hero-arrow-path-rounded-square" class="h-4 w-4" />
                <span class="ml-1 text-xs">{@post.reposts_count}</span>
              </div>
            </div>
            <%!-- show / edit / delete --%>
            <div class="inline-flex space-x-2 ml-1 mt-6 text-xs align-middle">
              <%!--
              <span :if={@current_user && @post.user_id == @current_user.id}>

                <.link
                  patch={
                    if @post.visibility == :public,
                      do: ~p"/public/posts/#{@post}/edit",
                      else: ~p"/app/timeline/#{@post}/edit"
                  }
                  class="dark:hover:text-green-400 hover:text-green-600"
                  id={"edit-#{@post.id}-button"}
                  data-tippy-content="Edit post"
                  phx-hook="TippyHook"
                >
                  Edit
                </.link>
              </span>
              --%>
              <.link
                :if={@current_user && @post.user_id == @current_user.id}
                phx-click={JS.push("delete", value: %{id: @post.id})}
                data-confirm="Are you sure you want to delete this post?"
                class="dark:hover:text-red-400 hover:text-red-600"
                id={"delete-#{@post.id}-button"}
                data-tippy-content="Delete post"
                phx-hook="TippyHook"
              >
                Delete
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    <div id="replies" phx-update="stream" class="flex flex-col justify-center px-4 pt-6">
      <div
        :for={{id, item} <- @stream}
        :if={item}
        id={id}
        class={[
          "group flex space-x-3 mb-4 py-1.5 px-1 bg-white border-2 rounded-md border-gray-200 dark:border-gray-700 shadow-md dark:shadow-emerald-500/50 dark:bg-gray-800"
        ]}
      >
        <.reply
          :if={item}
          reply={item}
          post={@post}
          current_user={@current_user}
          user_connection={
            if item.user_id != @current_user.id,
              do: Accounts.get_user_connection_for_reply_shared_users(item.user_id, @current_user.id)
          }
          key={@key}
          color={get_uconn_color_for_shared_item(item, @current_user) || :purple}
          id={"reply-card-#{id}"}
          reply_index={id}
          reply_loading_count={@reply_loading_count}
          reply_loading={@reply_loading}
          reply_list={@loading_list}
          reply_user={get_user_from_item(item)}
          loading_id={
            Enum.find_index(@loading_list, fn {_index, element} ->
              Kernel.to_string(element.id) == String.trim(id, "replies-")
            end)
          }
          finished_loading_list={@finished_loading_list}
        />
      </div>
    </div>
    <%!-- pagination --%>

    <nav
      :if={@reply_count > 0}
      id="reply-pagination"
      class="flex items-center justify-between border-t border-gray-200 px-4 sm:px-0"
    >
      <div class="-mt-px flex w-0 flex-1">
        <.link
          :if={@options.page > 1}
          patch={~p"/app/posts/#{@post}?#{%{@options | page: @options.page - 1}}"}
          class="inline-flex items-center group border-t-2 border-transparent pl-1 pt-4 text-sm font-medium text-gray-400 dark:text-gray-500 hover:border-gray-300 hover:text-gray-700 dark:hover:text-gray-200"
        >
          <svg
            class="mr-3 h-5 w-5 text-gray-400 dark:text-gray-500 group-hover:text-gray-700 dark:group-hover:text-gray-200"
            viewBox="0 0 20 20"
            fill="currentColor"
            aria-hidden="true"
          >
            <path
              fill-rule="evenodd"
              d="M18 10a.75.75 0 01-.75.75H4.66l2.1 1.95a.75.75 0 11-1.02 1.1l-3.5-3.25a.75.75 0 010-1.1l3.5-3.25a.75.75 0 111.02 1.1l-2.1 1.95h12.59A.75.75 0 0118 10z"
              clip-rule="evenodd"
            />
          </svg>
          Previous
        </.link>
      </div>
      <div class="hidden sm:-mt-px sm:flex">
        <.link
          :for={{page_number, current_page?} <- pages(@options, @reply_count)}
          class={
            if current_page?,
              do:
                "inline-flex items-center border-t-2 border-primary-500 px-4 pt-4 text-sm font-medium text-primary-600 dark:text-primary-400",
              else:
                "inline-flex items-center border-t-2 border-transparent pl-1 pt-4 text-sm font-medium text-gray-400 dark:text-gray-500 hover:border-gray-300 hover:text-gray-700 dark:hover:text-gray-200"
          }
          patch={~p"/app/posts/#{@post}?#{%{@options | page: page_number}}"}
          aria-current="page"
        >
          {page_number}
        </.link>
      </div>
      <div class="-mt-px flex w-0 flex-1 justify-end">
        <.link
          :if={more_pages?(@options, @reply_count)}
          patch={~p"/app/posts/#{@post}?#{%{@options | page: @options.page + 1}}"}
          class="inline-flex items-center group border-t-2 border-transparent pl-1 pt-4 text-sm font-medium text-gray-400 dark:text-gray-500 hover:border-gray-300 hover:text-gray-700 dark:hover:text-gray-200"
        >
          Next
          <svg
            class="ml-3 h-5 w-5 text-gray-400 dark:text-gray-500 group-hover:text-gray-700 dark:group-hover:text-gray-200"
            viewBox="0 0 20 20"
            fill="currentColor"
            aria-hidden="true"
          >
            <path
              fill-rule="evenodd"
              d="M2 10a.75.75 0 01.75-.75h12.59l-2.1-1.95a.75.75 0 111.02-1.1l3.5 3.25a.75.75 0 010 1.1l-3.5 3.25a.75.75 0 11-1.02-1.1l2.1-1.95H2.75A.75.75 0 012 10z"
              clip-rule="evenodd"
            />
          </svg>
        </.link>
      </div>
    </nav>
    """
  end

  attr :id, :string, doc: "the html id for the reply card"
  attr :current_user, :string, required: true
  attr :key, :string, required: true
  attr :post, Mosslet.Timeline.Post, required: true

  attr :color, :atom,
    default: :purple,
    values: [:emerald, :orange, :pink, :purple, :rose, :yellow, :zinc]

  attr :loading_id, :integer,
    required: true,
    doc: "the integer id of the reply being loaded (matched from indexed list)"

  attr :reply_loading, :boolean, required: true, doc: "whether the post is being loaded or not"
  attr :reply_list, :list, doc: "the list of posts in the stream"
  attr :src, :string, default: "", doc: "the src image string"

  attr :reply_loading_count, :integer,
    required: true,
    doc: "the integer for the reply to be loaded"

  attr :finished_loading_list, :list,
    default: [],
    doc: "the list of replu_ids that have finished being loaded"

  attr :reply_user, Accounts.User, doc: "the user whom the reply belongs to"
  attr :user_connection, Accounts.UserConnection, doc: "the user_connection struct"

  attr :reply_index, :string,
    doc: "the index of the reply in the list of replies (typically the associated post's id)"

  attr :reply, Mosslet.Timeline.Reply, doc: "the reply struct"

  def reply(assigns) do
    assigns =
      assign(
        assigns,
        :src,
        maybe_get_avatar_src(assigns.reply, assigns.current_user, assigns.key, assigns.reply_list)
      )

    ~H"""
    <%!-- replies --%>
    <div class="pt-1">
      <div class="flex flex-col">
        <div role="list" class="-mb-8">
          <div id={"reply-#{@reply.id}"}>
            <div class="relative pb-8">
              <div class="relative flex items-start space-x-3">
                <div class="relative">
                  <.phx_avatar
                    :if={@user_connection}
                    src={if !show_avatar?(@user_connection), do: "", else: @src}
                    class="h-8 w-8 rounded-full"
                  />
                  <.phx_avatar
                    :if={!@user_connection}
                    src={if !show_avatar?(@current_user), do: "", else: @src}
                    class="h-8 w-8 rounded-full"
                  />
                  <span class="absolute -bottom-0.5 -right-1 rounded-tl bg-gray-50 group-hover:bg-primary-50 dark:bg-gray-900 dark:group-hover:bg-gray-700 px-0.5 py-px">
                    <svg
                      class="h-4 w-4 text-gray-500 dark:text-gray-400"
                      viewBox="0 0 20 20"
                      fill="currentColor"
                      aria-hidden="true"
                    >
                      <path
                        fill-rule="evenodd"
                        d="M10 2c-2.236 0-4.43.18-6.57.524C1.993 2.755 1 4.014 1 5.426v5.148c0 1.413.993 2.67 2.43 2.902.848.137 1.705.248 2.57.331v3.443a.75.75 0 001.28.53l3.58-3.579a.78.78 0 01.527-.224 41.202 41.202 0 005.183-.5c1.437-.232 2.43-1.49 2.43-2.903V5.426c0-1.413-.993-2.67-2.43-2.902A41.289 41.289 0 0010 2zm0 7a1 1 0 100-2 1 1 0 000 2zM8 8a1 1 0 11-2 0 1 1 0 012 0zm5 1a1 1 0 100-2 1 1 0 000 2z"
                        clip-rule="evenodd"
                      />
                    </svg>
                  </span>
                </div>
                <div class="min-w-0 flex-1">
                  <div>
                    <div class="inline-flex text-sm">
                      <%!-- Reply username --%>
                      <%!-- username --%>
                      <p
                        :if={@reply.visibility == :private}
                        class="text-sm font-semibold leading-6 text-gray-900 dark:text-gray-100"
                      >
                        {decr_uconn_item(
                          get_item_connection(@reply, @current_user).username,
                          @current_user,
                          get_uconn_for_shared_item(@reply, @current_user),
                          @key
                        )}
                      </p>

                      <p
                        :if={@reply.visibility in [:connections]}
                        class="text-sm font-semibold leading-6 text-gray-900 dark:text-gray-100"
                      >
                        {decr_item(
                          @reply.username,
                          @current_user,
                          get_post_key(@post, @current_user),
                          @key,
                          @reply,
                          "username"
                        )}
                      </p>

                      <span :if={@current_user} class="inline-flex justify-end text-sm space-x-2">
                        <%!--
                        <.link
                          :if={@current_user && @current_user.id == @reply.user_id}
                          patch={
                            if @post.visibility == :public,
                              do: ~p"/public/posts/#{@post}/show/#{@reply}/edit",
                              else: ~p"/app/timeline/#{@post}/show/#{@reply}/edit"
                          }
                          id={"edit-#{@reply.id}-button"}
                          data-tippy-content="Edit reply"
                          phx-hook="TippyHook"
                          class="ml-4"
                        >
                          <.phx_icon
                            name="hero-pencil"
                            class="h-5 w-5 hover:text-green-600 dark:hover:text-green-400"
                          />
                        </.link>
                        --%>
                        <.link
                          :if={
                            @current_user &&
                              (@current_user.id == @reply.user_id || @current_user.id == @post.user_id)
                          }
                          phx-click={JS.push("delete-reply", value: %{id: @reply.id})}
                          data-confirm="Are you sure you want to delete this reply?"
                          id={"delete-#{@reply.id}-button"}
                          data-tippy-content="Delete reply"
                          phx-hook="TippyHook"
                          class="ml-4"
                        >
                          <.phx_icon
                            name="hero-trash"
                            class="h-5 w-5 hover:text-red-600 dark:hover:text-red-400"
                          />
                        </.link>
                      </span>
                    </div>
                    <div class="flex space-x-2">
                      <p class="mt-0.5 text-xs text-gray-500 dark:text-gray-400">
                        Replied <.local_time_ago at={@reply.inserted_at} id={@reply.id} />
                      </p>
                      <.post_reply_show_photos_icon
                        current_user={@current_user}
                        reply={@reply}
                      />
                    </div>

                    <span
                      :if={@reply.image_urls_updated_at}
                      id={"timestamp-#{@reply.id}-updated"}
                      class="invisible inline-flex text-xs text-gray-500 dark:text-gray-400 align-middle"
                    >
                      <time datetime={@reply.updated_at}>
                        <.local_time_ago
                          id={"#{@reply.id}-updated"}
                          at={@reply.image_urls_updated_at}
                        />
                      </time>
                    </span>
                  </div>
                  <div
                    id={"reply-body-#{@reply.id}"}
                    phx-hook="TrixContentReplyHook"
                    class="post-body"
                  >
                    {html_block(
                      decr_item(
                        @reply.body,
                        @current_user,
                        get_post_key(@post, @current_user),
                        @key,
                        @reply,
                        "body"
                      )
                    )}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def post_show_photos_icon(assigns) do
    ~H"""
    <button
      id={"post-#{@post.id}-show-photos-#{@current_user.id}"}
      class="inline-flex align-middle hover:text-emerald-600 dark:hover:text-emerald-400 hover:cursor-pointer"
      phx-click={
        JS.dispatch("mosslet:show-post-photos-#{@post.id}",
          to: "#post-card-#{@post.id}",
          detail: %{post_id: @post.id, user_id: @current_user.id}
        )
      }
      data-tippy-content="Show photos"
      phx-hook="TippyHook"
    >
      <.phx_icon name="hero-photo" class="h-4 w-4" />
    </button>
    """
  end

  def post_reply_show_photos_icon(assigns) do
    ~H"""
    <button
      id={"reply-#{@reply.id}-show-photos-#{@current_user.id}"}
      class="inline-flex align-middle hover:text-emerald-600 dark:hover:text-emerald-400 hover:cursor-pointer"
      phx-click={
        JS.dispatch("mosslet:show-reply-photos-#{@reply.id}",
          to: "#reply-#{@reply.id}",
          detail: %{reply_id: @reply.id, user_id: @current_user.id}
        )
      }
      data-tippy-content="Show photos"
      phx-hook="TippyHook"
    >
      <.phx_icon name="hero-photo" class="h-4 w-4" />
    </button>
    """
  end

  attr :at, :any, required: true
  attr :id, :any, required: true

  def local_time(assigns) do
    ~H"""
    <time phx-hook="LocalTime" id={"time-#{@id}"} class="hidden">{@at}</time>
    """
  end

  defp more_pages?(options, post_count) do
    options.page * options.per_page < post_count
  end

  defp pages(options, post_count) do
    page_count = ceil(post_count / options.per_page)

    for page_number <- (options.page - 2)..(options.page + 2),
        page_number > 0 do
      if page_number <= page_count do
        current_page? = page_number == options.page
        {page_number, current_page?}
      end
    end
  end
end
