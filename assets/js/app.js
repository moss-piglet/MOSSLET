// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";

// Mobile native bridge for iOS/Android apps
import MobileNative from "./mobile_native";

import Alpine from "../vendor/alpinejs";
import collapse from "../vendor/@alpinejs/collapse";
import focus from "../vendor/@alpinejs/focus";
import intersect from "../vendor/@alpinejs/intersect";
import "../vendor/@alpinejs/persist";
import ui from "../vendor/@alpinejs/ui";

import "./mood_picker";

// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";

import live_select from "live_select";

// Add your custom hooks to the hooks folder - then import them in hooks/index.js
import mossletHooks from "./hooks/index";

Alpine.plugin(collapse);
Alpine.plugin(focus);
Alpine.plugin(intersect);
Alpine.plugin(ui);

window.Alpine = Alpine;

// Make tippy globally available
window.tippy = tippy;

// Set default tippy props to fix accessibility landmark issues
tippy.setDefaultProps({
  appendTo: () => {
    let container = document.getElementById("tippy-container");
    if (!container) {
      container = document.createElement("div");
      container.id = "tippy-container";
      container.setAttribute("aria-hidden", "true");
      document.body.appendChild(container);
    }
    return container;
  },
});

Alpine.start();

// Trix-Editor

// Change the trix config
document.addEventListener("trix-before-initialize", function (event) {
  Trix.config.textAttributes.highlight = { tagName: "mark" };
  Trix.config.textAttributes.emoji = { tagName: "emoji" };
});

document.addEventListener("trix-initialize", function (event) {
  var groupElement = event.target.toolbarElement.querySelector(
    ".trix-button-group.trix-button-group--text-tools"
  );

  groupElement.insertAdjacentHTML(
    "beforeend",
    '<button type="button" class="trix-button trix-button--icon trix-button--icon-highlight" data-trix-attribute="highlight" data-trix-key="y" title="Highlight" tabindex="-1"><span class="align-middle"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="size-5"><path fill-rule="evenodd" d="M20.599 1.5c-.376 0-.743.111-1.055.32l-5.08 3.385a18.747 18.747 0 0 0-3.471 2.987 10.04 10.04 0 0 1 4.815 4.815 18.748 18.748 0 0 0 2.987-3.472l3.386-5.079A1.902 1.902 0 0 0 20.599 1.5Zm-8.3 14.025a18.76 18.76 0 0 0 1.896-1.207 8.026 8.026 0 0 0-4.513-4.513A18.75 18.75 0 0 0 8.475 11.7l-.278.5a5.26 5.26 0 0 1 3.601 3.602l.502-.278ZM6.75 13.5A3.75 3.75 0 0 0 3 17.25a1.5 1.5 0 0 1-1.601 1.497.75.75 0 0 0-.7 1.123 5.25 5.25 0 0 0 9.8-2.62 3.75 3.75 0 0 0-3.75-3.75Z" clip-rule="evenodd" /></svg></span></button>'
  );

  groupElement.insertAdjacentHTML(
    "beforeend",
    `<div x-data="{
          open: false,
          toggle() {
              this.open = !this.open
          },
          close(focusAfter) {
              this.open = false
              focusAfter && focusAfter.focus()
          }
      }"
      x-on:keydown.escape.prevent.stop="close($refs.button)"
      x-on:click.outside="open = false"
      x-on:close-emoji-dropdown.window="open = false"
      x-id="['dropdown-button']" 
      class="border-l-1 border-gray-300">
      <button 
          type="button" 
          class="trix-button trix-button--icon trix-button--icon-emojis" 
          data-trix-attribute="emoji" 
          title="Emoji" 
          data-trix-action="x-emoji" 
          x-ref="button" 
          x-on:click="toggle()" 
          :aria-expanded="open" 
          :aria-controls="$id('dropdown-button')"
      >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="size-5"><path fill-rule="evenodd" d="M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25Zm-2.625 6c-.54 0-.828.419-.936.634a1.96 1.96 0 0 0-.189.866c0 .298.059.605.189.866.108.215.395.634.936.634.54 0 .828-.419.936-.634.13-.26.189-.568.189-.866 0-.298-.059-.605-.189-.866-.108-.215-.395-.634-.936-.634Zm4.314.634c.108-.215.395-.634.936-.634.54 0 .828.419.936.634.13.26.189.568.189.866 0 .298-.059.605-.189.866-.108.215-.395.634-.936.634-.54 0-.828-.419-.936-.634a1.96 1.96 0 0 1-.189-.866c0-.298.059-.605.189-.866Zm2.023 6.828a.75.75 0 1 0-1.06-1.06 3.75 3.75 0 0 1-5.304 0 .75.75 0 0 0-1.06 1.06 5.25 5.25 0 0 0 7.424 0Z" clip-rule="evenodd" /></svg>
      </button>
      <div 
          x-ref="panel" 
          x-show="open" 
          x-transition.origin.top.left 
          :id="$id('dropdown-button')" 
          data-emoji="${event.target.toolbarElement.id}" 
          x-cloak 
          class="absolute top-6 left-0 origin-top-left p-1.5 outline-none border-none picker-container z-50">
      </div>
    </div>`
  );
});

