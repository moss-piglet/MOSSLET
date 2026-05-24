/**
 * Client-side image modal for ZK-decrypted post images.
 *
 * Opens a fullscreen modal with the already-decrypted images entirely in
 * the browser — no server round-trip, no plaintext leakage over the wire.
 *
 * Mirrors the look and interaction patterns of the server-rendered
 * `liquid_image_modal` component (keyboard nav, swipe, download, dots).
 */

let _currentIndex = 0;
let _images = [];
let _altTexts = [];
let _canDownload = false;
let _modalEl = null;
let _boundKeydown = null;
let _touchStartX = 0;

const MODAL_ID = "zk-image-modal";

function show(images, { index = 0, altTexts = [], canDownload = false } = {}) {
  _images = images;
  _altTexts = altTexts;
  _canDownload = canDownload;
  _currentIndex = Math.max(0, Math.min(index, images.length - 1));

  remove();
  _modalEl = buildModal();
  document.body.appendChild(_modalEl);
  document.body.classList.add("overflow-hidden");

  requestAnimationFrame(() => {
    _modalEl.classList.remove("hidden");
    const bg = _modalEl.querySelector(`#${MODAL_ID}-bg`);
    const container = _modalEl.querySelector(`#${MODAL_ID}-container`);
    if (bg) {
      bg.classList.remove("opacity-0");
      bg.classList.add("opacity-100");
    }
    if (container) {
      container.classList.remove("hidden", "opacity-0", "translate-y-4", "sm:scale-95");
      container.classList.add("opacity-100", "translate-y-0", "sm:scale-100");
    }
  });

  _boundKeydown = handleKeydown;
  window.addEventListener("keydown", _boundKeydown);
}

function remove() {
  if (_boundKeydown) {
    window.removeEventListener("keydown", _boundKeydown);
    _boundKeydown = null;
  }
  const existing = document.getElementById(MODAL_ID);
  if (existing) existing.remove();
  _modalEl = null;
  document.body.classList.remove("overflow-hidden");
}

function goTo(idx) {
  _currentIndex = Math.max(0, Math.min(idx, _images.length - 1));
  render();
}

function render() {
  if (!_modalEl) return;

  const img = _modalEl.querySelector(`#${MODAL_ID}-img`);
  if (img && _images[_currentIndex]) {
    img.src = _images[_currentIndex];
    const alt = _altTexts[_currentIndex];
    img.alt = alt && alt.trim() ? alt : `Photo ${_currentIndex + 1}`;
  }

  const counter = _modalEl.querySelector(`#${MODAL_ID}-counter`);
  if (counter) counter.textContent = `Photo ${_currentIndex + 1} of ${_images.length}`;

  const prevBtn = _modalEl.querySelector(`#${MODAL_ID}-prev`);
  const nextBtn = _modalEl.querySelector(`#${MODAL_ID}-next`);
  if (prevBtn) prevBtn.style.display = _currentIndex > 0 ? "" : "none";
  if (nextBtn) nextBtn.style.display = _currentIndex < _images.length - 1 ? "" : "none";

  const dots = _modalEl.querySelectorAll(`[data-dot-index]`);
  dots.forEach((dot) => {
    const i = parseInt(dot.dataset.dotIndex, 10);
    if (i === _currentIndex) {
      dot.className =
        "relative w-3 h-3 rounded-full transition-all duration-200 hover:scale-125 bg-emerald-500 ring-2 ring-emerald-200 dark:ring-emerald-800";
    } else {
      dot.className =
        "relative w-3 h-3 rounded-full transition-all duration-200 hover:scale-125 bg-slate-300 dark:bg-slate-600 hover:bg-slate-400 dark:hover:bg-slate-500";
    }
  });

  preloadAdjacent();
}

function preloadAdjacent() {
  [_currentIndex - 1, _currentIndex + 1].forEach((i) => {
    if (i >= 0 && i < _images.length) {
      const img = new Image();
      img.src = _images[i];
    }
  });
}

