defmodule Mosslet.Journal.Export do
  @moduledoc """
  Exports journal books and entries in various formats.

  All entries are decrypted before export using the user's session key.
  Supported formats: :csv, :txt, :pdf, :markdown
  """

  alias Mosslet.Journal

  @page_width 595
  @page_height 842
  @margin 60
  @content_width @page_width - 2 * @margin

  def export(user, key, format) when format in [:csv, :txt, :pdf, :markdown] do
    books = Journal.list_books(user)

    decrypted_books =
      Enum.map(books, fn book ->
        decrypted_book = Journal.decrypt_book(book, user, key)

        entries =
          Journal.list_journal_entries(user,
            book_id: book.id,
            limit: 100_000,
            order: :asc
          )

        decrypted_entries = Enum.map(entries, &Journal.decrypt_entry(&1, user, key))

        {decrypted_book, decrypted_entries}
      end)

    loose_entries = Journal.list_loose_entries(user, limit: 100_000)

    decrypted_loose =
      loose_entries
      |> Enum.map(&Journal.decrypt_entry(&1, user, key))
      |> Enum.sort_by(& &1.entry_date, {:asc, Date})

    all_data = {decrypted_books, decrypted_loose}

    case format do
      :csv -> generate_csv(all_data)
      :txt -> generate_txt(all_data)
      :pdf -> generate_pdf(all_data)
      :markdown -> generate_markdown(all_data)
    end
  end

  defp generate_csv({books, loose_entries}) do
    header = "Book,Date,Title,Mood,Favorite,Word Count,Entry\r\n"

    book_rows =
      Enum.flat_map(books, fn {book, entries} ->
        Enum.map(entries, fn entry ->
          csv_row(book.title || "Untitled Book", entry)
        end)
      end)

    loose_rows = Enum.map(loose_entries, fn entry -> csv_row("(No Book)", entry) end)

    data = IO.iodata_to_binary([header | book_rows ++ loose_rows])
    {:ok, data, "journal_export.csv", "text/csv"}
  end

  defp csv_row(book_name, entry) do
    [
      csv_escape(book_name),
      csv_escape(to_string(entry.entry_date)),
      csv_escape(entry.title || ""),
      csv_escape(entry.mood || ""),
      csv_escape(if(entry.is_favorite, do: "Yes", else: "No")),
      csv_escape(to_string(entry.word_count || 0)),
      csv_escape(entry.body || "")
    ]
    |> Enum.join(",")
    |> Kernel.<>("\r\n")
  end

  defp csv_escape(value) when is_binary(value) do
    if String.contains?(value, [",", "\"", "\n", "\r"]) do
      "\"" <> String.replace(value, "\"", "\"\"") <> "\""
    else
      value
    end
  end

  defp csv_escape(value), do: csv_escape(to_string(value))

  defp generate_txt({books, loose_entries}) do
    parts =
      [
        "MOSSLET JOURNAL EXPORT",
        "Exported: #{Date.utc_today()}",
        String.duplicate("=", 60),
        ""
      ]

    book_parts =
      Enum.flat_map(books, fn {book, entries} ->
        [
          "",
          String.duplicate("─", 60),
          "📖 #{book.title || "Untitled Book"}",
          if(book.description, do: "   #{book.description}", else: nil),
          "   #{length(entries)} entries",
          String.duplicate("─", 60),
          ""
          | Enum.flat_map(entries, &format_entry_txt/1)
        ]
        |> Enum.reject(&is_nil/1)
      end)

    loose_parts =
      if loose_entries != [] do
        [
          "",
          String.duplicate("─", 60),
          "📝 Entries Without a Book",
          "   #{length(loose_entries)} entries",
          String.duplicate("─", 60),
          ""
          | Enum.flat_map(loose_entries, &format_entry_txt/1)
        ]
      else
        []
      end

    data = Enum.join(parts ++ book_parts ++ loose_parts, "\n")
    {:ok, data, "journal_export.txt", "text/plain"}
  end

  defp format_entry_txt(entry) do
    lines = [
      "  📅 #{entry.entry_date}#{if entry.is_favorite, do: " ⭐", else: ""}",
      if(entry.title, do: "  #{entry.title}", else: nil),
      if(entry.mood, do: "  Mood: #{entry.mood}", else: nil),
      "",
      indent_body(entry.body || "", "  "),
      ""
    ]

    Enum.reject(lines, &is_nil/1)
  end

  defp indent_body(text, prefix) do
    text
    |> String.split("\n")
    |> Enum.map_join("\n", &(prefix <> &1))
  end

  defp generate_markdown({books, loose_entries}) do
    parts = [
      "# MOSSLET Journal Export",
      "",
      "_Exported: #{Date.utc_today()}_",
      "",
      "---",
      ""
    ]

    book_parts =
      Enum.flat_map(books, fn {book, entries} ->
        [
          "## 📖 #{book.title || "Untitled Book"}",
          "",
          if(book.description, do: "> #{book.description}\n", else: nil),
          "_#{length(entries)} entries_",
          ""
          | Enum.flat_map(entries, &format_entry_markdown/1)
        ]
        |> Enum.reject(&is_nil/1)
      end)

    loose_parts =
      if loose_entries != [] do
        [
          "## 📝 Entries Without a Book",
          "",
          "_#{length(loose_entries)} entries_",
          ""
          | Enum.flat_map(loose_entries, &format_entry_markdown/1)
        ]
      else
        []
      end

    data = Enum.join(parts ++ book_parts ++ loose_parts, "\n")
    {:ok, data, "journal_export.md", "text/markdown"}
  end

  defp format_entry_markdown(entry) do
    lines = [
      "### #{entry.title || "Untitled"}#{if entry.is_favorite, do: " ⭐", else: ""}",
      "",
      "**Date:** #{entry.entry_date}#{if entry.mood, do: " · **Mood:** #{entry.mood}", else: ""}",
      "",
      entry.body || "",
      "",
      "---",
      ""
    ]

    lines
  end

  defp generate_pdf({books, loose_entries}) do
    doc =
      PrawnEx.Document.new(page_size: :a4)
      |> PrawnEx.add_page()
      |> render_pdf_title_page()

    doc =
      Enum.reduce(books, doc, fn {book, entries}, acc ->
        render_pdf_book(acc, book, entries)
      end)

    doc =
      if loose_entries != [] do
        render_pdf_loose_entries(doc, loose_entries)
      else
        doc
      end

    binary = PrawnEx.to_binary(doc)
    {:ok, binary, "journal_export.pdf", "application/pdf"}
  end

  defp render_pdf_title_page(doc) do
    doc
    |> PrawnEx.set_font("Helvetica", 28)
    |> PrawnEx.text_at({@margin, @page_height - 200}, "MOSSLET")
    |> PrawnEx.set_font("Helvetica", 18)
    |> PrawnEx.text_at({@margin, @page_height - 240}, "Journal Export")
    |> PrawnEx.set_font("Helvetica", 11)
    |> PrawnEx.text_at({@margin, @page_height - 280}, "Exported: #{Date.utc_today()}")
  end

  defp render_pdf_book(doc, book, entries) do
    doc = doc |> PrawnEx.add_page()

    doc =
      doc
      |> PrawnEx.set_font("Helvetica", 20)
      |> PrawnEx.text_at(
        {@margin, @page_height - 80},
        truncate_text(book.title || "Untitled Book", 50)
      )

    y = @page_height - 110

    {doc, y} =
      if book.description do
        doc = PrawnEx.set_font(doc, "Helvetica", 10)
        doc = PrawnEx.text_at(doc, {@margin, y}, truncate_text(book.description, 80))
        {doc, y - 20}
      else
        {doc, y}
      end

    doc = PrawnEx.set_font(doc, "Helvetica", 9)
    doc = PrawnEx.text_at(doc, {@margin, y}, "#{length(entries)} entries")

    Enum.reduce(entries, {doc, y - 30}, fn entry, {d, cur_y} ->
      render_pdf_entry(d, entry, cur_y)
    end)
    |> elem(0)
  end

  defp render_pdf_loose_entries(doc, entries) do
    doc = doc |> PrawnEx.add_page()

    doc =
      doc
      |> PrawnEx.set_font("Helvetica", 20)
      |> PrawnEx.text_at({@margin, @page_height - 80}, "Entries Without a Book")

    doc = PrawnEx.set_font(doc, "Helvetica", 9)
    doc = PrawnEx.text_at(doc, {@margin, @page_height - 110}, "#{length(entries)} entries")

    Enum.reduce(entries, {doc, @page_height - 140}, fn entry, {d, cur_y} ->
      render_pdf_entry(d, entry, cur_y)
    end)
    |> elem(0)
  end

  defp render_pdf_entry(doc, entry, y) when y < @margin + 100 do
    doc = PrawnEx.add_page(doc)
    render_pdf_entry(doc, entry, @page_height - @margin)
  end

  defp render_pdf_entry(doc, entry, y) do
    title = entry.title || "Untitled"
    date_str = to_string(entry.entry_date)
    mood_str = if entry.mood, do: " · #{entry.mood}", else: ""
    fav_str = if entry.is_favorite, do: " *", else: ""

    doc = PrawnEx.set_font(doc, "Helvetica", 12)
    doc = PrawnEx.text_at(doc, {@margin, y}, truncate_text("#{title}#{fav_str}", 60))
    y = y - 16

    doc = PrawnEx.set_font(doc, "Helvetica", 8)
    doc = PrawnEx.text_at(doc, {@margin, y}, "#{date_str}#{mood_str}")
    y = y - 14

    body = entry.body || ""
    lines = wrap_text(body, 85)
    doc = PrawnEx.set_font(doc, "Helvetica", 9)

    {doc, y} =
      Enum.reduce(lines, {doc, y}, fn line, {d, cur_y} ->
        if cur_y < @margin + 20 do
          d = PrawnEx.add_page(d)
          cur_y = @page_height - @margin
          d = PrawnEx.set_font(d, "Helvetica", 9)
          d = PrawnEx.text_at(d, {@margin, cur_y}, line)
          {d, cur_y - 12}
        else
          d = PrawnEx.text_at(d, {@margin, cur_y}, line)
          {d, cur_y - 12}
        end
      end)

    y = y - 10

    doc = PrawnEx.set_stroking_gray(doc, 0.85)
    doc = PrawnEx.line(doc, {@margin, y}, {@margin + @content_width, y})
    doc = PrawnEx.stroke(doc)
    doc = PrawnEx.set_stroking_gray(doc, 0.0)

    {doc, y - 10}
  end

  defp wrap_text(text, chars_per_line) do
    text
    |> String.split("\n")
    |> Enum.flat_map(fn paragraph ->
      if String.length(paragraph) <= chars_per_line do
        [paragraph]
      else
        wrap_paragraph(paragraph, chars_per_line)
      end
    end)
  end

  defp wrap_paragraph(text, max) do
    words = String.split(text, ~r/\s+/, trim: true)

    {lines, current} =
      Enum.reduce(words, {[], ""}, fn word, {lines, current} ->
        candidate = if current == "", do: word, else: current <> " " <> word

        if String.length(candidate) > max and current != "" do
          {[current | lines], word}
        else
          {lines, candidate}
        end
      end)

    Enum.reverse([current | lines])
  end

  defp truncate_text(text, max_len) do
    if String.length(text) > max_len do
      String.slice(text, 0, max_len - 3) <> "..."
    else
      text
    end
  end
end
