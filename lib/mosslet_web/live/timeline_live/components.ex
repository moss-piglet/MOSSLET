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

  def timeline_header(assigns) do
    ~H"""
    <div>
      <img
        :if={@current_user.connection.profile}
        class="mb-4 h-32 w-full object-cover lg:h-48"
        src={~p"/images/profile/#{get_banner_image_for_connection(@current_user.connection)}"}
        alt="profile banner image"
      />
      <div class="mx-auto flex items-center justify-between max-w-4xl px-6">
        <div class="flex items-center space-x-5">
          <div>
            <h1 class="text-4xl font-bold text-gray-900 dark:text-gray-100">
              Timeline
            </h1>
          </div>
        </div>
        <div class="mt-6 flex flex-col-reverse justify-stretch space-y-4 space-y-reverse sm:flex-row-reverse sm:justify-end sm:space-x-3 sm:space-y-0 sm:space-x-reverse md:mt-0 md:flex-row md:space-x-3">
          <%!-- filter / page / sort --%>
          <div class="inline-flex items-center">
            <div id="filter-for-posts" class="flex justify-start py-2 ml-2 sm:ml-6">
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

            <div id="per-page-for-posts" class="flex justify-start py-2 ml-2 sm:ml-6">
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
      <div class="px-4 py-6 sm:px-6">
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
    <div id={@id} class="relative timeline-post anchor">
      <div :if={@post.user_id == @current_user.id} class="shrink-0">
        <.phx_avatar
          :if={@post.user_id == @current_user.id}
          class="size-10 rounded-full"
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
          class="size-10 rounded-full"
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
        <div class="inline-flex text-sm justify-start">
          <div class="font-medium flex-none text-gray-900 dark:text-gray-100">
            {decr_item(
              @post.username,
              @current_user,
              get_post_key(@post, @current_user),
              @key,
              @post,
              "username"
            )}
          </div>
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

        <div class="mt-2 space-x-2 text-sm">
          <div class="inline-flex space-x-2 py-2 align-middle">
            <%!-- favorite post icon --%>
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
            <.timeline_post_show_photos_icon
              current_user={@current_user}
              post={@post}
            />
            <%!-- favorite post icon --%>
            <.timeline_post_favorite_icon
              :if={@current_user && can_fav?(@current_user, @post)}
              current_user={@current_user}
              post={@post}
            />
            <%!-- unfavorite post icon --%>
            <.timeline_post_unfavorite_icon
              :if={@current_user && !can_fav?(@current_user, @post)}
              current_user={@current_user}
              post={@post}
            />
            <div class="inline-flex space-x-2 ml-1 text-xs align-middle">
              <%!-- New Post Reply icon --%>
              <.timeline_new_post_reply_icon
                current_user={@current_user}
                post={@post}
                return_url={@return_url}
              />
            </div>
            <%!-- new repost icon --%>
            <.timeline_new_post_repost_icon current_user={@current_user} key={@key} post={@post} />
          </div>
          <%!-- show / edit / delete --%>
          <.timeline_post_actions
            :if={@current_user.id == @post.user_id}
            current_user={@current_user}
            post={@post}
            return_url={@return_url}
          />
          <span class="text-sm text-gray-500 dark:text-gray-400">&middot;</span>
          <span
            id={"timestamp-#{@post.id}-created"}
            class="inline-flex text-xs text-gray-500 dark:text-gray-400 align-middle"
          >
            <time datetime={@post.inserted_at}>
              <.local_time_ago id={"#{@post.id}-created"} at={@post.inserted_at} />
            </time>
          </span>

          <span
            :if={@post.image_urls_updated_at}
            id={"timestamp-#{@post.id}-updated"}
            class="invisible inline-flex text-xs text-gray-500 dark:text-gray-400 align-middle"
          >
            <time datetime={@post.updated_at}>
              <.local_time_ago id={"#{@post.id}-updated"} at={@post.image_urls_updated_at} />
            </time>
          </span>
        </div>

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
      <div id="show-new-post-button" class="flex-1 items-center justify-start px-4 mx-2">
        <button
          type="button"
          class="inline-flex items-center justify-center rounded-full bg-emerald-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-emerald-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600"
          phx-click={
            JS.hide(to: "#show-new-post-button")
            |> JS.toggle(to: "#new-post-container")
            |> JS.toggle(to: "#hide-new-post-button")
          }
        >
          <.phx_icon name="hero-chat-bubble-oval-left-ellipsis" class="size-5 mr-1" /> Start new Post
        </button>
      </div>
      <div id="hide-new-post-button" class="hidden flex-1 items-center justify-start mb-4 px-4 mx-2">
        <button
          type="button"
          class="inline-flex items-center justify-center rounded-full bg-emerald-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-emerald-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600"
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
        class="hidden bg-gray-50 dark:bg-gray-800 mx-4 py-6 sm:mx-6 rounded-md shadow-md dark:shadow-emerald-500/50"
      >
        <div class="flex space-x-3 pl-1 pr-2">
          <%!--
          <div class="shrink-0">
            <.phx_avatar
              class="size-10 rounded-full"
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

              <div class="mt-3 flex items-center justify-between">
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
                  class="inline-flex items-center justify-center rounded-full bg-emerald-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-emerald-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600"
                >
                  <.phx_icon name="hero-chat-bubble-oval-left-ellipsis" class="size-5 mr-1" />
                  Share Post
                </button>
                <button
                  :if={!@post_form.source.valid? && !@uploads_in_progress}
                  type="submit"
                  class="inline-flex items-center justify-center rounded-full bg-gray-600 dark:bg-gray-400 px-3 py-2 text-sm font-semibold text-white shadow-sm opacity-20"
                  disabled
                >
                  <.phx_icon name="hero-chat-bubble-oval-left-ellipsis" class="size-5 mr-1" />
                  Share Post
                </button>
                <button
                  :if={@uploads_in_progress}
                  type="submit"
                  class="inline-flex items-center justify-center rounded-full bg-gray-600 dark:bg-gray-400 px-3 py-2 text-sm font-semibold text-white shadow-sm opacity-20"
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
      class="inline-flex align-middle hover:text-emerald-600 dark:hover:text-emerald-400 hover:cursor-pointer"
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
      class="inline-flex align-middle hover:text-emerald-600 dark:hover:text-emerald-400 hover:cursor-pointer"
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
      class="inline-flex align-middle hover:text-emerald-600 dark:hover:text-emerald-400 hover:cursor-pointer"
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
      class="inline-flex align-middle hover:text-emerald-600 dark:hover:text-emerald-400 hover:cursor-pointer"
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
      class="inline-flex align-middle hover:text-emerald-600 dark:hover:text-emerald-400 hover:cursor-pointer"
      phx-click="fav"
      phx-value-id={@post.id}
      data-tippy-content="Add favorite"
      phx-hook="TippyHook"
    >
      <.phx_icon name="hero-star" class="h-4 w-4" />
      <span class="ml-1 text-xs">{@post.favs_count}</span>
    </button>
    """
  end

  def timeline_post_unfavorite_icon(assigns) do
    ~H"""
    <button
      id={"post-#{@post.id}-unfav-#{@current_user.id}"}
      class="inline-flex align-middle text-emerald-600 dark:text-emerald-400 hover:cursor-pointer"
      phx-click="unfav"
      phx-value-id={@post.id}
      data-tippy-content="Remove favorite"
      phx-hook="TippyHook"
    >
      <.phx_icon name="hero-star-solid" class="h-4 w-4" />
      <span class="ml-1 text-xs">{@post.favs_count}</span>
    </button>
    """
  end

  def timeline_new_post_reply_icon(assigns) do
    ~H"""
    <button
      :if={@current_user}
      id={"post-#{@post.id}-reply-#{@current_user.id}"}
      class="inline-flex align-middle hover:text-emerald-600 dark:hover:text-emerald-400 hover:cursor-pointer"
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
      :if={
        @current_user &&
          (@post.reposts_count > 0 && !can_repost?(@current_user, @post))
      }
      class="inline-flex align-middle text-secondary-600 dark:text-secondary-400 cursor-default"
    >
      <.phx_icon name="hero-arrow-path-rounded-square" class="h-4 w-4" />
      <span class="ml-1 text-xs">{@post.reposts_count}</span>
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
      <.link
        :if={@current_user && @post.user_id == @current_user.id}
        phx-click={JS.push("delete_post", value: %{id: @post.id})}
        data-confirm="Are you sure you want to delete this post?"
        class="dark:hover:text-red-400 hover:text-red-600"
        id={"delete-post-#{@post.id}-button"}
        data-tippy-content="Delete post"
        phx-hook="TippyHook"
      >
        Delete
      </.link>
    </div>
    """
  end

  def timeline_post_first_reply(assigns) do
    ~H"""
    <div :if={!Enum.empty?(@post.replies)} id={"first-reply-#{@post.id}"} class="pt-4">
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
              <div class="relative flex items-start space-x-3">
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
                    class="h-8 w-8 rounded-full"
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
                      <p class="text-sm font-semibold leading-6">
                        {decr_item(
                          reply.username,
                          @current_user,
                          get_post_key(@post, @current_user),
                          @key,
                          reply,
                          "body"
                        )}
                      </p>
                      <div class="inline-flex justify-end text-sm space-x-2">
                        <%!--
                        <.link
                          :if={@current_user && @current_user.id == reply.user_id}
                          id={"edit-#{reply.id}-button"}
                          phx-click="edit_reply"
                          phx-value-id={reply.id}
                          phx-value-url={@return_url}
                          data-tippy-content="Edit Reply"
                          phx-hook="TippyHook"
                          class="ml-4"
                        >
                          <.phx_icon
                            name="hero-pencil"
                            class="size-4 hover:text-green-600 dark:hover:text-green-400"
                          />
                        </.link>
                        --%>
                        <.link
                          :if={
                            @current_user &&
                              (@current_user.id == reply.user_id || @current_user.id == @post.user_id)
                          }
                          phx-click={JS.push("delete_reply", value: %{id: reply.id})}
                          data-confirm="Are you sure you want to delete this Reply?"
                          id={"delete-#{reply.id}-button"}
                          data-tippy-content="Delete Reply"
                          phx-hook="TippyHook"
                          class="ml-4"
                        >
                          <.phx_icon
                            name="hero-trash"
                            class="size-4 hover:text-red-600 dark:hover:text-red-400"
                          />
                        </.link>
                      </div>
                    </div>
                    <div class="inline-flex items-center space-x-2">
                      <p class="mt-0.5 text-xs text-gray-500 dark:text-gray-400">
                        Replied <.local_time_ago at={reply.inserted_at} id={reply.id} />
                      </p>
                      <span class="text-sm text-gray-500 dark:text-gray-400">&middot;</span>
                      <span
                        id={"timestamp-#{reply.id}-updated"}
                        class="inline-flex text-xs text-gray-500 dark:text-gray-400 align-middle"
                      >
                        <time datetime={reply.updated_at}>
                          <.local_time_ago id={"#{reply.id}-updated"} at={reply.updated_at} />
                        </time>
                        <span
                          :if={Timex.after?(reply.updated_at, reply.inserted_at)}
                          }
                          class="inline-flex items-center rounded-md bg-emerald-100 px-1.5 py-0.5 text-xs font-medium text-emerald-700"
                        >
                          Updated
                        </span>
                      </span>
                      <.timeline_reply_show_photos_icon
                        current_user={@current_user}
                        reply={reply}
                      />
                    </div>
                  </div>

                  <div id={"reply-body-#{reply.id}"} phx-hook="TrixContentReplyHook" class="post-body">
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
