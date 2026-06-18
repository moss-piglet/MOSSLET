defmodule MossletWeb.PinComponents do
  @moduledoc """
  Shared UI for dashboard pinning (Task #229d), rendered atop the business org
  dashboard (`BusinessLive.Show`).

  A "Pinned" strip surfaces two groups of quick-access shortcuts:

    * `org_shared` — curated by the org owner/admin, visible to the whole org
      (a small "Team" badge).
    * `personal` — the viewer's own private pins.

  Each pin is one of three `pin_type`s:

    * `:circle` / `:file` — store only a target FK; the NAME is reused from the
      already-decrypted client-side render (`DecryptGroupMetadata` /
      `DecryptSharedFileName`) — no new ciphertext.
    * `:link` — a free URL whose label + URL decrypt browser-side via `DecryptPin`
      with the viewer's `user_key` (personal) or the per-org `org_key`
      (org-wide). The server never sees plaintext or keys (ZK / I2/I3).

  The host LiveView resolves each pin into a view-model (see
  `BusinessLive.Show`'s `resolve_pins/*`) and handles the
  `save_pin_link` / `remove_pin` / `reorder_pins` / form-toggle events.
  """
  use Phoenix.Component

  import MossletWeb.CoreComponents
  import MossletWeb.DesignSystem

  @doc """
  The full pinned strip: the org-wide (shared) pins, the viewer's personal pins,
  and the "Add link" affordance. ZK throughout.
  """
  attr :org, :map, required: true
  attr :sealed_org_key, :string, default: nil
  attr :org_shared_pins, :list, default: []
  attr :personal_pins, :list, default: []
  attr :can_manage_org_pins?, :boolean, default: false
  attr :can_pin_personal?, :boolean, default: false
  attr :show_pin_form?, :boolean, default: false
  attr :pin_form, :map, required: true
  attr :pin_form_scope, :atom, default: :personal

  def pinned_strip(assigns) do
    ~H"""
    <section
      :if={
        @org_shared_pins != [] or @personal_pins != [] or @can_pin_personal? or
          @can_manage_org_pins?
      }
      id="dashboard-pins"
      class="rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm p-5 space-y-4"
    >
      <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div class="min-w-0">
          <h2 class="flex items-center gap-2 text-base font-semibold text-slate-900 dark:text-slate-100">
            <.phx_icon name="hero-bookmark" class="size-4 text-teal-500 dark:text-teal-400" /> Pinned
          </h2>
          <p class="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
            Quick access to your circles, files, and links. Link names are encrypted on your device.
          </p>
        </div>
        <div class="flex shrink-0 items-center gap-2">
          <.liquid_button
            :if={!@show_pin_form?}
            phx-click="show_pin_form"
            id="add-pin-link-button"
            color="emerald"
            size="sm"
            icon="hero-link"
          >
            Add link
          </.liquid_button>
        </div>
      </div>

      <%!-- Add-link compose (ZK write path). Label + URL are encrypted browser-side
           by PinLinkFormHook with the user_key (personal) or org_key (org-wide)
           before "save_pin_link" is pushed; the .form phx-submit is the
           no-crypto fallback (refused). --%>
      <.form
        :if={@show_pin_form?}
        for={@pin_form}
        id="pin-link-form"
        phx-submit="create_pin_link"
        phx-hook="PinLinkFormHook"
        data-pin-scope={to_string(@pin_form_scope)}
        data-sealed-org-key={@pin_form_scope == :org_shared && @sealed_org_key}
        class="rounded-xl border border-slate-200/60 dark:border-slate-700/60 bg-gradient-to-br from-slate-50/80 to-slate-100/50 dark:from-slate-800/50 dark:to-slate-900/30 p-4 space-y-4"
      >
        <.phx_input
          field={@pin_form[:label]}
          name="pin[label]"
          type="text"
          label="Label"
          placeholder="e.g. Team handbook"
          maxlength="120"
        />
        <.phx_input
          field={@pin_form[:url]}
          name="pin[url]"
          type="url"
          label="Link"
          placeholder="https://…"
          maxlength="2000"
        />

        <%!-- Scope toggle (org owner/admin only): a personal pin (private) vs an
             org-wide pin everyone sees. The hidden input pins the value the JS
             hook reads; the server re-checks authority on write (I1). --%>
        <div :if={@can_manage_org_pins?} class="flex items-center gap-4">
          <label class="inline-flex items-center gap-2 cursor-pointer">
            <input
              type="radio"
              name="pin[scope]"
              value="personal"
              checked={@pin_form_scope != :org_shared}
              phx-click="set_pin_form_scope"
              phx-value-scope="personal"
              class="size-4 border-slate-300 dark:border-slate-600 text-teal-600 focus:ring-teal-500"
            />
            <span class="text-sm text-slate-700 dark:text-slate-300">Just for me</span>
          </label>
          <label class="inline-flex items-center gap-2 cursor-pointer">
            <input
              type="radio"
              name="pin[scope]"
              value="org_shared"
              checked={@pin_form_scope == :org_shared}
              phx-click="set_pin_form_scope"
              phx-value-scope="org_shared"
              class="size-4 border-slate-300 dark:border-slate-600 text-teal-600 focus:ring-teal-500"
            />
            <span class="text-sm text-slate-700 dark:text-slate-300">Share with the team</span>
          </label>
        </div>

        <div class="flex flex-col-reverse gap-2 sm:flex-row sm:items-center sm:justify-end">
          <.liquid_button type="button" variant="ghost" color="slate" phx-click="hide_pin_form">
            Cancel
          </.liquid_button>
          <.liquid_button
            type="submit"
            id="pin-link-submit"
            color="emerald"
            icon="hero-bookmark"
            phx-disable-with="Pinning…"
          >
            Pin link
          </.liquid_button>
        </div>
      </.form>

      <%!-- Team (org-wide) pins, grouped by type so circles, files, and links
           each cluster together for fast scanning. Reorderable within a type
           group by an owner/admin (PinsReorderHook). --%>
      <.pin_scope_group
        :if={@org_shared_pins != []}
        scope={:org_shared}
        heading="Team"
        heading_class="text-teal-700 dark:text-teal-300"
        heading_icon="hero-user-group"
        pins={@org_shared_pins}
        reorderable?={@can_manage_org_pins?}
        org={@org}
        sealed_org_key={@sealed_org_key}
      />

      <%!-- Personal pins, grouped by type. Always reorderable by their owner. --%>
      <.pin_scope_group
        :if={@personal_pins != []}
        scope={:personal}
        heading={(@org_shared_pins != [] && "Yours") || nil}
        heading_class="text-slate-500 dark:text-slate-400"
        heading_icon={nil}
        pins={@personal_pins}
        reorderable?={true}
        org={@org}
        sealed_org_key={@sealed_org_key}
      />

      <p
        :if={@org_shared_pins == [] && @personal_pins == [] && !@show_pin_form?}
        class="text-xs text-slate-500 dark:text-slate-400"
      >
        Nothing pinned yet. Pin a circle or file from below, or add a link.
      </p>
    </section>
    """
  end

  # One scope's pins (Team or Yours), grouped into circle / file / link clusters
  # so each type is easy to find. Each non-empty cluster is its own reorderable
  # list (drag permutes order within that type only).
  attr :scope, :atom, required: true
  attr :heading, :any, default: nil
  attr :heading_class, :string, default: nil
  attr :heading_icon, :any, default: nil
  attr :pins, :list, required: true
  attr :reorderable?, :boolean, default: false
  attr :org, :map, required: true
  attr :sealed_org_key, :string, default: nil

  defp pin_scope_group(assigns) do
    grouped = Enum.group_by(assigns.pins, & &1.pin.pin_type)

    assigns =
      assign(assigns,
        circle_pins: Map.get(grouped, :circle, []),
        file_pins: Map.get(grouped, :file, []),
        link_pins: Map.get(grouped, :link, [])
      )

    ~H"""
    <div class="space-y-2.5">
      <h3
        :if={@heading}
        class={[
          "flex items-center gap-1.5 text-xs font-semibold uppercase tracking-wide",
          @heading_class
        ]}
      >
        <.phx_icon :if={@heading_icon} name={@heading_icon} class="size-3.5" />{@heading}
      </h3>

      <.pin_type_cluster
        :if={@circle_pins != []}
        scope={@scope}
        type={:circle}
        label="Circles"
        icon="hero-chat-bubble-left-right"
        pins={@circle_pins}
        reorderable?={@reorderable?}
        org={@org}
        sealed_org_key={@sealed_org_key}
      />
      <.pin_type_cluster
        :if={@file_pins != []}
        scope={@scope}
        type={:file}
        label="Files"
        icon="hero-document"
        pins={@file_pins}
        reorderable?={@reorderable?}
        org={@org}
        sealed_org_key={@sealed_org_key}
      />
      <.pin_type_cluster
        :if={@link_pins != []}
        scope={@scope}
        type={:link}
        label="Links"
        icon="hero-link"
        pins={@link_pins}
        reorderable?={@reorderable?}
        org={@org}
        sealed_org_key={@sealed_org_key}
      />
    </div>
    """
  end

  # One type cluster (e.g. the circles within "Team"): a tiny muted label + the
  # chips. The chips share a type accent (see pin_chip); the label adds a textual
  # cue. The <ul> is the reorder unit (PinsReorderHook permutes within the type).
  attr :scope, :atom, required: true
  attr :type, :atom, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :pins, :list, required: true
  attr :reorderable?, :boolean, default: false
  attr :org, :map, required: true
  attr :sealed_org_key, :string, default: nil

  defp pin_type_cluster(assigns) do
    ~H"""
    <div class="space-y-1">
      <p class={[
        "flex items-center gap-1 text-[10px] font-medium uppercase tracking-wide",
        cluster_label_class(@type)
      ]}>
        <.phx_icon name={@icon} class="size-3" />{@label}
      </p>
      <ul
        id={"pins-#{@scope}-#{@type}"}
        phx-hook={@reorderable? && "PinsReorderHook"}
        data-pin-scope={to_string(@scope)}
        role="list"
        class="flex flex-wrap gap-2"
      >
        <.pin_chip
          :for={resolved <- @pins}
          resolved={resolved}
          org={@org}
          sealed_org_key={@sealed_org_key}
        />
      </ul>
    </div>
    """
  end

  defp cluster_label_class(:circle), do: "text-teal-600/80 dark:text-teal-400/80"
  defp cluster_label_class(:file), do: "text-violet-600/80 dark:text-violet-400/80"
  defp cluster_label_class(:link), do: "text-amber-600/80 dark:text-amber-400/80"

  # A pinned circle's icon matches its classification (#229b): official
  # department/team circles use the business icon; community circles use the
  # chat bubble — mirroring the circle cards in the dashboard's circles panel.
  defp circle_pin_icon(:team), do: "hero-building-office-2"
  defp circle_pin_icon(_), do: "hero-chat-bubble-left-right"

  # A single pin chip. Each pin_type gets its own accent (icon + token + border)
  # so circles, files, and links are distinguishable at a glance:
  #   * circle — teal chat bubble
  #   * file   — violet document
  #   * link   — amber link
  # Circle/file reuse the existing decrypt hooks (FK-only, no new ciphertext);
  # link decrypts its own label/URL via DecryptPin. The remove (x) is shown to
  # whoever may manage the pin.
  attr :resolved, :map, required: true
  attr :org, :map, required: true
  attr :sealed_org_key, :string, default: nil

  defp pin_chip(%{resolved: %{pin: %{pin_type: :link}}} = assigns) do
    ~H"""
    <li
      id={"pin-#{@resolved.pin.id}"}
      data-pin-id={@resolved.pin.id}
      class={["group", chip_class(:link)]}
    >
      <span class={chip_token_class(:link)}>
        <.phx_icon name="hero-link" class="size-3.5" />
      </span>
      <span
        id={"decrypt-pin-#{@resolved.pin.id}"}
        phx-hook="DecryptPin"
        phx-update="ignore"
        data-pin-scope={to_string(@resolved.pin.scope)}
        data-sealed-org-key={@resolved.pin.scope == :org_shared && @sealed_org_key}
        data-encrypted-label={@resolved.pin.encrypted_label}
        data-encrypted-url={@resolved.pin.encrypted_url}
        class="min-w-0"
      >
        <a
          data-decrypt-pin-url
          href="#"
          target="_blank"
          rel="noopener noreferrer"
          class="block truncate text-sm font-medium text-slate-700 dark:text-slate-200 hover:text-amber-700 dark:hover:text-amber-300"
        >
          <span data-decrypt-pin-label>Encrypted link</span>
        </a>
      </span>
      <.pin_badge_and_remove resolved={@resolved} />
    </li>
    """
  end

  defp pin_chip(%{resolved: %{pin: %{pin_type: :circle}}} = assigns) do
    ~H"""
    <li
      id={"pin-#{@resolved.pin.id}"}
      data-pin-id={@resolved.pin.id}
      data-hook-scope={"pin-circle-#{@resolved.pin.id}"}
      class={["group", chip_class(:circle)]}
    >
      <span class={chip_token_class(:circle)}>
        <.phx_icon name={circle_pin_icon(@resolved[:org_circle_type])} class="size-3.5" />
      </span>
      <span
        id={"decrypt-pin-circle-#{@resolved.pin.id}"}
        phx-hook="DecryptGroupMetadata"
        data-sealed-group-key={@resolved.sealed_key}
        data-encrypted-name={@resolved.label_ciphertext}
        data-scope-id={"pin-circle-#{@resolved.pin.id}"}
      ></span>
      <.link navigate={@resolved.navigate} class="min-w-0">
        <span
          data-decrypt-group-name
          class="block truncate text-sm font-medium text-slate-700 dark:text-slate-200 group-hover:text-teal-700 dark:group-hover:text-teal-300"
        >
          Circle
        </span>
      </.link>
      <.pin_badge_and_remove resolved={@resolved} />
    </li>
    """
  end

  defp pin_chip(%{resolved: %{pin: %{pin_type: :file}}} = assigns) do
    ~H"""
    <li
      id={"pin-#{@resolved.pin.id}"}
      data-pin-id={@resolved.pin.id}
      class={["group", chip_class(:file)]}
    >
      <span class={chip_token_class(:file)}>
        <.phx_icon name="hero-document" class="size-3.5" />
      </span>
      <span
        id={"decrypt-pin-file-#{@resolved.pin.id}"}
        phx-hook="DecryptSharedFileName"
        phx-update="ignore"
        data-sealed-file-key={@resolved.sealed_key}
        data-encrypted-filename={@resolved.label_ciphertext}
        class="min-w-0"
      >
        <.link
          navigate={@resolved.navigate}
          data-shared-filename
          class="block truncate text-sm font-medium text-slate-700 dark:text-slate-200 group-hover:text-violet-700 dark:group-hover:text-violet-300"
        >
          Encrypted file
        </.link>
      </span>
      <.pin_badge_and_remove resolved={@resolved} />
    </li>
    """
  end

  # Per-type chip shell (border + hover tint), shared shape across all chips.
  defp chip_class(type) do
    [
      "inline-flex max-w-full items-center gap-2 rounded-full border bg-white/70 dark:bg-slate-800/50 pl-1.5 pr-1.5 py-1 transition-colors",
      chip_border_class(type)
    ]
  end

  defp chip_border_class(:circle),
    do:
      "border-teal-200/70 dark:border-teal-800/50 hover:border-teal-300 dark:hover:border-teal-700"

  defp chip_border_class(:file),
    do:
      "border-violet-200/70 dark:border-violet-800/50 hover:border-violet-300 dark:hover:border-violet-700"

  defp chip_border_class(:link),
    do:
      "border-amber-200/70 dark:border-amber-800/50 hover:border-amber-300 dark:hover:border-amber-700"

  # Per-type colored icon token (rounded badge holding the type icon).
  defp chip_token_class(:circle),
    do:
      "flex size-6 shrink-0 items-center justify-center rounded-full bg-teal-100 dark:bg-teal-900/40 text-teal-600 dark:text-teal-400"

  defp chip_token_class(:file),
    do:
      "flex size-6 shrink-0 items-center justify-center rounded-full bg-violet-100 dark:bg-violet-900/40 text-violet-600 dark:text-violet-400"

  defp chip_token_class(:link),
    do:
      "flex size-6 shrink-0 items-center justify-center rounded-full bg-amber-100 dark:bg-amber-900/40 text-amber-600 dark:text-amber-400"

  attr :resolved, :map, required: true

  defp pin_badge_and_remove(assigns) do
    ~H"""
    <span
      :if={@resolved.pin.scope == :org_shared}
      class="shrink-0 inline-flex items-center rounded-full bg-teal-100 dark:bg-teal-900/40 px-1.5 py-0.5 text-[10px] font-semibold text-teal-700 dark:text-teal-300"
      title="Shared with the whole team"
    >
      Team
    </span>
    <button
      :if={@resolved.can_manage?}
      type="button"
      phx-click="remove_pin"
      phx-value-id={@resolved.pin.id}
      id={"remove-pin-#{@resolved.pin.id}"}
      aria-label="Remove pin"
      data-confirm={@resolved.pin.scope == :org_shared && "Remove this pin for the whole team?"}
      class="shrink-0 rounded-full p-1 text-slate-400 hover:text-rose-500 hover:bg-rose-50 dark:hover:bg-rose-900/20"
    >
      <.phx_icon name="hero-x-mark" class="size-3.5" />
    </button>
    """
  end

  @doc """
  Quick-pin toggle buttons for a `:circle`/`:file` target rendered inline on the
  circle card / file row. A "Pin" star toggles the viewer's PERSONAL pin; an
  owner/admin additionally gets a "Team" toggle for the org-wide pin. All
  server-authoritative (the toggle handler re-checks authority — I1).
  """
  attr :pin_type, :atom, required: true
  attr :target_id, :string, required: true
  attr :personal_pinned?, :boolean, default: false
  attr :org_pinned?, :boolean, default: false
  attr :can_manage_org_pins?, :boolean, default: false
  attr :class, :string, default: nil

  def pin_toggle_buttons(assigns) do
    ~H"""
    <span class={["inline-flex items-center gap-1", @class]}>
      <button
        type="button"
        phx-click="toggle_pin"
        phx-value-pin_type={to_string(@pin_type)}
        phx-value-target_id={@target_id}
        phx-value-scope="personal"
        id={"pin-#{@pin_type}-#{@target_id}-personal"}
        aria-pressed={to_string(@personal_pinned?)}
        title={if(@personal_pinned?, do: "Unpin from your dashboard", else: "Pin to your dashboard")}
        class={[
          "rounded-lg p-1 transition-colors",
          @personal_pinned? && "text-teal-600 dark:text-teal-400",
          !@personal_pinned? &&
            "text-slate-400 hover:text-teal-600 dark:text-slate-500 dark:hover:text-teal-400"
        ]}
      >
        <.phx_icon
          name={if(@personal_pinned?, do: "hero-bookmark-solid", else: "hero-bookmark")}
          class="size-4"
        />
      </button>
      <button
        :if={@can_manage_org_pins?}
        type="button"
        phx-click="toggle_pin"
        phx-value-pin_type={to_string(@pin_type)}
        phx-value-target_id={@target_id}
        phx-value-scope="org_shared"
        id={"pin-#{@pin_type}-#{@target_id}-team"}
        aria-pressed={to_string(@org_pinned?)}
        title={if(@org_pinned?, do: "Unpin for the team", else: "Pin for the whole team")}
        class={[
          "rounded-lg px-1.5 py-1 text-[10px] font-semibold uppercase tracking-wide transition-colors",
          @org_pinned? && "bg-teal-100 text-teal-700 dark:bg-teal-900/40 dark:text-teal-300",
          !@org_pinned? &&
            "text-slate-400 hover:text-teal-600 dark:text-slate-500 dark:hover:text-teal-400"
        ]}
      >
        Team
      </button>
    </span>
    """
  end
end
