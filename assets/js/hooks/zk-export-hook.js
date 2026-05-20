/**
 * ZkExportHook — browser-side zero-knowledge journal export.
 *
 * The server sends encrypted journal data (NaCl secretbox blobs) + the
 * sealed user_key via push_event("zk-export-data"). This hook:
 *   1. Unseals the user_key using the user's private keys (WASM)
 *   2. Decrypts all entry fields client-side (secretbox)
 *   3. Formats the output as CSV, TXT, Markdown, or PDF
 *   4. Triggers a browser download
 *
 * The server never sees plaintext journal content during export.
 *
 * Supports chunked transfer for large journals — accumulates data across
 * multiple push_events before decrypting and formatting.
 */
import { unsealContextKey, decryptWithKey, getPublicKey } from "../crypto/session";
import { jsPDF } from "jspdf";

/**
 * User keys are double-base64 wrapped (the NIF seals a base64-encoded key,
 * then WASM unseal returns it re-encoded). Decode one layer.
 */
function unwrapUserKey(unsealedB64) {
  try {
    return atob(unsealedB64);
  } catch {
    return unsealedB64;
  }
}

function todayIso() {
  return new Date().toISOString().slice(0, 10);
}

// ---------------------------------------------------------------------------
// Text formatters
// ---------------------------------------------------------------------------

