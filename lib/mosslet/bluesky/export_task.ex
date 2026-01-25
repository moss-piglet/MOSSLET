defmodule Mosslet.Bluesky.ExportTask do
  @moduledoc """
  Supervised task for exporting posts to Bluesky during an active user session.

  This task runs under a TaskSupervisor (no_link) so the user can navigate
  between LiveViews while the export continues. Progress is broadcast via
  PubSub so any subscribing LiveView can display status.

  ## Privacy Model

  - **Public visibility posts**: Can use background Oban jobs (server keys)
  - **Private/Connections posts**: Must use this task during active session
    because we need the user's session key for decryption

  ## Likes and Bookmarks Sync

  When `sync_likes` is enabled on the account:
  - Syncs user's Mosslet likes (favs) to Bluesky for posts that have external URIs
  - Syncs user's Mosslet bookmarks to Bluesky saved posts for posts with external URIs

  ## Usage

      # Start an export (typically from BlueskySettingsLive)
      ExportTask.start(account, user, session_key, opts)

      # Subscribe to progress updates in any LiveView
      ExportTask.subscribe(user_id)

  ## PubSub Events

      {:bluesky_export_progress, %{
        status: :started | :exporting | :syncing_likes | :syncing_bookmarks | :completed | :failed,
        exported: integer(),
        total: integer(),
        current_post: string() | nil,
        error: string() | nil
      }}
  """

  alias Mosslet.Bluesky.Client
  alias Mosslet.Timeline

  require Logger

  @pubsub Mosslet.PubSub

  def topic(user_id), do: "bluesky_export:#{user_id}"

  def subscribe(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, topic(user_id))
  end

  def unsubscribe(user_id) do
    Phoenix.PubSub.unsubscribe(@pubsub, topic(user_id))
  end

  def start(account, user, session_key, opts \\ []) do
    Task.Supervisor.start_child(
      Mosslet.BlueskyImportTaskSupervisor,
      fn -> run_export(account, user, session_key, opts) end,
      restart: :temporary
    )
  end

  defp run_export(account, user, session_key, opts) do
    batch_size = Keyword.get(opts, :batch_size, 20)
    force_resync = Keyword.get(opts, :force_resync, false)
    public_only = Keyword.get(opts, :public_only, false)

    broadcast_progress(user.id, %{status: :started, exported: 0, total: 0})

    with :ok <- maybe_clear_deleted_posts(account, user, force_resync, public_only),
         {:ok, exported_count} <-
           fetch_and_export(account, user, session_key, batch_size, 0, 0, public_only),
         {:ok, account} <- maybe_sync_likes_to_bluesky(account, user, session_key, public_only),
         {:ok, _account} <-
           maybe_sync_bookmarks_to_bluesky(account, user, session_key, public_only) do
      broadcast_progress(user.id, %{
        status: :completed,
        exported: exported_count,
        total: exported_count
      })

      Logger.info(
        "[BlueskyExportTask] Completed export for @#{account.handle}: #{exported_count} posts"
      )
    else
      {:error, reason} ->
        broadcast_progress(user.id, %{status: :failed, error: inspect(reason)})
        Logger.error("[BlueskyExportTask] Failed for @#{account.handle}: #{inspect(reason)}")
    end
  end

  defp maybe_sync_likes_to_bluesky(account, user, session_key, public_only) do
    if account.sync_likes and not public_only do
      broadcast_progress(user.id, %{status: :syncing_likes, exported: 0, total: 0})
      sync_likes_to_bluesky(account, user, session_key)
    else
      {:ok, account}
    end
  end

  defp maybe_clear_deleted_posts(_account, _user, false, _public_only), do: :ok

  defp maybe_clear_deleted_posts(account, user, true, public_only) do
    broadcast_progress(user.id, %{status: :checking_deleted, exported: 0, total: 0})

    signing_key = parse_signing_key(account.signing_key)
    exported_posts = get_exported_posts(user.id, public_only)
    total = length(exported_posts)

    Logger.info("[BlueskyExportTask] Checking #{total} posts for deletion on Bluesky")

    cleared_count =
      exported_posts
      |> Enum.with_index(1)
      |> Enum.reduce(0, fn {post, index}, cleared ->
        broadcast_progress(user.id, %{
          status: :checking_deleted,
          exported: index,
          total: total
        })

        opts = build_request_opts(account, signing_key)

        case Client.post_exists?(account.access_jwt, post.external_uri, opts) do
          {:ok, false} ->
            Logger.info(
              "[BlueskyExportTask] Post #{post.id} deleted from Bluesky, clearing sync info"
            )

            Timeline.clear_bluesky_sync_info(post)
            cleared + 1

          {:ok, true} ->
            cleared

          {:error, reason} ->
            Logger.warning(
              "[BlueskyExportTask] Failed to check post #{post.id}: #{inspect(reason)}"
            )

            cleared
        end
      end)

    Logger.info("[BlueskyExportTask] Cleared sync info for #{cleared_count} deleted posts")
    :ok
  end

  defp get_exported_posts(user_id, public_only) do
    import Ecto.Query

    query =
      Mosslet.Timeline.Post
      |> where([p], p.user_id == ^user_id)
      |> where([p], p.source == :mosslet)
      |> where([p], not is_nil(p.external_uri))
      |> order_by([p], asc: p.inserted_at)

    query =
      if public_only do
        where(query, [p], p.visibility == :public)
      else
        query
      end

    Mosslet.Repo.all(query)
  end

  defp maybe_sync_bookmarks_to_bluesky(account, user, _session_key, public_only) do
    if account.sync_likes and not public_only do
      broadcast_progress(user.id, %{status: :syncing_bookmarks, exported: 0, total: 0})
      sync_bookmarks_to_bluesky(account, user)
    else
      {:ok, account}
    end
  end

  defp sync_likes_to_bluesky(account, user, session_key) do
    signing_key = parse_signing_key(account.signing_key)
    liked_posts = get_liked_bluesky_posts(user, session_key)

    Enum.each(liked_posts, fn post ->
      if post.external_uri && post.external_cid do
        opts = build_request_opts(account, signing_key)

        case Client.find_like_for_post(account.access_jwt, account.did, post.external_uri, opts) do
          {:ok, nil} ->
            case Client.create_like(
                   account.access_jwt,
                   account.did,
                   post.external_uri,
                   post.external_cid,
                   opts
                 ) do
              {:ok, _} ->
                Logger.debug("[BlueskyExportTask] Created like for post #{post.id}")

              {:error, reason} ->
                Logger.warning("[BlueskyExportTask] Failed to create like: #{inspect(reason)}")
            end

          {:ok, _like} ->
            :already_liked

          {:error, reason} ->
            Logger.warning("[BlueskyExportTask] Failed to check like: #{inspect(reason)}")
        end
      end
    end)

    Logger.info("[BlueskyExportTask] Synced #{length(liked_posts)} likes for @#{account.handle}")
    {:ok, account}
  end

  defp sync_bookmarks_to_bluesky(account, user) do
    signing_key = parse_signing_key(account.signing_key)
    bookmarked_posts = get_bookmarked_bluesky_posts(user)

    opts = build_request_opts(account, signing_key)

    case Client.get_saved_post_uris(account.access_jwt, opts) do
      {:ok, existing_saved_uris} ->
        Enum.each(bookmarked_posts, fn post ->
          if post.external_uri && post.external_uri not in existing_saved_uris do
            case Client.save_post(account.access_jwt, post.external_uri, opts) do
              {:ok, _} ->
                Logger.debug("[BlueskyExportTask] Saved post #{post.id} to Bluesky")

              {:error, reason} ->
                Logger.warning("[BlueskyExportTask] Failed to save post: #{inspect(reason)}")
            end
          end
        end)

        Logger.info(
          "[BlueskyExportTask] Synced #{length(bookmarked_posts)} bookmarks for @#{account.handle}"
        )

        {:ok, account}

      {:error, reason} ->
        Logger.warning("[BlueskyExportTask] Failed to get saved posts: #{inspect(reason)}")
        {:ok, account}
    end
  end

  defp get_liked_bluesky_posts(user, session_key) do
    import Ecto.Query

    Mosslet.Timeline.Post
    |> where([p], p.source == :bluesky)
    |> where([p], not is_nil(p.external_uri))
    |> where([p], not is_nil(p.external_cid))
    |> Mosslet.Repo.all()
    |> Mosslet.Repo.preload([:user_posts])
    |> Enum.filter(fn post ->
      favs_list = decrypt_favs_list(post, user, session_key)
      user.id in (favs_list || [])
    end)
  end

  defp get_bookmarked_bluesky_posts(user) do
    import Ecto.Query

    Mosslet.Timeline.Bookmark
    |> where([b], b.user_id == ^user.id)
    |> join(:inner, [b], p in Mosslet.Timeline.Post, on: b.post_id == p.id)
    |> where([b, p], p.source == :bluesky)
    |> where([b, p], not is_nil(p.external_uri))
    |> select([b, p], p)
    |> Mosslet.Repo.all()
  end

  defp decrypt_favs_list(post, user, session_key) do
    case Timeline.decrypt_post_body(post, user, session_key) do
      {:ok, _} ->
        post.favs_list

      _ ->
        []
    end
  rescue
    _ -> []
  end

  defp build_request_opts(account, signing_key) do
    pds_url = account.pds_url || "https://bsky.social"

    opts = [pds_url: pds_url]

    if signing_key do
      public_key = derive_public_key(signing_key)

      case Mosslet.Bluesky.OAuth.create_dpop_proof(
             signing_key,
             public_key,
             "POST",
             "#{pds_url}/xrpc/com.atproto.repo.createRecord",
             access_token: account.access_jwt
           ) do
        {:ok, proof} ->
          Keyword.merge(opts, dpop_proof: proof, signing_key: signing_key)

        _ ->
          opts
      end
    else
      opts
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

  defp fetch_and_export(
         account,
         user,
         session_key,
         batch_size,
         offset,
         total_exported,
         public_only
       ) do
    posts = get_unexported_posts(user.id, batch_size, offset, public_only)

    if Enum.empty?(posts) do
      {:ok, total_exported}
    else
      total_in_batch = length(posts)

      broadcast_progress(user.id, %{
        status: :exporting,
        exported: total_exported,
        total: total_exported + total_in_batch
      })

      {exported_count, continue?} =
        export_batch(posts, account, user, session_key, total_exported, total_in_batch)

      new_total = total_exported + exported_count

      if continue? && exported_count > 0 do
        fetch_and_export(
          account,
          user,
          session_key,
          batch_size,
          offset + batch_size,
          new_total,
          public_only
        )
      else
        {:ok, new_total}
      end
    end
  end

  defp get_unexported_posts(user_id, limit, offset, public_only) do
    import Ecto.Query

    query =
      Mosslet.Timeline.Post
      |> where([p], p.user_id == ^user_id)
      |> where([p], p.source == :mosslet)
      |> where([p], is_nil(p.external_uri))
      |> order_by([p], asc: p.inserted_at)
      |> limit(^limit)
      |> offset(^offset)

    query =
      if public_only do
        where(query, [p], p.visibility == :public)
      else
        query
      end

    query
    |> Mosslet.Repo.all()
    |> Mosslet.Repo.preload([:user_posts])
  end

  defp export_batch(posts, account, user, session_key, current_total, total_in_batch) do
    results =
      posts
      |> Enum.with_index()
      |> Enum.map(fn {post, index} ->
        result = export_single_post(post, account, user, session_key)

        broadcast_progress(user.id, %{
          status: :exporting,
          exported: current_total + index + 1,
          total: current_total + total_in_batch,
          current_post: get_post_preview(post, user, session_key)
        })

        result
      end)

    exported = Enum.count(results, &match?(:ok, &1))
    failed = Enum.count(results, &match?({:error, _}, &1))

    {exported, failed < total_in_batch}
  end

  defp export_single_post(post, account, user, session_key) do
    case decrypt_post_body(post, user, session_key) do
      {:ok, decrypted_body} ->
        {_text, facets} = Client.parse_facets(decrypted_body)
        pds_url = account.pds_url || "https://bsky.social"

        embed = build_images_embed(post, account, user, session_key, pds_url)

        opts =
          [facets: facets, pds_url: pds_url]
          |> maybe_add_embed(embed)

        case Client.create_post(account.access_jwt, account.did, decrypted_body, opts) do
          {:ok, %{uri: uri, cid: cid}} ->
            Timeline.mark_post_as_synced_to_bluesky(post, uri, cid)
            Logger.debug("[BlueskyExportTask] Exported post #{post.id} -> #{uri}")
            :ok

          {:error, {401, _}} ->
            Logger.warning("[BlueskyExportTask] Auth expired for post #{post.id}")
            {:error, :auth_expired}

          {:error, reason} ->
            Logger.error(
              "[BlueskyExportTask] Failed to export post #{post.id}: #{inspect(reason)}"
            )

            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("[BlueskyExportTask] Failed to decrypt post #{post.id}: #{inspect(reason)}")
        {:error, :decrypt_failed}
    end
  end

  defp maybe_add_embed(opts, nil), do: opts
  defp maybe_add_embed(opts, embed), do: Keyword.put(opts, :embed, embed)

  defp build_images_embed(post, account, user, session_key, pds_url) do
    case decrypt_post_image_urls(post, user, session_key) do
      {:ok, urls} when urls != [] ->
        alt_texts = decrypt_post_image_alt_texts(post, user, session_key)

        uploaded_images =
          urls
          |> Enum.with_index()
          |> Enum.take(4)
          |> Enum.map(fn {url, index} ->
            alt_text = Enum.at(alt_texts, index, "")
            upload_image_to_bluesky(url, alt_text, account, pds_url)
          end)
          |> Enum.filter(&match?({:ok, _, _}, &1))
          |> Enum.map(fn {:ok, blob, alt} -> %{"alt" => alt, "image" => blob} end)

        if Enum.empty?(uploaded_images) do
          nil
        else
          %{"$type" => "app.bsky.embed.images", "images" => uploaded_images}
        end

      _ ->
        nil
    end
  end

  defp decrypt_post_image_alt_texts(post, user, session_key) do
    alt_texts = post.image_alt_texts || []

    if is_list(alt_texts) && !Enum.empty?(alt_texts) do
      case get_post_key_for_export(post, user, session_key) do
        {:ok, post_key} ->
          Enum.map(alt_texts, fn encrypted_alt ->
            case Mosslet.Encrypted.Utils.decrypt(%{key: post_key, payload: encrypted_alt}) do
              {:ok, alt} -> alt
              _ -> ""
            end
          end)

        _ ->
          []
      end
    else
      []
    end
  end

  defp decrypt_post_image_urls(post, user, session_key) do
    image_urls = post.image_urls || []

    if is_list(image_urls) && !Enum.empty?(image_urls) do
      case get_post_key_for_export(post, user, session_key) do
        {:ok, post_key} ->
          decrypted =
            Enum.map(image_urls, fn encrypted_url ->
              case Mosslet.Encrypted.Utils.decrypt(%{key: post_key, payload: encrypted_url}) do
                {:ok, url} -> url
                _ -> nil
              end
            end)
            |> Enum.filter(&is_binary/1)

          {:ok, decrypted}

        _ ->
          {:ok, []}
      end
    else
      {:ok, []}
    end
  end

  defp get_post_key_for_export(post, user, key) do
    user_post = Enum.find(post.user_posts, &(&1.user_id == user.id))

    if user_post do
      case post.visibility do
        :public ->
          {:ok, Mosslet.Encrypted.Users.Utils.decrypt_public_item_key(user_post.key)}

        _ ->
          Mosslet.Encrypted.Users.Utils.decrypt_user_attrs_key(user_post.key, user, key)
      end
    else
      {:error, :no_user_post}
    end
  end

  defp upload_image_to_bluesky(image_url, alt_text, account, pds_url) do
    with {:ok, image_data, content_type} <- download_image(image_url),
         {:ok, %{blob: blob}} <-
           Client.upload_blob(account.access_jwt, image_data, content_type, pds_url: pds_url) do
      {:ok, blob, alt_text}
    else
      error ->
        Logger.warning("[BlueskyExportTask] Failed to upload image: #{inspect(error)}")
        error
    end
  end

  defp download_image(url) do
    case Req.get(url, decode_body: false) do
      {:ok, %{status: 200, body: body, headers: headers}} ->
        content_type = get_content_type(headers)
        {:ok, body, content_type}

      {:ok, %{status: status}} ->
        {:error, {:download_failed, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_content_type(headers) when is_map(headers) do
    case Map.get(headers, "content-type") do
      [ct | _] -> parse_content_type(ct)
      ct when is_binary(ct) -> parse_content_type(ct)
      _ -> "image/jpeg"
    end
  end

  defp get_content_type(headers) when is_list(headers) do
    case List.keyfind(headers, "content-type", 0) do
      {_, ct} -> parse_content_type(ct)
      nil -> "image/jpeg"
    end
  end

  defp get_content_type(_), do: "image/jpeg"

  defp parse_content_type(ct) when is_binary(ct) do
    ct |> String.split(";") |> List.first() |> String.trim()
  end

  defp decrypt_post_body(post, user, session_key) do
    Timeline.decrypt_post_body(post, user, session_key)
  end

  defp get_post_preview(post, user, session_key) do
    case decrypt_post_body(post, user, session_key) do
      {:ok, body} ->
        body
        |> String.slice(0, 50)
        |> then(&if(String.length(body) > 50, do: &1 <> "...", else: &1))

      _ ->
        nil
    end
  end

  defp broadcast_progress(user_id, progress) do
    Phoenix.PubSub.broadcast(@pubsub, topic(user_id), {:bluesky_export_progress, progress})
  end
end
