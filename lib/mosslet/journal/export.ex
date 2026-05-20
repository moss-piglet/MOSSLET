defmodule Mosslet.Journal.Export do
  @moduledoc """
  Exports journal books and entries in various formats.

  All entries are decrypted before export using the user's session key.
  Supported formats: :csv, :txt, :markdown

  Note: PDF export has moved to browser-side generation via jsPDF
  in the ZkExportHook (zero-knowledge, client-side decryption).
  """

  alias Mosslet.Journal

  def export(user, key, format) when format in [:csv, :txt, :markdown] do
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
end
