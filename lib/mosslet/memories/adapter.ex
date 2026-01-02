defmodule Mosslet.Memories.Adapter do
  @moduledoc """
  Behaviour defining the interface for platform-specific memory operations.

  This enables the same context API to work across web (direct Repo access)
  and native (API + cache) platforms.

  ## Implementation

  Web adapter (`Mosslet.Memories.Adapters.Web`):
  - Direct Postgres access via `Mosslet.Repo`
  - Uses `Fly.Repo.transaction_on_primary/1` for writes

  Native adapter (`Mosslet.Memories.Adapters.Native`):
  - HTTP API calls to cloud server via `Mosslet.API.Client`
  - Local SQLite cache via `Mosslet.Cache`
  - Offline fallback to cached data

  ## Pattern

  Following the same pattern as other adapters:
  - Business logic stays in the context (`Mosslet.Memories`)
  - Adapters handle data access (database vs API)

  Note: Memories is a legacy feature being phased out. This adapter
  implementation provides platform support during the transition period.
  """

  alias Mosslet.Memories.{Memory, Remark, UserMemory}
  alias Mosslet.Accounts.User
  alias Mosslet.Groups.Group

  @callback get_memory!(id :: binary()) :: Memory.t()
  @callback get_memory(id :: binary() | :new | String.t()) :: Memory.t() | nil

  @callback memory_count(user :: User.t()) :: non_neg_integer()
  @callback shared_with_user_memory_count(user :: User.t()) :: non_neg_integer()
  @callback timeline_memory_count(current_user :: User.t()) :: non_neg_integer()
  @callback shared_between_users_memory_count(
              user_id :: binary(),
              current_user_id :: binary()
            ) :: non_neg_integer()
  @callback public_memory_count(user :: User.t()) :: non_neg_integer()
  @callback group_memory_count(group :: Group.t()) :: non_neg_integer()
  @callback remark_count(memory :: Memory.t()) :: non_neg_integer()
  @callback get_total_storage(user :: User.t()) :: non_neg_integer()
  @callback count_all_memories() :: non_neg_integer()

  @callback get_remarks_loved_count(memory :: Memory.t()) :: non_neg_integer()
  @callback get_remarks_excited_count(memory :: Memory.t()) :: non_neg_integer()
  @callback get_remarks_happy_count(memory :: Memory.t()) :: non_neg_integer()
  @callback get_remarks_sad_count(memory :: Memory.t()) :: non_neg_integer()
  @callback get_remarks_thumbsy_count(memory :: Memory.t()) :: non_neg_integer()

  @callback preload(memory :: Memory.t()) :: Memory.t()

  @callback list_memories(user :: User.t(), options :: map()) :: [Memory.t()]
  @callback filter_timeline_memories(current_user :: User.t(), options :: map()) :: [Memory.t()]
  @callback filter_memories_shared_with_current_user(user_id :: binary(), options :: map()) :: [
              Memory.t()
            ]
  @callback list_public_memories(user :: User.t(), options :: map()) :: [Memory.t()]
  @callback list_group_memories(group :: Group.t(), options :: map()) :: [Memory.t()]
  @callback list_remarks(memory :: Memory.t(), options :: map()) :: [Remark.t()]

  @callback get_remark!(id :: binary()) :: Remark.t()
  @callback get_remark(id :: binary()) :: Remark.t() | nil

  @callback create_memory_multi(
              changeset :: Ecto.Changeset.t(),
              user :: User.t(),
              p_attrs :: map(),
              visibility :: String.t()
            ) ::
              {:ok, Memory.t()} | {:error, Ecto.Changeset.t() | String.t()}

  @callback create_shared_user_memory(
              memory :: Memory.t(),
              user :: User.t(),
              p_attrs :: map(),
              visibility :: String.t()
            ) :: {:ok, any()} | {:error, any()}

  @callback update_memory_multi(
              changeset :: Ecto.Changeset.t(),
              memory :: Memory.t(),
              user :: User.t(),
              p_attrs :: map()
            ) ::
              {:ok, Memory.t()} | {:error, Ecto.Changeset.t() | String.t()}

  @callback blur_memory_multi(changeset :: Ecto.Changeset.t(), opts :: keyword()) ::
              {:ok, Memory.t()} | {:error, Ecto.Changeset.t() | String.t()}

  @callback create_remark(changeset :: Ecto.Changeset.t()) ::
              {:ok, Remark.t()} | {:error, Ecto.Changeset.t()}

  @callback delete_remark(remark :: Remark.t()) ::
              {:ok, Remark.t()} | {:error, Ecto.Changeset.t()}

  @callback update_memory_fav(changeset :: Ecto.Changeset.t()) ::
              {:ok, Memory.t()} | {:error, Ecto.Changeset.t()}

  @callback inc_favs(memory :: Memory.t()) :: {:ok, Memory.t()}
  @callback decr_favs(memory :: Memory.t()) :: {:ok, Memory.t()}

  @callback delete_memory(memory :: Memory.t()) ::
              {:ok, Memory.t()} | {:error, Ecto.Changeset.t()}

  @callback last_ten_remarks_for(memory_id :: binary()) :: [Remark.t()]
  @callback last_user_remark_for_memory(memory_id :: binary(), user_id :: binary()) ::
              Remark.t() | nil
  @callback get_previous_n_remarks(date :: any(), memory_id :: binary(), n :: pos_integer()) :: [
              Remark.t()
            ]
  @callback preload_remark_user(remark :: Remark.t()) :: Remark.t()

  @callback get_public_user_memory(memory :: Memory.t()) :: UserMemory.t() | nil
  @callback get_user_memory(memory :: Memory.t(), user :: User.t()) :: UserMemory.t() | nil
end
