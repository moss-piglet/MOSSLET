defmodule MossletWeb.ChatComponents do
  @moduledoc """
  Chat and messaging components for Mosslet's group chat interface.

  Extracted from `MossletWeb.DesignSystem` as part of the design system
  modularization (Phase 1).
  """
  use Phoenix.Component
  use MossletWeb, :verified_routes

  import MossletWeb.CoreComponents, only: [phx_icon: 1]
  import MossletWeb.LocalTime, only: [local_time: 1]

  @doc """
  Liquid chat message component with premium styling for group chat.

  ## Examples

      <.liquid_chat_message
        id="msg-123"
        avatar_src="/images/avatar.jpg"
        sender_name="John"
        moniker="JD123"
        role={:owner}
        timestamp={~N[2024-01-01 12:00:00]}
        is_own_message={false}
        can_delete={true}
        on_delete="delete_message"
      >
        Hello, this is my message!
      </.liquid_chat_message>
  """
  attr :id, :string, required: true
  attr :avatar_src, :string, default: nil
  attr :avatar_alt, :string, default: "User avatar"
  attr :encrypted_avatar_data, :map, default: nil, doc: "ZK encrypted avatar blob + sealed key"
  attr :sender_name, :string, required: true
  attr :moniker, :string, required: true

  attr :org_display_name_decrypt?, :boolean,
    default: false,
    doc:
      "render a browser-filled placeholder for the sender's org-scoped ZK display name (Task #283)"

  attr :role, :atom, default: :member
  attr :timestamp, :any, required: true
  attr :is_own_message, :boolean, default: false
  attr :can_delete, :boolean, default: false
  attr :on_delete, :string, default: nil
  attr :is_grouped, :boolean, default: false
  attr :show_date_separator, :boolean, default: false

  attr :message_datetime, :any,
    default: nil,
    doc: "DateTime or NaiveDateTime for the date separator"

  attr :is_mentioned, :boolean,
    default: false,
    doc: "Whether this message mentions the current user"

  attr :is_new_mention, :boolean,
    default: false,
    doc: "Whether this is a newly received mention that should animate"

  attr :class, :any, default: ""
  slot :inner_block, required: true

  def liquid_chat_message(assigns) do
    ~H"""
    <div>
      <.liquid_chat_date_separator
        :if={@show_date_separator && @message_datetime}
        id={"date-sep-#{@id}"}
        datetime={@message_datetime}
      />
      <div
        id={@id}
        class={[
          "group/msg relative flex",
          if(@is_own_message, do: "justify-end", else: "justify-start"),
          @class
        ]}
        phx-hook={if(@is_new_mention, do: "MentionHighlight")}
        data-new-mention={@is_new_mention}
      >
        <div class={[
          "relative rounded-2xl max-w-[85%] sm:max-w-[75%]",
          "transition-all duration-300 ease-out hover:bg-gradient-to-r hover:from-teal-50/50 hover:via-white/70 hover:to-emerald-50/50 dark:hover:from-teal-900/20 dark:hover:via-slate-800/50 dark:hover:to-emerald-900/20",
          if(@is_grouped, do: "py-1 px-3 sm:px-4", else: "py-2.5 px-3 sm:px-4")
        ]}>
          <div class="flex items-start gap-3">
            <div :if={!@is_grouped && !@is_own_message} class="flex-shrink-0 pt-0.5">
              <div class={[
                "relative w-9 h-9 sm:w-10 sm:h-10 rounded-full overflow-hidden",
                "ring-2 ring-offset-2 ring-offset-white dark:ring-offset-slate-900",
                "transition-all duration-200",
                liquid_chat_avatar_ring(@role)
              ]}>
                <img
                  :if={@encrypted_avatar_data}
                  id={"zk-chat-avatar-#{@id}"}
                  phx-hook="DecryptAvatar"
                  data-encrypted-blob={@encrypted_avatar_data[:encrypted_blob_b64]}
                  data-sealed-key={@encrypted_avatar_data[:sealed_key]}
                  alt={@avatar_alt}
                  class="w-full h-full object-cover"
                />
                <img
                  :if={!@encrypted_avatar_data && @avatar_src}
                  id={"chat-avatar-#{@id}"}
                  src={@avatar_src}
                  alt={@avatar_alt}
                  class="w-full h-full object-cover"
                />
                <img
                  :if={!@encrypted_avatar_data && !@avatar_src}
                  src={~p"/images/logo.svg"}
                  alt={@avatar_alt}
                  class="w-full h-full object-cover"
                />
                <div class={[
                  "absolute inset-0 rounded-full opacity-0 group-hover/msg:opacity-100",
                  "bg-gradient-to-br from-white/20 to-transparent",
                  "transition-opacity duration-300"
                ]} />
              </div>
            </div>
            <div :if={@is_grouped && !@is_own_message} class="w-9 sm:w-10 flex-shrink-0" />

            <div class={[
              "min-w-0",
              if(@is_own_message, do: "flex flex-col items-end", else: "flex-1")
            ]}>
              <div
                :if={!@is_grouped}
                class={[
                  "flex flex-wrap items-center gap-x-2 gap-y-1 mb-1.5",
                  if(@is_own_message, do: "justify-end", else: "justify-start")
                ]}
              >
                <span
                  :if={@sender_name && !@is_own_message}
                  class={[
                    "font-semibold text-sm truncate max-w-[120px] sm:max-w-[180px]",
                    liquid_chat_sender_name_color(@role),
                    "transition-colors duration-200"
                  ]}
                >
                  {@sender_name}
                </span>

                <%!-- Org-scoped ZK display name (Task #283): for an org-mate the
                     viewer isn't personally connected to, the browser decrypts
                     their recognizable org persona and fills this span. Hidden
                     until filled so there's no empty gap or server placeholder. --%>
                <span
                  :if={@org_display_name_decrypt? && !@sender_name && !@is_own_message}
                  data-decrypt-org-name-target={@id}
                  class={[
                    "hidden font-semibold text-sm truncate max-w-[120px] sm:max-w-[180px]",
                    liquid_chat_sender_name_color(@role),
                    "transition-colors duration-200"
                  ]}
                ></span>

                <span
                  :if={!@is_own_message}
                  class={[
                    "inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium",
                    "transition-all duration-200",
                    liquid_chat_role_badge(@role)
                  ]}
                >
                  <.phx_icon name="hero-identification" class="w-3 h-3" />
                  <span
                    class="truncate max-w-[60px] sm:max-w-[100px]"
                    data-decrypt-moniker-target={@id}
                  >
                    {@moniker}
                  </span>
                </span>

                <span
                  :if={@is_own_message}
                  class={[
                    "inline-flex items-center gap-1 px-1.5 py-0.5 rounded-full text-xs font-medium",
                    "bg-gradient-to-r from-teal-100 to-emerald-100 text-teal-700",
                    "dark:from-teal-900/40 dark:to-emerald-900/40 dark:text-teal-300",
                    "border border-teal-200/60 dark:border-teal-700/40"
                  ]}
                >
                  <.phx_icon name="hero-check-mini" class="w-3 h-3" />
                  <span>You</span>
                </span>

                <time
                  id={"time-tooltip-" <> @id}
                  class={[
                    "text-xs whitespace-nowrap cursor-help",
                    "text-slate-500 dark:text-slate-400",
                    "hover:text-slate-700 dark:hover:text-slate-200",
                    "transition-colors duration-150"
                  ]}
                  phx-hook="LocalTimeTooltip"
                  data-timestamp={@timestamp}
                >
                  <.local_time id={@id <> "-created"} for={@timestamp} preset="TIME_SIMPLE" />
                </time>

                <button
                  :if={@can_delete && @on_delete}
                  type="button"
                  phx-click={@on_delete}
                  phx-value-id={@id}
                  class={[
                    "p-1 rounded-lg opacity-0 group-hover/msg:opacity-100 focus:opacity-100",
                    "text-slate-400 hover:text-red-500 dark:text-slate-500 dark:hover:text-red-400",
                    "hover:bg-red-50 dark:hover:bg-red-900/20",
                    "transition-all duration-200"
                  ]}
                  aria-label="Delete message"
                >
                  <.phx_icon name="hero-trash" class="w-3.5 h-3.5" />
                </button>
              </div>

              <div class="flex items-center gap-2">
                <div
                  :if={@is_grouped && @can_delete && @on_delete && @is_own_message}
                  class="flex-shrink-0"
                >
                  <button
                    type="button"
                    phx-click={@on_delete}
                    phx-value-id={@id}
                    class={[
                      "p-1 rounded-lg opacity-0 group-hover/msg:opacity-100 focus:opacity-100",
                      "text-slate-400 hover:text-red-500 dark:text-slate-500 dark:hover:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20",
                      "transition-all duration-200"
                    ]}
                    aria-label="Delete message"
                  >
                    <.phx_icon name="hero-trash" class="w-3.5 h-3.5" />
                  </button>
                </div>
                <div
                  class={[
                    "relative rounded-xl sm:rounded-2xl px-3.5 sm:px-4 py-2.5 sm:py-3",
                    "text-sm leading-relaxed",
                    "shadow-sm",
                    "transition-all duration-200",
                    if(@is_own_message,
                      do: [
                        "bg-gradient-to-r from-teal-500 to-emerald-500 dark:from-teal-600 dark:to-emerald-600",
                        "text-white",
                        "border border-teal-400/40 dark:border-teal-500/50",
                        "shadow-lg shadow-teal-500/25 dark:shadow-teal-500/15",
                        "group-hover/msg:shadow-xl group-hover/msg:shadow-teal-500/30 dark:group-hover/msg:shadow-teal-400/20",
                        "group-hover/msg:scale-[1.01]"
                      ],
                      else: [
                        "bg-white/95 dark:bg-slate-800/80 backdrop-blur-sm",
                        "border border-slate-200/60 dark:border-slate-700/50",
                        "group-hover/msg:border-teal-200/60 dark:group-hover/msg:border-teal-700/50",
                        "group-hover/msg:shadow-md group-hover/msg:shadow-teal-500/5 dark:group-hover/msg:shadow-teal-400/5"
                      ]
                    )
                  ]}
                  data-mention-content={if(@is_new_mention && !@is_own_message, do: "true")}
                >
                  <div class={[
                    "prose prose-sm max-w-none prose-p:my-0.5 prose-headings:mt-2 prose-headings:mb-1 prose-ul:my-1 prose-ol:my-1 prose-li:my-0 prose-pre:my-1.5 break-words",
                    if(@is_own_message,
                      do:
                        "text-white prose-headings:text-white prose-strong:text-white prose-code:text-teal-100 prose-code:bg-white/10 prose-a:text-teal-100 prose-a:no-underline hover:prose-a:underline",
                      else:
                        "prose-slate dark:prose-invert prose-code:text-teal-600 dark:prose-code:text-teal-400 prose-a:text-teal-600 dark:prose-a:text-teal-400 prose-a:no-underline hover:prose-a:underline"
                    )
                  ]}>
                    {render_slot(@inner_block)}
                  </div>
                </div>
                <div
                  :if={@is_grouped && @can_delete && @on_delete && !@is_own_message}
                  class="flex-shrink-0"
                >
                  <button
                    type="button"
                    phx-click={@on_delete}
                    phx-value-id={@id}
                    class={[
                      "p-1 rounded-lg opacity-0 group-hover/msg:opacity-100 focus:opacity-100",
                      "text-slate-400 hover:text-red-500 dark:text-slate-500 dark:hover:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20",
                      "transition-all duration-200"
                    ]}
                    aria-label="Delete message"
                  >
                    <.phx_icon name="hero-trash" class="w-3.5 h-3.5" />
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp liquid_chat_avatar_ring(:owner), do: "ring-pink-400 dark:ring-pink-500"
  defp liquid_chat_avatar_ring(:admin), do: "ring-orange-400 dark:ring-orange-500"
  defp liquid_chat_avatar_ring(:moderator), do: "ring-purple-400 dark:ring-purple-500"
  defp liquid_chat_avatar_ring(:member), do: "ring-emerald-400 dark:ring-emerald-500"
  defp liquid_chat_avatar_ring(_), do: "ring-teal-300 dark:ring-teal-500"

  defp liquid_chat_role_badge(:owner) do
    "bg-gradient-to-r from-pink-100 to-rose-50 text-pink-700 dark:from-pink-900/50 dark:to-rose-900/30 dark:text-pink-300"
  end

  defp liquid_chat_role_badge(:admin) do
    "bg-gradient-to-r from-orange-100 to-amber-50 text-orange-700 dark:from-orange-900/50 dark:to-amber-900/30 dark:text-orange-300"
  end

  defp liquid_chat_role_badge(:moderator) do
    "bg-gradient-to-r from-purple-100 to-indigo-50 text-purple-700 dark:from-purple-900/50 dark:to-indigo-900/30 dark:text-purple-300"
  end

  defp liquid_chat_role_badge(:member) do
    "bg-gradient-to-r from-emerald-100 to-teal-50 text-emerald-700 dark:from-emerald-900/50 dark:to-teal-900/30 dark:text-emerald-300"
  end

  defp liquid_chat_role_badge(_) do
    "bg-gradient-to-r from-teal-100 to-emerald-50 text-teal-700 dark:from-teal-900/50 dark:to-emerald-900/30 dark:text-teal-300"
  end

  defp liquid_chat_sender_name_color(:owner), do: "text-pink-600 dark:text-pink-300"
  defp liquid_chat_sender_name_color(:admin), do: "text-orange-600 dark:text-orange-300"
  defp liquid_chat_sender_name_color(:moderator), do: "text-purple-600 dark:text-purple-300"
  defp liquid_chat_sender_name_color(:member), do: "text-emerald-600 dark:text-emerald-300"
  defp liquid_chat_sender_name_color(_), do: "text-slate-700 dark:text-slate-300"

  @doc """
  Date separator for chat messages.

  Uses client-side local time via LocalDateSeparator hook for accurate
  "Today", "Yesterday", etc. display in user's timezone.

  ## Examples

      <.liquid_chat_date_separator id="sep-123" datetime={~U[2024-01-15 12:00:00Z]} />
  """
  attr :id, :string, required: true
  attr :datetime, :any, required: true, doc: "DateTime or NaiveDateTime for the separator"
  attr :class, :any, default: ""

  def liquid_chat_date_separator(assigns) do
    ~H"""
    <div class={["flex items-center gap-3 py-3", @class]}>
      <div class="flex-1 h-px bg-gradient-to-r from-transparent via-slate-200/60 to-slate-200/40 dark:via-slate-700/60 dark:to-slate-700/40" />
      <span class={[
        "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium",
        "bg-gradient-to-r from-slate-100/80 via-white/60 to-slate-100/80",
        "dark:from-slate-800/80 dark:via-slate-700/60 dark:to-slate-800/80",
        "text-slate-500 dark:text-slate-400",
        "border border-slate-200/40 dark:border-slate-700/40",
        "shadow-sm"
      ]}>
        <.phx_icon name="hero-calendar-days" class="w-3.5 h-3.5" />
        <span
          id={@id}
          phx-hook="LocalDateSeparator"
          data-datetime={format_datetime_for_hook(@datetime)}
          class="opacity-0 transition-opacity duration-200"
        ></span>
      </span>
      <div class="flex-1 h-px bg-gradient-to-r from-slate-200/40 via-slate-200/60 to-transparent dark:from-slate-700/40 dark:via-slate-700/60" />
    </div>
    """
  end

  defp format_datetime_for_hook(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_datetime_for_hook(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  defp format_datetime_for_hook(other), do: to_string(other)
end
