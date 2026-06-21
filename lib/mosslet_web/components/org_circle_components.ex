defmodule MossletWeb.OrgCircleComponents do
  @moduledoc """
  Shared, org-type-agnostic function components for an org-scoped circle
  dashboard: the ZK Files panel, the Members roster (+ add-members composer), and
  the embedded encrypted Chat panel.

  Rendered by both `MossletWeb.BusinessLive.CircleShow` (Task #221) and
  `MossletWeb.FamilyLive.CircleShow` (Task #271). The crypto-sensitive markup
  (ZK hooks, sealed-key data attributes, transparency copy) lives here once, so
  it can't drift between surfaces. Domain LiveViews own everything that must stay
  separate — the page header, routes, labels, and feature set — and compose
  these components. The only route-coupled bit (`org_path`) is passed in as a
  plain string, so each LiveView's `~p` route sigil stays compile-time verified.
  """
  use Phoenix.Component

  import MossletWeb.CoreComponents, only: [phx_icon: 1]

  alias Phoenix.LiveView.JS
  alias Mosslet.Files
  alias MossletWeb.GroupLive.Group
  alias MossletWeb.GroupLive.GroupMessage.EditForm
  alias MossletWeb.OrgCircleSupport
  alias MossletWeb.OrgIdentity

  @doc """
  Unread `@mention` count badge for a circle (Task #280) — a small overlay chip
  meant to sit on top of a circle's icon (render it inside a `relative`-positioned
  container, mirroring the personal circles index badge).

  Surface-tinted to match the #279 mention pills: `:family` → rose, `:business`
  → indigo, `:personal` (default) → teal. Counts are server-authoritative and
  ZK-safe — derived from `GroupMessageMention` records (UUIDs the server already
  holds), never from ciphertext. Renders nothing when `count` is 0.
  """
  attr :count, :integer, required: true
  attr :variant, :atom, default: :personal, values: [:personal, :family, :business]
  attr :id, :string, default: nil

  def mention_badge(assigns) do
    ~H"""
    <span
      :if={@count > 0}
      id={@id}
      class={[
        "absolute -top-1 -right-1 flex h-5 min-w-5 items-center justify-center rounded-full px-1 text-[10px] font-bold text-white shadow-lg ring-2 ring-white dark:ring-slate-800",
        mention_badge_theme(@variant)
      ]}
      title="Unread @mentions"
    >
      {if @count > 9, do: "9+", else: @count}
    </span>
    """
  end

  defp mention_badge_theme(:family),
    do: "bg-gradient-to-br from-rose-500 to-pink-500 shadow-rose-500/30"

  defp mention_badge_theme(:business),
    do: "bg-gradient-to-br from-indigo-500 to-violet-500 shadow-indigo-500/30"

  defp mention_badge_theme(_personal),
    do: "bg-gradient-to-br from-teal-500 to-emerald-500 shadow-teal-500/30"

  @doc """
  ZK file sharing panel: upload (browser-encrypted), the file list (filenames
  decrypted in-place), the catch-up affordance (#232), and the mandatory
  who-can-read transparency surface (I4).
  """
  attr :shared_files, :list, required: true
  attr :can_catch_up?, :boolean, required: true
  attr :viewer_missing_files?, :boolean, required: true
  attr :current_user, :map, required: true
  attr :membership, :map, required: true

  def circle_files_panel(assigns) do
    ~H"""
    <section
      id="shared-files-panel"
      phx-hook="SharedFileHook"
      data-max-bytes={Files.max_size_bytes()}
      class="rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm p-5 space-y-4"
    >
      <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div class="min-w-0">
          <h2 class="flex items-center gap-2 text-base font-semibold text-slate-900 dark:text-slate-100">
            <.phx_icon name="hero-lock-closed" class="size-4 text-teal-500 dark:text-teal-400" />
            Files
          </h2>
          <p class="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
            Encrypted on your device and shared only with this circle. Mosslet can't read them.
          </p>
        </div>
        <div class="flex shrink-0 items-center gap-2">
          <button
            :if={@can_catch_up?}
            type="button"
            id="catch-up-button"
            phx-click="request_catch_up"
            phx-disable-with="Sharing…"
            phx-hook="TippyHook"
            data-tippy-content="Give members who joined later access to earlier files. Re-encrypted on your device — Mosslet still can't read them."
            class="inline-flex flex-1 cursor-pointer items-center justify-center gap-1.5 rounded-full border border-teal-200/80 dark:border-teal-700/60 bg-teal-50/80 dark:bg-teal-900/20 px-4 py-2 text-sm font-semibold text-teal-700 dark:text-teal-300 shadow-sm transition-all duration-200 hover:bg-teal-100/80 dark:hover:bg-teal-900/40 hover:shadow-md sm:flex-none"
          >
            <.phx_icon name="hero-sparkles" class="size-4" /> Catch up
          </button>
          <div :if={@can_catch_up?} id="catch-up-crypto" phx-hook="CircleCatchUpHook"></div>
          <span
            :if={@viewer_missing_files?}
            id="catch-up-viewer-missing-hint"
            phx-hook="TippyHook"
            data-tippy-content="Some files were shared before you joined. Ask an admin or the uploader to share them with you."
            class="inline-flex items-center gap-1.5 rounded-full border border-slate-200/80 dark:border-slate-700/60 bg-slate-50/80 dark:bg-slate-800/40 px-3 py-2 text-xs font-medium text-slate-500 dark:text-slate-400"
          >
            <.phx_icon name="hero-information-circle" class="size-4" /> Missing earlier files
          </span>
          <label
            for="shared-file-input"
            class="inline-flex flex-1 cursor-pointer items-center justify-center gap-1.5 rounded-full bg-gradient-to-r from-teal-500 to-emerald-600 px-4 py-2 text-sm font-semibold text-white shadow-sm shadow-emerald-500/25 transition-all duration-200 hover:shadow-md hover:shadow-emerald-500/30 sm:flex-none"
          >
            <.phx_icon name="hero-arrow-up-tray" class="size-4" /> Upload
            <input id="shared-file-input" type="file" data-shared-file-input class="sr-only" />
          </label>
        </div>
      </div>

      <ul role="list" class="divide-y divide-slate-100 dark:divide-slate-700/60">
        <li
          :for={file <- @shared_files}
          id={"shared-file-#{file.id}"}
          class="flex items-center justify-between gap-3 py-3"
        >
          <div class="flex min-w-0 items-center gap-3">
            <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/40 dark:to-emerald-900/30 text-teal-600 dark:text-teal-300 ring-1 ring-teal-500/10">
              <.phx_icon name="hero-document-text" class="size-5" />
            </div>
            <div class="min-w-0">
              <div
                :if={file.viewer_sealed_key && file.encrypted_filename}
                id={"decrypt-filename-#{file.id}"}
                phx-hook="DecryptSharedFileName"
                phx-update="ignore"
                data-sealed-file-key={file.viewer_sealed_key}
                data-encrypted-filename={file.encrypted_filename}
              >
                <p
                  data-shared-filename
                  class="truncate text-sm font-medium text-slate-900 dark:text-slate-100"
                >
                  Decrypting…
                </p>
              </div>
              <p
                :if={!(file.viewer_sealed_key && file.encrypted_filename)}
                class="truncate text-sm font-medium text-slate-900 dark:text-slate-100"
              >
                Encrypted file
              </p>
              <p class="mt-0.5 flex items-center gap-1.5 text-xs text-slate-500 dark:text-slate-400">
                <span>{OrgCircleSupport.format_size(file.size_bytes)}</span>
                <span aria-hidden="true">·</span>
                <span class="inline-flex items-center gap-1">
                  <.phx_icon name="hero-eye" class="size-3" /> {file.reader_count} can open
                </span>
              </p>
            </div>
          </div>
          <div class="flex shrink-0 items-center gap-1">
            <button
              type="button"
              data-download-shared-file={file.id}
              id={"download-#{file.id}"}
              phx-hook="TippyHook"
              data-tippy-content="Download & decrypt on your device"
              class="inline-flex items-center gap-1 rounded-full px-3 py-1.5 text-xs font-medium text-teal-600 dark:text-teal-400 transition-colors duration-200 hover:bg-teal-50 dark:hover:bg-teal-900/20"
            >
              <.phx_icon name="hero-arrow-down-tray" class="size-4" />
              <span class="hidden sm:inline">Download</span>
            </button>
            <button
              :if={OrgCircleSupport.can_delete_file?(file, @current_user, @membership)}
              type="button"
              phx-click="delete_shared_file"
              phx-value-id={file.id}
              id={"delete-#{file.id}"}
              phx-hook="TippyHook"
              data-tippy-content="Remove for everyone"
              data-confirm="Remove this file for everyone in the circle? Copies already downloaded can't be recalled."
              class="inline-flex items-center gap-1 rounded-full px-3 py-1.5 text-xs font-medium text-rose-500 transition-colors duration-200 hover:bg-rose-50 dark:hover:bg-rose-900/20 hover:text-rose-600"
            >
              <.phx_icon name="hero-trash" class="size-4" />
              <span class="hidden sm:inline">Remove</span>
            </button>
          </div>
        </li>
        <li :if={@shared_files == []} class="flex flex-col items-center gap-2 py-8 text-center">
          <div class="flex h-12 w-12 items-center justify-center rounded-2xl bg-slate-100 dark:bg-slate-700/50 text-slate-400 dark:text-slate-500">
            <.phx_icon name="hero-document-plus" class="size-6" />
          </div>
          <p class="text-sm font-medium text-slate-700 dark:text-slate-200">No files yet</p>
          <p class="max-w-xs text-xs text-slate-500 dark:text-slate-400">
            Upload a file to share it securely with this circle — it's encrypted on your device first.
          </p>
        </li>
      </ul>

      <div class="rounded-xl border border-teal-200/60 dark:border-teal-800/50 bg-gradient-to-br from-teal-50/80 to-emerald-50/50 dark:from-teal-900/20 dark:to-emerald-900/10 p-4">
        <div class="flex items-center gap-2">
          <.phx_icon name="hero-shield-check" class="size-4 text-teal-600 dark:text-teal-400" />
          <p class="text-sm font-semibold text-slate-900 dark:text-slate-100">
            Who can open these files
          </p>
        </div>
        <ul class="mt-2.5 space-y-2 text-xs leading-relaxed text-slate-600 dark:text-slate-300">
          <li class="flex items-start gap-2">
            <.phx_icon
              name="hero-users"
              class="mt-0.5 size-3.5 shrink-0 text-teal-500 dark:text-teal-400"
            /> Everyone in this circle. Each person unlocks them with their own key.
          </li>
          <li class="flex items-start gap-2">
            <.phx_icon
              name="hero-clock"
              class="mt-0.5 size-3.5 shrink-0 text-teal-500 dark:text-teal-400"
            /> New members see files shared after they join. Use the
            <span class="inline-flex items-center gap-1 rounded-md border border-teal-200/80 dark:border-teal-700/60 bg-teal-50 dark:bg-teal-900/40 px-1.5 py-0.5 align-baseline text-[11px] font-semibold text-teal-700 dark:text-teal-300">
              <.phx_icon name="hero-sparkles" class="size-3" /> Catch up
            </span>
            button to share earlier ones too.
          </li>
          <li class="flex items-start gap-2">
            <.phx_icon
              name="hero-trash"
              class="mt-0.5 size-3.5 shrink-0 text-teal-500 dark:text-teal-400"
            /> Removing a file revokes it for everyone — you can't recall copies already downloaded.
          </li>
        </ul>
      </div>
    </section>
    """
  end

  @doc """
  Members roster (scoped to this circle's confirmed members) + the ZK
  add-members composer (owner/admin only). `org_path` is the back-to-org path
  string used by the "Invite more people" hint.
  """
  attr :members, :list, required: true
  attr :member_count, :integer, required: true
  attr :addable_members, :list, required: true
  attr :can_manage_circle?, :boolean, required: true
  attr :show_add_members?, :boolean, required: true
  attr :can_leave_circle?, :boolean, required: true
  attr :current_user_id, :string, required: true
  attr :membership, :map, required: true
  attr :current_user_group, :map, default: nil
  attr :sealed_group_key, :string, default: nil
  attr :viewer_sealed_org_key, :string, default: nil
  attr :org_path, :string, required: true

  def circle_members_roster(assigns) do
    ~H"""
    <section
      id="circle-members-roster"
      phx-hook="OrgMembers"
      data-sealed-org-key={@viewer_sealed_org_key}
      data-current-user-id={@current_user_id}
      class="rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm p-5 space-y-4"
    >
      <div class="flex items-center justify-between gap-3">
        <div>
          <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">Members</h2>
          <p class="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
            {@member_count} {if @member_count == 1, do: "person", else: "people"} in this circle.
          </p>
        </div>
        <button
          :if={@can_manage_circle? && !@show_add_members? && @addable_members != []}
          type="button"
          phx-click="show_add_members"
          id="show-add-members-button"
          class="inline-flex cursor-pointer items-center gap-1.5 rounded-full bg-gradient-to-r from-teal-500 to-emerald-600 px-4 py-2 text-sm font-semibold text-white shadow-sm shadow-emerald-500/25 transition-all duration-200 hover:shadow-md hover:shadow-emerald-500/30"
        >
          <.phx_icon name="hero-user-plus" class="size-4" /> Add
        </button>
      </div>

      <ul role="list" class="divide-y divide-slate-100 dark:divide-slate-700/60">
        <li
          :for={member <- @members}
          id={"circle-member-#{member.user.id}"}
          class="py-2.5 flex items-center gap-3"
          data-org-member-row
          data-encrypted-display-name={member.encrypted_display_name}
          data-encrypted-org-avatar={member.encrypted_org_avatar}
        >
          <div class="relative flex h-9 w-9 shrink-0 items-center justify-center rounded-full overflow-hidden bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/40 dark:to-emerald-900/40 text-teal-600 dark:text-teal-300">
            <span data-org-avatar-fallback class="flex items-center justify-center">
              <.phx_icon name="hero-user" class="size-4" />
            </span>
            <img
              data-org-avatar-target
              hidden
              alt=""
              class="absolute inset-0 h-full w-full object-cover"
            />
          </div>
          <p class="min-w-0 text-sm font-medium text-slate-900 dark:text-slate-100 truncate">
            <span {OrgIdentity.org_name_target(member)}>
              {OrgIdentity.placeholder_label(member)}
            </span>
          </p>

          <div class="ml-auto flex shrink-0 items-center gap-2">
            <span
              :if={member.self?}
              class="rounded-full bg-slate-100 dark:bg-slate-700/60 px-2 py-0.5 text-[11px] font-medium text-slate-500 dark:text-slate-400"
            >
              You
            </span>
            <button
              :if={member.self? && @can_leave_circle?}
              type="button"
              phx-click="leave_circle"
              id="leave-circle-button"
              data-confirm="Leave this circle? You'll lose access to its chat and files. You can't recall copies already downloaded."
              class="text-xs font-medium text-rose-500 hover:text-rose-600"
            >
              Leave
            </button>
            <button
              :if={
                !member.self? &&
                  OrgCircleSupport.can_remove_member?(@membership, @current_user_group, member)
              }
              type="button"
              phx-click="remove_member"
              phx-value-user_id={member.user.id}
              id={"remove-member-#{member.user.id}"}
              data-confirm="Remove this person from the circle? They'll lose access to its chat and files. You can't recall copies already downloaded."
              class="text-xs font-medium text-rose-500 hover:text-rose-600"
            >
              Remove
            </button>
          </div>
        </li>
      </ul>

      <form
        :if={@can_manage_circle? && @show_add_members?}
        id="add-members-form"
        phx-hook="CircleAddMembersHook"
        data-sealed-group-key={@sealed_group_key}
        data-sealed-org-key={@viewer_sealed_org_key}
        class="rounded-xl border border-teal-200/60 dark:border-teal-800/50 bg-gradient-to-br from-teal-50/60 to-emerald-50/40 dark:from-teal-900/15 dark:to-emerald-900/10 p-4 space-y-3"
      >
        <div class="flex items-start gap-2.5">
          <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-white/70 dark:bg-slate-800/60 text-teal-600 dark:text-teal-300 shadow-sm">
            <.phx_icon name="hero-user-plus" class="size-4" />
          </div>
          <div>
            <p class="text-sm font-medium text-slate-900 dark:text-slate-100">
              Add people from your organization
            </p>
            <p class="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
              They'll join the chat and can read files shared <strong>after</strong> they join.
            </p>
          </div>
        </div>

        <ul
          role="list"
          class="max-h-56 overflow-y-auto rounded-lg border border-slate-200/60 dark:border-slate-700/60 bg-white/60 dark:bg-slate-900/30 divide-y divide-slate-100 dark:divide-slate-700/50"
        >
          <li
            :for={member <- @addable_members}
            id={"add-member-row-#{member.user.id}"}
            data-org-member-row
            data-encrypted-display-name={member.encrypted_display_name}
          >
            <label
              for={"add-member-#{member.user.id}"}
              class="flex items-center gap-3 cursor-pointer px-3 py-2.5 hover:bg-teal-50/60 dark:hover:bg-teal-900/15 transition-colors duration-150"
            >
              <input
                type="checkbox"
                id={"add-member-#{member.user.id}"}
                name="add_members[]"
                value={member.user.id}
                class="size-4 rounded border-slate-300 dark:border-slate-600 text-teal-600 focus:ring-teal-500 focus:ring-offset-0"
              />
              <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-slate-100 to-slate-200 dark:from-slate-700 dark:to-slate-600 text-slate-500 dark:text-slate-300">
                <.phx_icon name="hero-user" class="size-3.5" />
              </div>
              <span
                class="min-w-0 flex-1 text-sm text-slate-900 dark:text-slate-100 truncate"
                data-decrypt-org-name
              >
                {member.personal_name || "Org member"}
              </span>
            </label>
          </li>
        </ul>

        <div class="flex items-center justify-end gap-2">
          <button
            type="button"
            phx-click="hide_add_members"
            class="inline-flex items-center justify-center rounded-full px-4 py-2 text-sm font-medium text-slate-600 dark:text-slate-300 hover:bg-white/70 dark:hover:bg-slate-800/60 transition-colors duration-200"
          >
            Cancel
          </button>
          <button
            type="submit"
            id="add-members-submit"
            phx-disable-with="Adding…"
            class="inline-flex items-center gap-1.5 rounded-full bg-gradient-to-r from-teal-500 to-emerald-600 px-4 py-2 text-sm font-semibold text-white shadow-sm shadow-emerald-500/25 transition-all duration-200 hover:shadow-md hover:shadow-emerald-500/30"
          >
            <.phx_icon name="hero-check" class="size-4" /> Add to circle
          </button>
        </div>
      </form>

      <p
        :if={@can_manage_circle? && !@show_add_members? && @addable_members == []}
        class="text-xs text-slate-500 dark:text-slate-400"
      >
        Everyone in this organization is already in this circle.
        <.link
          navigate={@org_path}
          class="font-medium text-teal-600 dark:text-teal-400 hover:underline"
        >
          Invite more people
        </.link>
        to add them.
      </p>
    </section>
    """
  end

  @doc """
  Embedded ZK group chat panel (reused per circle), including the metadata
  decrypt hook, the message stream + composer, the edit-message live component,
  and the markdown guide modal. `current_page` flows to the chat list/composer.
  """
  attr :group, :map, required: true
  attr :current_user_group, :map, default: nil
  attr :messages, :any, required: true
  attr :messages_list, :list, required: true
  attr :current_scope, :map, required: true
  attr :scrolled_to_top, :string, required: true
  attr :group_metadata, :map, required: true
  attr :total_messages_count, :integer, required: true
  attr :message, :any, default: nil
  attr :show_markdown_guide, :boolean, default: false
  attr :current_page, :atom, required: true

  attr :viewer_sealed_org_key, :string,
    default: nil,
    doc: "the viewer's sealed org_key, so the chat can ZK-decrypt org display names"

  attr :org_display_names, :map,
    default: %{},
    doc: "user_id => encrypted org display name ciphertext, for org-mate recognition"

  attr :org_avatars, :map,
    default: %{},
    doc:
      "user_id => encrypted org avatar ciphertext (org_key-secretbox), for org-mate recognition"

  def circle_chat_panel(assigns) do
    ~H"""
    <section
      id="circle-chat-panel"
      class="rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm overflow-hidden"
    >
      <div class="flex items-center justify-between gap-3 px-5 py-4 border-b border-slate-200/60 dark:border-slate-700/60">
        <div>
          <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">Chat</h2>
          <p class="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
            End-to-end encrypted. {@total_messages_count} message{if @total_messages_count != 1,
              do: "s"}.
          </p>
        </div>
        <span class="relative flex h-2.5 w-2.5" title="Live">
          <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
          <span class="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-500"></span>
        </span>
      </div>

      <div
        id="circle-chat-metadata"
        phx-hook="DecryptGroupMetadata"
        data-sealed-group-key={@group_metadata[:sealed_group_key]}
        data-encrypted-name={@group_metadata[:encrypted_name]}
        data-encrypted-moniker={@group_metadata[:encrypted_moniker]}
        data-browser-decrypt={@group_metadata[:browser_decrypt?]}
      >
      </div>

      <div class="h-[32rem] flex flex-col">
        <Group.show
          :if={@current_user_group}
          messages={@messages}
          messages_list={@messages_list}
          current_scope={@current_scope}
          group={@group}
          user_group={@current_user_group}
          scrolled_to_top={@scrolled_to_top}
          current_page={@current_page}
          viewer_sealed_org_key={@viewer_sealed_org_key}
          org_display_names={@org_display_names}
          org_avatars={@org_avatars}
        />
      </div>

      <.live_component
        module={EditForm}
        message={@message}
        id="message-edit-form"
        current_scope={@current_scope}
        user_group_key={if(@current_user_group, do: @current_user_group.key)}
        public?={@group.public?}
      />

      <MossletWeb.PrivacyComponents.liquid_markdown_guide_modal
        id="markdown-guide-modal"
        show={@show_markdown_guide}
        on_cancel={JS.push("close_markdown_guide")}
      />
    </section>
    """
  end
end
