defmodule Mosslet.FileUploads.JournalCoverUploadWriter do
  @moduledoc """
  A memory-efficient LiveView.UploadWriter for journal book cover images.

  Key features:
  - Streams chunks to disk instead of accumulating in memory
  - Validates MIME type from actual file content (magic bytes)
  - Converts images to WebP for storage efficiency
  - Encrypts with user's personal key for privacy
  - Cleans up temp files automatically

  Processing stages:
  1. Receiving chunks → temp file (0-30% progress)
  2. MIME validation & safety check (30-50%)
  3. Image processing: resize, WebP conversion (50-70%)
  4. Encryption (70-85%)
  5. Upload to object storage (85-95%)
  6. Ready state with cleanup (95-100%)
  """

  @behaviour Phoenix.LiveView.UploadWriter

  alias Mosslet.Encrypted
  alias Mosslet.FileUploads.TempStorage

  @max_dimension 800
  @allowed_mimes ~w(image/jpeg image/png image/webp image/heic image/heif)
  @temp_subdir "journal_cover"
  @mime_header_size 12
  @folder "uploads/journal/covers"

  @impl true
  def init(opts) do
    entry_ref = opts[:entry_ref]
    temp_path = TempStorage.temp_path(@temp_subdir, entry_ref)

    case File.open(temp_path, [:write, :binary]) do
      {:ok, file_handle} ->
        state = %{
          temp_path: temp_path,
          file_handle: file_handle,
          total_size: 0,
          expected_size: opts[:expected_size],
          lv_pid: opts[:lv_pid],
          entry_ref: entry_ref,
          user: opts[:user],
          key: opts[:key],
          book_id: opts[:book_id],
          processed_binary: nil,
          file_path: nil,
          error: nil,
          stage: :receiving
        }

        {:ok, state}

      {:error, reason} ->
        {:error, "Failed to create temp file: #{inspect(reason)}"}
    end
  end

  @impl true
  def meta(state) do
    cond do
      state.error ->
        %{error: state.error}

      state.file_path ->
        %{file_path: state.file_path}

      true ->
        %{stage: state.stage}
    end
  end

  @impl true
  def write_chunk(data, state) do
    size = byte_size(data)
    new_total = state.total_size + size

    case IO.binwrite(state.file_handle, data) do
      :ok ->
        if state.lv_pid && state.expected_size && state.expected_size > 0 do
          percent = min(30, round(new_total / state.expected_size * 30))
          notify_progress(state, :receiving, percent)
        end

        {:ok, %{state | total_size: new_total}}

      {:error, reason} ->
        {:error, "Failed to write chunk: #{inspect(reason)}", state}
    end
  end

  @impl true
  def close(state, :done) do
    File.close(state.file_handle)

    result =
      with {:ok, mime_type} <- validate_mime_from_header(state.temp_path),
           {:ok, binary} <- File.read(state.temp_path),
           {:ok, image} <- load_image(binary, mime_type),
           _ <- notify_progress(state, :checking, 35),
           {:ok, safe_image} <- check_safety(image),
           _ <- notify_progress(state, :processing, 50),
           {:ok, processed} <- process_image(safe_image),
           {:ok, webp_binary} <- to_webp_binary(processed),
           _ <- notify_progress(state, :encrypting, 70),
           {:ok, encrypted} <- encrypt_binary(webp_binary, state.user, state.key),
           {:ok, file_path} <- prepare_file_path(state.book_id),
           _ <- notify_progress(state, :uploading, 85),
           {:ok, _} <- upload_to_storage(file_path, encrypted) do
        notify_progress(state, :ready, 100)
        {:ok, file_path}
      end

    TempStorage.cleanup(state.temp_path)

    case result do
      {:ok, file_path} ->
        notify_progress(state, :complete, file_path)
        {:ok, %{state | file_path: file_path, file_handle: nil}}

      {:error, reason} ->
        notify_progress(state, :error, reason)
        {:ok, %{state | error: reason, file_handle: nil}}

      {:nsfw, message} ->
        notify_progress(state, :error, {:nsfw, message})
        {:ok, %{state | error: {:nsfw, message}, file_handle: nil}}
    end
  end

  def close(state, :cancel) do
    File.close(state.file_handle)
    TempStorage.cleanup(state.temp_path)
    {:ok, %{state | file_handle: nil}}
  end

  def close(state, {:error, _reason}) do
    File.close(state.file_handle)
    TempStorage.cleanup(state.temp_path)
    {:ok, %{state | file_handle: nil}}
  end

  defp validate_mime_from_header(path) do
    case File.open(path, [:read, :binary]) do
      {:ok, file} ->
        header = IO.binread(file, @mime_header_size)
        File.close(file)

        case header do
          {:error, reason} ->
            {:error, "Failed to read file header: #{inspect(reason)}"}

          data when is_binary(data) ->
            detected_mime = ExMarcel.MimeType.for({:string, data})

            if detected_mime in @allowed_mimes do
              {:ok, detected_mime}
            else
              {:error, "Invalid image type. Allowed: JPEG, PNG, WebP, HEIC"}
            end
        end

      {:error, reason} ->
        {:error, "Failed to open file: #{inspect(reason)}"}
    end
  end

  defp load_image(binary, mime_type) when mime_type in ["image/heic", "image/heif"] do
    with {:ok, {heic_image, _metadata}} <- Vix.Vips.Operation.heifload_buffer(binary),
         {:ok, materialized} <- materialize_heic(heic_image) do
      {:ok, materialized}
    else
      {:error, _reason} ->
        load_heic_with_sips(binary)
    end
  end

  defp load_image(binary, _mime_type) do
    case Image.from_binary(binary) do
      {:ok, image} -> {:ok, image}
      {:error, reason} -> {:error, "Failed to load image: #{inspect(reason)}"}
    end
  end

  defp materialize_heic(image) do
    srgb_image =
      case Image.to_colorspace(image, :srgb) do
        {:ok, srgb} -> srgb
        {:error, _} -> image
      end

    case Image.write(srgb_image, :memory, suffix: ".png") do
      {:ok, png_binary} -> Image.from_binary(png_binary)
      {:error, _} -> fallback_heic_materialization(srgb_image)
    end
  end

  defp fallback_heic_materialization(image) do
    case Image.write(image, :memory, suffix: ".jpg") do
      {:ok, jpg_binary} -> Image.from_binary(jpg_binary)
      {:error, reason} -> {:error, "Failed to materialize HEIC image: #{inspect(reason)}"}
    end
  end

  defp load_heic_with_sips(binary) do
    tmp_heic = TempStorage.temp_path(@temp_subdir, "heic_input")
    tmp_png = TempStorage.temp_path(@temp_subdir, "heic_output")

    :ok = File.write(tmp_heic, binary)

    result =
      case :os.type() do
        {:unix, :darwin} ->
          case System.cmd("sips", ["-s", "format", "png", tmp_heic, "--out", tmp_png],
                 stderr_to_stdout: true
               ) do
            {_output, 0} ->
              png_binary = File.read!(tmp_png)
              Image.from_binary(png_binary)

            {_output, _code} ->
              {:error, "HEIC/HEIF files are not supported. Please convert to JPEG or PNG."}
          end

        {:unix, _linux} ->
          case System.cmd("heif-convert", [tmp_heic, tmp_png], stderr_to_stdout: true) do
            {_output, 0} ->
              png_binary = File.read!(tmp_png)
              Image.from_binary(png_binary)

            {_output, _code} ->
              {:error, "HEIC/HEIF files are not supported. Please convert to JPEG or PNG."}
          end

        _ ->
          {:error, "HEIC/HEIF files are not supported on this platform."}
      end

    TempStorage.cleanup(tmp_heic)
    TempStorage.cleanup(tmp_png)
    result
  end

  defp check_safety(image) do
    case Mosslet.AI.Images.check_for_safety(image) do
      {:ok, _} -> {:ok, image}
      {:nsfw, message} -> {:nsfw, message}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_image(image) do
    with {:ok, {rotated, _flags}} <- Image.autorotate(image),
         {:ok, stripped} <- Image.remove_metadata(rotated),
         {:ok, resized} <- resize_image(stripped),
         {:ok, srgb} <- Image.to_colorspace(resized, :srgb) do
      {:ok, srgb}
    end
  end

  defp resize_image(image) do
    width = Image.width(image)
    height = Image.height(image)

    if width > @max_dimension or height > @max_dimension do
      Image.thumbnail(image, "#{@max_dimension}x#{@max_dimension}")
    else
      {:ok, image}
    end
  end

  defp to_webp_binary(image) do
    quality = calculate_adaptive_quality(image)

    case Image.write(image, :memory, suffix: ".webp", webp: [quality: quality]) do
      {:ok, binary} -> {:ok, binary}
      {:error, reason} -> {:error, "Failed to convert to WebP: #{inspect(reason)}"}
    end
  end

  defp calculate_adaptive_quality(image) do
    width = Image.width(image)
    height = Image.height(image)
    total_pixels = width * height

    cond do
      total_pixels < 250_000 -> 90
      total_pixels < 500_000 -> 85
      true -> 80
    end
  end

  defp encrypt_binary(binary, user, key) do
    {:ok, d_user_key} =
      Encrypted.Users.Utils.decrypt_user_attrs_key(user.user_key, user, key)

    encrypted = Encrypted.Utils.encrypt(%{key: d_user_key, payload: binary})
    {:ok, encrypted}
  end

  defp prepare_file_path(book_id) do
    storage_key = Ecto.UUID.generate()
    file_path = "#{@folder}/#{book_id}/#{storage_key}.webp"
    {:ok, file_path}
  end

  defp upload_to_storage(file_path, data) do
    bucket = Encrypted.Session.memories_bucket()

    case ExAws.S3.put_object(bucket, file_path, data) |> ExAws.request() do
      {:ok, %{status_code: 200}} -> {:ok, :uploaded}
      {:ok, resp} -> {:error, "Upload failed: #{inspect(resp)}"}
      {:error, _} = error -> error
    end
  end

  @doc """
  Deletes a cover image from object storage.
  """
  def delete_cover_image(file_path) when is_binary(file_path) do
    bucket = Encrypted.Session.memories_bucket()

    Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
      case ExAws.S3.delete_object(bucket, file_path) |> ExAws.request() do
        {:ok, _resp} ->
          {:ok, :cover_deleted}

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  def delete_cover_image(nil), do: :ok

  defp notify_progress(state, stage, value) do
    if state.lv_pid do
      send(state.lv_pid, {:cover_upload_progress, state.entry_ref, stage, value})
    end

    :ok
  end
end
