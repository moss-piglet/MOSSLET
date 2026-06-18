defmodule Mosslet.Announcements do
  @moduledoc """
  Two-tier zero-knowledge announcements (Task #229c, EPIC #207).

  An announcement is a notice posted into EITHER an org-wide dashboard
  (`org_id`) OR a single business circle (`group_id`) — never both. The title +
  body are **encrypted in the browser** with the tier's shared key (the per-org
  `org_key` for the org tier, the circle's `group_key` for the circle tier) and
  additionally Cloak-wrapped server-side. The server never sees the plaintext or
  the key (invariants I2/I3) — the same pattern as `Mosslet.Files`.

  Authority is **server-authoritative** (I1):

    * Org tier — only the org OWNER or an org ADMIN may author org-wide
      announcements.
    * Circle tier — only that circle's `UserGroup` OWNER / ADMIN / MODERATOR (the
      "team lead", per the locked #229 architecture decision — there is no
      separate org `:team_lead` role) may author circle announcements.

  Realtime reuses the existing per-tier topics with id-only events (no plaintext,
  no keys): the org topic (`org:<org_id>`, which dashboards already subscribe to
  via `Orgs.subscribe_org/1`) and the circle/group topic (`group:<group_id>`,
  subscribed via `Groups.group_subscribe/1`). Modeled on `Mosslet.Files`'
  `broadcast_file_change/1`.
  """

  import Ecto.Query

  alias Mosslet.Accounts.User
  alias Mosslet.Announcements.Announcement
  alias Mosslet.Announcements.AnnouncementRead
  alias Mosslet.Groups
  alias Mosslet.Groups.Group
  alias Mosslet.Groups.UserGroup
  alias Mosslet.Orgs
  alias Mosslet.Orgs.Membership
  alias Mosslet.Orgs.Org
  alias Mosslet.Repo

  @circle_author_roles [:owner, :admin, :moderator]

  ## Authority (server-authoritative — I1)

  @doc """
  Whether `user_id` may author an ORG-wide announcement: the org OWNER or an org
  ADMIN. Re-checked on every write.
  """
  def can_post_org_announcement?(%Org{} = org, user_id) when is_binary(user_id) do
    Orgs.owner?(org, user_id) or org_admin?(org, user_id)
  end

  def can_post_org_announcement?(_, _), do: false

  @doc """
  Whether `user_id` may author a CIRCLE announcement: the circle's own
  `UserGroup` role is owner / admin / moderator ("team lead"). Re-checked on
  every write. The group must be an org (business) circle.
  """
  def can_post_circle_announcement?(%Group{} = group, user_id) when is_binary(user_id) do
    not is_nil(group.org_id) and circle_author?(group, user_id)
  end

  def can_post_circle_announcement?(_, _), do: false

  defp org_admin?(%Org{} = org, user_id) do
    Membership
    |> where([m], m.org_id == ^org.id and m.user_id == ^user_id and m.role == :admin)
    |> Repo.exists?()
  end

  defp circle_author?(%Group{} = group, user_id) do
    UserGroup
    |> where([ug], ug.group_id == ^group.id and ug.user_id == ^user_id)
    |> where([ug], ug.role in ^@circle_author_roles)
    |> Repo.exists?()
  end

  ## Realtime (id-only events — ZK-safe)

  defp org_topic(org_id), do: "org:#{org_id}"
  defp group_topic(group_id), do: "group:#{group_id}"

  # A new announcement was published. Carries only ids (scope + author) so a
  # subscriber can refresh + decide whether to toast (the author already saw it).
  defp broadcast_published(%Announcement{org_id: org_id, author_id: author_id})
       when is_binary(org_id) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      org_topic(org_id),
      {:announcement_published, %{scope: :org, scope_id: org_id, author_id: author_id}}
    )
  end

  defp broadcast_published(%Announcement{group_id: group_id, author_id: author_id})
       when is_binary(group_id) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      group_topic(group_id),
      {:announcement_published, %{scope: :circle, scope_id: group_id, author_id: author_id}}
    )
  end

  # An announcement changed (edit/delete) — refresh only, no toast. Ids only.
  defp broadcast_updated(%Announcement{org_id: org_id}) when is_binary(org_id) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      org_topic(org_id),
      {:announcements_updated, %{scope: :org, scope_id: org_id}}
    )
  end

  defp broadcast_updated(%Announcement{group_id: group_id}) when is_binary(group_id) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      group_topic(group_id),
      {:announcements_updated, %{scope: :circle, scope_id: group_id}}
    )
  end

  ## Write path (ZK)

  @doc """
  Publishes an ORG-wide announcement. `attrs` carries the browser-encrypted
  `encrypted_title` (optional) + `encrypted_body` plus the plaintext surface
  metadata (`priority`, `expires_at`). `org_id` + `author_id` are stamped
  server-side. Authority (owner/admin) is re-checked here (I1). Broadcasts a
  publish event. Returns `{:ok, announcement}` or `{:error, reason}`.
  """
  def create_org_announcement(%Org{} = org, %User{} = author, attrs) do
    attrs = normalize_keys(attrs)

    if can_post_org_announcement?(org, author.id) do
      changeset = Announcement.org_insert_changeset(org, author, attrs)
      insert_and_broadcast(changeset)
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Publishes a CIRCLE announcement. `group` must be an org (business) circle and
  `author` must hold a managing per-circle role (owner/admin/moderator). The
  `group_id` + `author_id` are stamped server-side; authority is re-checked here
  (I1). Returns `{:ok, announcement}` or `{:error, reason}`.
  """
  def create_circle_announcement(%Group{} = group, %User{} = author, attrs) do
    attrs = normalize_keys(attrs)

    cond do
      is_nil(group.org_id) ->
        {:error, :not_an_org_circle}

      not can_post_circle_announcement?(group, author.id) ->
        {:error, :unauthorized}

      true ->
        changeset = Announcement.circle_insert_changeset(group, author, attrs)
        insert_and_broadcast(changeset)
    end
  end

  defp insert_and_broadcast(changeset) do
    case Repo.transaction_on_primary(fn -> Repo.insert(changeset) end) do
      {:ok, {:ok, announcement}} ->
        broadcast_published(announcement)
        {:ok, announcement}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Edits an announcement's encrypted content / surface metadata. Authorized to the
  author OR a current manager of the announcement's tier (org owner/admin, or the
  circle's owner/admin/moderator) — so a team lead can curate, and authorship
  survives staffing changes. Returns `{:ok, announcement}` or `{:error, reason}`.
  """
  def update_announcement(%Announcement{} = announcement, %User{} = actor, attrs) do
    attrs = normalize_keys(attrs)

    if can_manage?(announcement, actor) do
      changeset = Announcement.update_changeset(announcement, attrs)

      case Repo.transaction_on_primary(fn -> Repo.update(changeset) end) do
        {:ok, {:ok, updated}} ->
          broadcast_updated(updated)
          {:ok, updated}

        {:ok, {:error, changeset}} ->
          {:error, changeset}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Deletes an announcement (and its read receipts via FK cascade). Authorized to
  the author OR a current manager of the tier. Returns `{:ok, :deleted}` or
  `{:error, reason}`.
  """
  def delete_announcement(%Announcement{} = announcement, %User{} = actor) do
    if can_manage?(announcement, actor) do
      case Repo.transaction_on_primary(fn -> Repo.delete(announcement) end) do
        {:ok, {:ok, _}} ->
          broadcast_updated(announcement)
          {:ok, :deleted}

        {:ok, {:error, reason}} ->
          {:error, reason}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Whether `actor` may edit/delete `announcement`: the author, or a current
  manager of its tier (org owner/admin for the org tier; circle owner/admin/
  moderator for the circle tier).
  """
  def can_manage?(%Announcement{} = announcement, %User{} = actor) do
    cond do
      announcement.author_id == actor.id ->
        true

      is_binary(announcement.org_id) ->
        org = Orgs.get_org_by_id(announcement.org_id)
        not is_nil(org) and can_post_org_announcement?(org, actor.id)

      is_binary(announcement.group_id) ->
        group = Groups.get_group(announcement.group_id)
        not is_nil(group) and can_post_circle_announcement?(group, actor.id)

      true ->
        false
    end
  end

  ## Read path

  @doc "Gets an announcement by id (no auth — callers must authorize)."
  def get_announcement(id), do: Repo.get(Announcement, id)
  def get_announcement!(id), do: Repo.get!(Announcement, id)

  @doc """
  Lists the live ORG-wide announcements (not expired), pinned first then newest.
  Org-scoped.
  """
  def list_org_announcements(%Org{} = org) do
    Announcement
    |> where([a], a.org_id == ^org.id)
    |> live_announcements()
    |> Repo.all()
  end

  @doc """
  Lists the live CIRCLE announcements (not expired), pinned first then newest.
  Group-scoped.
  """
  def list_circle_announcements(%Group{} = group) do
    Announcement
    |> where([a], a.group_id == ^group.id)
    |> live_announcements()
    |> Repo.all()
  end

  # Shared ordering/expiry filter. Drops announcements whose `expires_at` is in
  # the past; orders pinned first, then newest.
  defp live_announcements(query) do
    now = DateTime.utc_now()

    query
    |> where([a], is_nil(a.expires_at) or a.expires_at > ^now)
    |> order_by([a], desc: a.priority == :pinned, desc: a.inserted_at)
  end

  @doc """
  Splits a list of announcements into `{pinned, recent}`: the single most-recent
  pinned announcement (rendered as a highlighted banner) and everything else (the
  "Recent" list). When nothing is pinned, `pinned` is `nil`.
  """
  def partition_pinned(announcements) when is_list(announcements) do
    case Enum.split_with(announcements, &(&1.priority == :pinned)) do
      {[], recent} -> {nil, recent}
      {[banner | rest_pinned], recent} -> {banner, rest_pinned ++ recent}
    end
  end

  ## Read receipts (ZK-safe — ids + timestamps only)

  @doc """
  Idempotently marks `announcement` as read by `user` (upsert; one row per
  pair). Returns `:ok`.
  """
  def mark_read(%Announcement{} = announcement, %User{} = user) do
    changeset = AnnouncementRead.insert_changeset(announcement, user)

    Repo.transaction_on_primary(fn ->
      Repo.insert(changeset,
        on_conflict: :nothing,
        conflict_target: [:announcement_id, :user_id]
      )
    end)

    :ok
  end

  @doc """
  Marks every currently-live announcement in the given tier as read by `user`.
  Returns `:ok`. Used when a member opens the tier so the unread badge clears.
  """
  def mark_all_read_org(%Org{} = org, %User{} = user) do
    org |> list_org_announcements() |> mark_each_read(user)
  end

  def mark_all_read_circle(%Group{} = group, %User{} = user) do
    group |> list_circle_announcements() |> mark_each_read(user)
  end

  defp mark_each_read(announcements, user) do
    Enum.each(announcements, &mark_read(&1, user))
    :ok
  end

  @doc """
  How many live ORG-wide announcements `user` hasn't read yet. Drives the unread
  badge.
  """
  def unread_org_count(%Org{} = org, %User{} = user) do
    org
    |> list_org_announcements()
    |> unread_count(user)
  end

  @doc "How many live CIRCLE announcements `user` hasn't read yet."
  def unread_circle_count(%Group{} = group, %User{} = user) do
    group
    |> list_circle_announcements()
    |> unread_count(user)
  end

  defp unread_count(announcements, %User{} = user) do
    ids = Enum.map(announcements, & &1.id)

    if ids == [] do
      0
    else
      read_ids =
        AnnouncementRead
        |> where([r], r.user_id == ^user.id and r.announcement_id in ^ids)
        |> select([r], r.announcement_id)
        |> Repo.all()
        |> MapSet.new()

      Enum.count(ids, &(not MapSet.member?(read_ids, &1)))
    end
  end

  ## Param parsing (surface metadata from the compose form)

  @doc """
  Maps the client priority hint to a known atom (never `String.to_atom/1` on user
  input). Unknown values fall back to `:normal`.
  """
  def parse_priority("pinned"), do: :pinned
  def parse_priority(:pinned), do: :pinned
  def parse_priority(_), do: :normal

  @doc """
  Parses the optional `datetime-local` auto-hide value into a UTC `DateTime` (or
  `nil` when absent/unparseable). The HTML control yields a timezone-less,
  second-less string (e.g. `"2026-06-18T15:30"`); we normalize + treat it as UTC.
  """
  def parse_expires_at(value) when is_binary(value) do
    case String.trim(value) do
      "" ->
        nil

      trimmed ->
        normalized = if String.length(trimmed) == 16, do: trimmed <> ":00", else: trimmed

        case NaiveDateTime.from_iso8601(normalized) do
          {:ok, naive} -> naive |> DateTime.from_naive!("Etc/UTC") |> DateTime.truncate(:second)
          _ -> nil
        end
    end
  end

  def parse_expires_at(_), do: nil

  defp normalize_keys(entry) do
    Map.new(entry, fn {k, v} -> {to_string(k), v} end)
  end
end
