defmodule Mosslet.Timeline.UserTimelinePreferences do
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
    # Encrypted list of muted keywords (JSON array of strings)
    field :mute_keywords, Mosslet.Encrypted.Binary
    # Hash for keyword matching
    field :mute_keywords_hash, Mosslet.Encrypted.HMAC

    # Encrypted list of muted user IDs (JSON array of binary_ids)
    field :muted_users, Mosslet.Encrypted.Binary
    field :muted_users_hash, Mosslet.Encrypted.HMAC

    belongs_to :user, User

    timestamps()
  end

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

  defp encrypt_mute_keywords(changeset, opts) do
    if changeset.valid? && opts[:user] && opts[:key] do
      mute_keywords = get_field(changeset, :mute_keywords)

      if mute_keywords && String.trim(mute_keywords) != "" do
        # Encrypt with user_key (same as other personal data)
        encrypted_keywords =
          Mosslet.Encrypted.Users.Utils.encrypt_user_data(
            mute_keywords,
            opts[:user],
            opts[:key]
          )

        changeset
        |> put_change(:mute_keywords, encrypted_keywords)
        |> put_change(:mute_keywords_hash, String.downcase(mute_keywords))
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
