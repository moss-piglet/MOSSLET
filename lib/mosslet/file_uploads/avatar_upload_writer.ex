defmodule Mosslet.FileUploads.AvatarUploadWriter do
  @moduledoc """
  A LiveView.UploadWriter for avatar uploads that processes images and keeps
  entries in place until form submission.

  This writer streams chunks to disk then processes in stages:
  1. Receiving chunks → temp file (0-40% progress)
  2. Image processing: autorotate, convert to WebP (40-90%)
  3. Ready state - image prepared for editing/cropping (90-100%)

  ## Usage

      allow_upload(:avatar,
        accept: ~w(.jpg .jpeg .png .webp .heic .heif),
        max_entries: 1,
        auto_upload: true,
        progress: &handle_progress/3,
        writer: fn _name, entry, socket ->
          {Mosslet.FileUploads.AvatarUploadWriter, %{
            lv_pid: self(),
            entry_ref: entry.ref
          }}
        end
      )

  ## Progress Events

  The writer sends messages to the LiveView process:
  - `{:avatar_upload_progress, entry_ref, :receiving, percent}` - Chunk reception
  - `{:avatar_upload_progress, entry_ref, :processing, percent}` - Image processing
  - `{:avatar_upload_ready, entry_ref, %{temp_path: path, preview_data_url: url}}` - Ready
  - `{:avatar_upload_error, entry_ref, reason}` - Error occurred
  """

  @behaviour Phoenix.LiveView.UploadWriter

  require Logger

  alias Mosslet.FileUploads.TempStorage

  @temp_subdir "avatar_uploads"

  @impl true
  def init(opts) do
    entry_ref = opts[:entry_ref]
    temp_path = TempStorage.temp_path(@temp_subdir, entry_ref) <> "_raw"

    case File.open(temp_path, [:write, :binary]) do
      {:ok, file_handle} ->
        state = %{
          temp_path: temp_path,
          file_handle: file_handle,
          total_size: 0,
          expected_size: opts[:expected_size],
          lv_pid: opts[:lv_pid],
          entry_ref: entry_ref,
          processed_path: nil,
          preview_data_url: nil,
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

      state.processed_path ->
        %{
          temp_path: state.processed_path,
          preview_data_url: state.preview_data_url
        }

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
          percent = min(40, round(new_total / state.expected_size * 40))
          send(state.lv_pid, {:avatar_upload_progress, state.entry_ref, :receiving, percent})
        end

        {:ok, %{state | total_size: new_total}}

      {:error, reason} ->
        {:error, "Failed to write chunk: #{inspect(reason)}"}
    end
  end

  @impl true
  def close(state, :done) do
    File.close(state.file_handle)

    result =
      with {:ok, binary} <- File.read(state.temp_path),
           result <- process_avatar(binary, state) do
        result
      end

    TempStorage.cleanup(state.temp_path)

    case result do
      {:ok, processed_path, preview_data_url} ->
        if state.lv_pid do
          send(
            state.lv_pid,
            {:avatar_upload_ready, state.entry_ref,
             %{
               temp_path: processed_path,
               preview_data_url: preview_data_url
             }}
          )
        end

        {:ok,
         %{
           state
           | processed_path: processed_path,
             preview_data_url: preview_data_url,
             file_handle: nil
         }}

      {:error, reason} ->
        if state.lv_pid do
          send(state.lv_pid, {:avatar_upload_error, state.entry_ref, reason})
        end

        {:ok, %{state | file_handle: nil, error: reason}}
    end
  end

  def close(state, :cancel) do
    File.close(state.file_handle)
    TempStorage.cleanup(state.temp_path)
    if state.processed_path, do: TempStorage.cleanup(state.processed_path)
    {:ok, %{state | file_handle: nil}}
  end

  def close(state, {:error, _reason}) do
    File.close(state.file_handle)
    TempStorage.cleanup(state.temp_path)
    if state.processed_path, do: TempStorage.cleanup(state.processed_path)
    {:ok, %{state | file_handle: nil}}
  end

  defp process_avatar(binary, state) do
    mime_type = ExMarcel.MimeType.for({:string, binary})
    notify_progress(state, :processing, 45)

    processed_path = TempStorage.temp_path(@temp_subdir, state.entry_ref) <> ".webp"

    result =
      cond do
        mime_type in ["image/heic", "image/heif"] ->
          process_heic(binary, processed_path, state)

        mime_type in ["image/jpeg", "image/jpg", "image/png", "image/webp"] ->
          process_standard_image(binary, processed_path, state)

        true ->
          {:error, "Unsupported image type: #{mime_type}"}
      end

    case result do
      {:ok, webp_binary} ->
        File.write!(processed_path, webp_binary)
        notify_progress(state, :processing, 80)
        preview = generate_thumbnail_preview(webp_binary)
        notify_progress(state, :processing, 100)
        {:ok, processed_path, preview}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_standard_image(binary, _processed_path, state) do
    with {:ok, image} <- Image.from_binary(binary),
         notify_progress(state, :processing, 55),
         {:ok, image} <- autorotate(image),
         notify_progress(state, :processing, 65),
         {:ok, webp_binary} <- Image.write(image, :memory, suffix: ".webp", quality: 90) do
      {:ok, webp_binary}
    end
  end

  defp process_heic(binary, _processed_path, state) do
    with {:ok, image} <- load_heic(binary),
         notify_progress(state, :processing, 55),
         {:ok, image} <- autorotate(image),
         notify_progress(state, :processing, 65),
         {:ok, webp_binary} <- Image.write(image, :memory, suffix: ".webp", quality: 90) do
      {:ok, webp_binary}
    end
  end

  defp load_heic(binary) do
    with {:ok, {heic_image, _metadata}} <- Vix.Vips.Operation.heifload_buffer(binary),
         {:ok, materialized} <- materialize_heic(heic_image) do
      {:ok, materialized}
    else
      {:error, _reason} ->
        load_heic_with_sips(binary)
    end
  end

  defp materialize_heic(image) do
    case Image.to_colorspace(image, :srgb) do
      {:ok, srgb_image} ->
        case Image.write(srgb_image, :memory, suffix: ".png") do
          {:ok, png_binary} -> Image.from_binary(png_binary)
          {:error, _} -> fallback_heic_materialization(srgb_image)
        end

      {:error, _} ->
        fallback_heic_materialization(image)
    end
  end

  defp fallback_heic_materialization(image) do
    case Image.write(image, :memory, suffix: ".png") do
      {:ok, png_binary} ->
        Image.from_binary(png_binary)

      {:error, _} ->
        case Image.write(image, :memory, suffix: ".jpg") do
          {:ok, jpg_binary} -> Image.from_binary(jpg_binary)
          {:error, reason} -> {:error, "Failed to materialize HEIC image: #{inspect(reason)}"}
        end
    end
  end

  defp load_heic_with_sips(binary) do
    tmp_heic =
      TempStorage.temp_path(@temp_subdir, "heic_input_#{:erlang.unique_integer([:positive])}")

    tmp_png =
      TempStorage.temp_path(
        @temp_subdir,
        "heic_output_#{:erlang.unique_integer([:positive])}.png"
      )

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

  defp autorotate(image) do
    case Image.autorotate(image) do
      {:ok, {rotated_image, _flags}} -> {:ok, rotated_image}
      {:error, reason} -> {:error, "Failed to autorotate: #{inspect(reason)}"}
    end
  end

  defp generate_thumbnail_preview(binary) do
    case Image.from_binary(binary) do
      {:ok, image} ->
        case Image.thumbnail(image, "400x400", crop: :attention) do
          {:ok, thumb} ->
            case Image.write(thumb, :memory, suffix: ".webp", quality: 75) do
              {:ok, thumb_binary} ->
                "data:image/webp;base64,#{Base.encode64(thumb_binary)}"

              _ ->
                nil
            end

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  defp notify_progress(state, stage, value) do
    if state.lv_pid do
      send(state.lv_pid, {:avatar_upload_progress, state.entry_ref, stage, value})
    end

    :ok
  end
end
