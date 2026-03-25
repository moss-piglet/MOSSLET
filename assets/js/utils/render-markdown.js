import { marked } from "../../vendor/marked.esm.js";
import DOMPurify from "../../vendor/dompurify.esm.js";

marked.setOptions({
  breaks: true,
  gfm: true,
});

export function renderMarkdown(text) {
  if (!text) return "";
  const rawHtml = marked.parse(text);
  return DOMPurify.sanitize(rawHtml);
}
