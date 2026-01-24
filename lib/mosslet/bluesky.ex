defmodule Mosslet.Bluesky do
  @moduledoc """
  Context module for managing Bluesky account integrations.

  Provides CRUD operations for Bluesky accounts and handles
  authentication, token refresh, and sync settings.
  """

  import Ecto.Query, warn: false

  alias Mosslet.Repo
  alias Mosslet.Bluesky.Account

  @doc """
  Gets a user's Bluesky account, if connected.
  """
  def get_account_for_user(user_id) do
    Repo.get_by(Account, user_id: user_id)
  end

  @doc """
  Gets a Bluesky account by ID.
  """
  def get_account!(id) do
    Repo.get!(Account, id)
  end

  @doc """
  Gets a Bluesky account by DID hash.
  """
  def get_account_by_did(did) do
    Repo.get_by(Account, did_hash: String.downcase(did))
  end

  @doc """
  Gets a Bluesky account by handle hash.
  """
  def get_account_by_handle(handle) do
    Repo.get_by(Account, handle_hash: String.downcase(handle))
  end

  @doc """
  Creates a new Bluesky account connection for a user.
  """
  def create_account(user, attrs) do
    Repo.transaction_on_primary(fn ->
      %Account{user_id: user.id}
      |> Account.create_changeset(attrs)
      |> Repo.insert!()
    end)
  end

  @doc """
  Updates a Bluesky account.
  """
  def update_account(%Account{} = account, attrs) do
    Repo.transaction_on_primary(fn ->
      account
      |> Account.changeset(attrs)
      |> Repo.update!()
    end)
  end

  @doc """
  Updates sync settings for a Bluesky account.
  """
  def update_sync_settings(%Account{} = account, attrs) do
    Repo.transaction_on_primary(fn ->
      account
      |> Account.sync_settings_changeset(attrs)
      |> Repo.update!()
    end)
  end

  @doc """
  Refreshes the access and refresh tokens for a Bluesky account.
  """
  def refresh_tokens(%Account{} = account, attrs) do
    Repo.transaction_on_primary(fn ->
      account
      |> Account.refresh_tokens_changeset(attrs)
      |> Repo.update!()
    end)
  end

  @doc """
  Updates the sync cursor after a successful sync operation.
  """
  def update_sync_cursor(%Account{} = account, cursor) do
    Repo.transaction_on_primary(fn ->
      account
      |> Account.sync_cursor_changeset(%{
        last_synced_at: DateTime.utc_now(),
        last_cursor: cursor
      })
      |> Repo.update!()
    end)
  end

  @doc """
  Updates the likes sync cursor after a successful likes sync operation.
  """
  def update_likes_cursor(%Account{} = account, cursor) do
    Repo.transaction_on_primary(fn ->
      account
      |> Account.sync_likes_cursor_changeset(%{last_likes_cursor: cursor})
      |> Repo.update!()
    end)
  end

  @doc """
  Disconnects/deletes a user's Bluesky account.
  """
  def delete_account(%Account{} = account) do
    Repo.transaction_on_primary(fn ->
      Repo.delete!(account)
    end)
  end

  @doc """
  Returns a changeset for tracking account changes.
  """
  def change_account(%Account{} = account, attrs \\ %{}) do
    Account.changeset(account, attrs)
  end

  @doc """
  Checks if a user has a connected Bluesky account.
  """
  def has_bluesky_account?(user_id) do
    query = from a in Account, where: a.user_id == ^user_id, select: count(a.id)
    Repo.one(query) > 0
  end

  @doc """
  Lists all accounts that have sync enabled (for background sync jobs).
  """
  def list_sync_enabled_accounts do
    query =
      from a in Account,
        where: a.sync_enabled == true,
        preload: [:user]

    Repo.all(query)
  end

  @doc """
  Lists accounts that need to sync posts FROM Bluesky.
  """
  def list_accounts_for_import do
    query =
      from a in Account,
        where: a.sync_enabled == true and a.sync_posts_from_bsky == true,
        preload: [:user]

    Repo.all(query)
  end

  @doc """
  Lists accounts that need to sync posts TO Bluesky.
  """
  def list_accounts_for_export do
    query =
      from a in Account,
        where: a.sync_enabled == true and a.sync_posts_to_bsky == true,
        preload: [:user]

    Repo.all(query)
  end
end
