defmodule Mosslet.Orgs.AuditEvent do
  @moduledoc """
  ZK admin audit log event (Task #212 / EPIC #207, §12 of
  `docs/BUSINESS_CIRCLES_DESIGN.md`).

  Option B — metadata-only, server-authoritative, APPEND-ONLY. A single row
  records one auditable business-org action as opaque ids + a non-sensitive
  category + timestamp. There is **no readable content** here: human-readable
  descriptions ("Jane changed Bob's role") are reconstructed CLIENT-SIDE by an
  org admin from data they already decrypt (member `display_name`s, circle
  names). The server never sees, and cannot read, the human meaning.

  Tamper-resistance:

    * **Immutable** — there is no `updated_at` and no update/delete changeset.
      The `Mosslet.Orgs` context exposes only insert + read.
    * **Server-authoritative** — `actor_id`/`org_id`/`target_id` are stamped
      programmatically from the authenticated caller (never `cast`), so a rogue
      admin cannot forge or suppress their own entry.

  No Cloak/`Encrypted.Binary`: every field is an opaque UUID or a non-sensitive
  system category — encrypting them buys no confidentiality and would break the
  FK cascade + queryability. ZK = no readable content at rest, which holds here.
  """
  use Mosslet.Schema

  alias Mosslet.Accounts.User
  alias Mosslet.Orgs.Org

  # Non-sensitive system categories. Anything genuinely sensitive about the
  # action lives only in the client-rendered description, never the DB.
  @actions ~w(
    member_invited
    member_added
    member_removed
    role_changed
    display_name_changed
    circle_created
    circle_updated
    circle_deleted
    file_shared
    file_revoked
  )

  # What `target_id` points at (no hard FK because it is polymorphic).
  @target_types ~w(user group shared_file)

  def actions, do: @actions
  def target_types, do: @target_types

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "org_audit_events" do
    field :action, :string
    field :target_id, :binary_id
    field :target_type, :string

    belongs_to :org, Org
    belongs_to :actor, User

    timestamps(updated_at: false)
  end

  @doc """
  Builds an INSERT-only changeset. `org_id` and `actor_id` are stamped onto the
  struct programmatically (never cast) by the context; only the non-sensitive
  `action`/`target_id`/`target_type` describe the event. Append-only — there is
  intentionally no update/delete changeset.
  """
  def insert_changeset(%Org{} = org, actor_id, attrs) when is_map(attrs) do
    %__MODULE__{org_id: org.id, actor_id: actor_id}
    |> cast(attrs, [:action, :target_id, :target_type])
    |> validate_required([:action])
    |> validate_inclusion(:action, @actions)
    |> validate_inclusion(:target_type, @target_types)
  end
end
