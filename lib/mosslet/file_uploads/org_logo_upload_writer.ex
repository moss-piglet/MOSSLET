defmodule Mosslet.FileUploads.OrgLogoUploadWriter do
  @moduledoc """
  A `Phoenix.LiveView.UploadWriter` for org brand-logo uploads (Task #228,
  branding add-on). Models `Mosslet.FileUploads.AvatarUploadWriter`: streams
  chunks to a temp file, then processes the image (autorotate, contain-fit
  within a max box, convert to WebP) and hands the final bytes back to the
  LiveView for browser-side ZK encryption with the per-org `org_key`.

  The server NEVER encrypts or persists the logo here — it only prepares the
  display-ready bytes. The LiveView pushes those bytes to the browser
  (`encrypt_org_logo`), the browser encrypts with the `org_key` and pushes the
  ciphertext back, and only the opaque blob is stored (invariants I2/I3).

  ## Stages

  1. Receiving chunks → temp file (0-40%)
  2. Image processing: autorotate, fit, WebP (40-90%)
  3. Ready — bytes prepared for browser-side encryption (90-100%)

  ## Progress messages (sent to the LiveView process)

  - `{:org_logo_upload_progress, entry_ref, :receiving, percent}`
  - `{:org_logo_upload_progress, entry_ref, :processing, percent}`
  - `{:org_logo_upload_ready, entry_ref, %{webp_binary: bin, preview_data_url: url}}`
  - `{:org_logo_upload_error, entry_ref, reason}`
  """

  @behaviour Phoenix.LiveView.UploadWriter

  alias Mosslet.FileUploads.TempStorage

  @temp_subdir "org_logo_uploads"

  # Logos are display assets, not photos — contain-fit within a modest box so
  # blobs stay small (and the encrypted payload likewise).
  @max_dimension 512

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
          webp_binary: nil,
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

      state.webp_binary ->
        %{preview_data_url: state.preview_data_url}

      true ->
        %{stage: state.stage}
    end
  end

  @impl true
  def write_chunk(data, state) do
    size = byte_size(data)
    new_total = state.total_size + size

    :ok = IO.binwrite(state.file_handle, data)

    if state.lv_pid && state.expected_size && state.expected_size > 0 do
      percent = min(40, round(new_total / state.expected_size * 40))
      send(state.lv_pid, {:org_logo_upload_progress, state.entry_ref, :receiving, percent})
    end

    {:ok, %{state | total_size: new_total}}
  end

  @impl true
  def close(state, :done) do
    File.close(state.file_handle)

    result =
      with {:ok, binary} <- File.read(state.temp_path),
           result <- process_logo(binary, state) do
        result
      end

    TempStorage.cleanup(state.temp_path)

    case result do
      {:ok, webp_binary, preview_data_url} ->
        if state.lv_pid do
          send(
            state.lv_pid,
            {:org_logo_upload_ready, state.entry_ref,
             %{webp_binary: webp_binary, preview_data_url: preview_data_url}}
          )
        end

        {:ok,
         %{
           state
           | webp_binary: webp_binary,
             preview_data_url: preview_data_url,
             file_handle: nil
         }}

      {:error, reason} ->
        if state.lv_pid do
          send(state.lv_pid, {:org_logo_upload_error, state.entry_ref, reason})
        end

        {:ok, %{state | file_handle: nil, error: reason}}
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

  defp process_logo(binary, state) do
    mime_type = ExMarcel.MimeType.for({:string, binary})
    notify_progress(state, :processing, 45)

    result =
      cond do
        mime_type in ["image/heic", "image/heif"] ->
          process_heic(binary, state)

        mime_type in ["image/jpeg", "image/jpg", "image/png", "image/webp"] ->
          process_standard_image(binary, state)

        true ->
          {:error, "Unsupported image type: #{mime_type}"}
      end

    case result do
      {:ok, webp_binary} ->
        notify_progress(state, :processing, 80)
        preview = generate_preview(webp_binary)
        notify_progress(state, :processing, 100)
        {:ok, webp_binary, preview}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_standard_image(binary, state) do
    with {:ok, image} <- Image.from_binary(binary),
         notify_progress(state, :processing, 55),
         {:ok, image} <- autorotate(image),
         notify_progress(state, :processing, 60),
         {:ok, image} <- contain_fit(image),
         notify_progress(state, :processing, 70),
         {:ok, webp_binary} <- Image.write(image, :memory, suffix: ".webp", quality: 90) do
      {:ok, webp_binary}
    end
  end

  defp process_heic(binary, state) do
    with {:ok, image} <- load_heic(binary),
         notify_progress(state, :processing, 55),
         {:ok, image} <- autorotate(image),
         notify_progress(state, :processing, 60),
         {:ok, image} <- contain_fit(image),
         notify_progress(state, :processing, 70),
         {:ok, webp_binary} <- Image.write(image, :memory, suffix: ".webp", quality: 90) do
      {:ok, webp_binary}
    end
  end

  # Scale the logo down so its longest edge is at most @max_dimension, preserving
  # aspect ratio. Never upscales (a small logo stays crisp).
  defp contain_fit(image) do
    width = Image.width(image)
    height = Image.height(image)
    longest = max(width, height)

    if longest <= @max_dimension do
      {:ok, image}
    else
      case Image.resize(image, @max_dimension / longest) do
        {:ok, resized} -> {:ok, resized}
        {:error, reason} -> {:error, "Failed to resize logo: #{inspect(reason)}"}
      end
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

  defp generate_preview(binary) do
    case Image.from_binary(binary) do
      {:ok, image} ->
        case Image.thumbnail(image, "256x256", crop: :none) do
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
      send(state.lv_pid, {:org_logo_upload_progress, state.entry_ref, stage, value})
    end

    :ok
  end
end