function handleKeydown(e) {
  if (e.key === "Escape") {
    e.preventDefault();
    remove();
  } else if (e.key === "ArrowLeft") {
    e.preventDefault();
    goTo(_currentIndex - 1);
  } else if (e.key === "ArrowRight") {
    e.preventDefault();
    goTo(_currentIndex + 1);
  }
}

function downloadCurrent() {
  const dataUrl = _images[_currentIndex];
  if (!dataUrl) return;
  try {
    const match = dataUrl.match(/^data:([^;]+);base64,(.+)$/);
    if (!match) return;
    const mimeType = match[1];
    const base64 = match[2];
    const bytes = Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));
    const blob = new Blob([bytes], { type: mimeType });
    const ext = mimeType.split("/")[1] || "webp";
    const filename = `mosslet-image-${_currentIndex + 1}.${ext}`;
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = filename;
    a.style.display = "none";
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  } catch (e) {
    console.error("ZK image download failed:", e);
  }
}

function heroIcon(name) {
  const icons = {
    photo: `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="h-5 w-5 text-emerald-600 dark:text-emerald-400"><path stroke-linecap="round" stroke-linejoin="round" d="m2.25 15.75 5.159-5.159a2.25 2.25 0 0 1 3.182 0l5.159 5.159m-1.5-1.5 1.409-1.409a2.25 2.25 0 0 1 3.182 0l2.909 2.909M3.75 21h16.5A2.25 2.25 0 0 0 22.5 18.75V5.25A2.25 2.25 0 0 0 20.25 3H3.75A2.25 2.25 0 0 0 1.5 5.25v13.5A2.25 2.25 0 0 0 3.75 21Z" /></svg>`,
    download: `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="h-4 w-4"><path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5M16.5 12 12 16.5m0 0L7.5 12m4.5 4.5V3" /></svg>`,
    close: `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="h-4 w-4"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" /></svg>`,
    left: `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="h-6 w-6"><path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5 8.25 12l7.5-7.5" /></svg>`,
    right: `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="h-6 w-6"><path stroke-linecap="round" stroke-linejoin="round" d="m8.25 4.5 7.5 7.5-7.5 7.5" /></svg>`,
  };
  return icons[name] || "";
}

