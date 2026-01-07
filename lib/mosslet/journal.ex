defmodule Mosslet.Journal do
  @moduledoc """
  The Journal context.

  Provides a private journaling feature for personal reflection.
  Journal entries are encrypted with the user's personal key and
  are never shared with anyone.
  """
  import Ecto.Query, warn: false

  alias Mosslet.Repo
  alias Mosslet.Journal.JournalEntry
  alias Mosslet.Encrypted.Users.Utils, as: EncryptedUtils

  def list_journal_entries(user, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    from(j in JournalEntry,
      where: j.user_id == ^user.id,
      order_by: [desc: j.entry_date, desc: j.inserted_at],
      limit: ^limit,
      offset: ^offset
    )
    |> Repo.all()
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

  def count_entries(user) do
    from(j in JournalEntry, where: j.user_id == ^user.id, select: count(j.id))
    |> Repo.one()
  end

  def total_word_count(user) do
    from(j in JournalEntry,
      where: j.user_id == ^user.id,
      select: coalesce(sum(j.word_count), 0)
    )
    |> Repo.one()
  end

  def streak_days(user) do
    today = Date.utc_today()

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

    %{entry | title: title, body: body}
  end

  def change_journal_entry(%JournalEntry{} = entry, attrs \\ %{}) do
    JournalEntry.changeset(entry, attrs, [])
  end

  defp handle_transaction_result({:ok, {:ok, result}}), do: {:ok, result}
  defp handle_transaction_result({:ok, {:error, changeset}}), do: {:error, changeset}
  defp handle_transaction_result({:error, _} = error), do: error
end
