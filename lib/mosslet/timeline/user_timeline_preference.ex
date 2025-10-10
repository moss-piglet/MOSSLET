defmodule Mosslet.Timeline.UserTimelinePreference do
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
    field :hide_content_warnings, :boolean, default: false

    # Content filtering preferences (encrypted - potentially sensitive)
    # Encrypted list of muted keywords - double encryption:
    # 1. Each keyword asymmetrically encrypted with user_key (enacl)
    # 2. List of encrypted values symmetrically encrypted for storage (Cloak StringList)
    field :mute_keywords, Mosslet.Encrypted.StringList
    field :mute_keywords_hash, Mosslet.Encrypted.HMAC

    # Encrypted list of muted user IDs - double encryption:
    # 1. Each user_id asymmetrically encrypted with user_key (enacl)
    # 2. List of encrypted values symmetrically encrypted for storage (Cloak StringList)
    field :muted_users, Mosslet.Encrypted.StringList
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
      :hide_content_warnings,
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
        # Asymmetrically encrypt each keyword individually with user_key
        encrypted_keywords =
          Enum.map(mute_keywords, fn keyword ->
            Mosslet.Encrypted.Users.Utils.encrypt_user_data(
              # Encrypt each keyword separately
              keyword,
              opts[:user],
              opts[:key]
            )
          end)

        # Create hash from all keywords for search/cache invalidation
        hash_value = mute_keywords |> Enum.join(",") |> String.downcase()

        changeset
        # StringList will symmetrically encrypt this list of asymmetrically encrypted values
        |> put_change(:mute_keywords, encrypted_keywords)
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

      if muted_users && length(muted_users) > 0 do
        # Asymmetrically encrypt each user_id individually with user_key
        encrypted_user_ids =
          Enum.map(muted_users, fn user_id ->
            Mosslet.Encrypted.Users.Utils.encrypt_user_data(
              # Encrypt each user_id separately
              user_id,
              opts[:user],
              opts[:key]
            )
          end)

        # Create hash for all user IDs (for search/cache invalidation)
        hash_value = Enum.join(muted_users, ",") |> String.downcase()

        changeset
        # StringList will symmetrically encrypt this list of asymmetrically encrypted values
        |> put_change(:muted_users, encrypted_user_ids)
        |> put_change(:muted_users_hash, hash_value)
      else
        changeset
      end
    else
      changeset
    end
  end
end
