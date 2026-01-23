defmodule Mosslet.Bluesky.Workers.ExportSyncWorker do
  @moduledoc """
  Oban worker for exporting public Mosslet posts to Bluesky.

  This worker syncs a user's public Mosslet posts to their connected
  Bluesky account, allowing them to maintain a presence on the open
  social web while keeping Mosslet as their privacy-first home base.

  Only posts meeting these criteria are exported:
  - visibility: :public
  - source: :mosslet (not already from Bluesky)
  - Not already synced to Bluesky
  """
  use Oban.Worker, queue: :bluesky_sync, max_attempts: 3

  alias Mosslet.Bluesky
  alias Mosslet.Bluesky.Client
  alias Mosslet.Timeline

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "sync_all"}}) do
    Logger.info("[BlueskyExport] Running scheduled sync for all accounts")
    enqueue_all_exports()
    :ok
  end

  def perform(%Oban.Job{args: %{"account_id" => account_id} = args}) do
    account = Bluesky.get_account!(account_id) |> Mosslet.Repo.preload(:user)
    limit = Map.get(args, "limit", 10)

    if account.sync_enabled && account.sync_posts_to_bsky do
      Logger.info("[BlueskyExport] Starting export for @#{account.handle}")
      do_export(account, limit)
    else
      Logger.info("[BlueskyExport] Sync disabled for @#{account.handle}, skipping")
      :ok
    end
  end

  def perform(%Oban.Job{args: %{"post_id" => post_id, "account_id" => account_id}}) do
    account = Bluesky.get_account!(account_id) |> Mosslet.Repo.preload(:user)

    if account.sync_enabled && account.sync_posts_to_bsky do
      case Timeline.get_post_for_export(post_id) do
        nil ->
          Logger.warning("[BlueskyExport] Post #{post_id} not found or not exportable")
          :ok

        post ->
          export_single_post(post, account)
      end
    else
      :ok
    end
  end

  defp do_export(account, limit) do
    user = account.user
    posts = Timeline.get_unexported_public_posts(user.id, limit)

    if posts == [] do
      Logger.info("[BlueskyExport] No posts to export for @#{account.handle}")
      :ok
    else
      case ensure_fresh_tokens(account) do
        {:ok, fresh_account} ->
          exported_count =
            posts
            |> Enum.reduce(0, fn post, count ->
              case export_single_post_no_refresh(post, fresh_account) do
                :ok -> count + 1
                _ -> count
              end
            end)

          Logger.info("[BlueskyExport] Exported #{exported_count} posts for @#{account.handle}")
          :ok

        {:error, reason} ->
          Logger.error(
            "[BlueskyExport] Token refresh failed for @#{account.handle}: #{inspect(reason)}"
          )

          {:error, :token_refresh_failed}
      end
    end
  end

  defp export_single_post(post, account) do
    decrypted_body = decrypt_post_body(post, account.user)

    {_text, facets} = Client.parse_facets(decrypted_body)
    signing_key = parse_signing_key(account.signing_key)

    opts =
      [
        facets: facets,
        pds_url: account.pds_url || "https://bsky.social"
      ]
      |> maybe_add_dpop_proof(account, signing_key)

    case Client.create_post(account.access_jwt, account.did, decrypted_body, opts) do
      {:ok, %{uri: uri, cid: cid}} ->
        Timeline.mark_post_as_synced_to_bluesky(post, uri, cid)
        Logger.debug("[BlueskyExport] Exported post #{post.id} -> #{uri}")
        :ok

      {:error, {status, %{error: "ExpiredToken"}}} when status in [400, 401] ->
        Logger.warning("[BlueskyExport] Auth expired, will retry")
        handle_token_refresh_and_retry(post, account, signing_key)

      {:error, {401, _}} ->
        Logger.warning("[BlueskyExport] Auth expired, will retry")
        handle_token_refresh_and_retry(post, account, signing_key)

      {:error, reason} ->
        Logger.error("[BlueskyExport] Failed to export post #{post.id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp maybe_add_dpop_proof(opts, _account, nil), do: opts

  defp maybe_add_dpop_proof(opts, account, signing_key) do
    public_key = derive_public_key(signing_key)
    pds_url = account.pds_url || "https://bsky.social"
    url = "#{pds_url}/xrpc/com.atproto.repo.createRecord"

    case Mosslet.Bluesky.OAuth.create_dpop_proof(signing_key, public_key, "POST", url,
           access_token: account.access_jwt
         ) do
      {:ok, proof} -> Keyword.merge(opts, dpop_proof: proof, signing_key: signing_key)
      _ -> opts
    end
  end

  defp derive_public_key(%{"kty" => "EC", "crv" => crv, "x" => x, "y" => y}) do
    %{"kty" => "EC", "crv" => crv, "x" => x, "y" => y}
  end

  defp parse_signing_key(nil), do: nil

  defp parse_signing_key(signing_key_json) do
    case Jason.decode(signing_key_json) do
      {:ok, key} -> key
      _ -> nil
    end
  end

  defp decrypt_post_body(post, user) do
    case Timeline.decrypt_post_body(post, user, :server_key) do
      {:ok, body} -> body
      _ -> post.body
    end
  end

  defp export_single_post_no_refresh(post, account) do
    decrypted_body = decrypt_post_body(post, account.user)
    {_text, facets} = Client.parse_facets(decrypted_body)
    signing_key = parse_signing_key(account.signing_key)

    opts =
      [
        facets: facets,
        pds_url: account.pds_url || "https://bsky.social"
      ]
      |> maybe_add_dpop_proof(account, signing_key)

    case Client.create_post(account.access_jwt, account.did, decrypted_body, opts) do
      {:ok, %{uri: uri, cid: cid}} ->
        Timeline.mark_post_as_synced_to_bluesky(post, uri, cid)
        Logger.debug("[BlueskyExport] Exported post #{post.id} -> #{uri}")
        :ok

      {:error, reason} ->
        Logger.error("[BlueskyExport] Failed to export post #{post.id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp ensure_fresh_tokens(account) do
    signing_key = parse_signing_key(account.signing_key)

    result =
      if signing_key do
        Client.refresh_oauth_session(account.refresh_jwt, signing_key,
          pds_url: account.pds_url || "https://bsky.social"
        )
      else
        Client.refresh_session(account.refresh_jwt,
          pds_url: account.pds_url || "https://bsky.social"
        )
      end

    case result do
      {:ok, tokens} ->
        Bluesky.refresh_tokens(account, %{
          access_jwt: tokens.access_token || tokens.access_jwt,
          refresh_jwt: tokens.refresh_token || tokens.refresh_jwt
        })

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_token_refresh_and_retry(post, account, signing_key) do
    result =
      if signing_key do
        Client.refresh_oauth_session(account.refresh_jwt, signing_key,
          pds_url: account.pds_url || "https://bsky.social"
        )
      else
        Client.refresh_session(account.refresh_jwt,
          pds_url: account.pds_url || "https://bsky.social"
        )
      end

    case result do
      {:ok, tokens} ->
        {:ok, updated_account} =
          Bluesky.refresh_tokens(account, %{
            access_jwt: tokens.access_token || tokens.access_jwt,
            refresh_jwt: tokens.refresh_token || tokens.refresh_jwt
          })

        export_single_post(post, updated_account)

      {:error, reason} ->
        Logger.error(
          "[BlueskyExport] Token refresh failed for @#{account.handle}: #{inspect(reason)}"
        )

        {:error, :token_refresh_failed}
    end
  end

  def enqueue_export(account_id, opts \\ []) do
    %{
      "account_id" => account_id,
      "limit" => Keyword.get(opts, :limit, 10)
    }
    |> __MODULE__.new()
    |> Oban.insert()
  end

  def enqueue_single_post_export(post_id, account_id) do
    %{
      "post_id" => post_id,
      "account_id" => account_id
    }
    |> __MODULE__.new()
    |> Oban.insert()
  end

  def enqueue_all_exports do
    Bluesky.list_accounts_for_export()
    |> Enum.each(fn account ->
      enqueue_export(account.id)
    end)
  end
end
