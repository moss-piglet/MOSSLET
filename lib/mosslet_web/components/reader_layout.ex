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
  attr :book_title, :string, default: nil
  attr :current_book_id, :string, default: nil
  attr :books, :list, default: []
  attr :has_loose_entries, :boolean, default: false
  attr :entry_id, :string, default: nil
  attr :entry_matches_scope, :boolean, default: true
  attr :entry_book_title, :string, default: nil

  slot :inner_block, required: true
  slot :top_right

  def reader_layout(assigns) do
    back_path = assigns[:back_path] || ~p"/app/journal"
    assigns = assign(assigns, :back_path, back_path)

    ~H"""
    <div
      class="min-h-screen bg-gradient-to-br from-slate-50 via-stone-50 to-slate-100 dark:from-slate-900 dark:via-slate-900 dark:to-slate-800"
      x-data="{ headerVisible: false, footerVisible: false, cursorVisible: true, scrollY: 0, lastScrollY: 0, userInteracted: false, hideTimer: null, cursorTimer: null, startHideTimer() { clearTimeout(this.hideTimer); this.hideTimer = setTimeout(() => { this.headerVisible = false; this.footerVisible = false; }, 2000); }, startCursorTimer() { clearTimeout(this.cursorTimer); this.cursorTimer = setTimeout(() => { this.cursorVisible = false; }, 3000); } }"
      x-init="
        setTimeout(() => { headerVisible = true; footerVisible = true; }, 100);
        hideTimer = setTimeout(() => { if (!userInteracted) { headerVisible = false; footerVisible = false; } }, 1500);
        cursorTimer = setTimeout(() => { cursorVisible = false; }, 3000);
        $watch('scrollY', value => {
          const diff = value - lastScrollY;
          if (Math.abs(diff) > 10) {
            headerVisible = diff < 0 || value < 50;
            footerVisible = diff < 0 || value < 50;
            lastScrollY = value;
          }
        });
      "
      x-bind:class="!cursorVisible && 'cursor-hidden'"
      @mousemove="cursorVisible = true; startCursorTimer()"
      @scroll.window="scrollY = window.scrollY"
      id="reader-layout"
    >
      <header
        class="fixed top-0 left-0 right-0 z-40 bg-white/80 dark:bg-slate-900/80 backdrop-blur-md border-b border-slate-200/50 dark:border-slate-700/50 transition-all duration-300"
        x-bind:class="headerVisible ? 'opacity-100 translate-y-0' : 'opacity-0 -translate-y-full pointer-events-none'"
        @mouseenter="headerVisible = true; footerVisible = true; cursorVisible = true; userInteracted = true; clearTimeout(hideTimer)"
        @mouseleave="startHideTimer()"
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
              <span :if={@book_title} class="truncate max-w-[150px]">{@book_title}</span>
              <span :if={!@book_title}>Back</span>
            </a>

            <div class="flex items-center gap-3">
              {render_slot(@top_right)}
            </div>
          </div>
        </div>
      </header>

      <div
        :if={!@entry_matches_scope}
        class="fixed top-14 left-0 right-0 z-30 bg-amber-50/95 dark:bg-amber-900/30 backdrop-blur-sm border-b border-amber-200/50 dark:border-amber-700/50 transition-all duration-300"
        x-bind:class="headerVisible ? 'opacity-100 translate-y-0' : 'opacity-0 -translate-y-full pointer-events-none'"
      >
        <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-2">
          <p class="text-xs text-center text-amber-700 dark:text-amber-300">
            <MossletWeb.CoreComponents.phx_icon
              name="hero-information-circle"
              class="inline h-3.5 w-3.5 mr-1"
            />
            <span :if={@entry_book_title}>
              Viewing entry that belongs to <span class="font-medium">{@entry_book_title}</span>
            </span>
            <span :if={!@entry_book_title && @current_book_id}>
              Viewing a <span class="font-medium">loose entry</span> (not in this book)
            </span>
          </p>
        </div>
      </div>

      <div
        class="fixed top-0 left-0 right-0 h-8 z-50"
        x-show="!headerVisible"
        @mouseenter="headerVisible = true; footerVisible = true; cursorVisible = true; userInteracted = true"
        @touchstart="headerVisible = true; footerVisible = true; cursorVisible = true; userInteracted = true"
      >
      </div>

      <main class={["pb-24", if(@entry_matches_scope, do: "pt-14", else: "pt-24")]}>
        <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          {render_slot(@inner_block)}
        </div>
      </main>

      <footer
        :if={
          @prev_path || @next_path || length(@books) > 1 || (@has_loose_entries && @current_book_id)
        }
        class="fixed bottom-0 left-0 right-0 z-40 bg-white/80 dark:bg-slate-900/80 backdrop-blur-md border-t border-slate-200/50 dark:border-slate-700/50 transition-all duration-300"
        x-bind:class="footerVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-full pointer-events-none'"
        @mouseenter="footerVisible = true; headerVisible = true; cursorVisible = true; userInteracted = true; clearTimeout(hideTimer)"
        @mouseleave="startHideTimer()"
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

            <div
              :if={length(@books) > 1 || (@has_loose_entries && @current_book_id)}
              class="relative"
              x-data="{ open: false }"
              @click.outside="open = false"
            >
              <button
                type="button"
                @click="open = !open"
                class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg transition-all"
              >
                <MossletWeb.CoreComponents.phx_icon name="hero-book-open" class="h-3.5 w-3.5" />
                <span :if={@book_title} class="truncate max-w-[100px]">{@book_title}</span>
                <span :if={!@book_title}>Loose entries</span>
                <MossletWeb.CoreComponents.phx_icon name="hero-chevron-up-down" class="h-3 w-3" />
              </button>
              <div
                x-show="open"
                x-transition:enter="transition ease-out duration-100"
                x-transition:enter-start="opacity-0 scale-95"
                x-transition:enter-end="opacity-100 scale-100"
                x-transition:leave="transition ease-in duration-75"
                x-transition:leave-start="opacity-100 scale-100"
                x-transition:leave-end="opacity-0 scale-95"
                class="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 w-48 bg-white dark:bg-slate-800 rounded-xl shadow-lg border border-slate-200 dark:border-slate-700 py-1 overflow-hidden"
              >
                <a
                  :for={book <- @books}
                  :if={book.id != @current_book_id}
                  href={~p"/app/journal/#{@entry_id}?scope=book&book_id=#{book.id}"}
                  data-phx-link="patch"
                  data-phx-link-state="push"
                  class="flex items-center gap-2 px-3 py-2 text-sm text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors"
                >
                  <span class={[
                    "w-3 h-3 rounded-full flex-shrink-0",
                    book_dot_color(book.cover_color)
                  ]}>
                  </span>
                  <span class="truncate">{book.title}</span>
                </a>
                <a
                  :if={@has_loose_entries && @current_book_id}
                  href={~p"/app/journal/#{@entry_id}?scope=loose"}
                  data-phx-link="patch"
                  data-phx-link-state="push"
                  class="flex items-center gap-2 px-3 py-2 text-sm text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors border-t border-slate-100 dark:border-slate-700"
                >
                  <span class="w-3 h-3 rounded-full flex-shrink-0 bg-slate-400"></span>
                  <span>Loose entries</span>
                </a>
              </div>
            </div>
            <div
              :if={length(@books) <= 1 && !(@has_loose_entries && @current_book_id)}
              class="flex items-center gap-1 text-slate-400 dark:text-slate-500"
            >
              <span :if={@book_title} class="text-xs truncate max-w-[120px]">{@book_title}</span>
              <span :if={!@book_title} class="text-xs">Loose entries</span>
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
        :if={
          @prev_path || @next_path || length(@books) > 1 || (@has_loose_entries && @current_book_id)
        }
        class="fixed bottom-0 left-0 right-0 h-4 z-50"
        x-show="!footerVisible"
        @mouseenter="headerVisible = true; footerVisible = true; cursorVisible = true; userInteracted = true"
        @touchstart="headerVisible = true; footerVisible = true; cursorVisible = true; userInteracted = true"
      >
      </div>
    </div>
    """
  end

  defp book_dot_color("yellow"), do: "bg-yellow-400"
  defp book_dot_color("amber"), do: "bg-amber-500"
  defp book_dot_color("orange"), do: "bg-orange-500"
  defp book_dot_color("rose"), do: "bg-rose-500"
  defp book_dot_color("pink"), do: "bg-pink-500"
  defp book_dot_color("purple"), do: "bg-purple-500"
  defp book_dot_color("violet"), do: "bg-violet-500"
  defp book_dot_color("blue"), do: "bg-blue-500"
  defp book_dot_color("cyan"), do: "bg-cyan-500"
  defp book_dot_color("teal"), do: "bg-teal-500"
  defp book_dot_color("emerald"), do: "bg-emerald-500"
  defp book_dot_color(_), do: "bg-slate-500"
end