// Add event listener for closing reply composer after successful submission
window.addEventListener("phx:close-reply-composer", (event) => {
  const { post_id } = event.detail;
  const composerId = `reply-composer-${post_id}`;
  const cardId = `timeline-card-${post_id}`;
  const buttonId = `reply-button-${post_id}`;

  const composer = document.getElementById(composerId);
  const card = document.getElementById(cardId);
  const button = document.getElementById(buttonId);

  // Hide the composer using stored JS command if available
  if (composer && !composer.classList.contains("hidden")) {
    if (composer.dataset.hideJs) {
      liveSocket.execJS(composer, composer.dataset.hideJs);
    } else {
      composer.classList.add("hidden");
    }

    // Remove ring from card
    if (card) {
      card.classList.remove("ring-2", "ring-emerald-300");
    }

    // Reset button state
    if (button) {
      button.setAttribute("data-composer-open", "false");
    }
  }
});

// Show reply thread after creating a reply (keeps thread expanded)
window.addEventListener("phx:show-reply-thread", (event) => {
  const { post_id } = event.detail;
  const threadId = `reply-thread-${post_id}`;
  const cardId = `timeline-card-${post_id}`;

  const thread = document.getElementById(threadId);
  const card = document.getElementById(cardId);

  // Show the thread using stored JS command
  if (thread && thread.dataset.showJs) {
    liveSocket.execJS(thread, thread.dataset.showJs);
  } else if (thread) {
    thread.classList.remove("hidden");
  }

  // Keep the card highlighted
  if (card) {
    card.classList.add("ring-2", "ring-emerald-300");
  }
});

// Hide nested reply composer after successful submission
window.addEventListener("phx:hide-nested-reply-composer", (event) => {
  const { reply_id } = event.detail;
  const composer = document.getElementById(`nested-composer-${reply_id}`);

  if (composer && composer.dataset.hideJs) {
    liveSocket.execJS(composer, composer.dataset.hideJs);
  } else if (composer) {
    composer.classList.add("hidden");
    const button = document.getElementById(`reply-button-${reply_id}`);
    if (button) {
      button.classList.remove("text-emerald-600", "dark:text-emerald-400");
      button.setAttribute("data-composer-open", "false");
    }
  }

  const textarea = composer?.querySelector(
    `#nested-reply-textarea-${reply_id}`
  );
  if (textarea) {
    textarea.value = "";
    textarea.dispatchEvent(new Event("input", { bubbles: true }));
  }
});

// Animate newly loaded replies
window.addEventListener("phx:animate-new-replies", (event) => {
  const { post_id, start_index } = event.detail;
  const thread = document.getElementById(`reply-thread-${post_id}`);

  if (thread) {
    const replyItems = thread.querySelectorAll(".reply-item");
    replyItems.forEach((item, index) => {
      if (index >= start_index) {
        item.style.opacity = "0";
        item.style.transform = "translateX(-8px) translateY(-8px)";

        setTimeout(() => {
          item.classList.add("nested-reply-expand-enter");
          item.style.opacity = "";
          item.style.transform = "";
        }, (index - start_index) * 50);
      }
    });
  }
});

