defmodule MossletWeb.ManageDataLive do
  @moduledoc false
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Journal
  alias MossletWeb.DesignSystem

  def mount(_params, _session, socket) do
    entry_count = Journal.count_entries(socket.assigns.current_scope.user)

    {:ok,
     assign(socket,
       page_title: "Settings",
       current_password: nil,
       export_format: "txt",
       exporting: false,
       export_error: nil,
       export_progress: 0,
       journal_entry_count: entry_count,
       form: to_form(Accounts.change_user_delete_data(socket.assigns.current_scope.user))
     )}
  end

  def handle_params(_params, _url, socket) do
    {:noreply,
     assign(socket,
       page_title: "Settings",
       current_password: nil,
       form: to_form(Accounts.change_user_delete_data(socket.assigns.current_scope.user))
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
  attr :checked, :boolean, default: false

  defp data_checkbox(assigns) do
    ~H"""
    <div class="group relative overflow-hidden rounded-xl p-3 -m-3 transition-all duration-200 ease-out hover:bg-slate-50 dark:hover:bg-slate-800/50">
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
      current_scope={@current_scope}
      current_page={:manage_data}
      sidebar_current_page={:manage_data}
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
          <%!-- Export Journal Card --%>
          <DesignSystem.liquid_card class="bg-gradient-to-br from-indigo-50/50 to-violet-50/30 dark:from-indigo-900/20 dark:to-violet-900/10">
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-indigo-100 via-violet-50 to-indigo-100 dark:from-indigo-900/30 dark:via-violet-900/25 dark:to-indigo-900/30">
                  <.phx_icon
                    name="hero-arrow-down-tray"
                    class="h-4 w-4 text-indigo-600 dark:text-indigo-400"
                  />
                </div>
                <span class="text-indigo-800 dark:text-indigo-200">Export Journal</span>
              </div>
            </:title>

            <div class="space-y-5">
              <p class="text-indigo-700 dark:text-indigo-300 leading-relaxed">
                Download a copy of all your journal books and entries. Your entries are decrypted securely in your browser and never leave your device in plaintext.
              </p>

              <div class="flex items-center gap-3 text-sm text-indigo-600 dark:text-indigo-400">
                <.phx_icon name="hero-pencil-square" class="h-4 w-4 flex-shrink-0" />
                <span>
                  {@journal_entry_count} {if @journal_entry_count == 1, do: "entry", else: "entries"} available to export
                </span>
              </div>

              <%!-- ZK export hook — all formats decrypted browser-side --%>
              <div
                id="zk-export-hook"
                phx-hook="ZkExportHook"
                phx-update="ignore"
                class="hidden"
              >
              </div>

              <form id="export-journal-form" phx-submit="export_journal" class="space-y-4">
                <div>
                  <label
                    for="export-format"
                    class="block text-sm font-medium text-indigo-800 dark:text-indigo-200 mb-2"
                  >
                    Export Format
                  </label>
                  <div class="grid grid-cols-2 sm:grid-cols-4 gap-2">
                    <label
                      :for={
                        {value, label, icon, desc} <- [
                          {"txt", "Plain Text", "hero-document-text", ".txt file"},
                          {"csv", "Spreadsheet", "hero-table-cells", ".csv file"},
                          {"markdown", "Markdown", "hero-code-bracket", ".md file"},
                          {"pdf", "PDF", "hero-document", ".pdf file"}
                        ]
                      }
                      class={[
                        "relative flex flex-col items-center gap-1.5 p-3 rounded-xl border-2 cursor-pointer transition-all duration-200",
                        if(@export_format == value,
                          do:
                            "border-indigo-500 dark:border-indigo-400 bg-indigo-50 dark:bg-indigo-900/30 shadow-md shadow-indigo-500/10",
                          else:
                            "border-slate-200 dark:border-slate-700 hover:border-indigo-300 dark:hover:border-indigo-600 hover:bg-indigo-50/50 dark:hover:bg-indigo-900/10"
                        )
                      ]}
                    >
                      <input
                        type="radio"
                        name="format"
                        value={value}
                        checked={@export_format == value}
                        phx-click="select_export_format"
                        phx-value-format={value}
                        class="sr-only"
                      />
                      <.phx_icon
                        name={icon}
                        class={[
                          "h-5 w-5",
                          if(@export_format == value,
                            do: "text-indigo-600 dark:text-indigo-400",
                            else: "text-slate-400 dark:text-slate-500"
                          )
                        ]}
                      />
                      <span class={[
                        "text-sm font-medium",
                        if(@export_format == value,
                          do: "text-indigo-700 dark:text-indigo-300",
                          else: "text-slate-600 dark:text-slate-400"
                        )
                      ]}>
                        {label}
                      </span>
                      <span class={[
                        "text-xs",
                        if(@export_format == value,
                          do: "text-indigo-600 dark:text-indigo-400",
                          else: "text-slate-500 dark:text-slate-400"
                        )
                      ]}>
                        {desc}
                      </span>
                    </label>
                  </div>
                </div>

                <%= if @export_error do %>
                  <p class="text-sm text-rose-600 dark:text-rose-400 flex items-center gap-1.5">
                    <.phx_icon name="hero-exclamation-circle" class="h-4 w-4 flex-shrink-0" />
                    {@export_error}
                  </p>
                <% end %>

                <%!-- Progress bar for chunked exports --%>
                <%= if @exporting do %>
                  <div class="space-y-2">
                    <div class="flex items-center justify-between text-xs text-indigo-600 dark:text-indigo-400">
                      <span>Decrypting entries...</span>
                      <span>{@export_progress}%</span>
                    </div>
                    <div class="h-2 rounded-full bg-indigo-100 dark:bg-indigo-900/30 overflow-hidden">
                      <div
                        class="h-full rounded-full bg-gradient-to-r from-indigo-500 to-violet-500 transition-all duration-300 ease-out"
                        style={"width: #{@export_progress}%"}
                      >
                      </div>
                    </div>
                  </div>
                <% end %>

                <div class="flex items-center justify-between pt-2">
                  <div class="flex items-start gap-2 text-xs text-indigo-600/80 dark:text-indigo-400/80">
                    <.phx_icon name="hero-lock-closed" class="h-3.5 w-3.5 mt-0.5 flex-shrink-0" />
                    <span>Decrypted in your browser — zero-knowledge export</span>
                  </div>

                  <DesignSystem.liquid_button
                    type="submit"
                    color="indigo"
                    icon="hero-arrow-down-tray"
                    disabled={@exporting || @journal_entry_count == 0}
                    phx-disable-with="Exporting..."
                  >
                    <%= if @exporting do %>
                      Exporting...
                    <% else %>
                      Export Journal
                    <% end %>
                  </DesignSystem.liquid_button>
                </div>
              </form>
            </div>
          </DesignSystem.liquid_card>

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
                value={@current_scope.user.decrypted[:email]}
                data-decrypt-field="email"
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
                    id="user_data_bookmarks"
                    name="user[data][bookmarks]"
                    icon="hero-bookmark"
                    label="Bookmarks"
                    description="Remove all your saved bookmarks and bookmark notes"
                    checked={data_checked?(@form, "bookmarks")}
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
                    id="user_data_user_connections"
                    name="user[data][user_connections]"
                    icon="hero-users"
                    label="Connections"
                    description="Remove all your connection relationships with other users"
                    checked={data_checked?(@form, "user_connections")}
                  />

                  <.data_checkbox
                    id="user_data_conversations"
                    name="user[data][conversations]"
                    icon="hero-chat-bubble-bottom-center-text"
                    label="Conversations"
                    description="Delete all direct message conversations and their messages, including any shared images"
                    checked={data_checked?(@form, "conversations")}
                  />

                  <.data_checkbox
                    id="user_data_journals"
                    name="user[data][journals]"
                    icon="hero-pencil-square"
                    label="Journals"
                    description="Remove all your private journal entries and journal books"
                    checked={data_checked?(@form, "journals")}
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
                    id="user_data_replies"
                    name="user[data][replies]"
                    icon="hero-chat-bubble-left-right"
                    label="Replies"
                    description="Remove all your replies to posts and conversations"
                    checked={data_checked?(@form, "replies")}
                  />
                </div>
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
                    phx-debounce="200"
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

                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-chat-bubble-bottom-center-text"
                      class="h-4 w-4 text-blue-600 dark:text-blue-400"
                    />
                    <span class="text-sm font-semibold text-blue-800 dark:text-blue-200">
                      Conversations
                    </span>
                  </div>
                  <p class="text-sm text-blue-700 dark:text-blue-300 ml-6">
                    Removes all direct message conversations, messages, and shared images
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

  def handle_event("select_export_format", %{"format" => format}, socket)
      when format in ~w(csv txt pdf markdown) do
    {:noreply, assign(socket, export_format: format)}
  end

  # ZK export for all formats — sends encrypted blobs to browser for client-side decryption
  def handle_event("export_journal", %{"format" => format}, socket)
      when format in ~w(csv txt markdown pdf) do
    user = socket.assigns.current_scope.user
    sealed_user_key = user.user_key

    socket =
      socket
      |> assign(exporting: true, export_error: nil, export_progress: 0)

    # Fetch all books and entries (Cloak auto-unwraps AES, fields are NaCl secretbox blobs)
    books = Journal.list_books(user)

    book_data =
      Enum.map(books, fn book ->
        entries =
          Journal.list_journal_entries(user, book_id: book.id, limit: 100_000, order: :asc)

        %{
          title: book.title,
          description: book.description,
          entries: Enum.map(entries, &entry_to_encrypted_map/1)
        }
      end)

    loose_entries =
      user
      |> Journal.list_loose_entries(limit: 100_000)
      |> Enum.map(&entry_to_encrypted_map/1)

    total_entries =
      Enum.reduce(book_data, length(loose_entries), fn b, acc -> acc + length(b.entries) end)

    # Send all data in a single push_event for small-to-medium journals.
    # For very large journals (1000+), chunk into batches.
    chunk_size = 200

    if total_entries <= chunk_size do
      {:noreply,
       socket
       |> assign(export_progress: 100, exporting: false)
       |> push_event("zk-export-data", %{
         sealed_user_key: sealed_user_key,
         format: format,
         books: book_data,
         loose_entries: loose_entries,
         chunk: "only",
         total_entries: total_entries
       })}
    else
      # Chunked: send books first, then loose entries in batches
      send(
        self(),
        {:export_chunks, sealed_user_key, format, book_data, loose_entries, chunk_size}
      )

      {:noreply, socket |> assign(export_progress: 5)}
    end
  end

  def handle_event("export_journal", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_delete_data(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, form: form, current_password: password)}
  end

  def handle_event("delete_data", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

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

  # Chunked ZK export — sends book_data + loose_entries in batches
  def handle_info(
        {:export_chunks, sealed_user_key, format, book_data, loose_entries, chunk_size},
        socket
      ) do
    total_entries =
      Enum.reduce(book_data, length(loose_entries), fn b, acc -> acc + length(b.entries) end)

    # Split books into chunks of entries
    {chunked_books, _} =
      Enum.reduce(book_data, {[], 0}, fn book, {acc, sent} ->
        book_entries = book.entries
        chunks = Enum.chunk_every(book_entries, chunk_size)

        {book_chunks, new_sent} =
          Enum.reduce(chunks, {[], sent}, fn chunk, {chunk_acc, s} ->
            progress = min(95, round((s + length(chunk)) / total_entries * 95))
            {chunk_acc ++ [{%{book | entries: chunk}, progress}], s + length(chunk)}
          end)

        {acc ++ book_chunks, new_sent}
      end)

    # Send first chunk with metadata
    socket =
      case chunked_books do
        [{first_book, progress} | rest_books] ->
          socket
          |> assign(export_progress: progress)
          |> push_event("zk-export-data", %{
            sealed_user_key: sealed_user_key,
            format: format,
            books: [first_book],
            loose_entries: [],
            chunk: "first",
            total_entries: total_entries
          })
          |> then(fn socket ->
            # Send remaining book chunks
            Enum.reduce(rest_books, socket, fn {book, prog}, s ->
              s
              |> assign(export_progress: prog)
              |> push_event("zk-export-data", %{
                books: [book],
                loose_entries: [],
                chunk: "middle"
              })
            end)
          end)

        [] ->
          socket
      end

    # Send loose entries in chunks
    loose_chunks = Enum.chunk_every(loose_entries, chunk_size)

    socket =
      Enum.reduce(loose_chunks, socket, fn chunk, s ->
        s
        |> push_event("zk-export-data", %{
          books: [],
          loose_entries: chunk,
          chunk: "middle"
        })
      end)

    # Final signal
    socket =
      socket
      |> assign(export_progress: 100, exporting: false)
      |> push_event("zk-export-data", %{chunk: "last"})

    {:noreply, socket}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  # Converts a JournalEntry to a map of encrypted (NaCl secretbox) field values.
  # Cloak auto-unwraps the AES at-rest layer on Ecto load, so these are
  # base64-encoded NaCl secretbox blobs — exactly what the browser WASM expects.
  defp entry_to_encrypted_map(entry) do
    %{
      title: entry.title,
      body: entry.body,
      mood: entry.mood,
      entry_date: Date.to_iso8601(entry.entry_date),
      is_favorite: entry.is_favorite,
      word_count: entry.word_count || 0
    }
  end
end
