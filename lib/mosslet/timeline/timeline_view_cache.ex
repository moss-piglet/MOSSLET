defmodule Mosslet.Timeline.TimelineViewCache do
  @moduledoc """
  Cache table for timeline view performance.

  Stores cached post counts and metadata for different timeline tabs.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "timeline_view_cache" do
    # "home", "connections", etc.
    field :tab_name, :string
    # Cached post count for tab
    field :post_count, :integer, default: 0
    # When newest post was created
    field :last_post_at, :naive_datetime
    # When cache should be refreshed
    field :cache_expires_at, :naive_datetime
    # JSON cache of post IDs/metadata
    field :cache_data, :string

    belongs_to :user, User

    timestamps()
  end

  @doc false
  def changeset(cache, attrs, _opts \\ []) do
    cache
    |> cast(attrs, [
      :user_id,
      :tab_name,
      :post_count,
      :last_post_at,
      :cache_expires_at,
      :cache_data
    ])
    |> validate_required([:user_id, :tab_name])
    |> validate_inclusion(:tab_name, ["home", "connections", "groups", "bookmarks", "discover"])
    |> validate_number(:post_count, greater_than_or_equal_to: 0)
    |> unique_constraint([:user_id, :tab_name])
  end
end
