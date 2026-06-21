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
  alias Mosslet.Orgs.{Org, Membership, Invitation, Guardianship, OwnershipTransfer}
  @callback list_orgs(user :: User.t()) :: [Org.t()]
  @callback list_orgs() :: [Org.t()]
  @callback list_orgs_with_billing() :: [Org.t()]
  @callback get_org!(user :: User.t(), slug :: String.t()) :: Org.t()
  @callback get_org!(slug :: String.t()) :: Org.t()
  @callback get_org_by_id(id :: String.t()) :: Org.t() | nil
  @callback get_org_by_slug(slug :: String.t()) :: Org.t() | nil
  @callback get_org_by_subdomain(subdomain :: String.t()) :: Org.t() | nil

  @callback create_org(user :: User.t(), changeset :: Ecto.Changeset.t()) ::
              {:ok, Org.t()} | {:error, Ecto.Changeset.t()}

  @callback list_memberships_for_user(user :: User.t()) :: [Membership.t()]
  @callback list_owned_orgs(user :: User.t(), type :: atom() | nil) :: [Org.t()]
  @callback count_owned_orgs(user :: User.t(), type :: atom() | nil) :: non_neg_integer()
  @callback count_member_orgs(user :: User.t(), type :: atom() | nil) :: non_neg_integer()

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

  # Org-scoped ZK identity (Task #225).
  @callback list_memberships_with_users(org :: Org.t()) :: [Membership.t()]
  @callback seal_org_key_for_members(org :: Org.t(), sealed_list :: [map()]) ::
              {:ok, non_neg_integer()} | {:error, term()}
  @callback set_org_display_name(membership :: Membership.t(), encrypted_name :: String.t()) ::
              {:ok, Membership.t()} | {:error, Ecto.Changeset.t()}

  # Org-scoped ZK display avatar (Task #277). `encrypted_avatar` is the opaque
  # org_key-secretbox ciphertext (base64) of the resized WebP bytes; clearing
  # falls back to initials derived from the org display name.
  @callback set_org_avatar(membership :: Membership.t(), encrypted_avatar :: String.t()) ::
              {:ok, Membership.t()} | {:error, Ecto.Changeset.t()}
  @callback clear_org_avatar(membership :: Membership.t()) ::
              {:ok, Membership.t()} | {:error, Ecto.Changeset.t()}

  # Org brand logo (Task #228, branding add-on). `storage_path` is the opaque
  # Tigris object key for the (already org_key-encrypted) logo blob.
  @callback set_org_logo(org :: Org.t(), storage_path :: String.t()) ::
              {:ok, Org.t()} | {:error, Ecto.Changeset.t()}
  @callback clear_org_logo(org :: Org.t()) ::
              {:ok, Org.t()} | {:error, Ecto.Changeset.t()}

  # Custom subdomain (Task #240, Phase B). The subdomain label is non-sensitive
  # plaintext; validation lives in `Org.subdomain_changeset/2`. The add-on
  # entitlement gate is enforced in the context/UI, not here.
  @callback set_org_subdomain(org :: Org.t(), attrs :: map()) ::
              {:ok, Org.t()} | {:error, Ecto.Changeset.t()}
  @callback clear_org_subdomain(org :: Org.t()) ::
              {:ok, Org.t()} | {:error, Ecto.Changeset.t()}

  @callback get_invitation_by_org!(org :: Org.t(), id :: String.t()) :: Invitation.t()
  @callback get_invitation_with_org(id :: String.t()) :: Invitation.t() | nil
  @callback delete_invitation!(invitation :: Invitation.t()) :: Invitation.t()

  @callback create_invitation(org :: Org.t(), params :: map()) ::
              {:ok, Invitation.t()} | {:error, Ecto.Changeset.t()}

  @callback count_pending_invitations(org :: Org.t()) :: non_neg_integer()

  @callback list_invitations_by_user(user :: User.t()) :: [Invitation.t()]
  @callback list_invitations_by_org(org :: Org.t()) :: [Invitation.t()]
  @callback list_pending_invitations_by_email_hash(email_hash :: term()) :: [Invitation.t()]
  @callback accept_invitation!(user :: User.t(), id :: String.t()) :: Membership.t()
  @callback accept_invitation_record!(user :: User.t(), invitation :: Invitation.t()) ::
              Membership.t()
  @callback reject_invitation!(user :: User.t(), id :: String.t()) :: Invitation.t()

  @callback establish_guardianship(
              guardian :: Membership.t(),
              managed :: Membership.t(),
              opts :: keyword()
            ) :: {:ok, Guardianship.t()} | {:error, Ecto.Changeset.t() | term()}

  @callback accept_guardianship(guardianship :: Guardianship.t()) ::
              {:ok, Guardianship.t()} | {:error, Ecto.Changeset.t()}
  @callback decline_guardianship(guardianship :: Guardianship.t()) ::
              {:ok, Guardianship.t()} | {:error, Ecto.Changeset.t()}
  @callback pause_guardianship(guardianship :: Guardianship.t()) ::
              {:ok, Guardianship.t()} | {:error, Ecto.Changeset.t()}
  @callback resume_guardianship(guardianship :: Guardianship.t()) ::
              {:ok, Guardianship.t()} | {:error, Ecto.Changeset.t()}
  @callback revoke_guardianship(guardianship :: Guardianship.t()) ::
              {:ok, Guardianship.t()} | {:error, Ecto.Changeset.t()}

  @callback list_active_guardians_for(org :: Org.t(), managed_user_id :: String.t()) :: [User.t()]
  @callback list_active_guardian_users_for_user(user_id :: String.t()) :: [User.t()]
  @callback list_guardianships_by_org(org :: Org.t()) :: [Guardianship.t()]
  @callback list_guardianships_for_managed_membership(membership :: Membership.t()) ::
              [Guardianship.t()]
  @callback list_guardianships_for_guardian_membership(membership :: Membership.t()) ::
              [Guardianship.t()]
  @callback get_guardianship!(id :: String.t()) :: Guardianship.t()
  @callback org_name_resolution_between_users(
              viewer_user_id :: String.t(),
              author_user_id :: String.t()
            ) :: %{sealed_org_key: binary(), encrypted_display_name: binary()} | nil

  # Ownership transfer handshake (Task #237).
  @callback insert_ownership_transfer(attrs :: map()) ::
              {:ok, OwnershipTransfer.t()} | {:error, Ecto.Changeset.t()}
  @callback get_ownership_transfer(id :: String.t()) :: OwnershipTransfer.t() | nil
  @callback get_pending_transfer_for_org(org :: Org.t()) :: OwnershipTransfer.t() | nil
  @callback list_pending_transfers_for_user(user :: User.t()) :: [OwnershipTransfer.t()]
  @callback accept_ownership_transfer_record(
              transfer :: OwnershipTransfer.t(),
              to_user :: User.t()
            ) :: {:ok, OwnershipTransfer.t()} | {:error, term()}
  @callback update_ownership_transfer_status(transfer :: OwnershipTransfer.t(), attrs :: map()) ::
              {:ok, OwnershipTransfer.t()} | {:error, Ecto.Changeset.t()}
end
