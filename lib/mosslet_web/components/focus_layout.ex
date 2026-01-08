defmodule MossletWeb.FocusLayout do
  @moduledoc """
  A minimal, distraction-free layout for focused activities like journaling.
  Removes all navigation distractions while keeping essential controls.
  """
  use MossletWeb, :verified_routes
  use Phoenix.Component

  attr :current_page, :atom, required: true
  attr :current_scope, :map, required: true
  attr :back_path, :string, default: nil
  attr :has_unsaved_changes, :boolean, default: false
  attr :saving, :boolean, default: false

  slot :inner_block, required: true
  slot :top_right
  slot :footer

  def focus_layout(assigns) do
    back_path = assigns[:back_path] || ~p"/app/journal"

    assigns = assign(assigns, :back_path, back_path)

    ~H"""
    <div
      class="min-h-screen bg-gradient-to-br from-slate-50 via-stone-50 to-slate-100 dark:from-slate-900 dark:via-slate-900 dark:to-slate-800"
      x-data="{ composing: false, headerVisible: true, footerVisible: true }"
      @focusin.window="if ($event.target.tagName === 'TEXTAREA' || ($event.target.tagName === 'INPUT' && $event.target.type === 'text')) { composing = true; headerVisible = false; footerVisible = false }"
      @focusout.window="composing = false; headerVisible = true; footerVisible = true"
      id="focus-layout"
      phx-hook={if @has_unsaved_changes, do: "UnsavedChanges", else: nil}
      data-has-unsaved={to_string(@has_unsaved_changes)}
    >
      <header
        class="fixed top-0 left-0 right-0 z-40 bg-white/80 dark:bg-slate-900/80 backdrop-blur-md border-b border-slate-200/50 dark:border-slate-700/50 transition-all duration-300"
        x-bind:class="headerVisible ? 'opacity-100 translate-y-0' : 'opacity-0 -translate-y-2 pointer-events-none'"
        @mouseenter="headerVisible = true; footerVisible = true"
        @mouseleave="if (composing) { headerVisible = false; footerVisible = false }"
        @touchstart="headerVisible = true; footerVisible = true"
      >
        <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-14">
            <a
              href={@back_path}
              class={[
                "inline-flex items-center gap-2 text-sm font-medium transition-colors",
                if(@saving,
                  do: "text-slate-400 dark:text-slate-500 cursor-wait",
                  else:
                    "text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100"
                )
              ]}
              data-phx-link="redirect"
              data-phx-link-state="push"
              onclick={"if (#{@has_unsaved_changes && !@saving}) { return confirm('You have unsaved changes. Are you sure you want to leave?'); } if (#{@saving}) { return false; }"}
            >
              <MossletWeb.CoreComponents.phx_icon name="hero-arrow-left" class="h-4 w-4" />
              <span :if={!@saving}>Back</span>
              <span :if={@saving} class="flex items-center gap-1.5">
                <span class="inline-block h-3 w-3 animate-spin rounded-full border-2 border-current border-t-transparent">
                </span>
                Saving...
              </span>
            </a>

            <div class="flex items-center gap-3">
              <span
                :if={@has_unsaved_changes && !@saving}
                class="text-xs text-amber-600 dark:text-amber-400"
              >
                Unsaved changes
              </span>
              {render_slot(@top_right)}
            </div>
          </div>
        </div>
      </header>

      <div
        class="fixed top-0 left-0 right-0 h-4 z-50"
        x-show="composing && !headerVisible"
        @mouseenter="headerVisible = true; footerVisible = true"
        @touchstart="headerVisible = true; footerVisible = true"
      >
      </div>

      <main class={["pt-14", if(@footer != [], do: "pb-20", else: "")]}>
        <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          {render_slot(@inner_block)}
        </div>
      </main>

      <footer
        :if={@footer != []}
        class="fixed bottom-0 left-0 right-0 z-40 bg-white/80 dark:bg-slate-900/80 backdrop-blur-md border-t border-slate-200/50 dark:border-slate-700/50 transition-all duration-300"
        x-bind:class="footerVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-2 pointer-events-none'"
        @mouseenter="headerVisible = true; footerVisible = true"
        @mouseleave="if (composing) { headerVisible = false; footerVisible = false }"
        @touchstart="headerVisible = true; footerVisible = true"
      >
        <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-16">
            {render_slot(@footer)}
          </div>
        </div>
      </footer>

      <div
        :if={@footer != []}
        class="fixed bottom-0 left-0 right-0 h-4 z-50"
        x-show="composing && !footerVisible"
        @mouseenter="headerVisible = true; footerVisible = true"
        @touchstart="headerVisible = true; footerVisible = true"
      >
      </div>
    </div>
    """
  end
end
