defmodule Mosslet.FileUploads.JournalImageWriter do
  @moduledoc """
  A memory-efficient LiveView.UploadWriter for journal image OCR.

  Key features:
  - Streams chunks to disk instead of accumulating in memory
  - Validates MIME type from actual file content (magic bytes)
  - Resizes large images to reduce memory during OCR
  - Cleans up temp files automatically
  - No encryption (images are ephemeral, deleted after OCR)

  Processing stages:
  1. Receiving chunks → temp file (0-40% progress)
  2. MIME validation & resize to JPEG (40-50%)
  3. OCR text extraction (50-85%)
  4. Date extraction from text (85-95%)
  5. Ready state with cleanup (95-100%)
  """

  @behaviour Phoenix.LiveView.UploadWriter

  alias Mosslet.FileUploads.TempStorage

  @max_dimension 1280
  @allowed_mimes ~w(image/jpeg image/png image/heic image/heif)
  @temp_subdir "journal_ocr"
  @mime_header_size 12

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
          client_mime: opts[:mime_type] || "image/jpeg",
          extracted_text: nil,
          extracted_date: nil,
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

      state.extracted_text ->
        %{extracted_text: state.extracted_text, extracted_date: state.extracted_date}

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
           {:ok, processed_binary, final_mime} <-
             process_for_ocr(state.temp_path, mime_type, state),
           {:ok, extracted_text, extracted_date} <-
             extract_text_from_image(processed_binary, final_mime, state) do
        notify_progress(state, :ready, %{text: extracted_text, date: extracted_date})
        {:ok, extracted_text, extracted_date}
      end

    TempStorage.cleanup(state.temp_path)

    case result do
      {:ok, extracted_text, extracted_date} ->
        {:ok,
         %{
           state
           | extracted_text: extracted_text,
             extracted_date: extracted_date,
             file_handle: nil
         }}

      {:error, reason} ->
        notify_progress(state, :error, reason)
        {:ok, %{state | error: reason, file_handle: nil}}
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
              {:error,
               "Invalid image type: #{detected_mime || "unknown"}. Allowed: JPEG, PNG, HEIC"}
            end
        end

      {:error, reason} ->
        {:error, "Failed to open file: #{inspect(reason)}"}
    end
  end

  defp process_for_ocr(temp_path, mime_type, state) do
    notify_progress(state, :processing, 42)

    with {:ok, image} <- open_image(temp_path, mime_type),
         {:ok, resized} <- resize_for_ocr(image),
         {:ok, jpeg_binary} <- to_jpeg_binary(resized) do
      notify_progress(state, :processing, 50)
      {:ok, jpeg_binary, "image/jpeg"}
    else
      {:error, reason} when is_binary(reason) ->
        {:error, reason}

      {:error, reason} ->
        {:error, "Image processing failed: #{inspect(reason)}"}
    end
  end

  defp open_image(path, mime_type) when mime_type in ["image/heic", "image/heif"] do
    tmp_jpg = TempStorage.temp_path(@temp_subdir, "heic_output")

    try do
      result =
        case :os.type() do
          {:unix, :darwin} ->
            case System.cmd("sips", ["-s", "format", "jpeg", path, "--out", tmp_jpg],
                   stderr_to_stdout: true
                 ) do
              {_output, 0} -> Image.open(tmp_jpg)
              {_output, _code} -> {:error, "Failed to convert HEIC image"}
            end

          {:unix, _linux} ->
            case System.cmd("heif-convert", ["-q", "85", path, tmp_jpg], stderr_to_stdout: true) do
              {_output, 0} -> Image.open(tmp_jpg)
              {_output, _code} -> {:error, "Failed to convert HEIC image"}
            end

          _ ->
            {:error, "HEIC conversion not supported on this platform"}
        end

      result
    after
      TempStorage.cleanup(tmp_jpg)
    end
  end

  defp open_image(path, _mime_type) do
    case Image.open(path) do
      {:ok, image} -> {:ok, image}
      {:error, reason} -> {:error, "Failed to load image: #{inspect(reason)}"}
    end
  end

  defp resize_for_ocr(image) do
    width = Image.width(image)
    height = Image.height(image)

    if width > @max_dimension or height > @max_dimension do
      Image.thumbnail(image, "#{@max_dimension}x#{@max_dimension}")
    else
      {:ok, image}
    end
  end

  defp to_jpeg_binary(image) do
    case Image.write(image, :memory, suffix: ".jpg", quality: 85, strip_metadata: true) do
      {:ok, binary} -> {:ok, binary}
      {:error, reason} -> {:error, "Failed to convert to JPEG: #{inspect(reason)}"}
    end
  end

  defp extract_text_from_image(binary, mime_type, state) do
    notify_progress(state, :extracting, 55)

    alias ReqLLM.Message.ContentPart

    system_prompt = """
    You are an expert OCR assistant that extracts handwritten text from journal images.

    Guidelines:
    - Extract ALL visible handwritten text from the image accurately
    - Preserve paragraph breaks and line structure where sensible
    - Correct obvious spelling errors only if you're highly confident
    - If text is unclear, make your best interpretation
    - Do not add any commentary, explanations, or metadata
    - Return ONLY the extracted text, nothing else
    - If the image contains no readable text, respond with: [No readable text found]

    Privacy note: This content is private journal writing. Process it respectfully and return only the text.
    """

    content = [
      ContentPart.image(binary, mime_type),
      ContentPart.text("Please extract all the handwritten text from this journal image.")
    ]

    message = %ReqLLM.Message{role: :user, content: content}

    notify_progress(state, :extracting, 70)

    case ReqLLM.generate_text("openrouter:openai/gpt-4o-mini", [message],
           system_prompt: system_prompt
         ) do
      {:ok, response} ->
        text = ReqLLM.Response.text(response)

        if text == "[No readable text found]" do
          {:error, :no_text_found}
        else
          notify_progress(state, :analyzing, 90)
          extracted_date = extract_date_from_text(text)
          {:ok, text, extracted_date}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Extracts a date from the beginning of journal text.

  Looks for common date patterns at the start of text:
  - "January 15, 2024" or "Jan 15, 2024"
  - "1/15/2024" or "01/15/2024"
  - "15/1/2024" or "15/01/2024"
  - "2024-01-15"
  - "Monday, January 15" (uses current year)
  - "January 15" (uses current year)
  """
  def extract_date_from_text(text) when is_binary(text) do
    first_lines = text |> String.split("\n", parts: 3) |> Enum.take(2) |> Enum.join(" ")

    patterns = [
      ~r/^(?:(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),?\s+)?(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})/i,
      ~r/^(?:(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),?\s+)?(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})/i,
      ~r/^(?:(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),?\s+)?(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s*(\d{4})?/i,
      ~r/^(?:(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),?\s+)?(\d{1,2})(?:st|nd|rd|th)?\s+(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\.?,?\s*(\d{4})?/i
    ]

    Enum.find_value(patterns, fn pattern ->
      case Regex.run(pattern, first_lines) do
        nil -> nil
        captures -> parse_date_captures(captures, pattern)
      end
    end)
  end

  def extract_date_from_text(_), do: nil

  defp parse_date_captures([_full | captures], pattern) do
    source = Regex.source(pattern)
    current_year = Date.utc_today().year

    cond do
      String.contains?(source, "(\\d{4})[") ->
        [year, month, day] = captures
        parse_ymd(year, month, day)

      String.contains?(source, "(\\d{1,2})[") and length(captures) >= 3 ->
        [month_or_day, day_or_month, year] = Enum.take(captures, 3)
        parse_mdy(month_or_day, day_or_month, year)

      String.contains?(source, "(January|") and not String.contains?(source, ")(January|") ->
        case captures do
          [month_name, day] -> parse_month_day(month_name, day, current_year)
          [month_name, day, nil] -> parse_month_day(month_name, day, current_year)
          [month_name, day, ""] -> parse_month_day(month_name, day, current_year)
          [month_name, day, year] -> parse_month_day(month_name, day, parse_int(year))
          _ -> nil
        end

      String.contains?(source, ")(January|") ->
        case captures do
          [day, month_name] -> parse_day_month(day, month_name, current_year)
          [day, month_name, nil] -> parse_day_month(day, month_name, current_year)
          [day, month_name, ""] -> parse_day_month(day, month_name, current_year)
          [day, month_name, year] -> parse_day_month(day, month_name, parse_int(year))
          _ -> nil
        end

      true ->
        nil
    end
  end

  defp parse_ymd(year, month, day) do
    Date.new(parse_int(year), parse_int(month), parse_int(day)) |> ok_or_nil()
  end

  defp parse_mdy(month, day, year) do
    Date.new(parse_int(year), parse_int(month), parse_int(day)) |> ok_or_nil()
  end

  defp parse_month_day(month_name, day, year) do
    month = month_name_to_number(month_name)
    if month, do: Date.new(year, month, parse_int(day)) |> ok_or_nil(), else: nil
  end

  defp parse_day_month(day, month_name, year) do
    month = month_name_to_number(month_name)
    if month, do: Date.new(year, month, parse_int(day)) |> ok_or_nil(), else: nil
  end

  defp parse_int(str) when is_binary(str), do: String.to_integer(str)
  defp parse_int(int) when is_integer(int), do: int

  defp ok_or_nil({:ok, date}), do: date
  defp ok_or_nil(_), do: nil

  defp month_name_to_number(name) do
    name = String.downcase(name)

    months = %{
      "january" => 1,
      "jan" => 1,
      "february" => 2,
      "feb" => 2,
      "march" => 3,
      "mar" => 3,
      "april" => 4,
      "apr" => 4,
      "may" => 5,
      "june" => 6,
      "jun" => 6,
      "july" => 7,
      "jul" => 7,
      "august" => 8,
      "aug" => 8,
      "september" => 9,
      "sep" => 9,
      "sept" => 9,
      "october" => 10,
      "oct" => 10,
      "november" => 11,
      "nov" => 11,
      "december" => 12,
      "dec" => 12
    }

    Map.get(months, name)
  end

  defp notify_progress(state, stage, value) do
    if state.lv_pid do
      send(state.lv_pid, {:journal_upload_progress, state.entry_ref, stage, value})
    end

    :ok
  end
end
