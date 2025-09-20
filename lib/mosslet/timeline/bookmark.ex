defmodule Mosslet.Timeline.Bookmark do
  @moduledoc """
  A bookmark represents a user's saved post with optional notes.

  Uses the existing post_key encryption strategy:
  - Notes are encrypted with the same key as the associated post's body
  - Automatic cleanup when post is deleted (via cascade)
  - Same decryption flow as post content
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Encrypted
  alias Mosslet.Accounts.User
  alias Mosslet.Timeline.{Post, BookmarkCategory}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "bookmarks" do
    # ENCRYPTED FIELDS (using post_key - same encryption as post.body)
    # User's private notes about this bookmark
    field :notes, Encrypted.Binary

    # HASHED FIELDS (for searching bookmark notes)
    # Searchable hash for notes
    field :notes_hash, Mosslet.Encrypted.HMAC

    # RELATIONSHIPS
    # User who bookmarked
    belongs_to :user, User
    # Post being bookmarked
    belongs_to :post, Post
    # Optional categorization
    belongs_to :category, BookmarkCategory

    timestamps()
  end

  @doc """
  Creates changeset for bookmark with post_key encryption.

  ## Options

  - `:post_key` - Required. The decrypted post key for encrypting notes

  ## Examples

      iex> post_key = MossletWeb.Helpers.get_post_key(post, user)
      iex> Bookmark.changeset(%Bookmark{}, %{notes: "Great article!"}, post_key: post_key)
  """
  def changeset(bookmark, attrs, opts \\ []) do
    bookmark
    |> cast(attrs, [:notes, :user_id, :post_id, :category_id])
    |> validate_required([:user_id, :post_id])
    |> validate_length(:notes, max: 10_000)
    |> encrypt_notes_with_post_key(opts)
    |> unique_constraint([:user_id, :post_id],
      name: :bookmarks_user_post_index,
      message: "You have already bookmarked this post"
    )
  end

  # Use the SAME post_key that encrypts post.body for consistency
  defp encrypt_notes_with_post_key(changeset, opts) do
    if changeset.valid? && opts[:post_key] do
      notes = get_field(changeset, :notes)

      if notes && String.trim(notes) != "" do
        # Use SAME encryption method as Post.body - direct call like in Post model
        encrypted_notes =
          Mosslet.Encrypted.Utils.encrypt(%{
            key: opts[:post_key],
            payload: String.trim(notes)
          })

        changeset
        |> put_change(:notes, encrypted_notes)
        |> put_change(:notes_hash, String.downcase(String.trim(notes)))
      else
        # Allow bookmarks without notes
        changeset
        |> put_change(:notes, nil)
        |> put_change(:notes_hash, nil)
      end
    else
      changeset
    end
  end
end
