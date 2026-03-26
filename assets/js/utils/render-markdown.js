import { marked } from "../../vendor/marked.esm.js";
import DOMPurify from "../../vendor/dompurify.esm.js";

const renderer = new marked.Renderer();
const originalLinkRenderer = renderer.link.bind(renderer);

renderer.link = function ({ href, title, tokens }) {
  const html = originalLinkRenderer({ href, title, tokens });
  return html.replace(
    /^<a /,
    '<a target="_blank" rel="noopener noreferrer" ',
  );
};

marked.setOptions({
  breaks: true,
  gfm: true,
  renderer,
});

DOMPurify.addHook("afterSanitizeAttributes", function (node) {
  if (node.tagName === "A") {
    node.setAttribute("target", "_blank");
    node.setAttribute("rel", "noopener noreferrer");
  }
});

export function renderMarkdown(text) {
  if (!text) return "";
  const rawHtml = marked.parse(text);
  return DOMPurify.sanitize(rawHtml, {
    ADD_ATTR: ["target", "rel"],
  });
}

export function extractFirstUrl(text) {
  if (!text) return null;
  const urlRegex = /https?:\/\/[^\s<>\[\]()]+/i;
  const match = text.match(urlRegex);
  return match ? match[0] : null;
}
