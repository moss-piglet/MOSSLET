/**
 * LetterPreview — renders a full, read-as-delivered preview of a time-capsule
 * letter inside a modal.
 *
 * Fully client-side (ZK): the plaintext title/body are read from the composer
 * inputs and rendered through the SAME renderMarkdown pipeline the reader uses,
 * so the preview matches exactly how the letter will look when opened. Nothing
 * is sent to the server.
 *
 * Attach to the letter container:
 *   <article
 *     phx-hook="LetterPreview"
 *     data-source="capsule-body"        // body textarea id (Markdown)
 *     data-title-source="capsule-title" // optional title input id (plain text)
 *   >
 *     <h1 data-preview-title></h1>
 *     <div data-preview-body></div>
 *   </article>
 */
import { renderMarkdown } from "../utils/render-markdown";

const LetterPreview = {
  mounted() {
    this.render();
  },

  render() {
    const source = document.getElementById(this.el.dataset.source);
    const titleSource = this.el.dataset.titleSource
      ? document.getElementById(this.el.dataset.titleSource)
      : null;

    const titleTarget = this.el.querySelector("[data-preview-title]");
    if (titleTarget) {
      titleTarget.textContent = titleSource ? titleSource.value.trim() : "";
    }

    const bodyTarget = this.el.querySelector("[data-preview-body]");
    if (bodyTarget && source) {
      const text = source.value || "";
      bodyTarget.innerHTML = text.trim()
        ? renderMarkdown(text)
        : '<p class="opacity-40">Your letter is empty — write a few words first.</p>';
    }
  },
};

export default LetterPreview;
