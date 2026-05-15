/**
 * Persistent key cache using IndexedDB + localStorage.
 *
 * Derived keys are encrypted with a non-extractable AES-256-GCM wrapping key
 * stored in IndexedDB. The encrypted blob lives in localStorage so it survives
 * browser restarts without re-entering the password.
 *
 * Security model:
 *   - The wrapping key is CryptoKey with `extractable: false` — JS cannot
 *     read it, only use it for encrypt/decrypt via Web Crypto.
 *   - An attacker who copies localStorage gets only encrypted ciphertext.
 *   - Clearing IndexedDB (or a different browser profile) invalidates the cache.
 *   - Cache is cleared on logout and password change.
 */

const DB_NAME = "_mosslet_crypto";
const DB_VERSION = 1;
const STORE_NAME = "keys";
const WRAPPING_KEY_ID = "wrapping_key";
const LS_CACHE_KEY = "_mosslet_key_cache";

/**
 * Open (or create) the IndexedDB database.
 * @returns {Promise<IDBDatabase>}
 */
function openDB() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = () => {
      request.result.createObjectStore(STORE_NAME);
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

/**
 * Retrieve the AES-256-GCM wrapping key from IndexedDB, generating one if absent.
 * @returns {Promise<CryptoKey>}
 */
async function getOrCreateWrappingKey() {
  const db = await openDB();

  const existing = await new Promise((resolve) => {
    const tx = db.transaction(STORE_NAME, "readonly");
    const req = tx.objectStore(STORE_NAME).get(WRAPPING_KEY_ID);
    req.onsuccess = () => resolve(req.result || null);
    req.onerror = () => resolve(null);
  });

  if (existing) return existing;

  const key = await crypto.subtle.generateKey(
    { name: "AES-GCM", length: 256 },
    false, // non-extractable
    ["encrypt", "decrypt"],
  );

  await new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, "readwrite");
    tx.objectStore(STORE_NAME).put(key, WRAPPING_KEY_ID);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });

  return key;
}

/**
 * Cache derived keys persistently.
 *
 * Encrypts the key bundle with the IndexedDB wrapping key and stores the
 * ciphertext in localStorage.
 *
 * @param {Object} keys - Keys to cache
 * @param {string} keys.userKey - The decrypted user_key (base64)
 * @param {string} keys.privateKey - The decrypted X25519 private key (base64)
 * @param {string} [keys.pqPrivateKey] - The decrypted PQ private key (base64), if available
 */
export async function cacheKeys({ userKey, privateKey, pqPrivateKey }) {
  try {
    const wrappingKey = await getOrCreateWrappingKey();

    const iv = crypto.getRandomValues(new Uint8Array(12));
    const payload = JSON.stringify({
      userKey,
      privateKey,
      pqPrivateKey: pqPrivateKey || null,
      cachedAt: Date.now(),
    });
    const encoded = new TextEncoder().encode(payload);

    const encrypted = await crypto.subtle.encrypt(
      { name: "AES-GCM", iv },
      wrappingKey,
      encoded,
    );

    localStorage.setItem(
      LS_CACHE_KEY,
      JSON.stringify({
        iv: Array.from(iv),
        ct: Array.from(new Uint8Array(encrypted)),
      }),
    );
  } catch (e) {
    // Silently fail — cache is a UX optimization, not critical
    console.warn("Key cache write failed:", e);
  }
}

/**
 * Retrieve cached keys from persistent storage.
 *
 * @returns {Promise<{userKey: string, privateKey: string, pqPrivateKey: string|null, cachedAt: number}|null>}
 */
export async function getCachedKeys() {
  try {
    const raw = localStorage.getItem(LS_CACHE_KEY);
    if (!raw) return null;

    const db = await openDB();
    const key = await new Promise((resolve) => {
      const tx = db.transaction(STORE_NAME, "readonly");
      const req = tx.objectStore(STORE_NAME).get(WRAPPING_KEY_ID);
      req.onsuccess = () => resolve(req.result || null);
      req.onerror = () => resolve(null);
    });
    if (!key) return null;

    const { iv, ct } = JSON.parse(raw);
    const decrypted = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv: new Uint8Array(iv) },
      key,
      new Uint8Array(ct),
    );

    return JSON.parse(new TextDecoder().decode(decrypted));
  } catch {
    // Cache corrupted or wrapping key missing — clear and return null
    clearKeyCache();
    return null;
  }
}

/**
 * Clear all cached keys.
 *
 * Call on logout, password change, and account deletion.
 */
export function clearKeyCache() {
  try {
    localStorage.removeItem(LS_CACHE_KEY);
  } catch {
    // Best effort
  }
  try {
    indexedDB.deleteDatabase(DB_NAME);
  } catch {
    // Best effort
  }
}
