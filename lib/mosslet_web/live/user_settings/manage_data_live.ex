defmodule MossletWeb.ManageDataLive do
  @moduledoc false
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias MossletWeb.DesignSystem

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Settings",
       current_password: nil,
       legacy_expanded: false,
       form: to_form(Accounts.change_user_delete_data(socket.assigns.current_user))
     )}
  end

  def handle_params(_params, _url, socket) do
    {:noreply,
     assign(socket,
       page_title: "Settings",
       current_password: nil,
       legacy_expanded: false,
       form: to_form(Accounts.change_user_delete_data(socket.assigns.current_user))
     )}
  end

  defp data_checked?(form, field) do
    case form[:data].value do
      %{^field => val} -> val in ["true", true]
      _ -> false
    end
  end

  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :description, :string, required: true
  attr :legacy, :boolean, default: false
  attr :checked, :boolean, default: false

  defp data_checkbox(assigns) do
    ~H"""
    <div class={[
      "group relative overflow-hidden rounded-xl p-3 -m-3 transition-all duration-200 ease-out hover:bg-slate-50 dark:hover:bg-slate-800/50",
      @legacy && "opacity-75"
    ]}>
      <div class="relative flex items-start gap-4">
        <div class="relative flex-shrink-0 pt-0.5">
          <input type="hidden" name={@name} value="false" />
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class="h-5 w-5 rounded-lg border-2 transition-all duration-200 ease-out transform-gpu cursor-pointer bg-slate-50 dark:bg-slate-900 text-emerald-600 dark:text-emerald-400 border-slate-300 dark:border-slate-600 hover:border-emerald-400 dark:hover:border-emerald-500 hover:bg-emerald-50 dark:hover:bg-emerald-900/20 focus:border-emerald-500 dark:focus:border-emerald-400 focus:outline-none focus:ring-0 checked:border-emerald-600 dark:checked:border-emerald-400 checked:bg-emerald-600 dark:checked:bg-emerald-500 shadow-sm hover:shadow-md focus:shadow-lg focus:shadow-emerald-500/10"
          />
        </div>
        <div class="flex-1 min-w-0">
          <label
            for={@id}
            class="flex items-center gap-2 text-sm font-medium text-slate-900 dark:text-slate-100 cursor-pointer leading-relaxed"
          >
            <.phx_icon name={@icon} class="h-4 w-4 text-slate-500 dark:text-slate-400" />
            {@label}
          </label>
          <p class="mt-1 text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
            {@description}
          </p>
        </div>
      </div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <.layout
      current_user={@current_user}
      current_page={:manage_data}
      sidebar_current_page={:manage_data}
      key={@key}
      type="sidebar"
    >
      <DesignSystem.liquid_container max_width="lg" class="py-16">
        <%!-- Page header with liquid metal styling --%>
        <div class="mb-12">
          <div class="mb-8">
            <h1 class="text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              Data Management
            </h1>
            <p class="mt-4 text-lg text-slate-600 dark:text-slate-400">
              Take control of your data with a fresh start when you need it.
            </p>
          </div>
          <%!-- Decorative accent line --%>
          <div class="h-1 w-24 rounded-full bg-gradient-to-r from-teal-400 via-emerald-400 to-cyan-400 shadow-sm shadow-emerald-500/30">
          </div>
        </div>

        <div class="space-y-8 max-w-3xl">
          <%!-- Fresh Start Card --%>
          <DesignSystem.liquid_card class="bg-gradient-to-br from-amber-50/50 to-orange-50/30 dark:from-amber-900/20 dark:to-orange-900/10">
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-amber-100 via-orange-50 to-amber-100 dark:from-amber-900/30 dark:via-orange-900/25 dark:to-amber-900/30">
                  <.phx_icon
                    name="hero-arrow-path"
                    class="h-4 w-4 text-amber-600 dark:text-amber-400"
                  />
                </div>
                <span class="text-amber-800 dark:text-amber-200">Fresh Start</span>
              </div>
            </:title>

            <div class="space-y-4">
              <p class="text-amber-700 dark:text-amber-300 leading-relaxed">
                Everyone deserves a fresh start. Sometimes you need to clear the slate and begin again.
                You can selectively delete your data while keeping your account active.
              </p>

              <div class="bg-amber-100 dark:bg-amber-900/30 rounded-lg p-4 border border-amber-200 dark:border-amber-700">
                <div class="flex items-start gap-3">
                  <.phx_icon
                    name="hero-exclamation-triangle"
                    class="h-5 w-5 mt-0.5 text-amber-600 dark:text-amber-400 flex-shrink-0"
                  />
                  <div class="space-y-2">
                    <h3 class="font-medium text-sm text-amber-800 dark:text-amber-200">
                      Important: This Action Cannot Be Undone
                    </h3>
                    <p class="text-sm text-amber-700 dark:text-amber-300">
                      Once you delete your data, it's permanently removed from our servers.
                      Please be certain before proceeding.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </DesignSystem.liquid_card>

          <%!-- Data Deletion Form Card --%>
          <DesignSystem.liquid_card>
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-rose-100 via-pink-50 to-rose-100 dark:from-rose-900/30 dark:via-pink-900/25 dark:to-rose-900/30">
                  <.phx_icon name="hero-trash" class="h-4 w-4 text-rose-600 dark:text-rose-400" />
                </div>
                <span>Delete Selected Data</span>
              </div>
            </:title>

            <.form
              for={@form}
              id="delete-data-form"
              phx-change="validate_password"
              phx-submit="delete_data"
              class="space-y-8"
            >
              <%!-- Hidden email field --%>
              <input
                type="hidden"
                name="user[email]"
                value={decr(@current_user.email, @current_user, @key)}
              />

              <%!-- Data Selection Section --%>
              <div class="space-y-6">
                <div>
                  <h3 class="text-lg font-medium text-slate-900 dark:text-slate-100">
                    Select Data to Delete
                  </h3>
                  <p class="mt-1 text-sm text-slate-600 dark:text-slate-400">
                    Choose which types of data you'd like to permanently remove from your account.
                  </p>
                </div>

                <div class="space-y-3">
                  <.data_checkbox
                    id="user_data_user_connections"
                    name="user[data][user_connections]"
                    icon="hero-users"
                    label="Connections"
                    description="Remove all your connection relationships with other users"
                    checked={data_checked?(@form, "user_connections")}
                  />

                  <.data_checkbox
                    id="user_data_groups"
                    name="user[data][groups]"
                    icon="hero-circle-stack"
                    label="Circles"
                    description="Delete all circles you've created and remove yourself from circles you've joined"
                    checked={data_checked?(@form, "groups")}
                  />

                  <.data_checkbox
                    id="user_data_posts"
                    name="user[data][posts]"
                    icon="hero-book-open"
                    label="Posts"
                    description="Remove all posts you've shared on your timeline (also deletes associated bookmarks)"
                    checked={data_checked?(@form, "posts")}
                  />

                  <.data_checkbox
                    id="user_data_bookmarks"
                    name="user[data][bookmarks]"
                    icon="hero-bookmark"
                    label="Bookmarks"
                    description="Remove all your saved bookmarks and bookmark notes"
                    checked={data_checked?(@form, "bookmarks")}
                  />

                  <.data_checkbox
                    id="user_data_replies"
                    name="user[data][replies]"
                    icon="hero-chat-bubble-left-right"
                    label="Replies"
                    description="Remove all your replies to posts and conversations"
                    checked={data_checked?(@form, "replies")}
                  />
                </div>

                <%!-- Legacy Data Section --%>
                <details class="group" open={@legacy_expanded}>
                  <summary
                    class="flex items-center gap-2 cursor-pointer text-sm text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300 transition-colors"
                    phx-click="toggle_legacy"
                  >
                    <.phx_icon
                      name="hero-chevron-right"
                      class="h-4 w-4 transition-transform group-open:rotate-90"
                    />
                    <span>Legacy data options</span>
                    <span class="text-xs text-slate-500 dark:text-slate-400">
                      (from previous app versions)
                    </span>
                  </summary>
                  <div class="mt-3 ml-6 space-y-3 border-l-2 border-slate-200 dark:border-slate-700 pl-4">
                    <.data_checkbox
                      id="user_data_memories"
                      name="user[data][memories]"
                      icon="hero-photo"
                      label="Memories"
                      description="Permanently delete all your saved memories and media"
                      legacy={true}
                      checked={data_checked?(@form, "memories")}
                    />

                    <.data_checkbox
                      id="user_data_remarks"
                      name="user[data][remarks]"
                      icon="hero-chat-bubble-left"
                      label="Remarks"
                      description="Delete all remarks you've made"
                      legacy={true}
                      checked={data_checked?(@form, "remarks")}
                    />
                  </div>
                </details>
              </div>

              <%!-- Password Confirmation Section --%>
              <div class="space-y-3">
                <label class="block text-sm font-medium text-slate-900 dark:text-slate-100">
                  Current Password <span class="text-rose-500 ml-1">*</span>
                </label>
                <p class="text-sm text-slate-600 dark:text-slate-400">
                  Confirm your identity by entering your current password.
                </p>

                <div class="group relative">
                  <%!-- Enhanced liquid background effect on focus --%>
                  <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-br from-emerald-50/30 via-teal-50/40 to-emerald-50/30 dark:from-emerald-900/15 dark:via-teal-900/20 dark:to-emerald-900/15 group-focus-within:opacity-100 rounded-xl">
                  </div>

                  <%!-- Enhanced shimmer effect on focus --%>
                  <div class="absolute inset-0 opacity-0 transition-all duration-700 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 group-focus-within:opacity-100 group-focus-within:translate-x-full -translate-x-full rounded-xl">
                  </div>

                  <%!-- Focus ring with liquid metal styling --%>
                  <div class="absolute -inset-1 opacity-0 transition-all duration-200 ease-out rounded-xl bg-gradient-to-r from-teal-500 via-emerald-500 to-teal-500 dark:from-teal-400 dark:via-emerald-400 dark:to-teal-400 group-focus-within:opacity-100 blur-sm">
                  </div>

                  <%!-- Secondary focus ring for better definition --%>
                  <div class="absolute -inset-0.5 opacity-0 transition-all duration-200 ease-out rounded-xl border-2 border-emerald-500 dark:border-emerald-400 group-focus-within:opacity-100">
                  </div>

                  <%!-- Password input with show/hide functionality --%>
                  <input
                    type="password"
                    id="current-password"
                    name="current_password"
                    required
                    class={[
                      "relative block w-full rounded-xl px-4 py-3 pr-12 text-slate-900 dark:text-slate-100",
                      "bg-slate-50 dark:bg-slate-900 placeholder:text-slate-500 dark:placeholder:text-slate-400",
                      "border-2 border-slate-200 dark:border-slate-700",
                      "hover:border-slate-300 dark:hover:border-slate-600",
                      "focus:border-emerald-500 dark:focus:border-emerald-400",
                      "focus:outline-none focus:ring-0",
                      "transition-all duration-200 ease-out",
                      "sm:text-sm sm:leading-6",
                      "shadow-sm focus:shadow-lg focus:shadow-emerald-500/10",
                      "focus:bg-white dark:focus:bg-slate-800"
                    ]}
                    placeholder="Enter your current password"
                    value={@current_password}
                  />

                  <%!-- Show/Hide password buttons with liquid styling --%>
                  <div class="absolute inset-y-0 right-0 flex items-center pr-3">
                    <button
                      type="button"
                      id="eye-current-password"
                      aria-label="Show current password"
                      data-tippy-content="Show current password"
                      phx-hook="TippyHook"
                      class="group/eye p-1 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors duration-200"
                      phx-click={
                        JS.set_attribute({"type", "text"}, to: "#current-password")
                        |> JS.remove_class("hidden", to: "#eye-slash-current-password")
                        |> JS.add_class("hidden", to: "#eye-current-password")
                      }
                    >
                      <.phx_icon
                        name="hero-eye"
                        class="h-5 w-5 text-slate-400 dark:text-slate-500 group-hover/eye:text-emerald-600 dark:group-hover/eye:text-emerald-400 transition-colors duration-200"
                      />
                    </button>
                    <button
                      type="button"
                      id="eye-slash-current-password"
                      aria-label="Hide current password"
                      data-tippy-content="Hide current password"
                      phx-hook="TippyHook"
                      class="hidden group/eye p-1 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors duration-200"
                      phx-click={
                        JS.set_attribute({"type", "password"}, to: "#current-password")
                        |> JS.add_class("hidden", to: "#eye-slash-current-password")
                        |> JS.remove_class("hidden", to: "#eye-current-password")
                      }
                    >
                      <.phx_icon
                        name="hero-eye-slash"
                        class="h-5 w-5 text-slate-400 dark:text-slate-500 group-hover/eye:text-emerald-600 dark:group-hover/eye:text-emerald-400 transition-colors duration-200"
                      />
                    </button>
                  </div>
                </div>
              </div>

              <%!-- Submit button --%>
              <div class="flex justify-end pt-6">
                <DesignSystem.liquid_button
                  type="submit"
                  color="rose"
                  icon="hero-trash"
                  phx-disable-with="Deleting..."
                >
                  Delete Selected Data
                </DesignSystem.liquid_button>
              </div>
            </.form>
          </DesignSystem.liquid_card>

          <%!-- What Gets Deleted Card --%>
          <DesignSystem.liquid_card class="bg-gradient-to-br from-blue-50/50 to-cyan-50/30 dark:from-blue-900/20 dark:to-cyan-900/10">
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
                  <.phx_icon
                    name="hero-information-circle"
                    class="h-4 w-4 text-blue-600 dark:text-blue-400"
                  />
                </div>
                <span class="text-blue-800 dark:text-blue-200">
                  What Happens When You Delete Data
                </span>
              </div>
            </:title>

            <div class="space-y-4">
              <p class="text-blue-700 dark:text-blue-300 leading-relaxed">
                Here's exactly what gets removed when you delete each type of data:
              </p>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-users"
                      class="h-4 w-4 text-blue-600 dark:text-blue-400"
                    />
                    <span class="text-sm font-semibold text-blue-800 dark:text-blue-200">
                      Connections
                    </span>
                  </div>
                  <p class="text-sm text-blue-700 dark:text-blue-300 ml-6">
                    Removes all friend relationships and connection history
                  </p>
                </div>

                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-circle-stack"
                      class="h-4 w-4 text-blue-600 dark:text-blue-400"
                    />
                    <span class="text-sm font-semibold text-blue-800 dark:text-blue-200">
                      Circles
                    </span>
                  </div>
                  <p class="text-sm text-blue-700 dark:text-blue-300 ml-6">
                    Deletes circles you created and removes you from joined circles
                  </p>
                </div>

                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-book-open"
                      class="h-4 w-4 text-blue-600 dark:text-blue-400"
                    />
                    <span class="text-sm font-semibold text-blue-800 dark:text-blue-200">
                      Posts
                    </span>
                  </div>
                  <p class="text-sm text-blue-700 dark:text-blue-300 ml-6">
                    Erases all timeline posts, shared content, and associated bookmarks
                  </p>
                </div>

                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-bookmark"
                      class="h-4 w-4 text-blue-600 dark:text-blue-400"
                    />
                    <span class="text-sm font-semibold text-blue-800 dark:text-blue-200">
                      Bookmarks
                    </span>
                  </div>
                  <p class="text-sm text-blue-700 dark:text-blue-300 ml-6">
                    Removes all saved bookmarks and your private notes
                  </p>
                </div>

                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-chat-bubble-left-right"
                      class="h-4 w-4 text-blue-600 dark:text-blue-400"
                    />
                    <span class="text-sm font-semibold text-blue-800 dark:text-blue-200">
                      Replies
                    </span>
                  </div>
                  <p class="text-sm text-blue-700 dark:text-blue-300 ml-6">
                    Deletes all your replies to conversations and threads
                  </p>
                </div>
              </div>

              <div class="pt-4 border-t border-blue-200 dark:border-blue-700">
                <p class="text-sm text-blue-700 dark:text-blue-300">
                  <span class="font-medium">Your account remains active:</span>
                  Deleting data doesn't close your account. You can continue using MOSSLET and start fresh
                  with a clean slate whenever you're ready.
                </p>
              </div>
            </div>
          </DesignSystem.liquid_card>

          <%!-- Privacy Assurance Card --%>
          <DesignSystem.liquid_card class="bg-gradient-to-br from-emerald-50/50 to-teal-50/30 dark:from-emerald-900/20 dark:to-teal-900/10">
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-emerald-100 via-teal-50 to-emerald-100 dark:from-emerald-900/30 dark:via-teal-900/25 dark:to-emerald-900/30">
                  <.phx_icon
                    name="hero-shield-check"
                    class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
                  />
                </div>
                <span class="text-emerald-800 dark:text-emerald-200">Complete Data Removal</span>
              </div>
            </:title>

            <div class="space-y-4">
              <p class="text-emerald-700 dark:text-emerald-300 leading-relaxed">
                When you delete data from MOSSLET, it's
                <strong class="font-medium">completely removed</strong>
                from our systems:
              </p>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-trash"
                      class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
                    />
                    <span class="text-sm font-semibold text-emerald-800 dark:text-emerald-200">
                      Permanent deletion
                    </span>
                  </div>
                  <p class="text-sm text-emerald-700 dark:text-emerald-300 ml-6">
                    No recovery possible once deleted
                  </p>
                </div>

                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-server"
                      class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
                    />
                    <span class="text-sm font-semibold text-emerald-800 dark:text-emerald-200">
                      Server cleanup
                    </span>
                  </div>
                  <p class="text-sm text-emerald-700 dark:text-emerald-300 ml-6">
                    Removed from all servers and backups
                  </p>
                </div>

                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-cloud"
                      class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
                    />
                    <span class="text-sm font-semibold text-emerald-800 dark:text-emerald-200">
                      Cloud storage cleared
                    </span>
                  </div>
                  <p class="text-sm text-emerald-700 dark:text-emerald-300 ml-6">
                    Files erased from external storage
                  </p>
                </div>

                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-eye-slash"
                      class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
                    />
                    <span class="text-sm font-semibold text-emerald-800 dark:text-emerald-200">
                      No data retention
                    </span>
                  </div>
                  <p class="text-sm text-emerald-700 dark:text-emerald-300 ml-6">
                    We don't keep copies for analytics
                  </p>
                </div>
              </div>

              <div class="pt-4 border-t border-emerald-200 dark:border-emerald-700">
                <p class="text-sm text-emerald-700 dark:text-emerald-300">
                  <span class="font-medium">Privacy first:</span>
                  We believe your data belongs to you. When you choose to delete it,
                  it's gone forever – just as it should be.
                </p>
              </div>
            </div>
          </DesignSystem.liquid_card>
        </div>
      </DesignSystem.liquid_container>
    </.layout>
    """
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    form =
      socket.assigns.current_user
      |> Accounts.change_user_delete_data(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, form: form, current_password: password)}
  end

  def handle_event("toggle_legacy", _params, socket) do
    {:noreply, assign(socket, legacy_expanded: !socket.assigns.legacy_expanded)}
  end

  def handle_event("delete_data", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user
    key = socket.assigns.key

    case Accounts.delete_user_data(user, password, key, user_params) do
      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}

      {:ok, nil} ->
        user
        |> Accounts.change_user_delete_data(user_params)
        |> to_form()

        info = "Woops! Looks like you didn't select any data to delete."

        {:noreply,
         socket
         |> put_flash(:success, nil)
         |> put_flash(:warning, info)
         |> push_patch(to: ~p"/app/users/manage-data")}

      :ok ->
        user
        |> Accounts.change_user_delete_data(user_params)
        |> to_form()

        info = "Fresh start! The data you selected was deleted successfully."

        {:noreply,
         socket
         |> put_flash(:warning, nil)
         |> put_flash(:success, info)
         |> push_patch(to: ~p"/app/users/manage-data")}
    end
  end

  def handle_info(
        {_ref, {:ok, :memory_deleted_from_storj, info}},
        socket
      ) do
    socket = put_flash(socket, :success, info)
    {:noreply, socket |> put_flash(:success, info)}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end
end