function csvEscape(value) {
  const str = value == null ? "" : String(value);
  if (str.includes(",") || str.includes('"') || str.includes("\n") || str.includes("\r")) {
    return '"' + str.replace(/"/g, '""') + '"';
  }
  return str;
}

function generateCsv(books, looseEntries) {
  const rows = ["Book,Date,Title,Mood,Favorite,Word Count,Entry\r\n"];

  for (const book of books) {
    const bookTitle = book.title || "Untitled Book";
    for (const entry of book.entries) {
      rows.push(
        [
          csvEscape(bookTitle),
          csvEscape(entry.entry_date),
          csvEscape(entry.title || ""),
          csvEscape(entry.mood || ""),
          csvEscape(entry.is_favorite ? "Yes" : "No"),
          csvEscape(String(entry.word_count || 0)),
          csvEscape(entry.body || ""),
        ].join(",") + "\r\n"
      );
    }
  }

  for (const entry of looseEntries) {
    rows.push(
      [
        csvEscape("(No Book)"),
        csvEscape(entry.entry_date),
        csvEscape(entry.title || ""),
        csvEscape(entry.mood || ""),
        csvEscape(entry.is_favorite ? "Yes" : "No"),
        csvEscape(String(entry.word_count || 0)),
        csvEscape(entry.body || ""),
      ].join(",") + "\r\n"
    );
  }

  return { data: rows.join(""), filename: "journal_export.csv", mime: "text/csv" };
}

function generateTxt(books, looseEntries) {
  const lines = [
    "MOSSLET JOURNAL EXPORT",
    `Exported: ${todayIso()}`,
    "=".repeat(60),
    "",
  ];

  for (const book of books) {
    lines.push("");
    lines.push("\u2500".repeat(60));
    lines.push(`\u{1F4D6} ${book.title || "Untitled Book"}`);
    if (book.description) lines.push(`   ${book.description}`);
    lines.push(`   ${book.entries.length} entries`);
    lines.push("\u2500".repeat(60));
    lines.push("");

    for (const entry of book.entries) {
      lines.push(`  \u{1F4C5} ${entry.entry_date}${entry.is_favorite ? " \u2B50" : ""}`);
      if (entry.title) lines.push(`  ${entry.title}`);
      if (entry.mood) lines.push(`  Mood: ${entry.mood}`);
      lines.push("");
      if (entry.body) {
        for (const line of entry.body.split("\n")) {
          lines.push(`  ${line}`);
        }
      }
      lines.push("");
    }
  }

  if (looseEntries.length > 0) {
    lines.push("");
    lines.push("\u2500".repeat(60));
    lines.push(`\u{1F4DD} Entries Without a Book`);
    lines.push(`   ${looseEntries.length} entries`);
    lines.push("\u2500".repeat(60));
    lines.push("");

    for (const entry of looseEntries) {
      lines.push(`  \u{1F4C5} ${entry.entry_date}${entry.is_favorite ? " \u2B50" : ""}`);
      if (entry.title) lines.push(`  ${entry.title}`);
      if (entry.mood) lines.push(`  Mood: ${entry.mood}`);
      lines.push("");
      if (entry.body) {
        for (const line of entry.body.split("\n")) {
          lines.push(`  ${line}`);
        }
      }
      lines.push("");
    }
  }

  return { data: lines.join("\n"), filename: "journal_export.txt", mime: "text/plain" };
}

function generateMarkdown(books, looseEntries) {
  const lines = [
    "# MOSSLET Journal Export",
    "",
    `_Exported: ${todayIso()}_`,
    "",
    "---",
    "",
  ];

  for (const book of books) {
    lines.push(`## \u{1F4D6} ${book.title || "Untitled Book"}`);
    lines.push("");
    if (book.description) {
      lines.push(`> ${book.description}`);
      lines.push("");
    }
    lines.push(`_${book.entries.length} entries_`);
    lines.push("");

    for (const entry of book.entries) {
      lines.push(`### ${entry.title || "Untitled"}${entry.is_favorite ? " \u2B50" : ""}`);
      lines.push("");
      let meta = `**Date:** ${entry.entry_date}`;
      if (entry.mood) meta += ` \u00B7 **Mood:** ${entry.mood}`;
      lines.push(meta);
      lines.push("");
      lines.push(entry.body || "");
      lines.push("");
      lines.push("---");
      lines.push("");
    }
  }

  if (looseEntries.length > 0) {
    lines.push(`## \u{1F4DD} Entries Without a Book`);
    lines.push("");
    lines.push(`_${looseEntries.length} entries_`);
    lines.push("");

    for (const entry of looseEntries) {
      lines.push(`### ${entry.title || "Untitled"}${entry.is_favorite ? " \u2B50" : ""}`);
      lines.push("");
      let meta = `**Date:** ${entry.entry_date}`;
      if (entry.mood) meta += ` \u00B7 **Mood:** ${entry.mood}`;
      lines.push(meta);
      lines.push("");
      lines.push(entry.body || "");
      lines.push("");
      lines.push("---");
      lines.push("");
    }
  }

  return { data: lines.join("\n"), filename: "journal_export.md", mime: "text/markdown" };
}

// ---------------------------------------------------------------------------
// PDF formatter (jsPDF, browser-side)
// ---------------------------------------------------------------------------

const PDF_MARGIN = 20;
const PDF_PAGE_W = 210;
const PDF_CONTENT_W = PDF_PAGE_W - 2 * PDF_MARGIN;
const PDF_LINE_H = 5;

/**
 * Strips characters that jsPDF's built-in helvetica (WinAnsi) can't render.
 * Replaces common Unicode with ASCII equivalents, drops emoji.
 */
function sanitizeForPdf(text) {
  if (!text) return "";
  return text
    .replace(/[\u2018\u2019\u201A]/g, "'")
    .replace(/[\u201C\u201D\u201E]/g, '"')
    .replace(/\u2026/g, "...")
    .replace(/\u2013/g, "-")
    .replace(/\u2014/g, "--")
    .replace(/\u2022/g, "*")
    .replace(/\u00B7/g, " - ")
    .replace(/[\u{1F000}-\u{1FFFF}]/gu, "")
    .replace(/[\u{2600}-\u{27BF}]/gu, "")
    .replace(/[\u{FE00}-\u{FE0F}]/gu, "")
    .replace(/[\u{200D}]/gu, "");
}

function pdfAddWrappedText(doc, text, x, y, maxWidth, lineHeight) {
  const lines = doc.splitTextToSize(text, maxWidth);
  for (const line of lines) {
    if (y > 280) {
      doc.addPage();
      y = PDF_MARGIN;
    }
    doc.text(line, x, y);
    y += lineHeight;
  }
  return y;
}

function generatePdf(books, looseEntries) {
  const doc = new jsPDF({ unit: "mm", format: "a4" });

  doc.setFont("helvetica", "bold");
  doc.setFontSize(28);
  doc.text("MOSSLET", PDF_MARGIN, 60);

  doc.setFont("helvetica", "normal");
  doc.setFontSize(18);
  doc.text("Journal Export", PDF_MARGIN, 72);

  doc.setFontSize(11);
  doc.text(`Exported: ${todayIso()}`, PDF_MARGIN, 84);

  for (const book of books) {
    doc.addPage();
    let y = PDF_MARGIN;

    doc.setFont("helvetica", "bold");
    doc.setFontSize(18);
    y = pdfAddWrappedText(doc, sanitizeForPdf(book.title || "Untitled Book"), PDF_MARGIN, y, PDF_CONTENT_W, 7);
    y += 2;

    if (book.description) {
      doc.setFont("helvetica", "italic");
      doc.setFontSize(10);
      y = pdfAddWrappedText(doc, sanitizeForPdf(book.description), PDF_MARGIN, y, PDF_CONTENT_W, PDF_LINE_H);
      y += 2;
    }

    doc.setFont("helvetica", "normal");
    doc.setFontSize(9);
    doc.text(`${book.entries.length} entries`, PDF_MARGIN, y);
    y += 8;

    for (const entry of book.entries) {
      if (y > 265) {
        doc.addPage();
        y = PDF_MARGIN;
      }

      doc.setFont("helvetica", "bold");
      doc.setFontSize(12);
      const title = sanitizeForPdf(entry.title || "Untitled");
      const fav = entry.is_favorite ? " *" : "";
      y = pdfAddWrappedText(doc, `${title}${fav}`, PDF_MARGIN, y, PDF_CONTENT_W, 5.5);

      doc.setFont("helvetica", "normal");
      doc.setFontSize(8);
      let meta = entry.entry_date || "";
      if (entry.mood) meta += ` - ${sanitizeForPdf(entry.mood)}`;
      doc.text(meta, PDF_MARGIN, y);
      y += 5;

      doc.setFontSize(9);
      const body = sanitizeForPdf(entry.body || "");
      y = pdfAddWrappedText(doc, body, PDF_MARGIN, y, PDF_CONTENT_W, PDF_LINE_H);
      y += 3;

      doc.setDrawColor(200);
      doc.line(PDF_MARGIN, y, PDF_MARGIN + PDF_CONTENT_W, y);
      y += 6;
    }
  }

  if (looseEntries.length > 0) {
    doc.addPage();
    let y = PDF_MARGIN;

    doc.setFont("helvetica", "bold");
    doc.setFontSize(18);
    doc.text("Entries Without a Book", PDF_MARGIN, y);
    y += 8;

    doc.setFont("helvetica", "normal");
    doc.setFontSize(9);
    doc.text(`${looseEntries.length} entries`, PDF_MARGIN, y);
    y += 8;

    for (const entry of looseEntries) {
      if (y > 265) {
        doc.addPage();
        y = PDF_MARGIN;
      }

      doc.setFont("helvetica", "bold");
      doc.setFontSize(12);
      const title = sanitizeForPdf(entry.title || "Untitled");
      const fav = entry.is_favorite ? " *" : "";
      y = pdfAddWrappedText(doc, `${title}${fav}`, PDF_MARGIN, y, PDF_CONTENT_W, 5.5);

      doc.setFont("helvetica", "normal");
      doc.setFontSize(8);
      let meta = entry.entry_date || "";
      if (entry.mood) meta += ` - ${sanitizeForPdf(entry.mood)}`;
      doc.text(meta, PDF_MARGIN, y);
      y += 5;

      doc.setFontSize(9);
      const body = sanitizeForPdf(entry.body || "");
      y = pdfAddWrappedText(doc, body, PDF_MARGIN, y, PDF_CONTENT_W, PDF_LINE_H);
      y += 3;

      doc.setDrawColor(200);
      doc.line(PDF_MARGIN, y, PDF_MARGIN + PDF_CONTENT_W, y);
      y += 6;
    }
  }

  return { blob: doc.output("blob"), filename: "journal_export.pdf" };
}

// ---------------------------------------------------------------------------
// Download helpers
// ---------------------------------------------------------------------------

function triggerDownload(data, filename, mimeType) {
  const bom = "\uFEFF";
  const blob = new Blob([bom + data], { type: mimeType + ";charset=utf-8" });
  triggerBlobDownload(blob, filename);
}

function triggerBlobDownload(blob, filename) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  link.style.display = "none";
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  setTimeout(() => URL.revokeObjectURL(url), 5000);
}

