defmodule Mosslet.Orgs.Adapters.Native do
  @moduledoc """
  Native adapter for org operations on desktop/mobile apps.

  This adapter communicates with the cloud server via HTTP API and
  caches data locally in SQLite for offline support.

  ## Flow

  1. API calls go to Fly.io server
  2. Server validates and returns data
  3. Data cached locally for offline access
  4. Offline operations queued for sync

  ## Zero-Knowledge

  All encryption/decryption happens locally on the device.
  The server only sees encrypted blobs.
  """

  @behaviour Mosslet.Orgs.Adapter

  require Logger

  alias Mosslet.API.Client
  alias Mosslet.Cache
  alias Mosslet.Session.Native, as: NativeSession
  alias Mosslet.Orgs.{Org, Membership, Invitation}
  alias Mosslet.Sync

  @impl true
  def list_orgs(user) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"orgs" => orgs}} <- Client.list_user_orgs(token) do
        Enum.each(orgs, &cache_org/1)
        Enum.map(orgs, &deserialize_org/1)
      else
        _ -> list_cached_orgs()
      end
    else
      list_cached_orgs()
    end
  end

  @impl true
  def list_orgs do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"orgs" => orgs}} <- Client.list_orgs(token) do
        Enum.each(orgs, &cache_org/1)
        Enum.map(orgs, &deserialize_org/1)
      else
        _ -> list_cached_orgs()
      end
    else
      list_cached_orgs()
    end
  end

  @impl true
  def get_org!(user, slug) when is_binary(slug) do
    case get_org_by_slug(slug) do
      nil -> raise Ecto.NoResultsError, queryable: Org
      org -> org
    end
  end

  @impl true
  def get_org!(slug) when is_binary(slug) do
    case get_org_by_slug(slug) do
      nil -> raise Ecto.NoResultsError, queryable: Org
      org -> org
    end
  end

  defp get_org_by_slug(slug) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"org" => org_data}} <- Client.get_org(token, slug) do
        cache_org(org_data)
        deserialize_org(org_data)
      else
        _ -> get_cached_org_by_slug(slug)
      end
    else
      get_cached_org_by_slug(slug)
    end
  end

  @impl true
  def get_org_by_id(id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"org" => org_data}} <- Client.get_org_by_id(token, id) do
        cache_org(org_data)
        deserialize_org(org_data)
      else
        _ -> get_cached_org(id)
      end
    else
      get_cached_org(id)
    end
  end

  @impl true
  def create_org(_user, _changeset) do
    if Sync.online?() do
      {:error, "Org creation must happen online via API"}
    else
      {:error, "Offline - cannot create org"}
    end
  end

  @impl true
  def update_org(org, attrs) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"org" => org_data}} <- Client.update_org(token, org.slug, attrs) do
        cache_org(org_data)
        {:ok, deserialize_org(org_data)}
      else
        {:error, %{"errors" => errors}} ->
          {:error, build_changeset_errors(errors, %Org{})}

        {:error, reason} ->
          {:error, reason}
      end
    else
      Cache.queue_for_sync("org", "update", Map.put(attrs, :slug, org.slug))
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def delete_org(org) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, _} <- Client.delete_org(token, org.slug) do
        Cache.invalidate_cache("org", org.id)
        {:ok, org}
      else
        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Offline - cannot delete org"}
    end
  end

  @impl true
  def sync_user_invitations(_user) do
    {:ok, %{}}
  end

  @impl true
  def list_members_by_org(org) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"members" => members}} <- Client.list_org_members(token, org.slug) do
        Enum.map(members, &deserialize_user/1)
      else
        _ -> []
      end
    else
      []
    end
  end

  @impl true
  def delete_membership(membership) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, _} <- Client.delete_org_membership(token, membership.id) do
        {:ok, membership}
      else
        {:error, %{"errors" => errors}} ->
          {:error, build_changeset_errors(errors, %Membership{})}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Offline - cannot delete membership"}
    end
  end

  @impl true
  def get_membership!(user, org_slug) when is_binary(org_slug) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"membership" => membership_data}} <-
             Client.get_org_membership(token, org_slug) do
        deserialize_membership(membership_data)
      else
        _ -> raise Ecto.NoResultsError, queryable: Membership
      end
    else
      raise Ecto.NoResultsError, queryable: Membership
    end
  end

  @impl true
  def get_membership!(id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"membership" => membership_data}} <-
             Client.get_membership(token, id) do
        deserialize_membership(membership_data)
      else
        _ -> raise Ecto.NoResultsError, queryable: Membership
      end
    else
      raise Ecto.NoResultsError, queryable: Membership
    end
  end

  @impl true
  def update_membership(membership, attrs) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"membership" => membership_data}} <-
             Client.update_org_membership(token, membership.id, attrs) do
        {:ok, deserialize_membership(membership_data)}
      else
        {:error, %{"errors" => errors}} ->
          {:error, build_changeset_errors(errors, %Membership{})}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Offline - cannot update membership"}
    end
  end

  @impl true
  def get_invitation_by_org!(org, id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"invitation" => invitation_data}} <-
             Client.get_org_invitation(token, org.slug, id) do
        deserialize_invitation(invitation_data)
      else
        _ -> raise Ecto.NoResultsError, queryable: Invitation
      end
    else
      raise Ecto.NoResultsError, queryable: Invitation
    end
  end

  @impl true
  def delete_invitation!(invitation) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, _} <- Client.delete_org_invitation(token, invitation.id) do
        invitation
      else
        _ -> raise Ecto.NoResultsError, queryable: Invitation
      end
    else
      raise "Offline - cannot delete invitation"
    end
  end

  @impl true
  def create_invitation(org, params) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"invitation" => invitation_data}} <-
             Client.create_org_invitation(token, org.slug, params) do
        {:ok, deserialize_invitation(invitation_data)}
      else
        {:error, %{"errors" => errors}} ->
          {:error, build_changeset_errors(errors, %Invitation{})}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Offline - cannot create invitation"}
    end
  end

  @impl true
  def list_invitations_by_user(_user) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"invitations" => invitations}} <- Client.list_user_invitations(token) do
        Enum.map(invitations, &deserialize_invitation/1)
      else
        _ -> []
      end
    else
      []
    end
  end

  @impl true
  def accept_invitation!(user, id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"membership" => membership_data}} <-
             Client.accept_org_invitation(token, id) do
        deserialize_membership(membership_data)
      else
        _ -> raise "Failed to accept invitation"
      end
    else
      raise "Offline - cannot accept invitation"
    end
  end

  @impl true
  def reject_invitation!(user, id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"invitation" => invitation_data}} <-
             Client.reject_org_invitation(token, id) do
        deserialize_invitation(invitation_data)
      else
        _ -> raise "Failed to reject invitation"
      end
    else
      raise "Offline - cannot reject invitation"
    end
  end

  defp list_cached_orgs do
    case Cache.list_cached_items("org") do
      items when is_list(items) ->
        items
        |> Enum.map(fn item -> deserialize_org(item.encrypted_data) end)
        |> Enum.reject(&is_nil/1)
        |> Enum.sort_by(& &1.id)

      _ ->
        []
    end
  end

  defp get_cached_org(id) do
    case Cache.get_cached_item("org", id) do
      %{encrypted_data: data} when not is_nil(data) ->
        deserialize_org(data)

      _ ->
        nil
    end
  end

  defp get_cached_org_by_slug(slug) do
    case Cache.list_cached_items("org") do
      items when is_list(items) ->
        items
        |> Enum.map(fn item -> deserialize_org(item.encrypted_data) end)
        |> Enum.find(fn org -> org && org.slug == slug end)

      _ ->
        nil
    end
  end

  defp cache_org(org_data) when is_map(org_data) do
    id = org_data["id"] || org_data[:id]
    Cache.cache_item("org", id, org_data)
  end

  defp deserialize_org(nil), do: nil

  defp deserialize_org(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, decoded} -> deserialize_org(decoded)
      _ -> nil
    end
  end

  defp deserialize_org(data) when is_map(data) do
    %Org{
      id: data["id"] || data[:id],
      name: data["name"] || data[:name],
      name_hash: data["name_hash"] || data[:name_hash],
      slug: data["slug"] || data[:slug],
      inserted_at: parse_naive_datetime(data["inserted_at"] || data[:inserted_at]),
      updated_at: parse_naive_datetime(data["updated_at"] || data[:updated_at])
    }
  end

  defp deserialize_membership(nil), do: nil

  defp deserialize_membership(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, decoded} -> deserialize_membership(decoded)
      _ -> nil
    end
  end

  defp deserialize_membership(data) when is_map(data) do
    role =
      case data["role"] || data[:role] do
        r when is_atom(r) -> r
        r when is_binary(r) -> String.to_existing_atom(r)
        _ -> :member
      end

    org = if data["org"], do: deserialize_org(data["org"]), else: nil
    user = if data["user"], do: deserialize_user(data["user"]), else: nil

    %Membership{
      id: data["id"] || data[:id],
      org_id: data["org_id"] || data[:org_id],
      user_id: data["user_id"] || data[:user_id],
      role: role,
      org: org,
      user: user,
      inserted_at: parse_naive_datetime(data["inserted_at"] || data[:inserted_at]),
      updated_at: parse_naive_datetime(data["updated_at"] || data[:updated_at])
    }
  end

  defp deserialize_invitation(nil), do: nil

  defp deserialize_invitation(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, decoded} -> deserialize_invitation(decoded)
      _ -> nil
    end
  end

  defp deserialize_invitation(data) when is_map(data) do
    org = if data["org"], do: deserialize_org(data["org"]), else: nil

    %Invitation{
      id: data["id"] || data[:id],
      org_id: data["org_id"] || data[:org_id],
      user_id: data["user_id"] || data[:user_id],
      sent_to: data["sent_to"] || data[:sent_to],
      sent_to_hash: data["sent_to_hash"] || data[:sent_to_hash],
      org: org,
      inserted_at: parse_naive_datetime(data["inserted_at"] || data[:inserted_at]),
      updated_at: parse_naive_datetime(data["updated_at"] || data[:updated_at])
    }
  end

  defp deserialize_user(nil), do: nil

  defp deserialize_user(data) when is_map(data) do
    %Mosslet.Accounts.User{
      id: data["id"] || data[:id],
      email: data["email"] || data[:email],
      username: data["username"] || data[:username]
    }
  end

  defp parse_naive_datetime(nil), do: nil

  defp parse_naive_datetime(str) when is_binary(str) do
    case NaiveDateTime.from_iso8601(str) do
      {:ok, dt} -> dt
      _ -> nil
    end
  end

  defp parse_naive_datetime(dt), do: dt

  defp build_changeset_errors(errors, struct) when is_map(errors) do
    Enum.reduce(errors, Ecto.Changeset.change(struct), fn {field, messages}, changeset ->
      field_atom = if is_binary(field), do: String.to_existing_atom(field), else: field

      Enum.reduce(List.wrap(messages), changeset, fn msg, cs ->
        Ecto.Changeset.add_error(cs, field_atom, msg)
      end)
    end)
  end

  defp build_changeset_errors(_, struct), do: Ecto.Changeset.change(struct)
end
