defmodule Mosslet.Timeline.ContentWarningCategory do
  @moduledoc """
  A content warning category for organizing different types of content warnings.

  Can be system-defined (global categories) or user-defined (personal categories).
  Uses Cloak encryption for name and description to allow searching while maintaining privacy.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "content_warning_categories" do
    # ENCRYPTED FIELDS (Cloak - searchable while encrypted)
    # Category name (e.g., "Mental Health")
    field :name, Mosslet.Encrypted.Binary
    # For searching categories by name
    field :name_hash, Mosslet.Encrypted.HMAC
    # Category description
    field :description, Mosslet.Encrypted.Binary

    # PLAINTEXT FIELDS (system data for UI/display)
    # System vs user-defined
    field :is_system_category, :boolean, default: false
    # amber, red, orange, yellow
    field :color, :string, default: "amber"
    # Hero icon name
    field :icon, :string, default: "hero-exclamation-triangle"

    field :severity_level, Ecto.Enum,
      values: [:low, :medium, :high],
      default: :medium

    # RELATIONSHIPS (null for system categories)
    # null for system categories
    belongs_to :user, User

    timestamps()
  end

  @doc """
  Creates changeset for content warning category.

  ## Examples

      # System category
      iex> ContentWarningCategory.changeset(%ContentWarningCategory{}, %{
      ...>   name: "Mental Health",
      ...>   description: "Content related to mental health, depression, anxiety",
      ...>   is_system_category: true,
      ...>   severity_level: :high,
      ...>   color: "red"
      ...> })
      
      # User category  
      iex> ContentWarningCategory.changeset(%ContentWarningCategory{}, %{
      ...>   name: "Food",
      ...>   description: "Food content that might trigger eating disorders",
      ...>   severity_level: :medium,
      ...>   user_id: user.id
      ...> })
  """
  def changeset(category, attrs, _opts \\ []) do
    category
    |> cast(attrs, [
      :name,
      :description,
      :is_system_category,
      :color,
      :icon,
      :severity_level,
      :user_id
    ])
    |> validate_required([:name, :severity_level])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_inclusion(:color, ["amber", "red", "orange", "yellow", "purple", "blue"])
    |> validate_system_category_rules()
    |> add_name_hash()
    |> unique_constraint([:name_hash, :user_id],
      name: :content_warning_categories_name_user_index,
      message: "You already have a category with this name"
    )
  end

  # System categories can't have user_id, user categories must have user_id
  defp validate_system_category_rules(changeset) do
    is_system = get_field(changeset, :is_system_category)
    user_id = get_field(changeset, :user_id)

    cond do
      is_system && user_id ->
        add_error(changeset, :user_id, "System categories cannot have a user_id")

      !is_system && !user_id ->
        add_error(changeset, :user_id, "User categories must have a user_id")

      true ->
        changeset
    end
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
