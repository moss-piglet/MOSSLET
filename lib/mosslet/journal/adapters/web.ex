defmodule Mosslet.Journal.Adapters.Web do
  @moduledoc """
  Web adapter for journal operations.

  This adapter uses direct Postgres access via `Mosslet.Repo`.
  This is the default adapter for web deployments on Fly.io.
  """

  @behaviour Mosslet.Journal.Adapter

  import Ecto.Query, warn: false

  alias Mosslet.Journal.{JournalBook, JournalEntry, JournalInsight}
  alias Mosslet.Repo

  # =====================
  # Book Functions
  # =====================

  @impl true
  def list_books(user) do
    from(b in JournalBook,
      where: b.user_id == ^user.id,
      left_join: e in assoc(b, :entries),
      group_by: b.id,
      select: %{b | entry_count: count(e.id)},
      order_by: [desc: b.updated_at]
    )
    |> Repo.all()
  end

  @impl true
  def get_book!(id, user) do
    from(b in JournalBook,
      where: b.id == ^id and b.user_id == ^user.id,
      left_join: e in assoc(b, :entries),
      group_by: b.id,
      select: %{b | entry_count: count(e.id)}
    )
    |> Repo.one!()
  end

  @impl true
  def get_book(id, user) do
    from(b in JournalBook,
      where: b.id == ^id and b.user_id == ^user.id,
      left_join: e in assoc(b, :entries),
      group_by: b.id,
      select: %{b | entry_count: count(e.id)}
    )
    |> Repo.one()
  end

  @impl true
  def create_book(changeset) do
    Repo.transaction_on_primary(fn ->
      Repo.insert(changeset)
    end)
    |> handle_transaction_result()
  end

  @impl true
  def update_book(changeset) do
    Repo.transaction_on_primary(fn ->
      Repo.update(changeset)
    end)
    |> handle_transaction_result()
  end

  @impl true
  def delete_book(book) do
    Repo.transaction_on_primary(fn ->
      Repo.delete(book)
    end)
    |> handle_transaction_result()
  end

  @impl true
  def update_book_cover_image(book, encrypted_url) do
    Repo.transaction_on_primary(fn ->
      book
      |> Ecto.Changeset.change(cover_image_url: encrypted_url)
      |> Repo.update()
    end)
    |> handle_transaction_result()
  end

  @impl true
  def clear_book_cover_image(book) do
    Repo.transaction_on_primary(fn ->
      book
      |> Ecto.Changeset.change(cover_image_url: nil)
      |> Repo.update()
    end)
    |> handle_transaction_result()
  end

  # =====================
  # Entry Functions
  # =====================

  @impl true
  def list_journal_entries(user, opts) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)
    book_id = Keyword.get(opts, :book_id)

    query =
      from(j in JournalEntry,
        where: j.user_id == ^user.id,
        order_by: [desc: j.entry_date, desc: j.inserted_at],
        limit: ^limit,
        offset: ^offset
      )

    query =
      if book_id do
        from(j in query, where: j.book_id == ^book_id)
      else
        query
      end

    Repo.all(query)
  end

  @impl true
  def list_loose_entries(user, opts) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    from(j in JournalEntry,
      where: j.user_id == ^user.id and is_nil(j.book_id),
      order_by: [desc: j.entry_date, desc: j.inserted_at],
      limit: ^limit,
      offset: ^offset
    )
    |> Repo.all()
  end

  @impl true
  def count_loose_entries(user) do
    from(j in JournalEntry,
      where: j.user_id == ^user.id and is_nil(j.book_id),
      select: count(j.id)
    )
    |> Repo.one()
  end

  @impl true
  def list_favorite_entries(user, opts) do
    limit = Keyword.get(opts, :limit, 20)

    from(j in JournalEntry,
      where: j.user_id == ^user.id and j.is_favorite == true,
      order_by: [desc: j.entry_date, desc: j.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @impl true
  def list_entries_by_date_range(user, start_date, end_date) do
    from(j in JournalEntry,
      where:
        j.user_id == ^user.id and
          j.entry_date >= ^start_date and
          j.entry_date <= ^end_date,
      order_by: [desc: j.entry_date]
    )
    |> Repo.all()
  end

  @impl true
  def get_journal_entry!(id, user) do
    from(j in JournalEntry,
      where: j.id == ^id and j.user_id == ^user.id
    )
    |> Repo.one!()
  end

  @impl true
  def get_journal_entry(id, user) do
    from(j in JournalEntry,
      where: j.id == ^id and j.user_id == ^user.id
    )
    |> Repo.one()
  end

  @impl true
  def create_journal_entry(changeset) do
    Repo.transaction_on_primary(fn ->
      Repo.insert(changeset)
    end)
    |> handle_transaction_result()
  end

  @impl true
  def update_journal_entry(changeset) do
    Repo.transaction_on_primary(fn ->
      Repo.update(changeset)
    end)
    |> handle_transaction_result()
  end

  @impl true
  def delete_journal_entry(entry) do
    Repo.transaction_on_primary(fn ->
      Repo.delete(entry)
    end)
    |> handle_transaction_result()
  end

  @impl true
  def toggle_favorite(entry) do
    Repo.transaction_on_primary(fn ->
      entry
      |> Ecto.Changeset.change(is_favorite: !entry.is_favorite)
      |> Repo.update()
    end)
    |> handle_transaction_result()
  end

  @impl true
  def move_entry_to_book(entry, book_id) do
    Repo.transaction_on_primary(fn ->
      entry
      |> Ecto.Changeset.change(book_id: book_id)
      |> Repo.update()
    end)
    |> handle_transaction_result()
  end

  @impl true
  def count_entries(user) do
    from(j in JournalEntry, where: j.user_id == ^user.id, select: count(j.id))
    |> Repo.one()
  end

  @impl true
  def count_book_entries(book_id) do
    from(j in JournalEntry, where: j.book_id == ^book_id, select: count(j.id))
    |> Repo.one()
  end

  @impl true
  def total_word_count(user) do
    from(j in JournalEntry,
      where: j.user_id == ^user.id,
      select: coalesce(sum(j.word_count), 0)
    )
    |> Repo.one()
  end

  @impl true
  def streak_entry_timestamps(user) do
    from(j in JournalEntry,
      where: j.user_id == ^user.id,
      select: j.inserted_at,
      order_by: [desc: j.inserted_at]
    )
    |> Repo.all()
  end

  @impl true
  def get_adjacent_entries(entry, user, opts) do
    book_id = Keyword.get(opts, :book_id)
    loose_only = Keyword.get(opts, :loose_only, false)

    base_query = from(j in JournalEntry, where: j.user_id == ^user.id)

    base_query =
      cond do
        book_id ->
          from(j in base_query, where: j.book_id == ^book_id)

        loose_only ->
          from(j in base_query, where: is_nil(j.book_id))

        true ->
          base_query
      end

    prev_entry =
      from(j in base_query,
        where:
          j.entry_date < ^entry.entry_date or
            (j.entry_date == ^entry.entry_date and j.inserted_at < ^entry.inserted_at),
        order_by: [desc: j.entry_date, desc: j.inserted_at],
        limit: 1,
        select: %{id: j.id}
      )
      |> Repo.one()

    next_entry =
      from(j in base_query,
        where:
          j.entry_date > ^entry.entry_date or
            (j.entry_date == ^entry.entry_date and j.inserted_at > ^entry.inserted_at),
        order_by: [asc: j.entry_date, asc: j.inserted_at],
        limit: 1,
        select: %{id: j.id}
      )
      |> Repo.one()

    %{
      prev_id: if(prev_entry, do: prev_entry.id, else: nil),
      next_id: if(next_entry, do: next_entry.id, else: nil)
    }
  end

  @impl true
  def get_entry_position_in_book(entry, user) do
    if entry.book_id do
      position =
        from(j in JournalEntry,
          where: j.user_id == ^user.id and j.book_id == ^entry.book_id,
          where:
            j.entry_date > ^entry.entry_date or
              (j.entry_date == ^entry.entry_date and j.inserted_at > ^entry.inserted_at),
          select: count(j.id)
        )
        |> Repo.one()

      total = count_book_entries(entry.book_id)
      {position + 1, total}
    else
      {nil, nil}
    end
  end

  # =====================
  # Insight Functions
  # =====================

  @impl true
  def get_insight(user) do
    from(i in JournalInsight, where: i.user_id == ^user.id)
    |> Repo.one()
  end

  @impl true
  def upsert_insight(changeset, existing) do
    Repo.transaction_on_primary(fn ->
      if existing do
        Repo.update(changeset)
      else
        Repo.insert(changeset)
      end
    end)
    |> handle_transaction_result()
  end

  # =====================
  # Private Helpers
  # =====================

  defp handle_transaction_result({:ok, {:ok, result}}), do: {:ok, result}
  defp handle_transaction_result({:ok, {:error, changeset}}), do: {:error, changeset}
  defp handle_transaction_result({:error, _} = error), do: error
end
