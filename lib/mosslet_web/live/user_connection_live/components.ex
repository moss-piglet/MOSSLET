defmodule MossletWeb.UserConnectionLive.Components do
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

  def user_connection_card(assigns) do
    ~H"""
    <.link navigate={~p"/app/users/connections/#{@user_connection}"} id={@id}>
      <div class="card">
        <div class="name">
          {decr_uconn(@user_connection.connection.name, @current_user, @user_connection.key, @key)}
        </div>
        <img src={
          if !show_avatar?(@user_connection) ||
               maybe_get_avatar_src(@user_connection, @current_user, @key, @user_connections) == "",
             do: ~p"/images/logo.svg",
             else: maybe_get_avatar_src(@user_connection, @current_user, @key, @user_connections)
        } />

        <div class="details">
          @{decr_uconn(
            @user_connection.connection.username,
            @current_user,
            @user_connection.key,
            @key
          )}
          <div class="text-sm">
            <.user_connection_badge
              color={@user_connection.color}
              label={decr_uconn(@user_connection.label, @current_user, @user_connection.key, @key)}
            />
          </div>
        </div>
      </div>
    </.link>
    """
  end

  def private_banner(assigns) do
    ~H"""
    <div class="flex w-full flex-col items-center space-y-4">
      <div class="pointer-events-auto flex w-full max-w-md rounded-lg bg-white shadow-lg ring-1 ring-background-950/5 dark:shadow-emerald-500/50 dark:bg-gray-800 dark:ring-emerald-500/5">
        <div class="w-0 flex-1 p-4">
          <div class="flex items-start">
            <div class="shrink-0 pt-0.5">
              <.phx_icon name="hero-eye-slash" class="size-6" />
            </div>
            <div class="ml-3 w-0 flex-1">
              <p class="text-lg font-medium text-gray-900 dark:text-gray-100">Private Visibility</p>
              <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                Your account visibility is currently set to private. <strong class="dark:text-gray-200">No one can send you connection requests</strong>, but you can still send connection requests to others.
              </p>
            </div>
          </div>
        </div>
        <div class="flex border-l border-background-200 dark:border-emerald-800">
          <.link
            navigate={~p"/app/users/edit-visibility"}
            class="flex w-full items-center justify-center rounded-none rounded-r-lg border border-transparent p-4 text-sm font-medium text-emerald-600 dark:text-emerald-500 hover:text-emerald-500 dark:hover:text-emerald-400 focus:ring-2 focus:ring-emerald-500 focus:outline-hidden"
          >
            Change
          </.link>
        </div>
      </div>
    </div>
    """
  end

  def user_connection_badge(assigns) do
    ~H"""
    <div class={[
      "rounded-md px-2 py-1 text-xs font-medium lowercase inline-block border #{border_color(@color)}",
      @color && badge_color(@color)
    ]}>
      {@label}
    </div>
    """
  end

  def user_connection_header(assigns) do
    ~H"""
    <div>
      <img
        :if={@user_connection.connection.profile}
        class="h-32 w-full object-cover lg:h-48"
        src={~p"/images/profile/#{get_banner_image_for_connection(@user_connection.connection)}"}
        alt="profile banner image"
      />
      <div class="mx-auto max-w-3xl px-4 sm:px-6 md:flex md:items-center md:justify-between md:space-x-5 lg:max-w-7xl lg:px-8">
        <div class="flex items-center space-x-5">
          <div class={
            if get_banner_image_for_connection(@user_connection.connection) == "",
              do: "shrink-0",
              else: "-mt-12 sm:-mt-16 sm:flex sm:items-end sm:space-x-5 shrink-0"
          }>
            <div class="relative">
              <.phx_avatar
                class="size-32 sm:size-48 rounded-full"
                src={
                  if !show_avatar?(@user_connection),
                    do: "",
                    else: maybe_get_avatar_src(@user_connection, @current_user, @key, [])
                }
                alt="Avatar for user connection"
              />
              <span class="absolute inset-0 rounded-full shadow-inner" aria-hidden="true"></span>
            </div>
          </div>
          <div>
            <h1
              :if={show_name?(@user_connection)}
              class="text-2xl font-bold text-gray-900 dark:text-gray-100"
            >
              {decr_uconn(@user_connection.connection.name, @current_user, @user_connection.key, @key)}
            </h1>
            <h1
              :if={!show_name?(@user_connection)}
              class="text-2xl font-bold text-gray-900 dark:text-gray-100"
            >
              {decr_uconn(
                @user_connection.connection.username,
                @current_user,
                @user_connection.key,
                @key
              )}
            </h1>
            <p class="text-sm font-medium text-gray-500 dark:text-gray-400">
              Became your
              <span class={username_link_text_color_no_hover(@user_connection.color)}>
                {decr_uconn(@user_connection.label, @current_user, @user_connection.key, @key)}
              </span>
              on
              <time datetime={@user_connection.confirmed_at}>
                <.local_time_med id={@user_connection.id} at={@user_connection.confirmed_at} />
              </time>
            </p>
          </div>
        </div>
        <div class="mt-6 flex flex-col-reverse justify-stretch space-y-4 space-y-reverse sm:flex-row-reverse sm:justify-end sm:space-x-3 sm:space-y-0 sm:space-x-reverse md:mt-0 md:flex-row md:space-x-3">
          <.link
            :if={@current_user}
            id={"edit-button-#{@user_connection.id}"}
            class="hover:text-emerald-600"
            phx-click={
              JS.push("edit_user_connection",
                value: %{id: @user_connection.id, return_url: @return_url}
              )
            }
            data-tippy-content="Edit Connection"
            phx-hook="TippyHook"
          >
            <button
              type="button"
              class="inline-flex items-center justify-center rounded-full bg-white dark:bg-gray-800 px-3 py-2 text-sm font-semibold text-gray-900 dark:text-gray-100 shadow-md dark:shadow-emerald-500/50 ring-1 ring-offset ring-gray-300 dark:ring-gray-500 hover:bg-gray-200 dark:hover:bg-gray-900"
            >
              Edit
            </button>
          </.link>
          <.link
            :if={@current_user}
            id={"delete-button-#{@user_connection.id}"}
            phx-click={JS.push("delete", value: %{id: @user_connection.id})}
            class="hover:text-rose-600"
            data-confirm="Are you sure you wish to remove this Connection?"
            data-tippy-content="Remove Connection"
            phx-hook="TippyHook"
          >
            <button
              type="button"
              class="inline-flex items-center justify-center rounded-full bg-rose-600 px-3 py-2 text-sm font-semibold text-white shadow-md dark:shadow-rose-500/50 hover:bg-rose-500 ring-1 ring-offset ring-rose-400 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-rose-600"
            >
              Remove Connection
            </button>
          </.link>
        </div>
      </div>
    </div>
    """
  end

  def user_connection_memories(assigns) do
    ~H"""
    <div class="bg-gray-50 dark:bg-gray-900 shadow dark:shadow-emerald-500/50 sm:rounded-lg">
      <div class="flex justify-between items-center align-middle px-4 py-5 sm:px-6">
        <div class="inline-flex">
          <h2
            id="memory-connection-title"
            class="text-lg/6 font-medium text-gray-900 dark:text-gray-100"
          >
            Memories
          </h2>
        </div>
        <div class="inline-flex max-w-2xl text-sm text-gray-500 dark:text-gray-400">
          <.phx_button
            id="new-memory-button"
            phx-click="new_memory"
            phx-value-url={@return_url}
            phx-value-username={
              decr_uconn(
                @user_connection.connection.username,
                @current_user,
                @user_connection.key,
                @key
              )
            }
            phx-value-email={
              decr_uconn(
                @user_connection.connection.email,
                @current_user,
                @user_connection.key,
                @key
              )
            }
            class="inline-flex items-center align-middle text-sm rounded-full"
            phx-hook="TippyHook"
            data-tippy-content={"Share a new Memory with @ #{decr_uconn(
                @user_connection.connection.username,
                @current_user,
                @user_connection.key,
                @key
              )}"}
          >
            <.phx_icon name="hero-photo" class="size-5 mr-1" /> New Memory
          </.phx_button>
        </div>
      </div>

      <div class="border-t border-gray-200 dark:border-gray-700 px-4 py-5 sm:px-6">
        <.user_connection_memory_cards
          options={@options}
          memories={@memories}
          memory_count={@memory_count}
          memory_loading={@memory_loading}
          memory_loading_count={@memory_loading_count}
          loading_list={@loading_list}
          finished_loading_list={@finished_loading_list}
          user_connection={@user_connection}
          current_user={@current_user}
          key={@key}
          return_url={@return_url}
        />
      </div>

      <%!-- Pagination --%>
      <div>
        <.user_connection_memory_pagination
          options={@options}
          memory_count={@memory_count}
          user_connection={@user_connection}
        />
      </div>
    </div>
    """
  end

  attr :options, :map, doc: "the pagination options map"
  attr :memory_count, :integer, doc: "the total count of current_user's memories"
  attr :group, Mosslet.Groups.Group, default: nil, doc: "the optional group struct"

  attr :user_connection, Mosslet.Accounts.UserConnection,
    default: nil,
    doc: "the user connection struct"

  def user_connection_memory_pagination(assigns) do
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
              else:
                ~p"/app/users/connections/#{@user_connection}?#{%{@options | memory_page: @options.memory_page - 1}}"
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
              else:
                ~p"/app/users/connections/#{@user_connection}?#{%{@options | memory_page: memory_page_number}}"
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
              else:
                ~p"/app/users/connections/#{@user_connection}?#{%{@options | memory_page: @options.memory_page + 1}}"
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

  def user_connection_memory_cards(assigns) do
    ~H"""
    <ul
      id="memories"
      role="list"
      phx-update="stream"
      class="grid grid-cols-2 gap-x-4 gap-y-8 sm:grid-cols-3 sm:gap-x-6 xl:gap-x-8"
    >
      <div id="memories-empty" class="only:block only:col-span-4 hidden">
        <.empty_memory_state />
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
            fn memory ->
              JS.navigate(~p"/app/memories/#{memory.id}")
              |> JS.push("show_memory", value: %{id: memory.id, url: @return_url})
            end
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

  def user_connection_profile(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-800 px-4 py-5 shadow dark:shadow-emerald-500/50 sm:rounded-lg sm:px-6">
      <h2 id="profile-title" class="text-lg font-medium text-gray-900 dark:text-gray-100">Profile</h2>
      <div class="border-t border-gray-200 dark:border-gray-700 py-5">
        <dl class="grid grid-cols-1 gap-x-4 gap-y-8 sm:grid-cols-2">
          <div class="sm:col-span-1">
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Username</dt>
            <dd class="mt-1 text-sm text-gray-900 dark:text-gray-100">
              {decr_uconn(
                @user_connection.connection.username,
                @current_user,
                @user_connection.key,
                @key
              )}
            </dd>
          </div>
          <div class="sm:col-span-1">
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Email address</dt>
            <dd
              :if={show_email?(@user_connection)}
              class="mt-1 text-sm text-gray-900 dark:text-gray-100"
            >
              {decr_uconn(
                @user_connection.connection.email,
                @current_user,
                @user_connection.key,
                @key
              )}
            </dd>
            <dd
              :if={!show_email?(@user_connection)}
              class="mt-1 text-sm text-gray-900 dark:text-gray-100"
            >
              I'm a mystery. 😊
            </dd>
          </div>
          <div class="sm:col-span-1">
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Memory mode</dt>
            <dd
              :if={@user_connection.photos?}
              class="mt-1 text-sm text-emerald-600 dark:text-emerald-400"
            >
              <span
                id="memory-mode-true"
                phx-hook="TippyHook"
                data-tippy-content="This person can download and save memories you share with them."
              >
                <.phx_icon name="hero-check-circle" />
              </span>
            </dd>
            <dd :if={!@user_connection.photos?} class="mt-1 text-sm text-rose-600 dark:text-rose-400">
              <span
                id="memory-mode-false"
                phx-hook="TippyHook"
                data-tippy-content="This person can not download memories you share with them."
              >
                <.phx_icon name="hero-x-circle" />
              </span>
            </dd>
          </div>
          <div class="sm:col-span-1">
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Zen mode</dt>
            <dd class="mt-1 text-sm text-gray-900 dark:text-gray-100">
              {@user_connection.zen? || "coming soon"}
            </dd>
          </div>
          <div class="sm:col-span-2">
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">About</dt>
            <dd
              :if={@user_connection.connection.profile && @user_connection.connection.profile.about}
              class="mt-1 text-sm text-gray-900 dark:text-gray-100"
            >
              {decr_uconn(
                @user_connection.connection.profile.about,
                @current_user,
                @user_connection.key,
                @key
              )}
            </dd>
            <dd
              :if={!@user_connection.connection.profile || !@user_connection.connection.profile.about}
              class="mt-1 text-sm text-gray-900 dark:text-gray-100"
            >
              I'm a mystery. 😊
            </dd>
          </div>
        </dl>
      </div>
    </div>
    """
  end

  def user_connection_groups(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-800 px-4 py-5 shadow dark:shadow-emerald-500/50 sm:rounded-lg sm:px-6">
      <h2
        id="groups-title"
        class="text-lg font-medium text-gray-900 dark:text-gray-100 border-b border-gray-200 dark:border-gray-700"
      >
        Groups
      </h2>
      <div>
        <ul id="groups" role="list" phx-update="stream">
          <div id="groups-empty" class="only:block only:col-span-4 hidden">
            <.empty_group_state />
          </div>
          <li :for={{dom_id, group} <- @groups} id={dom_id}>
            <div class="flex items-center justify-between gap-x-6 py-5">
              <div class="flex min-w-0 gap-x-4">
                <div class="min-w-0 flex-auto">
                  <p class="text-sm/6 font-semibold text-gray-900 dark:text-gray-100">
                    {decr_item(
                      group.name,
                      @current_user,
                      get_user_group(group, @current_user).key,
                      @key,
                      group
                    )}
                  </p>
                  <p class="mt-1 truncate text-xs/5 text-gray-500 dark:text-gray-400">
                    {decr_item(
                      group.description,
                      @current_user,
                      get_user_group(group, @current_user).key,
                      @key,
                      group
                    )}
                  </p>
                </div>
              </div>
              <.link
                id={"group-#{group.id}-link"}
                patch={~p"/app/groups/#{group.id}"}
                class="rounded-full bg-white dark:bg-gray-950 px-2.5 py-1 text-xs font-semibold text-gray-900 dark:text-gray-100 shadow-sm dark:shadow-emerald-500/50 ring-1 ring-inset ring-gray-300 dark:ring-gray-500 hover:bg-gray-50 dark:hovery:bg-gray-900"
                data-tippy-content="View Group"
                phx-hook="TippyHook"
              >
                View
              </.link>
            </div>
          </li>
        </ul>
        <.link
          patch={~p"/app/groups"}
          class="flex w-full items-center justify-center rounded-full bg-emerald-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-emerald-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600"
        >
          View all
        </.link>
      </div>
    </div>
    """
  end

  attr :options, :map, doc: "the pagination options map"
  attr :post_count, :integer, doc: "the total count of current_user's memories"
  attr :group, Mosslet.Groups.Group, default: nil, doc: "the optional group struct"

  attr :user_connection, Mosslet.Accounts.UserConnection,
    default: nil,
    doc: "the user connection struct"

  def user_connection_posts_pagination(assigns) do
    ~H"""
    <nav
      :if={@post_count > 0}
      id="post-pagination"
      class="flex bg-white dark:bg-gray-800 items-center justify-between border-t border-gray-200 dark:border-gray-700 px-4 pb-4"
    >
      <div class="-mt-px flex w-0 flex-1">
        <.link
          :if={@options.post_page > 1}
          patch={
            if @group,
              do: ~p"/app/groups/#{@group}?#{%{@options | post_page: @options.post_page - 1}}",
              else:
                ~p"/app/users/connections/#{@user_connection}?#{%{@options | post_page: @options.post_page - 1}}"
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
              else:
                ~p"/app/users/connections/#{@user_connection}?#{%{@options | post_page: post_page_number}}"
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
              else:
                ~p"/app/users/connections/#{@user_connection}?#{%{@options | post_page: @options.post_page + 1}}"
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

  def user_connection_posts(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-800 shadow dark:shadow-emerald-500/50 sm:overflow-hidden sm:rounded-lg">
      <div class="divide-y divide-gray-200 dark:divide-gray-700">
        <div class="px-4 py-5 sm:px-6">
          <div class="inline-flex justify-between items-center align-middle w-full">
            <h2 id="posts-title" class="text-lg font-medium text-gray-900 dark:text-gray-100">
              Posts
            </h2>
            <div id="show-new-post-button" class="items-center">
              <button
                type="button"
                class="inline-flex items-center justify-center rounded-full bg-emerald-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-emerald-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600"
                phx-click={
                  JS.hide(to: "#show-new-post-button")
                  |> JS.toggle(to: "#new-post-container")
                  |> JS.toggle(to: "#hide-new-post-button")
                }
              >
                <.phx_icon name="hero-chat-bubble-oval-left-ellipsis" class="size-5 mr-1" />
                Start new Post
              </button>
            </div>
            <div id="hide-new-post-button" class="hidden items-center">
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
          </div>
        </div>
        <%!-- New Post --%>
        <.new_post_form
          id="new-user-connection-post-form"
          current_user={@current_user}
          post_form={@post_form}
          key={@key}
          user_connection={@user_connection}
          uploads_in_progress={@uploads_in_progress}
        />

        <div class="px-4 py-6 sm:px-6">
          <ul id="posts" role="list" phx-update="stream">
            <div id="posts-empty" class="only:block only:col-span-4 hidden">
              <.empty_post_state />
            </div>
            <li :for={{dom_id, post} <- @posts} id={dom_id}>
              <.user_connection_post
                id={"user-connection-card-#{post.id}"}
                current_user={@current_user}
                user_connection={@user_connection}
                key={@key}
                post={post}
                posts={@posts}
                post_loading_list={@post_loading_list}
                return_url={@return_url}
                options={@options}
              />
            </li>
          </ul>
        </div>
      </div>
      <%!-- Pagination --%>
      <div>
        <.user_connection_posts_pagination
          options={@options}
          post_count={@post_count}
          user_connection={@user_connection}
        />
      </div>
    </div>
    """
  end

  def user_connection_post(assigns) do
    ~H"""
    <div id={@id} class="flex space-x-3 mb-4">
      <div class="shrink-0">
        <.phx_avatar
          class="size-10 rounded-full"
          src={
            if !show_avatar?(@user_connection),
              do: "",
              else: maybe_get_avatar_src(@post, @current_user, @key, @posts)
          }
          alt="user avatar for post"
        />
        <span
          :if={@post.repost}
          class="inline-flex items-center rounded-md bg-purple-100 px-2 py-1 text-xs font-medium text-purple-700"
        >
          repost
        </span>
      </div>
      <div>
        <div class="text-sm">
          <a href="#" class="font-medium text-gray-900 dark:text-gray-100">
            {decr_item(
              @post.username,
              @current_user,
              get_post_key(@post, @current_user),
              @key,
              @post,
              "username"
            )}
          </a>
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
          <div class="inline-flex space-x-2 align-middle">
            <%!-- favorite post icon --%>
            <.post_favorite_icon
              :if={@current_user && can_fav?(@current_user, @post)}
              current_user={@current_user}
              post={@post}
            />
            <%!-- unfavorite post icon --%>
            <.post_unfavorite_icon
              :if={@current_user && !can_fav?(@current_user, @post)}
              current_user={@current_user}
              post={@post}
            />
            <div class="inline-flex space-x-2 ml-1 text-xs align-middle">
              <%!-- New Post Reply icon --%>
              <.new_post_reply current_user={@current_user} post={@post} return_url={@return_url} />
            </div>
            <%!-- new repost icon --%>
            <.new_post_repost_icon current_user={@current_user} key={@key} post={@post} />
          </div>
          <%!-- show / edit / delete --%>
          <.post_actions
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
            <.local_time_ago id={"#{@post.id}-created"} at={@post.inserted_at} />
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
        <.post_first_reply
          color={@user_connection.color}
          current_user={@current_user}
          reverse_user_id={@user_connection.reverse_user_id}
          key={@key}
          post={@post}
          post_loading_list={@post_loading_list}
          options={@options}
          return_url={@return_url}
        />
      </div>
    </div>
    """
  end

  def new_post_form(assigns) do
    ~H"""
    <div
      id="new-post-container"
      class="hidden bg-white dark:bg-gray-800 px-4 py-6 rounded-b-md shadow-md dark:shadow-emerald-500/50"
    >
      <div class="flex space-x-3">
        <%!--
        <div class="shrink-0">
          <.phx_avatar
            class="size-10 rounded-full"
            src={
              if show_avatar?(@current_user),
                do: maybe_get_user_avatar(@current_user, @key),
                else: ""
            }
            alt="your user avatar"
          />
        </div>
        --%>
        <div id="user-connection-post-container" class="min-w-0 flex-1">
          <.form
            :let={post_form}
            for={@post_form}
            as={:post_params}
            id="user-connection-post-form"
            phx-change="validate_post"
            phx-submit="save_post"
          >
            <div>
              <.phx_input
                field={post_form[:user_id]}
                type="hidden"
                name={post_form[:user_id].name}
                value={@current_user.id}
              />
              <.phx_input
                field={post_form[:shared_user_id]}
                type="hidden"
                name={post_form[:shared_user_id].name}
                value={@user_connection.connection.user_id}
              />
              <.phx_input
                field={post_form[:visibility]}
                type="hidden"
                name={post_form[:visibility].name}
                value="connections"
              />
              <.phx_input
                field={post_form[:shared_user_username]}
                type="hidden"
                name={post_form[:shared_user_username].name}
                value={
                  decr_uconn(
                    @user_connection.connection.username,
                    @current_user,
                    @user_connection.key,
                    @key
                  )
                }
              />
              <.phx_input
                field={post_form[:username]}
                type="hidden"
                name={post_form[:username].name}
                value={decr(@current_user.username, @current_user, @key)}
              />

              <div id="ignore-trix-editor" phx-update="ignore">
                <trix-editor
                  input="trix-editor"
                  placeholder={"Send a Post to @#{decr_uconn(
                    @user_connection.connection.username,
                    @current_user,
                    @user_connection.key,
                    @key
                  )}"}
                  class="trix-content"
                  phx-debounce="blur"
                  required
                >
                </trix-editor>
              </div>

              <.phx_input
                field={post_form[:image_urls]}
                name={post_form[:image_urls].name}
                value={post_form[:image_urls].value}
                type="hidden"
              />

              <.phx_input
                id="trix-editor"
                field={post_form[:body]}
                name={post_form[:body].name}
                value={post_form[:body].value}
                phx-debounce="blur"
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
                :if={post_form.source.valid? && !@uploads_in_progress}
                type="submit"
                class="inline-flex items-center justify-center rounded-full bg-emerald-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-emerald-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600"
              >
                Post to @{decr_uconn(
                  @user_connection.connection.username,
                  @current_user,
                  @user_connection.key,
                  @key
                )}
              </button>
              <button
                :if={!post_form.source.valid? && !@uploads_in_progress}
                type="submit"
                class="inline-flex items-center justify-center rounded-full bg-gray-600 dark:bg-gray-400 px-3 py-2 text-sm font-semibold text-white opacity-20"
                disabled
              >
                Post to @{decr_uconn(
                  @user_connection.connection.username,
                  @current_user,
                  @user_connection.key,
                  @key
                )}
              </button>
              <button
                :if={@uploads_in_progress}
                type="submit"
                class="inline-flex items-center justify-center rounded-full bg-gray-600 dark:bg-gray-400 px-3 py-2 text-sm font-semibold text-white opacity-20"
                disabled
              >
                Updating...
              </button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  def post_favorite_icon(assigns) do
    ~H"""
    <div
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
    """
  end

  def post_unfavorite_icon(assigns) do
    ~H"""
    <div
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
    """
  end

  def new_post_reply(assigns) do
    ~H"""
    <div
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
    </div>
    """
  end

  def new_post_repost_icon(assigns) do
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

  def post_actions(assigns) do
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

  def post_first_reply(assigns) do
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
                    :if={!user_connection && reply.user_id == @current_user.id}
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

                    <p class="mt-0.5 text-xs text-gray-500 dark:text-gray-400">
                      Replied <.local_time_ago at={reply.inserted_at} id={reply.id} />
                    </p>
                    <span
                      :if={reply.image_urls_updated_at}
                      id={"timestamp-#{reply.id}-updated"}
                      class="invisible inline-flex text-xs text-gray-500 dark:text-gray-400 align-middle"
                    >
                      <time datetime={reply.updated_at}>
                        <.local_time_ago id={"#{reply.id}-updated"} at={reply.image_urls_updated_at} />
                      </time>
                    </span>
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

  def empty_group_state(assigns) do
    ~H"""
    <div class="pt-4 text-center">
      <.phx_icon name="hero-user-group" class="mx-auto size-8 text-gray-400" />
      <h3 class="mt-2 text-sm font-semibold text-gray-900 dark:text-gray-100">No Groups</h3>
      <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">You have no shared Groups yet.</p>
      <div class="mt-6"></div>
    </div>
    """
  end

  def empty_post_state(assigns) do
    ~H"""
    <div class="pt-4 text-center">
      <.phx_icon name="hero-chat-bubble-oval-left" class="mx-auto size-8 text-gray-400" />
      <h3 class="mt-2 text-sm font-semibold text-gray-900 dark:text-gray-100">No Posts</h3>
      <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">You have no shared Posts yet.</p>
      <div class="mt-6"></div>
    </div>
    """
  end

  def empty_memory_state(assigns) do
    ~H"""
    <div class="text-center">
      <.phx_icon name="hero-photo" class="mx-auto size-8 text-gray-400" />
      <h3 class="mt-2 text-sm font-semibold text-gray-900 dark:text-gray-100">No Memories</h3>
      <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">You have no shared Memories yet.</p>
      <div class="mt-6"></div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :stream, :list, required: true
  attr :card_click, :any, default: nil, doc: "the function for handling phx-click on each card"
  attr :current_user, :string, required: true
  attr :key, :string, required: true
  attr :options, :map, required: true, doc: "the options for pagination"
  attr :arrivals_count, :integer, doc: "the count of user_connection arrivals"

  attr :loading_list, :list,
    default: [],
    doc: "the list of indexed user_connection arrivals to match to the stream for loading"

  slot :action, doc: "the slot for showing user actions in the last table column"

  def cards_greeter(assigns) do
    ~H"""
    <div id={@id} phx-update="stream" class="py-10 grid grid-cols-1 gap-6 divide-y divide-emerald-100">
      <div
        :for={{id, item} <- @stream}
        phx-click={@card_click.(item)}
        class={[
          "col-span-1 divide-y divide-emerald-200 gap-x-4 py-2 px-2",
          @card_click &&
            "transition hover:bg-emerald-50 dark:hover:bg-gray-900 sm:hover:rounded-2xl sm:hover:scale-105"
        ]}
      >
        <.arrival
          :if={not is_nil(item)}
          uconn={item}
          current_user={@current_user}
          key={@key}
          list_id={id}
          color={item.color || :purple}
          loading_list={@loading_list}
          arrivals_count={@arrivals_count}
        />
      </div>
    </div>
    <!-- pagination -->
    <nav
      :if={@arrivals_count > 0}
      id="arrivals-pagination"
      class="flex items-center justify-between border-t border-gray-200 px-4 sm:px-0"
    >
      <div class="-mt-px flex w-0 flex-1">
        <.link
          :if={@options.page > 1}
          patch={~p"/app/users/connections/greet?#{%{@options | page: @options.page - 1}}"}
          class="inline-flex items-center border-t-2 border-transparent pr-1 pt-4 text-sm font-medium text-gray-500 hover:border-gray-300 hover:text-gray-700"
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
      <div class="hidden md:-mt-px md:flex">
        <.link
          :for={{page_number, current_page?} <- pages(@options, @arrivals_count)}
          class={
            if current_page?,
              do:
                "inline-flex items-center border-t-2 border-primary-500 px-4 pt-4 text-sm font-medium text-primary-600",
              else:
                "inline-flex items-center border-t-2 border-transparent px-4 pt-4 text-sm font-medium text-gray-500 hover:border-gray-300 hover:text-gray-700"
          }
          patch={~p"/app/users/connections/greet?#{%{@options | page: page_number}}"}
          aria-current="page"
        >
          {page_number}
        </.link>
      </div>
      <div class="-mt-px flex w-0 flex-1 justify-end">
        <.link
          :if={more_pages?(@options, @arrivals_count)}
          patch={~p"/app/users/connections/greet?#{%{@options | page: @options.page + 1}}"}
          class="inline-flex items-center border-t-2 border-transparent pl-1 pt-4 text-sm font-medium text-gray-500 hover:border-gray-300 hover:text-gray-700"
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

  attr :current_user, :string, required: true
  attr :key, :string, required: true
  attr :uconn, Mosslet.Accounts.UserConnection, required: true
  attr :list_id, :string
  attr :arrivals_count, :integer, doc: "the count of user_connection arrivals"

  attr :color, :atom,
    default: :purple,
    values: [:emerald, :orange, :pink, :purple, :rose, :yellow, :zinc]

  attr :loading_list, :list,
    default: [],
    doc: "the list of indexed user_connection arrivals to match to the stream for loading"

  def arrival(assigns) do
    ~H"""
    <div class="flex w-full items-center justify-between space-x-6 p-2">
      <div class="flex-1 truncate">
        <div class="flex items-center space-x-3">
          <h3
            class="truncate text-sm font-medium text-gray-900 dark:text-gray-50"
            title={"username: " <> decr_uconn(@uconn.request_username, @current_user, @uconn.key, @key)}
          >
            {decr_uconn(@uconn.request_username, @current_user, @uconn.key, @key)}
          </h3>
          <span class={"inline-flex flex-shrink-0 items-center rounded-full #{badge_color(@color)} px-1.5 py-0.5 text-xs font-medium ring-1 ring-inset"}>
            {decr_uconn(@uconn.label, @current_user, @uconn.key, @key)}
          </span>
        </div>
        <p
          class="mt-1 truncate text-sm text-gray-500 dark:text-gray-400"
          title={"email: " <> decr_uconn(@uconn.request_email, @current_user, @uconn.key, @key)}
        >
          {decr_uconn(@uconn.request_email, @current_user, @uconn.key, @key)}
        </p>
        <p class="mt-1 flex justify-start text-xs space-x-4">
          <.local_time_ago id={@uconn.id} at={@uconn.inserted_at} />
        </p>
      </div>
      <div class="flex-col items-center justify-between">
        <.phx_avatar
          class="mx-auto h-10 w-10 flex-shrink-0 rounded-full"
          src={
            if !show_avatar?(@uconn),
              do: "",
              else: maybe_get_avatar_src(@uconn, @current_user, @key, @loading_list)
          }
        />
        <div class="mt-2 space-x-4">
          <.link
            :if={@current_user && @uconn.user_id == @current_user.id}
            id={"#{@uconn.id}-accept-button"}
            phx-click={JS.push("accept_uconn", value: %{id: @uconn.id})}
            class="hover:text-emerald-600"
            data-tippy-content="Accept Connection"
            phx-hook="TippyHook"
          >
            <.phx_icon name="hero-hand-thumb-up" class="h-5 w-5" />
          </.link>
          <.link
            :if={@current_user && @uconn.user_id == @current_user.id}
            id={"#{@uconn.id}-delete-button"}
            phx-click={JS.push("decline_uconn", value: %{id: @uconn.id})}
            data-confirm="Are you sure you wish to decline this request?"
            class="hover:text-rose-600"
            data-tippy-content="Privately decline Connection"
            phx-hook="TippyHook"
          >
            <.phx_icon name="hero-hand-thumb-down" class="h-5 w-5" />
          </.link>
        </div>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :stream, :list, required: true
  attr :card_click, :any, default: nil, doc: "the function for handling phx-click on each card"
  attr :page, :integer, required: true
  attr :current_user, :string, required: true
  attr :key, :string, required: true

  slot :action, doc: "the slot for showing user actions in the last table column"

  def cards_connections(assigns) do
    ~H"""
    <div
      id={"#{@id}-connections"}
      phx-update="stream"
      class="py-10 grid grid-cols-1 gap-4 sm:grid-cols-2"
    >
      <div
        :for={{id, item} <- @stream}
        id={id}
        phx-click={@card_click.(item)}
        class={[
          "relative flex items-center space-x-3 rounded-lg border border-gray-300 dark:border-emerald-300 bg-white dark:bg-gray-950 px-6 py-5 shadow-md dark:shadow-emerald-400/50 focus-within:ring-2 focus-within:ring-primary-500 focus-within:ring-offset-2 hover:border-brand-400 drag-item:focus-within:ring-0 drag-item:focus-within:ring-offset-0 drag-ghost:bg-zinc-300 drag-ghost:border-0 drag-ghost:ring-0 ",
          @card_click &&
            "transition hover:cursor-pointer hover:bg-emerald-50 dark:hover:bg-gray-900 sm:hover:rounded-2xl sm:hover:scale-105"
        ]}
      >
        <.connection
          :if={not is_nil(item)}
          uconn={item}
          current_user={@current_user}
          key={@key}
          color={item.color || :purple}
        />
      </div>
    </div>
    """
  end

  attr :current_user, :string, required: true
  attr :key, :string, required: true
  attr :uconn, Mosslet.Accounts.UserConnection, required: true

  attr :color, :atom,
    default: :purple,
    values: [:emerald, :orange, :pink, :purple, :rose, :yellow, :zinc]

  def connection(assigns) do
    ~H"""
    <% uconn_user =
      if @uconn.user_id == @current_user.id,
        do: get_user_with_preloads(@uconn.reverse_user_id),
        else: get_user_with_preloads(@uconn.user_id) %>

    <div class="flex-shrink-0">
      <.phx_avatar class="mx-auto h-10 w-10 rounded-full" src={maybe_get_user_avatar(@uconn, @key)} />
    </div>
    <div class="min-w-0 flex-1">
      <a href="#" class="focus:outline-none">
        <span class="absolute inset-0" aria-hidden="true"></span>
        <p class="text-sm font-medium text-gray-900 dark:text-gray-50">
          {if @uconn.connection.name,
            do: decr_uconn(@uconn.connection.name, @current_user, @uconn.key, @key),
            else: decr_uconn(@uconn.connection.username, @current_user, @uconn.key, @key)}
          <span class={"inline-flex items-center rounded-full #{badge_color(@color)} px-2 py-1 text-xs font-medium  ring-1 ring-inset"}>
            {decr_uconn(@uconn.label, @current_user, @uconn.key, @key)}
          </span>
        </p>
        <p class="truncate text-sm text-gray-500 dark:text-gray-400">
          {decr_uconn(@uconn.connection.email, @current_user, @uconn.key, @key)}
        </p>
      </a>
      <div class="py-1 space-x-2 ">
        <.link
          :if={
            @current_user && @uconn.user_id == @current_user.id &&
              Map.get(uconn_user.connection, :profile) &&
              uconn_user.connection.profile.visibility != :private
          }
          title="View profile"
          class="hover:text-emerald-600"
          navigate={~p"/app/profile/#{uconn_user.connection.profile.slug}"}
        >
          <.phx_icon name="hero-user-circle" class="h-5 w-5" />
        </.link>
        <.link
          :if={@current_user && @uconn.user_id == @current_user.id}
          class="hover:text-emerald-600"
          navigate={~p"/app/users/connections/#{@uconn}/edit"}
          data-tippy-content="Edit Connection"
          phx-hook="TippyHook"
        >
          <.phx_icon name="hero-pencil" class="h-5 w-5" />
        </.link>

        <.link
          :if={@current_user && @uconn.user_id == @current_user.id}
          phx-click={JS.push("delete", value: %{id: @uconn.id})}
          class="hover:text-rose-600"
          data-confirm="Are you sure you wish to delete this Connection?"
          data-tippy-content="Delete Connection"
          phx-hook="TippyHook"
        >
          <.phx_icon name="hero-trash" class="h-5 w-5" />
        </.link>
      </div>
    </div>
    """
  end

  defp more_pages?(options, count) do
    options.page * options.per_page < count
  end

  defp pages(options, count) do
    page_count = ceil(count / options.per_page)

    for page_number <- (options.page - 3)..(options.page + 3),
        page_number > 0 do
      if page_number <= page_count do
        current_page? = page_number == options.page
        {page_number, current_page?}
      end
    end
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
end
