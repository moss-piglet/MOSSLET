defmodule MossletWeb.UserProfileLive.Components do
  @moduledoc """
  Components for user profile.
  """
  use Phoenix.Component
  use MossletWeb, :verified_routes

  alias Phoenix.LiveView.JS

  import MossletWeb.CoreComponents

  import MossletWeb.Helpers

  def user_profile_header(assigns) do
    ~H"""
    <div>
      <img
        :if={@current_user.connection.profile}
        class="h-32 w-full object-cover lg:h-48"
        src={~p"/images/profile/#{get_banner_image_for_connection(@current_user.connection)}"}
        alt="profile banner image"
      />
      <div class="mx-auto max-w-3xl px-4 sm:px-6 md:flex md:items-center md:justify-between md:space-x-5 lg:max-w-7xl lg:px-8">
        <div class="flex items-center space-x-5">
          <div class={
            if get_banner_image_for_connection(@current_user.connection) == "",
              do: "shrink-0",
              else: "-mt-12 sm:-mt-16 sm:flex sm:items-end sm:space-x-5 shrink-0"
          }>
            <div class="relative">
              <.phx_avatar
                class="size-32 sm:size-48 rounded-full"
                src={
                  if !show_avatar?(@current_user) ||
                       maybe_get_user_avatar(@current_user, @key) ==
                         "",
                     do: ~p"/images/logo.svg",
                     else: maybe_get_user_avatar(@current_user, @key)
                }
                alt="Your avatar"
              />
              <span class="absolute inset-0 rounded-full shadow-inner" aria-hidden="true"></span>
            </div>
          </div>
          <div>
            <h1
              :if={show_name?(@current_user)}
              class="text-2xl font-bold text-gray-900 dark:text-gray-100"
            >
              {decr_item(
                @current_user.connection.profile.name,
                @current_user,
                @current_user.connection.profile.profile_key,
                @key,
                @current_user.connection.profile
              )}
            </h1>
            <h1
              :if={!show_name?(@current_user)}
              class="text-2xl font-bold text-gray-900 dark:text-gray-100"
            >
              {decr_item(
                @current_user.connection.profile.username,
                @current_user,
                @current_user.connection.profile.profile_key,
                @key,
                @current_user.connection.profile
              )}
            </h1>
          </div>
        </div>
        <div class="mt-6 flex flex-col-reverse justify-stretch space-y-4 space-y-reverse sm:flex-row-reverse sm:justify-end sm:space-x-3 sm:space-y-0 sm:space-x-reverse md:mt-0 md:flex-row md:space-x-3">
          <.async_result :let={_result} assign={@post_shared_users_result}>
            <:loading>
              <div class="loading inline-flex items-center">
                <div class="spinner"></div>
              </div>
            </:loading>
            <:failed :let={{:error, reason}}>
              <div class="failed inline-flex items-center">
                Whoops: {reason}
              </div>
            </:failed>
            <.phx_button
              :if={@current_user}
              type="button"
              id={"new-post-button-#{@current_user.id}"}
              phx-click={JS.push("new_post")}
              class="inline-flex items-center justify-center rounded-full text-sm"
              data-tippy-content="New Post"
              phx-hook="TippyHook"
            >
              <.phx_icon name="hero-chat-bubble-oval-left-ellipsis" class="size-5 mr-1" /> New Post
            </.phx_button>

            <.link
              :if={@current_user}
              id={"edit-profile-button-#{@current_user.id}"}
              class="inline-flex items-center hover:text-emerald-600"
              phx-click={JS.patch(~p"/app/users/edit-profile")}
              data-tippy-content="Edit your profile"
              phx-hook="TippyHook"
            >
              <button
                type="button"
                class="inline-flex items-center justify-center rounded-full bg-white dark:bg-gray-800 px-3 py-2 text-sm font-semibold text-gray-900 dark:text-gray-100 shadow-md dark:shadow-emerald-500/50 ring-1 ring-offset ring-gray-300 dark:ring-gray-500 hover:bg-gray-200 dark:hover:bg-gray-900"
              >
                Edit Profile
              </button>
            </.link>
          </.async_result>
        </div>
      </div>
    </div>
    """
  end

  def user_profile(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-800 px-4 py-5 shadow dark:shadow-emerald-500/50 sm:rounded-lg sm:px-6">
      <h2 id="profile-title" class="text-lg font-medium text-gray-900 dark:text-gray-100">Profile</h2>
      <div class="border-t border-gray-200 py-5">
        <dl class="grid grid-cols-1 gap-x-4 gap-y-8 sm:grid-cols-3">
          <div class="sm:col-span-1">
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Username</dt>
            <dd class="mt-1 text-sm text-gray-900 dark:text-gray-100">
              {decr_item(
                @current_user.connection.profile.username,
                @current_user,
                @current_user.connection.profile.profile_key,
                @key,
                @current_user.connection.profile
              )}
            </dd>
          </div>
          <div class="sm:col-span-1">
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Email address</dt>
            <dd :if={show_email?(@current_user)} class="mt-1 text-sm text-gray-900 dark:text-gray-100">
              {decr_item(
                @current_user.connection.profile.email,
                @current_user,
                @current_user.connection.profile.profile_key,
                @key,
                @current_user.connection.profile
              )}
            </dd>
            <dd
              :if={!show_email?(@current_user)}
              class="mt-1 text-sm text-gray-900 dark:text-gray-100"
            >
              I'm a mystery. 😊
            </dd>
          </div>
          <div class="sm:col-span-1">
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Visibility</dt>
            <dd class="mt-1 text-sm text-gray-900 dark:text-gray-100">
              {@current_user.connection.profile.visibility}
            </dd>
          </div>
          <div class="sm:col-span-3">
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">About</dt>
            <dd
              :if={@current_user.connection.profile.about}
              class="mt-1 text-sm text-gray-900 dark:text-gray-100"
            >
              {decr_item(
                @current_user.connection.profile.about,
                @current_user,
                @current_user.connection.profile.profile_key,
                @key,
                @current_user.connection.profile
              )}
            </dd>
            <dd
              :if={!@current_user.connection.profile.about}
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
end
