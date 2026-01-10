defmodule MossletWeb.JournalLive.Book do
  @moduledoc """
  Journal book view - displays entries within a specific book.
  """
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Journal
  alias Mosslet.Journal.JournalBook
  alias MossletWeb.DesignSystem
  alias MossletWeb.Helpers.JournalHelpers

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
                  class="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium text-white bg-gradient-to-r from-teal-500 to-emerald-500 rounded-xl shadow-sm hover:from-teal-600 hover:to-emerald-600 transition-all duration-200"
                >
                  <.phx_icon name="hero-plus" class="h-4 w-4" /> Add Entry
                </.link>
              </div>
            </div>
          <% end %>
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
         |> assign(:page_title, decrypted.title)
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
         |> assign(:page_title, decrypted.title)
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
          {:noreply, socket}

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
