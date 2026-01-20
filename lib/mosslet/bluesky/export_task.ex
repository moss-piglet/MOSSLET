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

  ## Usage

      # Start an export (typically from BlueskySettingsLive)
      ExportTask.start(account, user, session_key, opts)

      # Subscribe to progress updates in any LiveView
      ExportTask.subscribe(user_id)

  ## PubSub Events

      {:bluesky_export_progress, %{
        status: :started | :exporting | :completed | :failed,
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

    broadcast_progress(user.id, %{status: :started, exported: 0, total: 0})

    case fetch_and_export(account, user, session_key, batch_size, 0, 0) do
      {:ok, exported_count} ->
        broadcast_progress(user.id, %{
          status: :completed,
          exported: exported_count,
          total: exported_count
        })

        Logger.info(
          "[BlueskyExportTask] Completed export for @#{account.handle}: #{exported_count} posts"
        )

      {:error, reason} ->
        broadcast_progress(user.id, %{status: :failed, error: inspect(reason)})
        Logger.error("[BlueskyExportTask] Failed for @#{account.handle}: #{inspect(reason)}")
    end
  end

  defp fetch_and_export(account, user, session_key, batch_size, offset, total_exported) do
    posts = get_unexported_posts(user.id, batch_size, offset)

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
        fetch_and_export(account, user, session_key, batch_size, offset + batch_size, new_total)
      else
        {:ok, new_total}
      end
    end
  end

  defp get_unexported_posts(user_id, limit, offset) do
    import Ecto.Query

    Mosslet.Timeline.Post
    |> where([p], p.user_id == ^user_id)
    |> where([p], p.source == :mosslet)
    |> where([p], is_nil(p.external_uri))
    |> order_by([p], asc: p.inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Mosslet.Repo.Local.all()
    |> Mosslet.Repo.Local.preload([:user_posts])
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

        case Client.create_post(
               account.access_jwt,
               account.did,
               decrypted_body,
               facets: facets,
               pds_url: account.pds_url || "https://bsky.social"
             ) do
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
