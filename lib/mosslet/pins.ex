defmodule Mosslet.Pins do
  @moduledoc """
  Dashboard pinning for quick access (Task #229d, EPIC #207).

  A pin is a quick-access shortcut on a business org's dashboard. There are two
  orthogonal axes (see `Mosslet.Pins.Pin`):

    * `scope` — `:personal` (private to one member) or `:org_shared` (curated by
      an org owner/admin, visible org-wide).
    * `pin_type` — `:circle` / `:file` (store only a `target_id` FK; the name is
      reused from the already-decrypted client-side render — no new ciphertext)
      or `:link` (a free URL whose label/URL are **encrypted in the browser**
      with the viewer's `user_key` for personal scope, or the per-org `org_key`
      for org-wide scope, then additionally Cloak-wrapped server-side — ZK,
      I2/I3, the same pattern as `Mosslet.Announcements`).

  Authority is **server-authoritative** (I1):

    * Org-wide (shared) pins — only the org OWNER or an org ADMIN may
      create/reorder/delete them.
    * Personal pins — any org MEMBER may create their own; only that member may
      reorder/delete them.

  Realtime: org-wide pins broadcast id-only events on the org topic
  (`org:<org_id>`, which the dashboard already subscribes to via
  `Orgs.subscribe_org/1`). Personal pins are private to a single member and are
  refreshed locally — no broadcast (no plaintext, no keys leak — ZK-safe).
  """

  import Ecto.Query

  alias Mosslet.Accounts.User
  alias Mosslet.Orgs
  alias Mosslet.Orgs.Membership
  alias Mosslet.Orgs.Org
  alias Mosslet.Pins.Pin
  alias Mosslet.Repo

  ## Authority (server-authoritative — I1)

  @doc """
  Whether `user_id` may create/manage ORG-WIDE (shared) pins: the org OWNER or
  an org ADMIN. Re-checked on every write.
  """
  def can_manage_org_pins?(%Org{} = org, user_id) when is_binary(user_id) do
    Orgs.owner?(org, user_id) or org_admin?(org, user_id)
  end

  def can_manage_org_pins?(_, _), do: false

  @doc """
  Whether `user_id` may create their own PERSONAL pin on this org's dashboard:
  any current member of the org. Re-checked on every write.
  """
  def can_pin_personal?(%Org{} = org, user_id) when is_binary(user_id) do
    Orgs.member_of_org?(org, user_id)
  end

  def can_pin_personal?(_, _), do: false

  defp org_admin?(%Org{} = org, user_id) do
    Membership
    |> where([m], m.org_id == ^org.id and m.user_id == ^user_id and m.role == :admin)
    |> Repo.exists?()
  end

  ## Realtime (id-only events — ZK-safe; org-wide pins only)

  defp org_topic(org_id), do: "org:#{org_id}"

  defp broadcast_org_pins_updated(org_id) when is_binary(org_id) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      org_topic(org_id),
      {:pins_updated, %{scope: :org_shared, org_id: org_id}}
    )
  end

  ## Write path

  @doc """
  Creates a PERSONAL pin for `user` on `org`'s dashboard. `attrs` carries
  `pin_type` plus either `target_id` (`:circle`/`:file`) or the browser-encrypted
  `encrypted_label`/`encrypted_url` (`:link`). Authority (org membership) is
  re-checked here (I1). Appends to the end of the member's strip.
  """
  def create_personal_pin(%Org{} = org, %User{} = user, attrs) do
    attrs = normalize_keys(attrs)

    if can_pin_personal?(org, user.id) do
      attrs = put_position(attrs, next_personal_position(org, user))

      org
      |> Pin.personal_insert_changeset(user, attrs)
      |> insert_pin()
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Creates an ORG-WIDE (shared) pin on `org`'s dashboard. Authority (owner/admin)
  is re-checked here (I1). Appends to the end of the shared strip and broadcasts
  an id-only update on the org topic.
  """
  def create_org_shared_pin(%Org{} = org, %User{} = creator, attrs) do
    attrs = normalize_keys(attrs)

    if can_manage_org_pins?(org, creator.id) do
      attrs = put_position(attrs, next_org_shared_position(org))

      case org |> Pin.org_shared_insert_changeset(creator, attrs) |> insert_pin() do
        {:ok, pin} ->
          broadcast_org_pins_updated(org.id)
          {:ok, pin}

        other ->
          other
      end
    else
      {:error, :unauthorized}
    end
  end

  defp insert_pin(changeset) do
    case Repo.transaction_on_primary(fn -> Repo.insert(changeset) end) do
      {:ok, {:ok, pin}} -> {:ok, pin}
      {:ok, {:error, changeset}} -> {:error, changeset}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Deletes a pin. Authorized to: the owner of a PERSONAL pin, or a current
  org owner/admin for an ORG-WIDE pin (I1). Org-wide deletes broadcast an
  id-only update. Returns `{:ok, :deleted}` or `{:error, reason}`.
  """
  def delete_pin(%Pin{} = pin, %User{} = actor) do
    if can_manage_pin?(pin, actor) do
      case Repo.transaction_on_primary(fn -> Repo.delete(pin) end) do
        {:ok, {:ok, _}} ->
          if pin.scope == :org_shared, do: broadcast_org_pins_updated(pin.org_id)
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
  Whether `actor` may delete/reorder `pin`: the owner of a personal pin, or a
  current org owner/admin for an org-wide pin.
  """
  def can_manage_pin?(%Pin{scope: :personal} = pin, %User{} = actor),
    do: pin.user_id == actor.id

  def can_manage_pin?(%Pin{scope: :org_shared} = pin, %User{} = actor) do
    case Orgs.get_org_by_id(pin.org_id) do
      %Org{} = org -> can_manage_org_pins?(org, actor.id)
      _ -> false
    end
  end

  def can_manage_pin?(_, _), do: false

  @doc """
  Reorders a scope's pins to match `ordered_ids` (a list of pin ids in the new
  display order); each pin's `position` becomes its index. Only pins that belong
  to the given scope (+ `user` for `:personal`) on `org` are touched — ids that
  don't match are ignored (no cross-scope/cross-org tampering, I1). Authority is
  re-checked. Org-wide reorders broadcast an id-only update.
  """
  def reorder_personal_pins(%Org{} = org, %User{} = user, ordered_ids)
      when is_list(ordered_ids) do
    if can_pin_personal?(org, user.id) do
      eligible =
        Pin
        |> where([p], p.org_id == ^org.id and p.scope == :personal and p.user_id == ^user.id)
        |> select([p], p.id)
        |> Repo.all()
        |> MapSet.new()

      apply_positions(ordered_ids, eligible)
      :ok
    else
      {:error, :unauthorized}
    end
  end

  def reorder_org_shared_pins(%Org{} = org, %User{} = actor, ordered_ids)
      when is_list(ordered_ids) do
    if can_manage_org_pins?(org, actor.id) do
      eligible =
        Pin
        |> where([p], p.org_id == ^org.id and p.scope == :org_shared)
        |> select([p], p.id)
        |> Repo.all()
        |> MapSet.new()

      apply_positions(ordered_ids, eligible)
      broadcast_org_pins_updated(org.id)
      :ok
    else
      {:error, :unauthorized}
    end
  end

  defp apply_positions(ordered_ids, eligible) do
    Repo.transaction_on_primary(fn ->
      ordered_ids
      |> Enum.filter(&MapSet.member?(eligible, &1))
      |> Enum.with_index()
      |> Enum.each(fn {id, index} ->
        Pin
        |> where([p], p.id == ^id)
        |> Repo.update_all(set: [position: index])
      end)
    end)

    :ok
  end

  ## Read path

  @doc "Gets a pin by id (no auth — callers must authorize)."
  def get_pin(id), do: Repo.get(Pin, id)
  def get_pin!(id), do: Repo.get!(Pin, id)

  @doc """
  Lists a member's PERSONAL pins on this org's dashboard, in display order.
  """
  def list_personal_pins(%Org{} = org, %User{} = user) do
    Pin
    |> where([p], p.org_id == ^org.id and p.scope == :personal and p.user_id == ^user.id)
    |> order_by([p], asc: p.position, asc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists the org's ORG-WIDE (shared) pins, in display order. Org-scoped.
  """
  def list_org_shared_pins(%Org{} = org) do
    Pin
    |> where([p], p.org_id == ^org.id and p.scope == :org_shared)
    |> order_by([p], asc: p.position, asc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Finds the viewer's existing PERSONAL pin for a given `:circle`/`:file` target,
  or `nil`. Drives the quick-pin toggle (pin ⇄ unpin) on the dashboard.
  """
  def get_personal_target_pin(%Org{} = org, %User{} = user, pin_type, target_id)
      when pin_type in [:circle, :file] and is_binary(target_id) do
    Repo.get_by(Pin,
      org_id: org.id,
      scope: :personal,
      user_id: user.id,
      pin_type: pin_type,
      target_id: target_id
    )
  end

  def get_personal_target_pin(_, _, _, _), do: nil

  @doc """
  Finds the org's existing ORG-WIDE pin for a given `:circle`/`:file` target, or
  `nil`. Drives the admin quick-pin toggle.
  """
  def get_org_shared_target_pin(%Org{} = org, pin_type, target_id)
      when pin_type in [:circle, :file] and is_binary(target_id) do
    Repo.get_by(Pin,
      org_id: org.id,
      scope: :org_shared,
      pin_type: pin_type,
      target_id: target_id
    )
  end

  def get_org_shared_target_pin(_, _, _), do: nil

  defp next_personal_position(org, user) do
    Pin
    |> where([p], p.org_id == ^org.id and p.scope == :personal and p.user_id == ^user.id)
    |> next_position()
  end

  defp next_org_shared_position(org) do
    Pin
    |> where([p], p.org_id == ^org.id and p.scope == :org_shared)
    |> next_position()
  end

  defp next_position(query) do
    case Repo.aggregate(query, :max, :position) do
      nil -> 0
      max -> max + 1
    end
  end

  ## Param parsing (surface metadata)

  @doc """
  Maps a client pin-type hint to a known atom (never `String.to_atom/1` on user
  input). Unknown values return `nil` (the changeset then rejects it).
  """
  def parse_pin_type("circle"), do: :circle
  def parse_pin_type(:circle), do: :circle
  def parse_pin_type("file"), do: :file
  def parse_pin_type(:file), do: :file
  def parse_pin_type("link"), do: :link
  def parse_pin_type(:link), do: :link
  def parse_pin_type(_), do: nil

  defp put_position(attrs, position), do: Map.put(attrs, "position", position)

  defp normalize_keys(entry) do
    Map.new(entry, fn {k, v} -> {to_string(k), v} end)
  end
end
