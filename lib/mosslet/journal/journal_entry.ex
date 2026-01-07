defmodule Mosslet.Journal.JournalEntry do
  @moduledoc """
  A private journal entry for personal reflection.

  Journal entries are encrypted with the user's personal key (user_key)
  and are NEVER shared with connections or anyone else. This is strictly
  private, user-only content.

  Encryption pattern: user_key only (no dual-update, no conn_key)
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User
  alias Mosslet.Encrypted
  alias Mosslet.Journal.JournalBook

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "journal_entries" do
    field :title, Encrypted.Binary
    field :title_hash, Encrypted.HMAC
    field :body, Encrypted.Binary
    field :mood, Ecto.Enum, values: [:grateful, :happy, :calm, :neutral, :anxious, :sad, :angry]
    field :is_favorite, :boolean, default: false
    field :word_count, :integer, default: 0
    field :entry_date, :date

    belongs_to :user, User
    belongs_to :book, JournalBook

    timestamps()
  end

  def changeset(journal_entry, attrs, opts \\ []) do
    journal_entry
    |> cast(attrs, [:title, :body, :mood, :is_favorite, :entry_date, :user_id, :book_id])
    |> validate_required([:body])
    |> validate_length(:title, max: 200)
    |> validate_length(:body, max: 50_000)
    |> set_entry_date()
    |> calculate_word_count()
    |> add_title_hash()
    |> maybe_require_user_id(opts)
    |> encrypt_attrs(opts)
  end

  defp maybe_require_user_id(changeset, opts) do
    if opts[:user] do
      validate_required(changeset, [:user_id])
    else
      changeset
    end
  end

  defp set_entry_date(changeset) do
    if get_field(changeset, :entry_date) do
      changeset
    else
      put_change(changeset, :entry_date, Date.utc_today())
    end
  end

  defp calculate_word_count(changeset) do
    body = get_field(changeset, :body)

    if body && is_binary(body) do
      word_count =
        body
        |> String.split(~r/\s+/, trim: true)
        |> length()

      put_change(changeset, :word_count, word_count)
    else
      changeset
    end
  end

  defp add_title_hash(changeset) do
    if title = get_change(changeset, :title) do
      put_change(changeset, :title_hash, String.downcase(title))
    else
      changeset
    end
  end

  defp encrypt_attrs(changeset, opts) do
    if changeset.valid? && opts[:user] && opts[:key] do
      changeset
      |> maybe_encrypt_title(opts)
      |> encrypt_body(opts)
    else
      changeset
    end
  end

  defp maybe_encrypt_title(changeset, opts) do
    if title = get_change(changeset, :title) do
      encrypted_title =
        Encrypted.Users.Utils.encrypt_user_data(title, opts[:user], opts[:key])

      put_change(changeset, :title, encrypted_title)
    else
      changeset
    end
  end

  defp encrypt_body(changeset, opts) do
    if body = get_change(changeset, :body) do
      encrypted_body =
        Encrypted.Users.Utils.encrypt_user_data(body, opts[:user], opts[:key])

      put_change(changeset, :body, encrypted_body)
    else
      changeset
    end
  end
end
