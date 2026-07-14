/**
 * MarkdownToolbar — lightweight formatting affordance for a Markdown textarea.
 *
 * Purely client-side, DOM-only sugar: it wraps or toggles the current textarea
 * selection with Markdown syntax. No content ever leaves the browser here —
 * encryption still happens on submit via the owning form hook (ZK write path).
 *
 * Usage:
 *   <div phx-hook="MarkdownToolbar" data-target="capsule-body">
 *     <button type="button" data-md-action="bold">…</button>
 *     <button type="button" data-md-action="italic">…</button>
 *     <button type="button" data-md-action="quote">…</button>
 *   </div>
 *
 * Supported actions:
 *   bold   — wrap selection in ** **   (inline, toggles)
 *   italic — wrap selection in *  *    (inline, toggles)
 *   quote  — prefix each selected line with "> " (block indent, toggles)
 *   indent — prefix each selected line with a non-breaking-space indent so a
 *            fresh letter paragraph is visually indented (Markdown collapses
 *            literal leading whitespace; nbsp survives), toggles
 */
const INLINE = {
  bold: "**",
  italic: "*",
};

// A visible first-line indent that survives Markdown + DOMPurify (literal
// leading spaces get collapsed or turned into a code block).
const INDENT = "\u00A0\u00A0\u00A0\u00A0";

const MarkdownToolbar = {
  mounted() {
    this._onClick = (e) => this._handle(e);
    this.el.addEventListener("click", this._onClick);
  },

  destroyed() {
    this.el.removeEventListener("click", this._onClick);
  },

  _textarea() {
    const id = this.el.dataset.target;
    return id ? document.getElementById(id) : null;
  },

  _handle(e) {
    const btn = e.target.closest("[data-md-action]");
    if (!btn) return;
    e.preventDefault();

    const ta = this._textarea();
    if (!ta) return;

    const action = btn.dataset.mdAction;
    if (action === "quote") {
      this._toggleLinePrefix(ta, "> ");
    } else if (action === "indent") {
      this._toggleLinePrefix(ta, INDENT);
    } else if (INLINE[action]) {
      this._toggleInline(ta, INLINE[action]);
    }

    ta.focus();
    ta.dispatchEvent(new Event("input", { bubbles: true }));
  },

  _toggleInline(ta, marker) {
    const start = ta.selectionStart;
    const end = ta.selectionEnd;
    const value = ta.value;
    const selected = value.slice(start, end);
    const len = marker.length;

    const alreadyWrapped =
      selected.startsWith(marker) &&
      selected.endsWith(marker) &&
      selected.length >= len * 2;

    if (alreadyWrapped) {
      const inner = selected.slice(len, selected.length - len);
      ta.value = value.slice(0, start) + inner + value.slice(end);
      ta.setSelectionRange(start, start + inner.length);
      return;
    }

    if (start === end) {
      // No selection: drop the markers and place the caret between them.
      ta.value = value.slice(0, start) + marker + marker + value.slice(end);
      const caret = start + len;
      ta.setSelectionRange(caret, caret);
      return;
    }

    ta.value = value.slice(0, start) + marker + selected + marker + value.slice(end);
    ta.setSelectionRange(start + len, end + len);
  },

  _toggleLinePrefix(ta, prefix) {
    const value = ta.value;
    const start = ta.selectionStart;
    const end = ta.selectionEnd;

    // Expand selection to full lines.
    const lineStart = value.lastIndexOf("\n", start - 1) + 1;
    let lineEnd = value.indexOf("\n", end);
    if (lineEnd === -1) lineEnd = value.length;

    const block = value.slice(lineStart, lineEnd);
    const lines = block.split("\n");
    const allPrefixed = lines.every(
      (l) => l.startsWith(prefix) || l.trim() === "",
    );

    const updated = lines
      .map((l) => {
        if (allPrefixed) {
          return l.startsWith(prefix) ? l.slice(prefix.length) : l;
        }
        return l.trim() === "" ? l : prefix + l;
      })
      .join("\n");

    ta.value = value.slice(0, lineStart) + updated + value.slice(lineEnd);
    ta.setSelectionRange(lineStart, lineStart + updated.length);
  },
};

export default MarkdownToolbar;
