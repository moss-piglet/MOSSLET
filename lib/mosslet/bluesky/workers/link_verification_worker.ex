defmodule Mosslet.Bluesky.Workers.LinkVerificationWorker do
  @moduledoc """
  Oban worker for verifying Bluesky link status on synced posts.

  This worker checks if posts that were synced to Bluesky still exist there.
  If a post has been deleted from Bluesky, it clears the external_uri/cid
  so the Bluesky badge is no longer shown.

  This is a privacy-first, non-invasive cleanup operation:
  - Does NOT re-export any posts
  - Only clears sync metadata for deleted posts
  - Rate-limited to avoid API abuse
  - Runs in low-priority background queue
  """
  use Oban.Worker, queue: :bluesky_sync, max_attempts: 2, priority: 3

  alias Mosslet.Bluesky
  alias Mosslet.Bluesky.Client
  alias Mosslet.Timeline

  require Logger

  @batch_size 20
  @delay_between_checks_ms 500

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"account_id" => account_id}}) do
    account = Bluesky.get_account!(account_id)

    if account.sync_enabled do
      Logger.info("[BlueskyLinkVerify] Starting verification for @#{account.handle}")
      do_verification(account)
    else
      Logger.info("[BlueskyLinkVerify] Sync disabled for @#{account.handle}, skipping")
      :ok
    end
  end

  defp do_verification(account) do
    case ensure_fresh_tokens(account) do
      {:ok, fresh_account} ->
        posts = get_synced_posts(fresh_account.user_id)
        total = length(posts)

        Logger.info("[BlueskyLinkVerify] Checking #{total} posts for @#{account.handle}")

        {cleared, checked} =
          posts
          |> Enum.reduce({0, 0}, fn post, {cleared_count, checked_count} ->
            Process.sleep(@delay_between_checks_ms)

            case check_and_clear_if_deleted(post, fresh_account) do
              :cleared -> {cleared_count + 1, checked_count + 1}
              :exists -> {cleared_count, checked_count + 1}
              :error -> {cleared_count, checked_count + 1}
            end
          end)

        Logger.info(
          "[BlueskyLinkVerify] Completed for @#{account.handle}: #{cleared} cleared of #{checked} checked"
        )

        :ok

      {:error, reason} ->
        Logger.error(
          "[BlueskyLinkVerify] Token refresh failed for @#{account.handle}: #{inspect(reason)}"
        )

        {:error, :token_refresh_failed}
    end
  end

  defp check_and_clear_if_deleted(post, account) do
    signing_key = parse_signing_key(account.signing_key)
    pds_url = account.pds_url || "https://bsky.social"

    opts =
      [pds_url: pds_url]
      |> maybe_add_dpop_opts(account, signing_key, pds_url)

    case Client.post_exists?(account.access_jwt, post.external_uri, opts) do
      {:ok, false} ->
        Logger.info(
          "[BlueskyLinkVerify] Post #{post.id} deleted from Bluesky, marking as unverified"
        )

        Timeline.mark_bluesky_link_unverified(post)
        :cleared

      {:ok, true} ->
        if post.bluesky_link_verified == false do
          Timeline.mark_bluesky_link_verified(post)
        end

        :exists

      {:error, reason} ->
        Logger.warning("[BlueskyLinkVerify] Failed to check post #{post.id}: #{inspect(reason)}")
        :error
    end
  end

  defp get_synced_posts(user_id) do
    import Ecto.Query

    Mosslet.Timeline.Post
    |> where([p], p.user_id == ^user_id)
    |> where([p], not is_nil(p.external_uri))
    |> order_by([p], asc: p.inserted_at)
    |> limit(@batch_size)
    |> Mosslet.Repo.all()
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

  defp parse_signing_key(nil), do: nil

  defp parse_signing_key(signing_key_json) do
    case Jason.decode(signing_key_json) do
      {:ok, key} -> key
      _ -> nil
    end
  end

  defp maybe_add_dpop_opts(opts, _account, nil, _pds_url), do: opts

  defp maybe_add_dpop_opts(opts, account, signing_key, pds_url) do
    public_key = derive_public_key(signing_key)
    url = "#{pds_url}/xrpc/com.atproto.repo.getRecord"

    case Mosslet.Bluesky.OAuth.create_dpop_proof(signing_key, public_key, "GET", url,
           access_token: account.access_jwt
         ) do
      {:ok, proof} -> Keyword.merge(opts, dpop_proof: proof, signing_key: signing_key)
      _ -> opts
    end
  end

  defp derive_public_key(%{"kty" => "EC", "crv" => crv, "x" => x, "y" => y}) do
    %{"kty" => "EC", "crv" => crv, "x" => x, "y" => y}
  end

  @doc """
  Enqueue a link verification job for the given account.
  """
  def enqueue_verification(account_id) do
    %{"account_id" => account_id}
    |> __MODULE__.new()
    |> Oban.insert()
  end
end
