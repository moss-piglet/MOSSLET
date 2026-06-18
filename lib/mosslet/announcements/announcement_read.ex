defmodule Mosslet.Announcements.AnnouncementRead do
  @moduledoc """
  A ZK-safe read receipt (Task #229c): records only that `user_id` has seen
  `announcement_id`, and when. There is NO plaintext and NO key material here —
  it carries only ids + timestamps, so it's safe to store and query directly.

  Drives the per-tier unread badge + the realtime "new announcement" toast. One
  row per (announcement, user); marking is idempotent via upsert (see
  `Mosslet.Announcements.mark_read/2`).

  `announcement_id`/`user_id` are stamped programmatically by the context, never
  cast from user params.
  """
  use Mosslet.Schema

  alias Mosslet.Accounts.User
  alias Mosslet.Announcements.Announcement

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "announcement_reads" do
    belongs_to :announcement, Announcement
    belongs_to :user, User

    timestamps()
  end

  @doc """
  Insert changeset for a read receipt. Both ids are stamped server-side.
  """
  def insert_changeset(%Announcement{} = announcement, %User{} = user) do
    %__MODULE__{}
    |> change()
    |> put_change(:announcement_id, announcement.id)
    |> put_change(:user_id, user.id)
    |> foreign_key_constraint(:announcement_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:announcement_id, :user_id])
  end
end
