defmodule MossletWeb.AnnouncementComponents do
  @moduledoc """
  Shared UI for the two-tier ZK announcements feature (Task #229c), used by both
  the org dashboard (`BusinessLive.Show`, org tier) and the circle page
  (`BusinessLive.CircleShow`, circle tier).

  The panel renders identically for both tiers; only the encryption key and the
  authoring authority differ. The host LiveView supplies:

    * `tier` — `:org` or `:circle` (selects the key-tier the JS hooks read).
    * `sealed_key` — the viewer's sealed key for this tier (the per-org `org_key`
      = `Membership.key` for `:org`; the circle `group_key` = the viewer's
      `UserGroup.key` for `:circle`). Used by both the write hook
      (`AnnouncementFormHook`) and the read hook (`DecryptAnnouncement`).
    * `can_post?` — whether the viewer may author/manage announcements in this
      tier (server-authoritative; re-checked on every write).

  Titles/bodies are decrypted browser-side via `DecryptAnnouncement`; the server
  never sees plaintext or keys (ZK / I2/I3). The host LiveView handles the
  `save_announcement` / `delete_announcement` / form-toggle events.
  """
  use Phoenix.Component

  import MossletWeb.CoreComponents
  import MossletWeb.DesignSystem

  @doc """
  The full announcements panel: a pinned banner (if any), the compose affordance
  (gated by `can_post?`), and the "Recent" list. ZK throughout.
  """
  attr :tier, :atom, required: true
  attr :sealed_key, :string, default: nil
  attr :can_post?, :boolean, default: false
  attr :show_form?, :boolean, default: false
  attr :form, :map, required: true
  attr :banner, :map, default: nil
  attr :recent, :list, default: []
  attr :unread_count, :integer, default: 0
  attr :current_user_id, :string, required: true

  def announcements_panel(assigns) do
    ~H"""
    <section
      id={"announcements-#{@tier}"}
      class="rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm p-5 space-y-4"
    >
      <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div class="min-w-0">
          <h2 class="flex items-center gap-2 text-base font-semibold text-slate-900 dark:text-slate-100">
            <.phx_icon name="hero-megaphone" class="size-4 text-teal-500 dark:text-teal-400" />
            Announcements
            <span
              :if={@unread_count > 0}
              id={"announcements-#{@tier}-unread"}
              class="inline-flex items-center rounded-full bg-rose-100 dark:bg-rose-900/40 px-2 py-0.5 text-[11px] font-semibold text-rose-700 dark:text-rose-300"
            >
              {@unread_count} new
            </span>
          </h2>
          <p class="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
            {announcement_blurb(@tier)} Encrypted on each member's device — Mosslet can't read them.
          </p>
        </div>
        <div class="flex shrink-0 items-center gap-2">
          <button
            :if={@unread_count > 0}
            type="button"
            phx-click="mark_announcements_read"
            id={"announcements-#{@tier}-mark-read"}
            class="text-xs font-medium text-teal-600 dark:text-teal-400 hover:underline"
          >
            Mark all read
          </button>
          <.liquid_button
            :if={@can_post? && !@show_form?}
            phx-click="show_announcement_form"
            id={"new-announcement-#{@tier}-button"}
            color="emerald"
            size="sm"
            icon="hero-plus"
          >
            New
          </.liquid_button>
        </div>
      </div>

      <%!-- Compose (ZK write path). Title/body are encrypted browser-side with
           the tier's key by AnnouncementFormHook before "save_announcement" is
           pushed; the .form phx-submit is the no-crypto fallback (refused). --%>
      <.form
        :if={@can_post? && @show_form?}
        for={@form}
        id={"announcement-form-#{@tier}"}
        phx-submit="create_announcement"
        phx-hook="AnnouncementFormHook"
        data-key-tier={key_tier(@tier)}
        data-sealed-org-key={@tier == :org && @sealed_key}
        data-sealed-group-key={@tier == :circle && @sealed_key}
        class="rounded-xl border border-slate-200/60 dark:border-slate-700/60 bg-gradient-to-br from-slate-50/80 to-slate-100/50 dark:from-slate-800/50 dark:to-slate-900/30 p-4 space-y-4"
      >
        <.phx_input
          field={@form[:title]}
          name="announcement[title]"
          type="text"
          label="Title (optional)"
          placeholder="e.g. Office closed Friday"
          maxlength="160"
        />
        <div>
          <label
            for={"announcement-body-#{@tier}"}
            class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5"
          >
            Announcement
          </label>
          <textarea
            id={"announcement-body-#{@tier}"}
            name="announcement[body]"
            rows="4"
            maxlength="5000"
            required
            placeholder="What would you like your team to know?"
            class="block w-full rounded-xl border border-slate-300 dark:border-slate-600 dark:bg-slate-700 text-sm text-slate-900 dark:text-slate-100 placeholder:text-slate-400 focus:border-teal-500 focus:ring-teal-500/30"
          ></textarea>
        </div>

        <div class="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
          <label class="inline-flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              name="announcement[priority]"
              value="pinned"
              class="size-4 rounded border-slate-300 dark:border-slate-600 text-teal-600 focus:ring-teal-500 focus:ring-offset-0"
            />
            <span class="text-sm text-slate-700 dark:text-slate-300">
              Pin as a highlighted banner
            </span>
          </label>
          <div>
            <label
              for={"announcement-expires-#{@tier}"}
              class="block text-xs font-medium text-slate-500 dark:text-slate-400 mb-1"
            >
              Auto-hide after (optional)
            </label>
            <input
              type="datetime-local"
              id={"announcement-expires-#{@tier}"}
              name="announcement[expires_at]"
              class="rounded-lg border-slate-300 dark:border-slate-600 dark:bg-slate-700 text-xs py-1.5 focus:border-teal-500 focus:ring-teal-500/30"
            />
          </div>
        </div>

        <div class="flex flex-col-reverse gap-2 sm:flex-row sm:items-center sm:justify-end">
          <.liquid_button
            type="button"
            variant="ghost"
            color="slate"
            phx-click="hide_announcement_form"
          >
            Cancel
          </.liquid_button>
          <.liquid_button
            type="submit"
            id={"announcement-submit-#{@tier}"}
            color="emerald"
            icon="hero-paper-airplane"
            phx-disable-with="Posting…"
          >
            Post announcement
          </.liquid_button>
        </div>
      </.form>

      <%!-- Pinned banner: the single most-recent pinned announcement, rendered
           prominently. ZK — title/body decrypt browser-side. --%>
      <.announcement_card
        :if={@banner}
        announcement={@banner}
        tier={@tier}
        sealed_key={@sealed_key}
        can_manage={@can_post? || @banner.author_id == @current_user_id}
        variant={:banner}
      />

      <div :if={@recent != []} class="space-y-2">
        <h3 class="text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
          Recent
        </h3>
        <ul role="list" class="space-y-2">
          <.announcement_card
            :for={announcement <- @recent}
            announcement={announcement}
            tier={@tier}
            sealed_key={@sealed_key}
            can_manage={@can_post? || announcement.author_id == @current_user_id}
            variant={:recent}
          />
        </ul>
      </div>

      <p
        :if={is_nil(@banner) && @recent == [] && !@show_form?}
        class="text-xs text-slate-500 dark:text-slate-400"
      >
        No announcements yet.{if @can_post?, do: " Post one to keep your team in the loop.", else: ""}
      </p>
    </section>
    """
  end

  # A single announcement, shared by the banner + recent variants. The title/body
  # stay encrypted and decrypt browser-side via DecryptAnnouncement (ZK). The
  # delete affordance is shown to the author or a tier manager (`can_manage`);
  # the server re-checks authority on the write.
  attr :announcement, :map, required: true
  attr :tier, :atom, required: true
  attr :sealed_key, :string, default: nil
  attr :can_manage, :boolean, default: false
  attr :variant, :atom, default: :recent

  defp announcement_card(assigns) do
    ~H"""
    <li
      :if={@variant == :recent}
      id={"announcement-#{@announcement.id}"}
      class="rounded-xl border border-slate-200/60 dark:border-slate-700/60 bg-white/70 dark:bg-slate-800/50 p-4"
    >
      <.announcement_body
        announcement={@announcement}
        tier={@tier}
        sealed_key={@sealed_key}
        can_manage={@can_manage}
        pinned={false}
      />
    </li>
    <div
      :if={@variant == :banner}
      id={"announcement-#{@announcement.id}"}
      class="rounded-xl border border-teal-200/70 dark:border-teal-800/50 bg-gradient-to-br from-teal-50/80 to-emerald-50/50 dark:from-teal-900/20 dark:to-emerald-900/10 p-4"
    >
      <.announcement_body
        announcement={@announcement}
        tier={@tier}
        sealed_key={@sealed_key}
        can_manage={@can_manage}
        pinned={true}
      />
    </div>
    """
  end

  attr :announcement, :map, required: true
  attr :tier, :atom, required: true
  attr :sealed_key, :string, default: nil
  attr :can_manage, :boolean, default: false
  attr :pinned, :boolean, default: false

  defp announcement_body(assigns) do
    ~H"""
    <div
      id={"decrypt-announcement-#{@announcement.id}"}
      phx-hook="DecryptAnnouncement"
      phx-update="ignore"
      data-key-tier={key_tier(@tier)}
      data-sealed-org-key={@tier == :org && @sealed_key}
      data-sealed-group-key={@tier == :circle && @sealed_key}
      data-encrypted-title={@announcement.encrypted_title}
      data-encrypted-body={@announcement.encrypted_body}
    >
      <div class="flex items-start justify-between gap-3">
        <div class="min-w-0 flex-1">
          <span
            :if={@pinned}
            class="inline-flex items-center gap-1 rounded-full bg-teal-100 dark:bg-teal-900/40 px-2 py-0.5 text-[11px] font-semibold text-teal-700 dark:text-teal-300 mb-1"
          >
            <.phx_icon name="hero-bookmark" class="size-3" /> Pinned
          </span>
          <p
            :if={@announcement.encrypted_title}
            data-decrypt-announcement-title
            class="text-sm font-semibold text-slate-900 dark:text-slate-100"
          >
            Encrypted announcement
          </p>
          <p
            data-decrypt-announcement-body
            class="mt-1 text-sm text-slate-700 dark:text-slate-300 whitespace-pre-wrap break-words"
          >
            Decrypting…
          </p>
        </div>
      </div>
      <div class="mt-2 flex items-center justify-between gap-2">
        <p class="text-[11px] text-slate-400 dark:text-slate-500">
          {format_posted_at(@announcement.inserted_at)}
        </p>
        <button
          :if={@can_manage}
          type="button"
          phx-click="delete_announcement"
          phx-value-id={@announcement.id}
          id={"delete-announcement-#{@announcement.id}"}
          data-confirm="Delete this announcement for everyone?"
          class="text-[11px] font-medium text-rose-500 hover:text-rose-600"
        >
          Delete
        </button>
      </div>
    </div>
    """
  end

  defp key_tier(:org), do: "org"
  defp key_tier(:circle), do: "group"

  defp announcement_blurb(:org),
    do: "Org-wide notices from your owner and admins."

  defp announcement_blurb(:circle),
    do: "Notices from this circle's leads."

  defp format_posted_at(%NaiveDateTime{} = dt),
    do: Calendar.strftime(dt, "%b %-d, %Y")

  defp format_posted_at(%DateTime{} = dt),
    do: Calendar.strftime(dt, "%b %-d, %Y")

  defp format_posted_at(_), do: ""
end
