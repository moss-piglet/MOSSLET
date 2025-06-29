defmodule MossletWeb.MemoryLive.Components do
  @moduledoc """
  Components for memories.
  """
  use MossletWeb, :component
  use MossletWeb, :verified_routes

  import MossletWeb.CoreComponents,
    only: [
      phx_avatar: 1,
      delete_icon: 1,
      phx_icon: 1,
      local_time_ago: 1,
      local_time_full: 1
    ]

  import MossletWeb.Helpers

  alias Phoenix.LiveView.JS
  alias Mosslet.Accounts

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

  def memory_image(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-950 shadow dark:shadow-emerald-500/50 sm:rounded-lg xs:col-span-2 sm:col-span-4">
      <div class="flex justify-between items-center align-middle px-4 py-5 sm:px-6">
        <div class="inline-flex">
          <h2 id="memory-title" class="text-lg/6 font-medium text-gray-900 dark:text-gray-100">
            Memory
          </h2>
        </div>
        <div class="inline-flex max-w-2xl text-sm text-gray-500 dark:text-gray-400">
          <.button
            :if={show_blur_memory?(@memory, @current_user)}
            id={"#{@memory.id}-blur-button"}
            class="rounded-full"
            phx-value-id={@memory.id}
            phx-click={
              JS.remove_class("blur-3xl", to: "#memory-image-show-#{@memory.id}")
              |> JS.push("blur-memory", value: %{id: @memory.id})
            }
          >
            Show
          </.button>
          <.button
            :if={!show_blur_memory?(@memory, @current_user)}
            id={"#{@memory.id}-blur-button"}
            class="rounded-full"
            phx-value-id={@memory.id}
            phx-click={
              JS.add_class("blur-3xl", to: "#memory-image-show-#{@memory.id}")
              |> JS.push("blur-memory", value: %{id: @memory.id})
            }
          >
            Blur
          </.button>
          <.badge
            :if={@memory.visibility == :connections && @memory.group_id}
            id={"#{@memory.id}-visibility-badge-group"}
            color="secondary"
            label={
              decr_group(
                get_group(@memory.group_id).name,
                @current_user,
                get_user_group(get_group(@memory.group_id), @current_user).key,
                @key
              )
            }
            class="rounded-full p-2"
            data-tippy-content="This Memory is being shared with this group."
            phx-hook="TippyHook"
          />
          <.button
            icon="hero-arrow-long-left"
            link_type="live_patch"
            class="ml-2 rounded-full"
            label="Back to Timeline"
            to={~p"/app/timeline"}
          />
        </div>
      </div>

      <div class="border-t border-gray-200 dark:border-gray-700 py-5">
        <img
          src={
            maybe_get_memory_src(
              assigns.memory,
              assigns.current_user,
              assigns.key,
              assigns.memory_list
            )
          }
          id={"public-memory-image-#{@memory.id}"}
          alt="memory image"
          class={
            if show_blur_memory?(@memory, @current_user),
              do:
                "blur-3xl pointer-events-none object-scale-down group-hover:opacity-75 flex-auto scroll-py-4 overflow-y-auto",
              else:
                "pointer-events-none object-scale-down group-hover:opacity-75 flex-auto scroll-py-4 overflow-y-auto"
          }
        />
      </div>
    </div>
    """
  end

  def memory_details(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-950 px-4 py-5 shadow dark:shadow-emerald-500/50 col-span-1 md:col-span-2 sm:rounded-lg sm:px-6">
      <h2 id="memory-details-title" class="text-lg font-medium text-gray-900 dark:text-gray-100">
        Details
      </h2>
      <div class="border-t border-gray-200 py-5">
        <dl class="grid grid-cols-1 gap-x-4 gap-y-8 lg:grid-cols-2">
          <div class="sm:col-span-1">
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Username</dt>
            <dd :if={@user_connection} class="mt-1 text-sm text-gray-900 dark:text-gray-100">
              {decr_uconn(
                @user_connection.connection.username,
                @current_user,
                @user_connection.key,
                @key
              )}
            </dd>
            <dd
              :if={@memory.user_id == @current_user.id}
              class="mt-1 text-sm text-gray-900 dark:text-gray-100"
            >
              {decr(
                @current_user.username,
                @current_user,
                @key
              )}
            </dd>
          </div>
          <div class="sm:col-span-1">
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Email</dt>
            <dd :if={@user_connection} class="mt-1 text-wrap text-sm text-gray-900 dark:text-gray-100">
              {decr_uconn(
                @user_connection.connection.email,
                @current_user,
                @user_connection.key,
                @key
              )}
            </dd>
            <dd
              :if={@memory.user_id == @current_user.id}
              class="mt-1 text-sm text-gray-900 dark:text-gray-100"
            >
              {decr(
                @current_user.email,
                @current_user,
                @key
              )}
            </dd>
          </div>
          <div class="sm:col-span-1">
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Blurb</dt>
            <dd :if={@memory.blurb} class="mt-1 text-wrap text-sm text-gray-900 dark:text-gray-100">
              {decr_item(
                @memory.blurb,
                @current_user,
                get_memory_key(@memory, @current_user),
                @key,
                @memory
              )}
            </dd>
          </div>

          <div class="sm:col-span-1">
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">
              Created <span class="sr-only">Memory created at</span>
            </dt>

            <dd
              id={@memory.id <> "-created-at-details"}
              class="mt-1 text-wrap text-sm text-gray-900 dark:text-gray-100"
            >
              <time datetime={@memory.inserted_at}>
                <.local_time_full id={@memory.id <> "-created"} at={@memory.inserted_at} />
              </time>
            </dd>
          </div>
          <div class="sm:col-span-1">
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Reactions</dt>
            <dd class="mt-4 text-sm text-gray-900 dark:text-gray-100">
              <%!-- Memory reactions ---%>
              <.memory_reactions
                current_user={@current_user}
                key={@key}
                memory={@memory}
                memory_list={@memory_list}
                user_connection={@user_connection}
                excited_count={@excited_count}
                loved_count={@loved_count}
                happy_count={@happy_count}
                sad_count={@sad_count}
                thumbsy_count={@thumbsy_count}
              />
            </dd>
          </div>
          <div class="sm:col-span-1">
            <%!-- Memory actions for shared memory ---%>
            <dt :if={@user_connection} class="text-sm font-medium text-gray-500 dark:text-gray-400">
              Actions
            </dt>
            <div class="inline-flex space-x-1 mt-2">
              <dd :if={@user_connection} class="mt-1 text-sm text-emerald-600 dark:text-emerald-400">
                <.link
                  id="user-connection-view-link"
                  patch={~p"/app/users/connections/#{@user_connection}"}
                  class="rounded-full bg-white dark:bg-gray-950 px-2.5 py-1 text-xs font-semibold text-gray-900 dark:text-gray-100 shadow-sm dark:shadow-emerald-500/50 ring-1 ring-inset ring-gray-300 dark:ring-gray-500 hover:bg-gray-50 dark:hovery:bg-gray-900"
                  data-tippy-content="View Connection"
                  phx-hook="TippyHook"
                >
                  View
                </.link>
              </dd>
              <dd
                :if={check_if_user_can_download_shared_memory(@memory.user_id, @current_user.id)}
                class="mt-1 text-sm text-emerald-600 dark:text-emerald-400"
              >
                <.memory_shared_actions
                  current_user={@current_user}
                  key={@key}
                  memory={@memory}
                  user_connection={@user_connection}
                  temp_socket={@temp_socket}
                />
              </dd>
            </div>

            <%!-- Memory actions for current_user's own memory ---%>
            <dt
              :if={@memory.user_id == @current_user.id}
              class="text-sm font-medium text-gray-500 dark:text-gray-400"
            >
              Actions
            </dt>
            <dd
              :if={@memory.user_id == @current_user.id}
              class="mt-1 text-sm text-emerald-600 dark:text-emerald-400"
            >
              <.memory_actions
                current_user={@current_user}
                key={@key}
                memory={@memory}
                user_connection={@user_connection}
                temp_socket={@temp_socket}
              />
            </dd>
          </div>
        </dl>
      </div>
    </div>
    """
  end

  def memory_reactions(assigns) do
    ~H"""
    <!-- reaction count -->
    <div id="mood-reactions" class="space-x-2">
      <div
        :if={
          @current_user &&
            Enum.all?(
              [@excited_count, @loved_count, @happy_count, @sad_count, @thumbsy_count],
              fn x -> x == 0 end
            )
        }
        class="inline-flex items-center"
      >
        Be the first to react!
      </div>

      <div :if={@excited_count > 0} class="relative inline-flex items-center">
        <.mood_svg mood={:excited} />
        <span
          :if={@excited_count > 1}
          class="absolute -top-3 -right-3 z-20 truncate text-xs font-medium text-rose-500 bg-rose-100 rounded-full py-0.5 px-2"
        >
          {@excited_count}
        </span>
      </div>

      <div :if={@loved_count > 0} class="relative inline-flex items-center">
        <.mood_svg mood={:loved} />
        <span
          :if={@loved_count > 1}
          class="absolute -top-3 -right-3 z-20 truncate text-xs font-medium text-pink-500 bg-pink-100 rounded-full py-0.5 px-2"
        >
          {@loved_count}
        </span>
      </div>

      <div :if={@happy_count > 0} class="relative inline-flex items-center">
        <.mood_svg mood={:happy} />
        <span
          :if={@happy_count > 1}
          class="absolute -top-3 -right-3 z-20 truncate text-xs font-medium text-green-500 bg-green-100 rounded-full py-0.5 px-2"
        >
          {@happy_count}
        </span>
      </div>

      <div :if={@sad_count > 0} class="relative inline-flex items-center">
        <.mood_svg mood={:sad} />
        <span
          :if={@sad_count > 1}
          class="absolute -top-3 -right-3 z-20 truncate text-xs font-medium text-purple-500 bg-purple-100 rounded-full py-0.5 px-2"
        >
          {@sad_count}
        </span>
      </div>

      <div :if={@thumbsy_count > 0} class="relative inline-flex items-center">
        <.mood_svg mood={:thumbsy} />
        <span
          :if={@thumbsy_count > 1}
          class="absolute -top-3 -right-3 z-20 truncate text-xs font-medium text-yellow-500 bg-yellow-100 rounded-full py-0.5 px-2"
        >
          {@thumbsy_count}
        </span>
      </div>
    </div>
    """
  end

  def memory_actions(assigns) do
    ~H"""
    <div class="space-x-2">
      <button>
        <.link
          :if={@memory.user_id == @current_user.id}
          target="_blank"
          href={
            Routes.memory_download_path(@temp_socket, :download_memory, @memory.id,
              memory_id: @memory.id,
              memory_name: "mosslet-memory-download",
              memory_file_type: @memory.type,
              current_user_id: @current_user.id,
              memory_user_id: @memory.user_id,
              key: @key
            )
          }
          id={"memory-download-link" <> @memory.id}
          data-tippy-content="Download to your device"
          phx-hook="TippyHook"
          download="mosslet-memory"
          class="text-emerald-600 hover:text-emerald-500 active:text-emerald-700 dark:hover:text-emerald-400 dark:active:text-emerald-700"
        >
          <.phx_icon name="hero-arrow-down-tray" class="size-6 ml-1" />
        </.link>
      </button>

      <%!-- Delete button ---%>
      <button :if={@current_user && @memory.user_id == @current_user.id}>
        <.link
          id={"memory-delete-button-#{@memory.id}"}
          phx-click={
            JS.push("delete_memory",
              value: %{
                id: @memory.id,
                url:
                  decr_item(
                    @memory.memory_url,
                    @current_user,
                    get_memory_key(@memory, @current_user),
                    @key,
                    @memory
                  )
              }
            )
          }
          method="delete"
          data-tippy-content="Delete your memory."
          phx-hook="TippyHook"
          data-confirm="Are you sure you want to delete this memory?"
        >
          <.phx_icon
            name="hero-trash"
            class="text-rose-600 hover:text-rose-500 active:text-rose-700 dark:hover:text-rose-400 dark:active:text-rose-700"
          />
        </.link>
      </button>
    </div>
    """
  end

  def memory_shared_actions(assigns) do
    ~H"""
    <div>
      <.link
        :if={check_if_user_can_download_shared_memory(@memory.user_id, @current_user.id)}
        target="_blank"
        href={
          Routes.memory_download_path(@temp_socket, :download_shared_memory, @memory.id,
            memory_id: @memory.id,
            memory_name: "mosslet-shared-memory-download",
            memory_file_type: @memory.type,
            current_user_id: @current_user.id,
            uconn_id: @user_connection.id,
            key: @key
          )
        }
        id={"memory-download-link-" <> @memory.id}
        data-tippy-content="Download to your device"
        phx-hook="TippyHook"
        download="mosslet-memory"
        class="text-emerald-600 hover:text-emerald-500 active:text-emerald-700 dark:hover:text-emerald-400 dark:active:text-emerald-700"
      >
        <.phx_icon name="hero-arrow-down-tray" class="size-6 ml-1" />
      </.link>
    </div>
    """
  end

  def memory_remarks(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-950 px-4 py-5 shadow dark:shadow-emerald-500/50 col-span-1 md:col-span-2 sm:rounded-lg sm:px-6">
      <h2 id="new-remark-form-title" class="text-lg font-medium text-gray-900 dark:text-gray-100">
        New Remark
      </h2>
      <div class="border-t border-gray-200 py-5">
        <%!-- New Remark form --%>
        <.live_component
          :if={@current_user}
          module={MossletWeb.MemoryLive.RemarkFormComponent}
          id={@remark.id || :new}
          memory={@memory}
          remark={@remark}
          current_user={@current_user}
          key={@key}
          patch={@patch}
        />
      </div>
    </div>
    """
  end

  def memory_remarks_feed(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-950 px-4 py-5 shadow dark:shadow-emerald-500/50 col-span-1 md:col-span-2 sm:rounded-lg sm:px-6">
      <h2 id="memory-remarks-feed-title" class="text-lg font-medium text-gray-900 dark:text-gray-100">
        Remarks
      </h2>
      <div class="border-t border-gray-200 py-5">
        <%!-- Remark feed --%>
        <div id="remarks" phx-update="stream" class="flex-col">
          <div
            :for={{dom_id, remark} <- @remarks}
            id={dom_id}
            phx-hook="HoverRemark"
            data-toggle={JS.toggle(to: "#remark-#{remark.id}-buttons")}
            class="mt-4"
          >
            <div class="relative">
              <div
                :if={is_nil(remark.body)}
                id={remark.id <> "-remark-no-body"}
                class="relative flex gap-x-4"
              >
                <p class="flex-auto py-0.5 text-xs leading-5 text-gray-500">
                  <span :if={@current_user} class="font-medium text-gray-900 dark:text-gray-100">
                    {maybe_show_remark_username(
                      decr_item(
                        get_item_connection(remark, @current_user).username,
                        @current_user,
                        get_username_remark_key(remark, @current_user),
                        @key,
                        remark
                      )
                    )}
                  </span>

                  <span :if={is_nil(remark.body)}>reacted with <%= remark.mood %></span>.
                </p>
                <div>
                  <time
                    datetime={remark.inserted_at}
                    class="flex-none py-0.5 text-xs leading-5 text-gray-500 dark:text-gray-400"
                  >
                    <.local_time_ago id={remark.id <> "-created"} at={remark.inserted_at} />
                  </time>
                  <.delete_icon
                    :if={
                      @current_user &&
                        (@current_user.id == remark.user_id ||
                           @current_user.id == @memory.user_id)
                    }
                    id={"remark-#{remark.id}-buttons"}
                    phx_click={
                      if @current_user.id == remark.user_id ||
                           @current_user.id == @memory.user_id,
                         do: "delete-remark",
                         else: nil
                    }
                    value={remark.id}
                  />
                </div>
              </div>

              <div :if={!is_nil(remark.body)} id={remark.id <> "-body"} class="relative flex gap-x-4">
                <% user_connection =
                  Accounts.get_user_connection_for_reply_shared_users(
                    remark.user_id,
                    @current_user.id
                  ) %>

                <.phx_avatar
                  :if={user_connection}
                  src={
                    if !show_avatar?(user_connection),
                      do: "",
                      else:
                        maybe_get_avatar_src(
                          remark,
                          @current_user,
                          @key,
                          @loading_list
                        )
                  }
                  size="h-6 w-6"
                  class="relative mt-3 h-6 w-6 flex-none rounded-full bg-gray-50 dark:bg-gray-900"
                />

                <.phx_avatar
                  :if={!user_connection && !is_nil(@current_user)}
                  src={
                    if !show_avatar?(@current_user),
                      do: "",
                      else:
                        maybe_get_avatar_src(
                          remark,
                          @current_user,
                          @key,
                          @loading_list
                        )
                  }
                  size="h-6 w-6"
                  class="relative mt-3 h-6 w-6 flex-none rounded-full bg-gray-50 dark:bg-gray-900"
                />
                <div class="flex-auto rounded-md p-3 ring-1 ring-inset ring-gray-200 dark:ring-primary-200">
                  <div class="flex justify-between gap-x-4">
                    <div class="py-0.5 text-xs leading-5 text-gray-500 dark:text-gray-400">
                      <span :if={@current_user} class="font-medium text-gray-900 dark:text-gray-100">
                        {maybe_show_remark_username(
                          decr_item(
                            get_item_connection(remark, @current_user).username,
                            @current_user,
                            get_username_remark_key(remark, @current_user),
                            @key,
                            remark
                          )
                        )}
                      </span>
                      remarked
                      <span :if={!is_nil(remark.body) && remark.mood != :nothing}>
                        and reacted with {remark.mood}.
                      </span>
                    </div>
                    <div>
                      <time
                        datetime={remark.inserted_at}
                        class="flex-none py-0.5 text-xs leading-5 text-gray-500"
                      >
                        <.local_time_ago id={remark.id <> "-created"} at={remark.inserted_at} />
                      </time>
                      <.delete_icon
                        :if={
                          @current_user &&
                            (@current_user.id == remark.user_id ||
                               @current_user.id == @memory.user_id)
                        }
                        id={"remark-#{remark.id}-buttons"}
                        phx_click={
                          if @current_user.id == remark.user_id ||
                               @current_user.id == @memory.user_id,
                             do: "delete-remark",
                             else: nil
                        }
                        value={remark.id}
                      />
                    </div>
                  </div>
                  <p class="text-sm leading-6 text-gray-500">
                    {maybe_show_remark_body(
                      decr_item(
                        remark.body,
                        @current_user,
                        get_memory_key(@memory, @current_user),
                        @key,
                        remark
                      )
                    )}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <.memory_remarks_pagination
        group={nil}
        memory={@memory}
        remark_count={@remark_count}
        options={@options}
        user_connection={@user_connection}
      />
    </div>
    """
  end

  def memory_remarks_pagination(assigns) do
    ~H"""
    <nav
      :if={@remark_count > 0}
      id="remarks-pagination"
      class="flex items-center justify-between border-t border-gray-200 dark:border-gray-700 px-4 sm:px-0"
    >
      <div class="-mt-px flex w-0 flex-1">
        <.link
          :if={@options.remark_page > 1}
          patch={
            if @group,
              do: ~p"/app/groups/#{@group}?#{%{@options | remark_page: @options.remark_page - 1}}",
              else:
                ~p"/app/memories/#{@memory}?#{%{@options | remark_page: @options.remark_page - 1}}"
          }
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
      <div class="-mt-px md:flex">
        <.link
          :for={{remark_page_number, remark_current_page?} <- remark_pages(@options, @remark_count)}
          class={
            if remark_current_page?,
              do:
                "inline-flex items-center border-t-2 border-primary-500 px-4 pt-4 text-sm font-medium text-primary-600",
              else:
                "inline-flex items-center border-t-2 border-transparent px-4 pt-4 text-sm font-medium text-gray-500 hover:border-gray-300 hover:text-gray-700"
          }
          patch={
            if @group,
              do: ~p"/app/groups/#{@group}?#{%{@options | remark_page: remark_page_number}}",
              else: ~p"/app/memories/#{@memory}?#{%{@options | remark_page: remark_page_number}}"
          }
          aria-current="remark page"
        >
          {remark_page_number}
        </.link>
      </div>
      <div class="-mt-px flex w-0 flex-1 justify-end">
        <.link
          :if={more_remark_pages?(@options, @remark_count)}
          patch={
            if @group,
              do: ~p"/app/groups/#{@group}?#{%{@options | page: @options.page + 1}}",
              else:
                ~p"/app/memories/#{@memory}?#{%{@options | remark_page: @options.remark_page + 1}}"
          }
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

  attr :id, :string, required: true
  attr :stream, :list, required: true
  attr :card_click, :any, default: nil, doc: "the function for handling phx-click on each card"
  attr :current_user, :string, required: true
  attr :options, :map, doc: "the pagination options map"
  attr :memory_count, :integer, doc: "the total count of current_user's memories"
  attr :key, :string, required: true
  attr :memory_loading, :boolean, required: true, doc: "whether a memory is loading or not"
  attr :group, Mosslet.Groups.Group, default: nil, doc: "the optional group struct"

  attr :loading_list, :list,
    default: [],
    doc: "the list of indexed memories to match to the stream for loading"

  attr :finished_loading_list, :list,
    default: [],
    doc: "the list of memory_ids that have finished being loaded"

  attr :memory_loading_count, :integer,
    required: true,
    doc: "the integer for the memory to be loaded"

  slot :action, doc: "the slot for showing user actions in the last table column"

  def cards(assigns) do
    ~H"""
    <ul
      id={@id}
      phx-update="stream"
      class="py-4 grid grid-cols-2 gap-x-4 gap-y-8 sm:grid-cols-4 sm:gap-x-6 lg:grid-cols-4 xl:gap-x-8"
    >
      <div id="memories-empty" class="only:block only:col-span-4 hidden">
        <.empty_memory_state />
      </div>

      <li :for={{id, item} <- @stream}>
        <.memory
          :if={item}
          id={id}
          memory={item}
          current_user={@current_user}
          key={@key}
          color={get_uconn_color_for_shared_item(item, @current_user) || :purple}
          memory_index={id}
          memory_loading_count={@memory_loading_count}
          memory_loading={@memory_loading}
          memory_list={@loading_list}
          card_click={@card_click}
          loading_id={
            Enum.find_index(@loading_list, fn {_index, element} ->
              Kernel.to_string(element.id) == String.trim(id, "memories-")
            end)
          }
          finished_loading_list={@finished_loading_list}
        />
      </li>
    </ul>
    """
  end

  attr :id, :string, required: true
  attr :stream, :list, required: true
  attr :card_click, :any, default: nil, doc: "the function for handling phx-click on each card"
  attr :current_user, :string, required: true
  attr :user, :string, required: true
  attr :key, :string, required: true
  attr :memories, :list, required: true, doc: "the list of memories"
  attr :options, :map, doc: "the pagination options map"
  attr :memory_count, :integer, doc: "the total count of current_user's memories"
  attr :memory_loading, :boolean, required: true, doc: "whether a memory is loading or not"
  attr :slug, :string, doc: "the slug for the profile url"

  attr :loading_list, :list,
    default: [],
    doc: "the list of indexed memories to match to the stream for loading"

  attr :finished_loading_list, :list,
    default: [],
    doc: "the list of memory_ids that have finished being loaded"

  attr :memory_loading_count, :integer,
    required: true,
    doc: "the integer for the memory to be loaded"

  slot :action, doc: "the slot for showing user actions in the last table column"

  def public_cards(assigns) do
    ~H"""
    <ul
      id={@id}
      phx-update="stream"
      class="py-10 grid grid-cols-2 gap-x-4 gap-y-8 sm:grid-cols-3 sm:gap-x-6 lg:grid-cols-4 xl:gap-x-8"
    >
      <li :for={{id, item} <- @stream} id={id}>
        <.public_memory
          :if={item}
          id={"public-memory-card-#{id}"}
          memory={item}
          current_user={@current_user}
          user={@user}
          key={@key}
          card_click={fn _card -> JS.patch(~p"/profile/#{@slug}/memory/#{item}") end}
          color={get_uconn_color_for_shared_item(item, @user) || :purple}
          memory_index={id}
          memory_loading_count={@memory_loading_count}
          memory_loading={@memory_loading}
          memory_list={@loading_list}
          loading_id={
            Enum.find_index(@loading_list, fn {_index, element} ->
              Kernel.to_string(element.id) == String.trim(id, "memories-")
            end)
          }
          finished_loading_list={@finished_loading_list}
        />
      </li>
    </ul>
    <!-- pagination -->
    <nav
      :if={@memory_count > 0}
      id="memory-pagination"
      class="flex items-center justify-between border-t border-gray-200 px-4 sm:px-0"
    >
      <div class="-mt-px flex w-0 flex-1">
        <.link
          :if={@options.page > 1}
          patch={~p"/profile/#{@slug}?#{%{@options | page: @options.page - 1}}"}
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
      <div class="-mt-px md:flex">
        <.link
          :for={{page_number, current_page?} <- pages(@options, @memory_count)}
          class={
            if current_page?,
              do:
                "inline-flex items-center border-t-2 border-primary-500 px-4 pt-4 text-sm font-medium text-primary-600",
              else:
                "inline-flex items-center border-t-2 border-transparent px-4 pt-4 text-sm font-medium text-gray-500 hover:border-gray-300 hover:text-gray-700"
          }
          patch={~p"/profile/#{@slug}?#{%{@options | page: page_number}}"}
          aria-current="page"
        >
          {page_number}
        </.link>
      </div>
      <div class="-mt-px flex w-0 flex-1 justify-end">
        <.link
          :if={more_pages?(@options, @memory_count)}
          patch={~p"/profile/#{@slug}?#{%{@options | page: @options.page + 1}}"}
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

  attr :id, :string, required: true
  attr :current_user, :string, required: true
  attr :key, :string, required: true
  attr :memory, Mosslet.Memories.Memory, required: true

  attr :loading_id, :integer,
    required: true,
    doc: "the integer id of the memory being loaded (matched from indexed list)"

  attr :memory_loading, :boolean, required: true, doc: "whether the memory is being loaded or not"
  attr :memory_list, :list, doc: "the list of memories in the stream"
  attr :src, :string, default: "", doc: "the src image string"
  attr :card_click, :any, default: nil, doc: "the function for handling phx-click on each card"

  attr :memory_loading_count, :integer,
    required: true,
    doc: "the integer for the memory to be loaded"

  attr :finished_loading_list, :list,
    default: [],
    doc: "the list of memory_ids that have finished being loaded"

  attr :color, :atom,
    default: :purple,
    values: [:emerald, :orange, :pink, :purple, :rose, :yellow, :zinc]

  attr :memory_index, :string, doc: "the dom_id index of the memory in the stream"

  def memory(assigns) do
    assigns =
      assign(
        assigns,
        :src,
        maybe_get_memory_src(
          assigns.memory,
          assigns.current_user,
          assigns.key,
          assigns.memory_list
        )
      )

    ~H"""
    <div
      id={"memory-thumb-container-#{@memory.id}"}
      data-tippy-content={
        case get_shared_item_identity_atom(@memory, @current_user) do
          :connection -> "Shared with you"
          :self -> "You are sharing this Memory"
          :private -> "Private to you"
          :public -> "Public Memory"
          :invalid -> "This is invalid"
        end
      }
      phx-hook="TippyHook"
    >
      <div
        :if={
          (not @memory_loading && @src != "") ||
            @memory.id in @finished_loading_list
        }
        id={"memory-[#{@loading_id}]-#{@memory.id}"}
        class={memory_thumb_class(@memory, @current_user)}
        phx-click={@card_click.(@memory)}
      >
        <img
          src={@src}
          id={"memory-image-#{@memory.id}"}
          alt=""
          class={
            if show_blur_memory?(@memory, @current_user),
              do: "blur-3xl pointer-events-none object-cover group-hover:opacity-75",
              else: "pointer-events-none object-cover group-hover:opacity-75"
          }
        />
        <div id={"#{@memory.id}-blur-button"} class="absolute top-1 left-1 z-20">
          <.button
            :if={show_blur_memory?(@memory, @current_user)}
            class="rounded-full"
            size="xs"
            phx-value-id={@memory.id}
            phx-click={
              JS.remove_class("blur-3xl", to: "#memory-image-#{@memory.id}")
              |> JS.push("blur-memory", value: %{id: @memory.id})
            }
          >
            Show
          </.button>
          <.button
            :if={!show_blur_memory?(@memory, @current_user)}
            class="rounded-full"
            size="xs"
            phx-value-id={@memory.id}
            phx-click={
              JS.add_class("blur-3xl", to: "#memory-image-#{@memory.id}")
              |> JS.push("blur-memory", value: %{id: @memory.id})
            }
          >
            Blur
          </.button>
        </div>
      </div>
      <div
        :if={
          (@memory_loading && @src == "") ||
            (@memory.id not in @finished_loading_list && @src == "")
        }
        id={"memory-[#{@loading_id}]-#{@memory.id}"}
        class={memory_thumb_class(@memory, @current_user)}
      >
        <.spinner size="md" class="text-primary-500" />
      </div>
    </div>
    """
  end

  attr :id, :string, doc: "the html id for the memory"
  attr :current_user, :string, required: true
  attr :user, :string, required: true
  attr :key, :string, required: true
  attr :memory, Mosslet.Memories.Memory, required: true

  attr :loading_id, :integer,
    required: true,
    doc: "the integer id of the memory being loaded (matched from indexed list)"

  attr :memory_loading, :boolean, required: true, doc: "whether the memory is being loaded or not"
  attr :memory_list, :list, doc: "the list of memories in the stream"
  attr :src, :string, default: "", doc: "the src image string"
  attr :card_click, :any, default: nil, doc: "the function for handling phx-click on each card"

  attr :memory_index, :string,
    doc: "the index for the memory being loaded, typically the id of the memory"

  attr :memory_loading_count, :integer,
    required: true,
    doc: "the integer for the memory to be loaded"

  attr :finished_loading_list, :list,
    default: [],
    doc: "the list of memory_ids that have finished being loaded"

  attr :color, :atom,
    default: :purple,
    values: [:emerald, :orange, :pink, :purple, :rose, :yellow, :zinc]

  def public_memory(assigns) do
    assigns =
      assign(
        assigns,
        :src,
        maybe_get_public_memory_src(
          assigns.user,
          assigns.memory,
          assigns.current_user,
          assigns.memory_list
        )
      )

    ~H"""
    <div
      id={"public-memory-thumb-container-#{@memory.id}"}
      data-tippy-content={
        case get_shared_item_identity_atom(@memory, @current_user, @user) do
          :connection ->
            "Shared with you"

          :self ->
            "You are sharing this Memory"

          :private ->
            "Private to you"

          :public ->
            "Public Memory"

          :public_self ->
            "You are sharing this Memory publicly. Anyone who can see your profile can see this Memory."
        end
      }
      phx-hook="TippyHook"
      class="relative"
    >
      <div
        :if={
          (not @memory_loading && @src != "") ||
            @memory.id in @finished_loading_list
        }
        id={"memory-[#{@loading_id}]-#{@memory.id}"}
        class={memory_thumb_class(@memory, @current_user, @user)}
        phx-click={@card_click.(@memory)}
      >
        <img
          src={@src}
          id={"public-memory-image-#{@memory.id}"}
          alt=""
          class={
            if show_blur_memory?(@memory, @current_user),
              do: "blur-3xl pointer-events-none object-cover group-hover:opacity-75",
              else: "pointer-events-none object-cover group-hover:opacity-75"
          }
        />
      </div>
      <div
        :if={
          (@memory_loading && @src == "") || (@memory.id not in @finished_loading_list && @src == "")
        }
        id={"memory-[#{@loading_id}]-#{@memory.id}"}
        class={memory_thumb_class(@memory, @current_user, @user)}
      >
        <.spinner size="md" class="text-primary-500" />
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :stream, :list, required: true
  attr :page, :integer, required: true
  attr :end_of_remarks?, :boolean, required: true
  attr :user, :any, required: true, doc: "the user for the memory"
  attr :current_user, :any, required: true, doc: "the current user of the session"
  attr :key, :string, required: true
  attr :card_click, :any, default: nil, doc: "the function for handling phx-click on each card"

  def remarks(assigns) do
    ~H"""
    <span
      :if={@page > 1}
      class="text-3xl fixed bottom-2 right-2 bg-zinc-900 text-white rounded-lg p-3 text-center min-w-[65px] z-50 opacity-80"
    >
      <span class="text-sm">pg</span>
      {@page}
    </span>

    <ul
      id={@id}
      phx-update="stream"
      phx-viewport-top={@page > 1 && "prev-page"}
      phx-viewport-bottom={!@end_of_remarks? && "next-page"}
      phx-page-loading
      class={[
        if(@end_of_remarks?, do: "pb-10", else: "pb-[calc(10vh)]"),
        if(@page == 1, do: "pt-2", else: "pt-[calc(10vh)]")
      ]}
    >
      <li
        :for={{id, item} <- @stream}
        id={id}
        phx-click={@card_click.(item)}
        class={[
          "group memoryative flex gap-x-4 space-y-2",
          @card_click &&
            "transition sm:hover:rounded-2xl sm:hover:scale-105"
        ]}
      >
        <.remark
          :if={item}
          remark={item}
          current_user={@current_user}
          user={@user}
          key={@key}
          color={get_uconn_color_for_shared_item(item, @user) || :purple}
        />
      </li>
    </ul>
    """
  end

  def remark(assigns) do
    ~H"""
    <div class="absolute left-0 top-0 flex w-6 justify-center -bottom-6"></div>
    <%!-- used to be an old .memory component here --%>
    <div class="flex-auto rounded-md p-3 ring-1 ring-inset ring-gray-200">
      <div class="flex justify-between gap-x-4">
        <div class="py-0.5 text-xs leading-5 text-gray-500">
          <span class="font-medium text-gray-900 dark:text-white">
            {maybe_show_remark_username(
              decr_item(
                get_item_connection(@remark, @current_user).username,
                @current_user,
                get_username_remark_key(@remark, @current_user),
                @key,
                @remark
              )
            )}
          </span>
          remarked
        </div>
        <!-- actions -->
        <div class="flex-col justify-end space-x-2 ml-1 text-xs align-middle">
          <.link
            :if={@current_user && @remark.user_id == @current_user.id}
            phx-click={JS.push("delete-remark", value: %{id: @remark.id})}
            data-confirm="Are you sure you want to delete this Remark?"
            class="text-pink-600 hover:text-pink-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-pink-600"
            title="Delete Remark"
          >
            <.icon name="hero-trash" class="h-4 w-4" />
          </.link>
          <time
            datetime="2023-01-23T15:56"
            class="flex-none py-0.5 text-xs leading-5 text-gray-500 dark:text-gray-400"
          >
            <.local_time_ago id={@remark.id <> "-created"} at={@remark.inserted_at} />
          </time>
        </div>
      </div>
      <p
        :if={@remark && !is_nil(@remark.body)}
        class="text-sm leading-6 text-gray-500 dark:text-gray-400"
      >
        {maybe_show_remark_body(
          decr_item(
            @remark.body,
            @current_user,
            get_body_remark_key(@remark, @current_user),
            @key,
            @remark
          )
        )}
      </p>
    </div>
    """
  end

  attr :at, :any, required: true
  attr :id, :any, required: true

  def local_time(assigns) do
    ~H"""
    <time phx-hook="LocalTime" id={"time-#{@id}"} class="hidden">{@at}</time>
    """
  end

  attr :mood, :atom,
    default: :nothing,
    doc: "the remark mood, one of [:excited, :loved, :happy, :sad, :thumbsy, :nothing]"

  attr :div_size_css, :string, default: "h-7 w-7"
  attr :svg_size_css, :string, default: "h-4 w-4"

  def mood_svg(assigns) do
    ~H"""
    <div
      :if={@mood == :excited}
      class={"bg-rose-500 flex #{@div_size_css} items-center justify-center rounded-full"}
    >
      <svg
        class={"text-white #{@svg_size_css} flex-shrink-0"}
        viewBox="0 0 20 20"
        fill="currentColor"
        aria-hidden="true"
      >
        <path
          fill-rule="evenodd"
          d="M13.5 4.938a7 7 0 11-9.006 1.737c.202-.257.59-.218.793.039.278.352.594.672.943.954.332.269.786-.049.773-.476a5.977 5.977 0 01.572-2.759 6.026 6.026 0 012.486-2.665c.247-.14.55-.016.677.238A6.967 6.967 0 0013.5 4.938zM14 12a4 4 0 01-4 4c-1.913 0-3.52-1.398-3.91-3.182-.093-.429.44-.643.814-.413a4.043 4.043 0 001.601.564c.303.038.531-.24.51-.544a5.975 5.975 0 011.315-4.192.447.447 0 01.431-.16A4.001 4.001 0 0114 12z"
          clip-rule="evenodd"
        />
      </svg>
    </div>

    <div
      :if={@mood == :loved}
      class={"bg-pink-400 flex #{@div_size_css} items-center justify-center rounded-full"}
    >
      <svg
        class={"text-white #{@svg_size_css} flex-shrink-0"}
        viewBox="0 0 20 20"
        fill="currentColor"
        aria-hidden="true"
      >
        <path d="M9.653 16.915l-.005-.003-.019-.01a20.759 20.759 0 01-1.162-.682 22.045 22.045 0 01-2.582-1.9C4.045 12.733 2 10.352 2 7.5a4.5 4.5 0 018-2.828A4.5 4.5 0 0118 7.5c0 2.852-2.044 5.233-3.885 6.82a22.049 22.049 0 01-3.744 2.582l-.019.01-.005.003h-.002a.739.739 0 01-.69.001l-.002-.001z" />
      </svg>
    </div>

    <div
      :if={@mood == :happy}
      class={"bg-green-400 flex #{@div_size_css} items-center justify-center rounded-full"}
    >
      <svg
        class={"text-white #{@svg_size_css} flex-shrink-0"}
        viewBox="0 0 20 20"
        fill="currentColor"
        aria-hidden="true"
      >
        <path
          fill-rule="evenodd"
          d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.536-4.464a.75.75 0 10-1.061-1.061 3.5 3.5 0 01-4.95 0 .75.75 0 00-1.06 1.06 5 5 0 007.07 0zM9 8.5c0 .828-.448 1.5-1 1.5s-1-.672-1-1.5S7.448 7 8 7s1 .672 1 1.5zm3 1.5c.552 0 1-.672 1-1.5S12.552 7 12 7s-1 .672-1 1.5.448 1.5 1 1.5z"
          clip-rule="evenodd"
        />
      </svg>
    </div>

    <div
      :if={@mood == :sad}
      class={"bg-purple-400 flex #{@div_size_css} items-center justify-center rounded-full"}
    >
      <svg
        class={"text-white #{@svg_size_css} flex-shrink-0"}
        viewBox="0 0 20 20"
        fill="currentColor"
        aria-hidden="true"
      >
        <path
          fill-rule="evenodd"
          d="M10 18a8 8 0 100-16 8 8 0 000 16zm-3.536-3.475a.75.75 0 001.061 0 3.5 3.5 0 014.95 0 .75.75 0 101.06-1.06 5 5 0 00-7.07 0 .75.75 0 000 1.06zM9 8.5c0 .828-.448 1.5-1 1.5s-1-.672-1-1.5S7.448 7 8 7s1 .672 1 1.5zm3 1.5c.552 0 1-.672 1-1.5S12.552 7 12 7s-1 .672-1 1.5.448 1.5 1 1.5z"
          clip-rule="evenodd"
        />
      </svg>
    </div>

    <div
      :if={@mood == :thumbsy}
      class={"bg-yellow-400 flex #{@div_size_css} items-center justify-center rounded-full"}
    >
      <svg
        class={"text-white #{@svg_size_css} flex-shrink-0"}
        viewBox="0 0 20 20"
        fill="currentColor"
        aria-hidden="true"
      >
        <path d="M1 8.25a1.25 1.25 0 112.5 0v7.5a1.25 1.25 0 11-2.5 0v-7.5zM11 3V1.7c0-.268.14-.526.395-.607A2 2 0 0114 3c0 .995-.182 1.948-.514 2.826-.204.54.166 1.174.744 1.174h2.52c1.243 0 2.261 1.01 2.146 2.247a23.864 23.864 0 01-1.341 5.974C17.153 16.323 16.072 17 14.9 17h-3.192a3 3 0 01-1.341-.317l-2.734-1.366A3 3 0 006.292 15H5V8h.963c.685 0 1.258-.483 1.612-1.068a4.011 4.011 0 012.166-1.73c.432-.143.853-.386 1.011-.814.16-.432.248-.9.248-1.388z" />
      </svg>
    </div>
    """
  end

  defp more_pages?(options, memory_count) do
    options.page * options.per_page < memory_count
  end

  defp pages(options, memory_count) do
    page_count = ceil(memory_count / options.per_page)

    for page_number <- (options.page - 2)..(options.page + 2),
        page_number > 0 do
      if page_number <= page_count do
        current_page? = page_number == options.page
        {page_number, current_page?}
      end
    end
  end

  defp more_remark_pages?(options, remark_count) do
    options.remark_page * options.remark_per_page < remark_count
  end

  defp remark_pages(options, remark_count) do
    page_count = ceil(remark_count / options.remark_per_page)

    for remark_page_number <- (options.remark_page - 2)..(options.remark_page + 2),
        remark_page_number > 0 do
      if remark_page_number <= page_count do
        remark_current_page? = remark_page_number == options.remark_page
        {remark_page_number, remark_current_page?}
      end
    end
  end

  defp memory_thumb_class(memory, user) do
    case get_shared_item_identity_atom(memory, user) do
      :self ->
        default_memory_thumb_class() <>
          " shadow-md shadow-primary-500/50 dark:shadow-md dark:shadow-primary-500/70"

      :private ->
        default_memory_thumb_class()

      :connection ->
        default_memory_thumb_class() <>
          " shadow-md shadow-secondary-500/50 dark:shadow-md dark:shadow-secondary-500/70"

      :public ->
        default_memory_thumb_class()

      :public_self ->
        default_memory_thumb_class()

      _rest ->
        default_memory_thumb_class()
    end
  end

  defp memory_thumb_class(memory, _current_user, user) do
    case get_shared_item_identity_atom(memory, user) do
      :self ->
        default_memory_thumb_class() <>
          " shadow-md shadow-primary-500/50 dark:shadow-md dark:shadow-primary-500/70"

      :private ->
        default_memory_thumb_class()

      :connection ->
        default_memory_thumb_class() <>
          " shadow-md shadow-secondary-500/50 dark:shadow-md dark:shadow-secondary-500/70"

      :public ->
        default_public_memory_thumb_class()

      :public_self ->
        default_public_memory_thumb_class()

      _rest ->
        default_public_memory_thumb_class()
    end
  end

  defp default_memory_thumb_class() do
    "group aspect-h-3 aspect-w-4 block w-full overflow-hidden rounded-lg bg-gray-100 dark:bg-gray-800 ring-primary-600 focus-within:ring-2 focus-within:ring-primary-500 focus-within:ring-offset-2 focus-within:ring-offset-gray-100 transition hover:cursor-pointer hover:bg-primary-50 sm:hover:rounded-lg sm:hover:scale-105 cursor-pointer"
  end

  defp default_public_memory_thumb_class() do
    "group block w-full aspect-h-3 aspect-w-4 overflow-hidden rounded-lg bg-gray-100 dark:bg-gray-800 ring-primary-600 focus-within:ring-2 focus-within:ring-primary-500 focus-within:ring-offset-2 focus-within:ring-offset-gray-100 transition hover:bg-primary-50 sm:hover:rounded-lg sm:hover:scale-105 cursor-pointer"
  end
end
