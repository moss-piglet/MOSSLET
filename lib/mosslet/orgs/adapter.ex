defmodule Mosslet.Orgs.Adapter do
  @moduledoc """
  Behaviour defining the interface for platform-specific org operations.

  This enables the same context API to work across web (direct Repo access)
  and native (API + cache) platforms.

  ## Implementation

  Web adapter (`Mosslet.Orgs.Adapters.Web`):
  - Direct Postgres access via `Mosslet.Repo`

  Native adapter (`Mosslet.Orgs.Adapters.Native`):
  - HTTP API calls to cloud server via `Mosslet.API.Client`
  - Local SQLite cache via `Mosslet.Cache`
  - Offline fallback to cached data

  ## Pattern

  Following the same pattern as other adapters:
  - Business logic stays in the context (`Mosslet.Orgs`)
  - Adapters handle data access (database vs API)
  """

  alias Mosslet.Accounts.User
  alias Mosslet.Orgs.{Org, Membership, Invitation}

  @callback list_orgs(user :: User.t()) :: [Org.t()]
  @callback list_orgs() :: [Org.t()]
  @callback get_org!(user :: User.t(), slug :: String.t()) :: Org.t()
  @callback get_org!(slug :: String.t()) :: Org.t()
  @callback get_org_by_id(id :: String.t()) :: Org.t() | nil

  @callback create_org(user :: User.t(), changeset :: Ecto.Changeset.t()) ::
              {:ok, Org.t()} | {:error, Ecto.Changeset.t()}

  @callback update_org(org :: Org.t(), attrs :: map()) ::
              {:ok, Org.t()} | {:error, Ecto.Changeset.t()}

  @callback delete_org(org :: Org.t()) ::
              {:ok, Org.t()} | {:error, Ecto.Changeset.t()}

  @callback sync_user_invitations(user :: User.t()) :: {:ok, map()} | {:error, term()}

  @callback list_members_by_org(org :: Org.t()) :: [User.t()]

  @callback delete_membership(membership :: Membership.t()) ::
              {:ok, Membership.t()} | {:error, Ecto.Changeset.t()}

  @callback get_membership!(user :: User.t(), org_slug :: String.t()) :: Membership.t()
  @callback get_membership!(id :: String.t()) :: Membership.t()

  @callback update_membership(membership :: Membership.t(), attrs :: map()) ::
              {:ok, Membership.t()} | {:error, Ecto.Changeset.t()}

  @callback get_invitation_by_org!(org :: Org.t(), id :: String.t()) :: Invitation.t()
  @callback delete_invitation!(invitation :: Invitation.t()) :: Invitation.t()

  @callback create_invitation(org :: Org.t(), params :: map()) ::
              {:ok, Invitation.t()} | {:error, Ecto.Changeset.t()}

  @callback list_invitations_by_user(user :: User.t()) :: [Invitation.t()]
  @callback accept_invitation!(user :: User.t(), id :: String.t()) :: Membership.t()
  @callback reject_invitation!(user :: User.t(), id :: String.t()) :: Invitation.t()
end
