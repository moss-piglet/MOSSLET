/**
 * CapsuleLetterFormHook — browser-side time-capsule encryption (ZK write path).
 *
 * A time capsule is a "letter to your future self". This hook intercepts the
 * letter form submit, encrypts the letter's title/body with the user_key, and
 * pushes a `save_capsule_zk` event carrying only ciphertext. The server sees
 * the delivery date and cosmetic stationery — never the words.
 *
 * Data attributes on the form:
 *   data-sealed-user-key — sealed user_key (from user.user_key)
 *
 * Plaintext metadata (deliver_on, stationery) rides along as normal form
 * fields and is read server-side; only title/body are encrypted here.
 */
import { encryptWithKey, getUserKey, getPublicKey } from "../crypto/session";

const CapsuleLetterFormHook = {
  mounted() {
    this._userKey = null;
    this._unsealKey();
    this.el.addEventListener("submit", (e) => this._onSubmit(e), true);

    // Enter in the single-line title must never seal the letter — that could
    // trap someone into sending an empty letter. Let it be a no-op there.
    const title = this.el.querySelector('input[name="capsule[title]"]');
    if (title) {
      title.addEventListener("keydown", (e) => {
        if (e.key === "Enter") e.preventDefault();
      });
    }

    // Gate the "Seal & send" button (which lives in the layout footer, outside
    // the form). On the capture phase — before the phx-click that opens the
    // confirmation modal fires — we:
    //   * block + gently warn if the letter has no words, and
    //   * stamp the chosen delivery date onto the button so the server can show
    //     the correct date in the confirm modal (metadata only, never content).
    this._sealBtn = document.getElementById("capsule-seal-btn");
    if (this._sealBtn) {
      this._onSealClick = (e) => this._prepareSeal(e);
      this._sealBtn.addEventListener("click", this._onSealClick, true);
    }

    // Keep the "stays sealed for …" preview live, client-side, so we never
    // round-trip the (metadata) date on every change.
    this._dateInput = this.el.querySelector('input[name="capsule[deliver_on]"]');
    if (this._dateInput) {
      this._onDateChange = () => this._updateDurationPreview();
      this._dateInput.addEventListener("change", this._onDateChange);
      this._dateInput.addEventListener("input", this._onDateChange);
      // The date input lives inside a phx-update="ignore" container, so the
      // server's initial (UTC, connect-param-less) render would otherwise get
      // frozen in. Re-derive min + default from the BROWSER's real local date
      // so the picker is always correct for the user — while staying valid
      // against the server's UTC "must be a future date" gate.
      this._setupDates();
    }
  },

  _setupDates() {
    const pad = (n) => String(n).padStart(2, "0");
    const isoLocal = (d) =>
      `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;

    const now = new Date();

    // Earliest selectable day is the viewer's LOCAL tomorrow — delivery is
    // judged against their calendar (the server validates against the same
    // local "today", passed from the LiveView).
    const localTomorrow = new Date(now);
    localTomorrow.setHours(0, 0, 0, 0);
    localTomorrow.setDate(localTomorrow.getDate() + 1);
    this._dateInput.min = isoLocal(localTomorrow);

    const def = new Date(now);
    def.setHours(0, 0, 0, 0);
    def.setDate(def.getDate() + 365);
    const defStr = isoLocal(def);

    if (!this._dateInput.value || this._dateInput.value < this._dateInput.min) {
      this._dateInput.value = defStr;
    }

    this._updateDurationPreview();
  },

  destroyed() {
    if (this._sealBtn && this._onSealClick) {
      this._sealBtn.removeEventListener("click", this._onSealClick, true);
    }
  },

  _updateDurationPreview() {
    const target = document.getElementById("capsule-seal-duration");
    if (!target || !this._dateInput?.value) return;

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const target_date = new Date(this._dateInput.value + "T00:00:00");
    const days = Math.round((target_date - today) / 86400000);

    target.textContent = this._humanize(days);
  },

  _humanize(days) {
    const q = (n, unit) => `${n} ${unit}${n === 1 ? "" : "s"}`;
    if (days <= 0) return "no time at all";
    if (days < 7) return q(days, "day");
    if (days < 45) return q(Math.round(days / 7), "week");
    if (days < 365) return q(Math.round(days / 30), "month");
    return q(Math.round(days / 365), "year");
  },

  _prepareSeal(e) {
    const body =
      this.el.querySelector('textarea[name="capsule[body]"]')?.value || "";

    if (!body.trim()) {
      e.preventDefault();
      e.stopImmediatePropagation();
      this.pushEvent("capsule_empty", {});
      return;
    }

    const deliverOn =
      this.el.querySelector('input[name="capsule[deliver_on]"]')?.value || "";
    this._sealBtn.setAttribute("phx-value-date", deliverOn);
  },

  updated() {
    if (!this._userKey) this._unsealKey();
  },

  async _unsealKey() {
    if (!getPublicKey()) {
      window.addEventListener("mosslet:keys-ready", () => this._unsealKey(), {
        once: true,
      });
      return;
    }

    const sealedKey = this.el.dataset.sealedUserKey;
    if (!sealedKey) return;

    try {
      this._userKey = await getUserKey(sealedKey);
    } catch (e) {
      console.error("CapsuleLetterFormHook: failed to unseal user key:", e);
    }
  },

  _onSubmit(e) {
    if (!this._userKey) return;

    e.preventDefault();
    e.stopImmediatePropagation();

    const body =
      this.el.querySelector('textarea[name="capsule[body]"]')?.value || "";

    // The confirmation modal is the intent gate; this is just a safety net.
    if (!body.trim()) {
      this.pushEvent("capsule_empty", {});
      return;
    }

    this._encryptAndPush("save_capsule_zk").catch((err) => {
      console.error("CapsuleLetterFormHook: encryption failed:", err);
      this.pushEvent("capsule_encrypt_failed", {});
    });
  },

  async _encryptAndPush(eventName) {
    const title =
      this.el.querySelector('input[name="capsule[title]"]')?.value || "";
    const body =
      this.el.querySelector('textarea[name="capsule[body]"]')?.value || "";
    const deliverOn =
      this.el.querySelector('input[name="capsule[deliver_on]"]')?.value || "";
    const stationery =
      this.el.querySelector('input[name="capsule[stationery]"]')?.value ||
      this.el.querySelector('select[name="capsule[stationery]"]')?.value ||
      "classic";

    const [encTitle, encBody] = await Promise.all([
      title.trim() ? encryptWithKey(title, this._userKey) : null,
      body.trim() ? encryptWithKey(body, this._userKey) : null,
    ]);

    const wordCount = body
      .trim()
      .split(/\s+/)
      .filter((w) => w.length > 0).length;

    this.pushEvent(eventName, {
      encrypted_title: encTitle,
      encrypted_body: encBody,
      deliver_on: deliverOn,
      stationery: stationery,
      word_count: wordCount,
    });
  },
};

export default CapsuleLetterFormHook;
