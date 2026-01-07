defmodule MossletWeb.ReaderLayout do
  @moduledoc """
  A calm, distraction-free layout for reading content like journal entries.
  Similar to focus layout but optimized for reading with next/previous navigation.
  """
  use MossletWeb, :verified_routes
  use Phoenix.Component

  attr :current_page, :atom, required: true
  attr :current_scope, :map, required: true
  attr :back_path, :string, default: nil
  attr :prev_path, :string, default: nil
  attr :next_path, :string, default: nil

  slot :inner_block, required: true
  slot :top_right

  def reader_layout(assigns) do
    back_path = assigns[:back_path] || ~p"/app/journal"
    assigns = assign(assigns, :back_path, back_path)

    ~H"""
    <div
      class="min-h-screen bg-gradient-to-br from-slate-50 via-stone-50 to-slate-100 dark:from-slate-900 dark:via-slate-900 dark:to-slate-800"
      x-data="{ headerVisible: false, footerVisible: false, scrollY: 0, lastScrollY: 0 }"
      x-init="
        setTimeout(() => { headerVisible = true; footerVisible = true; }, 100);
        setTimeout(() => { headerVisible = false; footerVisible = false; }, 2500);
        $watch('scrollY', value => {
          const diff = value - lastScrollY;
          if (Math.abs(diff) > 10) {
            headerVisible = diff < 0 || value < 50;
            footerVisible = diff < 0 || value < 50;
            lastScrollY = value;
          }
        });
      "
      @scroll.window="scrollY = window.scrollY"
      id="reader-layout"
    >
      <header
        class="fixed top-0 left-0 right-0 z-40 bg-white/80 dark:bg-slate-900/80 backdrop-blur-md border-b border-slate-200/50 dark:border-slate-700/50 transition-all duration-300"
        x-bind:class="headerVisible ? 'opacity-100 translate-y-0' : 'opacity-0 -translate-y-full pointer-events-none'"
        @mouseenter="headerVisible = true"
      >
        <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-14">
            <a
              href={@back_path}
              class="inline-flex items-center gap-2 text-sm font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100 transition-colors"
              data-phx-link="redirect"
              data-phx-link-state="push"
            >
              <MossletWeb.CoreComponents.phx_icon name="hero-arrow-left" class="h-4 w-4" />
              <span>Back</span>
            </a>

            <div class="flex items-center gap-3">
              {render_slot(@top_right)}
            </div>
          </div>
        </div>
      </header>

      <div
        class="fixed top-0 left-0 right-0 h-8 z-50"
        x-show="!headerVisible"
        @mouseenter="headerVisible = true; footerVisible = true"
        @touchstart="headerVisible = true; footerVisible = true"
      >
      </div>

      <main class="pt-14 pb-24">
        <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          {render_slot(@inner_block)}
        </div>
      </main>

      <footer
        :if={@prev_path || @next_path}
        class="fixed bottom-0 left-0 right-0 z-40 bg-white/80 dark:bg-slate-900/80 backdrop-blur-md border-t border-slate-200/50 dark:border-slate-700/50 transition-all duration-300"
        x-bind:class="footerVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-full pointer-events-none'"
        @mouseenter="footerVisible = true"
      >
        <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-16">
            <div class="w-32">
              <a
                :if={@next_path}
                href={@next_path}
                class="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-all"
                data-phx-link="redirect"
                data-phx-link-state="push"
              >
                <MossletWeb.CoreComponents.phx_icon name="hero-chevron-left" class="h-4 w-4" />
                <span>Older</span>
              </a>
            </div>

            <div class="flex items-center gap-1 text-slate-400 dark:text-slate-500">
              <span class="text-xs">Swipe or use arrows</span>
            </div>

            <div class="w-32 flex justify-end">
              <a
                :if={@prev_path}
                href={@prev_path}
                class="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-all"
                data-phx-link="redirect"
                data-phx-link-state="push"
              >
                <span>Newer</span>
                <MossletWeb.CoreComponents.phx_icon name="hero-chevron-right" class="h-4 w-4" />
              </a>
            </div>
          </div>
        </div>
      </footer>

      <div
        :if={@prev_path || @next_path}
        class="fixed bottom-0 left-0 right-0 h-4 z-50"
        x-show="!footerVisible"
        @mouseenter="headerVisible = true; footerVisible = true"
        @touchstart="headerVisible = true; footerVisible = true"
      >
      </div>
    </div>
    """
  end
end
