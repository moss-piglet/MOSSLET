/**
 * Org display avatar helpers (Task #277) — shared by the circle-chat hooks
 * (DecryptGroupMessage message headers + MentionPicker dropdown).
 *
 * An org-mate's org avatar is the resized WebP bytes encrypted with the shared
 * `org_key` (secretbox). Org-mates decrypt it browser-side with the `org_key`
 * they already hold (sealed in their Membership.key) — the server never sees the
 * plaintext image. When a member hasn't set an org avatar, we fall back to
 * INITIALS derived from their org display name (never the bare Mosslet logo, and
 * never their personal avatar — persona separation).
 */
import { decryptSecretbox, b64Encode } from "../crypto/session";

// Deterministic, pleasant background for the initials avatar, derived from the
// name so a given person keeps the same color across renders.
const INITIALS_PALETTE = [
  "#0d9488", // teal-600
  "#059669", // emerald-600
  "#0891b2", // cyan-600
  "#7c3aed", // violet-600
  "#db2777", // pink-600
  "#d97706", // amber-600
  "#dc2626", // red-600
  "#2563eb", // blue-600
];

function hashString(str) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = (hash << 5) - hash + str.charCodeAt(i);
    hash |= 0;
  }
  return Math.abs(hash);
}

function initialsFor(name) {
  const parts = String(name || "")
    .trim()
    .split(/[\s—–-]+/)
    .filter(Boolean);

  if (parts.length === 0) return "?";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

/**
 * Returns a data URL for a circular initials avatar derived from `name`.
 * `size` is the pixel dimension (square). Returns null when no name is given.
 */
export function orgInitialsDataUrl(name, size = 80) {
  if (!name) return null;

  try {
    const canvas = document.createElement("canvas");
    canvas.width = size;
    canvas.height = size;
    const ctx = canvas.getContext("2d");
    if (!ctx) return null;

    const color = INITIALS_PALETTE[hashString(name) % INITIALS_PALETTE.length];
    ctx.fillStyle = color;
    ctx.fillRect(0, 0, size, size);

    ctx.fillStyle = "#ffffff";
    ctx.font = `600 ${Math.round(size * 0.42)}px ui-sans-serif, system-ui, -apple-system, sans-serif`;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(initialsFor(name), size / 2, size / 2 + size * 0.02);

    return canvas.toDataURL("image/png");
  } catch (_e) {
    return null;
  }
}

/**
 * Decrypts an org avatar ciphertext (org_key-secretbox of WebP bytes) into a
 * displayable `data:` URL. Returns null on any failure (caller falls back to
 * initials).
 */
export async function decryptOrgAvatarUrl(ciphertext, orgKey) {
  if (!ciphertext || !orgKey) return null;

  try {
    const bytes = await decryptSecretbox(ciphertext, orgKey);
    if (!bytes) return null;
    return `data:image/webp;base64,${b64Encode(bytes)}`;
  } catch (_e) {
    return null;
  }
}