// Add event listener for scroll to top
window.addEventListener("phx:scroll-to-top", (event) => {
  // Use a custom smooth scroll with easing for better animation
  const startPosition = window.pageYOffset;
  const targetPosition = 0;
  const distance = targetPosition - startPosition;
  const duration = Math.min(1200, Math.max(800, Math.abs(distance) * 2)); // Dynamic duration based on distance
  let start = null;

  function ease(t, b, c, d) {
    // easeOutQuart easing function for smooth deceleration
    t /= d;
    t--;
    return -c * (t * t * t * t - 1) + b;
  }

  function animation(currentTime) {
    if (start === null) start = currentTime;
    const timeElapsed = currentTime - start;
    const run = ease(timeElapsed, startPosition, distance, duration);
    window.scrollTo(0, run);
    if (timeElapsed < duration) requestAnimationFrame(animation);
  }

  requestAnimationFrame(animation);
});

// Mark existing posts as loaded to prevent animation on page load
document.addEventListener("DOMContentLoaded", function () {
  const existingPosts = document.querySelectorAll(
    ".timeline-post-item.new-post"
  );
  existingPosts.forEach(function (post) {
    post.classList.add("loaded");
  });
});

// Auto-cleanup new post animations for truly new posts
const observer = new MutationObserver(function (mutations) {
  mutations.forEach(function (mutation) {
    mutation.addedNodes.forEach(function (node) {
      if (node.nodeType === Node.ELEMENT_NODE) {
        // Check if this is a new timeline post container
        const isNewPostContainer =
          node.classList && node.classList.contains("timeline-post-container");
        const newPostContainers = isNewPostContainer
          ? [node]
          : (node.querySelectorAll &&
              node.querySelectorAll(".timeline-post-container")) ||
            [];

        newPostContainers.forEach(function (container) {
          const postItem = container.querySelector(
            ".timeline-post-item.new-post"
          );
          if (postItem && !postItem.classList.contains("loaded")) {
            // Clean up animation classes after completion
            setTimeout(function () {
              postItem.classList.remove("new-post");
            }, 3800); // 0.8s slide + 3s highlight
          }
        });
      }
    });
  });
});

// Start observing the timeline posts container
const timelineContainer = document.getElementById("timeline-posts");
if (timelineContainer) {
  observer.observe(timelineContainer, {
    childList: true,
    subtree: false, // Only watch direct children
  });
}

// Remove the targeted animation approach
// Add event listener for tab count updates to show notification badges
window.addEventListener("phx:update-tab-counts", (event) => {
  const { tabCounts, activeTab } = event.detail;

  // Update tab badges with new counts
  Object.entries(tabCounts).forEach(([tab, count]) => {
    const tabElement = document.querySelector(`[data-tab="${tab}"]`);
    if (tabElement && tab !== activeTab) {
      const badge = tabElement.querySelector(".unread-badge");
      if (badge && count > 0) {
        badge.textContent = count;
        badge.classList.remove("hidden");

        // Add a subtle pulse animation to indicate new content
        badge.classList.add("animate-pulse");
        setTimeout(() => {
          badge.classList.remove("animate-pulse");
        }, 2000);
      }
    }
  });
});

// Add event listener for new post banner notifications
window.addEventListener("phx:show-new-posts-banner", (event) => {
  const { count, tab } = event.detail;

  // Find or create the new posts banner
  let banner = document.getElementById("new-posts-banner");

  if (!banner) {
    // Create new banner element
    banner = document.createElement("div");
    banner.id = "new-posts-banner";
    banner.className = `
      fixed top-20 left-1/2 transform -translate-x-1/2 z-50
      bg-emerald-500 dark:bg-emerald-600 text-white px-6 py-3 rounded-full
      shadow-lg border border-emerald-400 dark:border-emerald-500
      cursor-pointer transition-all duration-300 ease-out
      hover:bg-emerald-600 dark:hover:bg-emerald-700
      hover:scale-105 active:scale-95
    `;

    // Add click handler to scroll to top and refresh
    banner.addEventListener("click", () => {
      window.scrollTo({ top: 0, behavior: "smooth" });
      banner.remove();
      // Trigger a refresh of the timeline
      window.dispatchEvent(new CustomEvent("phx:refresh-timeline"));
    });

    document.body.appendChild(banner);
  }

  // Update banner content
  const postText = count === 1 ? "post" : "posts";
  banner.innerHTML = `
    <div class="flex items-center gap-2 text-sm font-medium">
      <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-11a1 1 0 10-2 0v2H7a1 1 0 100 2h2v2a1 1 0 102 0v-2h2a1 1 0 100-2h-2V7z" clip-rule="evenodd" />
      </svg>
      <span>${count} new ${postText}</span>
      <svg class="w-4 h-4 ml-1" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M14.707 12.707a1 1 0 01-1.414 0L10 9.414l-3.293 3.293a1 1 0 01-1.414-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 010 1.414z" clip-rule="evenodd" />
      </svg>
    </div>
  `;

  // Animate in
  banner.style.transform = "translateX(-50%) translateY(-20px)";
  banner.style.opacity = "0";

  requestAnimationFrame(() => {
    banner.style.transform = "translateX(-50%) translateY(0)";
    banner.style.opacity = "1";
  });

  // Auto-hide after 10 seconds
  setTimeout(() => {
    if (banner.parentNode) {
      banner.style.transform = "translateX(-50%) translateY(-20px)";
      banner.style.opacity = "0";
      setTimeout(() => banner.remove(), 300);
    }
  }, 10000);
});

