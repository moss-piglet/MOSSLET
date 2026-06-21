defmodule MossletWeb.GuardianAvatarSealSupport do
  @moduledoc """
  Shared wiring for the family guardian safety-override avatar seal flow
  (Task #284).

  A guardian must see their MANAGED member's PERSONAL avatar so a minor can't
  hide behind a misleading org avatar. The managed member's `conn_key` (which
  decrypts that avatar) can only be sealed for the guardian in the MANAGED
  member's own browser. This module centralises the server-side wiring so the
  seal can be triggered from ANY LiveView the managed member frequents — not just
  the family dashboard (which a managed member may rarely visit). The timeline
  (where they post) is the most reliable trigger.

  The recipient set is server-authoritative (I1) — derived from active
  Guardianship records, never client params.
  """
  import Phoenix.LiveView, only: [push_event: 3]
  import Phoenix.Component, only: [assign: 3]

  alias Mosslet.Orgs

  @doc """
  The active guardianships where `user` is the managed member and the guardian's
  avatar key has NOT yet been sealed, as a browser-seal payload
  `[%{guardianship_id, public_key, pq_public_key}]`. Empty for non-managed users.
  """
  def seal_targets(%{id: user_id}) when is_binary(user_id) do
    user_id
    |> Orgs.list_guardianships_needing_avatar_key()
    |> Enum.map(fn %{guardianship_id: gid, guardian_user: guardian} ->
      %{
        guardianship_id: gid,
        public_key: guardian.key_pair["public"],
        pq_public_key: guardian.pq_public_key
      }
    end)
    |> Enum.reject(&is_nil(&1.public_key))
  end

  def seal_targets(_), do: []

  @doc """
  Assigns `:guardian_avatar_seal_targets` and, when connected with pending
  targets, pushes `seal_avatar_key_for_guardians` so the managed member's browser
  (GuardianAvatarSeal hook) seals their `conn_key` for each guardian.
  """
  def assign_and_request(socket, user) do
    if Phoenix.LiveView.connected?(socket) do
      targets = seal_targets(user)
      socket = assign(socket, :guardian_avatar_seal_targets, targets)

      if targets != [] do
        push_event(socket, "seal_avatar_key_for_guardians", %{guardians: targets})
      else
        socket
      end
    else
      assign(socket, :guardian_avatar_seal_targets, [])
    end
  end

  @doc """
  Persists the browser-sealed `conn_key` copies for `user`'s guardians.
  Server-authoritative + idempotent (see `Orgs.seal_managed_avatar_keys/2`).
  """
  def finalize(%{id: user_id}, sealed) when is_binary(user_id) and is_list(sealed) do
    Orgs.seal_managed_avatar_keys(user_id, sealed)
  end
end
