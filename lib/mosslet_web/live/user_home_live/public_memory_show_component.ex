defmodule MossletWeb.UserHomeLive.PublicMemoryShowComponent do
  @moduledoc false
  use MossletWeb, :live_component

  alias Mosslet.Accounts
  alias Mosslet.Memories
  alias MossletWeb.Endpoint
  alias MossletWeb.MemoryLive.Components

  def render(assigns) do
    ~H"""
    <div class="transform divide-y divide-gray-100 dark:divide-primary-500 overflow-hidden rounded-xl bg-white dark:bg-gray-900 transition-all">
      <div :if={@current_user && @memory.user_id == @current_user.id} class="relative group">
        <.button
          phx-click={
            JS.push("delete",
              value: %{
                id: @memory.id,
                url:
                  decr_item(
                    @memory.memory_url,
                    @current_user,
                    get_memory_key(@memory),
                    @key,
                    @memory
                  )
              }
            )
          }
          method={:delete}
          icon="hero-trash"
          data-confirm="Are you sure you want to delete this memory?"
          color="danger"
          class="group h-12 w-full border-0 bg-transparent pl-11 text-gray-400 group-hover:text-white pr-4 focus:ring-0 focus:text-white sm:text-sm"
        >
          Delete memory
        </.button>
      </div>

      <div class="flex transform-gpu divide-x divide-gray-100 dark:divide-primary-500">
        <img
          src={
            maybe_get_public_memory_src(
              assigns.user,
              assigns.memory,
              assigns.current_user,
              assigns.memory_list
            )
          }
          id={"public-memory-image-#{@memory.id}"}
          alt=""
          class={
            if show_blur_memory?(@memory, @current_user),
              do:
                "blur-3xl pointer-events-none object-contain group-hover:opacity-75 min-h-svh min-w-0 flex-auto scroll-py-4 overflow-y-auto sm:h-96",
              else:
                "pointer-events-none object-contain group-hover:opacity-75 min-h-svh min-w-0 flex-auto scroll-py-4 overflow-y-auto sm:h-96"
          }
        />

        <div class="hidden h-svh w-1/3 flex-none flex-col divide-y divide-gray-100 dark:divide-primary-500 overflow-y-auto sm:flex">
          <div class="flex-none p-6 text-center">
            <img
              :if={@current_user}
              src={
                maybe_get_avatar_src(
                  assigns.memory,
                  assigns.current_user,
                  assigns.key,
                  assigns.memory_list
                )
              }
              alt=""
              class="mx-auto h-16 w-16 rounded-full"
            />
            <.phx_avatar
              :if={!@current_user && @user.connection.profile.show_avatar?}
              src={
                maybe_get_public_profile_user_avatar(
                  @user,
                  @user.connection.profile,
                  @current_user
                )
              }
              alt=""
              class="mx-auto h-16 w-16 rounded-full"
            />
            <h2 :if={@current_user} class="mt-3 font-semibold text-gray-900 dark:text-gray-100">
              {decr_uconn_item(
                get_item_connection(@memory, @current_user).username,
                @current_user,
                get_uconn_for_shared_item(@memory, @current_user),
                @key
              )}
            </h2>
            <h2 :if={!@current_user} class="mt-3 font-semibold text-gray-900 dark:text-gray-100">
              {decr_public_item(
                @memory.username,
                get_memory_key(@memory)
              )}
            </h2>
            <p :if={@memory.blurb} class="text-sm leading-6 text-gray-500 dark:text-gray-400">
              {decr_item(
                @memory.blurb,
                @current_user,
                get_memory_key(@memory, @current_user),
                @key,
                @memory
              )}
            </p>
          </div>
          <div class="flex flex-auto flex-col justify-start p-6">
            <dl class="grid grid-cols-1 gap-x-6 gap-y-3 text-sm text-gray-700 dark:text-gray-300">
              <dt
                class="inline-flex items-center col-end-1 font-semibold text-gray-900 dark:text-gray-100"
                id={"reactions-memory-" <> @memory.id}
              >
                Reactions
              </dt>
              <dd>
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
                    class="inline-flex items-center text-gray-500 dark:text-gray-400"
                  >
                    Be the first to react!
                  </div>
                  <div
                    :if={
                      !@current_user &&
                        Enum.all?(
                          [@excited_count, @loved_count, @happy_count, @sad_count, @thumbsy_count],
                          fn x -> x == 0 end
                        )
                    }
                    class="inline-flex items-center text-gray-500 dark:text-gray-400"
                  >
                    <.link
                      type="a"
                      href={~p"/auth/sign_in"}
                      class="text-primary-600 hover:text-primary-400 underline"
                    >
                      Sign in to be the first to react
                    </.link>
                  </div>
                  <div :if={@excited_count > 0} class="relative inline-flex items-center">
                    <Components.mood_svg mood={:excited} />
                    <span
                      :if={@excited_count > 1}
                      class="absolute -top-3 -right-3 z-20 truncate text-xs font-medium text-rose-500 bg-rose-100 rounded-full py-0.5 px-2"
                    >
                      {@excited_count}
                    </span>
                  </div>

                  <div :if={@loved_count > 0} class="relative inline-flex items-center">
                    <Components.mood_svg mood={:loved} />
                    <span
                      :if={@loved_count > 1}
                      class="absolute -top-3 -right-3 z-20 truncate text-xs font-medium text-pink-500 bg-pink-100 rounded-full py-0.5 px-2"
                    >
                      {@loved_count}
                    </span>
                  </div>

                  <div :if={@happy_count > 0} class="relative inline-flex items-center">
                    <Components.mood_svg mood={:happy} />
                    <span
                      :if={@happy_count > 1}
                      class="absolute -top-3 -right-3 z-20 truncate text-xs font-medium text-green-500 bg-green-100 rounded-full py-0.5 px-2"
                    >
                      {@happy_count}
                    </span>
                  </div>

                  <div :if={@sad_count > 0} class="relative inline-flex items-center">
                    <Components.mood_svg mood={:sad} />
                    <span
                      :if={@sad_count > 1}
                      class="absolute -top-3 -right-3 z-20 truncate text-xs font-medium text-purple-500 bg-purple-100 rounded-full py-0.5 px-2"
                    >
                      {@sad_count}
                    </span>
                  </div>

                  <div :if={@thumbsy_count > 0} class="relative inline-flex items-center">
                    <Components.mood_svg mood={:thumbsy} />
                    <span
                      :if={@thumbsy_count > 1}
                      class="absolute -top-3 -right-3 z-20 truncate text-xs font-medium text-yellow-500 bg-yellow-100 rounded-full py-0.5 px-2"
                    >
                      {@thumbsy_count}
                    </span>
                  </div>
                </div>
              </dd>

              <dt
                id={"date-memory-created-" <> @memory.id}
                class="inline-flex items-center col-end-1 font-semibold text-gray-900 dark:text-gray-100"
              >
                Created <span class="sr-only">Memory created at</span>
              </dt>
              <dd id={@memory.id <> "-created-at-details"} class="text-sm leading-6 ">
                <time datetime={@memory.inserted_at}>
                  <.local_time_full id={@memory.id <> "-created"} at={@memory.inserted_at} />
                </time>
              </dd>
              <% uconn = get_uconn_for_shared_item(@memory, @current_user) %>
              <dt
                :if={
                  @current_user && not is_nil(uconn) &&
                    (check_if_user_can_download_shared_memory(@memory.user_id, @current_user.id) ||
                       check_if_user_can_download_memory(@memory.user_id, @current_user.id))
                }
                class="inline-flex items-center col-end-1 font-semibold text-gray-900 dark:text-gray-100"
              >
                Actions
              </dt>
              <dd class="text-sm leading-6 ">
                <div :if={@current_user}>
                  <.link
                    :if={
                      not is_nil(uconn) &&
                        check_if_user_can_download_shared_memory(@memory.user_id, @current_user.id)
                    }
                    target="_blank"
                    href={
                      Routes.memory_download_path(
                        @socket,
                        :download_shared_public_memory,
                        @slug,
                        @memory.id,
                        memory_id: @memory.id,
                        memory_name: "mosslet-shared-memory-public-download",
                        memory_file_type: @memory.type,
                        current_user_id: @current_user.id,
                        uconn_id: uconn.id,
                        key: @key
                      )
                    }
                    id={"memory-download-link-" <> @memory.id}
                    data-tippy-content="Download to your device"
                    phx-hook="TippyHook"
                    download="mosslet-memory"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke-width="1.5"
                      stroke="currentColor"
                      class="h-6 w-6 text-gray-900 dark:text-gray-100"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5M16.5 12 12 16.5m0 0L7.5 12m4.5 4.5V3"
                      />
                    </svg>
                  </.link>

                  <.link
                    :if={
                      not is_nil(uconn) &&
                        check_if_user_can_download_memory(@memory.user_id, @current_user.id)
                    }
                    target="_blank"
                    href={
                      Routes.memory_download_path(@socket, :download_public_memory, @slug, @memory.id,
                        memory_id: @memory.id,
                        memory_name: "mosslet-memory-public-download",
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
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke-width="1.5"
                      stroke="currentColor"
                      class="h-6 w-6 text-gray-900 dark:text-gray-100"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5M16.5 12 12 16.5m0 0L7.5 12m4.5 4.5V3"
                      />
                    </svg>
                  </.link>
                </div>
              </dd>
            </dl>

            <div class="py-10">
              <!-- Remark feed -->
              <.h3>Remarks</.h3>
              <.live_component
                :if={@current_user}
                module={MossletWeb.MemoryLive.RemarkFormComponent}
                id={@remark.id || :new}
                memory={@memory}
                remark={@remark}
                current_user={@current_user}
                key={@key}
                patch={~p"/app/profile/#{@slug}/memory/#{@memory.id}"}
              />
              <.button
                :if={!@current_user}
                link_type="a"
                to={~p"/auth/sign_in"}
                color="primary"
                class="flex justify-center rounded-full"
                size="sm"
                {alpine_autofocus()}
              >
                Sign in to remark
              </.button>
              <div class="flex-col">
                <!-- Remark feed -->
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
                          <span
                            :if={@current_user}
                            class="font-medium text-gray-900 dark:text-gray-100"
                          >
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
                          <span
                            :if={!@current_user}
                            class="font-medium text-gray-900 dark:text-gray-100"
                          >
                            {maybe_show_remark_username(
                              decr_public_item(
                                remark.memory.username,
                                get_memory_key(@memory)
                              )
                            )}
                          </span>
                          <span :if={is_nil(remark.body)}>reacted with <%= remark.mood %></span>.
                        </p>
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
                            phx_target={@myself}
                            value={remark.id}
                          />
                        </div>
                      </div>

                      <div
                        :if={!is_nil(remark.body)}
                        id={remark.id <> "-body"}
                        class="relative flex gap-x-4"
                      >
                        <.phx_avatar
                          :if={!is_nil(@current_user)}
                          src={
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
                          :if={
                            is_nil(@current_user) && @user.connection.profile.show_avatar? &&
                              @user.id == remark.memory.user_id
                          }
                          src={
                            maybe_get_public_profile_user_avatar(
                              @user,
                              @user.connection.profile,
                              @current_user
                            )
                          }
                          alt=""
                          size="h-6 w-6"
                          class="relative mt-3 h-6 w-6 flex-none rounded-full bg-gray-50 dark:bg-gray-900"
                        />
                        <div class="flex-auto rounded-md p-3 ring-1 ring-inset ring-gray-200 dark:ring-primary-200">
                          <div class="flex justify-between gap-x-4">
                            <div class="py-0.5 text-xs leading-5 text-gray-500">
                              <span
                                :if={@current_user}
                                class="font-medium text-gray-900 dark:text-gray-100"
                              >
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
                              <span
                                :if={!@current_user}
                                class="font-medium text-gray-900 dark:text-gray-100"
                              >
                                {maybe_show_remark_username(
                                  decr_public_item(
                                    remark.memory.username,
                                    get_memory_key(@memory)
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
                                phx_target={@myself}
                                value={remark.id}
                              />
                            </div>
                          </div>
                          <p class="text-sm leading-6 text-gray-500">
                            {maybe_show_remark_body(
                              decr_public_item(
                                remark.body,
                                get_memory_key(@memory, @current_user)
                              )
                            )}
                          </p>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <!-- pagination -->
            <nav
              :if={@remark_count > 0}
              id="memory-pagination"
              class="flex items-center justify-between border-t border-gray-200 px-4 sm:px-0"
            >
              <div class="-mt-px flex w-0 flex-1">
                <.link
                  :if={@options.page > 1}
                  patch={
                    ~p"/app/profile/#{@slug}/memory/#{@memory.id}?#{%{@options | page: @options.page - 1}}"
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
              <div class="hidden md:-mt-px md:flex">
                <.link
                  :for={{page_number, current_page?} <- pages(@options, @remark_count)}
                  class={
                    if current_page?,
                      do:
                        "inline-flex items-center border-t-2 border-primary-500 px-4 pt-4 text-sm font-medium text-primary-600",
                      else:
                        "inline-flex items-center border-t-2 border-transparent px-4 pt-4 text-sm font-medium text-gray-500 hover:border-gray-300 hover:text-gray-700"
                  }
                  patch={
                    ~p"/app/profile/#{@slug}/memory/#{@memory.id}?#{%{@options | page: page_number}}"
                  }
                  aria-current="page"
                >
                  {page_number}
                </.link>
              </div>
              <div class="-mt-px flex w-0 flex-1 justify-end">
                <.link
                  :if={more_pages?(@options, @remark_count)}
                  patch={
                    ~p"/app/profile/#{@slug}/memory/#{@memory.id}?#{%{@options | page: @options.page + 1}}"
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
          </div>
        </div>
      </div>
    </div>
    """
  end

  def update(assigns, socket) do
    # remarks = Memories.list_remarks(memory, options)
    memory = assigns.memory
    current_user = assigns.current_user

    if connected?(socket) do
      if current_user do
        Accounts.private_subscribe(current_user)
        Memories.subscribe()
        Memories.connections_subscribe(current_user)
        Endpoint.subscribe("memory:#{memory.id}")
      else
        Accounts.subscribe()
        Memories.subscribe()
      end
    end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:remark_count, Memories.remark_count(memory))
     |> assign(:excited_count, Memories.get_remarks_excited_count(memory))
     |> assign(:loved_count, Memories.get_remarks_loved_count(memory))
     |> assign(:happy_count, Memories.get_remarks_happy_count(memory))
     |> assign(:sad_count, Memories.get_remarks_sad_count(memory))
     |> assign(:thumbsy_count, Memories.get_remarks_thumbsy_count(memory))}
  end

  def handle_event("delete-remark", %{"item_id" => remark_id}, socket) do
    {:noreply, socket |> delete_remark(remark_id) |> push_patch(to: socket.assigns.remark_url)}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  defp delete_remark(socket, remark_id) do
    remark = Memories.get_remark!(remark_id)
    memory = Memories.get_memory!(remark.memory_id)
    user = socket.assigns.current_user

    if user.id == remark.user_id || user.id == memory.user_id do
      case Memories.delete_remark(remark, user: user) do
        {:ok, _remark} ->
          socket

        {:ok, _connection, _remark} ->
          socket
      end
    else
      socket
    end
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
end
