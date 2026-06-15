defmodule MossletWeb.OrgIdentity do
  @moduledoc """
  Shared org-scoped ZK display-name logic (Task #225), reused VERBATIM by the
  Family and Business dashboards. The identity layer is type-agnostic: one
  per-org `org_key` sealed per member (`Membership.key`), one org-facing
  `display_name` encrypted with it. Org-type-specific features stay in each
  LiveView; only this shared identity primitive lives here.

  See `docs/ORG_DISPLAY_NAME_DESIGN.md`. Strictly `org_id`-scoped — never leaks
  identity across org boundaries (D1).
  """

  alias Mosslet.Orgs
  alias Mosslet.Orgs.{Org, Membership}
  alias Mosslet.Accounts

  @doc """
  Builds the roster `member` maps for an org, each carrying the ZK fields the
  template + `OrgMembers` hook need:

    * `:user` / `:membership` — as before.
    * `:encrypted_display_name` — the member's org persona ciphertext (or nil).
    * `:personal_name` — a personal connection name the viewer can already read
      (preferred when present, design Q4), or nil.
    * `:self?` — true for the viewer's own row.
    * `:connection_status` — `:connected | :pending | :none | :self`, the
      viewer's personal `UserConnection` status to this member (Task #226). Used
      to render the one-tap "Connect with teammate" button only when `:none`.

  `personal_name_fun` is `(member_user -> binary | nil)` so each LiveView can
  reuse its existing connection-name resolution (additive; no regression).

  Pass `statuses` (a `member_user_id => :connected | :pending | :none` map from
  `Accounts.connection_statuses_for/2`) to populate `:connection_status` in a
  single batched query (no N+1). When omitted, all rows default to `:none`
  (button hidden via `self?`/personal_name guards is unaffected).
  """
  def build_members(%Org{} = org, viewer, personal_name_fun, statuses \\ %{})
      when is_function(personal_name_fun, 1) and is_map(statuses) do
    org
    |> Orgs.list_memberships_with_users()
    |> Enum.map(fn membership ->
      user = membership.user
      self? = user.id == viewer.id

      connection_status =
        if self?, do: :self, else: Map.get(statuses, user.id, :none)

      %{
        user: user,
        membership: membership,
        encrypted_display_name: membership.display_name,
        personal_name: if(self?, do: nil, else: personal_name_fun.(user)),
        self?: self?,
        connection_status: connection_status
      }
    end)
  end

  @doc """
  Whether to show the one-tap "Connect with teammate" button for a roster row
  (Task #226): only for other members the viewer has no personal `UserConnection`
  with yet. Hidden for self, and once a request is pending or connected.
  """
  def show_connect_button?(%{self?: true}), do: false
  def show_connect_button?(%{connection_status: :none}), do: true
  def show_connect_button?(_member), do: false

  @doc """
  Whether a pending personal connection request exists between the viewer and
  this roster member (Task #226) — used to show a non-actionable "Pending" pill.
  """
  def connection_pending?(%{connection_status: :pending}), do: true
  def connection_pending?(_member), do: false

  @doc """
  Resolves the viewer's own membership row from a pre-built member list (the row
  whose `:self?` is true). Returns the `Membership` or nil.
  """
  def viewer_membership(members) do
    case Enum.find(members, & &1.self?) do
      %{membership: membership} -> membership
      _ -> nil
    end
  end

  @doc """
  The viewer's sealed `org_key` (their `Membership.key`) for the read/seal hook,
  or `nil` when not yet sealed for them.
  """
  def viewer_sealed_org_key(members) do
    case viewer_membership(members) do
      %Membership{key: key} -> key
      _ -> nil
    end
  end

  @doc """
  Whether the viewer should bootstrap the `org_key` (design Q1=A): they are the
  org owner AND no member holds the key yet. The owner's browser then generates
  + self-seals the key.
  """
  def should_bootstrap?(%Org{} = org, viewer, members) do
    Orgs.owner?(org, viewer.id) and
      viewer_sealed_org_key(members) == nil and
      not Enum.any?(members, &(&1.membership.key != nil))
  end

  @doc """
  Whether the viewer already holds the `org_key` and there are members who still
  need it sealed. When true, the LiveView pushes `seal_org_key_for_members` so
  the viewer's browser seals for them (design 4.2b).
  """
  def viewer_can_seal_for_others?(members) do
    viewer_sealed_org_key(members) != nil and
      Enum.any?(members, &(&1.membership.key == nil))
  end

  @doc """
  Returns the display label for a roster row, server-side: the viewer's "You",
  a readable personal connection name (Q4 preference), else a neutral
  placeholder. The org persona (encrypted) is filled in client-side by the hook,
  overriding the placeholder when decrypted.
  """
  def placeholder_label(member, fallback \\ "Team member")
  def placeholder_label(%{self?: true}, _fallback), do: "You"

  def placeholder_label(%{personal_name: name}, _fallback)
      when is_binary(name) and name != "",
      do: name

  def placeholder_label(_member, fallback), do: fallback

  @doc """
  Template helper: the attributes to splat onto a roster row's name `<span>`.

  Returns the `data-decrypt-org-name` marker ONLY when the hook should fill this
  row with the decrypted org persona — i.e. NOT the viewer's own row and NOT a
  row where a readable personal-connection name is already shown (Q4: personal
  name is preferred and must not be overwritten). Otherwise returns `%{}`.
  """
  def org_name_target(%{self?: true}), do: %{}

  def org_name_target(%{personal_name: name}) when is_binary(name) and name != "", do: %{}

  def org_name_target(_member), do: %{"data-decrypt-org-name" => "1"}

  @doc """
  Builds the payload (members needing the key, with public keys) the viewer's
  browser must seal `org_key` for. Server-authoritative (D1).
  """
  def members_to_seal(%Org{} = org) do
    Orgs.members_needing_org_key(org)
  end

  @doc """
  Builds the seal payload for adding the given org members to a business circle
  (no personal `UserConnection` required — membership in the org is the only
  prerequisite). Server-authoritative (D1/I1): `user_ids` is intersected with the
  org's CURRENT membership rows, so a tampered client can never seal a circle key
  for a non-member.

  Each returned map carries the member's `public_key` + `pq_public_key` (the
  sealing target — public keys are not secret) and their org `display_name`
  ciphertext (`encrypted_display_name`, secretbox under the shared `org_key`).
  The adder's browser already holds the `org_key`, so it can decrypt the name and
  re-encrypt it with the circle `group_key` — all client-side, ZK. The raw
  `org_key` / `group_key` and plaintext names never reach the server.

  Members whose public key is missing are dropped (we can't seal for them).
  """
  def members_to_add(%Org{} = org, user_ids) when is_list(user_ids) do
    wanted = MapSet.new(user_ids)

    org
    |> Orgs.list_memberships_with_users()
    |> Enum.filter(fn membership -> MapSet.member?(wanted, membership.user_id) end)
    |> Enum.map(fn membership ->
      user = membership.user

      %{
        user_id: user.id,
        public_key: user.key_pair["public"],
        pq_public_key: user.pq_public_key,
        encrypted_display_name: membership.display_name
      }
    end)
    |> Enum.reject(&is_nil(&1.public_key))
  end

  @doc """
  Persists browser-sealed `org_key` copies and returns `{:ok, count}`.
  Server-authoritative + idempotent (drops non-members / already-sealed).
  """
  def finalize_org_key(%Org{} = org, sealed_members) when is_list(sealed_members) do
    Orgs.seal_org_key_for_members(org, sealed_members)
  end

  @doc """
  One-tap "Connect with teammate" (Task #226): send a standard personal
  `UserConnection` invite from the viewer to a fellow org member, reusing the
  existing invite + sealing path (no new crypto, no master key — the connection
  key is sealed for the recipient using the viewer's own in-memory session key,
  exactly as the personal connections UI does).

  Server-authoritative: the `target_user_id` MUST be a current member of `org`
  (D1) — a tampered client cannot invite a non-member through this path. The
  recipient is resolved by `user_id` (the viewer can't read the member's
  encrypted username/email under ZK), but sealing is identical to the
  username/email flow.

  Returns `{:ok, uconn}`, `{:error, :not_a_member}`, or
  `{:error, %Ecto.Changeset{}}`.
  """
  def connect_teammate(%Org{} = org, current_scope, target_user_id)
      when is_binary(target_user_id) do
    user = current_scope.user
    key = current_scope.key

    cond do
      target_user_id == user.id ->
        {:error, :not_a_member}

      not Orgs.member_of_org?(org, target_user_id) ->
        {:error, :not_a_member}

      true ->
        uconn_params = %{
          "selector" => "user_id",
          "user_id" => target_user_id,
          "temp_label" => "Teammate",
          "color" => "emerald",
          "connection_id" => user.connection.id,
          "reverse_user_id" => user.id
        }

        Accounts.create_user_connection(uconn_params,
          user: user,
          key: key,
          selector: "user_id"
        )
    end
  end
end