window.addEventListener("phx:show-el", (e) =>
  document.getElementById(e.detail.id).removeAttribute("style")
);

window.addEventListener("phx:update_post_fav_count", (event) => {
  const { post_id, favs_count, is_liked } = event.detail;
  const countElements = document.querySelectorAll(
    `[data-post-fav-count="${post_id}"]`
  );
  countElements.forEach((el) => {
    el.textContent = favs_count > 0 ? favs_count : "";
  });

  if (is_liked !== undefined) {
    const likedButton = document.getElementById(
      `hero-heart-solid-button-${post_id}`
    );
    const unlikedButton = document.getElementById(
      `hero-heart-button-${post_id}`
    );
    const button = likedButton || unlikedButton;

    if (button) {
      const iconEl = button.querySelector("[id^='hero-heart']");

      if (is_liked) {
        button.id = `hero-heart-solid-button-${post_id}`;
        button.setAttribute("phx-click", "unfav");
        button.setAttribute("data-tippy-content", "Remove love");
        button.classList.remove(
          "text-slate-500",
          "dark:text-slate-400",
          "hover:text-rose-600",
          "dark:hover:text-rose-400"
        );
        button.classList.add(
          "text-rose-600",
          "dark:text-rose-400",
          "bg-rose-50/50",
          "dark:bg-rose-900/20"
        );
        if (iconEl) {
          iconEl.id = `hero-heart-solid-icon-${post_id}`;
          iconEl.classList.remove("hero-heart");
          iconEl.classList.add("hero-heart-solid");
        }
      } else {
        button.id = `hero-heart-button-${post_id}`;
        button.setAttribute("phx-click", "fav");
        button.setAttribute("data-tippy-content", "Show love");
        button.classList.remove(
          "text-rose-600",
          "dark:text-rose-400",
          "bg-rose-50/50",
          "dark:bg-rose-900/20"
        );
        button.classList.add(
          "text-slate-500",
          "dark:text-slate-400",
          "hover:text-rose-600",
          "dark:hover:text-rose-400"
        );
        if (iconEl) {
          iconEl.id = `hero-heart-icon-${post_id}`;
          iconEl.classList.remove("hero-heart-solid");
          iconEl.classList.add("hero-heart");
        }
      }

      if (button._tippy) {
        button._tippy.setContent(is_liked ? "Remove love" : "Show love");
      }
    }
  }
});

