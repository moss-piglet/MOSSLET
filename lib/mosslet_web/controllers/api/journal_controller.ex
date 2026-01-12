defmodule MossletWeb.API.JournalController do
  @moduledoc """
  API controller for journal operations.

  Handles CRUD for journal books, entries, and insights.
  All data is encrypted - native apps decrypt on-device for zero-knowledge.
  """
  use MossletWeb, :controller

  alias Mosslet.Journal
  alias Mosslet.Journal.{JournalBook, JournalEntry}

  action_fallback MossletWeb.API.FallbackController

  # =====================
  # Book Endpoints
  # =====================

  def list_books(conn, _params) do
    user = conn.assigns.current_user
    books = Journal.list_books(user)

    conn
    |> put_status(:ok)
    |> json(%{books: Enum.map(books, &serialize_book/1)})
  end

  def show_book(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Journal.get_book(id, user) do
      nil ->
        {:error, :not_found}

      book ->
        conn
        |> put_status(:ok)
        |> json(%{book: serialize_book(book)})
    end
  end

  def create_book(conn, %{"book" => book_params}) do
    user = conn.assigns.current_user
    key = get_session_key(conn)

    case Journal.create_book(user, book_params, key) do
      {:ok, book} ->
        conn
        |> put_status(:created)
        |> json(%{book: serialize_book(book)})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_book(conn, %{"id" => id, "book" => book_params}) do
    user = conn.assigns.current_user
    key = get_session_key(conn)

    case Journal.get_book(id, user) do
      nil ->
        {:error, :not_found}

      book ->
        case Journal.update_book(book, book_params, user, key) do
          {:ok, updated_book} ->
            conn
            |> put_status(:ok)
            |> json(%{book: serialize_book(updated_book)})

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  def delete_book(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    key = get_session_key(conn)

    case Journal.get_book(id, user) do
      nil ->
        {:error, :not_found}

      book ->
        case Journal.delete_book(book, user, key) do
          {:ok, _book} ->
            conn
            |> put_status(:ok)
            |> json(%{deleted: true})

          {:error, :unauthorized} ->
            {:error, :unauthorized}

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  def update_book_cover(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user
    key = get_session_key(conn)

    case Journal.get_book(id, user) do
      nil ->
        {:error, :not_found}

      book ->
        result =
          case params["cover_image_url"] do
            nil -> Journal.clear_book_cover_image(book)
            url -> Journal.update_book_cover_image(book, url, user, key)
          end

        case result do
          {:ok, updated_book} ->
            conn
            |> put_status(:ok)
            |> json(%{book: serialize_book(updated_book)})

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  def count_book_entries(conn, %{"id" => id}) do
    count = Journal.count_book_entries(id)

    conn
    |> put_status(:ok)
    |> json(%{count: count})
  end

  # =====================
  # Entry Endpoints
  # =====================

  def list_entries(conn, params) do
    user = conn.assigns.current_user
    opts = build_list_opts(params)
    entries = Journal.list_journal_entries(user, opts)

    conn
    |> put_status(:ok)
    |> json(%{entries: Enum.map(entries, &serialize_entry/1)})
  end

  def list_loose_entries(conn, params) do
    user = conn.assigns.current_user
    opts = build_list_opts(params)
    entries = Journal.list_loose_entries(user, opts)

    conn
    |> put_status(:ok)
    |> json(%{entries: Enum.map(entries, &serialize_entry/1)})
  end

  def count_loose_entries(conn, _params) do
    user = conn.assigns.current_user
    count = Journal.count_loose_entries(user)

    conn
    |> put_status(:ok)
    |> json(%{count: count})
  end

  def list_favorite_entries(conn, params) do
    user = conn.assigns.current_user
    opts = build_list_opts(params)
    entries = Journal.list_favorite_entries(user, opts)

    conn
    |> put_status(:ok)
    |> json(%{entries: Enum.map(entries, &serialize_entry/1)})
  end

  def list_entries_by_date_range(conn, %{"start_date" => start_str, "end_date" => end_str}) do
    user = conn.assigns.current_user

    with {:ok, start_date} <- Date.from_iso8601(start_str),
         {:ok, end_date} <- Date.from_iso8601(end_str) do
      entries = Journal.list_entries_by_date_range(user, start_date, end_date)

      conn
      |> put_status(:ok)
      |> json(%{entries: Enum.map(entries, &serialize_entry/1)})
    else
      _ -> {:error, :bad_request}
    end
  end

  def show_entry(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Journal.get_journal_entry(id, user) do
      nil ->
        {:error, :not_found}

      entry ->
        conn
        |> put_status(:ok)
        |> json(%{entry: serialize_entry(entry)})
    end
  end

  def create_entry(conn, %{"entry" => entry_params}) do
    user = conn.assigns.current_user
    key = get_session_key(conn)

    case Journal.create_journal_entry(user, entry_params, key) do
      {:ok, entry} ->
        conn
        |> put_status(:created)
        |> json(%{entry: serialize_entry(entry)})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_entry(conn, %{"id" => id, "entry" => entry_params}) do
    user = conn.assigns.current_user
    key = get_session_key(conn)

    case Journal.get_journal_entry(id, user) do
      nil ->
        {:error, :not_found}

      entry ->
        case Journal.update_journal_entry(entry, entry_params, user, key) do
          {:ok, updated_entry} ->
            conn
            |> put_status(:ok)
            |> json(%{entry: serialize_entry(updated_entry)})

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  def delete_entry(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Journal.get_journal_entry(id, user) do
      nil ->
        {:error, :not_found}

      entry ->
        case Journal.delete_journal_entry(entry, user) do
          {:ok, _entry} ->
            conn
            |> put_status(:ok)
            |> json(%{deleted: true})

          {:error, :unauthorized} ->
            {:error, :unauthorized}

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  def toggle_favorite(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Journal.get_journal_entry(id, user) do
      nil ->
        {:error, :not_found}

      entry ->
        case Journal.toggle_favorite(entry, user) do
          {:ok, updated_entry} ->
            conn
            |> put_status(:ok)
            |> json(%{entry: serialize_entry(updated_entry)})

          {:error, :unauthorized} ->
            {:error, :unauthorized}

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  def move_to_book(conn, %{"id" => id, "book_id" => book_id}) do
    user = conn.assigns.current_user

    case Journal.get_journal_entry(id, user) do
      nil ->
        {:error, :not_found}

      entry ->
        case Journal.move_entry_to_book(entry, book_id, user) do
          {:ok, updated_entry} ->
            conn
            |> put_status(:ok)
            |> json(%{entry: serialize_entry(updated_entry)})

          {:error, :unauthorized} ->
            {:error, :unauthorized}

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  def count_entries(conn, _params) do
    user = conn.assigns.current_user
    count = Journal.count_entries(user)

    conn
    |> put_status(:ok)
    |> json(%{count: count})
  end

  def total_word_count(conn, _params) do
    user = conn.assigns.current_user
    count = Journal.total_word_count(user)

    conn
    |> put_status(:ok)
    |> json(%{count: count})
  end

  def streak_timestamps(conn, _params) do
    user = conn.assigns.current_user
    timestamps = Journal.adapter().streak_entry_timestamps(user)

    conn
    |> put_status(:ok)
    |> json(%{timestamps: Enum.map(timestamps, &NaiveDateTime.to_iso8601/1)})
  end

  def adjacent_entries(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user

    case Journal.get_journal_entry(id, user) do
      nil ->
        {:error, :not_found}

      entry ->
        opts = build_adjacent_opts(params)
        result = Journal.get_adjacent_entries(entry, user, opts)

        conn
        |> put_status(:ok)
        |> json(result)
    end
  end

  def entry_position(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Journal.get_journal_entry(id, user) do
      nil ->
        {:error, :not_found}

      entry ->
        {position, total} = Journal.get_entry_position_in_book(entry, user)

        conn
        |> put_status(:ok)
        |> json(%{position: position, total: total})
    end
  end

  # =====================
  # Insight Endpoints
  # =====================

  def show_insight(conn, _params) do
    user = conn.assigns.current_user

    case Journal.get_insight(user) do
      nil ->
        conn
        |> put_status(:ok)
        |> json(%{insight: nil})

      insight ->
        conn
        |> put_status(:ok)
        |> json(%{insight: serialize_insight(insight)})
    end
  end

  def upsert_insight(conn, %{"insight" => insight_params}) do
    user = conn.assigns.current_user
    key = get_session_key(conn)
    insight_text = insight_params["insight"]

    case Journal.upsert_insight(user, insight_text, key) do
      {:ok, insight} ->
        conn
        |> put_status(:ok)
        |> json(%{insight: serialize_insight(insight)})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # =====================
  # Private Helpers
  # =====================

  defp get_session_key(conn) do
    conn.assigns[:session_key]
  end

  defp build_list_opts(params) do
    []
    |> maybe_add_opt(:limit, params["limit"], &parse_int/1)
    |> maybe_add_opt(:offset, params["offset"], &parse_int/1)
    |> maybe_add_opt(:book_id, params["book_id"], & &1)
  end

  defp build_adjacent_opts(params) do
    []
    |> maybe_add_opt(:book_id, params["book_id"], & &1)
    |> maybe_add_opt(:loose_only, params["loose_only"], &parse_bool/1)
  end

  defp maybe_add_opt(opts, _key, nil, _parser), do: opts

  defp maybe_add_opt(opts, key, value, parser) do
    case parser.(value) do
      nil -> opts
      parsed -> Keyword.put(opts, key, parsed)
    end
  end

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_int(value) when is_integer(value), do: value
  defp parse_int(_), do: nil

  defp parse_bool("true"), do: true
  defp parse_bool("false"), do: false
  defp parse_bool(true), do: true
  defp parse_bool(false), do: false
  defp parse_bool(_), do: nil

  defp serialize_book(%JournalBook{} = book) do
    %{
      id: book.id,
      user_id: book.user_id,
      title: book.title,
      description: book.description,
      cover_image_url: book.cover_image_url,
      entry_count: book.entry_count || 0,
      inserted_at: book.inserted_at,
      updated_at: book.updated_at
    }
  end

  defp serialize_entry(%JournalEntry{} = entry) do
    %{
      id: entry.id,
      user_id: entry.user_id,
      book_id: entry.book_id,
      title: entry.title,
      body: entry.body,
      mood: entry.mood,
      word_count: entry.word_count || 0,
      entry_date: entry.entry_date,
      is_favorite: entry.is_favorite || false,
      inserted_at: entry.inserted_at,
      updated_at: entry.updated_at
    }
  end

  defp serialize_insight(insight) do
    %{
      id: insight.id,
      user_id: insight.user_id,
      insight: insight.insight,
      generated_at: insight.generated_at,
      inserted_at: insight.inserted_at,
      updated_at: insight.updated_at
    }
  end
end
