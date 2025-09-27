defmodule Mosslet.Timeline.USerTimelinePreference do
  @moduledoc """
  User preferences for timeline navigation and display.

  Stores UI preferences (plaintext) and content filtering (encrypted).
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_timeline_preferences" do
    # Timeline tab preferences (plaintext - UI preferences, not sensitive)
    field :default_tab, :string, default: "home"

    field :tab_order, {:array, :string},
      default: ["home", "connections", "groups", "bookmarks", "discover"]

    field :hidden_tabs, {:array, :string}, default: []

    # View preferences (plaintext - UI settings)
    field :posts_per_page, :integer, default: 25
    field :auto_refresh, :boolean, default: true
    field :show_post_counts, :boolean, default: true
    field :hide_reposts, :boolean, default: false
    field :hide_mature_content, :boolean, default: false

    # Content filtering preferences (encrypted - potentially sensitive)
    # Encrypted list of muted keywords using StringList type (handles JSON automatically)
    field :mute_keywords, Mosslet.Encrypted.StringList
    # Hash for keyword matching
    field :mute_keywords_hash, Mosslet.Encrypted.HMAC

    # Encrypted list of muted user IDs (JSON array of binary_ids)
    field :muted_users, Mosslet.Encrypted.Binary
    field :muted_users_hash, Mosslet.Encrypted.HMAC

    belongs_to :user, User

    timestamps()
  end

  @valid_content_warning_categories ~w(mental_health violence substance_use politics personal other)

  @doc false
  def changeset(preferences, attrs, opts \\ []) do
    preferences
    |> cast(attrs, [
      :default_tab,
      :tab_order,
      :hidden_tabs,
      :posts_per_page,
      :auto_refresh,
      :show_post_counts,
      :hide_reposts,
      :hide_mature_content,
      :mute_keywords,
      :muted_users,
      :user_id
    ])
    |> validate_required([:user_id])
    |> validate_inclusion(:default_tab, ["home", "connections", "groups", "bookmarks", "discover"])
    |> validate_number(:posts_per_page, greater_than: 0, less_than_or_equal_to: 100)
    |> validate_tab_order()
    |> validate_mute_keywords_category()
    |> encrypt_mute_keywords(opts)
    |> encrypt_muted_users(opts)
    |> unique_constraint(:user_id)
  end

  defp validate_tab_order(changeset) do
    tab_order = get_field(changeset, :tab_order)
    valid_tabs = ["home", "connections", "groups", "bookmarks", "discover"]

    if tab_order && Enum.all?(tab_order, &(&1 in valid_tabs)) do
      changeset
    else
      add_error(changeset, :tab_order, "contains invalid tab names")
    end
  end

  defp validate_mute_keywords_category(changeset) do
    # With StringList type, mute_keywords is already a list at this point
    mute_keywords = get_field(changeset, :mute_keywords)

    cond do
      # Empty list or nil - valid
      is_nil(mute_keywords) or mute_keywords == [] ->
        changeset

      # List of keywords - validate each one
      is_list(mute_keywords) ->
        if Enum.all?(mute_keywords, &(&1 in @valid_content_warning_categories)) do
          changeset
        else
          add_error(changeset, :mute_keywords, "contains invalid content warning categories")
        end

      # Single string - convert to list format for StringList
      is_binary(mute_keywords) and String.trim(mute_keywords) != "" ->
        category = String.trim(mute_keywords)

        if category in @valid_content_warning_categories do
          # Convert single category to list for StringList field
          put_change(changeset, :mute_keywords, [category])
        else
          add_error(changeset, :mute_keywords, "must be a valid content warning category")
        end

      # Invalid type
      true ->
        add_error(changeset, :mute_keywords, "must be a list of valid content warning categories")
    end
  end

  defp encrypt_mute_keywords(changeset, opts) do
    if changeset.valid? && opts[:user] && opts[:key] do
      mute_keywords = get_field(changeset, :mute_keywords)

      if mute_keywords && length(mute_keywords) > 0 do
        # StringList type handles encryption automatically, but we need the hash for searching
        # Create hash from all keywords for search/cache invalidation
        hash_value = mute_keywords |> Enum.join(",") |> String.downcase()

        changeset
        |> put_change(:mute_keywords_hash, hash_value)
      else
        changeset
      end
    else
      changeset
    end
  end

  defp encrypt_muted_users(changeset, opts) do
    if changeset.valid? && opts[:user] && opts[:key] do
      muted_users = get_field(changeset, :muted_users)

      if muted_users && String.trim(muted_users) != "" do
        # Encrypt with user_key (same as other personal data)
        encrypted_users =
          Mosslet.Encrypted.Users.Utils.encrypt_user_data(
            muted_users,
            opts[:user],
            opts[:key]
          )

        # Create hash for all user IDs (for search/cache invalidation)
        user_ids = Jason.decode!(muted_users)
        hash_value = Enum.join(user_ids, ",") |> String.downcase()

        changeset
        |> put_change(:muted_users, encrypted_users)
        |> put_change(:muted_users_hash, hash_value)
      else
        changeset
      end
    else
      changeset
    end
  end
end
