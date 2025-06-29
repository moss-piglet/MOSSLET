defmodule MossletWeb.MemoryDownloadController do
  use MossletWeb, :controller

  alias Mosslet.Accounts
  alias Mosslet.Encrypted
  alias Mosslet.Memories

  alias Mosslet.Extensions.MemoryProcessor
  alias MossletWeb.Helpers
  alias MossletWeb.Router.Helpers, as: Routes

  def download_memory(conn, %{
        "current_user_id" => current_user_id,
        "memory_id" => memory_id,
        "memory_name" => memory_name,
        "memory_file_type" => memory_file_type,
        "memory_user_id" => memory_user_id,
        "key" => key
      }) do
    memory_user = Accounts.get_user_with_preloads(memory_user_id)
    current_user = Accounts.get_user!(current_user_id)
    memory = Memories.get_memory!(memory_id)
    user_memory = Memories.get_user_memory(memory, current_user)

    if memory_user != nil && current_user != nil do
      case Helpers.check_if_user_can_download_memory(
             memory_user.id,
             current_user.id
           ) do
        true ->
          memory_binary =
            MemoryProcessor.get_ets_memory(
              "user:#{memory_user.id}-memory:#{memory.id}-key:#{memory_user.connection.id}"
            )
            |> Encrypted.Users.Utils.decrypt_item(current_user, user_memory.key, key)

          conn
          |> send_download({:binary, memory_binary},
            filename: memory_name,
            content_type: memory_file_type
          )

        _rest ->
          conn
          |> put_flash(:warning, "There was an error downloading the Memory.")
          |> redirect(to: Routes.memory_index_path(conn, :index))
          |> halt()
      end
    else
      conn
      |> redirect(to: Routes.memory_index_path(conn, :index))
      |> halt()
    end
  end

  def download_memory(conn, _params) do
    conn
    |> redirect(to: Routes.memory_index_path(conn, :index))
    |> halt()
  end

  def download_public_memory(conn, %{
        "current_user_id" => current_user_id,
        "memory_id" => memory_id,
        "memory_name" => memory_name,
        "memory_file_type" => memory_file_type,
        "memory_user_id" => memory_user_id,
        "key" => _key
      }) do
    memory_user = Accounts.get_user_with_preloads(memory_user_id)
    current_user = Accounts.get_user!(current_user_id)
    memory = Memories.get_memory!(memory_id)
    user_memory = Memories.get_public_user_memory(memory)

    if memory_user != nil && current_user != nil do
      case Helpers.check_if_user_can_download_memory(
             memory_user.id,
             current_user.id
           ) do
        true ->
          memory_binary =
            MemoryProcessor.get_ets_memory(
              "profile-user:#{memory_user_id}-memory:#{memory.id}-key:#{user_memory.id}"
            )
            |> Encrypted.Users.Utils.decrypt_public_item(user_memory.key)

          conn
          |> send_download({:binary, memory_binary},
            filename: memory_name,
            content_type: memory_file_type
          )

        _rest ->
          conn
          |> put_flash(:warning, "There was an error downloading the Memory.")
          |> redirect(to: Routes.memory_index_path(conn, :index))
          |> halt()
      end
    else
      conn
      |> redirect(to: Routes.memory_index_path(conn, :index))
      |> halt()
    end
  end

  def download_public_memory(conn, _params) do
    conn
    |> redirect(to: Routes.memory_index_path(conn, :index))
    |> halt()
  end

  def download_shared_memory(conn, %{
        "current_user_id" => current_user_id,
        "memory_id" => memory_id,
        "memory_name" => memory_name,
        "memory_file_type" => memory_file_type,
        "uconn_id" => uconn_id,
        "key" => key
      }) do
    uconn = Accounts.get_user_connection!(uconn_id)
    current_user = Accounts.get_user!(current_user_id)
    memory = Memories.get_memory!(memory_id)
    memory_user = Accounts.get_user_with_preloads(memory.user_id)
    user_memory = Memories.get_user_memory(memory, current_user)

    if uconn != nil && current_user != nil do
      case Helpers.check_if_user_can_download_shared_memory(
             memory_user.id,
             current_user.id
           ) do
        true ->
          shared_memory_binary =
            MemoryProcessor.get_ets_memory(
              "user:#{memory_user.id}-memory:#{memory.id}-key:#{user_memory.id}"
            )
            |> Encrypted.Users.Utils.decrypt_item(current_user, user_memory.key, key)

          conn
          |> send_download({:binary, shared_memory_binary},
            filename: memory_name,
            content_type: memory_file_type
          )

        _rest ->
          conn
          |> put_flash(:warning, "There was an error downloading the Memory.")
          |> redirect(to: Routes.memory_index_path(conn, :index))
          |> halt()
      end
    else
      conn
      |> redirect(to: Routes.memory_index_path(conn, :index))
      |> halt()
    end
  end

  def download_shared_memory(conn, _params) do
    conn
    |> redirect(to: Routes.memory_index_path(conn, :index))
    |> halt()
  end

  def download_shared_public_memory(conn, %{
        "current_user_id" => current_user_id,
        "memory_id" => memory_id,
        "memory_name" => memory_name,
        "memory_file_type" => memory_file_type,
        "uconn_id" => uconn_id,
        "key" => _key
      }) do
    uconn = Accounts.get_user_connection!(uconn_id)
    current_user = Accounts.get_user!(current_user_id)
    memory = Memories.get_memory!(memory_id)
    memory_user = Accounts.get_user_with_preloads(memory.user_id)
    user_memory = Memories.get_public_user_memory(memory)

    if uconn != nil && current_user != nil do
      case Helpers.check_if_user_can_download_shared_memory(
             memory_user.id,
             current_user.id
           ) do
        true ->
          shared_memory_binary =
            MemoryProcessor.get_ets_memory(
              "profile-user:#{memory_user.id}-memory:#{memory.id}-key:#{user_memory.id}"
            )
            |> Encrypted.Users.Utils.decrypt_public_item(user_memory.key)

          conn
          |> send_download({:binary, shared_memory_binary},
            filename: memory_name,
            content_type: memory_file_type
          )

        _rest ->
          conn
          |> put_flash(:warning, "There was an error downloading the Memory.")
          |> redirect(to: Routes.memory_index_path(conn, :index))
          |> halt()
      end
    else
      conn
      |> redirect(to: Routes.memory_index_path(conn, :index))
      |> halt()
    end
  end

  def download_shared_public_memory(conn, _params) do
    conn
    |> redirect(to: Routes.memory_index_path(conn, :index))
    |> halt()
  end
end
