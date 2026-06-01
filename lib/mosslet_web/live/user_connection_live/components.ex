defmodule MossletWeb.UserConnectionLive.Components do
  @moduledoc """
  Components for user connections.
  """
  use Phoenix.Component
  use MossletWeb, :verified_routes

  alias Phoenix.LiveView.JS

  import MossletWeb.CoreComponents

  import MossletWeb.Helpers

  def user_connection_header(assigns) do
    ~H"""
    <div>
      <%!-- DecryptConnectionCard hook for browser-side ZK decryption --%>
      <div
        :if={@conn_fields[:sealed_uconn_key]}
        id={"decrypt-conn-show-#{@user_connection.id}"}
        phx-hook="DecryptConnectionCard"
        phx-update="ignore"
        data-sealed-uconn-key={@conn_fields[:sealed_uconn_key]}
        data-encrypted-conn-name={@conn_fields[:encrypted_name]}
        data-encrypted-conn-username={@conn_fields[:encrypted_username]}
        data-encrypted-conn-label={@conn_fields[:encrypted_label]}
        data-encrypted-conn-email={@conn_fields[:encrypted_email]}
        class="hidden"
      >
      </div>

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
              <span data-decrypt-conn-name class="animate-pulse">&nbsp;</span>
            </h1>
            <h1
              :if={!show_name?(@user_connection)}
              class="text-2xl font-bold text-gray-900 dark:text-gray-100"
            >
              <span data-decrypt-conn-username class="animate-pulse">&nbsp;</span>
            </h1>
            <p class="text-sm font-medium text-gray-500 dark:text-gray-400">
              Became your
              <span class={username_link_text_color_no_hover(@user_connection.color)}>
                <span data-decrypt-conn-label class="animate-pulse">&nbsp;</span>
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
        data-encrypted-name={@profile_fields[:encrypted_name]}
        data-encrypted-username={@profile_fields[:encrypted_username]}
        data-encrypted-email={@profile_fields[:encrypted_email]}
        class="hidden"
      >
      </div>
      <h2 id="profile-title" class="text-lg font-medium text-gray-900 dark:text-gray-100">Profile</h2>
      <div class="border-t border-gray-200 dark:border-gray-700 py-5">
        <dl class="grid grid-cols-1 gap-x-4 gap-y-8 sm:grid-cols-2">
          <div class="sm:col-span-1">
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Username</dt>
            <dd class="mt-1 text-sm text-gray-900 dark:text-gray-100">
              <span data-decrypt-conn-username class="animate-pulse">&nbsp;</span>
            </dd>
          </div>
          <div :if={show_email?(@user_connection)} class="sm:col-span-1">
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Email address</dt>
            <dd class="mt-1 text-sm text-gray-900 dark:text-gray-100">
              <span data-decrypt-conn-email class="animate-pulse">&nbsp;</span>
            </dd>
          </div>
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
              {if @profile_fields, do: @profile_fields[:about]}
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
