defmodule MossletWeb.UserHomeLive.Components do
  @moduledoc """
  Components for user home profile.
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
      <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div class="relative -mt-12 sm:-mt-16 flex items-end space-x-5">
          <div class="flex">
            <div class="relative">
              <.phx_avatar
                class="size-24 sm:size-32 rounded-full ring-4 ring-white dark:ring-gray-800 shadow-lg"
                src={
                  if !show_avatar?(@current_user) ||
                       maybe_get_user_avatar(@current_user, @key) ==
                         "",
                     do: ~p"/images/logo.svg",
                     else: maybe_get_user_avatar(@current_user, @key)
                }
                alt="Your avatar"
              />
            </div>
          </div>
          <div class="mt-6 sm:flex-1 sm:min-w-0 sm:flex sm:items-center sm:justify-end sm:space-x-6 sm:pb-1">
            <div class="sm:hidden md:block mt-6 min-w-0 flex-1">
              <h1
                :if={show_name?(@current_user)}
                class="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100 truncate"
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
                class="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100 truncate"
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
        </div>
        <div class="hidden sm:block md:hidden mt-6 min-w-0 flex-1">
          <h1
            :if={show_name?(@current_user)}
            class="text-2xl font-bold text-gray-900 dark:text-gray-100 truncate"
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
            class="text-2xl font-bold text-gray-900 dark:text-gray-100 truncate"
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
    </div>
    """
  end

  def user_profile(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-800 px-4 py-5 shadow dark:shadow-emerald-500/50 sm:rounded-lg sm:px-6">
      <h2 id="profile-title" class="text-lg font-medium text-gray-900 dark:text-gray-100">
        Your profile
      </h2>
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
