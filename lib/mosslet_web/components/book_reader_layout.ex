defmodule MossletWeb.BookReaderLayout do
  @moduledoc """
  An immersive, book-like layout for reading journal book entries.
  Controls float in/out on scroll or hover for a distraction-free reading experience.
  """
  use MossletWeb, :verified_routes
  use Phoenix.Component

  alias MossletWeb.Helpers.JournalHelpers

  attr :current_scope, :map, required: true
  attr :back_path, :string, default: nil
  attr :book_title, :string, default: nil
  attr :book_cover_color, :string, default: nil
  attr :book_cover_src, :string, default: nil
  attr :entry_count, :integer, default: 0
  attr :page_spread, :integer, default: 0
  attr :max_spread, :integer, default: 0
  attr :on_edit, :string, default: "edit_book"
  attr :on_exit_reader, :string, default: "exit_reader"
  attr :add_entry_path, :string, default: nil

  slot :inner_block, required: true
  slot :top_right

  def book_reader_layout(assigns) do
    back_path = assigns[:back_path] || ~p"/app/journal"
    assigns = assign(assigns, :back_path, back_path)

    ~H"""
    <div
      class="min-h-screen bg-gradient-to-br from-amber-50/30 via-stone-50 to-slate-100 dark:from-slate-900 dark:via-slate-900 dark:to-slate-800"
      x-data="{ headerVisible: false, footerVisible: false, scrollY: 0, lastScrollY: 0, userInteracted: false, hideTimer: null }"
      x-init="
        setTimeout(() => { headerVisible = true; footerVisible = true; }, 100);
        hideTimer = setTimeout(() => { if (!userInteracted) { headerVisible = false; footerVisible = false; } }, 2000);
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
      id="book-reader-layout"
    >
      <header
        class="fixed top-0 left-0 right-0 z-40 bg-white/80 dark:bg-slate-900/80 backdrop-blur-md border-b border-slate-200/50 dark:border-slate-700/50 transition-all duration-300"
        x-bind:class="headerVisible ? 'opacity-100 translate-y-0' : 'opacity-0 -translate-y-full pointer-events-none'"
        @mouseenter="headerVisible = true; userInteracted = true"
      >
        <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-14">
            <button
              type="button"
              phx-click={@on_exit_reader}
              class="inline-flex items-center gap-2 text-sm font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100 transition-colors"
            >
              <MossletWeb.CoreComponents.phx_icon name="hero-list-bullet" class="h-4 w-4" />
              <span>List View</span>
            </button>

            <div class="flex items-center gap-2">
              <div :if={@book_cover_src} class="hidden sm:block">
                <img
                  src={@book_cover_src}
                  class="h-8 w-auto rounded shadow-sm"
                  alt=""
                />
              </div>
              <div
                :if={!@book_cover_src && @book_cover_color}
                class={[
                  "hidden sm:flex h-8 w-6 rounded items-center justify-center",
                  JournalHelpers.book_cover_gradient(@book_cover_color)
                ]}
              >
                <MossletWeb.CoreComponents.phx_icon
                  name="hero-book-open"
                  class="h-3.5 w-3.5 text-white/80"
                />
              </div>
              <span class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate max-w-[200px]">
                {@book_title || "Untitled Book"}
              </span>
            </div>

            <div class="flex items-center gap-2">
              <button
                type="button"
                phx-click={@on_edit}
                class="p-2 text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg transition-colors"
                title="Edit book"
              >
                <MossletWeb.CoreComponents.phx_icon name="hero-pencil" class="h-4 w-4" />
              </button>
              {render_slot(@top_right)}
            </div>
          </div>
        </div>
      </header>

      <div
        class="fixed top-0 left-0 right-0 h-8 z-50"
        x-show="!headerVisible"
        @mouseenter="headerVisible = true; footerVisible = true; userInteracted = true"
        @touchstart="headerVisible = true; footerVisible = true; userInteracted = true"
      >
      </div>

      <main class="pt-14 pb-24">
        <div class="max-w-5xl mx-auto px-2 sm:px-4 lg:px-6 py-4 sm:py-8">
          {render_slot(@inner_block)}
        </div>
      </main>

      <footer
        class="fixed bottom-0 left-0 right-0 z-40 bg-white/80 dark:bg-slate-900/80 backdrop-blur-md border-t border-slate-200/50 dark:border-slate-700/50 transition-all duration-300"
        x-bind:class="footerVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-full pointer-events-none'"
        @mouseenter="footerVisible = true; userInteracted = true"
      >
        <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-16">
            <div class="w-28">
              <button
                :if={@page_spread > 0}
                type="button"
                phx-click="flip_page"
                phx-value-direction="prev"
                class="inline-flex items-center gap-2 px-3 py-2 text-sm font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-all"
              >
                <MossletWeb.CoreComponents.phx_icon name="hero-chevron-left" class="h-4 w-4" />
                <span class="hidden sm:inline">Previous</span>
              </button>
            </div>

            <div class="flex items-center gap-4">
              <span class="text-xs text-slate-500 dark:text-slate-400">
                Pages {@page_spread * 2 + 1}-{min(@page_spread * 2 + 2, @entry_count)} of {@entry_count}
              </span>

              <a
                :if={@add_entry_path}
                href={@add_entry_path}
                class="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-white bg-gradient-to-r from-teal-500 to-emerald-500 rounded-lg shadow-sm hover:from-teal-600 hover:to-emerald-600 transition-all"
                data-phx-link="redirect"
                data-phx-link-state="push"
              >
                <MossletWeb.CoreComponents.phx_icon name="hero-plus" class="h-3.5 w-3.5" />
                <span class="hidden sm:inline">Add Entry</span>
              </a>
            </div>

            <div class="w-28 flex justify-end">
              <button
                :if={@page_spread < @max_spread}
                type="button"
                phx-click="flip_page"
                phx-value-direction="next"
                class="inline-flex items-center gap-2 px-3 py-2 text-sm font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-all"
              >
                <span class="hidden sm:inline">Next</span>
                <MossletWeb.CoreComponents.phx_icon name="hero-chevron-right" class="h-4 w-4" />
              </button>
            </div>
          </div>
        </div>
      </footer>

      <div
        class="fixed bottom-0 left-0 right-0 h-4 z-50"
        x-show="!footerVisible"
        @mouseenter="headerVisible = true; footerVisible = true; userInteracted = true"
        @touchstart="headerVisible = true; footerVisible = true; userInteracted = true"
      >
      </div>
    </div>
    """
  end
end
