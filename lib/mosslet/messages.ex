defmodule Mosslet.Messages do
  @moduledoc """
  The Messages context.

  This context uses platform-aware adapters for database operations:
  - Web (Fly.io): Direct Postgres access via `Mosslet.Messages.Adapters.Web`
  - Native (Desktop/Mobile): API + SQLite cache via `Mosslet.Messages.Adapters.Native`

  The adapter is selected at runtime based on `Mosslet.Platform.native?()`.
  """

  alias Mosslet.Platform
  alias Mosslet.Messages.Message

  @doc """
  Returns the appropriate adapter module based on the current platform.
  """
  def adapter do
    if Platform.native?() do
      Module.concat([__MODULE__, Adapters, Native])
    else
      Mosslet.Messages.Adapters.Web
    end
  end

  @doc """
  Returns the list of messages.

  ## Examples

      iex> list_messages()
      [%Message{}, ...]

  """
  def list_messages(conversation_id) do
    adapter().list_messages(conversation_id)
  end

  @doc """
  Gets a single message.

  Raises `Ecto.NoResultsError` if the Message does not exist.

  ## Examples

      iex> get_message!(123)
      %Message{}

      iex> get_message!(456)
      ** (Ecto.NoResultsError)

  """
  def get_message!(conversation_id, id) do
    adapter().get_message!(conversation_id, id)
  end

  def get_last_message!(conversation_id) do
    adapter().get_last_message!(conversation_id)
  end

  @doc """
  Creates a message.

  ## Examples

      iex> create_message(%{field: value})
      {:ok, %Message{}}

      iex> create_message(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_message(conversation_id, attrs \\ %{}) do
    adapter().create_message(conversation_id, attrs)
  end

  @doc """
  Updates a message.

  ## Examples

      iex> update_message(message, %{field: new_value})
      {:ok, %Message{}}

      iex> update_message(message, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_message(%Message{} = message, attrs) do
    adapter().update_message(message, attrs)
  end

  @doc """
  Deletes a message.

  ## Examples

      iex> delete_message(message)
      {:ok, %Message{}}

      iex> delete_message(message)
      {:error, %Ecto.Changeset{}}

  """
  def delete_message(%Message{} = message) do
    adapter().delete_message(message)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking message changes.

  ## Examples

      iex> change_message(message)
      %Ecto.Changeset{data: %Message{}}

  """
  def change_message(%Message{} = message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  @doc """
  Convert an Ecto DB message to a LangChain Message struct.
  """
  def db_messages_to_langchain_messages(messages) do
    Enum.map(messages, fn db_msg ->
      LangChain.Message.new!(%{
        role: db_msg.role,
        content: db_msg.content
      })
    end)
  end
end
