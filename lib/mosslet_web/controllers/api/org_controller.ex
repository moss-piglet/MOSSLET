defmodule MossletWeb.API.OrgController do
  @moduledoc """
  API endpoints for organization operations.

  Handles organization CRUD, membership, and invitation management.
  """
  use MossletWeb, :controller

  alias Mosslet.Orgs
  alias Mosslet.Orgs.{Org, Membership}

  action_fallback MossletWeb.API.FallbackController

  def index(conn, _params) do
    user = conn.assigns.current_user

    orgs = Orgs.list_orgs(user)

    conn
    |> put_status(:ok)
    |> json(%{orgs: Enum.map(orgs, &serialize_org/1)})
  end

  def mine(conn, _params) do
    user = conn.assigns.current_user

    orgs = Orgs.list_orgs(user)

    conn
    |> put_status(:ok)
    |> json(%{orgs: Enum.map(orgs, &serialize_org/1)})
  end

  def show(conn, %{"id" => slug}) do
    user = conn.assigns.current_user

    case Orgs.get_org!(user, slug) do
      nil ->
        {:error, :not_found}

      org ->
        conn
        |> put_status(:ok)
        |> json(%{org: serialize_org(org)})
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def show_by_id(conn, %{"id" => id}) do
    case Orgs.get_org_by_id(id) do
      nil ->
        {:error, :not_found}

      org ->
        conn
        |> put_status(:ok)
        |> json(%{org: serialize_org(org)})
    end
  end

  def create(conn, %{"org" => org_params}) do
    user = conn.assigns.current_user

    case Orgs.create_org(user, org_params) do
      {:ok, org} ->
        conn
        |> put_status(:created)
        |> json(%{
          org: serialize_org(org),
          message: "Organization created successfully"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def create(_conn, _params), do: {:error, :missing_params}

  def update(conn, %{"id" => slug, "org" => org_params}) do
    user = conn.assigns.current_user

    case Orgs.get_org!(user, slug) do
      nil ->
        {:error, :not_found}

      org ->
        if can_manage_org?(user, org) do
          case Orgs.update_org(org, org_params) do
            {:ok, updated_org} ->
              conn
              |> put_status(:ok)
              |> json(%{
                org: serialize_org(updated_org),
                message: "Organization updated successfully"
              })

            {:error, changeset} ->
              {:error, changeset}
          end
        else
          {:error, :forbidden}
        end
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def update(_conn, _params), do: {:error, :missing_params}

  def delete(conn, %{"id" => slug}) do
    user = conn.assigns.current_user

    case Orgs.get_org!(user, slug) do
      nil ->
        {:error, :not_found}

      org ->
        if can_manage_org?(user, org) do
          case Orgs.delete_org(org) do
            {:ok, _} ->
              conn
              |> put_status(:ok)
              |> json(%{message: "Organization deleted successfully"})

            {:error, error} ->
              {:error, error}
          end
        else
          {:error, :forbidden}
        end
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def list_members(conn, %{"org_id" => slug}) do
    user = conn.assigns.current_user

    case Orgs.get_org!(user, slug) do
      nil ->
        {:error, :not_found}

      org ->
        members = Orgs.list_members_by_org(org)

        conn
        |> put_status(:ok)
        |> json(%{members: Enum.map(members, &serialize_membership/1)})
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def show_membership(conn, %{"id" => id}) do
    case Orgs.get_membership!(id) do
      nil ->
        {:error, :not_found}

      membership ->
        conn
        |> put_status(:ok)
        |> json(%{membership: serialize_membership(membership)})
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def update_membership(conn, %{"id" => id, "membership" => membership_params}) do
    user = conn.assigns.current_user

    case Orgs.get_membership!(id) do
      nil ->
        {:error, :not_found}

      membership ->
        org = Orgs.get_org_by_id(membership.org_id)

        if can_manage_org?(user, org) do
          case Orgs.update_membership(membership, membership_params) do
            {:ok, updated_membership} ->
              conn
              |> put_status(:ok)
              |> json(%{
                membership: serialize_membership(updated_membership),
                message: "Membership updated successfully"
              })

            {:error, changeset} ->
              {:error, changeset}
          end
        else
          {:error, :forbidden}
        end
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def update_membership(_conn, _params), do: {:error, :missing_params}

  def delete_membership(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Orgs.get_membership!(id) do
      nil ->
        {:error, :not_found}

      membership ->
        org = Orgs.get_org_by_id(membership.org_id)
        is_self = membership.user_id == user.id
        is_admin = can_manage_org?(user, org)

        if is_self || is_admin do
          case Orgs.delete_membership(membership) do
            {:ok, _} ->
              conn
              |> put_status(:ok)
              |> json(%{message: "Member removed from organization"})

            {:error, error} ->
              {:error, error}
          end
        else
          {:error, :forbidden}
        end
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def list_my_invitations(conn, _params) do
    user = conn.assigns.current_user

    invitations = Orgs.list_invitations_by_user(user)

    conn
    |> put_status(:ok)
    |> json(%{invitations: Enum.map(invitations, &serialize_invitation/1)})
  end

  def show_invitation(conn, %{"org_id" => slug, "id" => id}) do
    user = conn.assigns.current_user

    case Orgs.get_org!(user, slug) do
      nil ->
        {:error, :not_found}

      org ->
        case Orgs.get_invitation_by_org!(org, id) do
          nil ->
            {:error, :not_found}

          invitation ->
            conn
            |> put_status(:ok)
            |> json(%{invitation: serialize_invitation(invitation)})
        end
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def create_invitation(conn, %{"org_id" => slug, "invitation" => invitation_params}) do
    user = conn.assigns.current_user

    case Orgs.get_org!(user, slug) do
      nil ->
        {:error, :not_found}

      org ->
        if can_manage_org?(user, org) do
          case Orgs.create_invitation(org, invitation_params) do
            {:ok, invitation} ->
              conn
              |> put_status(:created)
              |> json(%{
                invitation: serialize_invitation(invitation),
                message: "Invitation sent successfully"
              })

            {:error, changeset} ->
              {:error, changeset}
          end
        else
          {:error, :forbidden}
        end
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def create_invitation(_conn, _params), do: {:error, :missing_params}

  def delete_invitation(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    invitations = Orgs.list_invitations_by_user(user)
    invitation = Enum.find(invitations, &(&1.id == id))

    if invitation do
      org = Orgs.get_org_by_id(invitation.org_id)

      if can_manage_org?(user, org) do
        Orgs.delete_invitation!(invitation)

        conn
        |> put_status(:ok)
        |> json(%{message: "Invitation deleted"})
      else
        {:error, :forbidden}
      end
    else
      {:error, :not_found}
    end
  end

  def accept_invitation(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Orgs.accept_invitation!(user, id) do
      {:ok, membership} ->
        conn
        |> put_status(:ok)
        |> json(%{
          membership: serialize_membership(membership),
          message: "Invitation accepted"
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: inspect(reason)})
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def reject_invitation(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Orgs.reject_invitation!(user, id) do
      {:ok, _} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "Invitation rejected"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: inspect(reason)})
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  defp can_manage_org?(user, org) do
    membership =
      Enum.find(org.memberships || [], fn m ->
        m.user_id == user.id && m.role in ["admin", :admin]
      end)

    membership != nil
  end

  defp serialize_org(nil), do: nil

  defp serialize_org(%Org{} = org) do
    %{
      id: org.id,
      name: org.name,
      slug: org.slug,
      inserted_at: org.inserted_at,
      updated_at: org.updated_at,
      memberships: Enum.map(org.memberships || [], &serialize_membership/1)
    }
  end

  defp serialize_membership(nil), do: nil

  defp serialize_membership(%Membership{} = membership) do
    %{
      id: membership.id,
      org_id: membership.org_id,
      user_id: membership.user_id,
      role: membership.role,
      inserted_at: membership.inserted_at,
      updated_at: membership.updated_at
    }
  end

  defp serialize_invitation(nil), do: nil

  defp serialize_invitation(invitation) do
    %{
      id: invitation.id,
      org_id: invitation.org_id,
      email: invitation.email,
      user_id: invitation.user_id,
      role: invitation.role,
      inserted_at: invitation.inserted_at
    }
  end
end
