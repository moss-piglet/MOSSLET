defmodule Mosslet.FileUploads.JournalImageWriter do
  @moduledoc """
  A custom LiveView.UploadWriter that handles journal image OCR with
  streaming progress feedback.

  This writer processes images in stages with real-time progress updates:
  1. Receiving chunks (0-40% progress)
  2. OCR text extraction (40-85%)
  3. Date extraction from text (85-95%)
  4. Ready state (95-100%)

  ## Usage

      allow_upload(:journal_image,
        accept: ~w(.gif .jpg .jpeg .png .webp .heic .heif),
        max_entries: 1,
        auto_upload: true,
        progress: &handle_journal_upload_progress/3,
        writer: fn _name, entry, socket ->
          {Mosslet.FileUploads.JournalImageWriter, %{
            lv_pid: self(),
            entry_ref: entry.ref,
            expected_size: entry.client_size
          }}
        end
      )

  ## Progress Events

  The writer sends messages to the LiveView process:
  - `{:journal_upload_progress, entry_ref, :receiving, percent}` - Chunk reception
  - `{:journal_upload_progress, entry_ref, :extracting, percent}` - OCR in progress
  - `{:journal_upload_progress, entry_ref, :analyzing, percent}` - Date extraction
  - `{:journal_upload_progress, entry_ref, :ready, data}` - Ready with extracted data
  - `{:journal_upload_progress, entry_ref, :error, reason}` - Error occurred

  ## Consuming

  When consuming, `meta` returns:
  - `%{extracted_text: text, extracted_date: date}` - Extracted data
  - `%{error: reason}` - If processing failed
  """

  @behaviour Phoenix.LiveView.UploadWriter

  @impl true
  def init(opts) do
    state = %{
      chunks: [],
      total_size: 0,
      expected_size: opts[:expected_size],
      lv_pid: opts[:lv_pid],
      entry_ref: opts[:entry_ref],
      mime_type: opts[:mime_type] || "image/jpeg",
      extracted_text: nil,
      extracted_date: nil,
      error: nil,
      stage: :receiving
    }

    {:ok, state}
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
    new_state = %{state | chunks: [data | state.chunks], total_size: new_total}

    if state.lv_pid && state.expected_size && state.expected_size > 0 do
      percent = min(40, round(new_total / state.expected_size * 40))
      notify_progress(state, :receiving, percent)
    end

    {:ok, new_state}
  end

  @impl true
  def close(state, :done) do
    binary = state.chunks |> Enum.reverse() |> IO.iodata_to_binary()
    mime_type = detect_mime_type(binary, state.mime_type)

    case process_journal_image(binary, mime_type, state) do
      {:ok, extracted_text, extracted_date} ->
        notify_progress(state, :ready, %{text: extracted_text, date: extracted_date})

        {:ok,
         %{state | extracted_text: extracted_text, extracted_date: extracted_date, chunks: []}}

      {:error, reason} ->
        notify_progress(state, :error, reason)
        {:ok, %{state | chunks: [], error: reason}}
    end
  end

  def close(state, :cancel) do
    {:ok, %{state | chunks: []}}
  end

  def close(state, {:error, _reason}) do
    {:ok, %{state | chunks: []}}
  end

  defp detect_mime_type(binary, fallback) do
    case ExMarcel.MimeType.for({:string, binary}) do
      nil -> fallback
      mime -> mime
    end
  end

  defp process_journal_image(binary, mime_type, state) do
    notify_progress(state, :extracting, 45)

    binary
    |> maybe_convert_heic(mime_type)
    |> extract_text_from_image(state)
  end

  defp maybe_convert_heic(binary, mime_type) when mime_type in ["image/heic", "image/heif"] do
    tmp_heic =
      Path.join(System.tmp_dir!(), "journal_heic_#{:erlang.unique_integer([:positive])}.heic")

    tmp_jpg =
      Path.join(System.tmp_dir!(), "journal_heic_#{:erlang.unique_integer([:positive])}.jpg")

    try do
      :ok = File.write(tmp_heic, binary)

      result =
        case :os.type() do
          {:unix, :darwin} ->
            case System.cmd("sips", ["-s", "format", "jpeg", tmp_heic, "--out", tmp_jpg],
                   stderr_to_stdout: true
                 ) do
              {_output, 0} -> {:ok, File.read!(tmp_jpg), "image/jpeg"}
              {_output, _code} -> {:error, "Failed to convert HEIC image"}
            end

          {:unix, _linux} ->
            case System.cmd("heif-convert", ["-q", "85", tmp_heic, tmp_jpg],
                   stderr_to_stdout: true
                 ) do
              {_output, 0} -> {:ok, File.read!(tmp_jpg), "image/jpeg"}
              {_output, _code} -> {:error, "Failed to convert HEIC image"}
            end

          _ ->
            {:error, "HEIC conversion not supported on this platform"}
        end

      result
    after
      File.rm(tmp_heic)
      File.rm(tmp_jpg)
    end
  end

  defp maybe_convert_heic(binary, mime_type), do: {:ok, binary, mime_type}

  defp extract_text_from_image({:error, reason}, _state), do: {:error, reason}

  defp extract_text_from_image({:ok, binary, mime_type}, state) do
    notify_progress(state, :extracting, 60)

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
