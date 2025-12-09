defmodule MossletWeb.AdminKeyRotationLive do
  @moduledoc """
  Admin dashboard for monitoring encryption key rotation progress.

  Features:
  - Real-time progress updates via PubSub
  - Overall rotation summary with statistics
  - Per-schema progress tracking
  - Status filtering and details
  """
  use MossletWeb, :live_view

  alias Mosslet.Security.KeyRotation
  alias Mosslet.Security.KeyRotationProgress

  import MossletWeb.DesignSystem

  def render(assigns) do
    ~H"""
    <.layout
      current_page={:admin_key_rotation}
      sidebar_current_page={:admin_key_rotation}
      current_user={@current_user}
      key={@key}
      type="sidebar"
    >
      <div class="min-h-screen bg-gradient-to-br from-slate-50 via-slate-50 to-slate-100 dark:from-slate-900 dark:via-slate-900 dark:to-slate-800">
        <div class="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8">
          <header class="mb-6">
            <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
              <div class="flex items-center gap-3">
                <div class="flex h-11 w-11 items-center justify-center rounded-xl bg-gradient-to-br from-cyan-500 to-teal-600 shadow-lg shadow-cyan-500/20">
                  <.phx_icon name="hero-key" class="h-6 w-6 text-white" />
                </div>
                <div>
                  <h1 class="text-2xl font-bold tracking-tight text-slate-900 dark:text-slate-100">
                    Key Rotation
                  </h1>
                  <p class="text-sm text-slate-500 dark:text-slate-400">
                    Monitor encryption key rotation progress
                  </p>
                </div>
              </div>

              <div class="flex items-center gap-2">
                <.liquid_button
                  variant="ghost"
                  color="slate"
                  phx-click="refresh"
                  icon="hero-arrow-path"
                  size="sm"
                >
                  Refresh
                </.liquid_button>

                <.liquid_button
                  navigate={~p"/admin/dash"}
                  variant="secondary"
                  color="indigo"
                  icon="hero-chart-bar"
                  size="sm"
                >
                  Dashboard
                </.liquid_button>
              </div>
            </div>
          </header>

          <.key_status_card
            vault_status={@vault_status}
            rotation_complete={@rotation_complete}
            old_key_copied={@old_key_copied}
          />

          <div class="mb-6 rounded-xl bg-white/90 dark:bg-slate-800/90 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-sm p-5">
            <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">
                  Rotation Controls
                </h2>
                <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
                  <%= cond do %>
                    <% !@new_key_configured -> %>
                      No new key configured. Set CLOAK_KEY_NEW to enable rotation.
                    <% @has_active_rotations -> %>
                      Rotation is initialized with {@summary.total_schemas} schemas.
                    <% @has_failed_rotations -> %>
                      {Map.get(@summary.by_status, "failed", 0)} schema(s) failed. You can resume to continue from where they left off.
                    <% true -> %>
                      Ready to initialize rotation from {@vault_status.base_key_tag} to {@vault_status.current_default_tag}.
                  <% end %>
                </p>
              </div>

              <div class="flex flex-wrap gap-2">
                <%= cond do %>
                  <% !@new_key_configured -> %>
                    <.liquid_button variant="secondary" color="slate" size="sm" disabled>
                      <.phx_icon name="hero-key" class="h-4 w-4 mr-1.5" /> No New Key
                    </.liquid_button>
                  <% @has_active_rotations -> %>
                    <.liquid_button
                      variant="primary"
                      color="emerald"
                      size="sm"
                      phx-click="start_rotation"
                      icon="hero-play"
                    >
                      Start Rotation
                    </.liquid_button>
                    <.liquid_button
                      variant="secondary"
                      color="rose"
                      size="sm"
                      phx-click="cancel_rotation"
                      icon="hero-x-mark"
                      data-confirm="Are you sure you want to cancel all pending rotations?"
                    >
                      Cancel
                    </.liquid_button>
                  <% @has_failed_rotations -> %>
                    <.liquid_button
                      variant="primary"
                      color="amber"
                      size="sm"
                      phx-click="resume_all_failed"
                      icon="hero-arrow-path"
                    >
                      Resume All Failed
                    </.liquid_button>
                  <% true -> %>
                    <.liquid_button
                      variant="primary"
                      color="cyan"
                      size="sm"
                      phx-click="initiate_rotation"
                      icon="hero-bolt"
                    >
                      Initialize Rotation
                    </.liquid_button>
                <% end %>
              </div>
            </div>
          </div>

          <div
            :if={@viewing_rotation_id}
            class="mb-6 rounded-xl bg-amber-50 dark:bg-amber-900/20 border border-amber-200/60 dark:border-amber-700/40 p-4"
          >
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-2">
                <.phx_icon name="hero-archive-box" class="h-5 w-5 text-amber-600 dark:text-amber-400" />
                <span class="text-sm font-medium text-amber-800 dark:text-amber-200">
                  Viewing historical rotation
                </span>
              </div>
              <.liquid_button
                variant="secondary"
                color="amber"
                size="sm"
                phx-click="view_current_rotation"
                icon="hero-arrow-left"
              >
                Back to Current
              </.liquid_button>
            </div>
          </div>

          <div
            :if={
              (@has_active_rotations or @summary.total_schemas > 0) and is_nil(@viewing_rotation_id)
            }
            class="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-4 mb-6"
          >
            <.stat_card
              title="Total Schemas"
              value={@summary.total_schemas}
              icon="hero-cube"
              color={if @has_active_rotations, do: "blue", else: "slate"}
            />
            <.stat_card
              title="Total Records"
              value={@summary.total_records}
              icon="hero-circle-stack"
              color={if @has_active_rotations, do: "purple", else: "slate"}
            />
            <.stat_card
              title="Processed"
              value={@summary.processed_records}
              icon="hero-check-circle"
              color={if @has_active_rotations, do: "emerald", else: "slate"}
            />
            <.stat_card
              title="Failed"
              value={@summary.failed_records}
              icon="hero-x-circle"
              color={if @has_active_rotations, do: "rose", else: "slate"}
            />
          </div>

          <div class="mb-6">
            <.progress_overview summary={@summary} has_active_rotations={@has_active_rotations} />
          </div>

          <div class="mb-6 rounded-xl bg-white/80 dark:bg-slate-800/80 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-sm">
            <.form for={%{}} phx-change="filter_changed" class="p-4">
              <div class="flex flex-col gap-3 sm:flex-row sm:items-end">
                <div class="flex-1">
                  <label class="block text-xs font-medium text-slate-500 dark:text-slate-400 mb-1.5">
                    Status Filter
                  </label>
                  <.liquid_filter_select
                    name="status"
                    value={@filter_status}
                    label="Filter by status"
                    options={[
                      {"", "All"},
                      {"pending", "Pending"},
                      {"in_progress", "In Progress"},
                      {"completed", "Completed"},
                      {"failed", "Failed"},
                      {"stalled", "Stalled"}
                    ]}
                  />
                </div>
              </div>
            </.form>
          </div>

          <div class="space-y-4">
            <div
              :if={@progress_list == [] and @current_rotation_id == nil}
              class="rounded-xl bg-white/80 dark:bg-slate-800/80 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 p-8 text-center"
            >
              <div class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-gradient-to-br from-slate-100 to-slate-200 dark:from-slate-800 dark:to-slate-700">
                <.phx_icon name="hero-key" class="h-6 w-6 text-slate-400 dark:text-slate-500" />
              </div>
              <h2 class="mt-3 text-sm font-semibold text-slate-900 dark:text-slate-100">
                No rotation progress records
              </h2>
              <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                Key rotation has not been initiated yet.
              </p>
            </div>

            <.rotation_card
              :for={progress <- Enum.reject(@progress_list, &(&1.status == "completed"))}
              progress={progress}
            />

            <% completed_list = Enum.filter(@progress_list, &(&1.status == "completed")) %>
            <div :if={completed_list != []} class="mt-6">
              <button
                type="button"
                phx-click="toggle_completed"
                class="flex items-center gap-2 text-sm font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200 transition-colors"
              >
                <.phx_icon
                  name={if @show_completed, do: "hero-chevron-down", else: "hero-chevron-right"}
                  class="h-4 w-4"
                /> Completed Schemas ({length(completed_list)})
              </button>

              <div :if={@show_completed} class="mt-3 space-y-4">
                <.rotation_card :for={progress <- completed_list} progress={progress} />
              </div>
            </div>
          </div>

          <.cipher_tag_tracker_section
            cipher_tag_report={@cipher_tag_report}
            show_cipher_tags={@show_cipher_tags}
            selected_old_tag={@selected_old_tag}
            old_tag_scan_result={@old_tag_scan_result}
            vault_status={@vault_status}
          />

          <.rotation_history_section
            rotation_history={@rotation_history}
            current_rotation_id={@current_rotation_id}
            show_history={@show_history}
          />
        </div>
      </div>
    </.layout>
    """
  end

  attr :cipher_tag_report, :map, required: true
  attr :show_cipher_tags, :boolean, default: false
  attr :selected_old_tag, :string
  attr :old_tag_scan_result, :map
  attr :vault_status, :map, required: true

  defp cipher_tag_tracker_section(assigns) do
    retired_tags = assigns.vault_status.retired_tags || []
    assigns = assign(assigns, :retired_tags, retired_tags)

    ~H"""
    <div class="mt-8">
      <button
        type="button"
        phx-click="toggle_cipher_tags"
        class="flex items-center gap-2 text-sm font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200 transition-colors mb-4"
      >
        <.phx_icon
          name={if @show_cipher_tags, do: "hero-chevron-down", else: "hero-chevron-right"}
          class="h-4 w-4"
        />
        <.phx_icon name="hero-finger-print" class="h-4 w-4" /> Cipher Tag Tracking
      </button>

      <div :if={@show_cipher_tags} class="space-y-4">
        <div class="rounded-xl bg-white/90 dark:bg-slate-800/90 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-sm p-5">
          <div class="flex items-center gap-2 mb-4">
            <.phx_icon
              name="hero-magnifying-glass"
              class="h-5 w-5 text-amber-600 dark:text-amber-400"
            />
            <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">
              Scan for Old Key Usage
            </h2>
          </div>

          <p class="text-sm text-slate-600 dark:text-slate-400 mb-4">
            Select a retired cipher tag to scan for records that still use it.
            HMAC fields are deterministic hashes and cannot be re-encrypted.
          </p>

          <div class="flex flex-wrap gap-2 mb-4">
            <button
              :for={tag <- @retired_tags}
              type="button"
              phx-click="scan_old_tag"
              phx-value-tag={tag}
              class={[
                "px-3 py-1.5 rounded-lg text-sm font-medium transition-all border",
                if(@selected_old_tag == tag,
                  do:
                    "bg-amber-100 dark:bg-amber-900/30 border-amber-300 dark:border-amber-700 text-amber-800 dark:text-amber-200",
                  else:
                    "bg-slate-100 dark:bg-slate-700 border-slate-200 dark:border-slate-600 text-slate-700 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-600"
                )
              ]}
            >
              {tag}
            </button>
            <span :if={@retired_tags == []} class="text-sm text-slate-500 dark:text-slate-400 italic">
              No retired keys configured
            </span>
          </div>

          <div
            :if={@old_tag_scan_result}
            class="mt-4 p-4 rounded-lg bg-slate-50 dark:bg-slate-900/50 border border-slate-200 dark:border-slate-700"
          >
            <div class="flex items-center justify-between mb-3">
              <h3 class="text-sm font-semibold text-slate-800 dark:text-slate-200">
                Scan Results for
                <code class="bg-amber-100 dark:bg-amber-900/40 px-1.5 py-0.5 rounded font-mono">
                  {@old_tag_scan_result.target_tag}
                </code>
              </h3>
              <span class={[
                "px-2 py-1 rounded-full text-xs font-medium",
                if(@old_tag_scan_result.total_records_affected == 0,
                  do: "bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-300",
                  else: "bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-300"
                )
              ]}>
                <%= if @old_tag_scan_result.total_records_affected == 0 do %>
                  <.phx_icon name="hero-check-circle" class="h-3.5 w-3.5 inline -mt-0.5 mr-1" />
                  All Clear
                <% else %>
                  <.phx_icon name="hero-exclamation-triangle" class="h-3.5 w-3.5 inline -mt-0.5 mr-1" /> {@old_tag_scan_result.total_records_affected} records
                <% end %>
              </span>
            </div>

            <%= if @old_tag_scan_result.total_records_affected == 0 do %>
              <p class="text-sm text-emerald-700 dark:text-emerald-300">
                No records found using this cipher tag. All data has been rotated.
              </p>
            <% else %>
              <div class="space-y-3">
                <p class="text-sm text-amber-700 dark:text-amber-300">
                  Found {@old_tag_scan_result.schemas_affected} schema(s) with records still using this key.
                </p>

                <div
                  :for={schema_result <- @old_tag_scan_result.by_schema}
                  class="p-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700"
                >
                  <div class="flex items-center justify-between mb-2">
                    <span class="text-sm font-medium text-slate-800 dark:text-slate-200">
                      {format_schema_name(schema_result.schema)}
                    </span>
                    <span class="text-xs text-amber-600 dark:text-amber-400 font-medium">
                      {schema_result.records_with_old_key} record(s)
                    </span>
                  </div>

                  <div class="flex flex-wrap gap-1.5 mb-2">
                    <span
                      :for={{field, count} <- schema_result.field_breakdown}
                      class="px-2 py-0.5 rounded text-xs bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-400"
                    >
                      {field}: {count}
                    </span>
                  </div>

                  <details :if={schema_result.sample_record_ids != []} class="mt-2">
                    <summary class="text-xs text-slate-500 dark:text-slate-400 cursor-pointer hover:text-slate-700 dark:hover:text-slate-300">
                      Sample record IDs ({length(schema_result.sample_record_ids)})
                    </summary>
                    <div class="mt-1 text-xs font-mono text-slate-600 dark:text-slate-400 break-all">
                      {Enum.join(schema_result.sample_record_ids, ", ")}
                    </div>
                  </details>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <div class="rounded-xl bg-white/90 dark:bg-slate-800/90 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-sm p-5">
          <div class="flex items-center gap-2 mb-4">
            <.phx_icon name="hero-chart-pie" class="h-5 w-5 text-cyan-600 dark:text-cyan-400" />
            <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">
              Current Cipher Tag Distribution
            </h2>
          </div>

          <p class="text-sm text-slate-600 dark:text-slate-400 mb-4">
            Overview of which cipher tags are in use across all encrypted schemas.
            <span class="text-amber-600 dark:text-amber-400 font-medium">HMAC fields</span>
            are shown separately as they cannot be rotated.
          </p>

          <div class="space-y-4">
            <div
              :for={schema <- @cipher_tag_report.schemas}
              class="p-4 rounded-lg bg-slate-50 dark:bg-slate-900/50 border border-slate-200 dark:border-slate-700"
            >
              <div class="flex items-center justify-between mb-3">
                <h3 class="text-sm font-semibold text-slate-800 dark:text-slate-200">
                  {format_schema_name(schema.schema)}
                </h3>
                <span class="text-xs text-slate-500 dark:text-slate-400">
                  {schema.records_sampled} records sampled
                </span>
              </div>

              <div class="grid gap-3 sm:grid-cols-2 mb-3">
                <div>
                  <p class="text-xs font-medium text-slate-600 dark:text-slate-400 mb-1.5">
                    Rotatable Fields ({length(schema.rotatable_fields)})
                  </p>
                  <div class="flex flex-wrap gap-1">
                    <code
                      :for={field <- schema.rotatable_fields}
                      class="text-xs bg-cyan-100 dark:bg-cyan-900/40 text-cyan-700 dark:text-cyan-300 px-1.5 py-0.5 rounded"
                    >
                      {field}
                    </code>
                  </div>
                </div>
                <div>
                  <p class="text-xs font-medium text-amber-700 dark:text-amber-300 mb-1.5">
                    HMAC Fields ({length(schema.hmac_fields)}) — Non-rotatable
                  </p>
                  <div class="flex flex-wrap gap-1">
                    <code
                      :for={field <- schema.hmac_fields}
                      class="text-xs bg-amber-100 dark:bg-amber-900/40 text-amber-700 dark:text-amber-300 px-1.5 py-0.5 rounded"
                    >
                      {field}
                    </code>
                    <span
                      :if={schema.hmac_fields == []}
                      class="text-xs text-slate-500 dark:text-slate-400 italic"
                    >
                      None
                    </span>
                  </div>
                </div>
              </div>

              <%= if schema.cipher_tag_distribution != %{} do %>
                <div class="mt-3 pt-3 border-t border-slate-200 dark:border-slate-700">
                  <p class="text-xs font-medium text-slate-600 dark:text-slate-400 mb-2">
                    Tag Distribution
                  </p>
                  <div class="flex flex-wrap gap-2">
                    <span
                      :for={{key, count} <- schema.cipher_tag_distribution}
                      class={[
                        "px-2 py-1 rounded text-xs font-medium",
                        if(String.contains?(key, @cipher_tag_report.current_cipher_tag),
                          do:
                            "bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-300",
                          else: "bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-300"
                        )
                      ]}
                    >
                      {key}: {count}
                    </span>
                  </div>
                </div>
              <% else %>
                <p class="text-xs text-slate-500 dark:text-slate-400 italic">
                  No encrypted data found (all fields may be nil)
                </p>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :rotation_history, :list, required: true
  attr :current_rotation_id, :string
  attr :show_history, :boolean, default: false

  defp rotation_history_section(assigns) do
    past_rotations =
      Enum.reject(assigns.rotation_history, fn r ->
        r.rotation_id == assigns.current_rotation_id
      end)

    assigns = assign(assigns, :past_rotations, past_rotations)

    ~H"""
    <div :if={@past_rotations != []} class="mt-8">
      <button
        type="button"
        phx-click="toggle_history"
        class="flex items-center gap-2 text-sm font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200 transition-colors mb-4"
      >
        <.phx_icon
          name={if @show_history, do: "hero-chevron-down", else: "hero-chevron-right"}
          class="h-4 w-4"
        />
        <.phx_icon name="hero-archive-box" class="h-4 w-4" />
        Past Rotations ({length(@past_rotations)})
      </button>

      <div :if={@show_history} class="space-y-3">
        <div
          :for={rotation <- @past_rotations}
          class="rounded-xl bg-white/70 dark:bg-slate-800/70 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 p-4"
        >
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-3">
              <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-emerald-100 dark:bg-emerald-900/50">
                <.phx_icon
                  name="hero-check-circle"
                  class="h-5 w-5 text-emerald-600 dark:text-emerald-400"
                />
              </div>
              <div>
                <p class="text-sm font-medium text-slate-900 dark:text-slate-100">
                  {rotation.from_cipher_tag} → {rotation.to_cipher_tag}
                </p>
                <p class="text-xs text-slate-500 dark:text-slate-400">
                  <.local_time_full id={"rotation-#{rotation.rotation_id}"} at={rotation.inserted_at} />
                </p>
              </div>
            </div>
            <.liquid_button
              variant="ghost"
              color="slate"
              size="sm"
              phx-click="view_rotation"
              phx-value-rotation-id={rotation.rotation_id}
            >
              View Details
            </.liquid_button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :vault_status, :map, required: true
  attr :rotation_complete, :boolean, default: false
  attr :old_key_copied, :boolean, default: false

  defp key_status_card(assigns) do
    ~H"""
    <div class="mb-6 rounded-xl bg-white/90 dark:bg-slate-800/90 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-sm p-5">
      <div class="flex items-center gap-2 mb-4">
        <.phx_icon name="hero-shield-check" class="h-5 w-5 text-cyan-600 dark:text-cyan-400" />
        <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">
          Key Configuration
        </h2>
      </div>

      <div class="grid gap-4 sm:grid-cols-2">
        <div class="flex items-start gap-3 p-3 rounded-lg bg-gradient-to-br from-emerald-50 to-teal-50 dark:from-emerald-900/20 dark:to-teal-900/20 border border-emerald-200/60 dark:border-emerald-700/40">
          <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-emerald-100 dark:bg-emerald-900/50">
            <.phx_icon name="hero-key" class="h-5 w-5 text-emerald-600 dark:text-emerald-400" />
          </div>
          <div class="min-w-0">
            <p class="text-xs font-medium text-emerald-700 dark:text-emerald-300 mb-1">
              Current Active Key
            </p>
            <code class="text-sm font-mono font-semibold text-emerald-900 dark:text-emerald-100 bg-emerald-100 dark:bg-emerald-900/40 px-2 py-0.5 rounded">
              {@vault_status.current_default_tag}
            </code>
            <p class="text-xs text-emerald-600 dark:text-emerald-400 mt-1.5">
              Used for all new encryptions
            </p>
          </div>
        </div>

        <div class="flex items-start gap-3 p-3 rounded-lg bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-800/50 dark:to-slate-700/50 border border-slate-200/60 dark:border-slate-700/40">
          <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-slate-200 dark:bg-slate-700">
            <.phx_icon name="hero-archive-box" class="h-5 w-5 text-slate-600 dark:text-slate-400" />
          </div>
          <div class="min-w-0 flex-1">
            <p class="text-xs font-medium text-slate-700 dark:text-slate-300 mb-1">
              Retired Keys
            </p>
            <%= if @vault_status.retired_tags == [] do %>
              <p class="text-sm text-slate-500 dark:text-slate-400 italic">
                No retired keys
              </p>
            <% else %>
              <div class="flex flex-wrap gap-1.5">
                <code
                  :for={tag <- @vault_status.retired_tags}
                  class="text-xs font-mono text-slate-700 dark:text-slate-300 bg-slate-200 dark:bg-slate-700 px-2 py-0.5 rounded"
                >
                  {tag}
                </code>
              </div>
            <% end %>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-1.5">
              Available for decryption only
            </p>
          </div>
        </div>
      </div>

      <div
        :if={@vault_status.rotation_in_progress}
        class="mt-4 flex items-center gap-2 p-3 rounded-lg bg-amber-50 dark:bg-amber-900/20 border border-amber-200/60 dark:border-amber-700/40"
      >
        <.phx_icon
          name="hero-arrow-path"
          class="h-5 w-5 text-amber-600 dark:text-amber-400 animate-spin"
        />
        <div>
          <p class="text-sm font-medium text-amber-800 dark:text-amber-200">
            Rotation Mode Active
          </p>
          <p class="text-xs text-amber-700 dark:text-amber-300">
            New key (<code class="font-mono font-semibold text-amber-900 dark:text-amber-100">{@vault_status.current_default_tag}</code>) is set.
            Base key:
            <code class="font-mono font-semibold text-amber-900 dark:text-amber-100">
              {@vault_status.base_key_tag}
            </code>
          </p>
        </div>
      </div>

      <.rotation_complete_guidance
        :if={@rotation_complete}
        vault_status={@vault_status}
        old_key_copied={@old_key_copied}
      />
    </div>
    """
  end

  attr :vault_status, :map, required: true
  attr :old_key_copied, :boolean, default: false

  defp rotation_complete_guidance(assigns) do
    new_retired_entry =
      "#{assigns.vault_status.base_key_tag}:#{assigns.vault_status.base_key_value}"

    retired_env_value =
      case System.get_env("CLOAK_KEY_RETIRED") do
        nil -> new_retired_entry
        "" -> new_retired_entry
        existing -> "#{new_retired_entry},#{existing}"
      end

    assigns = assign(assigns, :retired_env_value, retired_env_value)

    ~H"""
    <div class="mt-4 rounded-lg bg-gradient-to-br from-emerald-50 to-teal-50 dark:from-emerald-900/20 dark:to-teal-900/20 border border-emerald-200/60 dark:border-emerald-700/40 p-4">
      <div class="flex items-start gap-3">
        <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-emerald-100 dark:bg-emerald-900/50">
          <.phx_icon name="hero-check-badge" class="h-5 w-5 text-emerald-600 dark:text-emerald-400" />
        </div>
        <div class="flex-1">
          <h3 class="text-sm font-semibold text-emerald-900 dark:text-emerald-100 mb-2">
            Rotation Complete! Next Steps:
          </h3>
          <ol class="text-xs text-emerald-800 dark:text-emerald-200 space-y-3 list-decimal list-inside">
            <li>
              Update your environment variables:
              <ul class="ml-4 mt-1 space-y-1 list-disc list-inside text-emerald-700 dark:text-emerald-300">
                <li>
                  Set
                  <code class="font-mono bg-emerald-100 dark:bg-emerald-900/40 px-1 rounded">
                    CLOAK_KEY
                  </code>
                  to your current
                  <code class="font-mono bg-emerald-100 dark:bg-emerald-900/40 px-1 rounded">
                    CLOAK_KEY_NEW
                  </code>
                  value
                </li>
                <li>
                  Set
                  <code class="font-mono bg-emerald-100 dark:bg-emerald-900/40 px-1 rounded">
                    CLOAK_KEY_TAG
                  </code>
                  to
                  <code class="font-mono bg-emerald-100 dark:bg-emerald-900/40 px-1 rounded">
                    {@vault_status.current_default_tag}
                  </code>
                </li>
                <li>
                  Remove
                  <code class="font-mono bg-emerald-100 dark:bg-emerald-900/40 px-1 rounded">
                    CLOAK_KEY_NEW
                  </code>
                  and
                  <code class="font-mono bg-emerald-100 dark:bg-emerald-900/40 px-1 rounded">
                    CLOAK_KEY_NEW_TAG
                  </code>
                </li>
              </ul>
            </li>
            <li>
              <span class="font-medium">(Recommended)</span>
              Add the old key to retired keys for emergency decryption:
              <div class="ml-4 mt-2 p-3 rounded-lg bg-emerald-100/50 dark:bg-emerald-900/30 border border-emerald-200 dark:border-emerald-800/50">
                <p class="text-emerald-700 dark:text-emerald-300 mb-2">
                  <code class="font-mono bg-emerald-100 dark:bg-emerald-900/40 px-1 rounded">
                    CLOAK_KEY_RETIRED
                  </code>
                  uses a comma-separated format of <code class="font-mono">tag:base64key</code>
                  pairs.
                </p>
                <div class="flex items-center gap-2 mt-3">
                  <button
                    id="copy-retired-key-btn"
                    type="button"
                    phx-hook="ClipboardHook"
                    data-content={@retired_env_value}
                    class={[
                      "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-medium transition-all",
                      if(@old_key_copied,
                        do: "bg-emerald-600 text-white",
                        else: "bg-slate-800 text-emerald-300 hover:bg-slate-700"
                      )
                    ]}
                  >
                    <%= if @old_key_copied do %>
                      <.phx_icon name="hero-check" class="h-3.5 w-3.5" /> Copied!
                    <% else %>
                      <.phx_icon name="hero-clipboard-document" class="h-3.5 w-3.5" />
                      Copy CLOAK_KEY_RETIRED value
                    <% end %>
                  </button>
                </div>
                <p
                  :if={@old_key_copied}
                  class="mt-2 text-[11px] text-emerald-700 dark:text-emerald-300"
                >
                  <.phx_icon name="hero-check-circle" class="h-3 w-3 inline -mt-0.5" />
                  Value copied! Set this as your
                  <code class="font-mono bg-emerald-100 dark:bg-emerald-900/40 px-1 rounded">
                    CLOAK_KEY_RETIRED
                  </code>
                  environment variable.
                </p>
                <p class="mt-2 text-[11px] text-emerald-600 dark:text-emerald-400 italic">
                  <.phx_icon name="hero-information-circle" class="h-3 w-3 inline -mt-0.5" />
                  Retired keys are only used for decryption — never for new encryptions.
                </p>
              </div>
            </li>
            <li>Restart the application to apply changes</li>
          </ol>
          <p class="mt-3 text-xs text-emerald-600 dark:text-emerald-400 italic">
            Once you update the environment and restart, this page will reflect the new configuration.
          </p>
        </div>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :value, :integer, required: true
  attr :icon, :string, required: true
  attr :color, :string, default: "slate"

  defp stat_card(assigns) do
    ~H"""
    <div class="rounded-xl bg-white/90 dark:bg-slate-800/90 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-sm p-4 sm:p-5">
      <div class="flex items-center gap-3">
        <div class={[
          "flex h-10 w-10 sm:h-11 sm:w-11 shrink-0 items-center justify-center rounded-lg",
          stat_icon_bg(@color)
        ]}>
          <.phx_icon name={@icon} class={["h-5 w-5 sm:h-6 sm:w-6", stat_icon_color(@color)]} />
        </div>
        <div class="min-w-0">
          <p class="text-xs sm:text-sm font-medium text-slate-500 dark:text-slate-400 truncate">
            {@title}
          </p>
          <p class="text-xl sm:text-2xl font-bold text-slate-900 dark:text-slate-100">
            {format_number(@value)}
          </p>
        </div>
      </div>
    </div>
    """
  end

  attr :summary, :map, required: true
  attr :has_active_rotations, :boolean, default: false

  defp progress_overview(assigns) do
    ~H"""
    <div class="rounded-xl bg-white/90 dark:bg-slate-800/90 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-sm p-5 sm:p-6">
      <div class="flex items-center justify-between mb-4">
        <div class="flex items-center gap-2">
          <.phx_icon
            name={if @has_active_rotations, do: "hero-chart-pie", else: "hero-clock"}
            class={[
              "h-5 w-5",
              if(@has_active_rotations,
                do: "text-cyan-600 dark:text-cyan-400",
                else: "text-slate-500 dark:text-slate-400"
              )
            ]}
          />
          <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">
            <%= if @has_active_rotations do %>
              Overall Progress
            <% else %>
              Last Rotation Summary
            <% end %>
          </h2>
        </div>
        <div class={[
          "text-2xl font-bold",
          if(@has_active_rotations,
            do: "text-cyan-600 dark:text-cyan-400",
            else: "text-emerald-600 dark:text-emerald-400"
          )
        ]}>
          <%= if @has_active_rotations do %>
            {@summary.progress_percentage}%
          <% else %>
            <.phx_icon name="hero-check-circle" class="h-7 w-7" />
          <% end %>
        </div>
      </div>

      <%= if @has_active_rotations do %>
        <div class="w-full bg-slate-200 dark:bg-slate-700 rounded-full h-3 mb-4 overflow-hidden">
          <div
            class="bg-gradient-to-r from-cyan-500 to-teal-500 h-3 rounded-full transition-all duration-500"
            style={"width: #{@summary.progress_percentage}%"}
          />
        </div>
      <% end %>

      <div class="grid grid-cols-2 sm:grid-cols-5 gap-3 text-sm">
        <.status_count_badge
          label="Pending"
          count={Map.get(@summary.by_status, "pending", 0)}
          color="amber"
        />
        <.status_count_badge
          label="In Progress"
          count={Map.get(@summary.by_status, "in_progress", 0)}
          color="blue"
        />
        <.status_count_badge
          label="Completed"
          count={Map.get(@summary.by_status, "completed", 0)}
          color="emerald"
        />
        <.status_count_badge
          label="Failed"
          count={Map.get(@summary.by_status, "failed", 0)}
          color="rose"
        />
        <.status_count_badge
          label="Stalled"
          count={Map.get(@summary.by_status, "stalled", 0)}
          color="slate"
        />
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :count, :integer, required: true
  attr :color, :string, required: true

  defp status_count_badge(assigns) do
    ~H"""
    <div class={[
      "flex items-center justify-between rounded-lg px-3 py-2",
      status_badge_bg(@color)
    ]}>
      <span class={["text-xs font-medium", status_badge_text(@color)]}>
        {@label}
      </span>
      <span class={["text-sm font-bold", status_badge_count(@color)]}>
        {@count}
      </span>
    </div>
    """
  end

  attr :progress, KeyRotationProgress, required: true

  defp rotation_card(assigns) do
    assigns =
      assign(assigns, :percentage, KeyRotationProgress.progress_percentage(assigns.progress))

    ~H"""
    <div class={[
      "rounded-xl bg-white/90 dark:bg-slate-800/90 backdrop-blur-sm border-l-4 border border-slate-200/60 dark:border-slate-700/60 shadow-sm overflow-hidden",
      status_border_color(@progress.status)
    ]}>
      <div class="p-4 sm:p-5">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between mb-4">
          <div class="flex items-center gap-3">
            <div class={[
              "flex h-10 w-10 shrink-0 items-center justify-center rounded-lg",
              status_icon_bg(@progress.status)
            ]}>
              <.phx_icon
                name={status_icon(@progress.status)}
                class={["h-5 w-5", status_icon_color(@progress.status)]}
              />
            </div>
            <div>
              <h3 class="text-sm font-semibold text-slate-900 dark:text-slate-100">
                {format_schema_name(@progress.schema_name)}
              </h3>
              <p class="text-xs text-slate-500 dark:text-slate-400">
                {@progress.table_name}
              </p>
            </div>
          </div>

          <div class={[
            "inline-flex items-center rounded-full px-3 py-1 text-xs font-medium ring-1 ring-inset self-start sm:self-auto",
            status_badge_class(@progress.status)
          ]}>
            <.phx_icon name={status_icon(@progress.status)} class="h-3 w-3 mr-1.5" />
            {String.replace(@progress.status, "_", " ") |> String.capitalize()}
          </div>
        </div>

        <div class="space-y-3">
          <div class="flex items-center justify-between text-sm">
            <span class="text-slate-500 dark:text-slate-400">Progress</span>
            <span class="font-semibold text-slate-900 dark:text-slate-100">
              {format_number(@progress.processed_records)} / {format_number(@progress.total_records)}
              <span class="text-slate-400 dark:text-slate-500 ml-1">({@percentage}%)</span>
            </span>
          </div>

          <div class="w-full bg-slate-200 dark:bg-slate-700 rounded-full h-2 overflow-hidden">
            <div
              class={[
                "h-2 rounded-full transition-all duration-500",
                progress_bar_color(@progress.status)
              ]}
              style={"width: #{@percentage}%"}
            />
          </div>

          <div class="grid grid-cols-2 gap-4 text-sm">
            <div class="flex items-center gap-2">
              <.phx_icon name="hero-arrow-right" class="h-4 w-4 text-slate-400" />
              <span class="text-slate-500 dark:text-slate-400">From:</span>
              <code class="text-xs bg-slate-100 dark:bg-slate-700 px-2 py-0.5 rounded font-mono text-slate-700 dark:text-slate-300">
                {@progress.from_cipher_tag}
              </code>
            </div>
            <div class="flex items-center gap-2">
              <.phx_icon name="hero-arrow-right" class="h-4 w-4 text-slate-400" />
              <span class="text-slate-500 dark:text-slate-400">To:</span>
              <code class="text-xs bg-slate-100 dark:bg-slate-700 px-2 py-0.5 rounded font-mono text-slate-700 dark:text-slate-300">
                {@progress.to_cipher_tag}
              </code>
            </div>
          </div>

          <div :if={@progress.failed_records > 0} class="flex items-center gap-2 text-sm">
            <.phx_icon name="hero-exclamation-triangle" class="h-4 w-4 text-rose-500" />
            <span class="text-rose-600 dark:text-rose-400 font-medium">
              {format_number(@progress.failed_records)} failed records
            </span>
          </div>

          <div
            :if={@progress.status in ["failed", "stalled"]}
            class="flex items-center gap-2 pt-2 border-t border-slate-100 dark:border-slate-700"
          >
            <.liquid_button
              variant="secondary"
              color="amber"
              size="sm"
              phx-click="resume_rotation"
              phx-value-progress-id={@progress.id}
              icon="hero-arrow-path"
            >
              Resume from {format_number(@progress.processed_records)}/{format_number(
                @progress.total_records
              )}
            </.liquid_button>
            <span class="text-xs text-slate-500 dark:text-slate-400">
              Will continue from last processed record
            </span>
          </div>

          <div class="flex flex-wrap gap-4 text-xs text-slate-500 dark:text-slate-400 pt-2 border-t border-slate-100 dark:border-slate-700">
            <div :if={@progress.started_at} class="flex items-center gap-1.5">
              <.phx_icon name="hero-play" class="h-3.5 w-3.5" /> Started:
              <.local_time_full id={"started-#{@progress.id}"} at={@progress.started_at} />
            </div>
            <div :if={@progress.completed_at} class="flex items-center gap-1.5">
              <.phx_icon name="hero-check" class="h-3.5 w-3.5" /> Completed:
              <.local_time_full id={"completed-#{@progress.id}"} at={@progress.completed_at} />
            </div>
            <div class="flex items-center gap-1.5">
              <.phx_icon name="hero-clock" class="h-3.5 w-3.5" /> Updated:
              <.local_time_full id={"updated-#{@progress.id}"} at={@progress.updated_at} />
            </div>
          </div>

          <div :if={@progress.error_log && @progress.error_log != ""} class="mt-3">
            <details class="group">
              <summary class="cursor-pointer text-xs font-medium text-rose-600 dark:text-rose-400 hover:text-rose-700 dark:hover:text-rose-300">
                <.phx_icon
                  name="hero-chevron-right"
                  class="h-3 w-3 inline-block mr-1 group-open:rotate-90 transition-transform"
                /> View Error Log
              </summary>
              <pre class="mt-2 text-xs bg-rose-50 dark:bg-rose-900/20 text-rose-800 dark:text-rose-200 p-3 rounded-lg overflow-x-auto border border-rose-200 dark:border-rose-800">{@progress.error_log}</pre>
            </details>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp stat_icon_bg("blue"), do: "bg-blue-100 dark:bg-blue-900/50"
  defp stat_icon_bg("emerald"), do: "bg-emerald-100 dark:bg-emerald-900/50"
  defp stat_icon_bg("purple"), do: "bg-purple-100 dark:bg-purple-900/50"
  defp stat_icon_bg("rose"), do: "bg-rose-100 dark:bg-rose-900/50"
  defp stat_icon_bg(_), do: "bg-slate-100 dark:bg-slate-700/50"

  defp stat_icon_color("blue"), do: "text-blue-600 dark:text-blue-400"
  defp stat_icon_color("emerald"), do: "text-emerald-600 dark:text-emerald-400"
  defp stat_icon_color("purple"), do: "text-purple-600 dark:text-purple-400"
  defp stat_icon_color("rose"), do: "text-rose-600 dark:text-rose-400"
  defp stat_icon_color(_), do: "text-slate-600 dark:text-slate-400"

  defp status_badge_bg("amber"), do: "bg-amber-50 dark:bg-amber-900/20"
  defp status_badge_bg("blue"), do: "bg-blue-50 dark:bg-blue-900/20"
  defp status_badge_bg("emerald"), do: "bg-emerald-50 dark:bg-emerald-900/20"
  defp status_badge_bg("rose"), do: "bg-rose-50 dark:bg-rose-900/20"
  defp status_badge_bg(_), do: "bg-slate-50 dark:bg-slate-800/50"

  defp status_badge_text("amber"), do: "text-amber-700 dark:text-amber-300"
  defp status_badge_text("blue"), do: "text-blue-700 dark:text-blue-300"
  defp status_badge_text("emerald"), do: "text-emerald-700 dark:text-emerald-300"
  defp status_badge_text("rose"), do: "text-rose-700 dark:text-rose-300"
  defp status_badge_text(_), do: "text-slate-700 dark:text-slate-300"

  defp status_badge_count("amber"), do: "text-amber-800 dark:text-amber-200"
  defp status_badge_count("blue"), do: "text-blue-800 dark:text-blue-200"
  defp status_badge_count("emerald"), do: "text-emerald-800 dark:text-emerald-200"
  defp status_badge_count("rose"), do: "text-rose-800 dark:text-rose-200"
  defp status_badge_count(_), do: "text-slate-800 dark:text-slate-200"

  defp status_border_color("pending"), do: "border-l-amber-500"
  defp status_border_color("in_progress"), do: "border-l-blue-500"
  defp status_border_color("completed"), do: "border-l-emerald-500"
  defp status_border_color("failed"), do: "border-l-rose-500"
  defp status_border_color("stalled"), do: "border-l-slate-500"
  defp status_border_color(_), do: "border-l-slate-500"

  defp status_icon_bg("pending"), do: "bg-amber-100 dark:bg-amber-900/50"
  defp status_icon_bg("in_progress"), do: "bg-blue-100 dark:bg-blue-900/50"
  defp status_icon_bg("completed"), do: "bg-emerald-100 dark:bg-emerald-900/50"
  defp status_icon_bg("failed"), do: "bg-rose-100 dark:bg-rose-900/50"
  defp status_icon_bg("stalled"), do: "bg-slate-100 dark:bg-slate-700/50"
  defp status_icon_bg(_), do: "bg-slate-100 dark:bg-slate-700/50"

  defp status_icon_color("pending"), do: "text-amber-600 dark:text-amber-400"
  defp status_icon_color("in_progress"), do: "text-blue-600 dark:text-blue-400"
  defp status_icon_color("completed"), do: "text-emerald-600 dark:text-emerald-400"
  defp status_icon_color("failed"), do: "text-rose-600 dark:text-rose-400"
  defp status_icon_color("stalled"), do: "text-slate-600 dark:text-slate-400"
  defp status_icon_color(_), do: "text-slate-600 dark:text-slate-400"

  defp status_icon("pending"), do: "hero-clock"
  defp status_icon("in_progress"), do: "hero-arrow-path"
  defp status_icon("completed"), do: "hero-check-circle"
  defp status_icon("failed"), do: "hero-x-circle"
  defp status_icon("stalled"), do: "hero-pause-circle"
  defp status_icon(_), do: "hero-question-mark-circle"

  defp status_badge_class("pending"),
    do:
      "bg-amber-50 text-amber-700 ring-amber-200 dark:bg-amber-900/20 dark:text-amber-300 dark:ring-amber-800/30"

  defp status_badge_class("in_progress"),
    do:
      "bg-blue-50 text-blue-700 ring-blue-200 dark:bg-blue-900/20 dark:text-blue-300 dark:ring-blue-800/30"

  defp status_badge_class("completed"),
    do:
      "bg-emerald-50 text-emerald-700 ring-emerald-200 dark:bg-emerald-900/20 dark:text-emerald-300 dark:ring-emerald-800/30"

  defp status_badge_class("failed"),
    do:
      "bg-rose-50 text-rose-700 ring-rose-200 dark:bg-rose-900/20 dark:text-rose-300 dark:ring-rose-800/30"

  defp status_badge_class("stalled"),
    do:
      "bg-slate-50 text-slate-700 ring-slate-200 dark:bg-slate-800 dark:text-slate-300 dark:ring-slate-700"

  defp status_badge_class(_),
    do:
      "bg-slate-50 text-slate-700 ring-slate-200 dark:bg-slate-800 dark:text-slate-300 dark:ring-slate-700"

  defp progress_bar_color("pending"), do: "bg-amber-500"
  defp progress_bar_color("in_progress"), do: "bg-gradient-to-r from-blue-500 to-cyan-500"
  defp progress_bar_color("completed"), do: "bg-gradient-to-r from-emerald-500 to-teal-500"
  defp progress_bar_color("failed"), do: "bg-rose-500"
  defp progress_bar_color("stalled"), do: "bg-slate-500"
  defp progress_bar_color(_), do: "bg-slate-500"

  defp format_schema_name(schema_name) do
    schema_name
    |> String.replace("Mosslet.", "")
    |> String.replace("Elixir.", "")
  end

  defp format_number(num) when is_integer(num) do
    num
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  defp format_number(num), do: to_string(num)

  def mount(_params, _session, socket) do
    if connected?(socket) do
      KeyRotation.subscribe()
    end

    socket =
      socket
      |> assign(:page_title, "Key Rotation")
      |> assign(:filter_status, "")
      |> assign(:old_key_copied, false)
      |> assign(:show_completed, false)
      |> assign(:show_history, false)
      |> assign(:show_cipher_tags, false)
      |> assign(:viewing_rotation_id, nil)
      |> assign(:selected_old_tag, nil)
      |> assign(:old_tag_scan_result, nil)
      |> load_data()

    {:ok, socket}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  def handle_event("clipboard_copied", _params, socket) do
    {:noreply, assign(socket, :old_key_copied, true)}
  end

  def handle_event("toggle_completed", _params, socket) do
    {:noreply, assign(socket, :show_completed, !socket.assigns.show_completed)}
  end

  def handle_event("toggle_history", _params, socket) do
    {:noreply, assign(socket, :show_history, !socket.assigns.show_history)}
  end

  def handle_event("toggle_cipher_tags", _params, socket) do
    {:noreply, assign(socket, :show_cipher_tags, !socket.assigns.show_cipher_tags)}
  end

  def handle_event("scan_old_tag", %{"tag" => tag}, socket) do
    result = KeyRotation.scan_all_for_cipher_tag(tag, limit: 500)

    socket =
      socket
      |> assign(:selected_old_tag, tag)
      |> assign(:old_tag_scan_result, result)

    {:noreply, socket}
  end

  def handle_event("view_rotation", %{"rotation-id" => rotation_id}, socket) do
    summary = KeyRotation.rotation_summary(rotation_id)
    progress_list = filter_progress(socket.assigns.filter_status, rotation_id)

    socket =
      socket
      |> assign(:viewing_rotation_id, rotation_id)
      |> assign(:summary, summary)
      |> assign(:progress_list, progress_list)
      |> assign(:has_active_rotations, false)

    {:noreply, socket}
  end

  def handle_event("view_current_rotation", _params, socket) do
    {:noreply,
     socket
     |> assign(:viewing_rotation_id, nil)
     |> load_data()}
  end

  def handle_event("refresh", _params, socket) do
    {:noreply, load_data(socket)}
  end

  def handle_event("filter_changed", %{"status" => status}, socket) do
    socket =
      socket
      |> assign(:filter_status, status)
      |> load_data()

    {:noreply, socket}
  end

  def handle_event("initiate_rotation", _params, socket) do
    case KeyRotation.initiate_rotation() do
      {:ok, _progress_list} ->
        socket =
          socket
          |> put_flash(:info, "Rotation initialized for all encrypted schemas")
          |> load_data()

        {:noreply, socket}

      {:error, :no_new_key_configured} ->
        {:noreply, put_flash(socket, :error, "No new key configured. Set CLOAK_KEY_NEW first.")}

      {:error, :same_cipher} ->
        {:noreply, put_flash(socket, :error, "Source and target ciphers are the same.")}

      {:error, errors} ->
        {:noreply, put_flash(socket, :error, "Failed to initiate: #{inspect(errors)}")}
    end
  end

  def handle_event("start_rotation", _params, socket) do
    case Mosslet.Workers.KeyRotationWorker.enqueue_all_active() do
      results when is_list(results) ->
        count = Enum.count(results, fn {status, _} -> status == :ok end)

        socket =
          socket
          |> put_flash(:info, "Started #{count} rotation jobs")
          |> load_data()

        {:noreply, socket}
    end
  end

  def handle_event("cancel_rotation", _params, socket) do
    case KeyRotation.cancel_rotation() do
      {:ok, count} ->
        socket =
          socket
          |> put_flash(:info, "Cancelled #{count} pending rotations")
          |> load_data()

        {:noreply, socket}
    end
  end

  def handle_event("resume_rotation", %{"progress-id" => progress_id}, socket) do
    case Mosslet.Workers.KeyRotationWorker.resume(progress_id) do
      {:ok, _job} ->
        socket =
          socket
          |> put_flash(:info, "Resumed rotation, continuing from last processed record")
          |> load_data()

        {:noreply, socket}

      {:error, :not_resumable} ->
        {:noreply, put_flash(socket, :error, "This rotation cannot be resumed")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to resume: #{inspect(reason)}")}
    end
  end

  def handle_event("resume_all_failed", _params, socket) do
    failed_progress =
      socket.assigns.progress_list
      |> Enum.filter(&(&1.status in ["failed", "stalled"]))

    results =
      Enum.map(failed_progress, fn progress ->
        Mosslet.Workers.KeyRotationWorker.resume(progress.id)
      end)

    resumed_count = Enum.count(results, fn result -> match?({:ok, _}, result) end)

    socket =
      socket
      |> put_flash(:info, "Resumed #{resumed_count} failed rotation(s)")
      |> load_data()

    {:noreply, socket}
  end

  def handle_info({:progress_updated, _progress}, socket) do
    {:noreply, load_data(socket)}
  end

  def handle_info({:rotation_cancelled, _count}, socket) do
    {:noreply, load_data(socket)}
  end

  defp load_data(socket) do
    current_rotation_id = KeyRotation.current_rotation_id()
    rotation_history = KeyRotation.list_rotation_ids()
    vault_status = Mosslet.Vault.rotation_status()
    has_active = KeyRotation.rotation_in_progress?()

    display_rotation_id =
      if current_rotation_id do
        current_rotation_id
      else
        case rotation_history do
          [latest | _] -> latest.rotation_id
          [] -> nil
        end
      end

    summary = KeyRotation.rotation_summary(display_rotation_id)
    progress_list = filter_progress(socket.assigns.filter_status, display_rotation_id)

    all_completed =
      summary.total_schemas > 0 and
        Map.get(summary.by_status, "completed", 0) == summary.total_schemas

    current_transition_completed =
      if display_rotation_id && all_completed && vault_status.rotation_in_progress do
        case Enum.find(rotation_history, &(&1.rotation_id == display_rotation_id)) do
          %{from_cipher_tag: from, to_cipher_tag: to} ->
            from == vault_status.base_key_tag and to == vault_status.current_default_tag

          _ ->
            false
        end
      else
        false
      end

    cipher_tag_report = KeyRotation.cipher_tag_usage_report(limit: 100)

    socket
    |> assign(:current_rotation_id, display_rotation_id)
    |> assign(:rotation_history, rotation_history)
    |> assign(:summary, summary)
    |> assign(:progress_list, progress_list)
    |> assign(:vault_status, vault_status)
    |> assign(:new_key_configured, vault_status.rotation_in_progress)
    |> assign(:has_active_rotations, has_active)
    |> assign(:has_failed_rotations, Map.get(summary.by_status, "failed", 0) > 0)
    |> assign(:rotation_complete, current_transition_completed)
    |> assign(:cipher_tag_report, cipher_tag_report)
  end

  defp filter_progress("", nil), do: []

  defp filter_progress("", rotation_id) do
    KeyRotation.list_progress_for_rotation(rotation_id)
  end

  defp filter_progress(_status, nil), do: []

  defp filter_progress(status, rotation_id) do
    KeyRotation.list_progress_for_rotation(rotation_id)
    |> Enum.filter(&(&1.status == status))
  end
end
