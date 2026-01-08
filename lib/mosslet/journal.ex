defmodule Mosslet.Journal do
  @moduledoc """
  The Journal context.

  Provides a private journaling feature for personal reflection.
  Journal entries are encrypted with the user's personal key and
  are never shared with anyone.

  This context uses platform-aware adapters for database operations:
  - Web (Fly.io): Direct Postgres access via `Mosslet.Journal.Adapters.Web`
  - Native (Desktop/Mobile): API calls via `Mosslet.Journal.Adapters.Native`

  The adapter is selected at runtime based on `Mosslet.Platform.native?()`.
  """

  alias Mosslet.Journal.{JournalBook, JournalEntry, JournalInsight}
  alias Mosslet.Encrypted.Users.Utils, as: EncryptedUtils
  alias Mosslet.Platform

  @doc """
  Returns the appropriate adapter module based on the current platform.
  """
  def adapter do
    if Platform.native?() do
      Module.concat([__MODULE__, Adapters, Native])
    else
      Mosslet.Journal.Adapters.Web
    end
  end

  # =====================
  # Book Functions
  # =====================

  def list_books(user) do
    adapter().list_books(user)
  end

  def get_book!(id, user) do
    adapter().get_book!(id, user)
  end

  def get_book(id, user) do
    adapter().get_book(id, user)
  end

  def create_book(user, attrs, key) do
    changeset =
      %JournalBook{}
      |> JournalBook.changeset(Map.put(attrs, "user_id", user.id), user: user, key: key)

    adapter().create_book(changeset)
  end

  def update_book(%JournalBook{} = book, attrs, user, key) do
    changeset = JournalBook.changeset(book, attrs, user: user, key: key)
    adapter().update_book(changeset)
  end

  def delete_book(%JournalBook{} = book, user, key \\ nil) do
    if book.user_id == user.id do
      if book.cover_image_url && key do
        decrypted_url = EncryptedUtils.decrypt_user_data(book.cover_image_url, user, key)
        Mosslet.FileUploads.JournalCoverUploadWriter.delete_cover_image(decrypted_url)
      end

      adapter().delete_book(book)
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
    adapter().update_book_cover_image(book, encrypted_url)
  end

  def clear_book_cover_image(%JournalBook{} = book) do
    adapter().clear_book_cover_image(book)
  end

  # =====================
  # Entry Functions
  # =====================

  def list_journal_entries(user, opts \\ []) do
    adapter().list_journal_entries(user, opts)
  end

  def list_loose_entries(user, opts \\ []) do
    adapter().list_loose_entries(user, opts)
  end

  def count_loose_entries(user) do
    adapter().count_loose_entries(user)
  end

  def list_favorite_entries(user, opts \\ []) do
    adapter().list_favorite_entries(user, opts)
  end

  def list_entries_by_date_range(user, start_date, end_date) do
    adapter().list_entries_by_date_range(user, start_date, end_date)
  end

  def get_journal_entry!(id, user) do
    adapter().get_journal_entry!(id, user)
  end

  def get_journal_entry(id, user) do
    adapter().get_journal_entry(id, user)
  end

  def create_journal_entry(user, attrs, key) do
    changeset =
      %JournalEntry{}
      |> JournalEntry.changeset(Map.put(attrs, "user_id", user.id), user: user, key: key)

    adapter().create_journal_entry(changeset)
  end

  def update_journal_entry(%JournalEntry{} = entry, attrs, user, key) do
    changeset = JournalEntry.changeset(entry, attrs, user: user, key: key)
    adapter().update_journal_entry(changeset)
  end

  def delete_journal_entry(%JournalEntry{} = entry, user) do
    if entry.user_id == user.id do
      adapter().delete_journal_entry(entry)
    else
      {:error, :unauthorized}
    end
  end

  def toggle_favorite(%JournalEntry{} = entry, user) do
    if entry.user_id == user.id do
      adapter().toggle_favorite(entry)
    else
      {:error, :unauthorized}
    end
  end

  def move_entry_to_book(%JournalEntry{} = entry, book_id, user) do
    if entry.user_id == user.id do
      adapter().move_entry_to_book(entry, book_id)
    else
      {:error, :unauthorized}
    end
  end

  def count_entries(user) do
    adapter().count_entries(user)
  end

  def count_book_entries(book_id) do
    adapter().count_book_entries(book_id)
  end

  def total_word_count(user) do
    adapter().total_word_count(user)
  end

  def streak_days(user, today \\ nil) do
    today = today || Date.utc_today()
    entries = adapter().streak_entry_dates(user)
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
    adapter().get_adjacent_entries(entry, user, opts)
  end

  def get_entry_position_in_book(%JournalEntry{} = entry, user) do
    adapter().get_entry_position_in_book(entry, user)
  end

  # =====================
  # Insight Functions
  # =====================

  @insight_auto_refresh_days 7
  @insight_manual_cooldown_hours 24

  def get_insight(user) do
    adapter().get_insight(user)
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
    existing = adapter().get_insight(user)

    changeset =
      if existing do
        JournalInsight.changeset(
          existing,
          %{insight: insight_text, generated_at: now},
          user: user,
          key: key
        )
      else
        JournalInsight.changeset(
          %JournalInsight{},
          %{insight: insight_text, generated_at: now, user_id: user.id},
          user: user,
          key: key
        )
      end

    adapter().upsert_insight(changeset, existing)
  end
end
