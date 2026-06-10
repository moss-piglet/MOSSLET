defmodule Mosslet.Bluesky do
  @moduledoc """
  Context module for managing Bluesky account integrations.

  Provides CRUD operations for Bluesky accounts and handles
  authentication, token refresh, and sync settings.
  """

  import Ecto.Query, warn: false

  alias Mosslet.Repo
  alias Mosslet.Bluesky.Account
  alias Mosslet.Bluesky.Client

  require Logger

  # Refresh the access token this many seconds before it actually expires,
  # so in-flight requests don't race the expiry boundary.
  @expiry_skew_seconds 120

  # Default access-token lifetime to assume when the OAuth server does not
  # return `expires_in` (Bluesky access tokens are short-lived, ~2 hours).
  @default_token_lifetime_seconds 3600

  # Max time to wait for the per-account refresh lock before giving up.
  @refresh_lock_timeout_ms 15_000

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

  @doc """
  Computes the absolute `access_jwt_expires_at` timestamp from an OAuth
  `expires_in` value (in seconds). Falls back to a conservative default
  lifetime when `expires_in` is missing.
  """
  @spec expires_at_from(integer() | nil) :: DateTime.t()
  def expires_at_from(expires_in) do
    lifetime =
      case expires_in do
        n when is_integer(n) and n > 0 -> n
        _ -> @default_token_lifetime_seconds
      end

    DateTime.utc_now()
    |> DateTime.add(lifetime, :second)
    |> DateTime.truncate(:second)
  end

  @doc """
  Returns true when the account's access token is expired (or close enough to
  expiry that it should be refreshed proactively).

  Accounts without a recorded expiry are treated as expired so they get
  refreshed once and start tracking expiry going forward.
  """
  @spec token_expired?(Account.t()) :: boolean()
  def token_expired?(%Account{access_jwt_expires_at: nil}), do: true

  def token_expired?(%Account{access_jwt_expires_at: expires_at}) do
    threshold = DateTime.add(DateTime.utc_now(), @expiry_skew_seconds, :second)
    DateTime.compare(expires_at, threshold) != :gt
  end

  @doc """
  Ensures the account has a valid (non-expired) access token, refreshing it
  lazily if needed, and returns the up-to-date account.

  Refreshes are serialized per-account across the cluster via a global lock so
  that concurrent sync jobs (import + export) never double-spend the single-use,
  rotating OAuth refresh token. The refresh is also idempotent under contention:
  once the lock is held, the account is re-read and re-checked so only one
  refresh actually happens per expiry window.

  Returns `{:ok, account}` with fresh tokens, or `{:error, reason}` if a refresh
  was required but failed. On refresh failure the previously stored tokens are
  left untouched (never clobbered).

  ## Options

    * `:force` - refresh even if the current token looks valid (default: false)
  """
  @spec with_valid_session(Account.t(), keyword()) :: {:ok, Account.t()} | {:error, term()}
  def with_valid_session(%Account{} = account, opts \\ []) do
    force? = Keyword.get(opts, :force, false)

    if force? or token_expired?(account) do
      refresh_under_lock(account, force?)
    else
      {:ok, account}
    end
  end

  defp refresh_under_lock(%Account{id: account_id} = account, force?) do
    lock_id = {{:bluesky_token_refresh, account_id}, self()}
    nodes = [node() | Node.list()]

    case :global.trans(
           lock_id,
           fn -> do_locked_refresh(account, force?) end,
           nodes,
           lock_retries()
         ) do
      :aborted ->
        Logger.warning(
          "[Bluesky] Could not acquire refresh lock for account #{account_id}, using current token"
        )

        {:ok, account}

      result ->
        result
    end
  end

  # Re-read the account inside the lock so we observe any refresh another job
  # just committed; only refresh if it is still needed. We merge fresh token
  # fields back onto the caller's struct so its preloaded associations (e.g.
  # `:user`) are preserved.
  defp do_locked_refresh(%Account{id: account_id} = account, force?) do
    current = Repo.get!(Account, account_id)

    if not force? and not token_expired?(current) do
      {:ok, merge_token_fields(account, current)}
    else
      case perform_refresh(current) do
        {:ok, refreshed} -> {:ok, merge_token_fields(account, refreshed)}
        {:error, _} = error -> error
      end
    end
  end

  defp merge_token_fields(target, source) do
    %{
      target
      | access_jwt: source.access_jwt,
        refresh_jwt: source.refresh_jwt,
        access_jwt_expires_at: source.access_jwt_expires_at
    }
  end

  defp perform_refresh(%Account{} = account) do
    signing_key = parse_signing_key(account.signing_key)
    pds_url = account.pds_url || "https://bsky.social"

    result =
      if signing_key do
        Client.refresh_oauth_session(account.refresh_jwt, signing_key, pds_url: pds_url)
      else
        Client.refresh_session(account.refresh_jwt, pds_url: pds_url)
      end

    case result do
      {:ok, tokens} ->
        refresh_tokens(account, %{
          access_jwt: tokens[:access_token] || tokens[:access_jwt],
          refresh_jwt: tokens[:refresh_token] || tokens[:refresh_jwt],
          access_jwt_expires_at: expires_at_from(tokens[:expires_in])
        })

      {:error, reason} ->
        Logger.error(
          "[Bluesky] Token refresh failed for account #{account.id}: #{inspect(reason)}"
        )

        {:error, {:token_refresh_failed, reason}}
    end
  end

  defp parse_signing_key(nil), do: nil

  defp parse_signing_key(signing_key_json) do
    case Jason.decode(signing_key_json) do
      {:ok, key} -> key
      _ -> nil
    end
  end

  # Rough number of lock retries to approximate @refresh_lock_timeout_ms.
  # :global.trans sleeps a random backoff (~0-1000ms) between retries.
  defp lock_retries, do: div(@refresh_lock_timeout_ms, 500)
end
