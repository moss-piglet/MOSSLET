defmodule Mosslet.Conversations.Adapters.Web do
  @moduledoc """
  Web adapter for conversation operations.

  Uses direct Postgres access via `Mosslet.Repo` and
  `Fly.Repo.transaction_on_primary/1` for writes.
  """

  @behaviour Mosslet.Conversations.Adapter

  import Ecto.Query, warn: false

  alias Mosslet.Repo
  alias Mosslet.Conversations.{Conversation, Message, UserConversation}

  @impl true
  def list_conversations(user) do
    blocked_ids_subquery =
      from(b in Mosslet.Accounts.UserBlock,
        where:
          (b.blocker_id == ^user.id or b.blocked_id == ^user.id) and
            b.block_type in [:full, :conversations_only],
        select:
          fragment(
            "CASE WHEN ? = ? THEN ? ELSE ? END",
            b.blocker_id,
            type(^user.id, :binary_id),
            b.blocked_id,
            b.blocker_id
          )
      )

    blocked_conversation_ids_subquery =
      from(partner_uc in UserConversation,
        where: partner_uc.user_id in subquery(blocked_ids_subquery),
        select: partner_uc.conversation_id
      )

    user_conversations =
      from(uc in UserConversation,
        where: uc.user_id == ^user.id and uc.archived == false,
        where: uc.conversation_id not in subquery(blocked_conversation_ids_subquery),
        join: c in assoc(uc, :conversation),
        preload: [conversation: {c, [user_connection: [:connection], user_conversations: []]}],
        order_by: [desc: c.updated_at]
      )
      |> Repo.all()

    conversation_ids = Enum.map(user_conversations, & &1.conversation_id)

    last_messages =
      if conversation_ids == [] do
        %{}
      else
        from(m in Message,
          where: m.conversation_id in ^conversation_ids,
          distinct: m.conversation_id,
          order_by: [desc: m.inserted_at],
          preload: [:sender]
        )
        |> Repo.all()
        |> Map.new(&{&1.conversation_id, &1})
      end

    connection_ids =
      user_conversations
      |> Enum.map(& &1.conversation.user_connection.connection_id)
      |> Enum.uniq()

    user_connections_map =
      if connection_ids == [] do
        %{}
      else
        from(uc in Mosslet.Accounts.UserConnection,
          where: uc.user_id == ^user.id and uc.connection_id in ^connection_ids,
          preload: [:connection]
        )
        |> Repo.all()
        |> Map.new(&{&1.connection_id, &1})
      end

    Enum.map(user_conversations, fn uc ->
      conn_id = uc.conversation.user_connection.connection_id
      user_conn = Map.get(user_connections_map, conn_id)

      %{
        user_conversation: uc,
        last_message: Map.get(last_messages, uc.conversation_id),
        user_connection: user_conn
      }
    end)
  end

  @impl true
  def list_archived_conversations(user) do
    from(uc in UserConversation,
      where: uc.user_id == ^user.id and uc.archived == true,
      join: c in assoc(uc, :conversation),
      preload: [conversation: {c, [user_connection: [:connection]]}],
      order_by: [desc: c.updated_at]
    )
    |> Repo.all()
    |> Enum.map(fn uc ->
      %{user_conversation: uc, last_message: nil}
    end)
  end

  @impl true
  def get_last_message(conversation_id) do
    from(m in Message,
      where: m.conversation_id == ^conversation_id,
      order_by: [desc: m.inserted_at],
      limit: 1,
      preload: [:sender]
    )
    |> Repo.one()
  end

  @impl true
  def get_user_connection_for_conversation(conversation_id, user_id) do
    from(uc in UserConversation,
      where: uc.conversation_id == ^conversation_id and uc.user_id != ^user_id,
      join: u in assoc(uc, :user),
      preload: [user: u]
    )
    |> Repo.one()
  end

  @impl true
  def get_conversation!(id) do
    Conversation
    |> Repo.get!(id)
    |> Repo.preload(user_connection: [:connection], user_conversations: [])
  end

  @impl true
  def get_conversation_for_connection(user_connection_id) do
    from(c in Conversation, where: c.user_connection_id == ^user_connection_id)
    |> Repo.one()
  end

  @impl true
  def get_or_create_conversation(user_connection_id, user_conversation_attrs_list) do
    case get_conversation_for_connection(user_connection_id) do
      %Conversation{} = conversation ->
        {:ok, Repo.preload(conversation, [:user_conversations])}

      nil ->
        case Repo.transaction_on_primary(fn ->
               %Conversation{}
               |> Conversation.changeset(%{user_connection_id: user_connection_id})
               |> Repo.insert()
             end) do
          {:ok, {:ok, conversation}} ->
            Enum.each(user_conversation_attrs_list, fn attrs ->
              Repo.transaction_on_primary(fn ->
                %UserConversation{}
                |> UserConversation.changeset(attrs)
                |> Ecto.Changeset.put_change(:conversation_id, conversation.id)
                |> Ecto.Changeset.put_change(:user_id, attrs.user_id)
                |> Repo.insert()
              end)
            end)

            {:ok, Repo.preload(conversation, [:user_conversations])}

          {:ok, {:error, changeset}} ->
            {:error, changeset}
        end
    end
  end

  @impl true
  def get_user_conversation(conversation_id, user_id) do
    from(uc in UserConversation,
      where: uc.conversation_id == ^conversation_id and uc.user_id == ^user_id
    )
    |> Repo.one()
  end

  @impl true
  def list_messages(conversation_id, opts) do
    limit = Keyword.get(opts, :limit, 50)
    before = Keyword.get(opts, :before)

    query =
      from(m in Message,
        where: m.conversation_id == ^conversation_id,
        order_by: [desc: m.inserted_at],
        limit: ^limit,
        preload: [:sender]
      )

    query =
      if before do
        from(m in query, where: m.inserted_at < ^before)
      else
        query
      end

    query
    |> Repo.all()
    |> Enum.reverse()
  end

  @impl true
  def create_message(attrs) do
    case Repo.transaction_on_primary(fn ->
           %Message{}
           |> Message.changeset(attrs)
           |> Ecto.Changeset.put_change(:conversation_id, attrs.conversation_id)
           |> Ecto.Changeset.put_change(:sender_id, attrs.sender_id)
           |> Repo.insert()
         end) do
      {:ok, {:ok, message}} ->
        Repo.transaction_on_primary(fn ->
          from(c in Conversation, where: c.id == ^message.conversation_id)
          |> Repo.update_all(
            set: [updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)]
          )
        end)

        {:ok, Repo.preload(message, [:sender])}

      {:ok, {:error, changeset}} ->
        {:error, changeset}
    end
  end

  @impl true
  def update_message(message, attrs) do
    case Repo.transaction_on_primary(fn ->
           message
           |> Message.changeset(attrs)
           |> Repo.update()
         end) do
      {:ok, {:ok, message}} -> {:ok, Repo.preload(message, [:sender])}
      {:ok, {:error, changeset}} -> {:error, changeset}
    end
  end

  @impl true
  def delete_message(message) do
    case Repo.transaction_on_primary(fn ->
           Repo.delete(message)
         end) do
      {:ok, {:ok, message}} -> {:ok, message}
      {:ok, {:error, changeset}} -> {:error, changeset}
    end
  end

  @impl true
  def mark_conversation_read(conversation_id, user_id) do
    case get_user_conversation(conversation_id, user_id) do
      nil ->
        {:error, :not_found}

      uc ->
        case Repo.transaction_on_primary(fn ->
               uc
               |> Ecto.Changeset.change(%{
                 last_read_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
               })
               |> Repo.update()
             end) do
          {:ok, {:ok, uc}} -> {:ok, uc}
          {:ok, {:error, changeset}} -> {:error, changeset}
        end
    end
  end

  @impl true
  def archive_conversation(conversation_id, user_id) do
    case get_user_conversation(conversation_id, user_id) do
      nil ->
        {:error, :not_found}

      uc ->
        case Repo.transaction_on_primary(fn ->
               uc
               |> Ecto.Changeset.change(%{archived: true})
               |> Repo.update()
             end) do
          {:ok, {:ok, uc}} -> {:ok, uc}
          {:ok, {:error, changeset}} -> {:error, changeset}
        end
    end
  end

  @impl true
  def unarchive_conversation(conversation_id, user_id) do
    case get_user_conversation(conversation_id, user_id) do
      nil ->
        {:error, :not_found}

      uc ->
        case Repo.transaction_on_primary(fn ->
               uc
               |> Ecto.Changeset.change(%{archived: false})
               |> Repo.update()
             end) do
          {:ok, {:ok, uc}} -> {:ok, uc}
          {:ok, {:error, changeset}} -> {:error, changeset}
        end
    end
  end

  @impl true
  def delete_conversation(conversation) do
    case Repo.transaction_on_primary(fn ->
           Repo.delete(conversation)
         end) do
      {:ok, {:ok, conversation}} -> {:ok, conversation}
      {:ok, {:error, changeset}} -> {:error, changeset}
    end
  end

  @impl true
  def count_unread_messages(user_id) do
    blocked_conversation_ids_subquery =
      from(partner_uc in UserConversation,
        join: b in Mosslet.Accounts.UserBlock,
        on:
          (b.blocker_id == ^user_id and b.blocked_id == partner_uc.user_id and
             b.block_type in [:full, :conversations_only]) or
            (b.blocked_id == ^user_id and b.blocker_id == partner_uc.user_id and
               b.block_type in [:full, :conversations_only]),
        where: partner_uc.user_id != ^user_id,
        select: partner_uc.conversation_id
      )

    from(uc in UserConversation,
      where: uc.user_id == ^user_id and uc.archived == false,
      where: uc.conversation_id not in subquery(blocked_conversation_ids_subquery),
      join: m in Message,
      on: m.conversation_id == uc.conversation_id,
      where:
        is_nil(uc.last_read_at) or
          m.inserted_at > uc.last_read_at,
      where: m.sender_id != ^user_id,
      select: count(m.id)
    )
    |> Repo.one() || 0
  end
end
