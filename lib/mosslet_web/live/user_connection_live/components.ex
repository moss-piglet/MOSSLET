defmodule MossletWeb.UserConnectionLive.Components do
  @moduledoc """
  Components for user connections.
  """
  use Phoenix.Component
  use MossletWeb, :verified_routes

  alias Mosslet.Accounts
  alias Mosslet.Timeline
  alias Phoenix.LiveView.JS

  import MossletWeb.CoreComponents

  import MossletWeb.Helpers

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
                encrypted_avatar_data={
                  if show_avatar?(@user_connection),
                    do: get_encrypted_avatar_data(@user_connection, @key)
                }
                id={"conn-profile-#{@user_connection.id}"}
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
              {@decrypted_conn.name}
            </h1>
            <h1
              :if={!show_name?(@user_connection)}
              class="text-2xl font-bold text-gray-900 dark:text-gray-100"
            >
              {@decrypted_conn.username}
            </h1>
            <p class="text-sm font-medium text-gray-500 dark:text-gray-400">
              Became your
              <span class={username_link_text_color_no_hover(@user_connection.color)}>
                {@decrypted_conn.label}
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
            id={"message-button-#{@user_connection.id}"}
            class="hover:text-teal-600"
            phx-click="start_conversation"
            phx-value-connection-id={@user_connection.connection_id}
            data-tippy-content="Send Encrypted Message"
            phx-hook="TippyHook"
          >
            <button
              type="button"
              class="inline-flex items-center justify-center rounded-full border-2 border-teal-300 dark:border-teal-500 bg-gradient-to-r from-teal-500 to-emerald-500 px-6 py-3 text-sm font-semibold text-white shadow-md hover:from-teal-600 hover:to-emerald-600 transition-all duration-200"
            >
              <MossletWeb.CoreComponents.phx_icon name="hero-chat-bubble-left" class="h-4 w-4 mr-2" />
              Message
            </button>
          </.link>
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
              class="inline-flex items-center justify-center rounded-full border-2 border-gray-300 dark:border-gray-500 bg-white dark:bg-gray-800 px-6 py-3 text-sm font-semibold text-gray-900 dark:text-gray-100 shadow-md hover:bg-gray-50 dark:hover:bg-gray-700 hover:border-gray-400 dark:hover:border-gray-400 transition-all duration-200"
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
              class="inline-flex items-center justify-center rounded-full py-3 px-6 text-center text-sm font-bold bg-gradient-to-r from-rose-500 to-red-500 text-white shadow-lg transform hover:scale-105 transition-all duration-200 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-rose-600"
            >
              Remove Connection
            </button>
          </.link>
        </div>
      </div>
    </div>
    """
  end

  def user_connection_profile(assigns) do
    assigns = assign_new(assigns, :profile_fields, fn -> nil end)

    ~H"""
    <div
      class="bg-white dark:bg-gray-800 px-4 py-5 shadow dark:shadow-emerald-500/50 sm:rounded-lg sm:px-6"
      data-profile-scope="uconn-profile"
    >
      <%!-- DecryptProfileFields hook for browser-side ZK decryption --%>
      <div
        :if={@profile_fields && @profile_fields[:browser_decrypt?]}
        id={"decrypt-uconn-profile-#{@user_connection.id}"}
        phx-hook="DecryptProfileFields"
        phx-update="ignore"
        data-profile-id="uconn-profile"
        data-sealed-profile-key={@profile_fields[:sealed_profile_key]}
        data-encrypted-about={@profile_fields[:encrypted_about]}
        data-encrypted-alternate-email={@profile_fields[:encrypted_alternate_email]}
        data-encrypted-website-url={@profile_fields[:encrypted_website_url]}
        data-encrypted-website-label={@profile_fields[:encrypted_website_label]}
        class="hidden"
      >
      </div>
      <h2 id="profile-title" class="text-lg font-medium text-gray-900 dark:text-gray-100">Profile</h2>
      <div class="border-t border-gray-200 dark:border-gray-700 py-5">
        <dl class="grid grid-cols-1 gap-x-4 gap-y-8 sm:grid-cols-2">
          <div class="sm:col-span-1">
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Username</dt>
            <dd class="mt-1 text-sm text-gray-900 dark:text-gray-100">
              {@decrypted_conn.username}
            </dd>
          </div>
          <div :if={show_email?(@user_connection)} class="sm:col-span-1">
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Email address</dt>
            <dd class="mt-1 text-sm text-gray-900 dark:text-gray-100">
              {@decrypted_conn.email}
            </dd>
          </div>
          <%!-- Memory and Zen mode TBD (maybe future features)
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
          --%>
          <div
            :if={@user_connection.connection.profile && @user_connection.connection.profile.about}
            class="sm:col-span-2"
          >
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">About</dt>
            <dd
              data-decrypt-profile="about"
              class={[
                "mt-1 text-sm text-gray-900 dark:text-gray-100",
                @profile_fields && @profile_fields[:browser_decrypt?] && "animate-pulse"
              ]}
            >
              {if @profile_fields,
                do: @profile_fields[:about],
                else: @decrypted_conn.about}
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
                    {group.decrypted[:name]}
                  </p>
                  <p class="mt-1 truncate text-xs/5 text-gray-500 dark:text-gray-400">
                    {group.decrypted[:description]}
                  </p>
                </div>
              </div>
              <.link
                id={"group-#{group.id}-link"}
                patch={~p"/app/circles/#{group.id}"}
                class="rounded-full border border-gray-300 dark:border-gray-500 bg-white dark:bg-gray-800 px-2.5 py-1 text-xs font-semibold text-gray-900 dark:text-gray-100 shadow-sm hover:bg-gray-50 dark:hover:bg-gray-700 hover:border-gray-400 dark:hover:border-gray-400 transition-all duration-200"
                data-tippy-content="View Group"
                phx-hook="TippyHook"
              >
                View
              </.link>
            </div>
          </li>
        </ul>
        <.link
          patch={~p"/app/circles"}
          class="flex w-full items-center justify-center rounded-full py-3 px-6 text-center text-sm font-bold focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600 bg-gradient-to-r from-teal-500 to-emerald-500 text-white shadow-lg transform hover:scale-105 transition-all duration-200"
        >
          View all
        </.link>
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
    <div
      :if={!Enum.empty?(@post.replies)}
      id={"first-reply-#{@post.id}"}
      class="my-2 pt-4 pb-2 pl-2 pr-4 bg-background-50 dark:bg-gray-900 border border-2 border-background-100 dark:border-emerald-500 rounded-lg shadow-md shadow-background-500/50 dark:shadow-emerald-500/50"
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
              <div class="relative flex items-start space-x-3">
                <div class="relative">
                  <.phx_avatar
                    :if={user_connection}
                    encrypted_avatar_data={
                      if show_avatar?(user_connection),
                        do: get_encrypted_avatar_data(user_connection, @key)
                    }
                    id={"conn-reply-#{reply.id}-uconn"}
                    class="h-8 w-8 rounded-full"
                  />
                  <.phx_avatar
                    :if={!user_connection && reply.user_id == @current_user.id}
                    encrypted_avatar_data={
                      if show_avatar?(@current_user),
                        do: get_encrypted_avatar_data(@current_user, @key)
                    }
                    id={"conn-reply-#{reply.id}-self"}
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
                      <%!-- Reply username — server-side decryption for public posts --%>
                      <p class="text-sm font-semibold leading-6">
                        {get_decrypted_reply_username(reply, @post, @current_user, @key)}
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
                      <.reply_show_photos_icon
                        :if={photos?(reply.image_urls)}
                        current_user={@current_user}
                        reply={reply}
                      />
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
                  <div
                    id={"reply-body-#{reply.id}"}
                    phx-hook="TrixContentReplyHook"
                    data-post-id={@post.id}
                    class="post-body"
                  >
                    {html_block(get_decrypted_reply_body(reply, @post, @current_user, @key))}
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

  def post_show_photos_icon(assigns) do
    ~H"""
    <button
      id={"post-#{@post.id}-show-photos-#{@current_user.id}"}
      class="inline-flex align-middle hover:text-emerald-600 dark:hover:text-emerald-400 hover:cursor-pointer"
      phx-click={
        JS.dispatch("mosslet:show-post-photos-#{@post.id}",
          to: "#posts-#{@post.id}",
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

  def reply_show_photos_icon(assigns) do
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
end
