defmodule Mosslet.FileUploads.Local do
  @moduledoc false
  def consume_uploaded_entries(socket, upload_name) do
    Phoenix.LiveView.consume_uploaded_entries(socket, upload_name, fn %{path: path}, _entry ->
      destination_path = move_file_into_priv(path)
      {:ok, destination_path}
    end)
  end

  def consume_uploaded_entry(socket, entry) do
    Phoenix.LiveView.consume_uploaded_entry(socket, entry, fn %{path: path} ->
      destination_path = move_file_into_priv(path)
      {:ok, destination_path}
    end)
  end

  def move_file_into_priv(path) do
    dest = Path.join([:code.priv_dir(:mosslet), "static", "uploads", Path.basename(path)])
    File.mkdir_p(Path.dirname(dest))
    File.cp!(path, dest)
    "/uploads/#{Path.basename(dest)}"
  end

  def presign_upload(_, _) do
    nil
  end
end
