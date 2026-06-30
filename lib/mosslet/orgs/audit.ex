defmodule Mosslet.Orgs.Audit do
  @moduledoc """
  Zero-knowledge admin audit log for BUSINESS orgs (Task #212 / EPIC #207, §12 of
  `docs/BUSINESS_CIRCLES_DESIGN.md`).

  **Option B — metadata-only, server-authoritative, APPEND-ONLY.** A read-only
  activity feed of business-org admin actions (member added/removed, role change,
  display-name change, circle created, file shared/revoked). Each event stores ONLY opaque ids + a
  non-sensitive `action` category + timestamp; the human-readable description
  ("Jane changed Bob's role") is reconstructed CLIENT-SIDE by an org admin from
  data they already decrypt (member `display_name`s, circle names). The server
  never sees, and cannot read, the human meaning.

  Why this is still zero-knowledge:

    * No readable CONTENT at rest — only UUIDs + a system category. Those
      structural ids are already plaintext throughout the schema
      (`orgs_memberships`, `groups`, `user_groups`, `user_shared_files`), so this
      leaks nothing the server doesn't already hold.
    * Cloak-encrypting opaque UUIDs would buy zero confidentiality and break the
      FK cascade + queryability, so the rows are plain (see `AuditEvent`).

  Tamper-resistance:

    * **Server-authoritative** — the actor is the authenticated caller, never a
      client-supplied id, so a rogue admin can't forge or misattribute an entry.
    * **Append-only** — this module exposes only insert + read. There is no
      update or delete API. The only way audit rows disappear is the `org_id`
      cascade (`on_delete: :delete_all`) when the whole org is deleted — so a
      deleted org leaves no orphaned logs (and the owner can download a final
      copy client-side first; see the dashboard delete flow).

  Recording is **best-effort / non-blocking**: a failure to write an audit row
  must never roll back or break the underlying action it describes.

  Realtime: an id-only `{:audit_recorded, %{org_id: org_id}}` event on the org
  topic (`org:<org_id>`, which the business dashboard already subscribes to via
  `Orgs.subscribe_org/1`) lets connected admins refresh the feed live.
  """

  import Ecto.Query
  require Logger

  alias Mosslet.Accounts.User
  alias Mosslet.Orgs
  alias Mosslet.Orgs.AuditEvent
  alias Mosslet.Orgs.Membership
  alias Mosslet.Orgs.Org
  alias Mosslet.Repo

  @default_limit 200

  ## Authority (server-authoritative)

  @doc """
  Whether `user_id` may VIEW the org's audit log: the org OWNER or an org ADMIN.
  Non-admins never see the panel and `list_audit_events/2` is gated on this in the
  LiveView. Re-checked on every render.
  """
  def can_view_audit_log?(%Org{} = org, user_id) when is_binary(user_id) do
    Orgs.owner?(org, user_id) or org_admin?(org, user_id)
  end

  def can_view_audit_log?(_, _), do: false

  defp org_admin?(%Org{} = org, user_id) do
    Membership
    |> where([m], m.org_id == ^org.id and m.user_id == ^user_id and m.role == :admin)
    |> Repo.exists?()
  end

  @doc """
  Returns the org's admin recipient cohort as `%{membership, user}`-style
  membership structs (`:user` preloaded), derived purely from
  `Membership.role == :admin` (server-authoritative). The owner is included even
  if their membership role is not `:admin`.
  """
  def list_org_admins(%Org{} = org) do
    org
    |> Orgs.list_memberships_with_users()
    |> Enum.filter(fn m -> m.role == :admin or org.created_by_id == m.user_id end)
  end

  ## Write path (append-only, best-effort, server-authoritative)

  @doc """
  Records one auditable action. BUSINESS orgs only. `actor` is the authenticated
  user performing the action (stamped server-side — never trusted from the
  client). `action` must be one of `AuditEvent.actions/0`.

  `opts`:
    * `:target_id`   — the polymorphic target's id (a user/group/shared_file uuid)
    * `:target_type` — `"user"` | `"group"` | `"shared_file"`
    * `:encrypted_label` — an OPAQUE, browser-supplied ciphertext (the action's
      human-readable target, e.g. a circle name, re-encrypted under the org's
      `org_key`). Stored as-is; the server never reads it (I6). Optional.

  Best-effort: returns `{:ok, event}` on success, `{:error, reason}` otherwise,
  but callers should ignore the result (the action it describes has already
  committed). Never raises.
  """
  def record_audit_event(org, actor, action, opts \\ [])

  def record_audit_event(%Org{type: :business} = org, %User{} = actor, action, opts)
      when is_binary(action) do
    attrs = %{
      "action" => action,
      "target_id" => opts[:target_id],
      "target_type" => opts[:target_type],
      "encrypted_label" => opts[:encrypted_label]
    }

    changeset = AuditEvent.insert_changeset(org, actor.id, attrs)

    case Repo.transaction_on_primary(fn -> Repo.insert(changeset) end) do
      {:ok, {:ok, event}} ->
        broadcast_recorded(org.id)
        {:ok, event}

      {:ok, {:error, changeset}} ->
        Logger.warning("[OrgAudit] dropped audit event: #{inspect(changeset.errors)}")
        {:error, changeset}

      {:error, reason} ->
        Logger.warning("[OrgAudit] failed to record audit event: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Non-business orgs (e.g. Family) have no audit log — silently ignore.
  def record_audit_event(%Org{}, %User{}, _action, _opts), do: {:ok, :skipped}

  ## Read path

  @doc """
  Lists the org's audit events, most recent first. `opts[:limit]` caps the result
  (default #{@default_limit}). Returns plain rows (ids + category + timestamp);
  the LiveView resolves human-readable descriptions client-side.
  """
  def list_audit_events(%Org{} = org, opts \\ []) do
    limit = opts[:limit] || @default_limit

    AuditEvent
    |> where([e], e.org_id == ^org.id)
    |> order_by([e], desc: e.inserted_at, desc: e.id)
    |> limit(^limit)
    |> Repo.all()
  end

  ## Realtime (id-only — ZK-safe)

  defp broadcast_recorded(org_id) when is_binary(org_id) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "org:#{org_id}",
      {:audit_recorded, %{org_id: org_id}}
    )

    :ok
  end
end
