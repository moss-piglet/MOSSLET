defmodule MossletWeb.TimelineLive.Components do
  @moduledoc """
  Components for user connections.
  """
  use Phoenix.Component
  use MossletWeb, :verified_routes

  alias Mosslet.Accounts
  alias MossletWeb.MemoryLive.Components, as: MemoryComponents
  alias Mosslet.Timeline
  alias Phoenix.LiveView.JS

  import MossletWeb.CoreComponents

  import MossletWeb.Helpers

  def timeline_header_content(assigns) do
    ~H"""
    <div class="mx-auto flex flex-col sm:flex-row items-start sm:items-center justify-between max-w-full sm:max-w-2xl lg:max-w-4xl px-3 sm:px-6">
      <div class="flex items-center space-x-5 mb-4 sm:mb-0">
        <div>
          <h1 class="text-2xl sm:text-3xl lg:text-4xl font-bold text-gray-900 dark:text-gray-100">
            Timeline
          </h1>
        </div>
      </div>
      <div class="w-full sm:w-auto flex flex-col sm:flex-row space-y-3 sm:space-y-0 sm:space-x-3">
        <%!-- filter / page / sort --%>
        <div class="flex flex-col sm:flex-row items-stretch sm:items-center space-y-2 sm:space-y-0 sm:space-x-2">
          <div id="filter-for-posts" class="flex-1 sm:flex-none">
            <form phx-change="filter">
              <PetalComponents.Field.field
                type="select"
                label="Filter"
                name="user_id"
                options={user_options(@post_shared_users)}
                value={@filter.user_id}
              />
            </form>
          </div>

          <div id="per-page-for-posts" class="flex-1 sm:flex-none">
            <form phx-change="filter">
              <PetalComponents.Field.field
                type="select"
                label="Per Page"
                name="post_per_page"
                options={[{"5", 5}, {"10", 10}, {"25", 25}, {"50", 50}]}
                value={@options.post_per_page}
              />
            </form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def timeline_header(assigns) do
    ~H"""
    <div>
      <img
        :if={@current_user.connection.profile}
        class="mb-4 h-24 w-full object-cover sm:h-32 lg:h-48"
        src={~p"/images/profile/#{get_banner_image_for_connection(@current_user.connection)}"}
        alt="profile banner image"
      />
      <div class="mx-auto flex flex-col sm:flex-row items-start sm:items-center justify-between max-w-full sm:max-w-2xl lg:max-w-4xl px-3 sm:px-6">
        <div class="flex items-center space-x-5 mb-4 sm:mb-0">
          <div>
            <h1 class="text-2xl sm:text-3xl lg:text-4xl font-bold text-gray-900 dark:text-gray-100">
              Timeline
            </h1>
          </div>
        </div>
        <div class="w-full sm:w-auto flex flex-col sm:flex-row space-y-3 sm:space-y-0 sm:space-x-3">
          <%!-- filter / page / sort --%>
          <div class="flex flex-col sm:flex-row items-stretch sm:items-center space-y-2 sm:space-y-0 sm:space-x-2">
            <div id="filter-for-posts" class="flex-1 sm:flex-none">
              <form phx-change="filter">
                <PetalComponents.Field.field
                  type="select"
                  label="Filter"
                  name="user_id"
                  options={user_options(@post_shared_users)}
                  value={@filter.user_id}
                />
              </form>
            </div>

            <div id="per-page-for-posts" class="flex-1 sm:flex-none">
              <form phx-change="filter">
                <PetalComponents.Field.field
                  type="select"
                  label="Per Page"
                  name="post_per_page"
                  options={[{"5", 5}, {"10", 10}, {"25", 25}, {"50", 50}]}
                  value={@options.post_per_page}
                />
              </form>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def timeline_memories(assigns) do
    ~H"""
    <div class="bg-gray-50 dark:bg-gray-900 shadow dark:shadow-emerald-500/50 sm:rounded-lg">
      <div class="flex justify-between items-center align-middle px-4 py-5 sm:px-6">
        <div class="inline-flex">
          <h2
            id="memory-timeline-title"
            class="text-lg/6 font-medium text-gray-900 dark:text-gray-100"
          >
            Memories
          </h2>
        </div>
      </div>

      <div class="border-t border-gray-200 dark:border-gray-700 px-4 py-5 sm:px-6">
        <.timeline_memory_cards
          options={@options}
          memories={@memories}
          memory_count={@memory_count}
          memory_loading={@memory_loading}
          memory_loading_count={@memory_loading_count}
          loading_list={@memory_loading_list}
          finished_loading_list={@memory_finished_loading_list}
          current_user={@current_user}
          key={@key}
          return_url={@return_url}
        />
      </div>

      <%!-- Pagination --%>
      <div>
        <.timeline_memory_pagination options={@options} memory_count={@memory_count} group={nil} />
      </div>
    </div>
    """
  end

  def timeline_memory_cards(assigns) do
    ~H"""
    <ul
      id="memories"
      role="list"
      phx-update="stream"
      class="grid grid-cols-2 gap-x-4 gap-y-8 sm:grid-cols-3 sm:gap-x-6 xl:gap-x-8"
    >
      <div id="memories-empty" class="only:block only:col-span-4 hidden">
        <.timeline_empty_memory_state />
      </div>

      <li :for={{dom_id, memory} <- @memories} id={dom_id}>
        <MemoryComponents.memory
          id={dom_id <> "-card"}
          memory={memory}
          current_user={@current_user}
          key={@key}
          color={get_uconn_color_for_shared_item(memory, @current_user) || :purple}
          memory_index={dom_id}
          memory_loading_count={@memory_loading_count}
          memory_loading={@memory_loading}
          memory_list={@loading_list}
          card_click={
            fn memory -> JS.push("show_memory", value: %{id: memory.id, url: @return_url}) end
          }
          loading_id={
            Enum.find_index(@loading_list, fn {_index, element} ->
              Kernel.to_string(element.id) == String.trim(dom_id, "memories-")
            end)
          }
          finished_loading_list={@finished_loading_list}
        />
      </li>
    </ul>
    """
  end

  def timeline_memory_pagination(assigns) do
    ~H"""
    <nav
      :if={@memory_count > 0}
      id="memory-pagination"
      class="flex bg-gray-50 dark:bg-gray-800 items-center justify-between border-t border-gray-200 dark:border-gray-700 px-4 pb-4 sm:rounded-b-lg"
    >
      <div class="-mt-px flex w-0 flex-1">
        <.link
          :if={@options.memory_page > 1}
          patch={
            if @group,
              do: ~p"/app/groups/#{@group}?#{%{@options | memory_page: @options.memory_page - 1}}",
              else: ~p"/app/timeline?#{%{@options | memory_page: @options.memory_page - 1}}"
          }
          class="inline-flex items-center border-t-2 border-transparent pr-1 pt-4 text-sm font-medium text-gray-500 dark:text-gray-400 hover:border-gray-300 hover:text-gray-700"
        >
          <svg
            class="mr-3 h-5 w-5 text-gray-400"
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
      <div class="sm:-mt-px sm:flex">
        <.link
          :for={{memory_page_number, memory_current_page?} <- memory_pages(@options, @memory_count)}
          class={
            if memory_current_page?,
              do:
                "inline-flex items-center border-t-2 border-primary-500 px-4 pt-4 text-sm font-medium text-primary-600",
              else:
                "inline-flex items-center border-t-2 border-transparent px-4 pt-4 text-sm font-medium text-gray-500 dark:text-gray-400 hover:border-gray-300 hover:text-gray-700"
          }
          patch={
            if @group,
              do: ~p"/app/groups/#{@group}?#{%{@options | memory_page: memory_page_number}}",
              else: ~p"/app/timeline?#{%{@options | memory_page: memory_page_number}}"
          }
          aria-current="memory page"
        >
          {memory_page_number}
        </.link>
      </div>
      <div class="-mt-px flex w-0 flex-1 justify-end">
        <.link
          :if={more_memory_pages?(@options, @memory_count)}
          patch={
            if @group,
              do: ~p"/app/groups/#{@group}?#{%{@options | memory_page: @options.memory_page + 1}}",
              else: ~p"/app/timeline?#{%{@options | memory_page: @options.memory_page + 1}}"
          }
          class="inline-flex items-center border-t-2 border-transparent pl-1 pt-4 text-sm font-medium text-gray-500 dark:text-gray-400 hover:border-gray-300 hover:text-gray-700"
        >
          Next
          <svg
            class="ml-3 h-5 w-5 text-gray-400"
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

  def timeline_empty_memory_state(assigns) do
    ~H"""
    <div class="text-center">
      <.phx_icon name="hero-photo" class="mx-auto size-8 text-gray-400" />
      <h3 class="mt-2 text-sm font-semibold text-gray-900 dark:text-gray-100">No Memories</h3>
      <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">You have no Memories yet.</p>
      <div class="mt-6"></div>
    </div>
    """
  end

  def timeline_empty_post_state(assigns) do
    ~H"""
    <div class="pt-4 text-center">
      <.phx_icon name="hero-chat-bubble-oval-left" class="mx-auto size-8 text-gray-400" />
      <h3 class="mt-2 text-sm font-semibold text-gray-900 dark:text-gray-100">No Posts</h3>
      <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">You have no Posts yet.</p>
      <div class="mt-6"></div>
    </div>
    """
  end

  def timeline_posts(assigns) do
    ~H"""
    <div>
      <div class="py-6">
        <ul id="posts" role="list" phx-update="stream">
          <div id="posts-empty" class="only:block only:col-span-4 hidden">
            <.timeline_empty_post_state />
          </div>

          <li :for={{dom_id, post} <- @posts} id={dom_id}>
            <.timeline_post
              id={"timeline-card-#{post.id}"}
              current_user={@current_user}
              post_shared_users={@post_shared_users}
              key={@key}
              post={post}
              posts={@posts}
              post_loading_list={@post_loading_list}
              return_url={@return_url}
              options={@options}
            />
          </li>
        </ul>

        <%!-- Pagination --%>
        <div>
          <.timeline_post_pagination options={@options} post_count={@post_count} group={nil} />
        </div>
      </div>
    </div>
    """
  end

  def timeline_post(assigns) do
    ~H"""
    <% user_post_receipt = get_user_post_receipt(@post, @current_user) %>
    <div
      id={@id}
      class="timeline-post bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 shadow-lg dark:shadow-emerald-500/10 rounded-xl transition-all duration-300 hover:shadow-xl hover:border-emerald-200 dark:hover:border-emerald-500/50 hover:-translate-y-0.5 group mb-4 mx-1 sm:mx-0 sm:mb-6"
    >
      <div :if={@post.user_id == @current_user.id} class="shrink-0">
        <.phx_avatar
          :if={@post.user_id == @current_user.id}
          class="size-12 rounded-full ring-2 ring-emerald-500/20 transition-all duration-200 hover:ring-emerald-500/50"
          src={
            if !show_avatar?(@current_user),
              do: "",
              else: maybe_get_avatar_src(@post, @current_user, @key, @posts)
          }
          alt="your avatar for post"
        />
        <span
          :if={@post.repost}
          class="inline-flex items-center rounded-md bg-purple-100 px-2 py-1 text-xs font-medium text-purple-700"
        >
          repost
        </span>
        <div class="flex sm:inline-flex my-3">
          <div
            :if={@post.user_id === @current_user.id && Enum.count(@post.user_posts) > 1}
            class=""
          >
            <.display_post_shared_users post={@post} user_connections={@post_shared_users} />
          </div>
        </div>
        <div class="flex sm:inline-flex my-3">
          <div
            :if={@post.user_id === @current_user.id && Enum.count(@post.user_posts) === 1}
            class=""
          >
            <.display_stale_post_shared_users post={@post} user_connections={@post_shared_users} />
          </div>
        </div>
      </div>
      <div :if={@post.user_id != @current_user.id} class="shrink-0">
        <% user_connection =
          Accounts.get_user_connection_for_reply_shared_users(@post.user_id, @current_user.id) %>
        <.phx_avatar
          :if={user_connection}
          class="size-12 rounded-full ring-2 ring-emerald-500/20 transition-all duration-200 hover:ring-emerald-500/50"
          src={
            if !show_avatar?(user_connection),
              do: "",
              else: maybe_get_avatar_src(@post, @current_user, @key, @posts)
          }
          alt="avatar for post"
        />
        <span
          :if={@post.repost}
          class="inline-flex items-center rounded-md bg-purple-100 px-2 py-1 text-xs font-medium text-purple-700"
        >
          repost
        </span>
      </div>

      <div class="flex flex-col">
        <div class="px-3 sm:px-6 mb-3">
          <div class="font-semibold text-lg text-gray-900 dark:text-white">
            {decr_item(
              @post.username,
              @current_user,
              get_post_key(@post, @current_user),
              @key,
              @post,
              "username"
            )}
          </div>

          <%!-- Timestamp --%>
          <time
            id={"timestamp-#{@post.id}-created"}
            class="text-xs text-gray-500 dark:text-gray-400 font-medium block mt-0.5"
            datetime={@post.inserted_at}
          >
            <.local_time_ago id={"#{@post.id}-created"} at={@post.inserted_at} />
          </time>
        </div>

        <%!-- Post Content --%>
        <div class="px-3 sm:px-6 pb-4">
          <div
            id={"post-body-#{@post.id}"}
            phx-hook="TrixContentPostHook"
            class="post-body text-gray-800 dark:text-gray-200 text-sm sm:text-base leading-relaxed break-words"
          >
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
        </div>

        <%!-- Post Actions Bar - Improved --%>
        <footer class="border-t border-gray-100 dark:border-gray-700 px-3 sm:px-6 py-3">
          <div class="flex items-center justify-between">
            <%!-- Primary engagement actions --%>
            <div class="flex items-center space-x-1">
              <%!-- Read/Unread status --%>
              <.timeline_post_read_icon
                :if={@current_user && read?(user_post_receipt)}
                current_user={@current_user}
                user_post_receipt={user_post_receipt}
              />
              <.timeline_post_unread_icon
                :if={@current_user && user_post_receipt && !read?(user_post_receipt)}
                current_user={@current_user}
                user_post_receipt={user_post_receipt}
              />

              <%!-- Favorite action --%>
              <.timeline_post_favorite_icon
                :if={@current_user && can_fav?(@current_user, @post)}
                current_user={@current_user}
                post={@post}
              />
              <.timeline_post_unfavorite_icon
                :if={@current_user && !can_fav?(@current_user, @post)}
                current_user={@current_user}
                post={@post}
              />

              <%!-- Reply action --%>
              <.timeline_new_post_reply_icon
                current_user={@current_user}
                post={@post}
                return_url={@return_url}
              />

              <%!-- Repost action --%>
              <.timeline_new_post_repost_icon
                current_user={@current_user}
                key={@key}
                post={@post}
              />

              <%!-- Photos action --%>
              <.timeline_post_show_photos_icon
                :if={photos?(@post.image_urls)}
                current_user={@current_user}
                post={@post}
              />
            </div>

            <%!-- Owner actions --%>
            <div class="flex items-center space-x-1">
              <.timeline_post_actions
                :if={@current_user.id == @post.user_id}
                current_user={@current_user}
                post={@post}
                return_url={@return_url}
              />
            </div>
          </div>
        </footer>

        <%!-- first reply --%>
        <.timeline_post_first_reply
          current_user={@current_user}
          key={@key}
          post={@post}
          post_loading_list={@post_loading_list}
          options={@options}
          return_url={@return_url}
        />
      </div>
    </div>

    <div :if={last_unread_post?(@post, @current_user)} class="relative mb-4">
      <div class="absolute inset-0 flex items-center" aria-hidden="true">
        <div class="w-full">
          <div class="absolute inset-0">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 1440 320"
              preserveAspectRatio="none"
              class="w-full h-3 rounded-full"
            >
              <defs>
                <linearGradient id="wavyGradient" x1="0%" y1="0%" x2="100%" y2="0%">
                  <stop offset="0%" class="text-teal-500" stop-color="currentColor" />
                  <stop offset="100%" class="text-emerald-500" stop-color="currentColor" />
                </linearGradient>
              </defs>
              <path
                fill="url(#wavyGradient)"
                d="M0,160L48,176C96,192,192,224,288,229.3C384,235,480,213,576,186.7C672,160,768,128,864,133.3C960,139,1056,181,1152,197.3C1248,213,1344,203,1392,197.3L1440,192L1440,320L1392,320C1344,320,1248,320,1152,320C1056,320,960,320,864,320C768,320,672,320,576,320C480,320,384,320,288,320L192,320L96,320L0,320Z"
              >
              </path>
            </svg>
          </div>
        </div>
      </div>

      <div class="relative flex justify-center">
        <span class="inline-flex align-middle px-2 text-sm bg-background-50 dark:bg-gray-950 text-background-600 dark:text-white rounded-md">
          Unread <.phx_icon name="hero-arrow-up" class="size-4 ml-1" />
        </span>
      </div>
    </div>
    """
  end

  # the @user_connections is actually the
  # shared_user structs on the Post
  # that is dynamically built with the live view
  def display_post_shared_users(assigns) do
    ~H"""
    <div
      class="z-40"
      id={"container-#{@post.id}-shared-with-dropdown"}
      phx-hook="TippyHook"
      data-tippy-content="View who you shared this post with."
    >
      <.dropdown id={"shared-with-dropdown-#{@post.id}"} svg_arrows={false}>
        <:title>
          <.phx_icon name="hero-users" />
        </:title>
        <%!-- don't use for now
        <:link
          :if={shared_with_everyone?(@user_connections, @post.user_posts)}
          phx_click={nil}
          data_confirm={nil}
          link_id={"everyone-sharing-#{@post.id}"}
          phx_hook="TippyHook"
          data_tippy_content="You are sharing this Post with all of your current Connections."
        >
          everyone
        </:link>

        --%>
        <:link
          :for={user_connection <- @user_connections}
          :if={shared_with_user?(user_connection, @post.user_posts)}
          phx_click="delete_user_post"
          phx_value_post_id={@post.id}
          phx_value_user_id={user_connection.user_id}
          phx_value_shared_username={user_connection.username}
          data_confirm={"Are you sure you want to stop sharing this Post with #{user_connection.username}?"}
          link_id={"sharing-with-user-#{user_connection.user_id}-post-#{@post.id}"}
          phx_hook="TippyHook"
          data_tippy_content={"Click to stop sharing this Post with #{user_connection.username}."}
        >
          {user_connection.username}
        </:link>
      </.dropdown>
    </div>
    """
  end

  # when you're no longer sharing a post with anyone
  def display_stale_post_shared_users(assigns) do
    ~H"""
    <div
      id={"not-sharing-#{@post.id}"}
      class="inline-flex justify-end pr-3 cursor-help"
      phx-hook="TippyHook"
      data-tippy-content="You are no longer sharing this Post with anyone. Consider deleting to keep your space clean 🌱."
    >
      <span class="inline-flex items-center rounded-full bg-gray-100 px-1.5 py-0.5 text-xs font-medium text-gray-600">
        Not sharing
      </span>
    </div>
    """
  end

  defp shared_with_user?(user_connection, user_posts) do
    Enum.any?(user_posts, fn user_post ->
      user_post.user_id == user_connection.user_id
    end)
  end

  def timeline_post_pagination(assigns) do
    ~H"""
    <nav
      :if={@post_count > 0}
      id="post-pagination"
      class="flex bg-background dark:bg-gray-950 items-center justify-between border-t border-gray-200 dark:border-gray-700 px-4 pb-4"
    >
      <div class="-mt-px flex w-0 flex-1">
        <.link
          :if={@options.post_page > 1}
          patch={
            if @group,
              do: ~p"/app/groups/#{@group}?#{%{@options | post_page: @options.post_page - 1}}",
              else: ~p"/app/timeline?#{%{@options | post_page: @options.post_page - 1}}"
          }
          class="inline-flex items-center border-t-2 border-transparent pr-1 pt-4 text-sm font-medium text-gray-500 dark:text-gray-400 hover:border-gray-300 hover:text-gray-700"
        >
          <svg
            class="mr-3 h-5 w-5 text-gray-400"
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
      <div class="sm:-mt-px sm:flex">
        <.link
          :for={{post_page_number, current_post_page?} <- post_pages(@options, @post_count)}
          class={
            if current_post_page?,
              do:
                "inline-flex items-center border-t-2 border-primary-500 px-4 pt-4 text-sm font-medium text-primary-600",
              else:
                "inline-flex items-center border-t-2 border-transparent px-4 pt-4 text-sm font-medium text-gray-500 dark:text-gray-400 hover:border-gray-300 hover:text-gray-700"
          }
          patch={
            if @group,
              do: ~p"/app/groups/#{@group}?#{%{@options | post_page: post_page_number}}",
              else: ~p"/app/timeline?#{%{@options | post_page: post_page_number}}"
          }
          aria-current="post page"
        >
          {post_page_number}
        </.link>
      </div>
      <div class="-mt-px flex w-0 flex-1 justify-end">
        <.link
          :if={more_post_pages?(@options, @post_count)}
          patch={
            if @group,
              do: ~p"/app/groups/#{@group}?#{%{@options | post_page: @options.post_page + 1}}",
              else: ~p"/app/timeline?#{%{@options | post_page: @options.post_page + 1}}"
          }
          class="inline-flex items-center border-t-2 border-transparent pl-1 pt-4 text-sm font-medium text-gray-500 dark:text-gray-400 hover:border-gray-300 hover:text-gray-700"
        >
          Next
          <svg
            class="ml-3 h-5 w-5 text-gray-400"
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

  def timeline_new_post_form(assigns) do
    ~H"""
    <div>
      <div id="show-new-post-button" class="flex-1 items-center justify-center mb-6">
        <button
          type="button"
          class="inline-flex items-center justify-center rounded-2xl bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-600 hover:to-emerald-700 px-6 py-3 text-sm font-semibold text-white shadow-xl hover:shadow-emerald-500/25 transition-all duration-200 hover:scale-105 active:scale-95"
          phx-click={
            JS.hide(to: "#show-new-post-button")
            |> JS.toggle(to: "#new-post-container")
            |> JS.toggle(to: "#hide-new-post-button")
          }
        >
          <.phx_icon name="hero-chat-bubble-oval-left-ellipsis" class="size-5 mr-2" /> Start new Post
        </button>
      </div>
      <div id="hide-new-post-button" class="hidden flex-1 items-center justify-center mb-6">
        <button
          type="button"
          class="inline-flex items-center justify-center rounded-2xl bg-gradient-to-r from-gray-500 to-gray-600 hover:from-gray-600 hover:to-gray-700 px-6 py-3 text-sm font-semibold text-white shadow-xl hover:shadow-gray-500/25 transition-all duration-200 hover:scale-105 active:scale-95"
          phx-click={
            JS.hide(to: "#hide-new-post-button")
            |> JS.toggle(to: "#new-post-container")
            |> JS.toggle(to: "#show-new-post-button")
          }
        >
          <.phx_icon name="hero-x-mark" class="size-5 mr-1" /> Close new Post
        </button>
      </div>
      <div
        id="new-post-container"
        class="hidden mt-6 bg-gradient-to-r from-white via-gray-50/80 to-white dark:from-gray-900/90 dark:via-gray-800/50 dark:to-gray-900/90 border border-gray-200/60 dark:border-emerald-500/30 shadow-xl dark:shadow-emerald-500/20 rounded-2xl p-3 sm:p-6 transition-all duration-300 hover:shadow-2xl backdrop-blur-sm animate-fade-in"
      >
        <div class="flex space-x-2 sm:space-x-3 pl-1 pr-2">
          <%!--
          <div class="shrink-0">
            <.phx_avatar
              class="size-12 rounded-full ring-2 ring-emerald-500/20 transition-all duration-200 hover:ring-emerald-500/50"
              src={
                if !show_avatar?(@current_user),
                  do: "",
                  else: maybe_get_user_avatar(@current_user, @key)
              }
              alt="your user avatar"
            />
          </div>
          --%>
          <div id="user-timeline-new-post-container" class="min-w-0 flex-1">
            <.form
              for={@post_form}
              as={:post_params}
              id="timeline-post-form"
              phx-change="validate_post"
              phx-submit="save_post"
            >
              <div>
                <.phx_input
                  field={@post_form[:user_id]}
                  type="hidden"
                  name={@post_form[:user_id].name}
                  value={@current_user.id}
                />
                <.phx_input
                  field={@post_form[:username]}
                  type="hidden"
                  name={@post_form[:username].name}
                  value={decr(@current_user.username, @current_user, @key)}
                />
                <.phx_input field={@post_form[:visibility]} type="hidden" value="connections" />

                <div id="ignore-trix-editor" phx-update="ignore">
                  <trix-editor
                    input="trix-editor"
                    placeholder="Share with all of your connections"
                    class="trix-content"
                    required
                    phx-debounce={750}
                  >
                  </trix-editor>
                </div>

                <.phx_input
                  field={@post_form[:image_urls]}
                  name={@post_form[:image_urls].name}
                  value={@post_form[:image_urls].value}
                  type="hidden"
                />

                <.phx_input
                  id="trix-editor"
                  field={@post_form[:body]}
                  name={@post_form[:body].name}
                  value={@post_form[:body].value}
                  phx-debounce={750}
                  phx-hook="TrixEditor"
                  type="hidden"
                />
              </div>

              <div class="mt-3 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
                <div class="group inline-flex items-start space-x-2 text-sm text-gray-500 dark:text-emerald-500">
                  <.phx_icon
                    name="hero-heart-solid"
                    class="size-5 shrink-0 text-gray-400 dark:text-emerald-500"
                  />
                  <span>Your words are important.</span>
                </div>

                <button
                  :if={@post_form.source.valid? && !@uploads_in_progress}
                  type="submit"
                  class="w-full sm:w-auto inline-flex items-center justify-center rounded-2xl bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-600 hover:to-emerald-700 px-6 py-3 text-sm font-semibold text-white shadow-lg hover:shadow-emerald-500/25 transition-all duration-200 hover:scale-105 active:scale-95"
                >
                  <.phx_icon name="hero-chat-bubble-oval-left-ellipsis" class="size-5 mr-1" />
                  Share Post
                </button>
                <button
                  :if={!@post_form.source.valid? && !@uploads_in_progress}
                  type="submit"
                  class="w-full sm:w-auto inline-flex items-center justify-center rounded-full bg-gray-600 dark:bg-gray-400 px-3 py-2 text-sm font-semibold text-white shadow-sm opacity-20"
                  disabled
                >
                  <.phx_icon name="hero-chat-bubble-oval-left-ellipsis" class="size-5 mr-1" />
                  Share Post
                </button>
                <button
                  :if={@uploads_in_progress}
                  type="submit"
                  class="w-full sm:w-auto inline-flex items-center justify-center rounded-full bg-gray-600 dark:bg-gray-400 px-3 py-2 text-sm font-semibold text-white shadow-sm opacity-20"
                  disabled
                >
                  <.phx_icon name="hero-chat-bubble-oval-left-ellipsis" class="size-5 mr-1" />
                  Updating...
                </button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def timeline_post_read_icon(assigns) do
    ~H"""
    <button
      id={"post-#{@user_post_receipt.id}-read-#{@current_user.id}"}
      class="inline-flex items-center px-2 sm:px-3 py-2 rounded-lg text-gray-600 dark:text-gray-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50 dark:hover:bg-emerald-900/30 transition-all duration-200 hover:scale-110 cursor-pointer"
      phx-click="toggle-unread"
      phx-value-id={@user_post_receipt.id}
      data-tippy-content="Mark Post as unread"
      phx-hook="TippyHook"
    >
      <.phx_icon name="hero-envelope" class="h-4 w-4" />
    </button>
    """
  end

  def timeline_post_unread_icon(assigns) do
    ~H"""
    <button
      id={"post-#{@user_post_receipt.id}-unread-#{@current_user.id}"}
      class="inline-flex items-center px-2 sm:px-3 py-2 rounded-lg text-gray-600 dark:text-gray-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50 dark:hover:bg-emerald-900/30 transition-all duration-200 hover:scale-110 cursor-pointer"
      phx-click="toggle-read"
      phx-value-id={@user_post_receipt.id}
      data-tippy-content="Mark Post as read"
      phx-hook="TippyHook"
    >
      <.phx_icon name="hero-envelope-open" class="h-4 w-4" />
    </button>
    """
  end

  def timeline_post_show_photos_icon(assigns) do
    ~H"""
    <button
      id={"post-#{@post.id}-show-photos-#{@current_user.id}"}
      class="inline-flex items-center px-2 sm:px-3 py-2 rounded-lg text-gray-600 dark:text-gray-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50 dark:hover:bg-emerald-900/30 transition-all duration-200 hover:scale-110 cursor-pointer"
      phx-click={
        JS.dispatch("mosslet:show-post-photos-#{@post.id}",
          to: "#timeline-card-#{@post.id}",
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

  def timeline_reply_show_photos_icon(assigns) do
    ~H"""
    <button
      id={"reply-#{@reply.id}-show-photos-#{@current_user.id}"}
      class="inline-flex items-center px-2 py-1 rounded-lg text-gray-600 dark:text-gray-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50 dark:hover:bg-emerald-900/30 transition-all duration-200 hover:scale-110 cursor-pointer"
      phx-click={
        JS.dispatch("mosslet:show-reply-photos-#{@reply.id}",
          to: "#container-reply-#{@reply.id}",
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

  def timeline_post_favorite_icon(assigns) do
    ~H"""
    <button
      id={"post-#{@post.id}-fav-#{@current_user.id}"}
      class="inline-flex items-center px-2 sm:px-3 py-2 rounded-lg text-gray-600 dark:text-gray-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50 dark:hover:bg-emerald-900/30 transition-all duration-200 hover:scale-110 cursor-pointer"
      phx-click="fav"
      phx-value-id={@post.id}
      data-tippy-content="Add favorite"
      phx-hook="TippyHook"
    >
      <.phx_icon name="hero-star" class="h-4 w-4" />
      <span class="ml-1 sm:ml-1.5 text-xs font-medium">{@post.favs_count}</span>
    </button>
    """
  end

  def timeline_post_unfavorite_icon(assigns) do
    ~H"""
    <button
      id={"post-#{@post.id}-unfav-#{@current_user.id}"}
      class="inline-flex items-center px-2 sm:px-3 py-2 rounded-lg text-emerald-600 dark:text-emerald-400 hover:text-emerald-700 dark:hover:text-emerald-300 hover:bg-emerald-50 dark:hover:bg-emerald-900/30 transition-all duration-200 hover:scale-110 cursor-pointer"
      phx-click="unfav"
      phx-value-id={@post.id}
      data-tippy-content="Remove favorite"
      phx-hook="TippyHook"
    >
      <.phx_icon name="hero-star-solid" class="h-4 w-4" />
      <span class="ml-1 sm:ml-1.5 text-xs font-medium">{@post.favs_count}</span>
    </button>
    """
  end

  def timeline_new_post_reply_icon(assigns) do
    ~H"""
    <button
      :if={@current_user}
      id={"post-#{@post.id}-reply-#{@current_user.id}"}
      class="inline-flex items-center px-2 sm:px-3 py-2 rounded-lg text-gray-600 dark:text-gray-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50 dark:hover:bg-emerald-900/30 transition-all duration-200 hover:scale-110 cursor-pointer"
      phx-click="reply"
      phx-value-id={@post.id}
      phx-value-url={@return_url}
      data-tippy-content="Reply"
      phx-hook="TippyHook"
    >
      <.phx_icon name="hero-chat-bubble-left-right" class="h-4 w-4" />
    </button>
    """
  end

  def timeline_new_post_repost_icon(assigns) do
    ~H"""
    <button
      :if={@current_user && can_repost?(@current_user, @post) && is_nil(@post.group_id)}
      id={"post-#{@post.id}-repost-#{@current_user.id}"}
      class="inline-flex items-center px-2 sm:px-3 py-2 rounded-lg text-gray-600 dark:text-gray-400 hover:text-purple-600 dark:hover:text-purple-400 hover:bg-purple-50 dark:hover:bg-purple-900/30 transition-all duration-200 hover:scale-110 cursor-pointer"
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
      <span class="ml-1 sm:ml-1.5 text-xs font-medium">{@post.reposts_count}</span>
    </button>

    <div
      :if={
        @current_user &&
          (@post.reposts_count > 0 && !can_repost?(@current_user, @post))
      }
      class="inline-flex items-center px-2 sm:px-3 py-2 rounded-lg text-secondary-600 dark:text-secondary-400 cursor-default"
    >
      <.phx_icon name="hero-arrow-path-rounded-square" class="h-4 w-4" />
      <span class="ml-1 sm:ml-1.5 text-xs font-medium">{@post.reposts_count}</span>
    </div>
    """
  end

  def timeline_post_actions(assigns) do
    ~H"""
    <div class="inline-flex space-x-2 ml-1 text-xs align-middle">
      <span :if={@current_user && @post.user_id == @current_user.id}>
        <div class="sr-only">
          <.link navigate={~p"/app/posts/#{@post}"}>
            Show
          </.link>
        </div>
        <%!--
        <.link
          class="dark:hover:text-green-400 hover:text-green-600"
          id={"edit-#{@post.id}-button"}
          phx-click="edit_post"
          phx-value-id={@post.id}
          phx-value-url={@return_url}
          data-tippy-content="Edit post"
          phx-hook="TippyHook"
        >
          Edit
        </.link>
        --%>
      </span>
      <button
        :if={@current_user && @post.user_id == @current_user.id}
        phx-click={JS.push("delete_post", value: %{id: @post.id})}
        data-confirm="Are you sure you want to delete this post?"
        class="inline-flex items-center px-2 sm:px-3 py-2 rounded-lg text-gray-600 dark:text-gray-400 hover:text-rose-600 dark:hover:text-rose-400 hover:bg-rose-50 dark:hover:bg-rose-900/30 transition-all duration-200 hover:scale-110 cursor-pointer"
        id={"delete-post-#{@post.id}-button"}
        data-tippy-content="Delete post"
        phx-hook="TippyHook"
      >
        <.phx_icon name="hero-trash" class="h-4 w-4" />
      </button>
    </div>
    """
  end

  def timeline_post_first_reply(assigns) do
    ~H"""
    <div
      :if={!Enum.empty?(@post.replies)}
      id={"first-reply-#{@post.id}"}
      class="my-2 pt-3 pb-2 px-3 sm:px-4 bg-background-50 dark:bg-gray-900 border border-background-100 dark:border-emerald-500 rounded-lg shadow-sm dark:shadow-emerald-500/30"
    >
      <% reply = Timeline.first_reply(@post, @options) %>
      <% user_connection =
        if reply,
          do: Accounts.get_user_connection_for_reply_shared_users(reply.user_id, @current_user.id) %>
      <div
        :if={(reply && user_connection) || (reply && reply.user_id == @current_user.id)}
        id={"container-reply-#{reply.id}"}
        class="flow-root"
      >
        <ul role="list" class="-mb-8">
          <li id={"reply-#{reply.id}"}>
            <div class="relative pb-8">
              <div class="relative flex items-start space-x-2 sm:space-x-3">
                <div class="relative">
                  <.phx_avatar
                    :if={user_connection}
                    src={
                      if !show_avatar?(user_connection),
                        do: "",
                        else:
                          maybe_get_avatar_src(
                            reply,
                            @current_user,
                            @key,
                            @post_loading_list
                          )
                    }
                    class="h-6 w-6 sm:h-8 sm:w-8 rounded-full"
                  />
                  <.phx_avatar
                    :if={reply.user_id == @current_user.id}
                    src={
                      if !show_avatar?(@current_user),
                        do: "",
                        else:
                          maybe_get_avatar_src(
                            reply,
                            @current_user,
                            @key,
                            @post_loading_list
                          )
                    }
                    class="h-6 w-6 sm:h-8 sm:w-8 rounded-full"
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
                    <%!-- Reply header with username and date --%>
                    <div class="flex items-center justify-between mb-2">
                      <div class="flex flex-col">
                        <%!-- Reply username --%>
                        <div class="font-semibold text-base text-gray-900 dark:text-white">
                          {decr_item(
                            reply.username,
                            @current_user,
                            get_post_key(@post, @current_user),
                            @key,
                            reply,
                            "body"
                          )}
                        </div>
                        <%!-- Reply timestamp --%>
                        <div class="text-xs text-gray-500 dark:text-gray-400 mt-0.5">
                          Replied <.local_time_ago at={reply.inserted_at} id={reply.id} />
                          <span
                            :if={Timex.after?(reply.updated_at, reply.inserted_at)}
                            class="inline-flex items-center rounded-md bg-emerald-100 px-1 py-0.5 text-xs font-medium text-emerald-700 ml-2"
                          >
                            Updated
                          </span>
                        </div>
                      </div>
                      <%!-- Reply actions --%>
                      <div class="flex items-center space-x-1">
                        <.timeline_reply_show_photos_icon
                          :if={photos?(reply.image_urls)}
                          current_user={@current_user}
                          reply={reply}
                        />
                        <button
                          :if={
                            @current_user &&
                              (@current_user.id == reply.user_id || @current_user.id == @post.user_id)
                          }
                          phx-click={JS.push("delete_reply", value: %{id: reply.id})}
                          data-confirm="Are you sure you want to delete this Reply?"
                          id={"delete-#{reply.id}-button"}
                          data-tippy-content="Delete Reply"
                          phx-hook="TippyHook"
                          class="inline-flex items-center px-2 py-1 rounded-lg text-gray-600 dark:text-gray-400 hover:text-rose-600 dark:hover:text-rose-400 hover:bg-rose-50 dark:hover:bg-rose-900/30 transition-all duration-200 hover:scale-110 cursor-pointer"
                        >
                          <.phx_icon
                            name="hero-trash"
                            class="h-3 w-3"
                          />
                        </button>
                      </div>
                    </div>
                  </div>

                  <div
                    id={"reply-body-#{reply.id}"}
                    phx-hook="TrixContentReplyHook"
                    class="post-body text-sm sm:text-base break-words"
                  >
                    {html_block(
                      decr_item(
                        reply.body,
                        @current_user,
                        get_post_key(@post, @current_user),
                        @key,
                        reply,
                        "body"
                      )
                    )}
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
    """
  end

  defp more_memory_pages?(options, memory_count) do
    options.memory_page * options.memory_per_page < memory_count
  end

  defp memory_pages(options, memory_count) do
    memory_page_count = ceil(memory_count / options.memory_per_page)

    for memory_page_number <- (options.memory_page - 3)..(options.memory_page + 3),
        memory_page_number > 0 do
      if memory_page_number <= memory_page_count do
        memory_current_page? = memory_page_number == options.memory_page
        {memory_page_number, memory_current_page?}
      end
    end
  end

  defp more_post_pages?(options, post_count) do
    options.post_page * options.post_per_page < post_count
  end

  defp post_pages(options, post_count) do
    post_page_count = ceil(post_count / options.post_per_page)

    for post_page_number <- (options.post_page - 3)..(options.post_page + 3),
        post_page_number > 0 do
      if post_page_number <= post_page_count do
        post_current_page? = post_page_number == options.post_page
        {post_page_number, post_current_page?}
      end
    end
  end

  # We use the shared_users because these are
  # NOT public and so we only want to filter
  # by the current_user's connections.
  defp user_options(shared_users) do
    user_options =
      Enum.into(shared_users, [], fn su ->
        ["#{su.username}": "#{su.user_id}"]
      end)
      |> List.flatten()

    [["All posts": ""] | user_options] |> List.flatten()
  end
end
