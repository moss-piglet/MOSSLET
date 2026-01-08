defmodule Mosslet.Journal do
  @moduledoc """
  The Journal context.

  Provides a private journaling feature for personal reflection.
  Journal entries are encrypted with the user's personal key and
  are never shared with anyone.
  """
  import Ecto.Query, warn: false

  alias Mosslet.Repo
  alias Mosslet.Journal.{JournalBook, JournalEntry, JournalInsight}
  alias Mosslet.Encrypted.Users.Utils, as: EncryptedUtils

  # =====================
  # Book Functions
  # =====================

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

  def get_book!(id, user) do
    from(b in JournalBook,
      where: b.id == ^id and b.user_id == ^user.id,
      left_join: e in assoc(b, :entries),
      group_by: b.id,
      select: %{b | entry_count: count(e.id)}
    )
    |> Repo.one!()
  end

  def get_book(id, user) do
    from(b in JournalBook,
      where: b.id == ^id and b.user_id == ^user.id,
      left_join: e in assoc(b, :entries),
      group_by: b.id,
      select: %{b | entry_count: count(e.id)}
    )
    |> Repo.one()
  end

  def create_book(user, attrs, key) do
    Repo.transaction_on_primary(fn ->
      %JournalBook{}
      |> JournalBook.changeset(Map.put(attrs, "user_id", user.id), user: user, key: key)
      |> Repo.insert()
    end)
    |> handle_transaction_result()
  end

  def update_book(%JournalBook{} = book, attrs, user, key) do
    Repo.transaction_on_primary(fn ->
      book
      |> JournalBook.changeset(attrs, user: user, key: key)
      |> Repo.update()
    end)
    |> handle_transaction_result()
  end

  def delete_book(%JournalBook{} = book, user, key \\ nil) do
    if book.user_id == user.id do
      if book.cover_image_url && key do
        decrypted_url = EncryptedUtils.decrypt_user_data(book.cover_image_url, user, key)
        Mosslet.FileUploads.JournalCoverUploadWriter.delete_cover_image(decrypted_url)
      end

      Repo.transaction_on_primary(fn ->
        Repo.delete(book)
      end)
      |> handle_transaction_result()
    else
      {:error, :unauthorized}
    end
  end

  def decrypt_book(%JournalBook{} = book, user, key) do
    title = EncryptedUtils.decrypt_user_data(book.title, user, key)

    description =
      if book.description do
        EncryptedUtils.decrypt_user_data(book.description, user, key)
      else
        nil
      end

    cover_image_url =
      if book.cover_image_url do
        EncryptedUtils.decrypt_user_data(book.cover_image_url, user, key)
      else
        nil
      end

    %{book | title: title, description: description, cover_image_url: cover_image_url}
  end

  def change_book(%JournalBook{} = book, attrs \\ %{}) do
    JournalBook.changeset(book, attrs, [])
  end

  def update_book_cover_image(%JournalBook{} = book, cover_image_url, user, key) do
    encrypted_url = EncryptedUtils.encrypt_user_data(cover_image_url, user, key)

    Repo.transaction_on_primary(fn ->
      book
      |> Ecto.Changeset.change(cover_image_url: encrypted_url)
      |> Repo.update()
    end)
    |> handle_transaction_result()
  end

  def clear_book_cover_image(%JournalBook{} = book) do
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

  def list_journal_entries(user, opts \\ []) do
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

  def list_loose_entries(user, opts \\ []) do
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

  def count_loose_entries(user) do
    from(j in JournalEntry,
      where: j.user_id == ^user.id and is_nil(j.book_id),
      select: count(j.id)
    )
    |> Repo.one()
  end

  def list_favorite_entries(user, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    from(j in JournalEntry,
      where: j.user_id == ^user.id and j.is_favorite == true,
      order_by: [desc: j.entry_date, desc: j.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

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

  def get_journal_entry!(id, user) do
    from(j in JournalEntry,
      where: j.id == ^id and j.user_id == ^user.id
    )
    |> Repo.one!()
  end

  def get_journal_entry(id, user) do
    from(j in JournalEntry,
      where: j.id == ^id and j.user_id == ^user.id
    )
    |> Repo.one()
  end

  def create_journal_entry(user, attrs, key) do
    Repo.transaction_on_primary(fn ->
      %JournalEntry{}
      |> JournalEntry.changeset(Map.put(attrs, "user_id", user.id), user: user, key: key)
      |> Repo.insert()
    end)
    |> handle_transaction_result()
  end

  def update_journal_entry(%JournalEntry{} = entry, attrs, user, key) do
    Repo.transaction_on_primary(fn ->
      entry
      |> JournalEntry.changeset(attrs, user: user, key: key)
      |> Repo.update()
    end)
    |> handle_transaction_result()
  end

  def delete_journal_entry(%JournalEntry{} = entry, user) do
    if entry.user_id == user.id do
      Repo.transaction_on_primary(fn ->
        Repo.delete(entry)
      end)
      |> handle_transaction_result()
    else
      {:error, :unauthorized}
    end
  end

  def toggle_favorite(%JournalEntry{} = entry, user) do
    if entry.user_id == user.id do
      Repo.transaction_on_primary(fn ->
        entry
        |> Ecto.Changeset.change(is_favorite: !entry.is_favorite)
        |> Repo.update()
      end)
      |> handle_transaction_result()
    else
      {:error, :unauthorized}
    end
  end

  def move_entry_to_book(%JournalEntry{} = entry, book_id, user) do
    if entry.user_id == user.id do
      Repo.transaction_on_primary(fn ->
        entry
        |> Ecto.Changeset.change(book_id: book_id)
        |> Repo.update()
      end)
      |> handle_transaction_result()
    else
      {:error, :unauthorized}
    end
  end

  def count_entries(user) do
    from(j in JournalEntry, where: j.user_id == ^user.id, select: count(j.id))
    |> Repo.one()
  end

  def count_book_entries(book_id) do
    from(j in JournalEntry, where: j.book_id == ^book_id, select: count(j.id))
    |> Repo.one()
  end

  def total_word_count(user) do
    from(j in JournalEntry,
      where: j.user_id == ^user.id,
      select: coalesce(sum(j.word_count), 0)
    )
    |> Repo.one()
  end

  def streak_days(user, today \\ nil) do
    today = today || Date.utc_today()

    entries =
      from(j in JournalEntry,
        where: j.user_id == ^user.id,
        select: j.entry_date,
        distinct: true,
        order_by: [desc: j.entry_date]
      )
      |> Repo.all()

    calculate_streak(entries, today, 0)
  end

  defp calculate_streak([], _expected_date, count), do: count

  defp calculate_streak([date | rest], expected_date, count) do
    cond do
      Date.compare(date, expected_date) == :eq ->
        calculate_streak(rest, Date.add(expected_date, -1), count + 1)

      Date.compare(date, expected_date) == :gt ->
        calculate_streak(rest, expected_date, count)

      true ->
        count
    end
  end

  def decrypt_entry(%JournalEntry{} = entry, user, key) do
    title =
      if entry.title do
        EncryptedUtils.decrypt_user_data(entry.title, user, key)
      else
        nil
      end

    body = EncryptedUtils.decrypt_user_data(entry.body, user, key)

    mood =
      if entry.mood do
        EncryptedUtils.decrypt_user_data(entry.mood, user, key)
      else
        nil
      end

    %{entry | title: title, body: body, mood: mood}
  end

  def change_journal_entry(%JournalEntry{} = entry, attrs \\ %{}) do
    JournalEntry.changeset(entry, attrs, [])
  end

  def get_adjacent_entries(%JournalEntry{} = entry, user, opts \\ []) do
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

  def get_entry_position_in_book(%JournalEntry{} = entry, user) do
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

  defp handle_transaction_result({:ok, {:ok, result}}), do: {:ok, result}
  defp handle_transaction_result({:ok, {:error, changeset}}), do: {:error, changeset}
  defp handle_transaction_result({:error, _} = error), do: error

  # =====================
  # Insight Functions
  # =====================

  @insight_auto_refresh_days 7
  @insight_manual_cooldown_hours 24

  def get_insight(user) do
    from(i in JournalInsight, where: i.user_id == ^user.id)
    |> Repo.one()
  end

  def decrypt_insight(%JournalInsight{} = insight, user, key) do
    decrypted_text = EncryptedUtils.decrypt_user_data(insight.insight, user, key)
    %{insight | insight: decrypted_text}
  end

  def insight_needs_auto_refresh?(nil), do: true

  def insight_needs_auto_refresh?(%JournalInsight{} = insight) do
    cutoff = DateTime.add(DateTime.utc_now(), -@insight_auto_refresh_days, :day)
    DateTime.compare(insight.generated_at, cutoff) == :lt
  end

  def can_manually_refresh_insight?(nil), do: true

  def can_manually_refresh_insight?(%JournalInsight{} = insight) do
    cutoff = DateTime.add(DateTime.utc_now(), -@insight_manual_cooldown_hours, :hour)
    DateTime.compare(insight.generated_at, cutoff) == :lt
  end

  def hours_until_manual_refresh(%JournalInsight{} = insight) do
    next_refresh = DateTime.add(insight.generated_at, @insight_manual_cooldown_hours, :hour)
    diff_seconds = DateTime.diff(next_refresh, DateTime.utc_now())
    max(0, div(diff_seconds, 3600))
  end

  def upsert_insight(user, insight_text, key) do
    now = DateTime.utc_now()

    Repo.transaction_on_primary(fn ->
      case get_insight(user) do
        nil ->
          %JournalInsight{}
          |> JournalInsight.changeset(
            %{insight: insight_text, generated_at: now, user_id: user.id},
            user: user,
            key: key
          )
          |> Repo.insert()

        existing ->
          existing
          |> JournalInsight.changeset(
            %{insight: insight_text, generated_at: now},
            user: user,
            key: key
          )
          |> Repo.update()
      end
    end)
    |> handle_transaction_result()
  end
end
