defmodule MossletWeb.JournalLive.Book do
  @moduledoc """
  Journal book view - displays entries within a specific book.
  """
  use MossletWeb, :live_view

  import MossletWeb.LocalTime, only: [local_time: 1]

  alias Mosslet.Accounts
  alias Mosslet.Journal
  alias Mosslet.Journal.JournalBook
  alias MossletWeb.DesignSystem
  alias MossletWeb.Helpers.JournalHelpers

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @view_mode == "reading" and @entries != [] do %>
      <.immersive_reading_layout
        current_scope={@current_scope}
        book={@book}
        decrypted_title={@decrypted_title}
        decrypted_description={@decrypted_description}
        decrypted_cover_image_url={@decrypted_cover_image_url}
        entries={@entries}
        page_spread={@page_spread}
        current_page={@current_page}
        flash={@flash}
        privacy_active={@privacy_active}
        privacy_countdown={@privacy_countdown}
        privacy_needs_password={@privacy_needs_password}
        privacy_form={@privacy_form}
      />
    <% else %>
      <.book_sidebar_view
        current_scope={@current_scope}
        book={@book}
        decrypted_title={@decrypted_title}
        decrypted_description={@decrypted_description}
        decrypted_cover_image_url={@decrypted_cover_image_url}
        entries={@entries}
        view_mode={@view_mode}
        page_spread={@page_spread}
        has_more={@has_more}
        show_edit_modal={@show_edit_modal}
        book_form={@book_form}
        uploads={@uploads}
        cover_upload_stage={@cover_upload_stage}
        current_cover_src={@current_cover_src}
        cover_loading={@cover_loading}
        privacy_active={@privacy_active}
        privacy_countdown={@privacy_countdown}
        privacy_needs_password={@privacy_needs_password}
        privacy_form={@privacy_form}
      />
    <% end %>
    """
  end

  defp book_sidebar_view(assigns) do
    ~H"""
    <.layout
      type="sidebar"
      current_scope={@current_scope}
      current_page={:journal}
      sidebar_current_page={:journal}
    >
      <div class="max-w-4xl mx-auto px-3 sm:px-6 pt-4 sm:pt-8 pb-24 sm:pb-8">
        <div class="mb-8">
          <.link
            navigate={~p"/app/journal"}
            class="inline-flex items-center gap-1 text-sm text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300 mb-4"
          >
            <.phx_icon name="hero-arrow-left" class="h-4 w-4" /> Back to Journal
          </.link>

          <%= if @decrypted_cover_image_url do %>
            <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4 mb-6">
              <div class="flex items-center gap-4">
                <div class="max-w-28 sm:max-w-32 flex-shrink-0">
                  <img
                    src={@decrypted_cover_image_url}
                    class="w-full h-auto max-h-36 sm:max-h-40 rounded-xl shadow-lg"
                    alt={"#{@decrypted_title} cover"}
                  />
                </div>
                <div>
                  <h1 class="text-xl sm:text-2xl font-bold text-slate-900 dark:text-slate-100">
                    {@decrypted_title}
                  </h1>
                  <p
                    :if={@decrypted_description}
                    class="text-sm text-slate-600 dark:text-slate-400 mt-1"
                  >
                    {@decrypted_description}
                  </p>
                  <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
                    {@book.entry_count} {if @book.entry_count == 1, do: "entry", else: "entries"}
                  </p>
                </div>
              </div>
              <div class="flex items-center gap-2 sm:flex-shrink-0">
                <DesignSystem.privacy_button
                  active={@privacy_active}
                  countdown={@privacy_countdown}
                  on_click="activate_privacy"
                />
                <button
                  type="button"
                  phx-click="edit_book"
                  class="p-2 text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg transition-colors"
                  title="Edit book"
                >
                  <.phx_icon name="hero-pencil" class="h-5 w-5" />
                </button>
                <.link
                  navigate={~p"/app/journal/new?book_id=#{@book.id}"}
                  class="inline-flex items-center gap-1.5 px-3 py-2 text-sm font-medium text-white bg-gradient-to-r from-teal-500 to-emerald-500 rounded-lg shadow-sm hover:from-teal-600 hover:to-emerald-600 transition-all"
                >
                  <.phx_icon name="hero-plus" class="h-4 w-4" /> Add Entry
                </.link>
              </div>
            </div>
          <% else %>
            <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
              <div class="flex items-center gap-4">
                <div class={[
                  "h-14 w-14 sm:h-16 sm:w-16 rounded-xl flex items-center justify-center flex-shrink-0",
                  JournalHelpers.book_cover_gradient(@book.cover_color)
                ]}>
                  <.phx_icon name="hero-book-open" class="h-7 w-7 sm:h-8 sm:w-8 text-white/80" />
                </div>
                <div class="min-w-0">
                  <h1 class="text-xl sm:text-2xl font-bold text-slate-900 dark:text-slate-100 truncate">
                    {@decrypted_title}
                  </h1>
                  <p
                    :if={@decrypted_description}
                    class="text-sm text-slate-600 dark:text-slate-400 mt-1 line-clamp-2"
                  >
                    {@decrypted_description}
                  </p>
                  <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
                    {@book.entry_count} {if @book.entry_count == 1, do: "entry", else: "entries"}
                  </p>
                </div>
              </div>

              <div class="flex items-center gap-2 sm:flex-shrink-0">
                <DesignSystem.privacy_button
                  active={@privacy_active}
                  countdown={@privacy_countdown}
                  on_click="activate_privacy"
                />
                <button
                  type="button"
                  phx-click="edit_book"
                  class="p-2 text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg transition-colors"
                  title="Edit book"
                >
                  <.phx_icon name="hero-pencil" class="h-5 w-5" />
                </button>
                <.link
                  navigate={~p"/app/journal/new?book_id=#{@book.id}"}
                  class="inline-flex items-center gap-1.5 px-3 py-2 text-sm font-medium text-white bg-gradient-to-r from-teal-500 to-emerald-500 rounded-lg shadow-sm hover:from-teal-600 hover:to-emerald-600 transition-all"
                >
                  <.phx_icon name="hero-plus" class="h-4 w-4" /> Add Entry
                </.link>
              </div>
            </div>
          <% end %>
        </div>

        <div :if={@entries != []} class="flex items-center justify-between mb-4">
          <div class="flex items-center gap-1 p-1 bg-slate-100 dark:bg-slate-800 rounded-lg">
            <button
              type="button"
              phx-click="set_view_mode"
              phx-value-mode="list"
              class={[
                "inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium rounded-md transition-all duration-200",
                if(@view_mode == "list",
                  do: "bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100 shadow-sm",
                  else:
                    "text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100"
                )
              ]}
            >
              <.phx_icon name="hero-list-bullet" class="h-4 w-4" /> List
            </button>
            <button
              type="button"
              phx-click="set_view_mode"
              phx-value-mode="pages"
              class={[
                "inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium rounded-md transition-all duration-200",
                if(@view_mode == "pages",
                  do: "bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100 shadow-sm",
                  else:
                    "text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100"
                )
              ]}
            >
              <.phx_icon name="hero-squares-2x2" class="h-4 w-4" /> Pages
            </button>
            <button
              type="button"
              phx-click="set_view_mode"
              phx-value-mode="reading"
              class={[
                "inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium rounded-md transition-all duration-200",
                if(@view_mode == "reading",
                  do: "bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100 shadow-sm",
                  else:
                    "text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100"
                )
              ]}
            >
              <.phx_icon name="hero-book-open" class="h-4 w-4" /> Reading
            </button>
          </div>
        </div>

        <div :if={@entries == []} class="text-center py-16">
          <.phx_icon
            name="hero-document-text"
            class="h-12 w-12 mx-auto text-slate-400 dark:text-slate-500 mb-4"
          />
          <h2 class="text-lg font-medium text-slate-900 dark:text-slate-100 mb-2">
            No entries yet
          </h2>
          <p class="text-slate-600 dark:text-slate-400 mb-6">
            Start filling this book with your thoughts.
          </p>
          <.link
            navigate={~p"/app/journal/new?book_id=#{@book.id}"}
            class="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium text-white bg-gradient-to-r from-teal-500 to-emerald-500 rounded-xl shadow-sm hover:from-teal-600 hover:to-emerald-600 transition-all duration-200"
          >
            <.phx_icon name="hero-pencil-square" class="h-4 w-4" /> Write first entry
          </.link>
        </div>

        <div :if={@entries != [] && @view_mode == "list"} class="space-y-3">
          <div
            :for={entry <- @entries}
            class="group bg-white dark:bg-slate-800 rounded-xl p-4 border border-slate-200 dark:border-slate-700 hover:border-emerald-300 dark:hover:border-emerald-600 transition-colors cursor-pointer"
            phx-click={
              JS.navigate(
                ~p"/app/journal/#{entry.id}?scope=book&book_id=#{@book.id}&view=#{@view_mode}"
              )
            }
          >
            <div class="flex items-start justify-between gap-4">
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2 mb-1">
                  <h2 class="text-base font-medium text-slate-900 dark:text-slate-100 truncate">
                    {entry.decrypted_title || "Untitled"}
                  </h2>
                  <span :if={entry.is_favorite} class="text-amber-500" title="Favorite">
                    ★
                  </span>
                </div>
                <p class="text-sm text-slate-600 dark:text-slate-400 line-clamp-2">
                  {truncate_body(entry.decrypted_body)}
                </p>
              </div>
              <div class="flex flex-col items-end gap-1 flex-shrink-0">
                <time class="text-xs text-slate-500 dark:text-slate-400">
                  {format_date(entry.entry_date)}
                </time>
                <div class="flex items-center gap-2">
                  <span :if={entry.mood} class="text-lg" title={entry.mood}>
                    {DesignSystem.mood_emoji(entry.mood)}
                  </span>
                  <button
                    type="button"
                    phx-click="delete_entry"
                    phx-value-id={entry.id}
                    data-confirm="Are you sure you want to delete this entry?"
                    class="p-1.5 text-slate-400 hover:text-red-500 dark:text-slate-500 dark:hover:text-red-400 opacity-0 group-hover:opacity-100 transition-all rounded-lg hover:bg-red-50 dark:hover:bg-red-950/30"
                    title="Delete entry"
                    onclick="event.stopPropagation()"
                  >
                    <.phx_icon name="hero-trash" class="h-4 w-4" />
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div :if={@entries != [] && @view_mode == "pages"} class="py-4">
          <.pages_grid_view entries={@entries} book_id={@book.id} view_mode={@view_mode} />
        </div>

        <div :if={@entries != [] && @view_mode == "reading"} class="py-4">
          <.book_reading_view
            entries={@entries}
            page_spread={@page_spread}
            book_id={@book.id}
            view_mode={@view_mode}
          />
        </div>

        <div :if={@has_more && @view_mode == "list"} class="mt-6 text-center">
          <button
            phx-click="load_more"
            class="px-4 py-2 text-sm font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100 transition-colors"
          >
            Load more
          </button>
        </div>
      </div>

      <.liquid_modal
        :if={@show_edit_modal}
        id="edit-book-modal"
        show={@show_edit_modal}
        on_cancel={JS.push("cancel_edit")}
        size="md"
      >
        <:title>Edit Book</:title>
        <.form for={@book_form} id="edit-book-form" phx-change="validate_book" phx-submit="save_book">
          <div class="space-y-6">
            <div>
              <.phx_input
                field={@book_form[:title]}
                type="text"
                label="Title"
                placeholder="My Travel Journal"
                required
              />
            </div>

            <div>
              <.phx_input
                field={@book_form[:description]}
                type="textarea"
                label="Description (optional)"
                placeholder="A collection of my travel memories..."
                rows="2"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
                Cover Color
              </label>
              <div class="flex flex-wrap gap-2">
                <label
                  :for={color <- JournalBook.cover_colors()}
                  class={[
                    "relative w-10 h-10 rounded-lg cursor-pointer transition-all",
                    JournalHelpers.book_cover_gradient(color),
                    if(@book_form[:cover_color].value == color,
                      do: "ring-2 ring-offset-2 ring-slate-900 dark:ring-white",
                      else: "hover:scale-110"
                    )
                  ]}
                >
                  <input
                    type="radio"
                    name="journal_book[cover_color]"
                    value={color}
                    checked={@book_form[:cover_color].value == color}
                    class="sr-only"
                    aria-label={"#{color} cover color"}
                  />
                </label>
              </div>
            </div>

            <DesignSystem.liquid_journal_cover_upload
              upload={@uploads.book_cover}
              upload_stage={@cover_upload_stage}
              current_cover_src={@current_cover_src}
              cover_loading={@cover_loading}
              on_delete="remove_cover"
            />

            <div
              :if={
                Enum.any?(@uploads.book_cover.entries) && !is_cover_processing?(@cover_upload_stage)
              }
              class="flex justify-end"
            >
              <button
                type="button"
                phx-click="upload_cover"
                phx-disable-with="Uploading..."
                class="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-gradient-to-r from-emerald-500 to-teal-500 rounded-xl shadow-sm hover:from-emerald-600 hover:to-teal-600 transition-all duration-200"
              >
                <.phx_icon name="hero-cloud-arrow-up" class="h-4 w-4" /> Upload Cover
              </button>
            </div>

            <div class="flex items-center justify-between pt-4">
              <button
                type="button"
                phx-click="delete_book"
                data-confirm="Are you sure you want to delete this book? All entries will become loose entries."
                class="px-4 py-2 text-sm font-medium text-red-600 dark:text-red-400 hover:text-red-700 dark:hover:text-red-300 transition-colors"
              >
                Delete Book
              </button>
              <div class="flex gap-3">
                <button
                  type="button"
                  phx-click="cancel_edit"
                  class="px-4 py-2 text-sm font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100 transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={
                    !@book_form.source.valid? ||
                      has_pending_cover_upload?(@uploads.book_cover.entries, @cover_upload_stage)
                  }
                  class="px-6 py-2.5 text-sm font-medium text-white bg-gradient-to-r from-teal-500 to-emerald-500 rounded-xl shadow-sm hover:from-teal-600 hover:to-emerald-600 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200"
                >
                  Update
                </button>
              </div>
            </div>
          </div>
        </.form>
      </.liquid_modal>

      <DesignSystem.privacy_screen
        active={@privacy_active}
        countdown={@privacy_countdown}
        needs_password={@privacy_needs_password}
        on_activate="activate_privacy"
        on_reveal="reveal_content"
        on_password_submit="verify_privacy_password"
        privacy_form={@privacy_form}
      />
    </.layout>
    """
  end

  attr :current_scope, :map, required: true
  attr :book, :map, required: true
  attr :decrypted_title, :string, required: true
  attr :decrypted_description, :string, default: nil
  attr :decrypted_cover_image_url, :string, default: nil
  attr :entries, :list, required: true
  attr :page_spread, :integer, required: true
  attr :current_page, :integer, required: true
  attr :flash, :map, required: true
  attr :privacy_active, :boolean, required: true
  attr :privacy_countdown, :integer, required: true
  attr :privacy_needs_password, :boolean, required: true
  attr :privacy_form, :map, required: true

  defp immersive_reading_layout(assigns) do
    total_entries = length(assigns.entries)
    current_page = assigns.current_page
    page_spread = assigns.page_spread

    show_mobile_front_cover = current_page == 0
    show_desktop_front_cover = page_spread == 0

    show_mobile_copyright = current_page == total_entries + 1
    show_mobile_back_cover = current_page == total_entries + 2

    mobile_entry_idx =
      cond do
        show_mobile_front_cover -> nil
        show_mobile_copyright -> nil
        show_mobile_back_cover -> nil
        true -> current_page - 1
      end

    mobile_entry = if mobile_entry_idx, do: Enum.at(assigns.entries, mobile_entry_idx), else: nil
    mobile_page_num = if show_mobile_front_cover, do: 0, else: current_page

    last_entry_spread = div(total_entries - 1, 2) + 1
    even_entries? = rem(total_entries, 2) == 0
    copyright_spread = last_entry_spread + 1
    back_cover_spread = if even_entries?, do: copyright_spread + 1, else: last_entry_spread + 1

    left_entry_idx = if show_desktop_front_cover, do: nil, else: (page_spread - 1) * 2
    right_entry_idx = if show_desktop_front_cover, do: nil, else: (page_spread - 1) * 2 + 1
    left_entry = if left_entry_idx, do: Enum.at(assigns.entries, left_entry_idx), else: nil
    right_entry = if right_entry_idx, do: Enum.at(assigns.entries, right_entry_idx), else: nil

    show_desktop_copyright_spread = even_entries? && page_spread == copyright_spread

    show_desktop_copyright_right =
      (left_entry != nil && right_entry == nil && page_spread == last_entry_spread) ||
        show_desktop_copyright_spread

    show_desktop_back_cover = page_spread == back_cover_spread

    total_pages = total_entries + 3
    max_spread = back_cover_spread

    assigns =
      assigns
      |> assign(:total_entries, total_entries)
      |> assign(:total_pages, total_pages)
      |> assign(:max_spread, max_spread)
      |> assign(:show_mobile_front_cover, show_mobile_front_cover)
      |> assign(:show_desktop_front_cover, show_desktop_front_cover)
      |> assign(:show_mobile_copyright, show_mobile_copyright)
      |> assign(:show_mobile_back_cover, show_mobile_back_cover)
      |> assign(:show_desktop_copyright_spread, show_desktop_copyright_spread)
      |> assign(:show_desktop_copyright_right, show_desktop_copyright_right)
      |> assign(:show_desktop_back_cover, show_desktop_back_cover)
      |> assign(:left_entry, left_entry)
      |> assign(:right_entry, right_entry)
      |> assign(
        :left_page_num,
        if(show_desktop_front_cover, do: 0, else: (page_spread - 1) * 2 + 1)
      )
      |> assign(
        :right_page_num,
        if(show_desktop_front_cover, do: 0, else: (page_spread - 1) * 2 + 2)
      )
      |> assign(:mobile_entry, mobile_entry)
      |> assign(:mobile_page_num, mobile_page_num)

    ~H"""
    <div id="flash-notifications" class="fixed bottom-4 right-4 z-[100]">
      <.phx_flash_group flash={@flash} />
    </div>
    <div
      id="immersive-reader"
      class="min-h-screen bg-gradient-to-br from-amber-50/30 via-stone-50 to-slate-100 dark:from-slate-900 dark:via-slate-900 dark:to-slate-800"
      x-data="{ headerVisible: true, footerVisible: true, cursorVisible: true, scrollY: 0, lastScrollY: 0, userInteracted: false, hintVisible: true, hideTimer: null, cursorTimer: null, touchStartX: 0, touchEndX: 0, isMobile: window.innerWidth < 768, startHideTimer() { clearTimeout(this.hideTimer); this.hideTimer = setTimeout(() => { this.headerVisible = false; this.footerVisible = false; }, 2000); }, startCursorTimer() { clearTimeout(this.cursorTimer); this.cursorTimer = setTimeout(() => { this.cursorVisible = false; }, 3000); } }"
      x-init="
        hideTimer = setTimeout(() => { if (!userInteracted) { headerVisible = false; footerVisible = false; } }, 2500);
        cursorTimer = setTimeout(() => { cursorVisible = false; }, 3000);
        setTimeout(() => { hintVisible = false; }, 4000);
        window.addEventListener('resize', () => { isMobile = window.innerWidth < 768; });
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
      @touchstart="touchStartX = $event.changedTouches[0].screenX"
      @touchend="
        touchEndX = $event.changedTouches[0].screenX;
        const diff = touchStartX - touchEndX;
        if (Math.abs(diff) > 80) {
          if (diff > 0) {
            $dispatch('swipe-left');
          } else {
            $dispatch('swipe-right');
          }
        }
      "
      phx-hook="BookReaderSwipe"
    >
      <header
        class="fixed top-0 left-0 right-0 z-40 bg-white/80 dark:bg-slate-900/80 backdrop-blur-md border-b border-slate-200/50 dark:border-slate-700/50 transition-all duration-300"
        x-bind:class="headerVisible ? 'opacity-100 translate-y-0' : 'opacity-0 -translate-y-full pointer-events-none'"
        @mouseenter="headerVisible = true; footerVisible = true; userInteracted = true; clearTimeout(hideTimer)"
        @mouseleave="startHideTimer()"
      >
        <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-14">
            <button
              type="button"
              phx-click="set_view_mode"
              phx-value-mode="list"
              aria-label="Exit Reading"
              class="inline-flex items-center gap-2 text-sm font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100 transition-colors"
            >
              <.phx_icon name="hero-list-bullet" class="h-4 w-4" />
              <span class="hidden sm:inline">Exit Reading</span>
            </button>

            <div class="flex items-center gap-2">
              <div
                :if={@decrypted_cover_image_url}
                class="hidden sm:block"
              >
                <img
                  src={@decrypted_cover_image_url}
                  class="h-8 w-auto rounded shadow-sm"
                  alt=""
                />
              </div>
              <div
                :if={!@decrypted_cover_image_url}
                class={[
                  "hidden sm:flex h-8 w-6 rounded items-center justify-center",
                  JournalHelpers.book_cover_gradient(@book.cover_color)
                ]}
              >
                <.phx_icon name="hero-book-open" class="h-3.5 w-3.5 text-white/80" />
              </div>
              <h1 class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate max-w-[200px]">
                {@decrypted_title}
              </h1>
            </div>

            <div class="flex items-center gap-2">
              <DesignSystem.privacy_button
                active={@privacy_active}
                countdown={@privacy_countdown}
                on_click="activate_privacy"
              />
              <MossletWeb.Layouts.theme_toggle />
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

      <main class="min-h-screen flex flex-col">
        <div class="flex-1 flex md:flex-row min-h-screen md:justify-center">
          <.immersive_front_cover
            :if={@show_mobile_front_cover}
            book={@book}
            decrypted_title={@decrypted_title}
            decrypted_cover_image_url={@decrypted_cover_image_url}
            class="w-full md:hidden"
          />
          <.immersive_page
            :if={@mobile_entry}
            entry={@mobile_entry}
            page_num={@mobile_page_num}
            total={@total_entries}
            side={if rem(@mobile_page_num, 2) == 1, do: "left", else: "right"}
            book_id={@book.id}
            page_spread={@page_spread}
            class="w-full md:hidden"
          />
          <.immersive_copyright_page
            :if={@show_mobile_copyright}
            book={@book}
            decrypted_title={@decrypted_title}
            current_scope={@current_scope}
            class="w-full md:hidden"
          />
          <.immersive_back_cover
            :if={@show_mobile_back_cover}
            book={@book}
            decrypted_title={@decrypted_title}
            decrypted_cover_image_url={@decrypted_cover_image_url}
            decrypted_description={@decrypted_description}
            current_scope={@current_scope}
            class="w-full md:hidden"
          />
          <.immersive_front_cover
            :if={@show_desktop_front_cover}
            book={@book}
            decrypted_title={@decrypted_title}
            decrypted_cover_image_url={@decrypted_cover_image_url}
            decrypted_description={@decrypted_description}
            class="hidden md:flex w-full"
          />
          <.immersive_page
            :if={!@show_desktop_front_cover && @left_entry}
            entry={@left_entry}
            page_num={@left_page_num}
            total={@total_entries}
            side="left"
            book_id={@book.id}
            page_spread={@page_spread}
            class="hidden md:flex md:w-1/2"
          />
          <div
            :if={!@show_desktop_front_cover}
            class="hidden md:block w-px bg-gradient-to-b from-transparent via-slate-300 dark:via-slate-600 to-transparent absolute left-1/2 top-0 bottom-0 z-10"
          />
          <.immersive_page
            :if={!@show_desktop_front_cover && @right_entry}
            entry={@right_entry}
            page_num={@right_page_num}
            total={@total_entries}
            side="right"
            book_id={@book.id}
            page_spread={@page_spread}
            class="hidden md:flex md:w-1/2"
          />
          <.immersive_blank_page
            :if={@show_desktop_copyright_spread}
            side="left"
            class="hidden md:flex md:w-1/2"
          />
          <.immersive_copyright_page
            :if={@show_desktop_copyright_right}
            book={@book}
            decrypted_title={@decrypted_title}
            current_scope={@current_scope}
            class="hidden md:flex md:w-1/2"
          />
          <.immersive_back_cover
            :if={@show_desktop_back_cover}
            book={@book}
            decrypted_title={@decrypted_title}
            decrypted_cover_image_url={@decrypted_cover_image_url}
            current_scope={@current_scope}
            class="hidden md:flex w-full"
          />
        </div>
      </main>

      <footer
        class="fixed bottom-0 left-0 right-0 z-40 bg-white/80 dark:bg-slate-900/80 backdrop-blur-md border-t border-slate-200/50 dark:border-slate-700/50 transition-all duration-300"
        x-bind:class="footerVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-full pointer-events-none'"
        @mouseenter="footerVisible = true; headerVisible = true; userInteracted = true; clearTimeout(hideTimer)"
        @mouseleave="startHideTimer()"
      >
        <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-16">
            <div class="w-28">
              <button
                :if={@current_page > 0}
                type="button"
                phx-click="flip_page"
                phx-value-direction="prev"
                x-bind:phx-value-is_mobile="isMobile"
                aria-label="Previous page"
                class="inline-flex items-center gap-2 px-3 py-2 text-sm font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-all"
              >
                <.phx_icon name="hero-chevron-left" class="h-4 w-4" />
                <span class="hidden sm:inline">
                  {if @current_page == 1 or @page_spread == 1, do: "Close", else: "Previous"}
                </span>
              </button>
            </div>

            <div class="flex items-center gap-4">
              <span
                :if={@show_desktop_front_cover}
                class="hidden md:inline text-xs text-slate-500 dark:text-slate-400"
              >
                Cover
              </span>
              <span
                :if={!@show_desktop_front_cover && !@show_desktop_back_cover && @right_entry}
                class="hidden md:inline text-xs text-slate-500 dark:text-slate-400"
              >
                {@left_page_num}-{@right_page_num} of {@total_entries}
              </span>
              <span
                :if={@show_desktop_copyright_right}
                class="hidden md:inline text-xs text-slate-500 dark:text-slate-400"
              >
                {@left_page_num} of {@total_entries} · The End
              </span>
              <span
                :if={@show_desktop_back_cover}
                class="hidden md:inline text-xs text-slate-500 dark:text-slate-400"
              >
                Back Cover
              </span>
              <span
                :if={@show_mobile_front_cover}
                class="md:hidden text-xs text-slate-500 dark:text-slate-400"
              >
                Cover
              </span>
              <span :if={@mobile_entry} class="md:hidden text-xs text-slate-500 dark:text-slate-400">
                {@mobile_page_num} of {@total_entries}
              </span>
              <span
                :if={@show_mobile_copyright}
                class="md:hidden text-xs text-slate-500 dark:text-slate-400"
              >
                The End
              </span>
              <span
                :if={@show_mobile_back_cover}
                class="md:hidden text-xs text-slate-500 dark:text-slate-400"
              >
                Back Cover
              </span>
              <.link
                navigate={~p"/app/journal/new?book_id=#{@book.id}&view=reading&page=#{@current_page}"}
                aria-label="Add Entry"
                class="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-white bg-gradient-to-r from-teal-500 to-emerald-500 rounded-lg shadow-sm hover:from-teal-600 hover:to-emerald-600 transition-all"
              >
                <.phx_icon name="hero-plus" class="h-3.5 w-3.5" />
                <span class="hidden sm:inline">Add Entry</span>
              </.link>
            </div>

            <div class="w-28 flex justify-end">
              <button
                :if={@current_page < @total_pages - 1}
                type="button"
                phx-click="flip_page"
                phx-value-direction="next"
                x-bind:phx-value-is_mobile="isMobile"
                aria-label="Next page"
                class="inline-flex items-center gap-2 px-3 py-2 text-sm font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-all"
              >
                <span class="hidden sm:inline">
                  {if @show_mobile_copyright or @current_page == @total_entries,
                    do: "Close",
                    else: "Next"}
                </span>
                <.phx_icon name="hero-chevron-right" class="h-4 w-4" />
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

      <div
        role="status"
        aria-live="polite"
        class="fixed bottom-20 left-1/2 -translate-x-1/2 z-30 pointer-events-none"
      >
        <div
          class="text-xs text-slate-400 dark:text-slate-500 bg-white/60 dark:bg-slate-800/60 backdrop-blur-sm px-3 py-1.5 rounded-full transition-opacity duration-500"
          x-bind:class="hintVisible && !userInteracted ? 'opacity-100' : 'opacity-0'"
        >
          Use ← → keys or swipe to turn pages
        </div>
      </div>
    </div>

    <DesignSystem.privacy_screen
      active={@privacy_active}
      countdown={@privacy_countdown}
      needs_password={@privacy_needs_password}
      on_activate="activate_privacy"
      on_reveal="reveal_content"
      on_password_submit="verify_privacy_password"
      privacy_form={@privacy_form}
    />
    """
  end

  attr :entry, :map, required: true
  attr :page_num, :integer, required: true
  attr :total, :integer, required: true
  attr :side, :string, required: true
  attr :book_id, :string, required: true
  attr :page_spread, :integer, required: true
  attr :class, :string, default: nil

  defp immersive_page(assigns) do
    is_odd = rem(assigns.page_num, 2) == 1

    assigns = assign(assigns, :is_odd, is_odd)

    ~H"""
    <div
      class={[
        "h-screen max-h-[900px] bg-white/90 dark:bg-slate-800/90 backdrop-blur-sm p-6 sm:p-10 md:p-12 cursor-pointer transition-all duration-200 hover:bg-white dark:hover:bg-slate-800 flex flex-col overflow-hidden relative",
        @class
      ]}
      x-bind:class="cursorVisible && 'group'"
      phx-click={
        JS.navigate(
          ~p"/app/journal/#{@entry.id}?scope=book&book_id=#{@book_id}&view=reading&page=#{@page_spread}"
        )
      }
    >
      <button
        type="button"
        phx-click="delete_entry"
        phx-value-id={@entry.id}
        data-confirm="Are you sure you want to rip this page from your journal? This will delete the page."
        class="absolute top-20 right-6 sm:right-10 md:right-12 p-2 text-slate-400 hover:text-red-500 dark:text-slate-500 dark:hover:text-red-400 opacity-0 group-hover:opacity-100 transition-all rounded-lg hover:bg-red-50 dark:hover:bg-red-950/30 z-10"
        title="Delete entry"
        onclick="event.stopPropagation()"
      >
        <.phx_icon name="hero-trash" class="h-5 w-5" />
      </button>
      <div class="flex flex-col h-full pt-16 pb-4">
        <div class="flex items-start justify-between mb-4 flex-shrink-0">
          <div class="flex-1 min-w-0 pr-10">
            <h2 class="text-xl sm:text-2xl md:text-3xl font-semibold text-slate-900 dark:text-slate-100 group-hover:text-emerald-600 dark:group-hover:text-emerald-400 transition-colors">
              {@entry.decrypted_title || "Untitled"}
            </h2>
            <time class="text-sm text-slate-500 dark:text-slate-400 mt-1 block">
              {format_date(@entry.entry_date)}
            </time>
          </div>
          <div class="flex items-center gap-2 flex-shrink-0">
            <span :if={@entry.is_favorite} class="text-amber-500 text-xl" title="Favorite">★</span>
            <span :if={@entry.mood} class="text-2xl" title={@entry.mood}>
              {DesignSystem.mood_emoji(@entry.mood)}
            </span>
          </div>
        </div>

        <div class="relative flex-1 min-h-0 overflow-hidden">
          <div class="text-base sm:text-lg md:text-xl text-slate-600 dark:text-slate-300 leading-relaxed whitespace-pre-wrap h-full overflow-hidden">
            {@entry.decrypted_body}
          </div>
          <div class="absolute bottom-0 left-0 right-0 h-24 bg-gradient-to-t from-white/90 dark:from-slate-800/90 to-transparent pointer-events-none" />
        </div>

        <div class="flex items-center justify-between pt-2 flex-shrink-0">
          <span class={[
            "text-sm font-serif italic text-slate-400 dark:text-slate-500",
            if(@is_odd, do: "order-first", else: "order-last")
          ]}>
            {@page_num}
          </span>
          <span class="text-sm text-emerald-500 dark:text-emerald-400 opacity-0 group-hover:opacity-100 transition-opacity">
            Click to read full entry →
          </span>
        </div>
      </div>
    </div>
    """
  end

  attr :book, :map, required: true
  attr :decrypted_title, :string, required: true
  attr :decrypted_cover_image_url, :string, default: nil
  attr :decrypted_description, :string, default: nil
  attr :class, :string, default: nil

  defp immersive_front_cover(assigns) do
    ~H"""
    <div
      class={[
        "h-screen max-h-[900px] flex items-center justify-center relative overflow-hidden cursor-pointer",
        @class
      ]}
      phx-click="flip_page"
      phx-value-direction="next"
      phx-value-is_mobile="true"
    >
      <div class="absolute inset-0 bg-gradient-to-br from-amber-50/50 via-stone-100 to-slate-200 dark:from-slate-900 dark:via-slate-800 dark:to-slate-900" />
      <div class="absolute inset-0 opacity-30 dark:opacity-20 bg-[radial-gradient(ellipse_at_center,_var(--tw-gradient-stops))] from-amber-100 via-transparent to-transparent" />

      <div class="relative z-10 flex flex-col items-center px-6 pointer-events-none">
        <div class="relative group perspective-1000">
          <div class="absolute -inset-4 bg-gradient-to-br from-black/20 to-black/40 rounded-lg blur-xl opacity-50 group-hover:opacity-60 transition-opacity" />
          <div class="absolute -inset-1 bg-gradient-to-br from-amber-200/30 dark:from-amber-500/10 to-transparent rounded-lg" />

          <div
            :if={@decrypted_cover_image_url}
            class="relative rounded-lg overflow-hidden shadow-[0_25px_60px_-15px_rgba(0,0,0,0.4)] dark:shadow-[0_25px_60px_-15px_rgba(0,0,0,0.7)] ring-1 ring-black/10 dark:ring-white/10 transform transition-transform duration-300 group-hover:scale-[1.02]"
          >
            <div class="absolute inset-y-0 left-0 w-3 bg-gradient-to-r from-black/30 via-black/10 to-transparent z-10" />
            <img
              src={@decrypted_cover_image_url}
              class="w-auto h-[55vh] min-h-[320px] max-h-[500px] object-cover"
              alt={@decrypted_title}
            />
            <div class="absolute inset-0 bg-gradient-to-t from-black/50 via-transparent to-transparent" />
            <div class="absolute bottom-0 left-0 right-0 p-5 text-center">
              <h1 class="text-xl sm:text-2xl font-serif font-bold text-white drop-shadow-[0_2px_4px_rgba(0,0,0,0.8)] line-clamp-2">
                {@decrypted_title}
              </h1>
              <p class="text-sm text-white/80 font-light italic mt-1 drop-shadow-[0_1px_2px_rgba(0,0,0,0.6)]">
                {if @decrypted_description, do: @decrypted_description, else: "A journal"}
              </p>
            </div>
          </div>

          <div
            :if={!@decrypted_cover_image_url}
            class={[
              "relative w-56 sm:w-64 h-[360px] sm:h-[420px] rounded-lg shadow-[0_25px_60px_-15px_rgba(0,0,0,0.4)] dark:shadow-[0_25px_60px_-15px_rgba(0,0,0,0.7)] ring-1 ring-black/10 dark:ring-white/10 flex flex-col items-center justify-center transform transition-transform duration-300 group-hover:scale-[1.02] overflow-hidden",
              JournalHelpers.book_cover_gradient(@book.cover_color)
            ]}
          >
            <div class="absolute inset-y-0 left-0 w-3 bg-gradient-to-r from-black/30 via-black/10 to-transparent" />
            <div class="absolute inset-0 bg-gradient-to-br from-white/10 via-transparent to-black/20" />

            <div class="relative z-10 flex flex-col items-center px-6 text-center">
              <div class="w-20 h-20 rounded-full bg-white/10 backdrop-blur-sm flex items-center justify-center ring-1 ring-white/20 mb-6">
                <.phx_icon name="hero-book-open" class="h-10 w-10 text-white/80" />
              </div>
              <h1 class="text-xl sm:text-2xl font-serif font-bold text-white drop-shadow-lg mb-3 line-clamp-3">
                {@decrypted_title}
              </h1>
              <div class="w-12 h-0.5 bg-white/40 rounded-full mb-3" />
              <p class="text-sm text-white/70 font-light italic">
                {if @decrypted_description, do: @decrypted_description, else: "A journal"}
              </p>
            </div>
          </div>
        </div>

        <p class="mt-8 text-sm text-slate-500 dark:text-slate-400 flex items-center gap-2 animate-pulse">
          <.phx_icon name="hero-chevron-right" class="h-4 w-4" />
          <span>Swipe or tap to open</span>
        </p>
      </div>
    </div>
    """
  end

  attr :side, :string, required: true
  attr :class, :string, default: nil

  defp immersive_blank_page(assigns) do
    ~H"""
    <div class={[
      "h-screen max-h-[900px] flex items-center justify-center relative overflow-hidden bg-gradient-to-br from-amber-50/30 via-stone-50 to-slate-100 dark:from-slate-900 dark:via-slate-900 dark:to-slate-800",
      @class
    ]}>
      <div class="absolute inset-0 opacity-30 dark:opacity-20 bg-[radial-gradient(ellipse_at_center,_var(--tw-gradient-stops))] from-amber-100 via-transparent to-transparent" />
    </div>
    """
  end

  attr :book, :map, required: true
  attr :decrypted_title, :string, required: true
  attr :decrypted_cover_image_url, :string, default: nil
  attr :current_scope, :map, required: true
  attr :class, :string, default: nil

  defp immersive_copyright_page(assigns) do
    decrypted_username =
      decr(
        assigns.current_scope.user.username,
        assigns.current_scope.user,
        assigns.current_scope.key
      )

    assigns = assign(assigns, :decrypted_username, decrypted_username)

    ~H"""
    <div class={[
      "h-screen max-h-[900px] flex items-center justify-center relative overflow-hidden bg-gradient-to-br from-amber-50/30 via-stone-50 to-slate-100 dark:from-slate-900 dark:via-slate-900 dark:to-slate-800",
      @class
    ]}>
      <div class="absolute inset-0 opacity-30 dark:opacity-20 bg-[radial-gradient(ellipse_at_center,_var(--tw-gradient-stops))] from-amber-100 via-transparent to-transparent" />
      <div class="relative z-10 text-center px-6 flex flex-col items-center">
        <p class="text-3xl sm:text-4xl font-serif italic text-slate-700 dark:text-slate-300 mb-8">
          The End
        </p>
        <div class="w-16 h-0.5 bg-slate-300 dark:bg-slate-600 rounded-full mb-8" />
        <p class="text-sm text-slate-500 dark:text-slate-400">
          © <.local_time for={DateTime.utc_now()} format="yyyy" /> {@decrypted_username}
        </p>
      </div>
    </div>
    """
  end

  attr :book, :map, required: true
  attr :decrypted_title, :string, required: true
  attr :decrypted_cover_image_url, :string, default: nil
  attr :current_scope, :map, required: true
  attr :decrypted_description, :string, default: nil
  attr :class, :string, default: nil

  defp immersive_back_cover(assigns) do
    decrypted_username =
      decr(
        assigns.current_scope.user.username,
        assigns.current_scope.user,
        assigns.current_scope.key
      )

    assigns = assign(assigns, :decrypted_username, decrypted_username)

    ~H"""
    <div
      class={[
        "h-screen max-h-[900px] flex items-center justify-center relative overflow-hidden cursor-pointer",
        @class
      ]}
      phx-click="flip_page"
      phx-value-direction="prev"
      phx-value-is_mobile="true"
    >
      <div class="absolute inset-0 bg-gradient-to-br from-amber-50/50 via-stone-100 to-slate-200 dark:from-slate-900 dark:via-slate-800 dark:to-slate-900" />
      <div class="absolute inset-0 opacity-30 dark:opacity-20 bg-[radial-gradient(ellipse_at_center,_var(--tw-gradient-stops))] from-amber-100 via-transparent to-transparent" />

      <div class="relative z-10 flex flex-col items-center px-6 pointer-events-none">
        <div class="relative group perspective-1000">
          <div class="absolute -inset-4 bg-gradient-to-br from-black/20 to-black/40 rounded-lg blur-xl opacity-50" />
          <div class="absolute -inset-1 bg-gradient-to-br from-amber-200/30 dark:from-amber-500/10 to-transparent rounded-lg" />

          <div
            :if={@decrypted_cover_image_url}
            class="relative rounded-lg overflow-hidden shadow-[0_25px_60px_-15px_rgba(0,0,0,0.4)] dark:shadow-[0_25px_60px_-15px_rgba(0,0,0,0.7)] ring-1 ring-black/10 dark:ring-white/10"
          >
            <div class="absolute inset-y-0 right-0 w-3 bg-gradient-to-l from-black/30 via-black/10 to-transparent z-10" />
            <img
              src={@decrypted_cover_image_url}
              class="w-auto h-[55vh] min-h-[320px] max-h-[500px] object-cover"
              alt={@decrypted_title}
            />
            <div class="absolute inset-0 bg-gradient-to-t from-black/50 via-transparent to-transparent" />
            <div class="absolute bottom-0 left-0 right-0 p-5 text-center">
              <p class="text-sm text-white/70 font-light italic drop-shadow-[0_1px_2px_rgba(0,0,0,0.6)]">
                A journal by {@decrypted_username}
              </p>
            </div>
          </div>

          <div
            :if={!@decrypted_cover_image_url}
            class={[
              "relative w-56 sm:w-64 h-[360px] sm:h-[420px] rounded-lg shadow-[0_25px_60px_-15px_rgba(0,0,0,0.4)] dark:shadow-[0_25px_60px_-15px_rgba(0,0,0,0.7)] ring-1 ring-black/10 dark:ring-white/10 flex flex-col items-center justify-center overflow-hidden",
              JournalHelpers.book_cover_gradient(@book.cover_color)
            ]}
          >
            <div class="absolute inset-y-0 right-0 w-3 bg-gradient-to-l from-black/30 via-black/10 to-transparent" />
            <div class="absolute inset-0 bg-gradient-to-br from-white/10 via-transparent to-black/20" />

            <div class="relative z-10 flex flex-col items-center px-6 text-center">
              <div class="w-20 h-20 rounded-full bg-white/10 backdrop-blur-sm flex items-center justify-center ring-1 ring-white/20 mb-6">
                <.phx_icon name="hero-book-open" class="h-10 w-10 text-white/80" />
              </div>
              <p class="text-sm text-white/70 font-light italic">
                A journal by {@decrypted_username}
              </p>
            </div>
          </div>
        </div>

        <p class="mt-8 text-sm text-slate-500 dark:text-slate-400 flex items-center gap-2 animate-pulse">
          <.phx_icon name="hero-chevron-left" class="h-4 w-4" />
          <span>Tap to open</span>
        </p>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"book_id" => book_id}, _session, socket) do
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    case Journal.get_book(book_id, user) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Book not found")
         |> push_navigate(to: ~p"/app/journal")}

      book ->
        decrypted = Journal.decrypt_book(book, user, key)
        entries = Journal.list_journal_entries(user, book_id: book_id, limit: 20)
        decrypted_entries = decrypt_entries(entries, user, key)

        cover_src =
          if decrypted.cover_image_url do
            load_cover_image_src(decrypted.cover_image_url, user, key)
          else
            nil
          end

        {:ok,
         socket
         |> assign(:page_title, "Journal")
         |> assign(:book, book)
         |> assign(:decrypted_title, decrypted.title)
         |> assign(:decrypted_description, decrypted.description)
         |> assign(:decrypted_cover_image_url, cover_src)
         |> assign(:entries, decrypted_entries)
         |> assign(:offset, 20)
         |> assign(:has_more, length(entries) == 20)
         |> assign(:show_edit_modal, false)
         |> assign(:book_form, nil)
         |> assign(:cover_upload_stage, nil)
         |> assign(:current_cover_src, cover_src)
         |> assign(:cover_loading, false)
         |> JournalHelpers.assign_privacy_state(user)
         |> allow_upload(:book_cover,
           accept: ~w(.jpg .jpeg .png .webp .heic .heif),
           max_entries: 1,
           max_file_size: 5_000_000,
           auto_upload: true,
           chunk_timeout: 30_000
         )}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    view_mode = params["view"] || "list"
    view_mode = if view_mode in ["list", "pages", "reading"], do: view_mode, else: "list"

    current_page =
      case Integer.parse(params["page"] || "") do
        {n, _} when n >= 0 -> n
        _ -> 0
      end

    page_spread = if current_page == 0, do: 0, else: div(current_page + 1, 2)

    prev_view_mode = socket.assigns[:view_mode]

    socket =
      cond do
        prev_view_mode == nil and view_mode in ["reading", "pages"] ->
          reload_entries_for_view_mode(socket, view_mode)

        prev_view_mode != view_mode and view_mode in ["reading", "pages"] ->
          reload_entries_for_view_mode(socket, view_mode)

        prev_view_mode in ["reading", "pages"] and view_mode == "list" ->
          reload_entries_for_view_mode(socket, view_mode)

        true ->
          socket
      end

    {:noreply,
     socket
     |> assign(:view_mode, view_mode)
     |> assign(:current_page, current_page)
     |> assign(:page_spread, page_spread)}
  end

  defp reload_entries_for_view_mode(socket, view_mode) do
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key
    book_id = socket.assigns.book.id

    {order, limit} =
      case view_mode do
        "reading" -> {:asc, 500}
        "pages" -> {:asc, 500}
        _ -> {:desc, 20}
      end

    entries = Journal.list_journal_entries(user, book_id: book_id, limit: limit, order: order)
    decrypted_entries = decrypt_entries(entries, user, key)

    socket
    |> assign(:entries, decrypted_entries)
    |> assign(:offset, if(view_mode == "list", do: 20, else: length(entries)))
    |> assign(:has_more, view_mode == "list" and length(entries) == 20)
  end

  @impl true
  def handle_event("set_view_mode", %{"mode" => mode}, socket)
      when mode in ["list", "pages", "reading"] do
    book_id = socket.assigns.book.id
    {:noreply, push_patch(socket, to: ~p"/app/journal/books/#{book_id}?view=#{mode}")}
  end

  @impl true
  def handle_event("flip_page", %{"direction" => direction} = params, socket) do
    entries = socket.assigns.entries
    total_entries = length(entries)
    total_pages = total_entries + 3
    current_page = socket.assigns.current_page
    is_mobile = params["is_mobile"] == "true" or params["is_mobile"] == true

    new_page =
      if is_mobile do
        case direction do
          "next" -> min(current_page + 1, total_pages - 1)
          "prev" -> max(current_page - 1, 0)
        end
      else
        current_spread = socket.assigns.page_spread
        last_entry_spread = div(total_entries - 1, 2) + 1
        even_entries? = rem(total_entries, 2) == 0
        copyright_spread = last_entry_spread + 1

        back_cover_spread =
          if even_entries?, do: copyright_spread + 1, else: last_entry_spread + 1

        max_spread = back_cover_spread

        new_spread =
          case direction do
            "next" -> min(current_spread + 1, max_spread)
            "prev" -> max(current_spread - 1, 0)
          end

        if new_spread == 0, do: 0, else: (new_spread - 1) * 2 + 1
      end

    book_id = socket.assigns.book.id

    {:noreply,
     push_patch(socket, to: ~p"/app/journal/books/#{book_id}?view=reading&page=#{new_page}")}
  end

  @impl true
  def handle_event("keyboard_nav", %{"key" => key} = params, socket)
      when key in ["ArrowLeft", "ArrowRight"] do
    if socket.assigns.view_mode == "reading" do
      direction = if key == "ArrowRight", do: "next", else: "prev"
      entries = socket.assigns.entries
      total_entries = length(entries)
      total_pages = total_entries + 3
      current_page = socket.assigns.current_page

      width = params["width"] || 1024
      is_mobile = width < 768

      new_page =
        if is_mobile do
          case direction do
            "next" -> min(current_page + 1, total_pages - 1)
            "prev" -> max(current_page - 1, 0)
          end
        else
          current_spread = socket.assigns.page_spread
          last_entry_spread = div(total_entries - 1, 2) + 1
          even_entries? = rem(total_entries, 2) == 0
          copyright_spread = last_entry_spread + 1

          back_cover_spread =
            if even_entries?, do: copyright_spread + 1, else: last_entry_spread + 1

          max_spread = back_cover_spread

          new_spread =
            case direction do
              "next" -> min(current_spread + 1, max_spread)
              "prev" -> max(current_spread - 1, 0)
            end

          if new_spread == 0, do: 0, else: (new_spread - 1) * 2 + 1
        end

      if new_page != current_page do
        book_id = socket.assigns.book.id

        {:noreply,
         push_patch(socket, to: ~p"/app/journal/books/#{book_id}?view=reading&page=#{new_page}")}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("keyboard_nav", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("swipe_navigate", %{"direction" => direction} = params, socket)
      when direction in ["next", "prev"] do
    if socket.assigns.view_mode == "reading" do
      is_mobile = params["is_mobile"] == true
      entries = socket.assigns.entries
      total_entries = length(entries)
      total_pages = total_entries + 3
      current_page = socket.assigns.current_page

      new_page =
        if is_mobile do
          case direction do
            "next" -> min(current_page + 1, total_pages - 1)
            "prev" -> max(current_page - 1, 0)
          end
        else
          current_spread = socket.assigns.page_spread
          last_entry_spread = div(total_entries - 1, 2) + 1
          even_entries? = rem(total_entries, 2) == 0
          copyright_spread = last_entry_spread + 1

          back_cover_spread =
            if even_entries?, do: copyright_spread + 1, else: last_entry_spread + 1

          max_spread = back_cover_spread

          new_spread =
            case direction do
              "next" -> min(current_spread + 1, max_spread)
              "prev" -> max(current_spread - 1, 0)
            end

          if new_spread == 0, do: 0, else: (new_spread - 1) * 2 + 1
        end

      if new_page != current_page do
        book_id = socket.assigns.book.id

        {:noreply,
         push_patch(socket, to: ~p"/app/journal/books/#{book_id}?view=reading&page=#{new_page}")}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "viewport_changed",
        %{"from_mobile" => from_mobile, "to_mobile" => to_mobile},
        socket
      ) do
    if socket.assigns.view_mode == "reading" do
      entries = socket.assigns.entries
      total_entries = length(entries)
      current_page = socket.assigns.current_page

      last_entry_spread = div(total_entries - 1, 2) + 1
      even_entries? = rem(total_entries, 2) == 0
      copyright_spread = last_entry_spread + 1
      back_cover_spread = if even_entries?, do: copyright_spread + 1, else: last_entry_spread + 1

      mobile_copyright_page = total_entries + 1
      mobile_back_cover_page = total_entries + 2

      new_page =
        cond do
          from_mobile && !to_mobile ->
            cond do
              current_page == mobile_back_cover_page ->
                (back_cover_spread - 1) * 2 + 1

              current_page == mobile_copyright_page ->
                if even_entries? do
                  (copyright_spread - 1) * 2 + 1
                else
                  (last_entry_spread - 1) * 2 + 1
                end

              true ->
                current_page
            end

          !from_mobile && to_mobile ->
            current_spread = socket.assigns.page_spread

            cond do
              current_spread == back_cover_spread ->
                mobile_back_cover_page

              even_entries? && current_spread == copyright_spread ->
                mobile_copyright_page

              true ->
                current_page
            end

          true ->
            current_page
        end

      if new_page != current_page do
        book_id = socket.assigns.book.id

        {:noreply,
         push_patch(socket, to: ~p"/app/journal/books/#{book_id}?view=reading&page=#{new_page}")}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key
    book_id = socket.assigns.book.id
    offset = socket.assigns.offset

    new_entries = Journal.list_journal_entries(user, book_id: book_id, limit: 20, offset: offset)
    decrypted_new = decrypt_entries(new_entries, user, key)

    {:noreply,
     socket
     |> assign(:entries, socket.assigns.entries ++ decrypted_new)
     |> assign(:offset, offset + 20)
     |> assign(:has_more, length(new_entries) == 20)}
  end

  @impl true
  def handle_event("edit_book", _params, socket) do
    book = socket.assigns.book

    changeset =
      Journal.change_book(book, %{
        title: socket.assigns.decrypted_title,
        description: socket.assigns.decrypted_description
      })

    {:noreply,
     socket
     |> assign(:show_edit_modal, true)
     |> assign(:book_form, to_form(changeset, as: :journal_book))
     |> assign(:current_cover_src, socket.assigns.decrypted_cover_image_url)
     |> assign(:pending_cover_path, nil)
     |> assign(:cover_upload_stage, nil)}
  end

  @impl true
  def handle_event("validate_book", %{"journal_book" => params}, socket) do
    changeset =
      socket.assigns.book
      |> Journal.change_book(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :book_form, to_form(changeset, as: :journal_book))}
  end

  @impl true
  def handle_event("save_book", %{"journal_book" => params}, socket) do
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key
    book = socket.assigns.book

    cover_file_path = socket.assigns[:pending_cover_path]
    consume_uploaded_entries(socket, :book_cover, fn _meta, _entry -> {:ok, nil} end)

    case Journal.update_book(book, params, user, key) do
      {:ok, updated_book} ->
        updated_book =
          cond do
            cover_file_path ->
              old_url = book.cover_image_url

              if old_url do
                decrypted_old =
                  Mosslet.Encrypted.Users.Utils.decrypt_user_data(old_url, user, key)

                Mosslet.FileUploads.JournalCoverUploadWriter.delete_cover_image(decrypted_old)
              end

              case Journal.update_book_cover_image(updated_book, cover_file_path, user, key) do
                {:ok, with_cover} -> with_cover
                {:error, _} -> updated_book
              end

            socket.assigns.current_cover_src == nil && book.cover_image_url ->
              old_url = book.cover_image_url
              decrypted_old = Mosslet.Encrypted.Users.Utils.decrypt_user_data(old_url, user, key)
              Mosslet.FileUploads.JournalCoverUploadWriter.delete_cover_image(decrypted_old)

              case Journal.clear_book_cover_image(updated_book) do
                {:ok, cleared} -> cleared
                {:error, _} -> updated_book
              end

            true ->
              updated_book
          end

        decrypted = Journal.decrypt_book(updated_book, user, key)

        cover_src =
          if decrypted.cover_image_url do
            load_cover_image_src(decrypted.cover_image_url, user, key)
          else
            nil
          end

        {:noreply,
         socket
         |> assign(:show_edit_modal, false)
         |> assign(:book_form, nil)
         |> assign(:book, %{updated_book | entry_count: book.entry_count})
         |> assign(:decrypted_title, decrypted.title)
         |> assign(:decrypted_description, decrypted.description)
         |> assign(:decrypted_cover_image_url, cover_src)
         |> assign(:current_cover_src, nil)
         |> assign(:pending_cover_path, nil)
         |> assign(:cover_upload_stage, nil)
         |> assign(:page_title, "Journal")
         |> put_flash(:info, "Book updated")
         |> push_event("restore-body-scroll", %{})}

      {:error, changeset} ->
        {:noreply, assign(socket, :book_form, to_form(changeset, as: :journal_book))}
    end
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    socket =
      Enum.reduce(socket.assigns.uploads.book_cover.entries, socket, fn entry, acc ->
        cancel_upload(acc, :book_cover, entry.ref)
      end)

    if socket.assigns[:pending_cover_path] do
      Mosslet.FileUploads.JournalCoverUploadWriter.delete_cover_image(
        socket.assigns.pending_cover_path
      )
    end

    {:noreply,
     socket
     |> assign(:show_edit_modal, false)
     |> assign(:book_form, nil)
     |> assign(:cover_upload_stage, nil)
     |> assign(:pending_cover_path, nil)
     |> assign(:current_cover_src, socket.assigns.decrypted_cover_image_url)
     |> push_event("restore-body-scroll", %{})}
  end

  @impl true
  def handle_event("cancel_cover_upload", %{"ref" => ref}, socket) do
    {:noreply,
     socket
     |> cancel_upload(:book_cover, ref)
     |> assign(:cover_upload_stage, nil)}
  end

  @impl true
  def handle_event("upload_cover", _params, socket) do
    entries = socket.assigns.uploads.book_cover.entries
    in_progress? = Enum.any?(entries, &(&1.progress < 100))

    if entries == [] or in_progress? do
      {:noreply, socket}
    else
      do_upload_cover(socket)
    end
  end

  @impl true
  def handle_event("remove_cover", _params, socket) do
    if socket.assigns[:pending_cover_path] do
      Mosslet.FileUploads.JournalCoverUploadWriter.delete_cover_image(
        socket.assigns.pending_cover_path
      )
    end

    consume_uploaded_entries(socket, :book_cover, fn _meta, _entry -> {:ok, nil} end)

    {:noreply,
     socket
     |> assign(:current_cover_src, nil)
     |> assign(:pending_cover_path, nil)
     |> assign(:cover_upload_stage, nil)}
  end

  @impl true
  def handle_event("delete_book", _params, socket) do
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key
    book = socket.assigns.book

    case Journal.delete_book(book, user, key) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Book deleted")
         |> push_event("restore-body-scroll", %{})
         |> push_navigate(to: ~p"/app/journal")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete book")}
    end
  end

  @impl true
  def handle_event("delete_entry", %{"id" => entry_id}, socket) do
    user = socket.assigns.current_scope.user
    book = socket.assigns.book

    entry = Enum.find(socket.assigns.entries, &(&1.id == entry_id))

    if entry do
      case Journal.delete_journal_entry(entry, user) do
        {:ok, _} ->
          updated_entries = Enum.reject(socket.assigns.entries, &(&1.id == entry_id))
          updated_book = %{book | entry_count: max(0, book.entry_count - 1)}

          {:noreply,
           socket
           |> assign(:entries, updated_entries)
           |> assign(:book, updated_book)
           |> put_flash(:info, "Entry deleted")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not delete entry")}
      end
    else
      {:noreply, put_flash(socket, :error, "Entry not found")}
    end
  end

  @impl true
  def handle_event("restore-body-scroll", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("activate_privacy", _params, socket) do
    user = socket.assigns.current_scope.user

    case Mosslet.Accounts.update_journal_privacy(user, true) do
      {:ok, _user} ->
        Mosslet.Journal.PrivacyTimer.activate(user.id)
        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to enable privacy mode")}
    end
  end

  @impl true
  def handle_event("reveal_content", _params, socket) do
    if socket.assigns.privacy_needs_password do
      {:noreply, socket}
    else
      user = socket.assigns.current_scope.user

      case Mosslet.Accounts.update_journal_privacy(user, false) do
        {:ok, _user} ->
          Mosslet.Journal.PrivacyTimer.deactivate(user.id)
          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to disable privacy mode")}
      end
    end
  end

  @impl true
  def handle_event("verify_privacy_password", %{"privacy" => %{"password" => password}}, socket) do
    user = socket.assigns.current_scope.user

    if Mosslet.Accounts.User.valid_password?(user, password) do
      case Mosslet.Accounts.update_journal_privacy(user, false) do
        {:ok, _user} ->
          Mosslet.Journal.PrivacyTimer.deactivate(user.id)

          {:noreply,
           socket
           |> assign(:privacy_active, false)
           |> assign(:privacy_countdown, 0)
           |> assign(:privacy_needs_password, false)
           |> push_event("restore-body-scroll", %{})}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to disable privacy mode")}
      end
    else
      {:noreply, put_flash(socket, :error, "Incorrect password")}
    end
  end

  @impl true
  def handle_info({:cover_upload_stage, stage}, socket) do
    {:noreply, assign(socket, :cover_upload_stage, stage)}
  end

  @impl true
  def handle_info({:cover_upload_complete, {:ok, file_path, preview_src}}, socket) do
    {:noreply,
     socket
     |> assign(:cover_upload_stage, {:ready, 100})
     |> assign(:pending_cover_path, file_path)
     |> assign(:current_cover_src, preview_src)}
  end

  @impl true
  def handle_info({:cover_upload_complete, {:ok, file_path}}, socket) do
    {:noreply,
     socket
     |> assign(:cover_upload_stage, {:ready, 100})
     |> assign(:pending_cover_path, file_path)}
  end

  @impl true
  def handle_info({:cover_upload_complete, {:error, error}}, socket) do
    {:noreply,
     socket
     |> assign(:cover_upload_stage, {:error, error})
     |> put_flash(:warning, error)}
  end

  @impl true
  def handle_info({_ref, {"get_user_avatar", user_id}}, socket) do
    user = Accounts.get_user_with_preloads(user_id)
    current_scope = %{socket.assigns.current_scope | user: user}
    {:noreply, assign(socket, :current_scope, current_scope)}
  end

  @impl true
  def handle_info({:privacy_timer_update, state}, socket) do
    {:noreply, JournalHelpers.handle_privacy_timer_update(socket, state)}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp load_cover_image_src(file_path, user, key) when is_binary(file_path) do
    bucket = Mosslet.Encrypted.Session.memories_bucket()
    host = Mosslet.Encrypted.Session.s3_host()
    host_name = "https://#{bucket}.#{host}"

    config = %{
      region: Mosslet.Encrypted.Session.s3_region(),
      access_key_id: Mosslet.Encrypted.Session.s3_access_key_id(),
      secret_access_key: Mosslet.Encrypted.Session.s3_secret_key_access()
    }

    options = [virtual_host: true, bucket_as_host: true, expires_in: 600]

    with {:ok, presigned_url} <-
           ExAws.S3.presigned_url(config, :get, host_name, file_path, options),
         {:ok, %{status: 200, body: encrypted_binary}} <-
           Req.get(presigned_url, retry: :transient, receive_timeout: 10_000),
         {:ok, d_user_key} <-
           Mosslet.Encrypted.Users.Utils.decrypt_user_attrs_key(user.user_key, user, key),
         {:ok, decrypted_binary} <-
           Mosslet.Encrypted.Utils.decrypt(%{key: d_user_key, payload: encrypted_binary}) do
      "data:image/webp;base64,#{Base.encode64(decrypted_binary)}"
    else
      _ -> nil
    end
  end

  defp load_cover_image_src(_, _, _), do: nil

  defp decrypt_entries(entries, user, key) do
    Enum.map(entries, fn entry ->
      decrypted = Journal.decrypt_entry(entry, user, key)

      entry
      |> Map.put(:decrypted_title, decrypted.title)
      |> Map.put(:decrypted_body, decrypted.body)
    end)
  end

  defp truncate_body(nil), do: ""

  defp truncate_body(body) do
    if String.length(body) > 150 do
      String.slice(body, 0, 150) <> "..."
    else
      body
    end
  end

  defp format_date(date) do
    today = Date.utc_today()

    cond do
      date == today -> "Today"
      date == Date.add(today, -1) -> "Yesterday"
      true -> Calendar.strftime(date, "%b %d, %Y")
    end
  end

  defp is_cover_processing?(nil), do: false
  defp is_cover_processing?({:ready, _}), do: false
  defp is_cover_processing?({:error, _}), do: false
  defp is_cover_processing?(_), do: true

  defp has_pending_cover_upload?([], _stage), do: false
  defp has_pending_cover_upload?(_entries, {:ready, _}), do: false
  defp has_pending_cover_upload?(_entries, _stage), do: true

  defp do_upload_cover(socket) do
    lv_pid = self()
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key
    bucket = Mosslet.Encrypted.Session.memories_bucket()

    socket = assign(socket, :cover_upload_stage, {:receiving, 10})

    cover_results =
      consume_uploaded_entries(
        socket,
        :book_cover,
        fn %{path: path}, entry ->
          send(lv_pid, {:cover_upload_stage, {:receiving, 30}})
          mime_type = ExMarcel.MimeType.for({:path, path})

          if mime_type in [
               "image/jpeg",
               "image/jpg",
               "image/png",
               "image/webp",
               "image/heic",
               "image/heif"
             ] do
            send(lv_pid, {:cover_upload_stage, {:converting, 40}})

            with {:ok, image} <- load_image_for_cover(path, mime_type),
                 {:ok, image} <- autorotate_cover_image(image),
                 _ <- send(lv_pid, {:cover_upload_stage, {:checking, 50}}),
                 {:ok, safe_image} <- check_cover_safety(image),
                 _ <- send(lv_pid, {:cover_upload_stage, {:resizing, 60}}),
                 {:ok, resized_image} <- resize_cover_image(safe_image),
                 {:ok, blob} <-
                   Image.write(resized_image, :memory,
                     suffix: ".webp",
                     quality: 85
                   ),
                 _ <- send(lv_pid, {:cover_upload_stage, {:encrypting, 75}}),
                 {:ok, e_blob} <- prepare_encrypted_cover_blob(blob, user, key),
                 {:ok, file_path} <- prepare_cover_file_path(entry, user.id),
                 _ <- send(lv_pid, {:cover_upload_stage, {:uploading, 85}}) do
              case ExAws.S3.put_object(bucket, file_path, e_blob) |> ExAws.request() do
                {:ok, %{status_code: 200}} ->
                  preview_src = "data:image/webp;base64,#{Base.encode64(blob)}"
                  {:ok, {entry, file_path, preview_src}}

                {:ok, resp} ->
                  {:postpone, {:error, "Upload failed: #{inspect(resp)}"}}

                {:error, reason} ->
                  {:postpone, {:error, reason}}
              end
            else
              {:nsfw, message} ->
                send(lv_pid, {:cover_upload_stage, {:error, message}})
                {:postpone, {:nsfw, message}}

              {:error, message} ->
                send(lv_pid, {:cover_upload_stage, {:error, message}})
                {:postpone, {:error, message}}
            end
          else
            send(lv_pid, {:cover_upload_stage, {:error, "Incorrect file type."}})
            {:postpone, :error}
          end
        end
      )

    case cover_results do
      [nsfw: message] ->
        {:noreply,
         socket
         |> assign(:cover_upload_stage, {:error, message})
         |> put_flash(:warning, message)}

      [error: message] ->
        {:noreply,
         socket
         |> assign(:cover_upload_stage, {:error, message})
         |> put_flash(:warning, message)}

      [:error] ->
        {:noreply,
         socket
         |> assign(:cover_upload_stage, {:error, "Incorrect file type."})
         |> put_flash(:warning, "Incorrect file type.")}

      [{_entry, file_path, preview_src}] ->
        send(lv_pid, {:cover_upload_complete, {:ok, file_path, preview_src}})
        {:noreply, assign(socket, :cover_upload_stage, {:uploading, 95})}

      _rest ->
        error_msg =
          "There was an error trying to upload your cover, please try a different image."

        {:noreply,
         socket
         |> assign(:cover_upload_stage, {:error, error_msg})
         |> put_flash(:warning, error_msg)}
    end
  end

  defp load_image_for_cover(path, mime_type) when mime_type in ["image/heic", "image/heif"] do
    binary = File.read!(path)

    with {:ok, {heic_image, _metadata}} <- Vix.Vips.Operation.heifload_buffer(binary),
         {:ok, materialized} <- materialize_cover_heic(heic_image) do
      {:ok, materialized}
    else
      {:error, _reason} ->
        load_cover_heic_with_sips(path)
    end
  end

  defp load_image_for_cover(path, _mime_type) do
    case Image.open(path) do
      {:ok, image} -> {:ok, image}
      {:error, reason} -> {:error, "Failed to load image: #{inspect(reason)}"}
    end
  end

  defp materialize_cover_heic(image) do
    case Image.to_colorspace(image, :srgb) do
      {:ok, srgb_image} ->
        case Image.write(srgb_image, :memory, suffix: ".png") do
          {:ok, png_binary} -> Image.from_binary(png_binary)
          {:error, _} -> fallback_cover_heic_materialization(srgb_image)
        end

      {:error, _} ->
        fallback_cover_heic_materialization(image)
    end
  end

  defp fallback_cover_heic_materialization(image) do
    case Image.write(image, :memory, suffix: ".png") do
      {:ok, png_binary} ->
        Image.from_binary(png_binary)

      {:error, _} ->
        case Image.write(image, :memory, suffix: ".jpg") do
          {:ok, jpg_binary} -> Image.from_binary(jpg_binary)
          {:error, reason} -> {:error, "Failed to materialize HEIC image: #{inspect(reason)}"}
        end
    end
  end

  defp load_cover_heic_with_sips(path) do
    tmp_png = Path.join(System.tmp_dir!(), "heic_#{:erlang.unique_integer([:positive])}.png")

    result =
      case :os.type() do
        {:unix, :darwin} ->
          case System.cmd("sips", ["-s", "format", "png", path, "--out", tmp_png],
                 stderr_to_stdout: true
               ) do
            {_output, 0} ->
              png_binary = File.read!(tmp_png)
              Image.from_binary(png_binary)

            {_output, _code} ->
              {:error, "HEIC/HEIF files are not supported. Please convert to JPEG or PNG."}
          end

        {:unix, _linux} ->
          case System.cmd("heif-convert", [path, tmp_png], stderr_to_stdout: true) do
            {_output, 0} ->
              png_binary = File.read!(tmp_png)
              Image.from_binary(png_binary)

            {_output, _code} ->
              {:error, "HEIC/HEIF files are not supported. Please convert to JPEG or PNG."}
          end

        _ ->
          {:error, "HEIC/HEIF files are not supported on this platform."}
      end

    File.rm(tmp_png)
    result
  end

  defp check_cover_safety(image) do
    Mosslet.AI.Images.check_for_safety(image)
  end

  defp autorotate_cover_image(image) do
    case Image.autorotate(image) do
      {:ok, {rotated_image, _flags}} -> {:ok, rotated_image}
      {:error, reason} -> {:error, "Failed to autorotate: #{inspect(reason)}"}
    end
  end

  defp resize_cover_image(image) do
    width = Image.width(image)
    height = Image.height(image)
    max_dimension = 1200

    if width > max_dimension or height > max_dimension do
      Image.thumbnail(image, "#{max_dimension}x#{max_dimension}")
    else
      {:ok, image}
    end
  end

  defp prepare_encrypted_cover_blob(blob, user, key) do
    {:ok, d_user_key} =
      Mosslet.Encrypted.Users.Utils.decrypt_user_attrs_key(user.user_key, user, key)

    encrypted = Mosslet.Encrypted.Utils.encrypt(%{key: d_user_key, payload: blob})
    {:ok, encrypted}
  end

  defp prepare_cover_file_path(_entry, user_id) do
    storage_key = Ecto.UUID.generate()
    file_path = "uploads/journal/covers/#{user_id}/#{storage_key}.webp"
    {:ok, file_path}
  end

  attr :entries, :list, required: true
  attr :book_id, :string, required: true
  attr :view_mode, :string, required: true

  defp pages_grid_view(assigns) do
    assigns = assign(assigns, :total_entries, length(assigns.entries))

    ~H"""
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
      <div
        :for={{entry, idx} <- Enum.with_index(@entries)}
        class="group bg-white dark:bg-slate-800/95 rounded-xl p-5 border border-slate-200 dark:border-slate-700 hover:border-emerald-300 dark:hover:border-emerald-600 hover:shadow-lg cursor-pointer transition-all duration-200 relative"
        phx-click={
          JS.navigate(~p"/app/journal/#{entry.id}?scope=book&book_id=#{@book_id}&view=#{@view_mode}")
        }
      >
        <button
          type="button"
          phx-click="delete_entry"
          phx-value-id={entry.id}
          data-confirm="Are you sure you want to delete this entry?"
          class="absolute top-3 right-3 p-1.5 text-slate-400 hover:text-red-500 dark:text-slate-500 dark:hover:text-red-400 opacity-0 group-hover:opacity-100 transition-all rounded-lg hover:bg-red-50 dark:hover:bg-red-950/30 z-10"
          title="Delete entry"
          onclick="event.stopPropagation()"
        >
          <.phx_icon name="hero-trash" class="h-4 w-4" />
        </button>
        <div class="flex flex-col h-full min-h-[320px]">
          <div class="flex items-start justify-between mb-3">
            <div class="flex-1 min-w-0 pr-6">
              <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100 truncate group-hover:text-emerald-600 dark:group-hover:text-emerald-400 transition-colors">
                {entry.decrypted_title || "Untitled"}
              </h2>
              <time class="text-xs text-slate-500 dark:text-slate-400">
                {format_date(entry.entry_date)}
              </time>
            </div>
            <div class="flex items-center gap-1.5 flex-shrink-0 ml-2">
              <span :if={entry.is_favorite} class="text-amber-500 text-sm" title="Favorite">★</span>
              <span :if={entry.mood} class="text-base" title={entry.mood}>
                {DesignSystem.mood_emoji(entry.mood)}
              </span>
            </div>
          </div>

          <div class="relative flex-1 overflow-hidden">
            <div class="text-sm text-slate-600 dark:text-slate-300 leading-relaxed line-clamp-[12]">
              {entry.decrypted_body || ""}
            </div>
            <div class="absolute bottom-0 left-0 right-0 h-16 bg-gradient-to-t from-white dark:from-slate-800/95 to-transparent pointer-events-none" />
          </div>

          <div class="mt-3 pt-2 border-t border-slate-100 dark:border-slate-700/50 flex items-center justify-between">
            <span class="text-xs text-slate-600 dark:text-slate-400">Page {idx + 1}</span>
            <span class="text-xs text-emerald-500 dark:text-emerald-400 opacity-0 group-hover:opacity-100 transition-opacity">
              Read →
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :entries, :list, required: true
  attr :page_spread, :integer, required: true
  attr :book_id, :string, required: true
  attr :view_mode, :string, required: true

  defp book_reading_view(assigns) do
    left_idx = assigns.page_spread * 2
    right_idx = left_idx + 1
    entries = assigns.entries
    total_entries = length(entries)
    max_spread = max(0, div(total_entries - 1, 2))

    assigns =
      assigns
      |> assign(:left_entry, Enum.at(entries, left_idx))
      |> assign(:right_entry, Enum.at(entries, right_idx))
      |> assign(:max_spread, max_spread)
      |> assign(:total_entries, total_entries)
      |> assign(:left_page_num, left_idx + 1)
      |> assign(:right_page_num, right_idx + 1)

    ~H"""
    <div class="relative">
      <div class="flex flex-col md:flex-row gap-4 md:gap-0">
        <.book_page
          entry={@left_entry}
          page_num={@left_page_num}
          total={@total_entries}
          side="left"
          book_id={@book_id}
          view_mode={@view_mode}
          page_spread={@page_spread}
        />
        <div class="hidden md:block w-px bg-gradient-to-b from-transparent via-slate-300 dark:via-slate-600 to-transparent" />
        <.book_page
          :if={@right_entry}
          entry={@right_entry}
          page_num={@right_page_num}
          total={@total_entries}
          side="right"
          book_id={@book_id}
          view_mode={@view_mode}
          page_spread={@page_spread}
        />
        <div
          :if={!@right_entry}
          class="hidden md:flex flex-1 min-h-[400px] bg-slate-50/50 dark:bg-slate-800/30 rounded-r-xl items-center justify-center"
        >
          <p class="text-sm text-slate-400 dark:text-slate-500 italic">End of book</p>
        </div>
      </div>

      <div class="flex items-center justify-between mt-6 px-2">
        <button
          type="button"
          phx-click="flip_page"
          phx-value-direction="prev"
          disabled={@page_spread == 0}
          class={[
            "inline-flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-lg transition-all duration-200",
            if(@page_spread == 0,
              do: "text-slate-300 dark:text-slate-600 cursor-not-allowed",
              else:
                "text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 hover:text-slate-900 dark:hover:text-slate-100"
            )
          ]}
        >
          <.phx_icon name="hero-chevron-left" class="h-5 w-5" /> Previous
        </button>
        <span class="text-sm text-slate-500 dark:text-slate-400">
          Pages {@left_page_num}-{min(@right_page_num, @total_entries)} of {@total_entries}
        </span>
        <button
          type="button"
          phx-click="flip_page"
          phx-value-direction="next"
          disabled={@page_spread >= @max_spread}
          class={[
            "inline-flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-lg transition-all duration-200",
            if(@page_spread >= @max_spread,
              do: "text-slate-300 dark:text-slate-600 cursor-not-allowed",
              else:
                "text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 hover:text-slate-900 dark:hover:text-slate-100"
            )
          ]}
        >
          Next <.phx_icon name="hero-chevron-right" class="h-5 w-5" />
        </button>
      </div>
    </div>
    """
  end

  attr :entry, :map, required: true
  attr :page_num, :integer, required: true
  attr :total, :integer, required: true
  attr :side, :string, required: true
  attr :book_id, :string, required: true
  attr :view_mode, :string, required: true
  attr :page_spread, :integer, required: true

  defp book_page(assigns) do
    ~H"""
    <div
      class={[
        "flex-1 min-h-[400px] bg-white dark:bg-slate-800/95 p-6 cursor-pointer group transition-all duration-200 hover:shadow-lg",
        if(@side == "left",
          do: "rounded-l-xl md:rounded-r-none rounded-xl md:rounded-xl",
          else: "rounded-r-xl md:rounded-l-none rounded-xl md:rounded-xl"
        )
      ]}
      phx-click={
        JS.navigate(
          ~p"/app/journal/#{@entry.id}?scope=book&book_id=#{@book_id}&view=#{@view_mode}&page=#{@page_spread}"
        )
      }
    >
      <div class="flex flex-col h-full">
        <div class="flex items-start justify-between mb-4">
          <div class="flex-1 min-w-0">
            <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100 truncate group-hover:text-emerald-600 dark:group-hover:text-emerald-400 transition-colors">
              {@entry.decrypted_title || "Untitled"}
            </h3>
            <time class="text-xs text-slate-500 dark:text-slate-400">
              {format_date(@entry.entry_date)}
            </time>
          </div>
          <div class="flex items-center gap-2 flex-shrink-0">
            <span :if={@entry.is_favorite} class="text-amber-500" title="Favorite">★</span>
            <span :if={@entry.mood} class="text-lg" title={@entry.mood}>
              {DesignSystem.mood_emoji(@entry.mood)}
            </span>
          </div>
        </div>

        <div class="relative flex-1 overflow-hidden">
          <div class="text-sm text-slate-600 dark:text-slate-300 leading-relaxed whitespace-pre-wrap">
            {truncate_page_body(@entry.decrypted_body)}
          </div>
          <div class="absolute bottom-0 left-0 right-0 h-24 bg-gradient-to-t from-white dark:from-slate-800/95 to-transparent pointer-events-none" />
        </div>

        <div class="mt-4 pt-3 border-t border-slate-100 dark:border-slate-700/50 flex items-center justify-between">
          <span class="text-xs text-slate-400 dark:text-slate-500">Page {@page_num}</span>
          <span class="text-xs text-emerald-500 dark:text-emerald-400 opacity-0 group-hover:opacity-100 transition-opacity">
            Click to read →
          </span>
        </div>
      </div>
    </div>
    """
  end

  defp truncate_page_body(nil), do: ""

  defp truncate_page_body(body) do
    if String.length(body) > 1200 do
      String.slice(body, 0, 1200)
    else
      body
    end
  end
end
