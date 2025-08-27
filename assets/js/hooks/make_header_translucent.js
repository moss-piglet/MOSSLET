export function makeHeaderTranslucentOnScroll() {
  const header = document.querySelector("header");
  if (header) {
    const distanceFromTop = window.scrollY;
    if (distanceFromTop > 0) {
      header.classList.add("is-active");
    } else {
      header.classList.remove("is-active");
    }
  }
}

// Initialize event listeners
export function bindHeaderTranslucency() {
  window.addEventListener("scroll", makeHeaderTranslucentOnScroll);
  window.addEventListener("DOMContentLoaded", makeHeaderTranslucentOnScroll);
  // Optionally re-bind on LiveView updates if needed
}

// Optionally put on window for Alpine.js direct calls
window.makeHeaderTranslucentOnScroll = makeHeaderTranslucentOnScroll;
