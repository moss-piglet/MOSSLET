defmodule MossletWeb.FamilyComponents do
  @moduledoc """
  Shared UI components for the Family (guardianship) feature.

  Includes role badges, the always-visible managed-member transparency panel
  (I2 — mandatory), and guardianship status pills. See
  `docs/GUARDIANSHIP_DESIGN.md`.
  """
  use Phoenix.Component
  use MossletWeb, :verified_routes

  import MossletWeb.CoreComponents, only: [phx_icon: 1]

  attr :role, :atom, required: true

  def family_role_badge(assigns) do
    {label, classes} =
      case assigns.role do
        :admin ->
          {"Admin", "bg-indigo-100 text-indigo-700 dark:bg-indigo-900/30 dark:text-indigo-300"}

        :guardian ->
          {"Guardian", "bg-teal-100 text-teal-700 dark:bg-teal-900/30 dark:text-teal-300"}

        :managed_member ->
          {"Managed", "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300"}

        _ ->
          {"Member", "bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"}
      end

    assigns = assign(assigns, label: label, classes: classes)

    ~H"""
    <span class={[
      "inline-flex items-center rounded-full px-2 py-0.5 text-[11px] font-medium",
      @classes
    ]}>
      {@label}
    </span>
    """
  end

  attr :status, :atom, required: true

  def guardianship_status_pill(assigns) do
    {label, classes} =
      case assigns.status do
        :active ->
          {"Active",
           "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-300"}

        :pending ->
          {"Pending consent",
           "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300"}

        :paused ->
          {"Paused", "bg-slate-200 text-slate-600 dark:bg-slate-700 dark:text-slate-300"}

        :declined ->
          {"Declined", "bg-rose-100 text-rose-700 dark:bg-rose-900/30 dark:text-rose-300"}

        _ ->
          {"Unknown", "bg-slate-100 text-slate-600"}
      end

    assigns = assign(assigns, label: label, classes: classes)

    ~H"""
    <span class={[
      "inline-flex items-center rounded-full px-2 py-0.5 text-[11px] font-medium",
      @classes
    ]}>
      {@label}
    </span>
    """
  end

  @doc """
  Always-visible transparency panel for a managed member (I2 — mandatory).

  Shows exactly who can read the member's content, at all times. Non-dismissible.
  `guardianships` is a list of `%{guardianship, guardian_name}` maps for the
  current managed-member viewer.
  """
  attr :guardianships, :list, required: true
  attr :class, :string, default: ""

  def transparency_panel(assigns) do
    ~H"""
    <div
      id="guardian-transparency-panel"
      phx-hook="DecryptComposerGuardians"
      class={[
        "rounded-2xl border border-teal-200/70 dark:border-teal-800/40 bg-teal-50/80 dark:bg-teal-900/15 p-4",
        @class
      ]}
    >
      <div class="flex items-start gap-2.5">
        <.phx_icon
          name="hero-eye"
          class="size-5 text-teal-600 dark:text-teal-400 flex-shrink-0 mt-0.5"
        />
        <div class="min-w-0">
          <h3 class="text-sm font-semibold text-teal-900 dark:text-teal-100">
            Who can read what you share here
          </h3>
          <p class="mt-1 text-xs text-teal-800/90 dark:text-teal-200/80">
            Your guardians can read posts and conversations you create in Mosslet, using their own
            private key. Mosslet's servers can't read them.
          </p>

          <ul class="mt-3 space-y-1.5">
            <li
              :for={item <- @guardianships}
              class="flex items-center justify-between gap-2 text-xs text-teal-900 dark:text-teal-100"
            >
              <div class="flex items-center gap-2 min-w-0">
                <.phx_icon
                  name="hero-user"
                  class="size-3.5 text-teal-600 dark:text-teal-400 flex-shrink-0"
                />
                <span
                  class="font-medium truncate"
                  data-guardian-name
                  data-sealed-org-key={item[:sealed_org_key]}
                  data-encrypted-display-name={item[:encrypted_display_name]}
                >{item.guardian_name}</span>
                <span class="text-teal-700/80 dark:text-teal-300/70 truncate">
                  <%= if item.guardianship.status == :active do %>
                    — can read your future posts &amp; conversations
                  <% else %>
                    — paused (no new content is shared)
                  <% end %>
                </span>
              </div>

              <%!-- The managed member's own privacy toggle (DESIGN §0): pause to
                    stop sharing NEW content, resume to share again. Past content
                    can't be un-shared, so there is no "revoke" here — pausing is
                    the honest, reversible control. --%>
              <button
                :if={item.guardianship.status == :active}
                type="button"
                phx-click="pause_guardianship"
                phx-value-id={item.guardianship.id}
                id={"pause-guardianship-#{item.guardianship.id}"}
                class="inline-flex shrink-0 items-center gap-1 rounded-full border border-teal-300/70 dark:border-teal-700/60 bg-white/70 dark:bg-teal-900/30 px-2.5 py-1 text-[11px] font-medium text-teal-700 dark:text-teal-200 transition-colors hover:bg-teal-100/80 dark:hover:bg-teal-800/40 focus:outline-none focus:ring-2 focus:ring-teal-500/40"
              >
                <.phx_icon name="hero-pause" class="size-3" /> Pause sharing
              </button>
              <button
                :if={item.guardianship.status == :paused}
                type="button"
                phx-click="resume_guardianship"
                phx-value-id={item.guardianship.id}
                id={"resume-guardianship-#{item.guardianship.id}"}
                class="inline-flex shrink-0 items-center gap-1 rounded-full border border-teal-300/70 dark:border-teal-700/60 bg-white/70 dark:bg-teal-900/30 px-2.5 py-1 text-[11px] font-medium text-teal-700 dark:text-teal-200 transition-colors hover:bg-teal-100/80 dark:hover:bg-teal-800/40 focus:outline-none focus:ring-2 focus:ring-teal-500/40"
              >
                <.phx_icon name="hero-play" class="size-3" /> Resume sharing
              </button>
            </li>
          </ul>

          <p class="mt-3 text-[11px] text-teal-700/80 dark:text-teal-300/70">
            Pausing stops sharing <strong>new</strong>
            content with a guardian. Things you already shared stay shared — that can't be undone.
          </p>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Compact composer chip shown when a guardian will be a recipient of the post
  being written (I2 — no surprise at authorship time).

  Each guardian entry is either `%{name: "..."}` (a guardian who is also a
  personal connection, so the server can decrypt the name) or
  `%{sealed_org_key: ..., encrypted_display_name: ...}` (no personal connection —
  the browser resolves the name via the family `org_key`, Task #225/#270). The
  `DecryptComposerGuardians` hook fills the ZK entries in-place. The "(guardian)"
  role suffix is always shown; only the NAME resolves.
  """
  attr :guardian_entries, :list, required: true
  attr :class, :string, default: ""

  def composer_guardian_chip(assigns) do
    ~H"""
    <div
      :if={@guardian_entries != []}
      id="composer-guardian-chip"
      phx-hook="DecryptComposerGuardians"
      class={[
        "inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-[11px] font-medium",
        "bg-teal-100 text-teal-700 dark:bg-teal-900/30 dark:text-teal-300",
        @class
      ]}
    >
      <.phx_icon name="hero-eye" class="size-3" />
      <span>
        Also shared with
        <%= for {entry, idx} <- Enum.with_index(@guardian_entries) do %>
          <span :if={idx > 0}>, </span><span
            data-guardian-name
            data-sealed-org-key={entry[:sealed_org_key]}
            data-encrypted-display-name={entry[:encrypted_display_name]}
          >{entry[:name] || "your guardian"}</span>
        <% end %>
        (guardian)
      </span>
    </div>
    """
  end
end
