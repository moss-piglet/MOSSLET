defmodule Mosslet.Journal.JournalBook do
  @moduledoc """
  A journal book that groups related journal entries together.

  Books are encrypted with the user's personal key and are private.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User
  alias Mosslet.Encrypted
  alias Mosslet.Journal.JournalEntry

  @cover_colors ~w(yellow amber orange rose pink purple violet blue cyan teal emerald)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "journal_books" do
    field :title, Encrypted.Binary, redact: true
    field :title_hash, Encrypted.HMAC, redact: true
    field :description, Encrypted.Binary, redact: true
    field :cover_color, :string, default: "emerald"
    field :cover_image_url, Encrypted.Binary, redact: true
    field :position, :integer, default: 0

    field :entry_count, :integer, virtual: true, default: 0

    belongs_to :user, User
    has_many :entries, JournalEntry, foreign_key: :book_id

    timestamps()
  end

  def cover_colors, do: @cover_colors

  def changeset(book, attrs, opts \\ []) do
    book
    |> cast(attrs, [:title, :description, :cover_color, :cover_image_url, :user_id])
    |> validate_required([:title])
    |> validate_length(:title, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_inclusion(:cover_color, @cover_colors)
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

  defp add_title_hash(changeset) do
    if title = get_change(changeset, :title) do
      put_change(changeset, :title_hash, String.downcase(title))
    else
      changeset
    end
  end

  @doc """
  ZK changeset — accepts pre-encrypted title/description from browser.
  The server stores the ciphertext directly without re-encrypting.
  """
  def changeset_zk(book, attrs) do
    book
    |> cast(attrs, [:cover_color, :user_id])
    |> validate_required([:user_id])
    |> validate_inclusion(:cover_color, @cover_colors)
    |> put_zk_title(attrs)
    |> put_zk_description(attrs)
  end

  defp put_zk_title(changeset, %{"encrypted_title" => ct, "title_blind_index" => idx})
       when is_binary(ct) and ct != "" do
    changeset
    |> put_change(:title, ct)
    |> put_change(:title_hash, idx)
  end

  defp put_zk_title(changeset, _attrs) do
    add_error(changeset, :title, "is required")
  end

  defp put_zk_description(changeset, %{"encrypted_description" => ct})
       when is_binary(ct) and ct != "" do
    put_change(changeset, :description, ct)
  end

  defp put_zk_description(changeset, _attrs), do: changeset

  defp encrypt_attrs(changeset, opts) do
    if changeset.valid? && opts[:user] && opts[:key] do
      changeset
      |> encrypt_title(opts)
      |> maybe_encrypt_description(opts)
    else
      changeset
    end
  end

  defp encrypt_title(changeset, opts) do
    if title = get_change(changeset, :title) do
      encrypted = Encrypted.Users.Utils.encrypt_user_data(title, opts[:user], opts[:key])
      put_change(changeset, :title, encrypted)
    else
      changeset
    end
  end

  defp maybe_encrypt_description(changeset, opts) do
    if description = get_change(changeset, :description) do
      encrypted = Encrypted.Users.Utils.encrypt_user_data(description, opts[:user], opts[:key])
      put_change(changeset, :description, encrypted)
    else
      changeset
    end
  end
end
