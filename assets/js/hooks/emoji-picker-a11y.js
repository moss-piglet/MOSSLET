export function fixEmojiPickerA11y(container) {
  if (!container) return;
  const emojiMart = container.querySelector("em-emoji-picker");
  if (!emojiMart?.shadowRoot) {
    setTimeout(() => fixEmojiPickerA11y(container), 50);
    return;
  }

  const shadow = emojiMart.shadowRoot;

  const scrollRegion = shadow.querySelector(".scroll");
  if (scrollRegion && !scrollRegion.hasAttribute("tabindex")) {
    scrollRegion.setAttribute("tabindex", "0");
    scrollRegion.setAttribute("aria-label", "Emoji list");
  }

  const nav = shadow.querySelector("nav");
  if (nav) {
    nav.setAttribute("role", "tablist");
    nav.querySelectorAll("button").forEach((btn) => {
      btn.setAttribute("role", "tab");
      if (!btn.hasAttribute("aria-selected")) {
        btn.setAttribute("aria-selected", "false");
      }
    });
  }

  function fixCategoryButtons(root) {
    root.querySelectorAll("button[aria-posinset]").forEach((btn) => {
      btn.removeAttribute("aria-posinset");
      btn.removeAttribute("aria-setsize");
    });

    root.querySelectorAll(".category").forEach((category) => {
      if (!category.getAttribute("role")) {
        category.setAttribute("role", "group");
        const label =
          category.querySelector(".label")?.textContent?.trim() || "Emojis";
        category.setAttribute("aria-label", label);
      }
    });

    root.querySelectorAll(".category button").forEach((btn) => {
      btn.removeAttribute("role");
      btn.removeAttribute("aria-selected");
    });
  }

  fixCategoryButtons(shadow);

  shadow.querySelectorAll(".skin-tone-button[aria-selected]").forEach((btn) => {
    btn.removeAttribute("aria-selected");
    const parent = btn.parentElement;
    if (parent && !parent.getAttribute("role")) {
      parent.setAttribute("role", "group");
      parent.setAttribute("aria-label", "Skin tone options");
    }
  });

  const observer = new MutationObserver((mutations) => {
    let needsFix = false;
    for (const mutation of mutations) {
      if (mutation.type === "childList" && mutation.addedNodes.length > 0) {
        needsFix = true;
        break;
      }
    }
    if (needsFix) {
      fixCategoryButtons(shadow);
    }
  });

  observer.observe(shadow, {
    childList: true,
    subtree: true,
  });

  if (container._emojiA11yObserver) {
    container._emojiA11yObserver.disconnect();
  }
  container._emojiA11yObserver = observer;
}