window.addEventListener("phx:update_post_bookmark", (event) => {
  const { post_id, is_bookmarked } = event.detail;

  const bookmarkedButton = document.getElementById(
    `hero-bookmark-solid-button-${post_id}`
  );
  const unbookmarkedButton = document.getElementById(
    `hero-bookmark-button-${post_id}`
  );
  const button = bookmarkedButton || unbookmarkedButton;

  if (button) {
    const iconEl = button.querySelector("[id^='hero-bookmark']");

    if (is_bookmarked) {
      button.id = `hero-bookmark-solid-button-${post_id}`;
      button.setAttribute("data-tippy-content", "Remove bookmark");
      button.classList.remove(
        "text-slate-400",
        "hover:text-amber-600",
        "dark:hover:text-amber-400",
        "hover:bg-amber-50/50",
        "dark:hover:bg-amber-900/20"
      );
      button.classList.add(
        "text-amber-600",
        "dark:text-amber-400",
        "bg-amber-50/50",
        "dark:bg-amber-900/20"
      );
      if (iconEl) {
        iconEl.id = `hero-bookmark-solid-icon-${post_id}`;
        iconEl.classList.remove("hero-bookmark");
        iconEl.classList.add("hero-bookmark-solid");
      }
    } else {
      button.id = `hero-bookmark-button-${post_id}`;
      button.setAttribute("data-tippy-content", "Bookmark this post");
      button.classList.remove(
        "text-amber-600",
        "dark:text-amber-400",
        "bg-amber-50/50",
        "dark:bg-amber-900/20"
      );
      button.classList.add(
        "text-slate-400",
        "hover:text-amber-600",
        "dark:hover:text-amber-400",
        "hover:bg-amber-50/50",
        "dark:hover:bg-amber-900/20"
      );
      if (iconEl) {
        iconEl.id = `hero-bookmark-icon-${post_id}`;
        iconEl.classList.remove("hero-bookmark-solid");
        iconEl.classList.add("hero-bookmark");
      }
    }

    if (button._tippy) {
      button._tippy.setContent(
        is_bookmarked ? "Remove bookmark" : "Bookmark this post"
      );
    }
  }
});

window.addEventListener("phx:update_post_repost_count", (event) => {
  const { post_id, reposts_count, can_repost } = event.detail;

  const countElements = document.querySelectorAll(
    `[data-post-repost-count="${post_id}"]`
  );
  countElements.forEach((el) => {
    el.textContent = reposts_count > 0 ? reposts_count : "";
  });

  if (can_repost === false) {
    const repostButton = document.getElementById(`repost-button-${post_id}`);

    if (repostButton) {
      repostButton.removeAttribute("phx-click");
      repostButton.removeAttribute("phx-value-id");
      repostButton.removeAttribute("phx-value-body");
      repostButton.removeAttribute("phx-value-username");
      repostButton.classList.add("cursor-not-allowed", "opacity-60");
      repostButton.classList.add(
        "text-emerald-600",
        "dark:text-emerald-400",
        "bg-emerald-50/50",
        "dark:bg-emerald-900/20"
      );
      repostButton.setAttribute(
        "data-tippy-content",
        "You have already reposted this"
      );

      if (repostButton._tippy) {
        repostButton._tippy.setContent("You have already reposted this");
      }
    }
  }
});

window.addEventListener("phx:update_reply_fav_count", (event) => {
  const { reply_id, favs_count, is_liked } = event.detail;
  const countElements = document.querySelectorAll(
    `[data-reply-fav-count="${reply_id}"]`
  );
  countElements.forEach((el) => {
    el.textContent = favs_count > 0 ? favs_count : "";
  });

  if (is_liked !== undefined) {
    const likedButton = document.getElementById(
      `hero-heart-solid-reply-button-${reply_id}`
    );
    const unlikedButton = document.getElementById(
      `hero-heart-reply-button-${reply_id}`
    );
    const button = likedButton || unlikedButton;

    if (button) {
      const iconEl = button.querySelector("[id^='hero-heart']");

      if (is_liked) {
        button.id = `hero-heart-solid-reply-button-${reply_id}`;
        button.setAttribute("phx-click", "unfav_reply");
        button.setAttribute("data-tippy-content", "Remove love");
        button.classList.remove(
          "text-slate-500",
          "dark:text-slate-400",
          "hover:text-rose-600",
          "dark:hover:text-rose-400"
        );
        button.classList.add(
          "text-rose-600",
          "dark:text-rose-400",
          "bg-rose-50/50",
          "dark:bg-rose-900/20"
        );
        if (iconEl) {
          iconEl.id = `hero-heart-solid-reply-icon-${reply_id}`;
          iconEl.classList.remove("hero-heart");
          iconEl.classList.add("hero-heart-solid");
        }
      } else {
        button.id = `hero-heart-reply-button-${reply_id}`;
        button.setAttribute("phx-click", "fav_reply");
        button.setAttribute("data-tippy-content", "Show love");
        button.classList.remove(
          "text-rose-600",
          "dark:text-rose-400",
          "bg-rose-50/50",
          "dark:bg-rose-900/20"
        );
        button.classList.add(
          "text-slate-500",
          "dark:text-slate-400",
          "hover:text-rose-600",
          "dark:hover:text-rose-400"
        );
        if (iconEl) {
          iconEl.id = `hero-heart-reply-icon-${reply_id}`;
          iconEl.classList.remove("hero-heart-solid");
          iconEl.classList.add("hero-heart");
        }
      }

      if (button._tippy) {
        button._tippy.setContent(is_liked ? "Remove love" : "Show love");
      }
    }
  }
});

