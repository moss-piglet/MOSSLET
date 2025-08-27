// Color scheme logic module

export function applyScheme(scheme) {
  if (scheme === "light") {
    document.documentElement.classList.remove("dark");
    document
      .querySelectorAll(".color-scheme-dark-icon")
      .forEach((el) => el.classList.remove("hidden"));
    document
      .querySelectorAll(".color-scheme-light-timeline-preview")
      .forEach((el) => el.classList.remove("hidden"));
    document
      .querySelectorAll(".color-scheme-light-icon")
      .forEach((el) => el.classList.add("hidden"));
    document
      .querySelectorAll(".color-scheme-dark-timeline-preview")
      .forEach((el) => el.classList.add("hidden"));
    localStorage.scheme = "light";
  } else {
    document.documentElement.classList.add("dark");
    document
      .querySelectorAll(".color-scheme-dark-icon")
      .forEach((el) => el.classList.add("hidden"));
    document
      .querySelectorAll(".color-scheme-light-timeline-preview")
      .forEach((el) => el.classList.add("hidden"));
    document
      .querySelectorAll(".color-scheme-light-icon")
      .forEach((el) => el.classList.remove("hidden"));
    document
      .querySelectorAll(".color-scheme-dark-timeline-preview")
      .forEach((el) => el.classList.remove("hidden"));
    localStorage.scheme = "dark";
  }
}

export function toggleScheme() {
  if (document.documentElement.classList.contains("dark")) {
    applyScheme("light");
  } else {
    applyScheme("dark");
  }
}

export function initScheme() {
  if (
    localStorage.scheme === "dark" ||
    (!("scheme" in localStorage) &&
      window.matchMedia("(prefers-color-scheme: dark)").matches)
  ) {
    applyScheme("dark");
  } else {
    applyScheme("light");
  }
}

try {
  initScheme();
} catch (_) {}

window.applyScheme = applyScheme;
window.toggleScheme = toggleScheme;
window.initScheme = initScheme;