function buildModal() {
  const el = document.createElement("div");
  el.id = MODAL_ID;
  el.className = "fixed top-0 left-0 w-screen h-screen z-[60] hidden";
  el.style.cssText = "position: fixed !important;";

  const alt = _altTexts[_currentIndex];
  const altText = alt && alt.trim() ? alt : `Photo ${_currentIndex + 1}`;

  el.innerHTML = `
    <div id="${MODAL_ID}-bg" class="fixed top-0 left-0 right-0 bottom-0 z-40 transition-all duration-300 ease-out bg-black/90 backdrop-blur-sm opacity-0" style="position:fixed!important;top:0!important;left:0!important;right:0!important;bottom:0!important;"></div>
    <div class="fixed top-0 left-0 right-0 bottom-0 z-50 flex items-center justify-center p-4" style="position:fixed!important;top:0!important;left:0!important;right:0!important;bottom:0!important;">
      <div id="${MODAL_ID}-container" class="relative w-full max-w-6xl max-h-[95vh] flex flex-col transform-gpu transition-all duration-300 ease-out opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95 hidden rounded-xl overflow-hidden bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-2xl shadow-black/50">
        <div class="flex items-center justify-between px-3 py-2.5 sm:p-4 gap-2 border-b border-slate-200 dark:border-slate-700 bg-white/50 dark:bg-slate-800/50">
          <div class="flex items-center gap-1.5 sm:space-x-3 min-w-0">
            ${heroIcon("photo")}
            <span id="${MODAL_ID}-counter" class="text-sm sm:text-lg font-semibold text-slate-900 dark:text-slate-100 truncate">Photo ${_currentIndex + 1} of ${_images.length}</span>
          </div>
          <div class="flex items-center gap-1.5 sm:space-x-2 flex-shrink-0">
            ${_canDownload ? `<button id="${MODAL_ID}-download" type="button" class="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium rounded-lg text-emerald-700 dark:text-emerald-300 hover:bg-emerald-50 dark:hover:bg-emerald-900/30 transition-colors duration-150">${heroIcon("download")} Download</button>` : ""}
            <button id="${MODAL_ID}-close" type="button" class="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium rounded-lg text-rose-700 dark:text-rose-300 hover:bg-rose-50 dark:hover:bg-rose-900/30 transition-colors duration-150">${heroIcon("close")} Close</button>
          </div>
        </div>
        <div class="relative flex-1 min-h-0 bg-slate-100 dark:bg-slate-900 overflow-hidden" oncontextmenu="return false">
          <div class="relative w-full h-full flex items-center justify-center p-4">
            <img id="${MODAL_ID}-img" src="${_images[_currentIndex] || ""}" alt="${altText}" class="max-w-full max-h-full w-auto h-auto object-contain select-none" loading="lazy" style="max-height:calc(95vh - 200px);max-width:calc(100vw);" draggable="false" />
            <button id="${MODAL_ID}-prev" class="absolute left-4 top-1/2 -translate-y-1/2 p-3 rounded-full bg-black/60 hover:bg-black/80 text-white transition-all duration-200 hover:scale-110" aria-label="Previous photo" style="${_currentIndex > 0 ? "" : "display:none"}">${heroIcon("left")}</button>
            <button id="${MODAL_ID}-next" class="absolute right-4 top-1/2 -translate-y-1/2 p-3 rounded-full bg-black/60 hover:bg-black/80 text-white transition-all duration-200 hover:scale-110" aria-label="Next photo" style="${_currentIndex < _images.length - 1 ? "" : "display:none"}">${heroIcon("right")}</button>
          </div>
        </div>
        ${_images.length > 1 ? buildDots() : ""}
      </div>
    </div>
  `;

  const closeBtn = el.querySelector(`#${MODAL_ID}-close`);
  if (closeBtn) closeBtn.addEventListener("click", () => remove());

  const bg = el.querySelector(`#${MODAL_ID}-bg`);
  if (bg) bg.addEventListener("click", () => remove());

  const prevBtn = el.querySelector(`#${MODAL_ID}-prev`);
  if (prevBtn) prevBtn.addEventListener("click", () => goTo(_currentIndex - 1));

  const nextBtn = el.querySelector(`#${MODAL_ID}-next`);
  if (nextBtn) nextBtn.addEventListener("click", () => goTo(_currentIndex + 1));

  const downloadBtn = el.querySelector(`#${MODAL_ID}-download`);
  if (downloadBtn) downloadBtn.addEventListener("click", () => downloadCurrent());

  el.querySelectorAll("[data-dot-index]").forEach((dot) => {
    dot.addEventListener("click", () => goTo(parseInt(dot.dataset.dotIndex, 10)));
  });

  let ts = 0;
  el.addEventListener("touchstart", (e) => { ts = e.changedTouches[0].screenX; }, { passive: true });
  el.addEventListener("touchend", (e) => {
    const diff = ts - e.changedTouches[0].screenX;
    if (diff > 50) goTo(_currentIndex + 1);
    else if (diff < -50) goTo(_currentIndex - 1);
  }, { passive: true });

  return el;
}

function buildDots() {
  let html = `<div class="flex justify-center p-4 border-t border-slate-200 dark:border-slate-700 bg-white/50 dark:bg-slate-800/50"><div class="flex space-x-2">`;
  for (let i = 0; i < _images.length; i++) {
    const active = i === _currentIndex;
    const cls = active
      ? "relative w-3 h-3 rounded-full transition-all duration-200 hover:scale-125 bg-emerald-500 ring-2 ring-emerald-200 dark:ring-emerald-800"
      : "relative w-3 h-3 rounded-full transition-all duration-200 hover:scale-125 bg-slate-300 dark:bg-slate-600 hover:bg-slate-400 dark:hover:bg-slate-500";
    html += `<button data-dot-index="${i}" class="${cls}" aria-label="Go to photo ${i + 1}"></button>`;
  }
  html += `</div></div>`;
  return html;
}

export default { show, remove };
