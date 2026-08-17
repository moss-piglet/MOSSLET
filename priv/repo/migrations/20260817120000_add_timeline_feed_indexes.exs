defmodule Mosslet.Repo.Migrations.AddTimelineFeedIndexes do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  # The timeline feed (Mosslet.Timeline.fetch_timeline_posts_from_db/2) is the
  # hottest query in the app. It filters user_posts by user_id and joins posts
  # via post_id, but the only existing index leads with post_id
  # (unique(post_id, user_id)) and cannot serve the user_id filter. The
  # composite below covers the filter and yields the join key from the index.
  #
  # The same query left-joins user_post_receipts on user_post_id, which no
  # existing index leads with (the unique index leads with user_id).
  #
  # The standalone is_read?/read_at indexes are dropped: both are only ever
  # filtered through user_id/user_post_id joins, never as leading columns, and
  # is_read? is a low-cardinality boolean — pure write overhead.
  def change do
    create_if_not_exists index(:user_posts, [:user_id, :post_id], concurrently: true)
    create_if_not_exists index(:user_post_receipts, [:user_post_id], concurrently: true)

    drop_if_exists index(:user_post_receipts, [:is_read?], concurrently: true)
    drop_if_exists index(:user_post_receipts, [:read_at], concurrently: true)
  end
end
