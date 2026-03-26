defmodule MossletWeb.ConversationLive.Show do
  use MossletWeb, :live_view

  import Ecto.Query, only: [from: 2]

  alias Mosslet.Accounts
  alias Mosslet.Conversations

  def render(assigns) do
    ~H"""
    <.layout
      current_page={:conversations}
      sidebar_current_page={:conversations}
      current_scope={@current_scope}
      type="sidebar"
    >
      <div class="flex flex-col h-full" id="conversation-show-container">
        <div class={[
          "flex-shrink-0 flex items-center gap-3 px-4 sm:px-6 py-3",
          "border-b border-slate-200/60 dark:border-slate-700/60",
          "bg-white/80 dark:bg-slate-800/80 backdrop-blur-sm"
        ]}>
          <.link
            navigate={~p"/app/conversations"}
            class="p-1.5 -ml-1.5 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 transition-all duration-200"
            aria-label="Back to conversations"
          >
            <.phx_icon name="hero-arrow-left" class="size-5" />
          </.link>

          <div class="flex items-center gap-3 flex-1 min-w-0">
            <div class="w-10 h-10 rounded-full overflow-hidden ring-2 ring-offset-1 ring-offset-white dark:ring-offset-slate-800 ring-slate-200/60 dark:ring-slate-700/60 flex-shrink-0">
              <img src={@partner_avatar} alt="Avatar" class="w-full h-full object-cover" />
            </div>
            <div class="min-w-0">
              <h1 class="font-semibold text-sm text-slate-900 dark:text-slate-100 truncate">
                {@partner_name}
              </h1>
              <p class="text-xs text-slate-500 dark:text-slate-400 truncate">
                <span class="inline-flex items-center gap-1">
                  <.phx_icon name="hero-lock-closed" class="w-3 h-3 text-teal-500" />
                  End-to-end encrypted
                </span>
              </p>
            </div>
          </div>

          <div class="flex items-center gap-1">
            <button
              :if={!@is_blocked}
              type="button"
              phx-click="open_block_modal"
              class="p-2 rounded-lg text-slate-400 hover:text-rose-500 hover:bg-rose-50 dark:hover:bg-rose-900/20 transition-all duration-200"
              title={"Block #{@partner_name}"}
            >
              <.phx_icon name="hero-no-symbol" class="size-5" />
            </button>
          </div>
        </div>

        <%= if @is_blocked do %>
          <div class="flex-1 flex items-center justify-center px-4">
            <div class="text-center max-w-sm">
              <div class="flex size-14 items-center justify-center rounded-2xl bg-rose-100 dark:bg-rose-900/30 mx-auto mb-4">
                <.phx_icon name="hero-no-symbol" class="size-7 text-rose-500 dark:text-rose-400" />
              </div>
              <h2 class="text-base font-semibold text-slate-800 dark:text-slate-200 mb-2">
                Conversation Blocked
              </h2>
              <p class="text-sm text-slate-500 dark:text-slate-400 mb-4">
                <%= if @blocked_by_me do %>
                  You have blocked this user. Unblock them from your settings to resume messaging.
                <% else %>
                  You cannot send messages in this conversation.
                <% end %>
              </p>
              <.link
                navigate={~p"/app/conversations"}
                class="text-sm font-medium text-teal-600 dark:text-teal-400 hover:text-teal-700 dark:hover:text-teal-300"
              >
                ← Back to conversations
              </.link>
            </div>
          </div>
        <% else %>
          <div
            id="messages-container"
            class="flex-1 overflow-y-auto min-h-0 px-4 sm:px-6 py-4 space-y-1"
            phx-hook="ConversationScroll"
            data-allow-download={to_string(@partner_allows_download)}
          >
            <div
              :if={@messages_empty?}
              id="messages-empty-state"
              class="flex flex-col items-center justify-center h-full text-center py-12"
            >
              <div class="flex size-14 items-center justify-center rounded-2xl bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/30 dark:to-emerald-900/30 mb-4">
                <.phx_icon name="hero-lock-closed" class="size-7 text-teal-600 dark:text-teal-400" />
              </div>
              <p class="text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                Start your encrypted conversation
              </p>
              <p class="text-xs text-slate-500 dark:text-slate-400 max-w-xs">
                Messages are encrypted end-to-end. Only you and {@partner_name} can read them.
              </p>
            </div>

            <div class="max-w-4xl mx-auto" id="messages-stream" phx-update="stream">
              <div
                :for={{dom_id, message} <- @streams.messages}
                id={dom_id}
                class={[
                  "group/msg flex mb-2",
                  if(message.sender_id == @current_scope.user.id,
                    do: "justify-end",
                    else: "justify-start"
                  )
                ]}
              >
                <div class="max-w-[85%] sm:max-w-[75%]">
                  <div class={[
                    "relative rounded-2xl px-4 py-2.5 text-sm leading-relaxed shadow-sm transition-all duration-200",
                    if(message.sender_id == @current_scope.user.id,
                      do: [
                        "bg-gradient-to-r from-teal-500 to-emerald-500 dark:from-teal-600 dark:to-emerald-600",
                        "text-white",
                        "border border-teal-400/40 dark:border-teal-500/50",
                        "shadow-lg shadow-teal-500/25 dark:shadow-teal-500/15"
                      ],
                      else: [
                        "bg-white/95 dark:bg-slate-800/80 backdrop-blur-sm",
                        "text-slate-800 dark:text-slate-200",
                        "border border-slate-200/60 dark:border-slate-700/50"
                      ]
                    )
                  ]}>
                    <div
                      id={"msg-content-#{message.id}"}
                      phx-hook="DecryptMessage"
                      data-encrypted-content={encode_message_content(message.content)}
                      data-conversation-key={@conversation_key_encrypted}
                      data-has-image={to_string(message.image_url != nil)}
                      data-message-id={message.id}
                      class={[
                        "prose prose-sm max-w-none prose-p:my-0.5 prose-headings:mt-2 prose-headings:mb-1 prose-ul:my-1 prose-ol:my-1 prose-li:my-0 prose-pre:my-1.5 break-words",
                        if(message.sender_id == @current_scope.user.id,
                          do:
                            "text-white prose-headings:text-white prose-strong:text-white prose-code:text-teal-100 prose-code:bg-white/10 prose-a:text-teal-100 prose-a:no-underline hover:prose-a:underline",
                          else:
                            "prose-slate dark:prose-invert prose-code:text-teal-600 dark:prose-code:text-teal-400 prose-a:text-teal-600 dark:prose-a:text-teal-400 prose-a:no-underline hover:prose-a:underline"
                        )
                      ]}
                    >
                      <span class="inline-flex items-center gap-1 text-xs opacity-60">
                        <.phx_icon name="hero-lock-closed" class="w-3 h-3" /> Decrypting...
                      </span>
                    </div>
                  </div>
                  <div class={[
                    "flex items-center gap-1.5 mt-1 px-1",
                    if(message.sender_id == @current_scope.user.id,
                      do: "justify-end",
                      else: "justify-start"
                    )
                  ]}>
                    <time class="text-xs text-slate-500 dark:text-slate-400">
                      <.local_time_ago id={"msg-time-#{message.id}"} at={message.inserted_at} />
                    </time>
                    <span
                      :if={message.edited}
                      class="text-xs text-slate-500 dark:text-slate-400 italic"
                    >
                      (edited)
                    </span>
                    <button
                      :if={message.sender_id == @current_scope.user.id}
                      type="button"
                      phx-click="confirm_delete_message"
                      phx-value-id={message.id}
                      class="opacity-0 group-hover/msg:opacity-100 p-0.5 rounded text-slate-400 hover:text-rose-500 transition-all duration-200"
                      title="Delete message"
                    >
                      <.phx_icon name="hero-trash" class="size-3.5" />
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div
            :if={@partner_typing}
            id="typing-indicator"
            class="flex-shrink-0 px-4 sm:px-6 pt-1 pb-0"
          >
            <div class="max-w-4xl mx-auto">
              <div class="flex items-center gap-2 py-1.5">
                <div class="flex gap-1 items-center">
                  <span class="w-1.5 h-1.5 rounded-full bg-teal-500/70 animate-bounce [animation-delay:0ms]" />
                  <span class="w-1.5 h-1.5 rounded-full bg-teal-500/70 animate-bounce [animation-delay:150ms]" />
                  <span class="w-1.5 h-1.5 rounded-full bg-teal-500/70 animate-bounce [animation-delay:300ms]" />
                </div>
                <span class="text-xs text-slate-500 dark:text-slate-400">
                  {@partner_name} is typing...
                </span>
              </div>
            </div>
          </div>

          <div class={[
            "flex-shrink-0 px-4 sm:px-6 py-3",
            "border-t border-slate-200/60 dark:border-slate-700/60",
            "bg-white/80 dark:bg-slate-800/80 backdrop-blur-sm"
          ]}>
            <div
              id="conversation-composer"
              phx-hook="ConversationComposer"
              data-conversation-key={@conversation_key_encrypted}
              data-user-public-key={@current_scope.user.key_pair["public"]}
              data-session-key={@current_scope.key}
              data-encrypted-private-key={@current_scope.user.key_pair["private"]}
              phx-drop-target={@uploads.photo.ref}
              class="max-w-4xl mx-auto"
            >
              <.form
                for={@form}
                id="message-form"
                phx-change="validate_upload"
                phx-submit="send_message_noop"
              >
                <div
                  :if={@completed_upload || uploading_photo?(@uploads.photo)}
                  id="conversation-photo-preview"
                  data-photo-ready={to_string(@completed_upload != nil)}
                  class="mb-2 p-2 rounded-xl border border-slate-200/60 dark:border-slate-700/60 bg-slate-50/60 dark:bg-slate-900/40"
                >
                  <%= cond do %>
                    <% @completed_upload && @completed_upload[:preview_data_url] -> %>
                      <div class="relative inline-block group">
                        <img
                          src={@completed_upload.preview_data_url}
                          alt={@completed_upload[:alt_text] || "Photo preview"}
                          class="h-20 w-20 object-cover rounded-lg"
                        />
                        <div class="absolute -top-1 -left-1 w-5 h-5 bg-emerald-500 rounded-full flex items-center justify-center shadow-lg">
                          <.phx_icon name="hero-check" class="h-3 w-3 text-white" />
                        </div>
                        <button
                          type="button"
                          phx-click="remove_completed_photo"
                          class="absolute -top-1 -right-1 w-5 h-5 bg-red-500 hover:bg-red-600 text-white rounded-full flex items-center justify-center transition-colors"
                        >
                          <.phx_icon name="hero-x-mark" class="h-3 w-3" />
                        </button>
                        <div class="absolute bottom-5 left-0.5 right-0.5 z-10 flex items-center justify-between">
                          <button
                            type="button"
                            id="conversation-edit-alt-photo"
                            phx-click="open_alt_text_modal"
                            phx-value-ref={@completed_upload.ref}
                            aria-label="Edit alt text"
                            class={[
                              "px-1.5 py-0.5 rounded text-[10px] font-bold flex items-center gap-0.5",
                              "transition-all duration-200 hover:scale-105",
                              if(@completed_upload[:alt_text] && @completed_upload[:alt_text] != "",
                                do: "bg-emerald-500 text-white",
                                else: "bg-slate-800 text-white hover:bg-slate-700"
                              )
                            ]}
                          >
                            <.phx_icon
                              :if={
                                !(@completed_upload[:alt_text] && @completed_upload[:alt_text] != "")
                              }
                              name="hero-plus"
                              class="h-2.5 w-2.5"
                            /> ALT
                          </button>
                          <button
                            type="button"
                            id="conversation-edit-image"
                            phx-click="open_image_edit_modal"
                            phx-value-ref={@completed_upload.ref}
                            aria-label="Edit image"
                            class={[
                              "w-6 h-5 rounded flex items-center justify-center",
                              "transition-all duration-200 hover:scale-105",
                              if(@completed_upload[:crop] && @completed_upload[:crop] != %{},
                                do: "bg-sky-500 text-white",
                                else: "bg-slate-800 text-white hover:bg-slate-700"
                              )
                            ]}
                          >
                            <.phx_icon name="hero-pencil" class="h-3 w-3" />
                          </button>
                        </div>
                        <div class="absolute bottom-0 left-0 right-0 bg-black/50 px-1 py-0.5 text-[9px] text-white truncate rounded-b-lg">
                          {@completed_upload.client_name}
                        </div>
                      </div>
                    <% upload_error?(@uploads.photo) -> %>
                      <div class="flex items-center gap-2 text-xs text-red-500">
                        <.phx_icon name="hero-exclamation-circle" class="h-4 w-4" />
                        <span>{upload_error_message(@uploads.photo)}</span>
                        <%= for entry <- @uploads.photo.entries do %>
                          <button
                            type="button"
                            phx-click="cancel_photo"
                            phx-value-ref={entry.ref}
                            class="ml-auto text-red-400 hover:text-red-600"
                          >
                            <.phx_icon name="hero-x-mark" class="h-4 w-4" />
                          </button>
                        <% end %>
                      </div>
                    <% uploading_photo?(@uploads.photo) -> %>
                      <div class="flex items-center gap-3">
                        <div class="h-20 w-20 rounded-lg bg-slate-200 dark:bg-slate-700 flex items-center justify-center">
                          <div class="w-5 h-5 rounded-full border-2 border-emerald-500/30 border-t-emerald-500 animate-spin">
                          </div>
                        </div>
                        <div class="flex-1 min-w-0">
                          <div class="text-xs font-medium text-slate-600 dark:text-slate-400 mb-1">
                            {upload_stage_label(@upload_stage)}
                          </div>
                          <div class="w-full bg-slate-200 dark:bg-slate-700 rounded-full h-1.5">
                            <div
                              class="bg-emerald-500 h-1.5 rounded-full transition-all duration-300"
                              style={"width: #{upload_stage_percent(@upload_stage)}%"}
                            >
                            </div>
                          </div>
                        </div>
                        <%= for entry <- @uploads.photo.entries do %>
                          <button
                            type="button"
                            phx-click="cancel_photo"
                            phx-value-ref={entry.ref}
                            class="p-1 text-slate-400 hover:text-red-500 transition-colors"
                          >
                            <.phx_icon name="hero-x-mark" class="h-4 w-4" />
                          </button>
                        <% end %>
                      </div>
                    <% true -> %>
                  <% end %>
                </div>
                <div class="relative">
                  <textarea
                    id="message-input"
                    name="content"
                    rows="1"
                    placeholder={"Message #{@partner_name}..."}
                    class={[
                      "block w-full resize-none rounded-2xl py-3 pl-4 pr-32 text-sm leading-relaxed",
                      "bg-slate-50/60 dark:bg-slate-900/40",
                      "border border-slate-200/60 dark:border-slate-700/60",
                      "focus:border-teal-400/60 dark:focus:border-teal-500/60",
                      "focus:ring-2 focus:ring-teal-500/20 dark:focus:ring-teal-400/20 focus:outline-none",
                      "text-slate-900 dark:text-slate-100",
                      "placeholder:text-slate-400 dark:placeholder:text-slate-500",
                      "transition-all duration-200",
                      "min-h-[48px] max-h-32 overflow-y-auto"
                    ]}
                    phx-hook="AutoResize"
                  ></textarea>
                  <div class="absolute right-2 bottom-2 flex items-center gap-1 z-[2]">
                    <.live_file_input upload={@uploads.photo} class="hidden" />
                    <label
                      for={@uploads.photo.ref}
                      id="conversation-image-upload-button"
                      class={[
                        "p-2 rounded-lg cursor-pointer transition-all duration-200 ease-out group",
                        if(@completed_upload,
                          do:
                            "text-emerald-500 dark:text-emerald-400 bg-emerald-50/50 dark:bg-emerald-900/20",
                          else:
                            "text-slate-500 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50/50 dark:hover:bg-emerald-900/20"
                        )
                      ]}
                      title="Attach photo"
                    >
                      <.phx_icon
                        name="hero-photo"
                        class="h-4 w-4 transition-transform duration-200 group-hover:scale-110"
                      />
                    </label>
                    <button
                      type="button"
                      id="conversation-emoji-button"
                      class="p-2 rounded-lg text-slate-500 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50/50 dark:hover:bg-emerald-900/20 transition-all duration-200 ease-out group"
                      phx-hook="ConversationEmojiPicker"
                      title="Add emoji"
                    >
                      <.phx_icon
                        name="hero-face-smile"
                        class="h-4 w-4 transition-transform duration-200 group-hover:scale-110"
                      />
                    </button>
                    <.liquid_markdown_guide_trigger
                      id="conversation-markdown-guide-trigger"
                      on_click={JS.push("open_markdown_guide")}
                      size="sm"
                    />
                    <button
                      type="submit"
                      class="group/btn inline-flex items-center justify-center gap-1.5 h-10 px-3 sm:px-4 rounded-xl bg-gradient-to-br from-teal-500 to-emerald-500 hover:from-teal-400 hover:to-emerald-400 text-white shadow-lg shadow-teal-500/25 hover:shadow-xl hover:shadow-teal-500/30 active:scale-95 transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-teal-500/50 focus:ring-offset-2 focus:ring-offset-white dark:focus:ring-offset-slate-800"
                      aria-label="Send message"
                    >
                      <.phx_icon name="hero-paper-airplane" class="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </.form>
            </div>
          </div>
        <% end %>
      </div>

      <.liquid_modal
        :if={@show_delete_message_confirm}
        id="delete-message-modal"
        show={@show_delete_message_confirm}
        size="sm"
        on_cancel={JS.push("cancel_delete_message")}
      >
        <:title>
          <div class="flex items-center gap-3">
            <div class="p-2 rounded-xl bg-rose-100 dark:bg-rose-900/30">
              <.phx_icon name="hero-trash" class="size-5 text-rose-600 dark:text-rose-400" />
            </div>
            <span>Delete Message</span>
          </div>
        </:title>

        <div class="space-y-4">
          <p class="text-sm text-slate-600 dark:text-slate-400">
            Are you sure you want to delete this message? This cannot be undone.
          </p>
          <div class="flex justify-end gap-3 pt-2">
            <.liquid_button
              type="button"
              variant="ghost"
              color="slate"
              phx-click="cancel_delete_message"
            >
              Cancel
            </.liquid_button>
            <.liquid_button
              type="button"
              color="rose"
              icon="hero-trash"
              phx-click="delete_message"
              phx-value-id={@delete_message_id}
            >
              Delete
            </.liquid_button>
          </div>
        </div>
      </.liquid_modal>

      <.live_component
        :if={@show_block_modal}
        module={MossletWeb.TimelineLive.BlockModalComponent}
        id="block-modal-component"
        show={@show_block_modal}
        user_id={@blocked_user_id}
        user_name={@partner_name}
        post_id="conversation-show"
        existing_block={nil}
        default_block_type="full"
        decrypted_reason=""
        block_update?={false}
        target_container="#conversation-show-container"
      />

      <.liquid_markdown_guide_modal
        id="conversation-markdown-guide-modal"
        show={@show_markdown_guide}
        on_cancel={JS.push("close_markdown_guide")}
      />

      <MossletWeb.DesignSystem.liquid_alt_text_modal
        show={@alt_text_modal_open}
        upload={@alt_text_editing_upload}
        alt_text={@alt_text_editing_value}
        id="conversation-alt-text-modal"
      />

      <MossletWeb.DesignSystem.liquid_image_edit_modal
        show={@image_edit_modal_open}
        upload={@image_edit_upload}
        crop={@image_edit_crop}
        id="conversation-image-edit-modal"
      />

      <div
        id="conversation-image-lightbox"
        phx-hook="ImageLightbox"
        class="fixed inset-0 z-[70] hidden"
        data-allow-download={to_string(@partner_allows_download)}
      >
        <div
          id="conversation-image-lightbox-backdrop"
          class="absolute inset-0 bg-black/90 backdrop-blur-md transition-opacity duration-300 opacity-0"
        >
        </div>
        <div class="absolute inset-0 flex items-center justify-center p-4">
          <div class="absolute top-4 right-4 z-10 flex items-center gap-2">
            <a
              id="conversation-image-lightbox-download"
              href="#"
              download="image.webp"
              class="hidden p-2.5 rounded-xl bg-white/10 hover:bg-white/20 text-white/90 hover:text-white transition-all duration-200 backdrop-blur-sm border border-white/10"
              title="Download image"
            >
              <.phx_icon name="hero-arrow-down-tray" class="size-5" />
            </a>
            <button
              id="conversation-image-lightbox-close"
              type="button"
              class="p-2.5 rounded-xl bg-white/10 hover:bg-white/20 text-white/90 hover:text-white transition-all duration-200 backdrop-blur-sm border border-white/10"
              title="Close"
            >
              <.phx_icon name="hero-x-mark" class="size-5" />
            </button>
          </div>
          <img
            id="conversation-image-lightbox-img"
            src=""
            alt="Full size image"
            class="max-w-[95vw] max-h-[90vh] object-contain rounded-lg shadow-2xl transition-transform duration-300 scale-95 opacity-0"
          />
        </div>
      </div>
    </.layout>
    """
  end

  def mount(%{"id" => conversation_id}, session, socket) do
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    conversation = Conversations.get_conversation!(conversation_id)
    user_conversation = Conversations.get_user_conversation(conversation_id, current_user.id)

    unless user_conversation do
      {:ok,
       socket
       |> put_flash(:error, "Conversation not found")
       |> push_navigate(to: ~p"/app/conversations")}
    else
      my_user_connection = find_my_user_connection(conversation, current_user)

      {partner_name, partner_avatar, _partner_username} =
        case my_user_connection do
          nil ->
            {"[Unknown]", "/images/logo.svg", "unknown"}

          uconn ->
            {
              get_decrypted_connection_name(uconn, current_user, key),
              get_connection_avatar_src(uconn, current_user, key),
              get_decrypted_connection_username(uconn, current_user, key)
            }
        end

      partner_user_id = get_partner_user_id(conversation, current_user.id)

      partner_allows_download =
        case Accounts.get_user_connection_between_users(current_user.id, partner_user_id) do
          %{photos?: true} -> true
          _ -> false
        end

      {is_blocked, blocked_by_me} = check_block_status(current_user, partner_user_id)

      messages =
        if is_blocked, do: [], else: Conversations.list_messages(conversation_id)

      conversation_key_encrypted =
        case user_conversation.key do
          key_data when is_binary(key_data) -> Base.encode64(key_data)
          _ -> ""
        end

      if connected?(socket) do
        Conversations.subscribe_to_conversation(conversation_id)
        Conversations.mark_conversation_read(conversation_id, current_user.id)
        Accounts.block_subscribe(current_user)
      end

      {:ok,
       socket
       |> assign(:page_title, "#{partner_name} — Conversations")
       |> assign(:conversation, conversation)
       |> assign(:user_conversation, user_conversation)
       |> assign(:partner_name, partner_name)
       |> assign(:partner_avatar, partner_avatar)
       |> assign(:partner_user_id, partner_user_id)
       |> assign(:is_blocked, is_blocked)
       |> assign(:blocked_by_me, blocked_by_me)
       |> assign(:messages_empty?, messages == [])
       |> stream(:messages, messages)
       |> assign(:conversation_key_encrypted, conversation_key_encrypted)
       |> assign(:show_markdown_guide, false)
       |> assign(:show_delete_message_confirm, false)
       |> assign(:delete_message_id, nil)
       |> assign(:show_block_modal, false)
       |> assign(:blocked_user_id, partner_user_id)
       |> assign(:partner_allows_download, partner_allows_download)
       |> assign(:form, to_form(%{}, as: :message))
       |> assign(:partner_typing, false)
       |> assign(:upload_stage, nil)
       |> assign(:completed_upload, nil)
       |> assign(:alt_text_modal_open, false)
       |> assign(:alt_text_editing_upload, nil)
       |> assign(:alt_text_editing_value, "")
       |> assign(:image_edit_modal_open, false)
       |> assign(:image_edit_upload, nil)
       |> assign(:image_edit_crop, %{})
       |> assign(:user_token, session["user_token"])
       |> allow_upload(:photo,
         accept: ~w(.gif .jpg .jpeg .png .webp .heic .heif),
         max_entries: 1,
         max_file_size: 10_000_000,
         auto_upload: true,
         progress: &handle_upload_progress/3,
         writer: fn _name, entry, socket ->
           {Mosslet.FileUploads.ImageUploadWriter,
            %{
              lv_pid: self(),
              entry_ref: entry.ref,
              user_token: socket.assigns.user_token,
              key: socket.assigns.current_scope.key,
              visibility: "connections",
              expected_size: entry.client_size
            }}
         end
       )}
    end
  end

  def terminate(_reason, socket) do
    if socket.assigns[:typing_timer] do
      Process.cancel_timer(socket.assigns.typing_timer)
    end

    if upload = socket.assigns[:completed_upload] do
      if upload[:temp_path], do: cleanup_temp_file(upload.temp_path)
    end

    :ok
  end

  def handle_event("typing", %{"typing" => typing}, socket) do
    conversation_id = socket.assigns.conversation.id
    user_id = socket.assigns.current_scope.user.id

    Conversations.broadcast_typing(conversation_id, user_id, typing)

    socket =
      if typing do
        if socket.assigns[:typing_timer] do
          Process.cancel_timer(socket.assigns.typing_timer)
        end

        timer = Process.send_after(self(), :clear_typing, 5_000)
        assign(socket, :typing_timer, timer)
      else
        if socket.assigns[:typing_timer] do
          Process.cancel_timer(socket.assigns.typing_timer)
        end

        assign(socket, :typing_timer, nil)
      end

    {:noreply, socket}
  end

  def handle_event("send_message", %{"encrypted_content" => encrypted_content}, socket) do
    current_user = socket.assigns.current_scope.user
    conversation = socket.assigns.conversation

    if socket.assigns.is_blocked do
      {:noreply, put_flash(socket, :error, "Cannot send messages in a blocked conversation")}
    else
      {image_url, image_key} = maybe_upload_photo(socket)

      attrs = %{
        content: Base.decode64!(encrypted_content),
        conversation_id: conversation.id,
        sender_id: current_user.id,
        image_url: image_url,
        image_key: image_key
      }

      case Conversations.create_message(attrs) do
        {:ok, message} ->
          Conversations.broadcast_new_message(conversation.id, message)
          Conversations.broadcast_typing(conversation.id, current_user.id, false)

          conversation.user_conversations
          |> Enum.each(fn uc ->
            Conversations.broadcast_conversation_updated(uc.user_id, conversation.id)
          end)

          {:noreply,
           socket
           |> assign(:completed_upload, nil)
           |> assign(:upload_stage, nil)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to send message")}
      end
    end
  end

  def handle_event("send_message", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("send_message_noop", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("confirm_delete_message", %{"id" => message_id}, socket) do
    {:noreply,
     socket
     |> assign(:show_delete_message_confirm, true)
     |> assign(:delete_message_id, message_id)}
  end

  def handle_event("cancel_delete_message", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_delete_message_confirm, false)
     |> assign(:delete_message_id, nil)}
  end

  def handle_event("delete_message", %{"id" => message_id}, socket) do
    current_user = socket.assigns.current_scope.user
    message = Conversations.get_message(message_id)

    cond do
      is_nil(message) ->
        {:noreply, put_flash(socket, :error, "Message not found")}

      message.sender_id != current_user.id ->
        {:noreply, put_flash(socket, :error, "You can only delete your own messages")}

      true ->
        case Conversations.delete_message(message) do
          {:ok, deleted} ->
            if message.image_url do
              Mosslet.FileUploads.ImageUploadWriter.delete_from_storage(message.image_url)
            end

            Conversations.broadcast_message_deleted(socket.assigns.conversation.id, deleted)

            {:noreply,
             socket
             |> stream_delete(:messages, deleted)
             |> assign(:show_delete_message_confirm, false)
             |> assign(:delete_message_id, nil)
             |> put_flash(:info, "Message deleted")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to delete message")}
        end
    end
  end

  def handle_event("open_block_modal", _params, socket) do
    {:noreply, assign(socket, :show_block_modal, true)}
  end

  def handle_event("close_block_modal", _params, socket) do
    {:noreply, assign(socket, :show_block_modal, false)}
  end

  def handle_event("open_markdown_guide", _params, socket) do
    {:noreply, assign(socket, :show_markdown_guide, true)}
  end

  def handle_event("close_markdown_guide", _params, socket) do
    {:noreply, assign(socket, :show_markdown_guide, false)}
  end

  def handle_event("cancel_photo", %{"ref" => ref}, socket) do
    {:noreply,
     socket
     |> cancel_upload(:photo, ref)
     |> assign(:upload_stage, nil)
     |> assign(:completed_upload, nil)}
  end

  def handle_event("remove_completed_photo", _params, socket) do
    if upload = socket.assigns.completed_upload do
      if upload[:temp_path], do: cleanup_temp_file(upload.temp_path)
    end

    {:noreply,
     socket
     |> assign(:completed_upload, nil)
     |> assign(:upload_stage, nil)}
  end

  def handle_event("open_alt_text_modal", %{"ref" => _ref}, socket) do
    upload = socket.assigns.completed_upload

    {:noreply,
     socket
     |> assign(:alt_text_modal_open, true)
     |> assign(:alt_text_editing_upload, upload)
     |> assign(:alt_text_editing_value, (upload && upload[:alt_text]) || "")}
  end

  def handle_event("close_alt_text_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:alt_text_modal_open, false)
     |> assign(:alt_text_editing_upload, nil)
     |> assign(:alt_text_editing_value, "")}
  end

  def handle_event("save_alt_text", %{"alt_text" => alt_text}, socket) do
    case socket.assigns.completed_upload do
      nil ->
        {:noreply, socket}

      upload ->
        updated_upload = Map.put(upload, :alt_text, String.trim(alt_text))

        {:noreply,
         socket
         |> assign(:completed_upload, updated_upload)
         |> assign(:alt_text_modal_open, false)
         |> assign(:alt_text_editing_upload, nil)
         |> assign(:alt_text_editing_value, "")}
    end
  end

  def handle_event("open_image_edit_modal", %{"ref" => _ref}, socket) do
    upload = socket.assigns.completed_upload

    {:noreply,
     socket
     |> assign(:image_edit_modal_open, true)
     |> assign(:image_edit_upload, upload)
     |> assign(:image_edit_crop, (upload && upload[:crop]) || %{})}
  end

  def handle_event("close_image_edit_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:image_edit_modal_open, false)
     |> assign(:image_edit_upload, nil)
     |> assign(:image_edit_crop, %{})}
  end

  def handle_event("save_image_crop", %{"ref" => _ref, "crop" => crop}, socket) do
    crop_map =
      case crop do
        %{"x" => x, "y" => y, "width" => w, "height" => h} ->
          %{x: x, y: y, width: w, height: h}

        _ ->
          %{}
      end

    case socket.assigns.completed_upload do
      nil ->
        {:noreply, socket}

      upload ->
        upload =
          if is_nil(upload[:original_preview_data_url]) do
            Map.put(upload, :original_preview_data_url, upload.preview_data_url)
          else
            upload
          end

        upload = Map.put(upload, :crop, crop_map)

        upload =
          if crop_map != %{} do
            case generate_cropped_preview(upload.temp_path, crop_map) do
              {:ok, cropped_preview} -> Map.put(upload, :preview_data_url, cropped_preview)
              _ -> upload
            end
          else
            Map.put(
              upload,
              :preview_data_url,
              upload[:original_preview_data_url] || upload.preview_data_url
            )
          end

        {:noreply,
         socket
         |> assign(:completed_upload, upload)
         |> assign(:image_edit_modal_open, false)
         |> assign(:image_edit_upload, nil)
         |> assign(:image_edit_crop, %{})}
    end
  end

  def handle_event("reset_crop", _params, socket) do
    case socket.assigns.completed_upload do
      nil ->
        {:noreply, socket}

      upload ->
        updated_upload =
          upload
          |> Map.put(:crop, %{})
          |> Map.put(
            :preview_data_url,
            upload[:original_preview_data_url] || upload.preview_data_url
          )

        {:noreply,
         socket
         |> assign(:completed_upload, updated_upload)
         |> assign(:image_edit_crop, %{})}
    end
  end

  def handle_event("decrypt_message_image", %{"message_id" => message_id}, socket) do
    message = Conversations.get_message(message_id)

    if message && message.image_url && message.image_key do
      case fetch_and_decrypt_image(message.image_url, message.image_key) do
        {:ok, data_url} ->
          {:reply, %{image_data_url: data_url}, socket}

        {:error, _reason} ->
          {:reply, %{error: "Failed to load image"}, socket}
      end
    else
      {:reply, %{error: "No image"}, socket}
    end
  end

  def handle_info(
        {:upload_ready, entry_ref, %{processed_binary: binary, trix_key: trix_key} = upload_data},
        socket
      ) do
    entry = Enum.find(socket.assigns.uploads.photo.entries, &(&1.ref == entry_ref))
    temp_path = write_upload_to_temp_file(binary, entry_ref)
    preview_data_url = generate_thumbnail_preview(binary)

    completed_upload = %{
      ref: entry_ref,
      client_name: (entry && entry.client_name) || "photo",
      temp_path: temp_path,
      trix_key: trix_key,
      preview_data_url: preview_data_url,
      ai_generated: Map.get(upload_data, :ai_generated, false)
    }

    {:noreply,
     socket
     |> assign(:upload_stage, {:ready, nil})
     |> assign(:completed_upload, completed_upload)}
  end

  def handle_info({:upload_progress, _entry_ref, stage, value}, socket) do
    {:noreply, assign(socket, :upload_stage, {stage, value})}
  end

  def handle_info({:upload_trix_key, _entry_ref, _trix_key}, socket) do
    {:noreply, socket}
  end

  def handle_info({:submit_block, block_params}, socket) do
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key
    partner_user_id = socket.assigns.partner_user_id

    blocked_user = Accounts.get_user!(partner_user_id)

    case Accounts.block_user(current_user, blocked_user, block_params,
           user: current_user,
           key: key
         ) do
      {:ok, _user_block} ->
        {:noreply,
         socket
         |> assign(:show_block_modal, false)
         |> assign(:is_blocked, true)
         |> assign(:blocked_by_me, true)
         |> assign(:messages_empty?, true)
         |> stream(:messages, [], reset: true)
         |> put_flash(:info, "User has been blocked")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to block user")}
    end
  end

  def handle_info({:close_block_modal}, socket) do
    {:noreply, assign(socket, :show_block_modal, false)}
  end

  def handle_info({:new_message, message}, socket) do
    if socket.assigns.is_blocked do
      {:noreply, socket}
    else
      current_user = socket.assigns.current_scope.user

      socket =
        socket
        |> assign(:messages_empty?, false)
        |> stream_insert(:messages, message)
        |> push_event("new-message", %{id: message.id})

      if message.sender_id != current_user.id do
        Conversations.mark_conversation_read(socket.assigns.conversation.id, current_user.id)
      end

      {:noreply, socket}
    end
  end

  def handle_info({:message_updated, message}, socket) do
    {:noreply, stream_insert(socket, :messages, message)}
  end

  def handle_info({:message_deleted, message}, socket) do
    {:noreply, stream_delete(socket, :messages, message)}
  end

  def handle_info({event, _block}, socket)
      when event in [:user_blocked, :user_unblocked, :user_block_updated] do
    current_user = socket.assigns.current_scope.user
    partner_user_id = socket.assigns.partner_user_id
    {is_blocked, blocked_by_me} = check_block_status(current_user, partner_user_id)

    messages =
      if is_blocked, do: [], else: Conversations.list_messages(socket.assigns.conversation.id)

    {:noreply,
     socket
     |> assign(:is_blocked, is_blocked)
     |> assign(:blocked_by_me, blocked_by_me)
     |> assign(:messages_empty?, messages == [])
     |> stream(:messages, messages, reset: true)}
  end

  def handle_info({:conversation_deleted, _conversation_id}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "This conversation has been deleted")
     |> push_navigate(to: ~p"/app/conversations")}
  end

  def handle_info({:typing, user_id, typing?}, socket) do
    if user_id != socket.assigns.current_scope.user.id do
      {:noreply, assign(socket, :partner_typing, typing?)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(:clear_typing, socket) do
    conversation_id = socket.assigns.conversation.id
    user_id = socket.assigns.current_scope.user.id
    Conversations.broadcast_typing(conversation_id, user_id, false)
    {:noreply, assign(socket, :typing_timer, nil)}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp encode_message_content(content) when is_binary(content) do
    Base.encode64(content)
  end

  defp encode_message_content(_), do: ""

  defp find_my_user_connection(conversation, current_user) do
    partner_user_id =
      conversation.user_conversations
      |> Enum.find(fn uc -> uc.user_id != current_user.id end)
      |> case do
        nil -> nil
        uc -> uc.user_id
      end

    if partner_user_id do
      from(uc in Mosslet.Accounts.UserConnection,
        where: uc.user_id == ^current_user.id and uc.reverse_user_id == ^partner_user_id,
        where: not is_nil(uc.confirmed_at),
        preload: [:connection]
      )
      |> Mosslet.Repo.one()
    else
      nil
    end
  end

  defp get_partner_user_id(conversation, current_user_id) do
    conversation.user_conversations
    |> Enum.find(fn uc -> uc.user_id != current_user_id end)
    |> case do
      nil -> nil
      uc -> uc.user_id
    end
  end

  defp check_block_status(current_user, partner_user_id) when is_binary(partner_user_id) do
    my_block = Accounts.get_user_block(current_user, partner_user_id)
    partner = Accounts.get_user!(partner_user_id)
    their_block = Accounts.get_user_block(partner, current_user.id)

    conversation_blocked_by_me =
      my_block != nil and my_block.block_type in [:full, :conversations_only]

    conversation_blocked_by_them =
      their_block != nil and their_block.block_type in [:full, :conversations_only]

    {conversation_blocked_by_me || conversation_blocked_by_them, conversation_blocked_by_me}
  end

  defp check_block_status(_current_user, _partner_user_id), do: {false, false}

  defp handle_upload_progress(:photo, entry, socket) do
    if entry.done? do
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp maybe_upload_photo(socket) do
    case socket.assigns.completed_upload do
      nil ->
        {nil, nil}

      upload ->
        binary = File.read!(upload.temp_path)
        binary = maybe_apply_crop(binary, upload[:crop])
        trix_key = upload.trix_key

        case Mosslet.FileUploads.ImageUploadWriter.upload_to_storage(binary, trix_key) do
          {:ok, file_path} ->
            cleanup_temp_file(upload.temp_path)
            {file_path, trix_key}

          {:error, reason} ->
            require Logger
            Logger.error("Failed to upload conversation photo: #{inspect(reason)}")
            {nil, nil}
        end
    end
  end

  defp fetch_and_decrypt_image(image_url, image_key) do
    bucket = Mosslet.Encrypted.Session.memories_bucket()

    case ExAws.S3.get_object(bucket, image_url) |> ExAws.request() do
      {:ok, %{body: encrypted_binary}} ->
        case Mosslet.Encrypted.Utils.decrypt(%{key: image_key, payload: encrypted_binary}) do
          {:ok, decrypted} ->
            {:ok, "data:image/webp;base64,#{Base.encode64(decrypted)}"}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp write_upload_to_temp_file(binary, entry_ref) do
    temp_path =
      Mosslet.FileUploads.TempStorage.temp_path("conversation_uploads", entry_ref) <> ".webp"

    File.write!(temp_path, binary)
    temp_path
  end

  defp generate_thumbnail_preview(binary) do
    case Image.from_binary(binary, pages: :all) do
      {:ok, image} ->
        is_animated = Image.pages(image) > 1

        thumb_result =
          if is_animated do
            Image.map_join_pages(image, fn page ->
              Image.thumbnail(page, "400x400", crop: :attention)
            end)
          else
            Image.thumbnail(image, "400x400", crop: :attention)
          end

        case thumb_result do
          {:ok, thumb} ->
            write_opts =
              if is_animated,
                do: [suffix: ".webp", webp: [quality: 75, minimize_file_size: true]],
                else: [suffix: ".webp", webp: [quality: 75]]

            case Image.write(thumb, :memory, write_opts) do
              {:ok, thumb_binary} ->
                "data:image/webp;base64,#{Base.encode64(thumb_binary)}"

              _ ->
                nil
            end

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  defp cleanup_temp_file(nil), do: :ok

  defp cleanup_temp_file(path) do
    File.rm(path)
    :ok
  end

  defp uploading_photo?(upload) do
    upload.entries != [] and not Enum.all?(upload.entries, & &1.done?)
  end

  defp upload_error?(upload) do
    Enum.any?(upload.entries, fn entry -> entry.cancelled? || !entry.valid? end) ||
      upload.errors != []
  end

  defp upload_error_message(upload) do
    upload_error = List.first(upload.errors)

    case upload_error do
      {_ref, :too_large} -> "File too large (max 10MB)"
      {_ref, :not_accepted} -> "File type not supported"
      {_ref, :too_many_files} -> "Only 1 photo allowed"
      _ -> "Upload failed"
    end
  end

  defp upload_stage_label(nil), do: "Preparing..."
  defp upload_stage_label({:receiving, _}), do: "Uploading..."
  defp upload_stage_label({:validating, _}), do: "Checking safety..."
  defp upload_stage_label({:processing, _}), do: "Processing..."
  defp upload_stage_label({:ready, _}), do: "Ready"
  defp upload_stage_label({:error, _}), do: "Error"
  defp upload_stage_label(_), do: "Processing..."

  defp upload_stage_percent(nil), do: 5
  defp upload_stage_percent({:receiving, val}) when is_integer(val), do: val
  defp upload_stage_percent({:validating, _}), do: 45
  defp upload_stage_percent({:processing, val}) when is_integer(val), do: val
  defp upload_stage_percent({:ready, _}), do: 100
  defp upload_stage_percent(_), do: 10

  defp maybe_apply_crop(binary, nil), do: binary
  defp maybe_apply_crop(binary, crop) when crop == %{}, do: binary

  defp maybe_apply_crop(binary, %{x: x, y: y, width: w, height: h}) do
    case Image.from_binary(binary, pages: :all) do
      {:ok, image} ->
        is_animated = Image.pages(image) > 1
        {img_width, img_height, _} = Image.shape(image)

        crop_x = round(x * img_width)
        crop_y = round(y * img_height)
        crop_w = round(w * img_width)
        crop_h = round(h * img_height)

        crop_w = min(crop_w, img_width - crop_x)
        crop_h = min(crop_h, img_height - crop_y)

        crop_result =
          if is_animated do
            Image.map_join_pages(image, fn page ->
              Image.crop(page, crop_x, crop_y, crop_w, crop_h)
            end)
          else
            Image.crop(image, crop_x, crop_y, crop_w, crop_h)
          end

        case crop_result do
          {:ok, cropped} ->
            write_opts =
              if is_animated,
                do: [suffix: ".webp", webp: [quality: 90, minimize_file_size: true]],
                else: [suffix: ".webp", webp: [quality: 90]]

            case Image.write(cropped, :memory, write_opts) do
              {:ok, cropped_binary} -> cropped_binary
              _ -> binary
            end

          _ ->
            binary
        end

      _ ->
        binary
    end
  end

  defp maybe_apply_crop(binary, _), do: binary

  defp generate_cropped_preview(temp_path, %{x: x, y: y, width: w, height: h}) do
    case File.read(temp_path) do
      {:ok, binary} ->
        case Image.from_binary(binary, pages: :all) do
          {:ok, image} ->
            is_animated = Image.pages(image) > 1
            {img_width, img_height, _} = Image.shape(image)

            crop_x = round(x * img_width)
            crop_y = round(y * img_height)
            crop_w = round(w * img_width)
            crop_h = round(h * img_height)

            crop_w = min(crop_w, img_width - crop_x)
            crop_h = min(crop_h, img_height - crop_y)

            crop_result =
              if is_animated do
                Image.map_join_pages(image, fn page ->
                  Image.crop(page, crop_x, crop_y, crop_w, crop_h)
                end)
              else
                Image.crop(image, crop_x, crop_y, crop_w, crop_h)
              end

            case crop_result do
              {:ok, cropped} ->
                thumb_result =
                  if is_animated do
                    Image.map_join_pages(cropped, fn page ->
                      Image.thumbnail(page, "400x400", crop: :attention)
                    end)
                  else
                    Image.thumbnail(cropped, "400x400", crop: :attention)
                  end

                case thumb_result do
                  {:ok, thumb} ->
                    write_opts =
                      if is_animated,
                        do: [suffix: ".webp", webp: [quality: 75, minimize_file_size: true]],
                        else: [suffix: ".webp", webp: [quality: 75]]

                    case Image.write(thumb, :memory, write_opts) do
                      {:ok, thumb_binary} ->
                        {:ok, "data:image/webp;base64,#{Base.encode64(thumb_binary)}"}

                      _ ->
                        {:error, :write_failed}
                    end

                  _ ->
                    {:error, :thumbnail_failed}
                end

              _ ->
                {:error, :crop_failed}
            end

          _ ->
            {:error, :image_load_failed}
        end

      _ ->
        {:error, :file_read_failed}
    end
  end

  defp generate_cropped_preview(_temp_path, _crop), do: {:error, :invalid_crop}
end
