defmodule Mosslet.Files do
  @moduledoc """
  Org-scoped zero-knowledge file sharing (Task #221, see
  `docs/ZK_FILE_SHARING_DESIGN.md`).

  A business-circle member uploads a file that is **encrypted in the browser**
  with a per-file `file_key` (NaCl secretbox). The opaque blob is stored on
  object storage (Tigris); the `file_key` is sealed per recipient via
  `sealForUser` (Cat-5 hybrid) — exactly like `UserPost.key`/`UserGroup.key`.
  The server stores only ciphertext + sealed key copies and never sees the
  `file_key` or the plaintext (invariants I2/I3).

  The recipient set is **server-authoritative** (I1): it is the circle's
  confirmed `UserGroup` members. The browser seals only for the public keys the
  server returns; `finalize_shared_file_zk/2` drops any sealed entry for a
  `user_id` that isn't a current circle member, so a tampered client can never
  seal a file for an outsider.
  """

  import Ecto.Query

  alias Mosslet.Accounts.User
  alias Mosslet.Files.SharedFile
  alias Mosslet.Files.UserSharedFile
  alias Mosslet.FileUploads.SharedFileStorage
  alias Mosslet.Groups
  alias Mosslet.Groups.Group
  alias Mosslet.Groups.UserGroup
  alias Mosslet.Repo

  # 50 MB per file (Q1). Enforced again server-side as defense in depth; the
  # browser also checks before encrypting.
  @max_size_bytes 50 * 1024 * 1024

  def max_size_bytes, do: @max_size_bytes

  ## Realtime (Task #231): shared-file changes propagate to every open circle
  ## Files panel + the org-dash "Files across your circles" overview, with no
  ## reload. We reuse the existing per-group topic (`group:#{group_id}`, which
  ## CircleShow already subscribes to via `Groups.group_subscribe/1`) AND an
  ## org-scoped topic so the org dashboard can refresh its overview. The events
  ## carry only ids — no ciphertext, no keys (ZK-safe).

  @doc """
  Subscribe the caller to shared-file events for an org (the org-dash overview).
  Handle `{:shared_files_updated, org_id}` in `handle_info/2`.
  """
  def subscribe_org_files(org_id) when is_binary(org_id) do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, org_files_topic(org_id))
  end

  defp org_files_topic(org_id), do: "org_files:#{org_id}"

  # Broadcasts a shared-file change to (a) the circle's group topic — picked up
  # by every open Files panel for that circle — and (b) the org-files topic —
  # picked up by the org dashboard overview. Ids only (ZK-safe).
  defp broadcast_file_change(%SharedFile{} = shared_file) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "group:#{shared_file.group_id}",
      {:shared_files_updated, shared_file.group_id}
    )

    if shared_file.org_id do
      Phoenix.PubSub.broadcast(
        Mosslet.PubSub,
        org_files_topic(shared_file.org_id),
        {:shared_files_updated, shared_file.org_id}
      )
    end

    :ok
  end

  @doc """
  Server-authoritative recipient set for a circle (I1): the circle's confirmed
  members, as a list of `%{user_id, public_key, pq_public_key}` for the browser
  to seal the `file_key` against. Used by the upload (phase 1) flow.
  """
  def circle_recipients(%Group{} = group) do
    member_user_ids = confirmed_member_user_ids(group)

    member_user_ids
    |> users_by_ids()
    |> Enum.map(fn user ->
      %{
        user_id: user.id,
        public_key: user.key_pair["public"],
        pq_public_key: user.pq_public_key
      }
    end)
  end

  @doc """
  Phase 1 (write path): inserts the `SharedFile` metadata for an opaque blob the
  browser already encrypted + uploaded. `group_id`/`org_id`/`uploader_id` are
  stamped server-side. Returns `{:ok, shared_file}` (the caller then asks the
  browser to seal the `file_key` for `circle_recipients/1`).

  Eligibility: `uploader` must be a confirmed member of the (business) circle.
  """
  def create_shared_file_zk(%Group{} = group, %User{} = uploader, attrs) do
    attrs = normalize_keys(attrs)

    cond do
      is_nil(group.org_id) ->
        {:error, :not_an_org_circle}

      not member_of_circle?(group, uploader.id) ->
        {:error, :not_a_circle_member}

      oversized?(attrs) ->
        {:error, :too_large}

      true ->
        changeset = SharedFile.insert_changeset(group, uploader, attrs)

        case Repo.transaction_on_primary(fn -> Repo.insert(changeset) end) do
          {:ok, {:ok, shared_file}} -> {:ok, shared_file}
          {:ok, {:error, changeset}} -> {:error, changeset}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  Phase 2 (write path): persists one `UserSharedFile` per **eligible** recipient.

  `sealed_recipients` is a list of maps (string keys) with `user_id` +
  `sealed_key` produced in the browser. Any entry whose `user_id` is not a
  current confirmed member of the file's circle is dropped (I1). Returns
  `{:ok, count_inserted}`.
  """
  def finalize_shared_file_zk(%SharedFile{} = shared_file, sealed_recipients)
      when is_list(sealed_recipients) do
    group = Groups.get_group!(shared_file.group_id)
    eligible_ids = confirmed_member_user_ids(group)

    inserted =
      sealed_recipients
      |> Enum.map(&normalize_keys/1)
      |> Enum.filter(fn entry ->
        is_binary(entry["sealed_key"]) and entry["user_id"] in eligible_ids
      end)
      |> Enum.reduce(0, fn entry, acc ->
        changeset =
          UserSharedFile.insert_changeset(shared_file, entry["user_id"], entry["sealed_key"])

        case Repo.transaction_on_primary(fn -> Repo.insert(changeset) end) do
          {:ok, {:ok, _}} -> acc + 1
          _ -> acc
        end
      end)

    if inserted > 0, do: broadcast_file_change(shared_file)

    {:ok, inserted}
  end

  ## Catch-up: grant new members access to EARLIER files (explicit, never silent
  ## — Task #231, see docs/ZK_FILE_SHARING_DESIGN.md §6.2). When someone joins a
  ## circle after a file was shared, they hold no sealed `file_key` for it. A
  ## current reader (the uploader, a circle admin/owner, or an org admin) can
  ## explicitly "catch everyone up": their browser unseals each file_key it can
  ## read and RE-SEALS it for the members who lack access. The server never sees
  ## a raw file_key (I2/I3); the recipient set stays server-authoritative (I1);
  ## the action is explicit + surfaced, never automatic.

  @doc """
  How many current confirmed circle members are missing access to at least one
  shared file in `group`. Drives the "catch up" affordance + tooltip. `0` means
  everyone can already read every file (affordance hidden).
  """
  def members_missing_file_access_count(%Group{} = group) do
    group
    |> members_missing_file_access()
    |> length()
  end

  @doc """
  The set of current confirmed circle members (`user_id`s) who lack a sealed
  `file_key` for one or more of the circle's shared files.
  """
  def members_missing_file_access(%Group{} = group) do
    member_ids = confirmed_member_user_ids(group)

    file_ids =
      SharedFile
      |> where([sf], sf.group_id == ^group.id)
      |> select([sf], sf.id)
      |> Repo.all()

    if file_ids == [] or member_ids == [] do
      []
    else
      total_files = length(file_ids)

      # For each member, how many of the circle's files they can already read.
      reader_counts =
        UserSharedFile
        |> where([usf], usf.shared_file_id in ^file_ids and usf.user_id in ^member_ids)
        |> group_by([usf], usf.user_id)
        |> select([usf], {usf.user_id, count(usf.id)})
        |> Repo.all()
        |> Map.new()

      Enum.filter(member_ids, fn uid ->
        Map.get(reader_counts, uid, 0) < total_files
      end)
    end
  end

  @doc """
  Builds the client-side re-seal payload for `actor` to catch everyone up on
  earlier files in `group`. For every file `actor` can read, returns the actor's
  OWN sealed `file_key` (so the browser can unseal it) plus the public keys of
  the current confirmed members who still lack access:

      [%{shared_file_id, sealed_key, missing: [%{user_id, public_key, pq_public_key}]}]

  Files where nobody is missing are dropped. The raw `file_key` never appears
  here — only the actor's already-sealed copy, which only the actor can unseal.
  Recipient set is server-authoritative (I1): only current circle members.
  """
  def catch_up_payload(%Group{} = group, %User{} = actor) do
    member_ids = confirmed_member_user_ids(group)

    # The files the actor can read (holds a sealed key for), with all current
    # reader rows preloaded so we can compute who's missing per file.
    actor_files =
      SharedFile
      |> join(:inner, [sf], usf in UserSharedFile,
        on: usf.shared_file_id == sf.id and usf.user_id == ^actor.id
      )
      |> where([sf, usf], sf.group_id == ^group.id)
      |> select([sf, usf], {sf, usf.key})
      |> Repo.all()

    file_ids = Enum.map(actor_files, fn {sf, _} -> sf.id end)

    readers_by_file =
      if file_ids == [] do
        %{}
      else
        UserSharedFile
        |> where([usf], usf.shared_file_id in ^file_ids)
        |> select([usf], {usf.shared_file_id, usf.user_id})
        |> Repo.all()
        |> Enum.group_by(fn {fid, _} -> fid end, fn {_, uid} -> uid end)
      end

    member_users =
      member_ids
      |> users_by_ids()
      |> Map.new(fn u -> {u.id, u} end)

    actor_files
    |> Enum.map(fn {sf, actor_sealed_key} ->
      existing_readers = MapSet.new(Map.get(readers_by_file, sf.id, []))

      missing =
        member_ids
        |> Enum.reject(&MapSet.member?(existing_readers, &1))
        |> Enum.map(&Map.get(member_users, &1))
        |> Enum.reject(&is_nil/1)
        |> Enum.map(fn user ->
          %{
            user_id: user.id,
            public_key: user.key_pair["public"],
            pq_public_key: user.pq_public_key
          }
        end)
        |> Enum.reject(&is_nil(&1.public_key))

      %{shared_file_id: sf.id, sealed_key: actor_sealed_key, missing: missing}
    end)
    |> Enum.reject(fn entry -> entry.missing == [] end)
  end

  @doc """
  Persists catch-up re-sealed `file_key`s. `sealed_entries` is a list of maps
  (string keys) with `shared_file_id`, `user_id`, `sealed_key`, each produced in
  the browser by re-sealing a file_key the actor could read. Server-authoritative
  (I1): an entry is inserted only when its `user_id` is a current confirmed
  member of THAT file's circle and doesn't already hold a row. Returns
  `{:ok, count_inserted}`.
  """
  def finalize_catch_up_zk(%Group{} = group, sealed_entries) when is_list(sealed_entries) do
    eligible_ids = MapSet.new(confirmed_member_user_ids(group))

    group_file_ids =
      SharedFile
      |> where([sf], sf.group_id == ^group.id)
      |> select([sf], sf.id)
      |> Repo.all()
      |> MapSet.new()

    existing_pairs =
      UserSharedFile
      |> where([usf], usf.shared_file_id in ^MapSet.to_list(group_file_ids))
      |> select([usf], {usf.shared_file_id, usf.user_id})
      |> Repo.all()
      |> MapSet.new()

    inserted =
      sealed_entries
      |> Enum.map(&normalize_keys/1)
      |> Enum.filter(fn e ->
        is_binary(e["sealed_key"]) and
          MapSet.member?(eligible_ids, e["user_id"]) and
          MapSet.member?(group_file_ids, e["shared_file_id"]) and
          not MapSet.member?(existing_pairs, {e["shared_file_id"], e["user_id"]})
      end)
      |> Enum.reduce(0, fn e, acc ->
        shared_file = %SharedFile{id: e["shared_file_id"]}

        changeset =
          UserSharedFile.insert_changeset(shared_file, e["user_id"], e["sealed_key"])

        case Repo.transaction_on_primary(fn -> Repo.insert(changeset) end) do
          {:ok, {:ok, _}} -> acc + 1
          _ -> acc
        end
      end)

    if inserted > 0 do
      Phoenix.PubSub.broadcast(
        Mosslet.PubSub,
        "group:#{group.id}",
        {:shared_files_updated, group.id}
      )

      if group.org_id do
        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          org_files_topic(group.org_id),
          {:shared_files_updated, group.org_id}
        )
      end
    end

    {:ok, inserted}
  end

  @doc """
  Lists the shared files in `group` that `user` can read (they hold a sealed
  `file_key`). Always circle-scoped. Preloads the recipient rows + uploader for
  the transparency surface. Newest first.
  """
  def list_shared_files_for_group(%Group{} = group, %User{} = user) do
    SharedFile
    |> join(:inner, [sf], usf in UserSharedFile, on: usf.shared_file_id == sf.id)
    |> where([sf, usf], sf.group_id == ^group.id)
    |> where([sf, usf], usf.user_id == ^user.id)
    |> order_by([sf], desc: sf.inserted_at)
    |> preload([:user_shared_files, :uploader])
    |> Repo.all()
  end

  @doc """
  Lists ALL shared files across the given org's circles that `user` can read,
  with each file's `group` preloaded so the org-dash overview can show which
  circle a file lives in (Task #221 + #229). Org- and reader-scoped.
  """
  def list_org_shared_files_for_user(org_id, %User{} = user) when is_binary(org_id) do
    viewer_rows = from(usf in UserSharedFile, where: usf.user_id == ^user.id)

    SharedFile
    |> join(:inner, [sf], usf in UserSharedFile, on: usf.shared_file_id == sf.id)
    |> where([sf, usf], sf.org_id == ^org_id)
    |> where([sf, usf], usf.user_id == ^user.id)
    |> order_by([sf], desc: sf.inserted_at)
    |> preload([:group, :uploader, user_shared_files: ^viewer_rows])
    |> Repo.all()
  end

  @doc "Gets a shared file by id (no auth — callers must authorize)."
  def get_shared_file(id), do: Repo.get(SharedFile, id)
  def get_shared_file!(id), do: Repo.get!(SharedFile, id)

  @doc """
  Returns the requester's own sealed `file_key` row for `shared_file`, or `nil`
  if they aren't a reader. Used by the read path to (a) authorize issuing a
  presigned URL and (b) hand the browser the sealed key to unseal locally.
  """
  def get_user_shared_file(%SharedFile{} = shared_file, %User{} = user) do
    Repo.get_by(UserSharedFile, shared_file_id: shared_file.id, user_id: user.id)
  end

  @doc """
  Authorizes + issues a short-lived presigned GET URL for the opaque blob, only
  if `user` holds a sealed `file_key` for the file (membership gate; defense in
  depth — the blob is opaque regardless). Returns `{:ok, url}` or
  `{:error, :unauthorized | reason}`.
  """
  def presigned_download_url(%SharedFile{} = shared_file, %User{} = user) do
    if get_user_shared_file(shared_file, user) do
      SharedFileStorage.presigned_url(shared_file.storage_path)
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Lists the users who currently hold a sealed `file_key` for `shared_file` (the
  mandatory transparency surface — I4). Returns the `User` structs.
  """
  def list_readers(%SharedFile{} = shared_file) do
    UserSharedFile
    |> where([usf], usf.shared_file_id == ^shared_file.id)
    |> join(:inner, [usf], u in User, on: u.id == usf.user_id)
    |> select([usf, u], u)
    |> Repo.all()
  end

  @doc """
  Revocation (I5): deletes the opaque blob + all `UserSharedFile` rows + the
  `SharedFile` record. No future access; we never claim to recall copies already
  downloaded. Authorized to the uploader or a circle admin/owner.
  """
  def delete_shared_file(%SharedFile{} = shared_file, %User{} = actor) do
    if can_delete?(shared_file, actor) do
      storage_path = shared_file.storage_path

      result =
        Repo.transaction_on_primary(fn ->
          Repo.delete_all(
            from(usf in UserSharedFile, where: usf.shared_file_id == ^shared_file.id)
          )

          Repo.delete(shared_file)
        end)

      case result do
        {:ok, {:ok, _}} ->
          # Best-effort async blob delete (the DB record is already gone, so
          # access is revoked regardless of object-store latency).
          SharedFileStorage.delete_blob(storage_path)
          broadcast_file_change(shared_file)
          {:ok, :revoked}

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
  Departed-member revocation (Q6 / I5): explicitly removes a (former) member's
  sealed `file_key` rows for every shared file in `group`, preventing FUTURE
  fetches by them. Never silent; honest copy ("can't recall downloads") lives in
  the UI. Returns `{:ok, count_removed}`.
  """
  def revoke_member_file_access(%Group{} = group, member_user_id)
      when is_binary(member_user_id) do
    file_ids =
      SharedFile
      |> where([sf], sf.group_id == ^group.id)
      |> select([sf], sf.id)
      |> Repo.all()

    result =
      Repo.transaction_on_primary(fn ->
        Repo.delete_all(
          from(usf in UserSharedFile,
            where: usf.shared_file_id in ^file_ids and usf.user_id == ^member_user_id
          )
        )
      end)

    case result do
      {:ok, {count, _}} when is_integer(count) -> {:ok, count}
      {:ok, _} -> {:ok, 0}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Tears down ALL shared files for a circle (I5) — used when the whole circle is
  deleted. Deletes every opaque blob from object storage AND removes the
  `SharedFile` + `UserSharedFile` rows.

  Call this BEFORE deleting the `Group` itself: the `shared_files.group_id` FK
  cascades the DB rows on group delete, but the cloud blobs would otherwise be
  orphaned forever. Returns `{:ok, count_deleted}`.
  """
  def delete_all_for_group(%Group{} = group), do: delete_all_for_group(group.id)

  def delete_all_for_group(group_id) when is_binary(group_id) do
    delete_files_where(dynamic([sf], sf.group_id == ^group_id))
  end

  @doc """
  Tears down ALL shared files across an entire org's circles (I5) — used when
  the org itself is deleted (board #227). Deletes every opaque blob from object
  storage AND removes the DB rows. Returns `{:ok, count_deleted}`.
  """
  def delete_all_for_org(org_id) when is_binary(org_id) do
    delete_files_where(dynamic([sf], sf.org_id == ^org_id))
  end

  # Shared teardown: collect storage paths, best-effort delete each blob, then
  # remove the DB rows in a single transaction. Blob deletion is async + best
  # effort — the DB removal is authoritative for access, and orphaned-blob
  # cleanup never blocks the delete.
  defp delete_files_where(condition) do
    files =
      SharedFile
      |> where(^condition)
      |> select([sf], %{id: sf.id, storage_path: sf.storage_path})
      |> Repo.all()

    file_ids = Enum.map(files, & &1.id)

    if file_ids == [] do
      {:ok, 0}
    else
      result =
        Repo.transaction_on_primary(fn ->
          Repo.delete_all(from(usf in UserSharedFile, where: usf.shared_file_id in ^file_ids))
          Repo.delete_all(from(sf in SharedFile, where: sf.id in ^file_ids))
        end)

      case result do
        {:ok, _} ->
          Enum.each(files, fn %{storage_path: path} ->
            SharedFileStorage.delete_blob(path)
          end)

          {:ok, length(file_ids)}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  ## Internals

  defp confirmed_member_user_ids(%Group{} = group) do
    UserGroup
    |> where([ug], ug.group_id == ^group.id)
    |> where([ug], not is_nil(ug.confirmed_at))
    |> select([ug], ug.user_id)
    |> Repo.all()
  end

  defp member_of_circle?(%Group{} = group, user_id) do
    user_id in confirmed_member_user_ids(group)
  end

  defp can_delete?(%SharedFile{} = shared_file, %User{} = actor) do
    cond do
      shared_file.uploader_id == actor.id ->
        true

      true ->
        group = Groups.get_group!(shared_file.group_id)
        admin_or_owner_of_circle?(group, actor.id)
    end
  end

  defp admin_or_owner_of_circle?(%Group{} = group, user_id) do
    UserGroup
    |> where([ug], ug.group_id == ^group.id and ug.user_id == ^user_id)
    |> where([ug], ug.role in [:owner, :admin, :moderator])
    |> Repo.exists?()
  end

  defp users_by_ids([]), do: []

  defp users_by_ids(ids) do
    User
    |> where([u], u.id in ^ids)
    |> Repo.all()
  end

  defp oversized?(attrs) do
    size = attrs["size_bytes"]
    is_integer(size) and size > @max_size_bytes
  end

  defp normalize_keys(entry) do
    Map.new(entry, fn {k, v} -> {to_string(k), v} end)
  end
end