window.addEventListener("phx:remove-el", (e) =>
  document.getElementById(e.detail.id).remove()
);

window.addEventListener("mosslet:decrement-badge", (e) => {
  const badge = e.target;
  if (!badge) return;

  const decrement = e.detail?.decrement || 1;
  const currentCount = parseInt(badge.textContent, 10) || 0;
  const newCount = Math.max(0, currentCount - decrement);

  if (newCount <= 0) {
    badge.style.display = "none";
  } else {
    badge.textContent = newCount > 99 ? "99+" : newCount;
  }
});

window.addEventListener("phx:update-reply-badge", (e) => {
  const { post_id, count } = e.detail;
  const badge = document.getElementById(
    `notification-badge-reply-button-${post_id}`
  );
  if (!badge) return;

  if (count <= 0) {
    badge.style.display = "none";
  } else {
    badge.style.display = "";
    badge.textContent = count > 99 ? "99+" : count;
  }
});

window.addEventListener("phx:open_external_url", (event) => {
  const url = event.detail.url;
  if (url) {
    window.open(url, "_blank", "noopener,noreferrer");
  }
});

window.addEventListener("phx:clipcopy", (event) => {
  if ("clipboard" in navigator) {
    var text;
    const target = event.target;

    // Check if we have a custom data attribute for copy text
    const customCopyText = target.getAttribute("data-copy-text");
    if (customCopyText) {
      text = customCopyText;
    } else if (
      target.id === "backup-codes-list" ||
      target.closest("#backup-codes-list")
    ) {
      // Special handling for backup codes - extract codes and format with spaces
      const codeElements = document.querySelectorAll(
        "#backup-codes-list .font-mono"
      );
      const codes = Array.from(codeElements)
        .map((el) => el.textContent.trim())
        .filter((code) => code && !el.classList.contains("line-through")) // Skip used codes
        .join(" ");
      text = codes;
    } else {
      // Default behavior - copy the element's text content
      text = target.textContent.trim();
    }

    document.querySelectorAll(`[data-clipboard-copy]`).forEach((el) => {
      if (el.id == event.detail.dispatcher.id) {
        liveSocket.execJS(el, el.getAttribute("data-clipboard-copy"));
      }
    });

    navigator.clipboard.writeText(text).then(() => {
      // Generate client-side timestamp for flash message
      const now = new Date();
      const timeString = now.toLocaleTimeString("en-US", {
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
        hour12: true,
      });

      // Send a custom event with timestamp that the LiveView can handle
      const timestampEvent = new CustomEvent("phx:clipcopy-timestamp", {
        detail: { timestamp: timeString, dispatcher: event.detail.dispatcher },
      });
      document.dispatchEvent(timestampEvent);
    });
  } else {
    alert("Sorry, your browser does not support clipboard copy.");
  }
});

