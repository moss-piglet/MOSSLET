defmodule Mosslet.Bluesky.ImportTask do
  @moduledoc """
  Supervised task for importing posts from Bluesky during an active user session.

  This task runs under a TaskSupervisor (no_link) so the user can navigate
  between LiveViews while the import continues. Progress is broadcast via
  PubSub so any subscribing LiveView can display status.

  ## Privacy Model

  - **Public imports**: Can use background Oban jobs (server keys)
  - **Private/Connections imports**: Must use this task during active session
    because we need the user's session key for encryption

  ## Usage

      # Start an import (typically from BlueskySettingsLive)
      ImportTask.start(account, user, session_key, opts)

      # Subscribe to progress updates in any LiveView
      ImportTask.subscribe(user_id)

  ## PubSub Events

      {:bluesky_import_progress, %{
        status: :started | :importing | :completed | :failed,
        imported: integer(),
        total: integer(),
        current_post: string() | nil,
        error: string() | nil
      }}
  """

  alias Mosslet.Bluesky
  alias Mosslet.Bluesky.Client
  alias Mosslet.Timeline
  alias Mosslet.Encrypted

  require Logger

  @pubsub Mosslet.PubSub

  def topic(user_id), do: "bluesky_import:#{user_id}"

  def subscribe(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, topic(user_id))
  end

  def unsubscribe(user_id) do
    Phoenix.PubSub.unsubscribe(@pubsub, topic(user_id))
  end

  def start(account, user, session_key, opts \\ []) do
    Task.Supervisor.start_child(
      Mosslet.BlueskyImportTaskSupervisor,
      fn -> run_import(account, user, session_key, opts) end,
      restart: :temporary
    )
  end

  defp run_import(account, user, session_key, opts) do
    limit = Keyword.get(opts, :limit, 50)
    full_sync = Keyword.get(opts, :full_sync, false)

    broadcast_progress(user.id, %{status: :started, imported: 0, total: 0})

    cursor = if full_sync, do: nil, else: account.last_cursor

    case fetch_and_import(account, user, session_key, cursor, limit, 0) do
      {:ok, imported_count} ->
        broadcast_progress(user.id, %{
          status: :completed,
          imported: imported_count,
          total: imported_count
        })

        Logger.info(
          "[BlueskyImportTask] Completed import for @#{account.handle}: #{imported_count} posts"
        )

      {:error, reason} ->
        broadcast_progress(user.id, %{status: :failed, error: inspect(reason)})
        Logger.error("[BlueskyImportTask] Failed for @#{account.handle}: #{inspect(reason)}")
    end
  end

  defp fetch_and_import(account, user, session_key, cursor, limit, total_imported) do
    case Client.get_author_feed(account.access_jwt, account.did,
           limit: limit,
           cursor: cursor,
           pds_url: account.pds_url || "https://bsky.social"
         ) do
      {:ok, %{feed: feed, cursor: new_cursor}} ->
        {imported_count, _} = import_batch(feed, account, user, session_key, total_imported)
        new_total = total_imported + imported_count

        Bluesky.update_sync_cursor(account, new_cursor)

        if new_cursor && length(feed) == limit do
          fetch_and_import(account, user, session_key, new_cursor, limit, new_total)
        else
          {:ok, new_total}
        end

      {:ok, %{feed: feed}} ->
        {imported_count, _} = import_batch(feed, account, user, session_key, total_imported)
        {:ok, total_imported + imported_count}

      {:error, {401, _}} ->
        Logger.warning("[BlueskyImportTask] Auth expired, attempting refresh")
        handle_token_refresh(account, user, session_key, cursor, limit, total_imported)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp import_batch(feed, account, user, session_key, current_total) do
    posts_to_import =
      feed
      |> Enum.filter(&is_own_post?(&1, account.did))
      |> Enum.reject(&already_imported?(&1, account.id))

    total_in_batch = length(posts_to_import)

    broadcast_progress(user.id, %{
      status: :importing,
      imported: current_total,
      total: current_total + total_in_batch
    })

    imported =
      posts_to_import
      |> Enum.with_index()
      |> Enum.map(fn {post_data, index} ->
        result = import_single_post(post_data, account, user, session_key)

        broadcast_progress(user.id, %{
          status: :importing,
          imported: current_total + index + 1,
          total: current_total + total_in_batch,
          current_post: get_post_preview(post_data)
        })

        result
      end)
      |> Enum.count(&match?({:ok, _}, &1))

    {imported, total_in_batch}
  end

  defp import_single_post(%{post: post_data}, account, user, session_key) do
    post_key = Encrypted.Utils.generate_key()

    attrs = %{
      "body" => post_data.record.text,
      "username" => account.handle,
      "user_id" => user.id,
      "visibility" => Atom.to_string(account.import_visibility),
      "source" => "bluesky",
      "external_uri" => post_data.uri,
      "external_cid" => post_data.cid,
      "bluesky_account_id" => account.id
    }

    opts = [
      user: user,
      key: session_key,
      trix_key: post_key,
      bluesky_import: true
    ]

    Timeline.create_bluesky_import_post(attrs, opts)
  end

  defp handle_token_refresh(account, user, session_key, cursor, limit, total_imported) do
    case Client.refresh_session(account.refresh_jwt,
           pds_url: account.pds_url || "https://bsky.social"
         ) do
      {:ok, session} ->
        {:ok, updated_account} =
          Bluesky.refresh_tokens(account, %{
            access_jwt: session.access_jwt,
            refresh_jwt: session.refresh_jwt
          })

        fetch_and_import(updated_account, user, session_key, cursor, limit, total_imported)

      {:error, _reason} ->
        {:error, :token_refresh_failed}
    end
  end

  defp is_own_post?(%{post: %{author: %{did: author_did}}}, account_did) do
    author_did == account_did
  end

  defp is_own_post?(_, _), do: false

  defp already_imported?(%{post: %{uri: uri}}, account_id) do
    Timeline.post_exists_by_external_uri?(uri, account_id)
  end

  defp get_post_preview(%{post: %{record: %{text: text}}}) do
    text |> String.slice(0, 50) |> then(&if(String.length(text) > 50, do: &1 <> "...", else: &1))
  end

  defp get_post_preview(_), do: nil

  defp broadcast_progress(user_id, progress) do
    Phoenix.PubSub.broadcast(@pubsub, topic(user_id), {:bluesky_import_progress, progress})
  end
end
