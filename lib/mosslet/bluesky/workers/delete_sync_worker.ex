defmodule Mosslet.Bluesky.Workers.DeleteSyncWorker do
  @moduledoc """
  Oban worker for deleting posts from Bluesky while keeping them on Mosslet.

  This is a key privacy feature - users can remove their content from the
  public Bluesky network while maintaining their encrypted backup on Mosslet.

  The worker handles:
  - Deleting posts from Bluesky via ATP
  - Clearing the external_uri/cid on the Mosslet post
  - Preserving the original post content encrypted on Mosslet
  """
  use Oban.Worker, queue: :bluesky_sync, max_attempts: 3

  alias Mosslet.Bluesky
  alias Mosslet.Bluesky.Client
  alias Mosslet.Timeline

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"external_uri" => external_uri, "account_id" => account_id}}) do
    account = Bluesky.get_account!(account_id)
    do_delete_by_uri(external_uri, account)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"post_id" => post_id, "account_id" => account_id}}) do
    account = Bluesky.get_account!(account_id)
    post = Timeline.get_post!(post_id)

    if post.external_uri && post.bluesky_account_id == account_id do
      do_delete(post, account)
    else
      Logger.info(
        "[BlueskyDelete] Post #{post_id} has no Bluesky URI or doesn't belong to account"
      )

      :ok
    end
  end

  defp do_delete_by_uri(external_uri, account) do
    rkey = Client.extract_rkey(external_uri)

    if rkey do
      case Client.delete_post(
             account.access_jwt,
             account.did,
             rkey,
             pds_url: account.pds_url || "https://bsky.social"
           ) do
        :ok ->
          Logger.info("[BlueskyDelete] Deleted from Bluesky by URI: #{external_uri}")
          :ok

        {:error, {401, _}} ->
          handle_token_refresh_and_retry_by_uri(external_uri, account)

        {:error, {400, %{error: "RecordNotFound"}}} ->
          Logger.info("[BlueskyDelete] Post already deleted from Bluesky: #{external_uri}")
          :ok

        {:error, reason} ->
          Logger.error(
            "[BlueskyDelete] Failed to delete by URI #{external_uri}: #{inspect(reason)}"
          )

          {:error, reason}
      end
    else
      Logger.warning("[BlueskyDelete] Could not extract rkey from URI: #{external_uri}")
      {:error, :invalid_uri}
    end
  end

  defp do_delete(post, account) do
    rkey = Client.extract_rkey(post.external_uri)

    if rkey do
      case Client.delete_post(
             account.access_jwt,
             account.did,
             rkey,
             pds_url: account.pds_url || "https://bsky.social"
           ) do
        :ok ->
          Timeline.clear_bluesky_sync_info(post)
          Logger.info("[BlueskyDelete] Deleted from Bluesky, kept on Mosslet: #{post.id}")
          :ok

        {:error, {401, _}} ->
          handle_token_refresh_and_retry(post, account)

        {:error, {400, %{error: "RecordNotFound"}}} ->
          Timeline.clear_bluesky_sync_info(post)
          Logger.info("[BlueskyDelete] Post already deleted from Bluesky: #{post.id}")
          :ok

        {:error, reason} ->
          Logger.error("[BlueskyDelete] Failed to delete post #{post.id}: #{inspect(reason)}")
          {:error, reason}
      end
    else
      Logger.warning("[BlueskyDelete] Could not extract rkey from URI: #{post.external_uri}")
      {:error, :invalid_uri}
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

        do_delete(post, updated_account)

      {:error, _} ->
        {:error, :token_refresh_failed}
    end
  end

  defp handle_token_refresh_and_retry_by_uri(external_uri, account) do
    case Client.refresh_session(account.refresh_jwt,
           pds_url: account.pds_url || "https://bsky.social"
         ) do
      {:ok, session} ->
        {:ok, updated_account} =
          Bluesky.refresh_tokens(account, %{
            access_jwt: session.access_jwt,
            refresh_jwt: session.refresh_jwt
          })

        do_delete_by_uri(external_uri, updated_account)

      {:error, _} ->
        {:error, :token_refresh_failed}
    end
  end

  def enqueue_delete(post_id, account_id) do
    %{
      "post_id" => post_id,
      "account_id" => account_id
    }
    |> __MODULE__.new()
    |> Oban.insert()
  end

  def enqueue_delete_by_uri(external_uri, account_id) do
    %{
      "external_uri" => external_uri,
      "account_id" => account_id
    }
    |> __MODULE__.new()
    |> Oban.insert()
  end
end
