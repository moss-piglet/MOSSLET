defmodule Mosslet.Notifications.Push do
  @moduledoc """
  Context for managing push notifications with zero-knowledge architecture.

  🔐 ZERO-KNOWLEDGE DESIGN:
  - Push payloads contain ONLY generic titles and metadata IDs
  - NO sensitive content (usernames, post content, etc.) in push payload
  - Device receives push, fetches actual content via API, decrypts locally
  - Apple/Google never see actual notification content

  Notification Types:
  - :new_post - New post from a connection
  - :new_reply - Reply to user's post
  - :new_message - Direct message (legacy)
  - :group_message - Group chat message
  - :connection_request - New connection request
  - :connection_accepted - Connection request accepted
  - :group_invite - Invited to a group
  """

  import Ecto.Query
  require Logger

  alias Mosslet.Notifications.DeviceToken
  alias Mosslet.Notifications.Push.{APNs, FCM}
  alias Mosslet.Repo

  @type notification_type ::
          :new_post
          | :new_reply
          | :new_message
          | :group_message
          | :connection_request
          | :connection_accepted
          | :group_invite

  @type push_result :: {:ok, map()} | {:error, term()}

  @doc """
  Registers a device token for push notifications.
  If token already exists for this device, updates it.
  """
  def register_device_token(user_id, attrs) do
    attrs = Map.put(attrs, :user_id, user_id)

    case get_device_token_by_hash(attrs.token) do
      nil ->
        %DeviceToken{}
        |> DeviceToken.changeset(attrs)
        |> Repo.insert()

      existing ->
        if existing.user_id == user_id do
          existing
          |> DeviceToken.update_changeset(Map.drop(attrs, [:token, :platform, :user_id]))
          |> Repo.update()
        else
          existing
          |> DeviceToken.changeset(%{user_id: user_id})
          |> Repo.update()
        end
    end
  end

  @doc """
  Unregisters a device token (deactivates it).
  """
  def unregister_device_token(token) do
    case get_device_token_by_hash(token) do
      nil ->
        {:error, :not_found}

      device_token ->
        device_token
        |> DeviceToken.deactivate_changeset()
        |> Repo.update()
    end
  end

  @doc """
  Removes a device token completely.
  """
  def delete_device_token(token) do
    case get_device_token_by_hash(token) do
      nil -> {:error, :not_found}
      device_token -> Repo.delete(device_token)
    end
  end

  @doc """
  Lists all active device tokens for a user.
  """
  def list_user_device_tokens(user_id) do
    DeviceToken
    |> where([d], d.user_id == ^user_id and d.active == true)
    |> Repo.all()
  end

  @doc """
  Gets a device token by its hash (for lookup without decryption).
  """
  def get_device_token_by_hash(token) do
    DeviceToken
    |> where([d], d.token_hash == ^token)
    |> Repo.one()
  end

  @doc """
  Sends a zero-knowledge push notification to a user.

  The push contains only:
  - Generic title/body (e.g., "New activity")
  - Notification type
  - Resource ID for fetching actual content

  ## Examples

      # New post notification
      Push.send_notification(user_id, :new_post, %{post_id: post.id})

      # New reply notification
      Push.send_notification(user_id, :new_reply, %{reply_id: reply.id, post_id: post.id})

      # Connection request
      Push.send_notification(user_id, :connection_request, %{connection_id: conn.id})
  """
  @spec send_notification(binary(), notification_type(), map()) :: [push_result()]
  def send_notification(user_id, type, metadata \\ %{}) do
    user_id
    |> list_user_device_tokens()
    |> Enum.map(fn device_token ->
      send_to_device(device_token, type, metadata)
    end)
  end

  @doc """
  Sends a notification to multiple users.
  """
  @spec send_notification_to_many([binary()], notification_type(), map()) :: :ok
  def send_notification_to_many(user_ids, type, metadata \\ %{}) do
    user_ids
    |> Enum.each(fn user_id ->
      send_notification(user_id, type, metadata)
    end)
  end

  @doc """
  Marks a device token as recently used.
  """
  def touch_device_token(device_token) do
    device_token
    |> DeviceToken.touch_changeset()
    |> Repo.update()
  end

  @doc """
  Deactivates stale device tokens (not used in 90 days).
  """
  def deactivate_stale_tokens do
    cutoff = DateTime.utc_now() |> DateTime.add(-90, :day)

    DeviceToken
    |> where([d], d.active == true)
    |> where([d], d.last_used_at < ^cutoff or is_nil(d.last_used_at))
    |> where([d], d.inserted_at < ^cutoff)
    |> Repo.update_all(set: [active: false])
  end

  @doc """
  Deletes all device tokens for a user (for account deletion).
  """
  def delete_all_user_tokens(user_id) do
    DeviceToken
    |> where([d], d.user_id == ^user_id)
    |> Repo.delete_all()
  end

  defp send_to_device(%DeviceToken{platform: :ios} = device_token, type, metadata) do
    payload = build_payload(type, metadata)

    case APNs.send(device_token.token, payload) do
      {:ok, _} = result ->
        touch_device_token(device_token)
        result

      {:error, :invalid_token} ->
        Logger.warning("APNs invalid token, deactivating: #{device_token.id}")
        Repo.update(DeviceToken.deactivate_changeset(device_token))
        {:error, :invalid_token}

      {:error, reason} = error ->
        Logger.error("APNs send failed: #{inspect(reason)}")
        error
    end
  end

  defp send_to_device(%DeviceToken{platform: :android} = device_token, type, metadata) do
    payload = build_payload(type, metadata)

    case FCM.send(device_token.token, payload) do
      {:ok, _} = result ->
        touch_device_token(device_token)
        result

      {:error, :invalid_token} ->
        Logger.warning("FCM invalid token, deactivating: #{device_token.id}")
        Repo.update(DeviceToken.deactivate_changeset(device_token))
        {:error, :invalid_token}

      {:error, reason} = error ->
        Logger.error("FCM send failed: #{inspect(reason)}")
        error
    end
  end

  defp build_payload(type, metadata) do
    {title, body} = generic_content(type)

    %{
      title: title,
      body: body,
      data: Map.merge(%{type: to_string(type)}, stringify_keys(metadata)),
      sound: "default",
      badge: 1,
      content_available: true,
      mutable_content: true
    }
  end

  defp generic_content(:new_post), do: {"New activity", "Someone shared something with you"}
  defp generic_content(:new_reply), do: {"New reply", "Someone replied to your post"}
  defp generic_content(:new_message), do: {"New message", "You have a new message"}
  defp generic_content(:group_message), do: {"Group activity", "New message in a group"}

  defp generic_content(:connection_request),
    do: {"Connection request", "Someone wants to connect"}

  defp generic_content(:connection_accepted),
    do: {"Connection accepted", "Your request was accepted"}

  defp generic_content(:group_invite), do: {"Group invitation", "You've been invited to a group"}
  defp generic_content(_), do: {"Mosslet", "You have new activity"}

  defp stringify_keys(map) do
    Map.new(map, fn {k, v} -> {to_string(k), to_string(v)} end)
  end
end