// ---------------------------------------------------------------------------
// Text format lookup (PDF handled separately)
// ---------------------------------------------------------------------------

const TEXT_FORMATTERS = {
  csv: generateCsv,
  txt: generateTxt,
  markdown: generateMarkdown,
};

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------

const ZkExportHook = {
  mounted() {
    this._books = [];
    this._looseEntries = [];
    this._userKey = null;
    this._format = null;

    this.handleEvent("zk-export-data", (payload) => this._handleChunk(payload));
  },

  async _handleChunk(payload) {
    if (payload.chunk === "first" || payload.chunk === "only") {
      this._books = [];
      this._looseEntries = [];
      this._format = payload.format;

      const sealedKey = payload.sealed_user_key;
      if (!sealedKey) {
        console.error("ZkExportHook: no sealed_user_key received");
        return;
      }

      if (!getPublicKey()) {
        await new Promise((resolve) => {
          window.addEventListener("mosslet:keys-ready", resolve, { once: true });
        });
      }

      try {
        const rawUserKey = await unsealContextKey(sealedKey);
        if (!rawUserKey) {
          console.error("ZkExportHook: failed to unseal user_key");
          return;
        }
        this._userKey = unwrapUserKey(rawUserKey);
      } catch (e) {
        console.error("ZkExportHook: unseal error:", e);
        return;
      }
    }

    if (payload.chunk === "last") {
      await this._finalize();
      return;
    }

    if (payload.books) {
      for (const book of payload.books) {
        const decryptedBook = {
          title: await this._decryptField(book.title),
          description: await this._decryptField(book.description),
          entries: await this._decryptEntries(book.entries),
        };
        this._books.push(decryptedBook);
      }
    }

    if (payload.loose_entries && payload.loose_entries.length > 0) {
      const decrypted = await this._decryptEntries(payload.loose_entries);
      this._looseEntries.push(...decrypted);
    }

    if (payload.chunk === "only") {
      await this._finalize();
    }
  },

  async _decryptField(encrypted) {
    if (!encrypted || !this._userKey) return null;
    try {
      return await decryptWithKey(encrypted, this._userKey);
    } catch {
      return null;
    }
  },

  async _decryptEntries(entries) {
    const results = [];
    for (const entry of entries) {
      results.push({
        title: await this._decryptField(entry.title),
        body: await this._decryptField(entry.body),
        mood: await this._decryptField(entry.mood),
        entry_date: entry.entry_date,
        is_favorite: entry.is_favorite,
        word_count: entry.word_count,
      });
    }
    return results;
  },

  async _finalize() {
    if (this._format === "pdf") {
      const { blob, filename } = generatePdf(this._books, this._looseEntries);
      triggerBlobDownload(blob, filename);
    } else {
      const formatter = TEXT_FORMATTERS[this._format];
      if (!formatter) {
        console.error("ZkExportHook: unknown format:", this._format);
        return;
      }
      const { data, filename, mime } = formatter(this._books, this._looseEntries);
      triggerDownload(data, filename, mime);
    }

    this._books = [];
    this._looseEntries = [];
    this._userKey = null;
  },
};

export default ZkExportHook;
