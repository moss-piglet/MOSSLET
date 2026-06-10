/**
 * ProfileAboutFormHook — browser-side profile about/bio encryption (ZK write path).
 *
 * Intercepts the profile form submit for non-public profiles, encrypts the
 * four profile-embedded fields (about, alternate_email, website_url, website_label)
 * with the profile_key, and pushes a ZK event. The server stores only ciphertext.
 *
 * For profile updates: unseals the existing profile_key from data-sealed-profile-key.
 * For profile creation: unseals the conn_key (the new profile_key derives from it).
 * For public profiles: falls through to normal form submit (server handles encryption).
 *
 * Data attributes on the form:
 *   data-sealed-profile-key  — base64 sealed profile_key (for update)
 *   data-visibility          — "public", "private", or "connections"
 *   data-action              — "update" or "create"
 */
import {
  unsealContextKey,
  getPublicKey,
  unwrapKey,
  encryptWithKey,
  getConnKey,
  getSealedConnKey,
} from "../crypto/session";

const ProfileAboutFormHook = {
  mounted() {
    this._profileKey = null;
    this._unsealKey();
    this.el.addEventListener("submit", (e) => this._onSubmit(e), true);
  },

  updated() {
    if (!this._profileKey) this._unsealKey();
  },

  async _unsealKey() {
    const visibility = this.el.dataset.visibility;
    if (visibility === "public") return;

    if (!getPublicKey()) {
      window.addEventListener(
        "mosslet:keys-ready",
        () => this._unsealKey(),
        { once: true },
      );
      return;
    }

    try {
      const action = this.el.dataset.action;
      if (action === "update") {
        const sealedKey = this.el.dataset.sealedProfileKey;
        if (!sealedKey) return;
        const raw = await unsealContextKey(sealedKey);
        if (raw) this._profileKey = unwrapKey(raw);
      } else {
        // Create: profile_key derives from conn_key
        const sealedConnKey = getSealedConnKey();
        if (!sealedConnKey) return;
        this._profileKey = await getConnKey(sealedConnKey);
      }
    } catch (e) {
      console.error("ProfileAboutFormHook: failed to unseal key:", e);
    }
  },

  _onSubmit(e) {
    const visibility = this.el.dataset.visibility;
    if (visibility === "public") return;
    if (!this._profileKey) return;

    e.preventDefault();
    e.stopImmediatePropagation();

    this._encryptAndSubmit().catch((err) => {
      console.error(
        "ProfileAboutFormHook: encryption failed, falling back:",
        err,
      );
      this.el.dispatchEvent(
        new Event("submit", { bubbles: true, cancelable: true }),
      );
    });
  },

  async _encryptAndSubmit() {
    const prefix = "connection[profile]";
    const aboutInput = this.el.querySelector(`[name="${prefix}[about]"]`);
    const altEmailInput = this.el.querySelector(
      `[name="${prefix}[alternate_email]"]`,
    );
    const websiteUrlInput = this.el.querySelector(
      `[name="${prefix}[website_url]"]`,
    );
    const websiteLabelInput = this.el.querySelector(
      `[name="${prefix}[website_label]"]`,
    );

    const about = aboutInput?.value || "";
    const altEmail = altEmailInput?.value?.trim() || "";
    const websiteUrl = websiteUrlInput?.value?.trim() || "";
    const websiteLabel = websiteLabelInput?.value?.trim() || "";

    const [encAbout, encAltEmail, encWebsiteUrl, encWebsiteLabel] =
      await Promise.all([
        about ? encryptWithKey(about, this._profileKey) : Promise.resolve(null),
        altEmail
          ? encryptWithKey(altEmail, this._profileKey)
          : Promise.resolve(null),
        websiteUrl
          ? encryptWithKey(websiteUrl, this._profileKey)
          : Promise.resolve(null),
        websiteLabel
          ? encryptWithKey(websiteLabel, this._profileKey)
          : Promise.resolve(null),
      ]);

    // Collect non-encrypted form fields that pass through normally
    const bannerImageInput = this.el.querySelector(
      `input[name="${prefix}[banner_image]"]:checked`,
    );
    // Each checkbox is preceded by a hidden `value="false"` input sharing the
    // same name (the standard Phoenix pattern). We must read the checkbox
    // itself, not the hidden fallback, so scope the selector to the checkbox.
    const showAvatarInput = this.el.querySelector(
      `input[type="checkbox"][name="${prefix}[show_avatar?]"]`,
    );
    const showEmailInput = this.el.querySelector(
      `input[type="checkbox"][name="${prefix}[show_email?]"]`,
    );
    const showNameInput = this.el.querySelector(
      `input[type="checkbox"][name="${prefix}[show_name?]"]`,
    );

    this.pushEvent("save_profile_zk", {
      encrypted_about: encAbout,
      encrypted_alternate_email: encAltEmail,
      encrypted_website_url: encWebsiteUrl,
      encrypted_website_label: encWebsiteLabel,
      banner_image: bannerImageInput?.value || "waves",
      // The avatar checkbox only renders when an avatar exists. When it is
      // absent, send null so the server preserves the stored value rather than
      // force-disabling it. The other two checkboxes always render.
      show_avatar: showAvatarInput ? showAvatarInput.checked : null,
      show_email: showEmailInput?.checked ?? false,
      show_name: showNameInput?.checked ?? false,
      action: this.el.dataset.action,
    });
  },
};

export default ProfileAboutFormHook;
