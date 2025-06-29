defmodule MossletWeb.TrixUploadsController do
  use MossletWeb, :controller

  def create(conn, params) do
    case impl().upload(conn.private.plug_session, params) do
      {:ok, file_url} ->
        send_resp(conn, 201, file_url)

      {:error, {:nsfw, message}} ->
        # Send a 418 "I'm a teapot" message
        send_resp(conn, 418, message)

      {:error, _reason} ->
        send_resp(conn, 400, "Unable to upload file, please try again later.")
    end
  end

  def get(conn, params) do
    case impl().get_file(params) do
      {:ok, file_url} ->
        send_resp(conn, 200, file_url)

      {:error, _reason} ->
        send_resp(conn, 400, "Unable to retrieve file, please try again later.")
    end
  end

  defp impl, do: Application.get_env(:mosslet, :uploader)[:adapter]

  def delete(conn, %{"key" => key, "content_type" => content_type}) do
    case impl().delete_file(key, content_type) do
      :ok -> send_resp(conn, 204, "File successfully deleted")
      {:error, _reason} -> send_resp(conn, 400, "Unable to delete file, please try again later.")
    end
  end
end
