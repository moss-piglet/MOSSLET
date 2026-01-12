defmodule MossletWeb.JournalLive.Index do
  @moduledoc """
  Journal index - displays books and loose entries with stats.
  """
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Journal
  alias Mosslet.Journal.AI, as: JournalAI
  alias Mosslet.Journal.JournalBook
  alias MossletWeb.DesignSystem
  alias MossletWeb.Helpers.JournalHelpers

  @impl true
  def render(assigns) do
    ~H"""
    <.layout type="sidebar" current_scope={@current_scope} current_page={:journal}>
      <div class="max-w-4xl mx-auto pb-8">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-8">
          <div>
            <h1 class="text-2xl font-bold text-slate-900 dark:text-slate-100">
              Journal
            </h1>
            <p class="mt-1 text-sm text-slate-600 dark:text-slate-400">
              Your private space for reflection
            </p>
          </div>

          <div class="flex flex-wrap items-center gap-2">
            <DesignSystem.privacy_button
              active={@privacy_active}
              countdown={@privacy_countdown}
              on_click="activate_privacy"
            />
            <button
              :if={@favorites != []}
              id={"favorites-toggle-#{@current_scope.user.id}"}
              type="button"
              phx-click="toggle_favorites"
              phx-hook="TippyHook"
              data-tippy-content={if @show_favorites, do: "Hide favorites", else: "Show favorites"}
              class={[
                "inline-flex items-center gap-1.5 px-4 py-2.5 text-sm font-medium rounded-xl border shadow-sm transition-all duration-200",
                if(@show_favorites,
                  do:
                    "text-amber-700 dark:text-amber-300 bg-amber-50 dark:bg-amber-900/30 border-amber-200 dark:border-amber-700",
                  else:
                    "text-slate-500 dark:text-slate-400 bg-white dark:bg-slate-800 border-slate-200 dark:border-slate-700 hover:text-amber-600 dark:hover:text-amber-400"
                )
              ]}
            >
              <span class="sr-only">
                {if @show_favorites, do: "Hide favorites", else: "Show favorites"}
              </span>
              <.phx_icon name="hero-star-solid" class="h-4 w-4" />
              <span class="hidden sm:inline">{length(@favorites)}</span>
            </button>
            <button
              type="button"
              phx-click="new_book"
              class="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium text-slate-700 dark:text-slate-300 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl shadow-sm hover:bg-slate-50 dark:hover:bg-slate-700 transition-all duration-200"
            >
              <.phx_icon name="hero-book-open" class="h-4 w-4" /> New Book
            </button>
            <button
              type="button"
              phx-click="show_upload_modal"
              id="upload-handwritten-btn"
              phx-hook="TippyHook"
              data-tippy-content="Upload handwritten journal"
              class="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium text-slate-700 dark:text-slate-300 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl shadow-sm hover:bg-slate-50 dark:hover:bg-slate-700 transition-all duration-200"
            >
              <.phx_icon name="hero-camera" class="h-4 w-4" />
              <span class="sr-only sm:not-sr-only">Upload</span>
            </button>
            <.link
              navigate={~p"/app/journal/new"}
              class="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium text-white bg-gradient-to-r from-teal-500 to-emerald-500 rounded-xl shadow-sm hover:from-teal-600 hover:to-emerald-600 transition-all duration-200"
            >
              <.phx_icon name="hero-pencil-square" class="h-4 w-4" /> New Entry
            </.link>
          </div>
        </div>

        <div class="grid grid-cols-3 gap-4 mb-8">
          <div class="bg-white dark:bg-slate-800 rounded-xl p-4 border border-slate-200 dark:border-slate-700">
            <div class="text-2xl font-bold text-slate-900 dark:text-slate-100">
              {@entry_count}
            </div>
            <div class="text-sm text-slate-600 dark:text-slate-400">Entries</div>
          </div>
          <div class="bg-white dark:bg-slate-800 rounded-xl p-4 border border-slate-200 dark:border-slate-700">
            <div class="text-2xl font-bold text-slate-900 dark:text-slate-100">
              {@total_words}
            </div>
            <div class="text-sm text-slate-600 dark:text-slate-400">Words</div>
          </div>
          <div class="bg-white dark:bg-slate-800 rounded-xl p-4 border border-slate-200 dark:border-slate-700">
            <div class="text-2xl font-bold text-emerald-600 dark:text-emerald-400">
              {@streak} 🔥
            </div>
            <div class="text-sm text-slate-600 dark:text-slate-400">Day streak</div>
          </div>
        </div>

        <div
          :if={@entry_count >= 3}
          class="mb-8 p-4 bg-gradient-to-r from-violet-50 to-purple-50 dark:from-violet-900/20 dark:to-purple-900/20 rounded-xl border border-violet-100 dark:border-violet-800"
        >
          <div class="flex items-start justify-between gap-3">
            <div class="flex items-start gap-3 flex-1">
              <span class="text-lg">🔮</span>
              <div class="flex-1">
                <h2 class="text-sm font-medium text-violet-800 dark:text-violet-200 mb-1">
                  Mood Insights
                </h2>
                <p
                  :if={@mood_insight && !@loading_insights}
                  class="text-sm text-violet-700 dark:text-violet-300 leading-relaxed"
                >
                  {@mood_insight}
                </p>
                <div :if={@loading_insights} class="space-y-2">
                  <p class="text-sm text-violet-600 dark:text-violet-400 italic">
                    {Enum.random([
                      "Reading between the lines of your journal... ✨",
                      "Discovering patterns in your reflections... 🌟",
                      "Connecting the dots of your journey... 💫",
                      "Finding the story in your words... 📖",
                      "Brewing some insights just for you... ☕"
                    ])}
                  </p>
                  <div class="flex gap-1">
                    <div class="w-2 h-2 rounded-full bg-violet-400 animate-bounce [animation-delay:-0.3s]" />
                    <div class="w-2 h-2 rounded-full bg-violet-400 animate-bounce [animation-delay:-0.15s]" />
                    <div class="w-2 h-2 rounded-full bg-violet-400 animate-bounce" />
                  </div>
                </div>
              </div>
            </div>
            <div :if={!@loading_insights} class="flex flex-col items-end gap-1">
              <button
                type="button"
                phx-click="refresh_insights"
                disabled={!@can_refresh}
                class={[
                  "p-1.5 rounded-lg transition-all",
                  @can_refresh &&
                    "text-violet-400 hover:text-violet-600 hover:bg-violet-100 dark:hover:text-violet-300 dark:hover:bg-violet-800/50",
                  !@can_refresh && "text-violet-300 dark:text-violet-600 cursor-not-allowed"
                ]}
                title={
                  if @can_refresh,
                    do: "Get fresh insights",
                    else: "Available in #{@hours_until_refresh}h"
                }
              >
                <.phx_icon name="hero-sparkles" class="h-4 w-4" />
              </button>
              <span
                :if={!@can_refresh && @hours_until_refresh > 0}
                class="text-[10px] text-violet-400 dark:text-violet-500"
              >
                {if @hours_until_refresh > 0, do: "#{@hours_until_refresh}h", else: ""}
              </span>
            </div>
          </div>
        </div>

        <div :if={@books != []} class="mb-8">
          <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100 mb-4">Books</h2>
          <div class="grid grid-cols-2 sm:grid-cols-3 gap-4">
            <div
              :for={book <- @books}
              class="group relative bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 overflow-hidden hover:border-emerald-300 dark:hover:border-emerald-600 transition-all cursor-pointer"
              phx-click={JS.navigate(~p"/app/journal/books/#{book.id}")}
            >
              <%= if book.decrypted_cover_image_url do %>
                <div class="aspect-[4/3]">
                  <img
                    src={book.decrypted_cover_image_url}
                    class="w-full h-full object-cover"
                    alt={"#{book.decrypted_title} cover"}
                  />
                </div>
              <% else %>
                <div class={[
                  "aspect-[4/3] flex items-center justify-center",
                  book_cover_gradient(book.cover_color)
                ]}>
                  <.phx_icon
                    name="hero-book-open"
                    class="h-10 w-10 text-white/80 group-hover:scale-110 transition-transform"
                  />
                </div>
              <% end %>
              <div class="p-3">
                <h3 class="font-medium text-slate-900 dark:text-slate-100 truncate">
                  {book.decrypted_title}
                </h3>
                <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
                  {book.entry_count} {if book.entry_count == 1, do: "entry", else: "entries"}
                </p>
              </div>
              <button
                id={"tooltip-add-entry-to-book-#{book.id}"}
                type="button"
                phx-click="new_entry_in_book"
                phx-value-book-id={book.id}
                phx-hook="TippyHook"
                data-tippy-content="Add entry to book"
                aria-label="Add entry to book"
                class="absolute top-2 right-2 p-1.5 bg-white dark:bg-slate-800 rounded-lg shadow-md opacity-0 group-hover:opacity-100 transition-opacity hover:bg-slate-50 dark:hover:bg-slate-700 ring-1 ring-black/10 dark:ring-white/10"
              >
                <.phx_icon name="hero-plus" class="h-4 w-4 text-slate-700 dark:text-slate-300" />
              </button>
            </div>
          </div>
        </div>

        <div :if={@show_favorites && @favorites != []} class="mb-8">
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
              Favorites
            </h2>
            <span class="text-sm text-slate-500 dark:text-slate-400">
              {length(@favorites)} starred
            </span>
          </div>
          <div class="space-y-3">
            <div
              :for={entry <- @favorites}
              class="group bg-white dark:bg-slate-800 rounded-xl p-4 border border-slate-200 dark:border-slate-700 hover:border-amber-300 dark:hover:border-amber-600 transition-colors cursor-pointer"
              phx-click={JS.navigate(~p"/app/journal/#{entry.id}")}
            >
              <div class="flex items-start justify-between gap-4">
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2 mb-1">
                    <h3 class="text-base font-medium text-slate-900 dark:text-slate-100 truncate">
                      {entry.decrypted_title || "Untitled"}
                    </h3>
                    <span class="text-amber-500">★</span>
                  </div>
                  <p class="text-sm text-slate-600 dark:text-slate-400 line-clamp-2">
                    {truncate_body(entry.decrypted_body)}
                  </p>
                </div>
                <div class="flex flex-col items-end gap-1">
                  <time class="text-xs text-slate-500 dark:text-slate-400">
                    {format_date(entry.entry_date)}
                  </time>
                  <span :if={entry.mood} class="text-lg" title={entry.mood}>
                    {mood_emoji(entry.mood)}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div :if={@entries == [] && @books == []} class="text-center py-16">
          <.phx_icon
            name="hero-book-open"
            class="h-12 w-12 mx-auto text-slate-400 dark:text-slate-500 mb-4"
          />
          <h2 class="text-lg font-medium text-slate-900 dark:text-slate-100 mb-2">
            Start your journal
          </h2>
          <p class="text-slate-600 dark:text-slate-400 mb-6">
            Capture your thoughts, feelings, and moments in a private space.
          </p>
          <div class="flex items-center justify-center gap-3">
            <button
              type="button"
              phx-click="new_book"
              class="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium text-slate-700 dark:text-slate-300 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl shadow-sm hover:bg-slate-50 dark:hover:bg-slate-700 transition-all duration-200"
            >
              <.phx_icon name="hero-book-open" class="h-4 w-4" /> Create a book
            </button>
            <.link
              navigate={~p"/app/journal/new"}
              class="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium text-white bg-gradient-to-r from-teal-500 to-emerald-500 rounded-xl shadow-sm hover:from-teal-600 hover:to-emerald-600 transition-all duration-200"
            >
              <.phx_icon name="hero-pencil-square" class="h-4 w-4" /> Write your first entry
            </.link>
          </div>
        </div>

        <div :if={@entries != []}>
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
              {if @books != [], do: "Loose Entries", else: "Entries"}
            </h2>
            <span class="text-sm text-slate-500 dark:text-slate-400">
              {if @books != [], do: "#{@loose_entry_count} not in a book", else: ""}
            </span>
          </div>
          <div class="space-y-3">
            <div
              :for={entry <- @entries}
              class="group bg-white dark:bg-slate-800 rounded-xl p-4 border border-slate-200 dark:border-slate-700 hover:border-emerald-300 dark:hover:border-emerald-600 transition-colors cursor-pointer"
              phx-click={JS.navigate(~p"/app/journal/#{entry.id}")}
            >
              <div class="flex items-start justify-between gap-4">
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2 mb-1">
                    <h3 class="text-base font-medium text-slate-900 dark:text-slate-100 truncate">
                      {entry.decrypted_title || "Untitled"}
                    </h3>
                    <span
                      :if={entry.is_favorite}
                      class="text-amber-500"
                      title="Favorite"
                    >
                      ★
                    </span>
                  </div>
                  <p class="text-sm text-slate-600 dark:text-slate-400 line-clamp-2">
                    {truncate_body(entry.decrypted_body)}
                  </p>
                </div>
                <div class="flex items-center gap-2 flex-shrink-0">
                  <button
                    :if={@books != []}
                    type="button"
                    id={"move-entry-#{entry.id}"}
                    phx-click={JS.push("show_move_modal", value: %{entry_id: entry.id})}
                    phx-hook="TippyHook"
                    data-tippy-content="Move to book"
                    aria-label="Move to book"
                    class="p-1.5 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg sm:opacity-0 sm:group-hover:opacity-100 transition-all"
                  >
                    <.phx_icon name="hero-folder-plus" class="h-4 w-4" />
                  </button>
                  <div class="flex flex-col items-end gap-1">
                    <time class="text-xs text-slate-500 dark:text-slate-400">
                      {format_date(entry.entry_date)}
                    </time>
                    <span
                      :if={entry.mood}
                      class="text-lg"
                      title={entry.mood}
                    >
                      {mood_emoji(entry.mood)}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div :if={@has_more} class="mt-6 text-center">
          <button
            phx-click="load_more"
            class="px-4 py-2 text-sm font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100 transition-colors"
          >
            Load more
          </button>
        </div>
      </div>

      <.liquid_modal
        :if={@show_book_modal}
        id="book-modal"
        show={@show_book_modal}
        on_cancel={JS.push("cancel_book_modal")}
        size="md"
      >
        <:title>{if @editing_book, do: "Edit Book", else: "New Book"}</:title>
        <.form for={@book_form} id="book-form" phx-change="validate_book" phx-submit="save_book">
          <div class="space-y-6">
            <p class="text-sm text-slate-600 dark:text-slate-400">
              Create a book to organize related journal entries
            </p>

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
                    book_cover_gradient(color),
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
                  />
                  <span class="sr-only">{Phoenix.Naming.humanize(color)} cover color</span>
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

            <div class="flex justify-end gap-3 pt-4">
              <button
                type="button"
                phx-click="cancel_book_modal"
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
                {if @editing_book, do: "Update", else: "Create Book"}
              </button>
            </div>
          </div>
        </.form>
      </.liquid_modal>

      <.liquid_modal
        :if={@show_move_modal}
        id="move-modal"
        show={@show_move_modal}
        on_cancel={JS.push("cancel_move_modal")}
        size="md"
      >
        <:title>Move to Book</:title>
        <div class="space-y-6">
          <p class="text-sm text-slate-600 dark:text-slate-400">
            Select a book to move this entry into
          </p>

          <div class="space-y-2">
            <button
              :for={book <- @books}
              type="button"
              phx-click="move_to_book"
              phx-value-book-id={book.id}
              class="w-full flex items-center gap-3 p-3 rounded-xl border border-slate-200 dark:border-slate-700 hover:border-emerald-300 dark:hover:border-emerald-600 hover:bg-slate-50 dark:hover:bg-slate-800 transition-all text-left"
            >
              <div class={[
                "h-10 w-10 rounded-lg flex items-center justify-center flex-shrink-0",
                book_cover_gradient(book.cover_color)
              ]}>
                <.phx_icon name="hero-book-open" class="h-5 w-5 text-white/80" />
              </div>
              <div class="flex-1 min-w-0">
                <div class="font-medium text-slate-900 dark:text-slate-100 truncate">
                  {book.decrypted_title}
                </div>
                <div class="text-xs text-slate-500 dark:text-slate-400">
                  {book.entry_count} {if book.entry_count == 1, do: "entry", else: "entries"}
                </div>
              </div>
            </button>
          </div>

          <div class="flex justify-end pt-2">
            <button
              type="button"
              phx-click="cancel_move_modal"
              class="px-4 py-2 text-sm font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100 transition-colors"
            >
              Cancel
            </button>
          </div>
        </div>
      </.liquid_modal>

      <.liquid_modal
        :if={@show_upload_modal}
        id="upload-modal"
        show={@show_upload_modal}
        on_cancel={JS.push("cancel_upload_modal")}
        size="lg"
      >
        <:title>Upload Handwritten Entry</:title>
        <div class="space-y-6">
          <%= if @upload_step == :upload do %>
            <.form
              for={%{}}
              phx-change="validate_upload"
              phx-submit="digitize_uploads"
              id="upload-form"
            >
              <div
                id="upload-drop-zone"
                phx-hook="SortableUploadsHook"
                class="relative border-2 border-dashed border-slate-300 dark:border-slate-600 rounded-xl overflow-hidden hover:border-teal-400 dark:hover:border-teal-500 phx-drop-target-active:border-teal-500 phx-drop-target-active:bg-teal-50 dark:phx-drop-target-active:bg-teal-900/20 transition-colors"
                phx-drop-target={@uploads.journal_image.ref}
              >
                <div id="upload-resize-wrapper" phx-hook="ImageResizeUploadHook">
                  <.live_file_input upload={@uploads.journal_image} class="sr-only" />
                </div>
                <%= if @uploads.journal_image.entries == [] do %>
                  <label for={@uploads.journal_image.ref} class="block p-8 text-center cursor-pointer">
                    <div class="space-y-4">
                      <div class="mx-auto w-12 h-12 rounded-full bg-slate-100 dark:bg-slate-800 flex items-center justify-center">
                        <.phx_icon name="hero-camera" class="h-6 w-6 text-slate-400" />
                      </div>
                      <div>
                        <span class="text-sm font-medium text-teal-700 dark:text-teal-300">
                          Choose photos
                        </span>
                        <p class="text-xs text-slate-600 dark:text-slate-400 mt-1">
                          or drag and drop
                        </p>
                      </div>
                      <p class="text-xs text-slate-500 dark:text-slate-400">
                        PNG, JPG or HEIC up to 10MB each • Up to 10 pages
                      </p>
                    </div>
                  </label>
                <% else %>
                  <div class="p-4">
                    <div class="grid grid-cols-3 gap-3" data-sortable-container>
                      <div
                        :for={entry <- ordered_entries(@uploads.journal_image.entries, @page_order)}
                        data-sortable-item
                        data-ref={entry.ref}
                        class="relative aspect-[4/3] rounded-lg overflow-hidden bg-slate-100 dark:bg-slate-800 cursor-grab active:cursor-grabbing select-none"
                      >
                        <.live_img_preview
                          entry={entry}
                          class="w-full h-full object-cover pointer-events-none"
                          alt={"Journal page #{get_page_number(entry.ref, @uploads.journal_image.entries, @page_order)} preview"}
                        />
                        <% processing_status = Map.get(@processing_images, to_string(entry.ref)) %>
                        <%= cond do %>
                          <% processing_status && elem(processing_status, 0) == :ready -> %>
                            <div class="absolute top-1.5 left-1.5 p-1 bg-emerald-500 rounded-full">
                              <.phx_icon name="hero-check-mini" class="h-3 w-3 text-white" />
                            </div>
                          <% processing_status && elem(processing_status, 0) == :error -> %>
                            <div class="absolute inset-0 bg-red-900/80 flex flex-col items-center justify-center gap-2 p-2">
                              <div class="p-1.5 bg-red-500 rounded-full">
                                <.phx_icon
                                  name="hero-exclamation-triangle-mini"
                                  class="h-4 w-4 text-white"
                                />
                              </div>
                              <span class="text-xs text-white font-medium text-center">
                                {elem(processing_status, 1)}
                              </span>
                            </div>
                          <% processing_status -> %>
                            <div class="absolute inset-0 bg-slate-900/70 flex flex-col items-center justify-center gap-2">
                              <div class="w-6 h-6 border-2 border-teal-400 border-t-transparent rounded-full animate-spin" />
                              <span class="text-xs text-white font-medium">
                                {format_processing_stage(processing_status)}
                              </span>
                              <span class="text-xs text-white/60">
                                {elem(processing_status, 1)}%
                              </span>
                            </div>
                          <% entry.progress < 100 -> %>
                            <div class="absolute inset-0 bg-slate-200 dark:bg-slate-700 flex flex-col items-center justify-center gap-2">
                              <div class="w-6 h-6 border-2 border-teal-500 border-t-transparent rounded-full animate-spin" />
                              <span class="text-xs text-slate-500 dark:text-slate-400">
                                Uploading {entry.progress}%
                              </span>
                            </div>
                          <% true -> %>
                        <% end %>
                        <div class="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent pointer-events-none" />
                        <div class="absolute bottom-1.5 left-1.5 right-1.5 flex items-center justify-between pointer-events-none">
                          <p class="text-xs text-white font-medium truncate">
                            Page {get_page_number(
                              entry.ref,
                              @uploads.journal_image.entries,
                              @page_order
                            )}
                          </p>
                          <.phx_icon name="hero-arrows-up-down" class="h-3.5 w-3.5 text-white/70" />
                        </div>
                        <button
                          type="button"
                          phx-click="cancel_upload"
                          phx-value-ref={entry.ref}
                          aria-label="Remove image"
                          class="absolute top-1.5 right-1.5 p-1 bg-black/50 hover:bg-black/70 rounded-full text-white transition-colors z-10"
                        >
                          <.phx_icon name="hero-x-mark" class="h-3.5 w-3.5" />
                        </button>
                        <div
                          :for={err <- upload_errors(@uploads.journal_image, entry)}
                          class="absolute inset-x-1.5 top-1.5 px-2 py-1 bg-red-500/90 text-white text-xs rounded"
                        >
                          {upload_error_to_string(err)}
                        </div>
                      </div>
                    </div>
                    <label
                      :if={length(@uploads.journal_image.entries) < 10}
                      for={@uploads.journal_image.ref}
                      class="mt-3 flex items-center justify-center gap-2 p-2 rounded-lg border-2 border-dashed border-slate-300 dark:border-slate-600 cursor-pointer hover:border-teal-400 dark:hover:border-teal-500 transition-colors"
                    >
                      <.phx_icon name="hero-plus" class="h-4 w-4 text-slate-400" />
                      <span class="text-xs text-slate-500 dark:text-slate-400">Add more pages</span>
                    </label>
                    <p class="mt-3 text-xs text-slate-500 dark:text-slate-400 text-center">
                      {length(@uploads.journal_image.entries)} of 10 pages • Drag images to reorder
                    </p>
                  </div>
                <% end %>
              </div>

              <div
                :for={err <- upload_errors(@uploads.journal_image)}
                class="mt-2 text-sm text-red-600"
              >
                {upload_error_to_string(err)}
              </div>

              <div class="mt-6 flex items-start gap-3 p-4 bg-emerald-50 dark:bg-emerald-900/20 rounded-xl border border-emerald-100 dark:border-emerald-800">
                <div class="flex-shrink-0 w-8 h-8 rounded-full bg-emerald-100 dark:bg-emerald-800/50 flex items-center justify-center">
                  <.phx_icon
                    name="hero-lock-closed"
                    class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
                  />
                </div>
                <div>
                  <p class="text-sm font-medium text-emerald-800 dark:text-emerald-200">
                    Your privacy is protected
                  </p>
                  <p class="text-xs text-emerald-700 dark:text-emerald-300 mt-0.5">
                    Your photos are processed securely and deleted immediately after digitizing. The extracted text is encrypted with your personal key—only you can read it.
                  </p>
                </div>
              </div>

              <div :if={@uploads.journal_image.entries != []} class="mt-6 flex justify-end gap-3">
                <button
                  type="button"
                  phx-click="cancel_upload_modal"
                  class="px-4 py-2 text-sm font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100 transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={Enum.any?(@uploads.journal_image.entries, &(&1.progress < 100))}
                  class={[
                    "inline-flex items-center gap-2 px-6 py-2.5 text-sm font-medium text-white rounded-xl shadow-sm transition-all duration-200",
                    if(Enum.any?(@uploads.journal_image.entries, &(&1.progress < 100)),
                      do: "bg-slate-400 cursor-not-allowed",
                      else:
                        "bg-gradient-to-r from-teal-500 to-emerald-500 hover:from-teal-600 hover:to-emerald-600"
                    )
                  ]}
                >
                  <.phx_icon name="hero-sparkles" class="h-4 w-4" /> Digitize
                </button>
              </div>
            </.form>
          <% end %>

          <%= if @upload_step == :processing do %>
            <div class="py-8 text-center">
              <div class="relative inline-flex items-center justify-center w-20 h-20 mb-6">
                <div class="absolute inset-0 rounded-full bg-gradient-to-r from-teal-500 to-emerald-500 opacity-20 animate-ping" />
                <div class="absolute inset-2 rounded-full bg-gradient-to-r from-teal-100 to-emerald-100 dark:from-teal-900/30 dark:to-emerald-900/30" />
                <div class="relative w-10 h-10 border-4 border-teal-500 border-t-transparent rounded-full animate-spin" />
              </div>
              <p class="text-base font-medium text-slate-900 dark:text-slate-100 mb-2">
                {upload_stage_text(@upload_stage, @total_images)}
              </p>
              <p :if={@total_images > 1} class="text-sm text-slate-600 dark:text-slate-400 mb-3">
                Processing page {@processed_images} of {@total_images}
              </p>
              <div class="w-full max-w-xs mx-auto mb-4">
                <div class="h-2 bg-slate-200 dark:bg-slate-700 rounded-full overflow-hidden">
                  <div
                    class="h-full bg-gradient-to-r from-teal-500 to-emerald-500 rounded-full transition-all duration-300"
                    style={"width: #{@upload_progress}%"}
                  />
                </div>
                <p class="text-xs text-slate-500 dark:text-slate-400 mt-2">
                  {@upload_progress}% complete
                </p>
              </div>
              <div class="flex justify-center gap-1.5">
                <div class="w-2 h-2 rounded-full bg-teal-500 animate-bounce [animation-delay:-0.3s]" />
                <div class="w-2 h-2 rounded-full bg-teal-500 animate-bounce [animation-delay:-0.15s]" />
                <div class="w-2 h-2 rounded-full bg-teal-500 animate-bounce" />
              </div>
            </div>
          <% end %>

          <%= if @upload_step == :preview do %>
            <.form for={@extracted_form} id="extracted-form" phx-submit="save_extracted_entry">
              <div class="space-y-4">
                <div>
                  <.phx_input
                    field={@extracted_form[:title]}
                    type="text"
                    label="Title (optional)"
                    placeholder="Give your entry a title"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">
                    Entry Date
                  </label>
                  <div class="relative">
                    <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                      <.phx_icon name="hero-calendar" class="h-4 w-4 text-slate-400" />
                    </div>
                    <input
                      type="date"
                      name="extracted[entry_date]"
                      value={
                        if @extracted_date,
                          do: Date.to_iso8601(@extracted_date),
                          else: Date.to_iso8601(Date.utc_today())
                      }
                      class="w-full pl-10 pr-3 py-2.5 text-sm text-slate-900 dark:text-slate-100 bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-600 rounded-xl focus:ring-2 focus:ring-teal-500 focus:border-teal-500 transition-colors [&::-webkit-calendar-picker-indicator]:opacity-0 [&::-webkit-calendar-picker-indicator]:absolute [&::-webkit-calendar-picker-indicator]:inset-0 [&::-webkit-calendar-picker-indicator]:w-full [&::-webkit-calendar-picker-indicator]:cursor-pointer"
                    />
                  </div>
                  <p
                    :if={@extracted_date}
                    class="mt-1.5 text-xs text-emerald-600 dark:text-emerald-400 flex items-center gap-1"
                  >
                    <.phx_icon name="hero-sparkles-mini" class="h-3 w-3" />
                    Date detected from your entry
                  </p>
                </div>

                <div>
                  <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">
                    Extracted Text
                  </label>
                  <textarea
                    name="extracted[body]"
                    rows="10"
                    class="w-full px-3 py-2 text-sm text-slate-900 dark:text-slate-100 bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-600 rounded-lg focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                    placeholder="Extracted text will appear here..."
                  >{@extracted_form[:body].value}</textarea>
                  <p class="mt-1 text-xs text-slate-500 dark:text-slate-400">
                    Review and edit the extracted text before saving
                  </p>
                </div>

                <div :if={@books != []}>
                  <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">
                    Add to Book (optional)
                  </label>
                  <select
                    name="extracted[book_id]"
                    class="w-full px-3 py-2 text-sm text-slate-900 dark:text-slate-100 bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-600 rounded-lg focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                  >
                    <option value="">No book (loose entry)</option>
                    <option :for={book <- @books} value={book.id}>
                      {book.decrypted_title}
                    </option>
                  </select>
                </div>
              </div>

              <div class="flex justify-end gap-3 pt-6">
                <button
                  type="button"
                  phx-click="cancel_upload_modal"
                  class="px-4 py-2 text-sm font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100 transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="px-6 py-2.5 text-sm font-medium text-white bg-gradient-to-r from-teal-500 to-emerald-500 rounded-xl shadow-sm hover:from-teal-600 hover:to-emerald-600 transition-all duration-200"
                >
                  Save Entry
                </button>
              </div>
            </.form>
          <% end %>

          <%= if @upload_step == :error do %>
            <div class="py-8 text-center">
              <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-red-100 dark:bg-red-900/30 mb-4">
                <.phx_icon name="hero-exclamation-triangle" class="h-8 w-8 text-red-500" />
              </div>
              <p class="text-sm font-medium text-slate-900 dark:text-slate-100 mb-1">
                Couldn't read the image
              </p>
              <p class="text-xs text-slate-500 dark:text-slate-400 mb-4">
                {@upload_error || "Please try with a clearer photo of your handwriting"}
              </p>
              <button
                type="button"
                phx-click="retry_upload"
                class="px-4 py-2 text-sm font-medium text-teal-600 dark:text-teal-400 hover:text-teal-700 dark:hover:text-teal-300 transition-colors"
              >
                Try Again
              </button>
            </div>
          <% end %>
        </div>
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

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    books = Journal.list_books(user)
    decrypted_books = decrypt_books(books, user, key)

    entries = Journal.list_loose_entries(user, limit: 20)
    decrypted_entries = decrypt_entries(entries, user, key)

    entry_count = Journal.count_entries(user)
    loose_entry_count = Journal.count_loose_entries(user)

    favorites = Journal.list_favorite_entries(user, limit: 10)
    decrypted_favorites = decrypt_entries(favorites, user, key)

    local_today = JournalHelpers.get_local_today(socket)

    socket =
      socket
      |> assign(:page_title, "Journal")
      |> assign(:books, decrypted_books)
      |> assign(:entries, decrypted_entries)
      |> assign(:favorites, decrypted_favorites)
      |> assign(:show_favorites, false)
      |> assign(:entry_count, entry_count)
      |> assign(:loose_entry_count, loose_entry_count)
      |> assign(:total_words, Journal.total_word_count(user))
      |> assign(:streak, Journal.streak_days(user, local_today))
      |> assign(:offset, 20)
      |> assign(:has_more, length(entries) == 20)
      |> assign(:mood_insight, nil)
      |> assign(:loading_insights, false)
      |> assign(:cached_insight, nil)
      |> assign(:can_refresh, true)
      |> assign(:hours_until_refresh, 0)
      |> assign(:show_book_modal, false)
      |> assign(:book_form, nil)
      |> assign(:editing_book, nil)
      |> assign(:cover_upload_stage, nil)
      |> assign(:current_cover_src, nil)
      |> assign(:cover_loading, false)
      |> assign(:show_move_modal, false)
      |> assign(:moving_entry_id, nil)
      |> assign(:show_upload_modal, false)
      |> assign(:upload_step, :upload)
      |> assign(:upload_progress, 0)
      |> assign(:upload_stage, nil)
      |> assign(:extracted_form, nil)
      |> assign(:extracted_date, nil)
      |> assign(:upload_error, nil)
      |> assign(:processing_images, %{})
      |> assign(:total_images, 0)
      |> assign(:processed_images, 0)
      |> JournalHelpers.assign_privacy_state(user)
      |> allow_upload(:journal_image,
        accept: ~w(.jpg .jpeg .png .heic),
        max_entries: 10,
        max_file_size: 10 * 1024 * 1024,
        auto_upload: true,
        progress: &handle_journal_upload_progress/3,
        writer: fn _name, entry, _socket ->
          {Mosslet.FileUploads.JournalImageWriter,
           %{
             lv_pid: self(),
             entry_ref: entry.ref,
             mime_type: entry.client_type,
             expected_size: entry.client_size
           }}
        end
      )
      |> allow_upload(:book_cover,
        accept: ~w(.jpg .jpeg .png .webp .heic .heif),
        max_entries: 1,
        max_file_size: 5 * 1024 * 1024,
        auto_upload: true,
        chunk_size: 64_000,
        chunk_timeout: 30_000
      )
      |> assign(:page_order, [])

    if connected?(socket) && entry_count >= 3 do
      send(self(), :load_cached_insight)
      {:ok, assign(socket, :loading_insights, true)}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key
    offset = socket.assigns.offset

    new_entries = Journal.list_loose_entries(user, limit: 20, offset: offset)
    decrypted_new = decrypt_entries(new_entries, user, key)

    {:noreply,
     socket
     |> assign(:entries, socket.assigns.entries ++ decrypted_new)
     |> assign(:offset, offset + 20)
     |> assign(:has_more, length(new_entries) == 20)}
  end

  @impl true
  def handle_event("toggle_favorites", _params, socket) do
    {:noreply, assign(socket, :show_favorites, !socket.assigns.show_favorites)}
  end

  @impl true
  def handle_event("refresh_insights", _params, socket) do
    cached_insight = socket.assigns.cached_insight

    if Journal.can_manually_refresh_insight?(cached_insight) do
      send(self(), :generate_new_insight)
      {:noreply, assign(socket, :loading_insights, true)}
    else
      hours = Journal.hours_until_manual_refresh(cached_insight)

      {:noreply,
       socket
       |> put_flash(
         :info,
         "New insights available in #{hours} hour#{if hours == 1, do: "", else: "s"} ✨"
       )}
    end
  end

  @impl true
  def handle_event("new_book", _params, socket) do
    changeset = Journal.change_book(%JournalBook{cover_color: "emerald"})

    {:noreply,
     socket
     |> assign(:show_book_modal, true)
     |> assign(:editing_book, nil)
     |> assign(:book_form, to_form(changeset, as: :journal_book))
     |> assign(:cover_upload_stage, nil)
     |> assign(:current_cover_src, nil)
     |> assign(:pending_cover_path, nil)
     |> assign(:cover_loading, false)}
  end

  @impl true
  def handle_event("validate_book", %{"journal_book" => params}, socket) do
    changeset =
      %JournalBook{}
      |> Journal.change_book(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :book_form, to_form(changeset, as: :journal_book))}
  end

  @impl true
  def handle_event("save_book", %{"journal_book" => params}, socket) do
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    cover_file_path = socket.assigns[:pending_cover_path]
    consume_uploaded_entries(socket, :book_cover, fn _meta, _entry -> {:ok, nil} end)

    case Journal.create_book(user, params, key) do
      {:ok, book} ->
        book =
          if cover_file_path do
            case Journal.update_book_cover_image(book, cover_file_path, user, key) do
              {:ok, updated} -> updated
              {:error, _} -> book
            end
          else
            book
          end

        decrypted_book =
          book
          |> Map.put(:entry_count, 0)
          |> decrypt_book(user, key)

        {:noreply,
         socket
         |> assign(:show_book_modal, false)
         |> assign(:book_form, nil)
         |> assign(:cover_upload_stage, nil)
         |> assign(:current_cover_src, nil)
         |> assign(:pending_cover_path, nil)
         |> assign(:books, [decrypted_book | socket.assigns.books])
         |> put_flash(:info, "Book created")
         |> push_event("restore-body-scroll", %{})}

      {:error, changeset} ->
        {:noreply, assign(socket, :book_form, to_form(changeset, as: :journal_book))}
    end
  end

  @impl true
  def handle_event("cancel_book_modal", _params, socket) do
    socket =
      Enum.reduce(socket.assigns.uploads.book_cover.entries, socket, fn entry, acc ->
        cancel_upload(acc, :book_cover, entry.ref)
      end)

    {:noreply,
     socket
     |> assign(:show_book_modal, false)
     |> assign(:book_form, nil)
     |> assign(:editing_book, nil)
     |> assign(:cover_upload_stage, nil)
     |> assign(:current_cover_src, nil)
     |> assign(:pending_cover_path, nil)
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
  def handle_event("remove_cover", _params, socket) do
    socket =
      Enum.reduce(socket.assigns.uploads.book_cover.entries, socket, fn entry, acc ->
        cancel_upload(acc, :book_cover, entry.ref)
      end)

    {:noreply,
     socket
     |> assign(:current_cover_src, nil)
     |> assign(:pending_cover_path, nil)
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
  def handle_event("new_entry_in_book", %{"book-id" => book_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/app/journal/new?book_id=#{book_id}")}
  end

  @impl true
  def handle_event("show_move_modal", %{"entry_id" => entry_id}, socket) do
    {:noreply,
     socket
     |> assign(:show_move_modal, true)
     |> assign(:moving_entry_id, entry_id)}
  end

  @impl true
  def handle_event("cancel_move_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_move_modal, false)
     |> assign(:moving_entry_id, nil)
     |> push_event("restore-body-scroll", %{})}
  end

  @impl true
  def handle_event("move_to_book", %{"book-id" => book_id}, socket) do
    user = socket.assigns.current_scope.user
    entry_id = socket.assigns.moving_entry_id

    entry = Enum.find(socket.assigns.entries, &(&1.id == entry_id))

    case Journal.move_entry_to_book(entry, book_id, user) do
      {:ok, _} ->
        books =
          Enum.map(socket.assigns.books, fn book ->
            if book.id == book_id do
              %{book | entry_count: book.entry_count + 1}
            else
              book
            end
          end)

        {:noreply,
         socket
         |> assign(:show_move_modal, false)
         |> assign(:moving_entry_id, nil)
         |> assign(:entries, Enum.reject(socket.assigns.entries, &(&1.id == entry_id)))
         |> assign(:books, books)
         |> assign(:loose_entry_count, socket.assigns.loose_entry_count - 1)
         |> put_flash(:info, "Entry moved to book")
         |> push_event("restore-body-scroll", %{})}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:show_move_modal, false)
         |> assign(:moving_entry_id, nil)
         |> put_flash(:error, "Could not move entry")
         |> push_event("restore-body-scroll", %{})}
    end
  end

  @impl true
  def handle_event("show_upload_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_upload_modal, true)
     |> assign(:upload_step, :upload)
     |> assign(:extracted_form, nil)
     |> assign(:upload_error, nil)}
  end

  @impl true
  def handle_event("cancel_upload_modal", _params, socket) do
    socket =
      Enum.reduce(socket.assigns.uploads.journal_image.entries, socket, fn entry, acc ->
        cancel_upload(acc, :journal_image, entry.ref)
      end)

    {:noreply,
     socket
     |> assign(:show_upload_modal, false)
     |> assign(:upload_step, :upload)
     |> assign(:upload_progress, 0)
     |> assign(:upload_stage, nil)
     |> assign(:extracted_form, nil)
     |> assign(:extracted_date, nil)
     |> assign(:upload_error, nil)
     |> assign(:processing_images, %{})
     |> assign(:total_images, 0)
     |> assign(:processed_images, 0)
     |> assign(:page_order, [])
     |> push_event("restore-body-scroll", %{})}
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    for entry <- socket.assigns.uploads.journal_image.entries do
      require Logger

      Logger.info(
        "Upload entry: #{entry.client_name} - client_size: #{entry.client_size} bytes (#{Float.round(entry.client_size / 1024 / 1024, 2)} MB), valid?: #{entry.valid?}"
      )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("reorder_uploads", %{"order" => order}, socket) do
    {:noreply, assign(socket, :page_order, order)}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply,
     socket
     |> cancel_upload(:journal_image, ref)
     |> assign(:upload_step, :upload)
     |> assign(:upload_progress, 0)
     |> assign(:upload_stage, nil)}
  end

  @impl true
  def handle_event("digitize_uploads", _params, socket) do
    entries =
      ordered_entries(socket.assigns.uploads.journal_image.entries, socket.assigns.page_order)

    total = length(entries)

    socket =
      socket
      |> assign(:upload_step, :processing)
      |> assign(:total_images, total)
      |> assign(:processed_images, 0)
      |> assign(:upload_progress, 5)
      |> assign(:upload_stage, :extracting)

    results =
      Enum.map(entries, fn entry ->
        consume_uploaded_entry(socket, entry, fn meta ->
          case meta do
            %{extracted_text: text, extracted_date: date} ->
              {:ok, {:ok, text, date}}

            %{error: :no_text_found} ->
              {:ok, {:error, "No readable text was found in the image. Try a clearer photo."}}

            %{error: reason} ->
              {:ok, {:error, "Something went wrong: #{inspect(reason)}"}}

            _ ->
              {:ok, {:error, "Processing not complete. Please try again."}}
          end
        end)
      end)

    successful_results =
      results
      |> Enum.filter(fn
        {:ok, _, _} -> true
        _ -> false
      end)

    if successful_results == [] do
      error_msg =
        case List.first(results) do
          {:error, msg} -> msg
          _ -> "Could not process any images. Please try again."
        end

      {:noreply,
       socket
       |> assign(:upload_step, :error)
       |> assign(:upload_error, error_msg)
       |> assign(:upload_progress, 0)
       |> assign(:upload_stage, nil)}
    else
      combined_text =
        successful_results
        |> Enum.with_index(1)
        |> Enum.map(fn {{:ok, text, _date}, idx} ->
          if length(successful_results) > 1 do
            "--- Page #{idx} ---\n\n#{text}"
          else
            text
          end
        end)
        |> Enum.join("\n\n")

      first_date =
        successful_results
        |> Enum.find_value(fn {:ok, _text, date} -> date end)

      form = to_form(%{"title" => "", "body" => combined_text, "book_id" => ""}, as: :extracted)

      {:noreply,
       socket
       |> assign(:upload_step, :preview)
       |> assign(:extracted_form, form)
       |> assign(:extracted_date, first_date)
       |> assign(:upload_progress, 100)
       |> assign(:upload_stage, :ready)
       |> assign(:page_order, [])}
    end
  end

  @impl true
  def handle_event("retry_upload", _params, socket) do
    {:noreply,
     socket
     |> assign(:upload_step, :upload)
     |> assign(:upload_progress, 0)
     |> assign(:upload_stage, nil)
     |> assign(:upload_error, nil)
     |> assign(:processing_images, %{})
     |> assign(:total_images, 0)
     |> assign(:processed_images, 0)
     |> assign(:page_order, [])}
  end

  @impl true
  def handle_event("save_extracted_entry", %{"extracted" => params}, socket) do
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key
    local_today = JournalHelpers.get_local_today(socket)

    entry_date =
      case params["entry_date"] do
        "" -> local_today
        nil -> local_today
        date_str -> Date.from_iso8601!(date_str)
      end

    entry_params = %{
      "title" => params["title"],
      "body" => params["body"],
      "entry_date" => entry_date,
      "book_id" => if(params["book_id"] == "", do: nil, else: params["book_id"])
    }

    case Journal.create_journal_entry(user, entry_params, key) do
      {:ok, entry} ->
        decrypted_entry =
          entry
          |> Map.put(:decrypted_title, params["title"])
          |> Map.put(:decrypted_body, params["body"])

        updated_entries =
          if is_nil(entry.book_id) do
            [decrypted_entry | socket.assigns.entries]
          else
            socket.assigns.entries
          end

        updated_books =
          if entry.book_id do
            Enum.map(socket.assigns.books, fn book ->
              if book.id == entry.book_id do
                %{book | entry_count: book.entry_count + 1}
              else
                book
              end
            end)
          else
            socket.assigns.books
          end

        {:noreply,
         socket
         |> assign(:show_upload_modal, false)
         |> assign(:upload_step, :upload)
         |> assign(:upload_progress, 0)
         |> assign(:upload_stage, nil)
         |> assign(:extracted_form, nil)
         |> assign(:extracted_date, nil)
         |> assign(:entries, updated_entries)
         |> assign(:books, updated_books)
         |> assign(:entry_count, socket.assigns.entry_count + 1)
         |> assign(
           :loose_entry_count,
           if(is_nil(entry.book_id),
             do: socket.assigns.loose_entry_count + 1,
             else: socket.assigns.loose_entry_count
           )
         )
         |> put_flash(:info, "Journal entry created from your handwriting ✨")
         |> push_event("restore-body-scroll", %{})}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not save entry")}
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
  def handle_info({:journal_upload_progress, ref, :receiving, percent}, socket) do
    processing_images = Map.put(socket.assigns.processing_images, ref, {:receiving, percent})

    if socket.assigns.upload_step == :processing do
      {avg_progress, stage} = calculate_aggregate_progress(processing_images)

      {:noreply,
       socket
       |> assign(:upload_progress, avg_progress)
       |> assign(:upload_stage, stage)
       |> assign(:processing_images, processing_images)}
    else
      {:noreply, assign(socket, :processing_images, processing_images)}
    end
  end

  @impl true
  def handle_info({:journal_upload_progress, ref, :processing, percent}, socket) do
    processing_images = Map.put(socket.assigns.processing_images, ref, {:processing, percent})

    if socket.assigns.upload_step == :processing do
      {avg_progress, stage} = calculate_aggregate_progress(processing_images)

      {:noreply,
       socket
       |> assign(:upload_progress, avg_progress)
       |> assign(:upload_stage, stage)
       |> assign(:processing_images, processing_images)}
    else
      {:noreply, assign(socket, :processing_images, processing_images)}
    end
  end

  @impl true
  def handle_info({:journal_upload_progress, ref, :extracting, percent}, socket) do
    processing_images = Map.put(socket.assigns.processing_images, ref, {:extracting, percent})

    if socket.assigns.upload_step == :processing do
      {avg_progress, stage} = calculate_aggregate_progress(processing_images)

      {:noreply,
       socket
       |> assign(:upload_progress, avg_progress)
       |> assign(:upload_stage, stage)
       |> assign(:processing_images, processing_images)}
    else
      {:noreply, assign(socket, :processing_images, processing_images)}
    end
  end

  @impl true
  def handle_info({:journal_upload_progress, ref, :analyzing, percent}, socket) do
    processing_images = Map.put(socket.assigns.processing_images, ref, {:analyzing, percent})

    if socket.assigns.upload_step == :processing do
      {avg_progress, stage} = calculate_aggregate_progress(processing_images)

      {:noreply,
       socket
       |> assign(:upload_progress, avg_progress)
       |> assign(:upload_stage, stage)
       |> assign(:processing_images, processing_images)}
    else
      {:noreply, assign(socket, :processing_images, processing_images)}
    end
  end

  @impl true
  def handle_info({:journal_upload_progress, ref, :ready, %{text: _text, date: _date}}, socket) do
    processing_images = Map.put(socket.assigns.processing_images, ref, {:ready, 100})

    if socket.assigns.upload_step == :processing do
      {avg_progress, _stage} = calculate_aggregate_progress(processing_images)

      {:noreply,
       socket
       |> assign(:upload_progress, avg_progress)
       |> assign(:processing_images, processing_images)}
    else
      {:noreply, assign(socket, :processing_images, processing_images)}
    end
  end

  @impl true
  def handle_info({:journal_upload_progress, ref, :error, :no_text_found}, socket) do
    if socket.assigns.upload_step == :processing do
      {:noreply,
       socket
       |> assign(:upload_step, :error)
       |> assign(:upload_error, "No readable text was found in the image. Try a clearer photo.")
       |> assign(:upload_progress, 0)
       |> assign(:upload_stage, nil)}
    else
      processing_images =
        Map.put(socket.assigns.processing_images, ref, {:error, "No text found"})

      {:noreply, assign(socket, :processing_images, processing_images)}
    end
  end

  @impl true
  def handle_info({:journal_upload_progress, ref, :error, reason}, socket) do
    if socket.assigns.upload_step == :processing do
      {:noreply,
       socket
       |> assign(:upload_step, :error)
       |> assign(:upload_error, "Something went wrong: #{inspect(reason)}")
       |> assign(:upload_progress, 0)
       |> assign(:upload_stage, nil)}
    else
      processing_images =
        Map.put(socket.assigns.processing_images, ref, {:error, "Processing failed"})

      {:noreply, assign(socket, :processing_images, processing_images)}
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
  def handle_info(:load_cached_insight, socket) do
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    case Journal.get_insight(user) do
      nil ->
        send(self(), :generate_new_insight)
        {:noreply, socket}

      cached_insight ->
        if Journal.insight_needs_auto_refresh?(cached_insight) do
          send(self(), :generate_new_insight)
          {:noreply, assign(socket, :cached_insight, cached_insight)}
        else
          decrypted = Journal.decrypt_insight(cached_insight, user, key)
          can_refresh = Journal.can_manually_refresh_insight?(cached_insight)
          hours = if can_refresh, do: 0, else: Journal.hours_until_manual_refresh(cached_insight)

          {:noreply,
           socket
           |> assign(:mood_insight, decrypted.insight)
           |> assign(:cached_insight, cached_insight)
           |> assign(:can_refresh, can_refresh)
           |> assign(:hours_until_refresh, hours)
           |> assign(:loading_insights, false)}
        end
    end
  end

  @impl true
  def handle_info(:generate_new_insight, socket) do
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key
    recent_entries = Journal.list_journal_entries(user, limit: 14)

    insight_text =
      case JournalAI.generate_mood_insights(recent_entries) do
        {:ok, text} -> text
        {:error, _} -> "Keep journaling! More entries help me understand your patterns better."
      end

    case Journal.upsert_insight(user, insight_text, key) do
      {:ok, cached_insight} ->
        {:noreply,
         socket
         |> assign(:mood_insight, insight_text)
         |> assign(:cached_insight, cached_insight)
         |> assign(:can_refresh, false)
         |> assign(:hours_until_refresh, 24)
         |> assign(:loading_insights, false)}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:mood_insight, insight_text)
         |> assign(:loading_insights, false)}
    end
  end

  @impl true
  def handle_info({_ref, {"get_user_avatar", user_id}}, socket) do
    user = Accounts.get_user_with_preloads(user_id)
    {:noreply, assign(socket, :current_user, user)}
  end

  @impl true
  def handle_info({:privacy_timer_update, state}, socket) do
    {:noreply, JournalHelpers.handle_privacy_timer_update(socket, state)}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp handle_journal_upload_progress(:journal_image, _entry, socket) do
    {:noreply, socket}
  end

  defp calculate_aggregate_progress(processing_images) when map_size(processing_images) == 0 do
    {0, :receiving}
  end

  defp calculate_aggregate_progress(processing_images) do
    values = Map.values(processing_images)
    count = length(values)

    total_progress =
      Enum.reduce(values, 0, fn
        {_stage, percent}, acc when is_number(percent) -> acc + percent
        _, acc -> acc
      end)

    avg_progress = round(total_progress / count)

    current_stage =
      values
      |> Enum.map(fn {stage, _} -> stage end)
      |> Enum.min_by(fn
        :receiving -> 0
        :processing -> 1
        :extracting -> 2
        :analyzing -> 3
        :ready -> 4
        :error -> 5
        _ -> 0
      end)

    {avg_progress, current_stage}
  end

  defp decrypt_books(books, user, key) do
    Enum.map(books, &decrypt_book(&1, user, key))
  end

  defp decrypt_book(book, user, key) do
    decrypted = Journal.decrypt_book(book, user, key)

    cover_src =
      if decrypted.cover_image_url do
        load_cover_image_src(decrypted.cover_image_url, user, key)
      else
        nil
      end

    book
    |> Map.put(:decrypted_title, decrypted.title)
    |> Map.put(:decrypted_cover_image_url, cover_src)
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

  defp upload_stage_text(:receiving, count) when count > 1, do: "Uploading images..."
  defp upload_stage_text(:receiving, _), do: "Uploading image..."
  defp upload_stage_text(:extracting, count) when count > 1, do: "Reading your handwriting..."
  defp upload_stage_text(:extracting, _), do: "Reading your handwriting..."
  defp upload_stage_text(:analyzing, count) when count > 1, do: "Detecting dates..."
  defp upload_stage_text(:analyzing, _), do: "Detecting date..."
  defp upload_stage_text(_, _), do: "Processing..."

  defp format_date(date) do
    today = Date.utc_today()

    cond do
      date == today -> "Today"
      date == Date.add(today, -1) -> "Yesterday"
      true -> Calendar.strftime(date, "%b %d, %Y")
    end
  end

  defp book_cover_gradient("emerald"), do: "bg-gradient-to-br from-emerald-500 to-teal-600"
  defp book_cover_gradient("teal"), do: "bg-gradient-to-br from-teal-500 to-cyan-600"
  defp book_cover_gradient("cyan"), do: "bg-gradient-to-br from-cyan-500 to-blue-600"
  defp book_cover_gradient("blue"), do: "bg-gradient-to-br from-blue-500 to-indigo-600"
  defp book_cover_gradient("violet"), do: "bg-gradient-to-br from-violet-500 to-purple-600"
  defp book_cover_gradient("purple"), do: "bg-gradient-to-br from-purple-500 to-pink-600"
  defp book_cover_gradient("pink"), do: "bg-gradient-to-br from-pink-500 to-rose-600"
  defp book_cover_gradient("rose"), do: "bg-gradient-to-br from-rose-500 to-red-600"
  defp book_cover_gradient("amber"), do: "bg-gradient-to-br from-amber-500 to-orange-600"
  defp book_cover_gradient("orange"), do: "bg-gradient-to-br from-orange-500 to-red-600"
  defp book_cover_gradient("yellow"), do: "bg-gradient-to-br from-yellow-400 to-amber-500"
  defp book_cover_gradient(_), do: "bg-gradient-to-br from-slate-500 to-slate-600"

  defp upload_error_to_string(:too_large), do: "File is too large (max 10MB)"

  defp upload_error_to_string(:not_accepted),
    do: "Invalid file type. Please use JPG, PNG, or HEIC"

  defp upload_error_to_string(:too_many_files), do: "Maximum 10 images allowed"
  defp upload_error_to_string(_), do: "Upload error"

  defp format_processing_stage({:receiving, _percent}), do: "Receiving..."
  defp format_processing_stage({:extracting, _percent}), do: "Reading text..."
  defp format_processing_stage({:analyzing, _percent}), do: "Analyzing..."
  defp format_processing_stage({:ready, _}), do: "Ready"
  defp format_processing_stage(_), do: "Processing..."

  defp ordered_entries(entries, []), do: entries

  defp ordered_entries(entries, page_order) do
    entry_map = Map.new(entries, &{&1.ref, &1})

    ordered =
      Enum.reduce(page_order, [], fn ref, acc ->
        case Map.get(entry_map, ref) do
          nil -> acc
          entry -> [entry | acc]
        end
      end)
      |> Enum.reverse()

    remaining_refs = MapSet.new(page_order)
    remaining = Enum.reject(entries, &MapSet.member?(remaining_refs, &1.ref))

    ordered ++ remaining
  end

  defp get_page_number(ref, entries, []) do
    Enum.find_index(entries, &(&1.ref == ref)) + 1
  end

  defp get_page_number(ref, entries, page_order) do
    ordered = ordered_entries(entries, page_order)
    Enum.find_index(ordered, &(&1.ref == ref)) + 1
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
                     minimize_file_size: true
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
    max_dimension = 800

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
end
