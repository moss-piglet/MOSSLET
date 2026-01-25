defmodule Mosslet.Bluesky.Workers.ExportSyncWorker do
  @moduledoc """
  Oban worker for exporting public Mosslet posts and replies to Bluesky.

  This worker syncs a user's public Mosslet posts to their connected
  Bluesky account, allowing them to maintain a presence on the open
  social web while keeping Mosslet as their privacy-first home base.

  Only posts meeting these criteria are exported:
  - visibility: :public
  - source: :mosslet (not already from Bluesky)
  - Not already synced to Bluesky

  Replies to Bluesky posts are also exported with proper reply threading.
  """
  use Oban.Worker, queue: :bluesky_sync, max_attempts: 3

  alias Mosslet.Bluesky
  alias Mosslet.Bluesky.Client
  alias Mosslet.Extensions.URLPreviewServer
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

  def perform(%Oban.Job{args: %{"reply_id" => reply_id, "account_id" => account_id}}) do
    account = Bluesky.get_account!(account_id) |> Mosslet.Repo.preload(:user)

    if account.sync_enabled && account.sync_posts_to_bsky do
      case Timeline.get_reply_for_export(reply_id) do
        nil ->
          Logger.warning("[BlueskyExport] Reply #{reply_id} not found or not exportable")
          :ok

        reply ->
          export_single_reply(reply, account)
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
    signing_key = parse_signing_key(account.signing_key)

    Logger.info(
      "[BlueskyExport] Attempting export for @#{account.handle}, did: #{account.did}, has_signing_key: #{signing_key != nil}"
    )

    {export_text, facets} = prepare_post_for_export(decrypted_body, post.id)

    pds_url = account.pds_url || "https://bsky.social"
    embed = build_external_embed(export_text, account, signing_key, pds_url)

    opts =
      [
        facets: facets,
        pds_url: pds_url
      ]
      |> maybe_put_embed(embed)
      |> maybe_add_dpop_proof(account, signing_key)

    case Client.create_post(account.access_jwt, account.did, export_text, opts) do
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

  @bluesky_max_graphemes 300

  defp prepare_post_for_export(text, post_id) do
    grapheme_count = String.graphemes(text) |> length()

    if grapheme_count <= @bluesky_max_graphemes do
      Client.parse_facets(text)
    else
      truncate_with_link(text, post_id)
    end
  end

  defp truncate_with_link(text, _post_id) do
    host = Application.get_env(:mosslet, :canonical_host) || "mosslet.com"
    scheme = if String.contains?(host, "localhost"), do: "http", else: "https"
    url = "#{scheme}://#{host}/discover"

    suffix = "\n\n📖 #{url}"
    suffix_graphemes = String.graphemes(suffix) |> length()
    available = @bluesky_max_graphemes - suffix_graphemes - 1

    truncated =
      text
      |> String.graphemes()
      |> Enum.take(available)
      |> Enum.join()
      |> String.trim_trailing()

    final_text = truncated <> "…" <> suffix

    {_text, facets} = Client.parse_facets(final_text)
    {final_text, facets}
  end

  defp export_single_post_no_refresh(post, account) do
    decrypted_body = decrypt_post_body(post, account.user)
    signing_key = parse_signing_key(account.signing_key)

    {export_text, facets} = prepare_post_for_export(decrypted_body, post.id)

    pds_url = account.pds_url || "https://bsky.social"
    embed = build_external_embed(export_text, account, signing_key, pds_url)

    opts =
      [
        facets: facets,
        pds_url: pds_url
      ]
      |> maybe_put_embed(embed)
      |> maybe_add_dpop_proof(account, signing_key)

    case Client.create_post(account.access_jwt, account.did, export_text, opts) do
      {:ok, %{uri: uri, cid: cid}} ->
        Timeline.mark_post_as_synced_to_bluesky(post, uri, cid)
        Logger.debug("[BlueskyExport] Exported post #{post.id} -> #{uri}")
        :ok

      {:error, reason} ->
        Logger.error("[BlueskyExport] Failed to export post #{post.id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp export_single_reply(reply, account) do
    reply = Mosslet.Repo.preload(reply, [:post, :parent_reply])
    decrypted_body = decrypt_reply_body(reply, account.user)
    signing_key = parse_signing_key(account.signing_key)

    Logger.info(
      "[BlueskyExport] Attempting reply export for @#{account.handle}, reply_id: #{reply.id}"
    )

    {export_text, facets} = prepare_reply_for_export(decrypted_body, reply.id)

    pds_url = account.pds_url || "https://bsky.social"

    reply_ref = build_reply_reference(reply)

    if reply_ref do
      opts =
        [
          facets: facets,
          pds_url: pds_url,
          reply: reply_ref
        ]
        |> maybe_add_dpop_proof(account, signing_key)

      case Client.create_post(account.access_jwt, account.did, export_text, opts) do
        {:ok, %{uri: uri, cid: cid}} ->
          Timeline.mark_reply_as_synced_to_bluesky(reply, uri, cid, reply_ref)
          Logger.debug("[BlueskyExport] Exported reply #{reply.id} -> #{uri}")
          :ok

        {:error, {status, %{error: "ExpiredToken"}}} when status in [400, 401] ->
          Logger.warning("[BlueskyExport] Auth expired for reply, will retry")
          handle_reply_token_refresh_and_retry(reply, account, signing_key)

        {:error, {401, _}} ->
          Logger.warning("[BlueskyExport] Auth expired for reply, will retry")
          handle_reply_token_refresh_and_retry(reply, account, signing_key)

        {:error, reason} ->
          Logger.error("[BlueskyExport] Failed to export reply #{reply.id}: #{inspect(reason)}")
          {:error, reason}
      end
    else
      Logger.warning(
        "[BlueskyExport] Cannot export reply #{reply.id} - parent post has no Bluesky URI"
      )

      {:error, :no_parent_uri}
    end
  end

  defp build_reply_reference(reply) do
    post = reply.post
    parent_reply = reply.parent_reply

    root_uri = post.external_uri
    root_cid = post.external_cid

    {parent_uri, parent_cid} =
      if parent_reply && parent_reply.external_uri do
        {parent_reply.external_uri, parent_reply.external_cid}
      else
        {root_uri, root_cid}
      end

    if root_uri && root_cid && parent_uri && parent_cid do
      %{
        "root" => %{"uri" => root_uri, "cid" => root_cid},
        "parent" => %{"uri" => parent_uri, "cid" => parent_cid}
      }
    else
      nil
    end
  end

  defp decrypt_reply_body(reply, user) do
    case Timeline.decrypt_reply_body(reply, user, :server_key) do
      {:ok, body} -> body
      _ -> reply.body
    end
  end

  defp prepare_reply_for_export(text, reply_id) do
    grapheme_count = String.graphemes(text) |> length()

    if grapheme_count <= @bluesky_max_graphemes do
      Client.parse_facets(text)
    else
      truncate_reply_with_link(text, reply_id)
    end
  end

  defp truncate_reply_with_link(text, _reply_id) do
    host = Application.get_env(:mosslet, :canonical_host) || "mosslet.com"
    scheme = if String.contains?(host, "localhost"), do: "http", else: "https"
    url = "#{scheme}://#{host}/discover"

    suffix = "\n\n📖 #{url}"
    suffix_graphemes = String.graphemes(suffix) |> length()
    available = @bluesky_max_graphemes - suffix_graphemes - 1

    truncated =
      text
      |> String.graphemes()
      |> Enum.take(available)
      |> Enum.join()
      |> String.trim_trailing()

    final_text = truncated <> "…" <> suffix

    {_text, facets} = Client.parse_facets(final_text)
    {final_text, facets}
  end

  defp handle_reply_token_refresh_and_retry(reply, account, signing_key) do
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

        export_single_reply(reply, updated_account)

      {:error, reason} ->
        Logger.error(
          "[BlueskyExport] Token refresh failed for reply @#{account.handle}: #{inspect(reason)}"
        )

        {:error, :token_refresh_failed}
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

  defp maybe_put_embed(opts, nil), do: opts
  defp maybe_put_embed(opts, embed), do: Keyword.put(opts, :embed, embed)

  defp build_external_embed(text, account, signing_key, pds_url) do
    case extract_first_url(text) do
      nil ->
        nil

      url ->
        case fetch_url_metadata(url) do
          {:ok, metadata} ->
            build_embed_with_metadata(metadata, account, signing_key, pds_url)

          {:error, reason} ->
            Logger.debug("[BlueskyExport] Failed to fetch URL metadata: #{inspect(reason)}")
            nil
        end
    end
  end

  defp extract_first_url(text) do
    regex = ~r/https?:\/\/[^\s<>\[\]]+/

    case Regex.run(regex, text) do
      [url | _] -> clean_url(url)
      _ -> nil
    end
  end

  defp clean_url(url) do
    url
    |> String.trim_trailing(".")
    |> String.trim_trailing(",")
    |> String.trim_trailing(";")
    |> String.trim_trailing(":")
    |> String.trim_trailing("!")
    |> String.trim_trailing("?")
    |> String.trim_trailing(")")
  end

  defp fetch_url_metadata(url) do
    case URLPreviewServer.fetch(url) do
      {:ok, preview} ->
        {:ok,
         %{
           url: preview["url"] || url,
           title: preview["title"] || "",
           description: preview["description"] || "",
           image_url: preview["original_image_url"] || get_image_url_from_preview(preview)
         }}

      {:error, _} = error ->
        error
    end
  end

  defp get_image_url_from_preview(%{"image" => image}) when is_binary(image) do
    if String.starts_with?(image, "data:") do
      nil
    else
      image
    end
  end

  defp get_image_url_from_preview(_), do: nil

  defp build_embed_with_metadata(metadata, account, signing_key, pds_url) do
    thumb = maybe_upload_thumb(metadata.image_url, account, signing_key, pds_url)

    external = %{
      "uri" => metadata.url,
      "title" => String.slice(metadata.title || "", 0, 300),
      "description" => String.slice(metadata.description || "", 0, 1000)
    }

    external =
      if thumb do
        Map.put(external, "thumb", thumb)
      else
        external
      end

    %{
      "$type" => "app.bsky.embed.external",
      "external" => external
    }
  end

  defp maybe_upload_thumb(nil, _account, _signing_key, _pds_url), do: nil
  defp maybe_upload_thumb("", _account, _signing_key, _pds_url), do: nil

  defp maybe_upload_thumb(image_url, account, signing_key, pds_url) do
    case fetch_and_resize_image(image_url) do
      {:ok, image_data, content_type} ->
        upload_opts =
          [pds_url: pds_url]
          |> maybe_add_dpop_proof_for_upload(account, signing_key, pds_url)

        case Client.upload_blob(account.access_jwt, image_data, content_type, upload_opts) do
          {:ok, %{blob: blob}} ->
            blob

          {:error, reason} ->
            Logger.debug("[BlueskyExport] Failed to upload thumb: #{inspect(reason)}")
            nil
        end

      {:error, reason} ->
        Logger.debug("[BlueskyExport] Failed to fetch/resize image: #{inspect(reason)}")
        nil
    end
  end

  defp fetch_and_resize_image(url) do
    case Req.get(url,
           max_redirects: 5,
           receive_timeout: 15_000,
           headers: [
             {"user-agent",
              "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"},
             {"accept", "image/*"}
           ]
         ) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        resize_image_for_bluesky(body)

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @max_thumb_size 976_560

  defp resize_image_for_bluesky(image_data) do
    case Image.from_binary(image_data) do
      {:ok, image} ->
        {:ok, resized} =
          Image.thumbnail(image, "800x800",
            resize: :down,
            crop: :none
          )

        case Image.write(resized, :memory, suffix: ".jpeg", quality: 90) do
          {:ok, jpeg_data} ->
            if byte_size(jpeg_data) <= @max_thumb_size do
              {:ok, jpeg_data, "image/jpeg"}
            else
              {:ok, compressed} =
                Image.write(resized, :memory, suffix: ".jpeg", quality: 60)

              {:ok, compressed, "image/jpeg"}
            end

          error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

  defp maybe_add_dpop_proof_for_upload(opts, _account, nil, _pds_url), do: opts

  defp maybe_add_dpop_proof_for_upload(opts, account, signing_key, pds_url) do
    public_key = derive_public_key(signing_key)
    url = "#{pds_url}/xrpc/com.atproto.repo.uploadBlob"

    case Mosslet.Bluesky.OAuth.create_dpop_proof(signing_key, public_key, "POST", url,
           access_token: account.access_jwt
         ) do
      {:ok, proof} -> Keyword.merge(opts, dpop_proof: proof, signing_key: signing_key)
      _ -> opts
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

  def enqueue_single_reply_export(reply_id, account_id) do
    %{
      "reply_id" => reply_id,
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
