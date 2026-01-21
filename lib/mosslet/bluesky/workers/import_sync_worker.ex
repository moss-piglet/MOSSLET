defmodule Mosslet.Bluesky.Workers.ImportSyncWorker do
  @moduledoc """
  Oban worker for importing posts from Bluesky to Mosslet with PUBLIC visibility.

  This worker is ONLY used when `import_visibility` is `:public`. For private
  or connections visibility, the `Mosslet.Bluesky.ImportTask` is used instead,
  which runs during the user's active session and has access to their session key.

  ## Content Moderation

  All imported content goes through the same safety pipelines as regular posts:
  - Images: AI detection, private/public moderation, WebP conversion
  - Text: Public moderation (since all posts via this worker are public)

  Posts that fail moderation are skipped, not the entire job.

  Posts are imported with:
  - Full encryption at rest (using server keys for public visibility)
  - Source tracking (source: :bluesky)
  - Original AT URI and CID preserved
  - Visibility set to :public (server-key encrypted)
  """
  use Oban.Worker, queue: :bluesky_sync, max_attempts: 3

  alias Mosslet.Bluesky
  alias Mosslet.Bluesky.Client
  alias Mosslet.Bluesky.ImportProcessor
  alias Mosslet.Timeline
  alias Mosslet.Encrypted

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"account_id" => account_id} = args}) do
    account = Bluesky.get_account!(account_id) |> Mosslet.Repo.Local.preload(:user)
    limit = Map.get(args, "limit", 50)
    full_sync = Map.get(args, "full_sync", false)

    if account.sync_enabled && account.sync_posts_from_bsky do
      Logger.info("[BlueskyImport] Starting import for @#{account.handle}")
      do_import(account, limit, full_sync)
    else
      Logger.info("[BlueskyImport] Sync disabled for @#{account.handle}, skipping")
      :ok
    end
  end

  defp do_import(account, limit, full_sync) do
    cursor = if full_sync, do: nil, else: account.last_cursor

    case Client.get_author_feed(account.access_jwt, account.did,
           limit: limit,
           cursor: cursor,
           pds_url: account.pds_url || "https://bsky.social"
         ) do
      {:ok, %{feed: feed, cursor: new_cursor}} ->
        stats = import_posts(account, feed)
        Bluesky.update_sync_cursor(account, new_cursor)

        Logger.info(
          "[BlueskyImport] Imported #{stats.imported} posts, skipped #{stats.skipped} for @#{account.handle}"
        )

        :ok

      {:ok, %{feed: feed}} ->
        stats = import_posts(account, feed)

        Logger.info(
          "[BlueskyImport] Imported #{stats.imported} posts, skipped #{stats.skipped} for @#{account.handle}"
        )

        :ok

      {:error, {401, _}} ->
        Logger.warning("[BlueskyImport] Auth expired for @#{account.handle}, attempting refresh")
        handle_token_refresh(account, limit, full_sync)

      {:error, reason} ->
        Logger.error("[BlueskyImport] Failed for @#{account.handle}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp import_posts(account, feed) do
    user = account.user

    results =
      feed
      |> Enum.filter(&is_own_post?(&1, account.did))
      |> Enum.reject(&already_imported?(&1, account.id))
      |> Enum.map(&import_single_post(&1, account, user))

    %{
      imported: Enum.count(results, &match?({:ok, _}, &1)),
      skipped: Enum.count(results, &match?({:skipped, _}, &1))
    }
  end

  defp is_own_post?(%{post: %{author: %{did: author_did}}}, account_did) do
    author_did == account_did
  end

  defp is_own_post?(_, _), do: false

  defp already_imported?(%{post: %{uri: uri}}, account_id) do
    Timeline.post_exists_by_external_uri?(uri, account_id)
  end

  defp import_single_post(%{post: post_data}, account, user) do
    post_key = Encrypted.Utils.generate_key()

    case ImportProcessor.process_post(post_data, visibility: :public, post_key: post_key) do
      {:ok, processed} ->
        attrs = %{
          "body" => processed.text,
          "username" => account.handle,
          "user_id" => user.id,
          "visibility" => "public",
          "source" => "bluesky",
          "external_uri" => post_data.uri,
          "external_cid" => post_data.cid,
          "bluesky_account_id" => account.id,
          "image_urls" => processed.image_urls,
          "ai_generated" => processed.ai_generated
        }

        opts = [
          user: user,
          key: :server_key,
          trix_key: post_key,
          bluesky_import: true
        ]

        Timeline.create_bluesky_import_post(attrs, opts)

      {:error, {:text_moderation_failed, reason}} ->
        Logger.info(
          "[BlueskyImport] Skipped post (text moderation): #{post_data.uri} - #{reason}"
        )

        {:skipped, :text_moderation}

      {:error, {:image_moderation_failed, reason}} ->
        Logger.info(
          "[BlueskyImport] Skipped post (image moderation): #{post_data.uri} - #{reason}"
        )

        {:skipped, :image_moderation}

      {:error, reason} ->
        Logger.warning(
          "[BlueskyImport] Failed to process post #{post_data.uri}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp handle_token_refresh(account, limit, full_sync) do
    case Client.refresh_session(account.refresh_jwt,
           pds_url: account.pds_url || "https://bsky.social"
         ) do
      {:ok, session} ->
        {:ok, updated_account} =
          Bluesky.refresh_tokens(account, %{
            access_jwt: session.access_jwt,
            refresh_jwt: session.refresh_jwt
          })

        do_import(updated_account, limit, full_sync)

      {:error, reason} ->
        Logger.error(
          "[BlueskyImport] Token refresh failed for @#{account.handle}: #{inspect(reason)}"
        )

        {:error, :token_refresh_failed}
    end
  end

  def enqueue_import(account_id, opts \\ []) do
    %{
      "account_id" => account_id,
      "limit" => Keyword.get(opts, :limit, 50),
      "full_sync" => Keyword.get(opts, :full_sync, false)
    }
    |> __MODULE__.new()
    |> Oban.insert()
  end

  def enqueue_all_imports do
    Bluesky.list_accounts_for_import()
    |> Enum.each(fn account ->
      enqueue_import(account.id)
    end)
  end
end
