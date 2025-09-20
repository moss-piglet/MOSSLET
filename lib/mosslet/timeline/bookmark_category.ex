defmodule Mosslet.Timeline.BookmarkCategory do
  @moduledoc """
  A bookmark category for organizing user's bookmarks.

  Uses Cloak encryption for user-specific but searchable content:
  - Name and description are encrypted with Cloak
  - Name hash allows searching across user's own categories
  - Color and icon are plaintext system data
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User
  alias Mosslet.Timeline.Bookmark

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "bookmark_categories" do
    # ENCRYPTED FIELDS (Cloak - user-specific but searchable)
    # Category name (Cloak encrypted)
    field :name, Mosslet.Encrypted.Binary
    # For searching categories by name
    field :name_hash, Mosslet.Encrypted.HMAC
    # Category description
    field :description, Mosslet.Encrypted.Binary

    # PLAINTEXT FIELDS (system data, not sensitive)
    field :color, Ecto.Enum,
      values: [:emerald, :blue, :purple, :amber, :rose, :cyan],
      default: :emerald

    # Hero icon name
    field :icon, :string, default: "hero-bookmark"

    # RELATIONSHIPS
    belongs_to :user, User
    has_many :bookmarks, Bookmark, foreign_key: :category_id, on_delete: :nilify_all

    timestamps()
  end

  @doc """
  Creates changeset for bookmark category with Cloak encryption.

  ## Examples

      iex> BookmarkCategory.changeset(%BookmarkCategory{}, %{
      ...>   name: "Articles",
      ...>   description: "Interesting articles to read later",
      ...>   color: :emerald,
      ...>   icon: "hero-document-text"
      ...> })
  """
  def changeset(category, attrs, _opts \\ []) do
    category
    |> cast(attrs, [:name, :description, :color, :icon, :user_id])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:description, max: 500)
    |> add_name_hash()
    |> unique_constraint([:user_id, :name_hash],
      name: :bookmark_categories_user_name_index,
      message: "You already have a category with this name"
    )
  end

  # Add searchable hash for category name (Cloak will encrypt the name field automatically)
  defp add_name_hash(changeset) do
    if changeset.valid? do
      name = get_field(changeset, :name)

      if name && String.trim(name) != "" do
        put_change(changeset, :name_hash, String.downcase(String.trim(name)))
      else
        changeset
      end
    else
      changeset
    end
  end
end
