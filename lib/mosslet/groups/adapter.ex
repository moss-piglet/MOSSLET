defmodule Mosslet.Groups.Adapter do
  @moduledoc """
  Behaviour defining the interface for platform-specific group operations.

  This enables the same context API to work across web (direct Repo access)
  and native (API + cache) platforms.

  ## Implementation

  Web adapter (`Mosslet.Groups.Adapters.Web`):
  - Direct Postgres access via `Mosslet.Repo`
  - Uses `Fly.Repo.transaction_on_primary/1` for writes

  Native adapter (`Mosslet.Groups.Adapters.Native`):
  - HTTP API calls to cloud server via `Mosslet.API.Client`
  - Local SQLite cache via `Mosslet.Cache`
  - Offline fallback to cached data

  ## Pattern

  Following the same pattern as `Mosslet.Accounts.Adapter`:
  - Business logic stays in the context (`Mosslet.Groups`)
  - Adapters handle data access (database vs API)
  - Context orchestrates operations and broadcasts events
  """

  alias Mosslet.Accounts.User
  alias Mosslet.Groups.{Group, GroupBlock, UserGroup}

  @callback get_group(id :: String.t()) :: Group.t() | nil
  @callback get_group!(id :: String.t()) :: Group.t()

  @callback list_groups(user :: User.t(), options :: keyword()) :: [Group.t()]
  @callback list_unconfirmed_groups(user :: User.t(), options :: keyword()) :: [Group.t()]
  @callback list_public_groups(
              user :: User.t(),
              search_term :: String.t() | nil,
              options :: keyword()
            ) :: [Group.t()]
  @callback public_group_count(user :: User.t(), search_term :: String.t() | nil) ::
              non_neg_integer()
  @callback filter_groups_with_users(
              user_id :: String.t(),
              current_user_id :: String.t(),
              options :: map()
            ) :: [Group.t()]
  @callback group_count(user :: User.t()) :: non_neg_integer()
  @callback group_count_confirmed(user :: User.t()) :: non_neg_integer()
  @callback list_user_groups_for_sync(user :: User.t(), options :: keyword()) :: [UserGroup.t()]

  @callback get_user_group(id :: String.t()) :: UserGroup.t() | nil
  @callback get_user_group!(id :: String.t()) :: UserGroup.t()
  @callback get_user_group_with_user!(id :: String.t()) :: UserGroup.t()
  @callback get_user_group_for_group_and_user(group :: Group.t(), user :: User.t()) ::
              UserGroup.t() | nil
  @callback list_user_groups(group :: Group.t()) :: [UserGroup.t()]
  @callback list_user_groups() :: [UserGroup.t()]
  @callback list_user_groups_for_user(user :: User.t()) :: [UserGroup.t()]

  @callback create_group(
              attrs :: map(),
              group_changeset :: Ecto.Changeset.t(),
              user :: User.t(),
              user_group_map :: map(),
              options :: keyword()
            ) :: {:ok, Group.t()} | {:error, Ecto.Changeset.t() | String.t()}

  @callback create_user_group(attrs :: map(), options :: keyword()) ::
              {:ok, {:ok, UserGroup.t()} | {:error, Ecto.Changeset.t()}} | {:error, term()}

  @callback update_group(group :: Group.t(), attrs :: map(), options :: keyword()) ::
              {:ok, Group.t()} | {:error, Ecto.Changeset.t()}

  @callback update_group_multi(
              group_changeset :: Ecto.Changeset.t(),
              user_group :: UserGroup.t(),
              user_group_attrs :: map(),
              options :: keyword()
            ) :: {:ok, map()} | {:error, atom(), Ecto.Changeset.t() | term(), map()}

  @callback update_user_group(user_group :: UserGroup.t(), attrs :: map(), options :: keyword()) ::
              {:ok, UserGroup.t()} | {:error, Ecto.Changeset.t()}

  @callback update_user_group_role(user_group :: UserGroup.t(), changeset :: Ecto.Changeset.t()) ::
              {:ok, UserGroup.t()} | {:error, Ecto.Changeset.t()}

  @callback delete_group(group :: Group.t()) ::
              {:ok, Group.t()} | {:error, String.t()}

  @callback delete_user_group(user_group :: UserGroup.t()) ::
              {:ok, UserGroup.t()} | {:error, String.t()}

  @callback join_group_confirm(user_group :: UserGroup.t()) ::
              {:ok, UserGroup.t()} | {:error, Ecto.Changeset.t()}

  @callback list_blocked_users(group_id :: String.t()) :: [GroupBlock.t()]
  @callback user_blocked?(group_id :: String.t(), user_id :: String.t()) :: boolean()
  @callback get_group_block(group_id :: String.t(), user_id :: String.t()) :: GroupBlock.t() | nil
  @callback get_group_block!(id :: String.t()) :: GroupBlock.t()

  @callback block_member_multi(actor :: UserGroup.t(), target :: UserGroup.t()) ::
              {:ok, map()} | {:error, atom(), Ecto.Changeset.t() | term(), map()}

  @callback delete_group_block(block :: GroupBlock.t()) ::
              {:ok, GroupBlock.t()} | {:error, Ecto.Changeset.t()}

  @callback validate_owner_count(group_id :: String.t()) ::
              :ok | {:error, :must_have_at_least_one_owner}

  @callback repo_preload(struct_or_structs :: term(), preloads :: term()) :: term()
end
