defmodule Mosslet.FileUploads.ImageUploadWriter do
  @moduledoc """
  A custom LiveView.UploadWriter that handles image processing with
  streaming progress feedback. Images are prepared but NOT uploaded until
  form submission.

  This writer processes images in stages with real-time progress updates:
  1. Receiving chunks (0-40% progress)
  2. NSFW safety check (40-50%)
  3. Image processing: metadata removal, resize, WebP conversion (50-90%)
  4. Ready state - image prepared for upload on submit (90-100%)

  ## Usage

      allow_upload(:photos,
        accept: ~w(.jpg .jpeg .png .webp .heic .heif),
        max_entries: 10,
        auto_upload: true,
        progress: &handle_upload_progress/3,
        writer: fn _name, entry, socket ->
          {Mosslet.FileUploads.ImageUploadWriter, %{
            lv_pid: self(),
            entry_ref: entry.ref,
            user_token: socket.assigns.user_token,
            key: socket.assigns.key,
            visibility: socket.assigns.selector
          }}
        end
      )

  ## Progress Events

  The writer sends messages to the LiveView process:
  - `{:upload_progress, entry_ref, :receiving, percent}` - Chunk reception progress
  - `{:upload_progress, entry_ref, :validating, 45}` - NSFW check in progress
  - `{:upload_progress, entry_ref, :processing, 65}` - Image processing
  - `{:upload_progress, entry_ref, :ready, nil}` - Ready for upload on submit
  - `{:upload_progress, entry_ref, :error, reason}` - Error occurred

  ## Consuming

  When consuming, `meta` returns:
  - `%{processed_binary: binary, trix_key: key}` - Processed image ready for upload
  - `%{error: reason}` - If processing failed

      consume_uploaded_entries(socket, :photos, fn %{processed_binary: binary}, entry ->
        # Upload binary to storage at submit time
        {:ok, do_upload(binary)}
      end)
  """

  @behaviour Phoenix.LiveView.UploadWriter

  alias Mosslet.Encrypted
  alias Mosslet.Accounts

  @max_dimension 2560
  @folder "uploads/trix"

  @impl true
  def init(opts) do
    user = Accounts.get_user_by_session_token(opts[:user_token])

    trix_key =
      opts[:trix_key] || generate_trix_key(user, opts[:visibility])

    state = %{
      chunks: [],
      total_size: 0,
      expected_size: opts[:expected_size],
      lv_pid: opts[:lv_pid],
      entry_ref: opts[:entry_ref],
      user_token: opts[:user_token],
      user: user,
      key: opts[:key],
      visibility: opts[:visibility] || "connections",
      trix_key: trix_key,
      processed_binary: nil,
      error: nil,
      stage: :receiving
    }

    if state.lv_pid do
      send(state.lv_pid, {:upload_trix_key, state.entry_ref, trix_key})
    end

    {:ok, state}
  end

  @impl true
  def meta(state) do
    cond do
      state.error ->
        %{error: state.error}

      state.processed_binary ->
        %{processed_binary: state.processed_binary, trix_key: state.trix_key}

      true ->
        %{stage: state.stage, trix_key: state.trix_key}
    end
  end

  @impl true
  def write_chunk(data, state) do
    size = byte_size(data)
    new_total = state.total_size + size
    new_state = %{state | chunks: [data | state.chunks], total_size: new_total}

    if state.lv_pid && state.expected_size && state.expected_size > 0 do
      percent = min(40, round(new_total / state.expected_size * 40))
      send(state.lv_pid, {:upload_progress, state.entry_ref, :receiving, percent})
    end

    {:ok, new_state}
  end

  @impl true
  def close(state, :done) do
    binary = state.chunks |> Enum.reverse() |> IO.iodata_to_binary()

    case process_image(binary, state) do
      {:ok, processed_binary} ->
        notify_ready(state, processed_binary)
        {:ok, %{state | processed_binary: processed_binary, chunks: []}}

      {:error, reason} ->
        notify_progress(state, :error, reason)
        {:ok, %{state | chunks: [], error: reason}}

      {:nsfw, message} ->
        notify_progress(state, :error, {:nsfw, message})
        {:ok, %{state | chunks: [], error: {:nsfw, message}}}
    end
  end

  def close(state, :cancel) do
    {:ok, %{state | chunks: []}}
  end

  def close(state, {:error, _reason}) do
    {:ok, %{state | chunks: []}}
  end

  defp process_image(binary, state) do
    mime_type = ExMarcel.MimeType.for({:string, binary})

    notify_progress(state, :validating, 45)

    with {:ok, image} <- load_image(binary, mime_type),
         {:ok, image} <- check_safety(image, state),
         :ok <- notify_progress(state, :processing, 55),
         {:ok, image} <- autorotate(image),
         {:ok, image} <- remove_metadata(image),
         {:ok, image} <- resize_image(image),
         {:ok, image} <- to_srgb(image),
         :ok <- notify_progress(state, :processing, 70),
         {:ok, webp_binary} <- to_webp_binary(image),
         :ok <- notify_progress(state, :processing, 90) do
      {:ok, webp_binary}
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

  defp load_image(binary, mime_type)
       when mime_type in ["image/jpeg", "image/jpg", "image/png", "image/webp", "image/gif"] do
    case Image.from_binary(binary) do
      {:ok, image} -> {:ok, image}
      {:error, reason} -> {:error, "Failed to load image: #{inspect(reason)}"}
    end
  end

  defp load_image(_binary, mime_type) do
    {:error, "Unsupported image type: #{mime_type}"}
  end

  defp load_heic_with_sips(binary) do
    tmp_heic = Path.join(System.tmp_dir!(), "heic_#{:erlang.unique_integer([:positive])}.heic")
    tmp_png = Path.join(System.tmp_dir!(), "heic_#{:erlang.unique_integer([:positive])}.png")

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
              {:error, heic_error_message("sips conversion failed")}
          end

        {:unix, _linux} ->
          case System.cmd("heif-convert", [tmp_heic, tmp_png], stderr_to_stdout: true) do
            {_output, 0} ->
              png_binary = File.read!(tmp_png)

              Image.from_binary(png_binary)

            {_output, _code} ->
              {:error, heic_error_message("heif-convert failed")}
          end

        _ ->
          {:error, heic_error_message("Unsupported platform for HEIC conversion")}
      end

    File.rm(tmp_heic)
    File.rm(tmp_png)
    result
  end

  defp materialize_heic(image) do
    srgb_image =
      case Image.to_colorspace(image, :srgb) do
        {:ok, srgb} -> srgb
        {:error, _} -> image
      end

    case Vix.Vips.Operation.rawsave_buffer(srgb_image) do
      {:ok, raw_binary} ->
        raw_width = Image.width(srgb_image)
        raw_height = Image.height(srgb_image)
        raw_bands = Image.bands(srgb_image)

        case Vix.Vips.Operation.rawload(raw_binary, raw_width, raw_height, raw_bands) do
          {:ok, {raw_image, _}} ->
            case Image.to_colorspace(raw_image, :srgb) do
              {:ok, final} ->
                {:ok, final}

              {:error, _} ->
                {:ok, raw_image}
            end

          {:error, _rawload_reason} ->
            fallback_heic_materialization(srgb_image)
        end

      {:error, _rawsave_reason} ->
        fallback_heic_materialization(srgb_image)
    end
  end

  defp fallback_heic_materialization(image) do
    case Image.write(image, :memory, suffix: ".png") do
      {:ok, png_binary} ->
        Image.from_binary(png_binary)

      {:error, _reason} ->
        case Image.write(image, :memory, suffix: ".jpg") do
          {:ok, jpg_binary} ->
            Image.from_binary(jpg_binary)

          {:error, _jpg_reason} ->
            {:error, "Failed to materialize HEIC image"}
        end
    end
  end

  defp check_safety(image, state) do
    notify_progress(state, :validating, 50)

    case Mosslet.AI.Images.check_for_safety(image) do
      {:ok, _} ->
        {:ok, image}

      {:nsfw, message} ->
        {:nsfw, message}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp autorotate(image) do
    case Image.autorotate(image) do
      {:ok, {rotated_image, _flags}} -> {:ok, rotated_image}
      {:error, reason} -> {:error, "Failed to autorotate: #{inspect(reason)}"}
    end
  end

  defp remove_metadata(image) do
    Image.remove_metadata(image)
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

  defp to_srgb(image) do
    {:ok, Image.to_colorspace!(image, :srgb)}
  end

  defp to_webp_binary(image) do
    quality = calculate_adaptive_quality(image)

    case Image.write(image, :memory, suffix: ".webp", webp: [quality: quality]) do
      {:ok, binary} -> {:ok, binary}
      {:error, reason} -> {:error, "Failed to convert to WebP: #{inspect(reason)}"}
    end
  end

  @doc """
  Uploads a processed image binary to cloud storage.

  Called at form submission time by process_uploaded_photos.
  Returns `{:ok, file_path}` on success or `{:error, reason}` on failure.
  """
  def upload_to_storage(binary, trix_key) do
    storage_key = Ecto.UUID.generate()
    file_path = "#{@folder}/#{storage_key}.webp"

    with {:ok, encrypted} <- encrypt_file(binary, trix_key),
         {:ok, _resp} <- put_object(file_path, encrypted) do
      {:ok, file_path}
    end
  end

  defp generate_trix_key(_user, _visibility) do
    Encrypted.Utils.generate_key()
  end

  defp encrypt_file(binary, trix_key) do
    encrypted = Encrypted.Utils.encrypt(%{key: trix_key, payload: binary})
    {:ok, encrypted}
  end

  defp put_object(file_path, data) do
    bucket = Encrypted.Session.memories_bucket()

    case ExAws.S3.put_object(bucket, file_path, data) |> ExAws.request() do
      {:ok, %{status_code: 200}} -> {:ok, :uploaded}
      {:ok, resp} -> {:error, "Upload failed: #{inspect(resp)}"}
      {:error, _} = error -> error
    end
  end

  defp calculate_adaptive_quality(image) do
    width = Image.width(image)
    height = Image.height(image)
    total_pixels = width * height

    cond do
      total_pixels < 500_000 -> 90
      total_pixels < 2_000_000 -> 85
      true -> 80
    end
  end

  defp heic_error_message(reason) when is_binary(reason) do
    if String.contains?(reason, "compression format has not been built in") do
      "HEIC/HEIF files are not supported. Please convert to JPEG or PNG."
    else
      "Failed to process HEIC/HEIF image. Please try a different format."
    end
  end

  defp heic_error_message(_reason) do
    "Failed to process HEIC/HEIF image. Please try a different format."
  end

  defp notify_ready(state, processed_binary) do
    if state.lv_pid do
      send(
        state.lv_pid,
        {:upload_ready, state.entry_ref,
         %{
           processed_binary: processed_binary,
           trix_key: state.trix_key
         }}
      )
    end

    :ok
  end

  defp notify_progress(state, stage, value) do
    if state.lv_pid do
      send(state.lv_pid, {:upload_progress, state.entry_ref, stage, value})
    end

    :ok
  end
end
