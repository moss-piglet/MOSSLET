defmodule Mosslet.Journal.Adapter do
  @moduledoc """
  Behaviour defining the interface for platform-specific journal operations.

  This enables the same context API to work across web (direct Repo access)
  and native (API + cache) platforms.

  ## Implementation

  Web adapter (`Mosslet.Journal.Adapters.Web`):
  - Direct Postgres access via `Mosslet.Repo`
  - Uses `Fly.Repo.transaction_on_primary/1` for writes

  Native adapter (`Mosslet.Journal.Adapters.Native`):
  - HTTP API calls to cloud server via `Mosslet.API.Client`
  - Local SQLite cache via `Mosslet.Cache`
  - Offline fallback to cached data

  ## Pattern

  Following the thin adapter pattern:
  - Business logic stays in the context (`Mosslet.Journal`)
  - Adapters only handle data access (Repo calls for web, API+cache for native)
  - Context orchestrates by calling adapter for data, then applying business logic

  Note: Journal entries are encrypted with user keys - decryption happens on-device
  for native apps (zero-knowledge), server-side for web.
  """

  alias Mosslet.Journal.{JournalBook, JournalEntry, JournalInsight}

  # =====================
  # Book Functions
  # =====================

  @callback list_books(user :: any()) :: [JournalBook.t()]

  @callback get_book!(id :: binary(), user :: any()) :: JournalBook.t()

  @callback get_book(id :: binary(), user :: any()) :: JournalBook.t() | nil

  @callback create_book(changeset :: Ecto.Changeset.t()) ::
              {:ok, JournalBook.t()} | {:error, Ecto.Changeset.t()}

  @callback update_book(changeset :: Ecto.Changeset.t()) ::
              {:ok, JournalBook.t()} | {:error, Ecto.Changeset.t()}

  @callback delete_book(book :: JournalBook.t()) ::
              {:ok, JournalBook.t()} | {:error, Ecto.Changeset.t()}

  @callback update_book_cover_image(book :: JournalBook.t(), encrypted_url :: binary()) ::
              {:ok, JournalBook.t()} | {:error, Ecto.Changeset.t()}

  @callback clear_book_cover_image(book :: JournalBook.t()) ::
              {:ok, JournalBook.t()} | {:error, Ecto.Changeset.t()}

  @callback update_book_positions(user :: any(), positions :: list({binary(), integer()})) ::
              :ok | {:error, term()}

  # =====================
  # Entry Functions
  # =====================

  @callback list_journal_entries(user :: any(), opts :: keyword()) :: [JournalEntry.t()]

  @callback list_loose_entries(user :: any(), opts :: keyword()) :: [JournalEntry.t()]

  @callback count_loose_entries(user :: any()) :: non_neg_integer()

  @callback list_favorite_entries(user :: any(), opts :: keyword()) :: [JournalEntry.t()]

  @callback list_entries_by_date_range(
              user :: any(),
              start_date :: Date.t(),
              end_date :: Date.t()
            ) ::
              [JournalEntry.t()]

  @callback get_journal_entry!(id :: binary(), user :: any()) :: JournalEntry.t()

  @callback get_journal_entry(id :: binary(), user :: any()) :: JournalEntry.t() | nil

  @callback create_journal_entry(changeset :: Ecto.Changeset.t()) ::
              {:ok, JournalEntry.t()} | {:error, Ecto.Changeset.t()}

  @callback update_journal_entry(changeset :: Ecto.Changeset.t()) ::
              {:ok, JournalEntry.t()} | {:error, Ecto.Changeset.t()}

  @callback delete_journal_entry(entry :: JournalEntry.t()) ::
              {:ok, JournalEntry.t()} | {:error, Ecto.Changeset.t()}

  @callback toggle_favorite(entry :: JournalEntry.t()) ::
              {:ok, JournalEntry.t()} | {:error, Ecto.Changeset.t()}

  @callback move_entry_to_book(entry :: JournalEntry.t(), book_id :: binary() | nil) ::
              {:ok, JournalEntry.t()} | {:error, Ecto.Changeset.t()}

  @callback count_entries(user :: any()) :: non_neg_integer()

  @callback count_book_entries(book_id :: binary()) :: non_neg_integer()

  @callback total_word_count(user :: any()) :: non_neg_integer()

  @callback streak_entry_timestamps(user :: any()) :: [NaiveDateTime.t()]

  @callback get_adjacent_entries(entry :: JournalEntry.t(), user :: any(), opts :: keyword()) ::
              %{prev_id: binary() | nil, next_id: binary() | nil}

  @callback get_entry_position_in_book(entry :: JournalEntry.t(), user :: any()) ::
              {non_neg_integer() | nil, non_neg_integer() | nil}

  # =====================
  # Insight Functions
  # =====================

  @callback get_insight(user :: any()) :: JournalInsight.t() | nil

  @callback upsert_insight(changeset :: Ecto.Changeset.t(), existing :: JournalInsight.t() | nil) ::
              {:ok, JournalInsight.t()} | {:error, Ecto.Changeset.t()}
end
