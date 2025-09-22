# Replace the process_uploaded_photos function with correct pattern
defp process_uploaded_photos(socket, current_user, key) do
  upload_entries = socket.assigns.uploads.photos.entries
  Logger.info("📷 PROCESS_UPLOADED_PHOTOS: Starting with #{length(upload_entries)} entries")

  if length(upload_entries) == 0 do
    []
  else
    # Process uploads directly in LiveView process - NO TASKS!
    for entry <- upload_entries do
      Logger.info(
        "📷 PROCESS_UPLOADED_PHOTOS: Processing entry #{entry.ref}: #{entry.client_name}"
      )

      consume_uploaded_entry(socket, entry, fn %{path: tmp_path} ->
        Logger.info(
          "📷 PROCESS_UPLOADED_PHOTOS: Consuming entry #{entry.ref}, tmp_path: #{tmp_path}"
        )

        # Generate a unique storage key for this photo
        storage_key = Ecto.UUID.generate()
        Logger.info("📷 PROCESS_UPLOADED_PHOTOS: Generated storage_key: #{storage_key}")

        # Get or generate the trix_key for encryption (same as posts use)
        trix_key =
          socket.assigns[:trix_key] || generate_and_encrypt_trix_key(current_user, nil)

        Logger.info("📷 PROCESS_UPLOADED_PHOTOS: Generated trix_key")

        # Use your existing Tigris.ex upload system
        upload_params = %{
          "Content-Type" => entry.client_type,
          "storage_key" => storage_key,
          "file" => %Plug.Upload{
            path: tmp_path,
            content_type: entry.client_type,
            filename: entry.client_name
          },
          "trix_key" => trix_key
        }

        Logger.info("📷 PROCESS_UPLOADED_PHOTOS: Prepared upload_params for #{entry.client_name}")

        # Get session for Tigris.ex (same pattern as trix uploads)
        session = %{
          "user_token" => Phoenix.Token.sign(MossletWeb.Endpoint, "user auth", current_user.id),
          "key" => key
        }

        Logger.info("📷 PROCESS_UPLOADED_PHOTOS: Prepared session")

        case Mosslet.FileUploads.Tigris.upload(session, upload_params) do
          {:ok, _presigned_url} ->
            Logger.info("📷 PROCESS_UPLOADED_PHOTOS: Upload successful for #{entry.client_name}")
            # Build the file path the same way Tigris.ex does internally
            [file_ext | _] = MIME.extensions(entry.client_type)
            file_path = "uploads/trix/#{storage_key}.#{file_ext}"
            Logger.info("📷 PROCESS_UPLOADED_PHOTOS: Built file_path: #{file_path}")
            {:ok, file_path}

          {:error, {:nsfw, message}} ->
            Logger.error("📷 PROCESS_UPLOADED_PHOTOS: NSFW content detected: #{message}")
            {:error, "Content not allowed: #{message}"}

          {:error, reason} ->
            Logger.error("📷 PROCESS_UPLOADED_PHOTOS: Upload failed: #{inspect(reason)}")
            {:error, "Upload failed: #{inspect(reason)}"}
        end
      end)
    end
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, path} -> path end)
  end
end
