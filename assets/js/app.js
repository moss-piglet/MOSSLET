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

import Alpine from "../vendor/alpinejs";
import collapse from "../vendor/@alpinejs/collapse";
import focus from "../vendor/@alpinejs/focus";
import "../vendor/@alpinejs/persist";
import ui from "../vendor/@alpinejs/ui";

// Import tippy.js from npm package
import tippy from "tippy.js";

// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";

import live_select from "live_select";

// Add your custom hooks to the hooks folder - then import them in hooks/index.js
import mossletHooks from "./hooks/index";

Alpine.plugin(collapse);
Alpine.plugin(focus);
Alpine.plugin(ui);

window.Alpine = Alpine;

// Make tippy globally available
window.tippy = tippy;

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
    "beforeend"
    '<button type="button" class="trix-button trix-button--icon trix-button--icon-highlight" data-trix-attribute="highlight" data-trix-key="y" title="Highlight" tabindex="-1"><span class="align-middle"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="size-5"><path fill-rule="evenodd" d="M20.599 1.5c-.376 0-.743.111-1.055.32l-5.08 3.385a18.747 18.747 0 0 0-3.471 2.987 10.04 10.04 0 0 1 4.815 4.815 18.748 18.748 0 0 0 2.987-3.472l3.386-5.079A1.902 1.902 0 0 0 20.599 1.5Zm-8.3 14.025a18.76 18.76 0 0 0 1.896-1.207 8.026 8.026 0 0 0-4.513-4.513A18.75 18.75 0 0 0 8.475 11.7l-.278.5a5.26 5.26 0 0 1 3.601 3.602l.502-.278ZM6.75 13.5A3.75 3.75 0 0 0 3 17.25a1.5 1.5 0 0 1-1.601 1.497.75.75 0 0 0-.7 1.123 5.25 5.25 0 0 0 9.8-2.62 3.75 3.75 0 0 0-3.75-3.75Z" clip-rule="evenodd" /></svg></span></button>',
  );

  groupElement.insertAdjacentHTML(
    "beforeend"
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
    </div>`,
  );
});

window.addEventListener("phx:show-el", (e) =>
  document.getElementById(e.detail.id).removeAttribute("style"),
);

window.addEventListener("phx:remove-el", (e) =>
  document.getElementById(e.detail.id).remove(),
);

let execJS = (selector, attr) => {
  document
    .querySelectorAll(selector)
    .forEach((el) => liveSocket.execJS(el, el.getAttribute(attr)));
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500
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
    live_select,
  ),
  params: { _csrf_token: csrfToken },
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

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
