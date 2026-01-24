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
    signing_key = parse_signing_key(account.signing_key)
    do_delete_by_uri(external_uri, account, signing_key)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"post_id" => post_id, "account_id" => account_id}}) do
    account = Bluesky.get_account!(account_id)
    post = Timeline.get_post!(post_id)

    if post.external_uri && post.bluesky_account_id == account_id do
      signing_key = parse_signing_key(account.signing_key)
      do_delete(post, account, signing_key)
    else
      Logger.info(
        "[BlueskyDelete] Post #{post_id} has no Bluesky URI or doesn't belong to account"
      )

      :ok
    end
  end

  defp do_delete_by_uri(external_uri, account, signing_key) do
    rkey = Client.extract_rkey(external_uri)

    if rkey do
      opts = build_delete_opts(account, signing_key)

      case Client.delete_post(account.access_jwt, account.did, rkey, opts) do
        :ok ->
          Logger.info("[BlueskyDelete] Deleted from Bluesky by URI: #{external_uri}")
          :ok

        {:error, {status, %{error: "ExpiredToken"}}} when status in [400, 401] ->
          handle_token_refresh_and_retry_by_uri(external_uri, account, signing_key)

        {:error, {401, _}} ->
          handle_token_refresh_and_retry_by_uri(external_uri, account, signing_key)

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

  defp do_delete(post, account, signing_key) do
    rkey = Client.extract_rkey(post.external_uri)

    if rkey do
      opts = build_delete_opts(account, signing_key)

      case Client.delete_post(account.access_jwt, account.did, rkey, opts) do
        :ok ->
          Timeline.clear_bluesky_sync_info(post)
          Logger.info("[BlueskyDelete] Deleted from Bluesky, kept on Mosslet: #{post.id}")
          :ok

        {:error, {status, %{error: "ExpiredToken"}}} when status in [400, 401] ->
          handle_token_refresh_and_retry(post, account, signing_key)

        {:error, {401, _}} ->
          handle_token_refresh_and_retry(post, account, signing_key)

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

  defp build_delete_opts(account, nil) do
    [pds_url: account.pds_url || "https://bsky.social"]
  end

  defp build_delete_opts(account, signing_key) do
    pds_url = account.pds_url || "https://bsky.social"
    url = "#{pds_url}/xrpc/com.atproto.repo.deleteRecord"
    public_key = derive_public_key(signing_key)

    case Mosslet.Bluesky.OAuth.create_dpop_proof(signing_key, public_key, "POST", url,
           access_token: account.access_jwt
         ) do
      {:ok, proof} ->
        [pds_url: pds_url, dpop_proof: proof, signing_key: signing_key]

      _ ->
        [pds_url: pds_url]
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

  defp refresh_tokens(account, signing_key) do
    if signing_key do
      Client.refresh_oauth_session(account.refresh_jwt, signing_key,
        pds_url: account.pds_url || "https://bsky.social"
      )
    else
      Client.refresh_session(account.refresh_jwt,
        pds_url: account.pds_url || "https://bsky.social"
      )
    end
  end

  defp handle_token_refresh_and_retry(post, account, signing_key) do
    case refresh_tokens(account, signing_key) do
      {:ok, tokens} ->
        {:ok, updated_account} =
          Bluesky.refresh_tokens(account, %{
            access_jwt: tokens[:access_token] || tokens[:access_jwt],
            refresh_jwt: tokens[:refresh_token] || tokens[:refresh_jwt]
          })

        new_signing_key = parse_signing_key(updated_account.signing_key)
        do_delete(post, updated_account, new_signing_key)

      {:error, reason} ->
        Logger.error(
          "[BlueskyDelete] Token refresh failed for @#{account.handle}: #{inspect(reason)}"
        )

        {:error, :token_refresh_failed}
    end
  end

  defp handle_token_refresh_and_retry_by_uri(external_uri, account, signing_key) do
    case refresh_tokens(account, signing_key) do
      {:ok, tokens} ->
        {:ok, updated_account} =
          Bluesky.refresh_tokens(account, %{
            access_jwt: tokens[:access_token] || tokens[:access_jwt],
            refresh_jwt: tokens[:refresh_token] || tokens[:refresh_jwt]
          })

        new_signing_key = parse_signing_key(updated_account.signing_key)
        do_delete_by_uri(external_uri, updated_account, new_signing_key)

      {:error, reason} ->
        Logger.error(
          "[BlueskyDelete] Token refresh failed for @#{account.handle}: #{inspect(reason)}"
        )

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