let execJS = (selector, attr) => {
  document
    .querySelectorAll(selector)
    .forEach((el) => liveSocket.execJS(el, el.getAttribute(attr)));
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

// Custom confirmation dialog for Phoenix LiveView data-confirm
// Intercepts clicks on elements with data-confirm attribute
document.addEventListener(
  "click",
  (e) => {
    const element = e.target.closest("[data-confirm]");
    if (!element) return;

    const message = element.getAttribute("data-confirm");
    if (!message) return;

    // Prevent the default action
    e.preventDefault();
    e.stopImmediatePropagation();

    const actionText = element.getAttribute("data-confirm-action");

    // Show our custom confirmation dialog
    showCustomConfirm(message, actionText, () => {
      // User confirmed - trigger the action without data-confirm
      const originalConfirm = element.getAttribute("data-confirm");
      element.removeAttribute("data-confirm");

      // Create a new click event and dispatch it
      const newEvent = new MouseEvent("click", {
        bubbles: true,
        cancelable: true,
        view: window,
      });

      element.dispatchEvent(newEvent);

      // Restore data-confirm for future use
      setTimeout(() => {
        element.setAttribute("data-confirm", originalConfirm);
      }, 100);
    });
  },
  true
); // Use capture phase to intercept before Phoenix

function extractActionFromMessage(message) {
  const match = message.match(/want to (\w+)/i);
  if (match && match[1]) {
    const action = match[1].toLowerCase();
    return action.charAt(0).toUpperCase() + action.slice(1);
  }
  return null;
}

function showCustomConfirm(message, actionText, onConfirm) {
  const buttonLabel =
    actionText || extractActionFromMessage(message) || "Confirm";
  // Create dialog element that matches our CSS selectors
  const dialog = document.createElement("dialog");
  dialog.setAttribute("data-confirm", "");

  // Create and safely set the message using textContent to prevent XSS
  const messageElement = document.createElement("p");
  messageElement.textContent = message; // Safe - prevents script injection

  const buttonsDiv = document.createElement("div");
  buttonsDiv.className = "dialog-buttons";

  const cancelButton = document.createElement("button");
  cancelButton.type = "button";
  cancelButton.setAttribute("data-confirm-cancel", "");
  cancelButton.textContent = "Cancel";

  const acceptButton = document.createElement("button");
  acceptButton.type = "button";
  acceptButton.setAttribute("data-confirm-accept", "");
  acceptButton.textContent = buttonLabel;

  buttonsDiv.appendChild(cancelButton);
  buttonsDiv.appendChild(acceptButton);

  dialog.appendChild(messageElement);
  dialog.appendChild(buttonsDiv);

  document.body.appendChild(dialog);

  // Show dialog with animation
  dialog.showModal();

  // Trigger the open state for CSS animations
  requestAnimationFrame(() => {
    dialog.setAttribute("open", "");
  });

  // Handle button clicks
  dialog.querySelector("[data-confirm-cancel]").onclick = () => {
    dialog.close();
    document.body.removeChild(dialog);
  };

  dialog.querySelector("[data-confirm-accept]").onclick = () => {
    dialog.close();
    document.body.removeChild(dialog);
    onConfirm();
  };

  // Close on backdrop click
  dialog.onclick = (e) => {
    if (e.target === dialog) {
      dialog.close();
      document.body.removeChild(dialog);
    }
  };

  // Close on ESC key
  dialog.onkeydown = (e) => {
    if (e.key === "Escape") {
      dialog.close();
      document.body.removeChild(dialog);
    }
  };
}

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  hooks: Object.assign(
    {},
    mossletHooks,
    {
      LocalTime: mossletHooks.LocalTime,
      LocalTimeAgo: mossletHooks.LocalTimeAgo,
      LocalTimeFull: mossletHooks.LocalTimeFull,
      LocalTimeMed: mossletHooks.LocalTimeMed,
      LocalTimeNow: mossletHooks.LocalTimeNow,
      LocalTimeNowMed: mossletHooks.LocalTimeNowMed,
    },
    live_select
  ),
  params: {
    _csrf_token: csrfToken,
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
  },
  dom: {
    onNodeAdded(el) {
      if (el.nodeType == 1 && el._x_marker) {
        el._x_marker = undefined;
        window.Alpine.initTree(el);
      } else if (el instanceof HTMLElement && el.autofocus) {
        el.focus(); // This allows you to auto focus with <input autofocus />
      }
    },
    onBeforeElUpdated(from, to) {
      // AlpineJS v3
      if (from._x_dataStack) {
        window.Alpine.clone(from, to);
      }
    },
  },
});

// Show progress bar on live navigation and form submits
topbar.config({
  barColors: { 0: "#059669" },
  shadowColor: "rgba(0, 0, 0, .3)",
});
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.getSocket().onOpen(() => execJS("#connection-status", "js-hide"));
liveSocket.getSocket().onError(() => execJS("#connection-status", "js-show"));
liveSocket.connect();

// Mood picker custom event handler
document.addEventListener("mood:select", (event) => {
  const { mood, input_id } = event.detail;
  const input = document.getElementById(input_id);
  if (input) {
    input.value = mood;
    input.dispatchEvent(new Event("input", { bubbles: true }));
  }
});

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
