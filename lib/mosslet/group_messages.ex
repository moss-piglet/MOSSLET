defmodule Mosslet.GroupMessages do
  @moduledoc """
  The GroupMessages context.

  This context uses platform-aware adapters for database operations:
  - Web (Fly.io): Direct Postgres access via `Mosslet.GroupMessages.Adapters.Web`
  - Native (Desktop/Mobile): API + SQLite cache via `Mosslet.GroupMessages.Adapters.Native`

  The adapter is selected at runtime based on `Mosslet.Platform.native?()`.
  """

  import Ecto.Query, warn: false

  alias Mosslet.Platform
  alias Mosslet.Repo
  alias Mosslet.Groups.{GroupMessage, GroupMessageMention}

  @doc """
  Returns the appropriate adapter module based on the current platform.
  """
  def adapter do
    if Platform.native?() do
      Module.concat([__MODULE__, Adapters, Native])
    else
      Mosslet.GroupMessages.Adapters.Web
    end
  end

  @doc """
  Returns the list of groups.

  ## Examples

      iex> list_groups()
      [%Group{}, ...]

  """
  def list_groups do
    adapter().list_groups()
  end

  def get_message!(id) do
    adapter().get_message!(id)
  end

  def last_ten_messages_for(group_id) do
    adapter().last_ten_messages_for(group_id)
  end

  def last_user_message_for_group(group_id, user_id) do
    adapter().last_user_message_for_group(group_id, user_id)
  end

  def delete_message(%GroupMessage{} = message) do
    adapter().delete_message(message)
    |> publish_message_deleted()
  end

  def change_message(%GroupMessage{} = message, attrs \\ %{}) do
    GroupMessage.changeset(message, attrs)
  end

  def create_message(attrs \\ %{}, opts \\ []) do
    adapter().create_message(attrs, opts)
  end

  def update_message(%GroupMessage{} = message, attrs) do
    adapter().update_message(message, attrs)
    |> publish_message_updated()
  end

  def preload_message_sender(message) do
    adapter().preload_message_sender(message)
  end

  def publish_message_created({:ok, message} = result) do
    Phoenix.PubSub.broadcast(Mosslet.PubSub, "group:#{message.group_id}", %{
      event: "new_message",
      payload: %{message: message}
    })

    result
  end

  def publish_message_created(result), do: result

  def publish_message_deleted({:ok, message} = result) do
    Phoenix.PubSub.broadcast(Mosslet.PubSub, "group:#{message.group_id}", %{
      event: "deleted_message",
      payload: %{message: message}
    })

    result
  end

  def publish_message_deleted(result), do: result

  def publish_message_updated({:ok, message} = result) do
    Phoenix.PubSub.broadcast(Mosslet.PubSub, "group:#{message.group_id}", %{
      event: "updated_message",
      payload: %{message: message}
    })

    result
  end

  def publish_message_updated(result), do: result

  def get_previous_n_messages(date, group_id, n) do
    adapter().get_previous_n_messages(date, group_id, n)
  end

  def get_message_count_for_group(group_id) do
    adapter().get_message_count_for_group(group_id)
  end

  def get_next_message_after(message) do
    adapter().get_next_message_after(message)
  end

  def get_previous_message_before(message) do
    adapter().get_previous_message_before(message)
  end

  def get_last_message_for_group(group_id) do
    adapter().get_last_message_for_group(group_id)
  end

  # ===========================================================================
  # Mentions
  # ===========================================================================

  @mention_regex ~r/@\[([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\]/i

  @doc """
  Parses mention tokens from message content.
  Returns a list of user_group_ids that were mentioned.

  Mention format: @[user_group_id]
  """
  def parse_mentions(content) when is_binary(content) do
    @mention_regex
    |> Regex.scan(content)
    |> Enum.map(fn [_full, id] -> id end)
    |> Enum.uniq()
  end

  def parse_mentions(_), do: []

  @doc """
  Creates mention records for a message.
  Takes the message and a list of user_group_ids to mention.
  Excludes self-mentions (sender mentioning themselves).
  """
  def create_mentions_for_message(%GroupMessage{} = message, mentioned_user_group_ids)
      when is_list(mentioned_user_group_ids) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    mentions =
      mentioned_user_group_ids
      |> Enum.reject(&(&1 == message.sender_id))
      |> Enum.uniq()
      |> Enum.map(fn user_group_id ->
        %{
          group_message_id: message.id,
          mentioned_user_group_id: user_group_id,
          inserted_at: now,
          updated_at: now
        }
      end)

    if Enum.empty?(mentions) do
      {:ok, []}
    else
      {:ok, _} =
        Repo.transaction_on_primary(fn ->
          Repo.insert_all(GroupMessageMention, mentions,
            on_conflict: :nothing,
            conflict_target: [:group_message_id, :mentioned_user_group_id]
          )
        end)

      {:ok, mentions}
    end
  end

  @doc """
  Gets unread mention count for a user_group in a specific group.
  """
  def get_unread_mention_count(user_group_id, group_id) do
    from(m in GroupMessageMention,
      join: gm in GroupMessage,
      on: gm.id == m.group_message_id,
      where: m.mentioned_user_group_id == ^user_group_id,
      where: gm.group_id == ^group_id,
      where: is_nil(m.read_at)
    )
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Gets list of unread message IDs for a user_group in a specific group.
  """
  def get_unread_mention_message_ids(user_group_id, group_id) do
    from(m in GroupMessageMention,
      join: gm in GroupMessage,
      on: gm.id == m.group_message_id,
      where: m.mentioned_user_group_id == ^user_group_id,
      where: gm.group_id == ^group_id,
      where: is_nil(m.read_at),
      select: gm.id
    )
    |> Repo.all()
    |> MapSet.new()
  end

  @doc """
  Gets total unread mention count across all groups for a user_group.
  Returns a map of %{group_id => count}.
  """
  def get_unread_mention_counts_by_group(user_group_ids) when is_list(user_group_ids) do
    from(m in GroupMessageMention,
      join: gm in GroupMessage,
      on: gm.id == m.group_message_id,
      where: m.mentioned_user_group_id in ^user_group_ids,
      where: is_nil(m.read_at),
      group_by: gm.group_id,
      select: {gm.group_id, count(m.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Marks all mentions as read for a user_group in a specific group.
  Called when user views the circle chat.
  """
  def mark_mentions_as_read(user_group_id, group_id) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    {:ok, _} =
      Repo.transaction_on_primary(fn ->
        from(m in GroupMessageMention,
          join: gm in GroupMessage,
          on: gm.id == m.group_message_id,
          where: m.mentioned_user_group_id == ^user_group_id,
          where: gm.group_id == ^group_id,
          where: is_nil(m.read_at)
        )
        |> Repo.update_all(set: [read_at: now])
      end)

    :ok
  end

  @doc """
  Marks a single mention as read for a specific message and user_group.
  Called after the mention highlight animation completes.
  """
  def mark_single_mention_as_read(message_id, user_group_id) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    from(m in GroupMessageMention,
      where: m.group_message_id == ^message_id,
      where: m.mentioned_user_group_id == ^user_group_id,
      where: is_nil(m.read_at)
    )
    |> Repo.update_all(set: [read_at: now])

    :ok
  end

  @doc """
  Check if a user_group has any unread mentions.
  """
  def has_unread_mentions?(user_group_id) do
    from(m in GroupMessageMention,
      where: m.mentioned_user_group_id == ^user_group_id,
      where: is_nil(m.read_at),
      limit: 1
    )
    |> Repo.exists?()
  end
end
