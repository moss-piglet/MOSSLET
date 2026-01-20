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
  def perform(%Oban.Job{args: %{"account_id" => account_id} = args}) do
    account = Bluesky.get_account!(account_id) |> Mosslet.Repo.Local.preload(:user)
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
    account = Bluesky.get_account!(account_id) |> Mosslet.Repo.Local.preload(:user)

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

    exported_count =
      posts
      |> Enum.map(&export_single_post(&1, account))
      |> Enum.count(&match?(:ok, &1))

    Logger.info("[BlueskyExport] Exported #{exported_count} posts for @#{account.handle}")
    :ok
  end

  defp export_single_post(post, account) do
    decrypted_body = decrypt_post_body(post, account.user)

    {_text, facets} = Client.parse_facets(decrypted_body)

    case Client.create_post(
           account.access_jwt,
           account.did,
           decrypted_body,
           facets: facets,
           pds_url: account.pds_url || "https://bsky.social"
         ) do
      {:ok, %{uri: uri, cid: cid}} ->
        Timeline.mark_post_as_synced_to_bluesky(post, uri, cid)
        Logger.debug("[BlueskyExport] Exported post #{post.id} -> #{uri}")
        :ok

      {:error, {401, _}} ->
        Logger.warning("[BlueskyExport] Auth expired, will retry")
        handle_token_refresh_and_retry(post, account)

      {:error, reason} ->
        Logger.error("[BlueskyExport] Failed to export post #{post.id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp decrypt_post_body(post, user) do
    key = get_user_key(user)

    case Timeline.decrypt_post_body(post, user, key) do
      {:ok, body} -> body
      _ -> post.body
    end
  end

  defp handle_token_refresh_and_retry(post, account) do
    case Client.refresh_session(account.refresh_jwt,
           pds_url: account.pds_url || "https://bsky.social"
         ) do
      {:ok, session} ->
        {:ok, updated_account} =
          Bluesky.refresh_tokens(account, %{
            access_jwt: session.access_jwt,
            refresh_jwt: session.refresh_jwt
          })

        export_single_post(post, updated_account)

      {:error, _} ->
        {:error, :token_refresh_failed}
    end
  end

  defp get_user_key(_user) do
    nil
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
