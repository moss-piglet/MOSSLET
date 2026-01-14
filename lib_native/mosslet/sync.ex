defmodule Mosslet.Sync do
  @moduledoc """
  Manages synchronization between local cache and cloud server.

  This GenServer handles:
  - Periodic polling for updates from the server
  - Processing the sync queue (pending local changes)
  - Online/offline detection with exponential backoff
  - Broadcasting sync status changes via PubSub

  ## Usage

  The Sync process is started automatically for native desktop/mobile apps.
  Subscribe to sync status updates:

      Phoenix.PubSub.subscribe(Mosslet.PubSub, "sync:status")

  Manually trigger a sync:

      Mosslet.Sync.sync_now()

  Check current status:

      Mosslet.Sync.status()
      # => %{online: true, syncing: false, last_sync: ~U[...], pending_count: 2}
  """

  use GenServer

  require Logger

  alias Mosslet.API.Client
  alias Mosslet.Cache
  alias Mosslet.Sync.ConflictResolver

  @sync_interval :timer.minutes(5)
  @retry_interval :timer.seconds(30)
  @max_retry_interval :timer.minutes(10)
  @health_check_interval :timer.seconds(10)

  defstruct [
    :token,
    :user_id,
    :last_sync,
    online: false,
    syncing: false,
    retry_count: 0,
    pending_count: 0
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def status do
    GenServer.call(__MODULE__, :status)
  end

  def sync_now do
    GenServer.cast(__MODULE__, :sync_now)
  end

  def set_credentials(token, user_id) do
    GenServer.cast(__MODULE__, {:set_credentials, token, user_id})
  end

  def clear_credentials do
    GenServer.cast(__MODULE__, :clear_credentials)
  end

  def online? do
    GenServer.call(__MODULE__, :online?)
  end

  @doc """
  Subscribe to sync status updates for LiveViews.

  Returns `{:ok, status_map}` if the Sync GenServer is running (native apps),
  or `{:error, :not_running}` for web deployments.

  ## Usage in LiveView

      def mount(_params, _session, socket) do
        sync_status =
          if connected?(socket) do
            case Mosslet.Sync.subscribe_and_get_status() do
              {:ok, status} -> status
              {:error, :not_running} -> nil
            end
          else
            nil
          end

        {:ok, assign(socket, sync_status: sync_status)}
      end

      def handle_info({:sync_status, status}, socket) do
        {:noreply, assign(socket, sync_status: status)}
      end
  """
  def subscribe_and_get_status do
    if running?() do
      Phoenix.PubSub.subscribe(Mosslet.PubSub, "sync:status")
      {:ok, status()}
    else
      {:error, :not_running}
    end
  end

  @doc """
  Check if the Sync GenServer is running.

  Returns `true` for native apps, `false` for web deployments.
  """
  def running? do
    case Process.whereis(__MODULE__) do
      nil -> false
      _pid -> true
    end
  end

  @impl true
  def init(_opts) do
    schedule_health_check()
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      online: state.online,
      syncing: state.syncing,
      last_sync: state.last_sync,
      pending_count: state.pending_count
    }

    {:reply, status, state}
  end

  def handle_call(:online?, _from, state) do
    {:reply, state.online, state}
  end

  @impl true
  def handle_cast(:sync_now, state) do
    if state.token && !state.syncing do
      send(self(), :sync)
    end

    {:noreply, state}
  end

  def handle_cast({:set_credentials, token, user_id}, state) do
    new_state = %{state | token: token, user_id: user_id}
    send(self(), :sync)
    {:noreply, new_state}
  end

  def handle_cast(:clear_credentials, state) do
    {:noreply, %{state | token: nil, user_id: nil, last_sync: nil}}
  end

  @impl true
  def handle_info(:health_check, state) do
    new_state = check_connectivity(state)
    schedule_health_check()
    {:noreply, new_state}
  end

  def handle_info(:sync, %{token: nil} = state) do
    {:noreply, state}
  end

  def handle_info(:sync, %{syncing: true} = state) do
    {:noreply, state}
  end

  def handle_info(:sync, state) do
    state = %{state | syncing: true}
    broadcast_status(state)

    case do_sync(state) do
      {:ok, new_state} ->
        new_state = %{
          new_state
          | syncing: false,
            online: true,
            retry_count: 0,
            last_sync: DateTime.utc_now()
        }

        broadcast_status(new_state)
        schedule_sync()
        {:noreply, new_state}

      {:error, :offline, new_state} ->
        new_state = %{new_state | syncing: false, online: false}
        broadcast_status(new_state)
        schedule_retry(new_state.retry_count)
        {:noreply, %{new_state | retry_count: new_state.retry_count + 1}}

      {:error, _reason, new_state} ->
        new_state = %{new_state | syncing: false}
        broadcast_status(new_state)
        schedule_retry(new_state.retry_count)
        {:noreply, %{new_state | retry_count: new_state.retry_count + 1}}
    end
  end

  defp do_sync(state) do
    with {:ok, state} <- push_pending_changes(state),
         {:ok, state} <- pull_updates(state) do
      cleanup_old_sync_items()
      {:ok, state}
    end
  end

  defp push_pending_changes(state) do
    pending_items = Cache.get_pending_sync_items(limit: 50)
    failed_items = Cache.get_failed_sync_items(3)

    all_items = pending_items ++ failed_items
    state = %{state | pending_count: length(all_items)}

    Enum.reduce_while(all_items, {:ok, state}, fn item, {:ok, acc_state} ->
      case sync_item(item, acc_state.token) do
        :ok ->
          {:cont, {:ok, %{acc_state | pending_count: acc_state.pending_count - 1}}}

        {:error, :offline} ->
          {:halt, {:error, :offline, acc_state}}

        {:error, reason} ->
          Logger.warning("Sync item #{item.id} failed: #{inspect(reason)}")
          {:cont, {:ok, acc_state}}
      end
    end)
  end

  defp sync_item(item, token) do
    {:ok, _} = Cache.mark_syncing(item)

    result =
      case item.action do
        "create" -> sync_create(item, token)
        "update" -> sync_update(item, token)
        "delete" -> sync_delete(item, token)
      end

    case result do
      {:ok, server_response} ->
        ConflictResolver.resolve(item, server_response)
        {:ok, _} = Cache.mark_synced(item)
        :ok

      {:error, {status, _body}} when status in [408, 502, 503, 504] ->
        {:ok, _} = Cache.mark_sync_failed(item, "Server unavailable: #{status}")
        {:error, :offline}

      {:error, %{reason: reason}} when reason in [:timeout, :econnrefused, :nxdomain] ->
        {:ok, _} = Cache.mark_sync_failed(item, "Network error: #{reason}")
        {:error, :offline}

      {:error, {status, body}} ->
        error_msg = "HTTP #{status}: #{inspect(body)}"
        {:ok, _} = Cache.mark_sync_failed(item, error_msg)
        {:error, {:server_error, status}}

      {:error, reason} ->
        {:ok, _} = Cache.mark_sync_failed(item, inspect(reason))
        {:error, reason}
    end
  end

  defp sync_create(item, token) do
    payload = decode_payload(item.payload)

    case item.resource_type do
      "post" -> Client.create_post(token, payload)
      "reply" -> Client.create_reply(token, payload)
      "user_connection" -> Client.create_connection(token, payload)
      "group" -> Client.create_group(token, payload)
      "user_group" -> Client.create_user_group(token, payload)
      "group_message" -> Client.create_group_message(token, payload)
      "memory" -> Client.create_memory(token, payload)
      "remark" -> Client.create_remark(token, payload)
      "conversation" -> Client.create_conversation(token, payload)
      _ -> {:error, {:unknown_resource_type, item.resource_type}}
    end
  end

  defp sync_update(item, token) do
    payload = decode_payload(item.payload)

    case {item.resource_type, item.action} do
      {"post", _} ->
        Client.update_post(token, item.resource_id, payload)

      {"reply", _} ->
        Client.update_reply(token, item.resource_id, payload)

      {"reply", "mark_read_for_post"} ->
        Client.mark_replies_read_for_post(token, payload["post_id"], payload["user_id"])

      {"reply", "mark_all_read"} ->
        Client.mark_all_replies_read_for_user(token, payload["user_id"])

      {"reply", "mark_nested_read"} ->
        Client.mark_nested_replies_read_for_parent(token, payload["parent_id"], payload["user_id"])

      {"receipt", "mark_read"} ->
        Client.mark_post_as_read(token, payload["post_id"], payload["user_id"])

      {"user_connection", "update"} ->
        Client.update_connection(token, item.resource_id, payload)

      {"user_connection", "update_label"} ->
        Client.update_connection_label(token, item.resource_id, payload["label"], payload["label_hash"])

      {"user_connection", "update_zen"} ->
        Client.update_connection_zen(token, item.resource_id, payload["zen"])

      {"user_connection", "update_photos"} ->
        Client.update_connection_photos(token, item.resource_id, payload["photos"])

      {"user", "update_name"} ->
        Client.update_user_name(token, payload)

      {"user", "update_username"} ->
        Client.update_user_username(token, payload)

      {"user", "update_visibility"} ->
        Client.update_user_visibility(token, payload["visibility"])

      {"user", "update_onboarding"} ->
        Client.update_user_onboarding(token, payload)

      {"user", "update_onboarding_profile"} ->
        Client.update_user_onboarding_profile(token, payload)

      {"user", "update_notifications"} ->
        Client.update_user_notifications(token, payload["enabled"])

      {"user", "update_tokens"} ->
        Client.update_user_tokens(token, payload["tokens"])

      {"user", "create_visibility_group"} ->
        Client.create_visibility_group(token, payload)

      {"user", "update_visibility_group"} ->
        Client.update_visibility_group(token, payload["id"], payload)

      {"group", _} ->
        Client.update_group(token, item.resource_id, payload)

      {"user_group", _} ->
        Client.update_user_group(token, item.resource_id, payload)

      {"group_message", _} ->
        Client.update_group_message(token, item.resource_id, payload)

      {"memory", _} ->
        Client.update_memory(token, item.resource_id, payload)

      {"conversation", _} ->
        Client.update_conversation(token, item.resource_id, payload)

      {"message", _} ->
        conversation_id = payload["conversation_id"]
        Client.update_message(token, conversation_id, item.resource_id, payload)

      {"org", _} ->
        Client.update_org(token, item.resource_id, payload)

      {"status", "update"} ->
        Client.update_user_status(token, payload)

      _ ->
        {:error, {:unknown_resource_type, item.resource_type, item.action}}
    end
  end

  defp sync_delete(item, token) do
    payload = decode_payload(item.payload)

    case item.resource_type do
      "post" -> Client.delete_post(token, item.resource_id)
      "reply" -> Client.delete_reply(token, item.resource_id)
      "user_connection" -> Client.delete_connection(token, item.resource_id)
      "group" -> Client.delete_group(token, item.resource_id)
      "user_group" -> Client.delete_user_group(token, item.resource_id)
      "group_message" -> Client.delete_group_message(token, item.resource_id)
      "memory" -> Client.delete_memory(token, item.resource_id)
      "remark" -> Client.delete_remark(token, item.resource_id)
      "conversation" -> Client.delete_conversation(token, item.resource_id)
      "message" -> Client.delete_message(token, payload["conversation_id"], item.resource_id)
      _ -> {:error, {:unknown_resource_type, item.resource_type}}
    end
  end

  defp decode_payload(payload) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, decoded} -> decoded
      {:error, _} -> %{payload: payload}
    end
  end

  defp decode_payload(payload), do: payload

  defp pull_updates(state) do
    since = state.last_sync || parse_last_sync_setting()

    case Client.full_sync(state.token, since: since) do
      {:ok, sync_data} ->
        cache_sync_data(sync_data)
        if synced_at = sync_data[:synced_at], do: Cache.set_setting("last_sync", synced_at)
        {:ok, state}

      {:error, {status, _}} when status in [408, 502, 503, 504] ->
        {:error, :offline, state}

      {:error, %{reason: reason}} when reason in [:timeout, :econnrefused, :nxdomain] ->
        {:error, :offline, state}

      {:error, reason} ->
        {:error, reason, state}
    end
  end

  defp parse_last_sync_setting do
    case Cache.get_setting("last_sync") do
      nil -> nil
      ts when is_binary(ts) -> ts
    end
  end

  defp cache_sync_data(sync_data) do
    if posts = sync_data[:posts] do
      Enum.each(posts, fn post ->
        Cache.cache_item("post", post[:id], Jason.encode!(post),
          etag: post[:etag],
          encrypted_key: post[:encrypted_key]
        )
      end)
    end

    if connections = sync_data[:connections] do
      Enum.each(connections, fn conn ->
        Cache.cache_item("connection", conn[:id], Jason.encode!(conn), etag: conn[:etag])
      end)
    end

    if groups = sync_data[:groups] do
      Enum.each(groups, fn group ->
        Cache.cache_item("group", group[:id], Jason.encode!(group), etag: group[:etag])
      end)
    end
  end

  defp cleanup_old_sync_items do
    Cache.cleanup_completed_sync_items(24)
  end

  defp check_connectivity(state) do
    if state.token do
      case Client.me(state.token) do
        {:ok, _} ->
          if !state.online do
            send(self(), :sync)
          end

          %{state | online: true}

        {:error, _} ->
          %{state | online: false}
      end
    else
      state
    end
  end

  defp schedule_sync do
    Process.send_after(self(), :sync, @sync_interval)
  end

  defp schedule_retry(retry_count) do
    delay = min(@retry_interval * :math.pow(2, retry_count), @max_retry_interval)
    Process.send_after(self(), :sync, trunc(delay))
  end

  defp schedule_health_check do
    Process.send_after(self(), :health_check, @health_check_interval)
  end

  defp broadcast_status(state) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "sync:status",
      {:sync_status,
       %{
         online: state.online,
         syncing: state.syncing,
         last_sync: state.last_sync,
         pending_count: state.pending_count
       }}
    )
  end
end
