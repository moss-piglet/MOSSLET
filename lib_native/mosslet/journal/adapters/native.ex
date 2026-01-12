defmodule Mosslet.Journal.Adapters.Native do
  @moduledoc """
  Native adapter for journal operations.

  This adapter uses HTTP API calls to communicate with the cloud server.
  It's used by desktop and mobile apps running elixir-desktop.

  ## Zero-Knowledge Architecture

  Journal entries are encrypted with user keys. In native mode:
  - Decryption happens on-device (true zero-knowledge)
  - Server only sees encrypted blobs
  - Local SQLite cache stores encrypted data for offline viewing
  """

  @behaviour Mosslet.Journal.Adapter

  alias Mosslet.API.Client
  alias Mosslet.Cache
  alias Mosslet.Journal.{JournalBook, JournalEntry, JournalInsight}
  alias Mosslet.Session.Native, as: NativeSession
  alias Mosslet.Sync

  # =====================
  # Book Functions
  # =====================

  @impl true
  def list_books(user) do
    if Sync.online?() do
      case Client.list_journal_books(get_token()) do
        {:ok, %{books: books}} ->
          books_list = Enum.map(books, &deserialize_book/1)
          cache_books(user.id, books_list)
          books_list

        {:error, _reason} ->
          get_cached_books(user.id)
      end
    else
      get_cached_books(user.id)
    end
  end

  @impl true
  def get_book!(id, user) do
    case get_book(id, user) do
      nil -> raise Ecto.NoResultsError, queryable: JournalBook
      book -> book
    end
  end

  @impl true
  def get_book(id, user) do
    if Sync.online?() do
      case Client.get_journal_book(get_token(), id) do
        {:ok, %{book: book_data}} ->
          book = deserialize_book(book_data)
          cache_book(user.id, book)
          book

        {:error, _reason} ->
          get_cached_book(user.id, id)
      end
    else
      get_cached_book(user.id, id)
    end
  end

  @impl true
  def create_book(changeset) do
    attrs = changeset_to_attrs(changeset)

    case Client.create_journal_book(get_token(), %{book: attrs}) do
      {:ok, %{book: book_data}} ->
        {:ok, deserialize_book(book_data)}

      {:error, %{errors: errors}} ->
        {:error, apply_errors_to_changeset(changeset, errors)}

      {:error, reason} ->
        {:error, add_error_to_changeset(changeset, :base, reason)}
    end
  end

  @impl true
  def update_book(changeset) do
    book = changeset.data
    attrs = changeset_to_attrs(changeset)

    case Client.update_journal_book(get_token(), book.id, %{book: attrs}) do
      {:ok, %{book: book_data}} ->
        {:ok, deserialize_book(book_data)}

      {:error, %{errors: errors}} ->
        {:error, apply_errors_to_changeset(changeset, errors)}

      {:error, reason} ->
        {:error, add_error_to_changeset(changeset, :base, reason)}
    end
  end

  @impl true
  def delete_book(book) do
    case Client.delete_journal_book(get_token(), book.id) do
      {:ok, _} ->
        invalidate_book_cache(book.user_id, book.id)
        {:ok, book}

      {:error, reason} ->
        {:error, Ecto.Changeset.change(book) |> Ecto.Changeset.add_error(:base, "#{reason}")}
    end
  end

  @impl true
  def update_book_cover_image(book, encrypted_url) do
    case Client.update_journal_book_cover(get_token(), book.id, %{cover_image_url: encrypted_url}) do
      {:ok, %{book: book_data}} ->
        {:ok, deserialize_book(book_data)}

      {:error, reason} ->
        {:error, Ecto.Changeset.change(book) |> Ecto.Changeset.add_error(:base, "#{reason}")}
    end
  end

  @impl true
  def clear_book_cover_image(book) do
    case Client.update_journal_book_cover(get_token(), book.id, %{cover_image_url: nil}) do
      {:ok, %{book: book_data}} ->
        {:ok, deserialize_book(book_data)}

      {:error, reason} ->
        {:error, Ecto.Changeset.change(book) |> Ecto.Changeset.add_error(:base, "#{reason}")}
    end
  end

  # =====================
  # Entry Functions
  # =====================

  @impl true
  def list_journal_entries(user, opts) do
    if Sync.online?() do
      params = build_list_params(opts)

      case Client.list_journal_entries(get_token(), params) do
        {:ok, %{entries: entries}} ->
          entries_list = Enum.map(entries, &deserialize_entry/1)
          cache_entries(user.id, entries_list)
          entries_list

        {:error, _reason} ->
          get_cached_entries(user.id, opts)
      end
    else
      get_cached_entries(user.id, opts)
    end
  end

  @impl true
  def list_loose_entries(user, opts) do
    list_journal_entries(user, Keyword.put(opts, :loose_only, true))
  end

  @impl true
  def count_loose_entries(_user) do
    if Sync.online?() do
      case Client.count_loose_journal_entries(get_token()) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def list_favorite_entries(user, opts) do
    list_journal_entries(user, Keyword.put(opts, :favorites_only, true))
  end

  @impl true
  def list_entries_by_date_range(_user, start_date, end_date) do
    if Sync.online?() do
      params = %{start_date: Date.to_iso8601(start_date), end_date: Date.to_iso8601(end_date)}

      case Client.list_journal_entries_by_date_range(get_token(), params) do
        {:ok, %{entries: entries}} ->
          Enum.map(entries, &deserialize_entry/1)

        {:error, _reason} ->
          []
      end
    else
      []
    end
  end

  @impl true
  def get_journal_entry!(id, user) do
    case get_journal_entry(id, user) do
      nil -> raise Ecto.NoResultsError, queryable: JournalEntry
      entry -> entry
    end
  end

  @impl true
  def get_journal_entry(id, user) do
    if Sync.online?() do
      case Client.get_journal_entry(get_token(), id) do
        {:ok, %{entry: entry_data}} ->
          entry = deserialize_entry(entry_data)
          cache_entry(user.id, entry)
          entry

        {:error, _reason} ->
          get_cached_entry(user.id, id)
      end
    else
      get_cached_entry(user.id, id)
    end
  end

  @impl true
  def create_journal_entry(changeset) do
    attrs = changeset_to_attrs(changeset)

    case Client.create_journal_entry(get_token(), %{entry: attrs}) do
      {:ok, %{entry: entry_data}} ->
        {:ok, deserialize_entry(entry_data)}

      {:error, %{errors: errors}} ->
        {:error, apply_errors_to_changeset(changeset, errors)}

      {:error, reason} ->
        {:error, add_error_to_changeset(changeset, :base, reason)}
    end
  end

  @impl true
  def update_journal_entry(changeset) do
    entry = changeset.data
    attrs = changeset_to_attrs(changeset)

    case Client.update_journal_entry(get_token(), entry.id, %{entry: attrs}) do
      {:ok, %{entry: entry_data}} ->
        {:ok, deserialize_entry(entry_data)}

      {:error, %{errors: errors}} ->
        {:error, apply_errors_to_changeset(changeset, errors)}

      {:error, reason} ->
        {:error, add_error_to_changeset(changeset, :base, reason)}
    end
  end

  @impl true
  def delete_journal_entry(entry) do
    case Client.delete_journal_entry(get_token(), entry.id) do
      {:ok, _} ->
        invalidate_entry_cache(entry.user_id, entry.id)
        {:ok, entry}

      {:error, reason} ->
        {:error, Ecto.Changeset.change(entry) |> Ecto.Changeset.add_error(:base, "#{reason}")}
    end
  end

  @impl true
  def toggle_favorite(entry) do
    case Client.toggle_journal_entry_favorite(get_token(), entry.id) do
      {:ok, %{entry: entry_data}} ->
        {:ok, deserialize_entry(entry_data)}

      {:error, reason} ->
        {:error, Ecto.Changeset.change(entry) |> Ecto.Changeset.add_error(:base, "#{reason}")}
    end
  end

  @impl true
  def move_entry_to_book(entry, book_id) do
    case Client.move_journal_entry_to_book(get_token(), entry.id, %{book_id: book_id}) do
      {:ok, %{entry: entry_data}} ->
        {:ok, deserialize_entry(entry_data)}

      {:error, reason} ->
        {:error, Ecto.Changeset.change(entry) |> Ecto.Changeset.add_error(:base, "#{reason}")}
    end
  end

  @impl true
  def count_entries(_user) do
    if Sync.online?() do
      case Client.count_journal_entries(get_token()) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def count_book_entries(book_id) do
    if Sync.online?() do
      case Client.count_journal_book_entries(get_token(), book_id) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def total_word_count(_user) do
    if Sync.online?() do
      case Client.total_journal_word_count(get_token()) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def streak_entry_timestamps(_user) do
    if Sync.online?() do
      case Client.journal_streak_timestamps(get_token()) do
        {:ok, %{timestamps: timestamps}} ->
          Enum.map(timestamps, &NaiveDateTime.from_iso8601!/1)

        {:error, _reason} ->
          []
      end
    else
      []
    end
  end

  @impl true
  def get_adjacent_entries(entry, _user, opts) do
    if Sync.online?() do
      params =
        opts
        |> Keyword.take([:book_id, :loose_only])
        |> Enum.into(%{})

      case Client.get_adjacent_journal_entries(get_token(), entry.id, params) do
        {:ok, %{prev_id: prev_id, next_id: next_id}} ->
          %{prev_id: prev_id, next_id: next_id}

        {:error, _reason} ->
          %{prev_id: nil, next_id: nil}
      end
    else
      %{prev_id: nil, next_id: nil}
    end
  end

  @impl true
  def get_entry_position_in_book(entry, _user) do
    if entry.book_id && Sync.online?() do
      case Client.get_journal_entry_position(get_token(), entry.id) do
        {:ok, %{position: position, total: total}} ->
          {position, total}

        {:error, _reason} ->
          {nil, nil}
      end
    else
      {nil, nil}
    end
  end

  # =====================
  # Insight Functions
  # =====================

  @impl true
  def get_insight(user) do
    if Sync.online?() do
      case Client.get_journal_insight(get_token()) do
        {:ok, %{insight: insight_data}} when not is_nil(insight_data) ->
          insight = deserialize_insight(insight_data)
          cache_insight(user.id, insight)
          insight

        {:ok, %{insight: nil}} ->
          nil

        {:error, _reason} ->
          get_cached_insight(user.id)
      end
    else
      get_cached_insight(user.id)
    end
  end

  @impl true
  def upsert_insight(changeset, _existing) do
    attrs = changeset_to_attrs(changeset)

    case Client.upsert_journal_insight(get_token(), %{insight: attrs}) do
      {:ok, %{insight: insight_data}} ->
        {:ok, deserialize_insight(insight_data)}

      {:error, %{errors: errors}} ->
        {:error, apply_errors_to_changeset(changeset, errors)}

      {:error, reason} ->
        {:error, add_error_to_changeset(changeset, :base, reason)}
    end
  end

  # =====================
  # Private Helpers
  # =====================

  defp get_token do
    NativeSession.get_token()
  end

  defp build_list_params(opts) do
    opts
    |> Keyword.take([:limit, :offset, :book_id, :loose_only, :favorites_only])
    |> Enum.into(%{})
  end

  defp changeset_to_attrs(changeset) do
    changeset.changes
    |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
  end

  defp apply_errors_to_changeset(changeset, errors) when is_map(errors) do
    Enum.reduce(errors, changeset, fn {field, messages}, cs ->
      field_atom = if is_binary(field), do: String.to_existing_atom(field), else: field
      messages_list = if is_list(messages), do: messages, else: [messages]

      Enum.reduce(messages_list, cs, fn msg, acc ->
        Ecto.Changeset.add_error(acc, field_atom, msg)
      end)
    end)
  end

  defp apply_errors_to_changeset(changeset, _errors), do: changeset

  defp add_error_to_changeset(changeset, field, reason) do
    msg = if is_binary(reason), do: reason, else: "Operation failed"
    Ecto.Changeset.add_error(changeset, field, msg)
  end

  # =====================
  # Deserialization
  # =====================

  defp deserialize_book(data) when is_map(data) do
    %JournalBook{
      id: data["id"],
      user_id: data["user_id"],
      title: data["title"],
      description: data["description"],
      cover_image_url: data["cover_image_url"],
      entry_count: data["entry_count"] || 0,
      inserted_at: parse_datetime(data["inserted_at"]),
      updated_at: parse_datetime(data["updated_at"])
    }
  end

  defp deserialize_entry(data) when is_map(data) do
    %JournalEntry{
      id: data["id"],
      user_id: data["user_id"],
      book_id: data["book_id"],
      title: data["title"],
      body: data["body"],
      mood: data["mood"],
      word_count: data["word_count"] || 0,
      entry_date: parse_date(data["entry_date"]),
      is_favorite: data["is_favorite"] || false,
      inserted_at: parse_datetime(data["inserted_at"]),
      updated_at: parse_datetime(data["updated_at"])
    }
  end

  defp deserialize_insight(data) when is_map(data) do
    %JournalInsight{
      id: data["id"],
      user_id: data["user_id"],
      insight: data["insight"],
      generated_at: parse_datetime(data["generated_at"]),
      inserted_at: parse_datetime(data["inserted_at"]),
      updated_at: parse_datetime(data["updated_at"])
    }
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp parse_datetime(%DateTime{} = dt), do: dt

  defp parse_date(nil), do: nil

  defp parse_date(str) when is_binary(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_date(%Date{} = date), do: date

  # =====================
  # Caching
  # =====================

  defp cache_books(user_id, books) do
    Enum.each(books, &cache_book(user_id, &1))
  end

  defp cache_book(user_id, book) do
    Cache.cache_item("journal_book", book.id, Jason.encode!(book), user_id: user_id)
  end

  defp get_cached_books(user_id) do
    case Cache.get_cached_items_by_type("journal_book", user_id: user_id) do
      items when is_list(items) ->
        items
        |> Enum.map(fn item ->
          case Jason.decode(item.encrypted_data) do
            {:ok, data} -> deserialize_book(data)
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp get_cached_book(user_id, id) do
    case Cache.get_cached_item("journal_book", id, user_id: user_id) do
      %{encrypted_data: data} when not is_nil(data) ->
        case Jason.decode(data) do
          {:ok, book_data} -> deserialize_book(book_data)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp invalidate_book_cache(user_id, book_id) do
    Cache.delete_cached_item("journal_book", book_id, user_id: user_id)
  end

  defp cache_entries(user_id, entries) do
    Enum.each(entries, &cache_entry(user_id, &1))
  end

  defp cache_entry(user_id, entry) do
    Cache.cache_item("journal_entry", entry.id, Jason.encode!(entry), user_id: user_id)
  end

  defp get_cached_entries(user_id, opts) do
    case Cache.get_cached_items_by_type("journal_entry", user_id: user_id) do
      items when is_list(items) ->
        entries =
          items
          |> Enum.map(fn item ->
            case Jason.decode(item.encrypted_data) do
              {:ok, data} -> deserialize_entry(data)
              _ -> nil
            end
          end)
          |> Enum.reject(&is_nil/1)
          |> filter_cached_entries(opts)
          |> Enum.sort_by(&{&1.entry_date, &1.inserted_at}, {:desc, :desc})

        limit = Keyword.get(opts, :limit, 20)
        offset = Keyword.get(opts, :offset, 0)

        entries
        |> Enum.drop(offset)
        |> Enum.take(limit)

      _ ->
        []
    end
  end

  defp filter_cached_entries(entries, opts) do
    book_id = Keyword.get(opts, :book_id)
    loose_only = Keyword.get(opts, :loose_only, false)
    favorites_only = Keyword.get(opts, :favorites_only, false)

    entries
    |> then(fn e -> if book_id, do: Enum.filter(e, &(&1.book_id == book_id)), else: e end)
    |> then(fn e -> if loose_only, do: Enum.filter(e, &is_nil(&1.book_id)), else: e end)
    |> then(fn e -> if favorites_only, do: Enum.filter(e, & &1.is_favorite), else: e end)
  end

  defp get_cached_entry(user_id, id) do
    case Cache.get_cached_item("journal_entry", id, user_id: user_id) do
      %{encrypted_data: data} when not is_nil(data) ->
        case Jason.decode(data) do
          {:ok, entry_data} -> deserialize_entry(entry_data)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp invalidate_entry_cache(user_id, entry_id) do
    Cache.delete_cached_item("journal_entry", entry_id, user_id: user_id)
  end

  defp cache_insight(user_id, insight) do
    Cache.cache_item("journal_insight", user_id, Jason.encode!(insight), user_id: user_id)
  end

  defp get_cached_insight(user_id) do
    case Cache.get_cached_item("journal_insight", user_id, user_id: user_id) do
      %{encrypted_data: data} when not is_nil(data) ->
        case Jason.decode(data) do
          {:ok, insight_data} -> deserialize_insight(insight_data)
          _ -> nil
        end

      _ ->
        nil
    end
  end
end
