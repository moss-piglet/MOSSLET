defmodule MossletWeb.JournalLive.Book do
  @moduledoc """
  Journal book view - displays entries within a specific book.
  """
  use MossletWeb, :live_view

  alias Mosslet.Journal
  alias Mosslet.Journal.JournalBook

  @impl true
  def render(assigns) do
    ~H"""
    <.layout type="sidebar" current_scope={@current_scope} current_page={:journal}>
      <div class="max-w-4xl mx-auto">
        <div class="mb-8">
          <.link
            navigate={~p"/app/journal"}
            class="inline-flex items-center gap-1 text-sm text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300 mb-4"
          >
            <.phx_icon name="hero-arrow-left" class="h-4 w-4" /> Back to Journal
          </.link>

          <div class="flex items-start justify-between gap-4">
            <div class="flex items-center gap-4">
              <div class={[
                "h-16 w-16 rounded-xl flex items-center justify-center",
                book_cover_gradient(@book.cover_color)
              ]}>
                <.phx_icon name="hero-book-open" class="h-8 w-8 text-white/80" />
              </div>
              <div>
                <h1 class="text-2xl font-bold text-slate-900 dark:text-slate-100">
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

            <div class="flex items-center gap-2">
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
                class="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium text-white bg-gradient-to-r from-teal-500 to-emerald-500 rounded-xl shadow-sm hover:from-teal-600 hover:to-emerald-600 transition-all duration-200"
              >
                <.phx_icon name="hero-plus" class="h-4 w-4" /> Add Entry
              </.link>
            </div>
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

        <div :if={@entries != []} class="space-y-3">
          <div
            :for={entry <- @entries}
            class="group bg-white dark:bg-slate-800 rounded-xl p-4 border border-slate-200 dark:border-slate-700 hover:border-emerald-300 dark:hover:border-emerald-600 transition-colors cursor-pointer"
            phx-click={JS.navigate(~p"/app/journal/#{entry.id}")}
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
                <span :if={entry.mood} class="text-lg" title={entry.mood}>
                  {mood_emoji(entry.mood)}
                </span>
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
                    aria-label={"#{color} cover color"}
                  />
                </label>
              </div>
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
                  disabled={!@book_form.source.valid?}
                  class="px-6 py-2.5 text-sm font-medium text-white bg-gradient-to-r from-teal-500 to-emerald-500 rounded-xl shadow-sm hover:from-teal-600 hover:to-emerald-600 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200"
                >
                  Update
                </button>
              </div>
            </div>
          </div>
        </.form>
      </.liquid_modal>
    </.layout>
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

        {:ok,
         socket
         |> assign(:page_title, decrypted.title)
         |> assign(:book, book)
         |> assign(:decrypted_title, decrypted.title)
         |> assign(:decrypted_description, decrypted.description)
         |> assign(:entries, decrypted_entries)
         |> assign(:offset, 20)
         |> assign(:has_more, length(entries) == 20)
         |> assign(:show_edit_modal, false)
         |> assign(:book_form, nil)}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
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
     |> assign(:book_form, to_form(changeset, as: :journal_book))}
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

    case Journal.update_book(book, params, user, key) do
      {:ok, updated_book} ->
        decrypted = Journal.decrypt_book(updated_book, user, key)

        {:noreply,
         socket
         |> assign(:show_edit_modal, false)
         |> assign(:book_form, nil)
         |> assign(:book, %{updated_book | entry_count: book.entry_count})
         |> assign(:decrypted_title, decrypted.title)
         |> assign(:decrypted_description, decrypted.description)
         |> assign(:page_title, decrypted.title)
         |> put_flash(:info, "Book updated")
         |> push_event("restore-body-scroll", %{})}

      {:error, changeset} ->
        {:noreply, assign(socket, :book_form, to_form(changeset, as: :journal_book))}
    end
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_edit_modal, false)
     |> assign(:book_form, nil)
     |> push_event("restore-body-scroll", %{})}
  end

  @impl true
  def handle_event("delete_book", _params, socket) do
    user = socket.assigns.current_scope.user
    book = socket.assigns.book

    case Journal.delete_book(book, user) do
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
end
