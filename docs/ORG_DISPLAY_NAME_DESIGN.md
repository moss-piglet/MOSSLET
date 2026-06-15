# 🪪 Mosslet Org-Scoped ZK Display Name — Design Doc (Task #225)

> **Status: APPROVED (Q1–Q5 resolved — see §9).**
> Part of EPIC #207. Companion docs: `BUSINESS_CIRCLES_DESIGN.md` (the per-org
> recipient-sealing pattern this mirrors, esp. §12 audit-key), and
> `ENCRYPTION_ARCHITECTURE.md` (trust boundaries, data-model conventions).

## 0. TL;DR

On the Family/Business org dashboard roster, members who are **not personally
connected** to the viewer show **"Team member"** instead of a name. This is
*correct* zero-knowledge behavior: today a member's name is only decryptable via
a `UserConnection` key sealed to the viewer (`resolve_display_name/3` →
`get_decrypted_connection_name/3` in `business_live/show.ex:684`). Two unconnected
org members genuinely cannot read each other's *personal* encrypted name, and we
have **no server-side master key** to fall back on.

**Fix (Option B — ZK-native org identity):** Introduce a per-org symmetric
**`org_key`**, sealed *per member* to that member's public key (Cat-5 hybrid
ML-KEM-1024 + X25519 via `sealForUser`), stored on a new **`Membership.key`**
field — exactly the shape of `UserGroup.key` and the §12 `UserOrgAuditKey.key`.
Each member sets an org-facing **`Membership.display_name`** (e.g. "Mark —
Engineering"), encrypted browser-side with the `org_key`. The roster is rendered
by a new browser hook (mirroring `DecryptGroupMetadata`) that unseals
`Membership.key` → `org_key` → decrypts every member's `display_name`. The raw
`org_key` and plaintext display names **never reach the server**.

The existing `UserConnection` architecture is **untouched** — it remains the
personal-identity path. The org display name is a deliberately *separate* persona
scoped to the org.

## 1. Goals & Non-Goals

### Goals

1. Every member of an org can **recognize every other member** on the roster
   (and anywhere we list org members), without needing a personal
   `UserConnection` to them.
2. **Zero new cryptographic primitives.** Reuse `generateKey()`, `sealForUser`,
   `unsealContextKey`, `encryptSecretboxString`/`decryptWithKey` exactly as
   shipped for circles and the audit key.
3. A privacy-preserving **org persona** distinct from the member's personal
   identity — a member chooses what name their org sees.
4. Scales to 20+ seats: sealing is O(members) and happens only at
   create/accept/add/backfill, not on every render.
5. Server-authoritative recipient set (the org's `Membership` rows); a tampered
   client can never seal the `org_key` for a non-member.

### Non-Goals / forbidden

- ❌ **No server master key. No silent server-side decryption.** The server only
  ever holds sealed `org_key` copies and ciphertext display names.
- ❌ **No change to `UserConnection`** or the personal-name path. "You" and
  connected-member resolution stay as-is (they can layer on top — see §7.3).
- ❌ **No key material / plaintext name in URL, Oban args, or email.**
- ❌ No reuse of the personal display name as the org name (separate persona;
  members opt in to what the org sees).

## 2. Threat model & invariants

Trust boundaries unchanged from `ENCRYPTION_ARCHITECTURE.md`:

- **Server sees:** Cloak-wrapped, `sealForUser`-sealed `org_key` blobs
  (`Membership.key`) and ciphertext display names (`Membership.display_name`).
  Never the `org_key` in the clear, never a plaintext org display name.
- **Browser (member's device):** unseals `org_key` with the member's own private
  key, decrypts every member's display name, and encrypts its own.

Invariants (review/CI checklist):

1. **D1 — Recipient set is server-authoritative.** The users an `org_key` may be
   sealed for are resolved server-side from `Orgs.Membership` of that `org_id`.
   The browser seals only for the public keys the server hands it. A tampered
   client cannot seal for a non-member.
2. **D2 — No master/server read key.** The server never seals the `org_key` for
   itself and never decrypts a `display_name`. Identical to `UserGroup`/audit.
3. **D3 — Same crypto everywhere.** `sealForUser(keyBytes, public_key,
   pq_public_key)` for sealing; `unsealContextKey` + `decryptWithKey` for
   reading. No bespoke KEM.
4. **D4 — `key`/`display_name` are programmatic, never `cast` from user params.**
   `Membership.key` is set only via the ZK seal path; `display_name` ciphertext
   comes from the browser hook payload, written via an explicit context fn.
5. **D5 — One `org_key` per org.** Every member's `Membership.key` unseals to the
   *same* raw `org_key`, so any member can decrypt any member's display name.

## 3. Data model

Follows `ENCRYPTION_ARCHITECTURE.md`: enums/booleans/FKs are plaintext system
data; human text stays encrypted. Migration via `mix ecto.gen.migration`.

### 3.1 `Orgs.Membership` — two new fields (the only schema change)

```elixir
# in schema "orgs_memberships"
field :key, Encrypted.Binary, redact: true          # org_key sealed FOR this member (sealForUser)
field :display_name, Encrypted.Binary, redact: true # org persona, encrypted WITH org_key (secretbox)
```

- `key` — the per-org symmetric `org_key`, **sealed for this member** via
  `sealForUser` (Cat-5 hybrid). Exactly mirrors `UserGroup.key` /
  `UserOrgAuditKey.key`. Set only by the ZK seal path (D4). Nullable: a member
  who predates this feature (or whose seal is pending backfill) has `nil` until
  sealed — handled gracefully (§7.4).
- `display_name` — the member's org-facing persona, **encrypted with the
  `org_key`** (secretbox) in the browser. Nullable: a member who hasn't set one
  yet shows a neutral placeholder + a "set your name" prompt (§7.4). No
  `display_name_hash` for now — we don't need server-side lookup by org name
  (roster is enumerated by membership rows, decrypted client-side). Add later
  only if a real lookup need appears.

Migration: `add :key, :binary` and `add :display_name, :binary` to
`orgs_memberships`, both `null: true`. (`Encrypted.Binary` columns are plain
`:binary` at the DB level — Cloak handles wrapping.)

### 3.2 No new tables, no new `Org` field

The `org_key` exists **only** as the set of per-member sealed copies in
`Membership.key` (no plaintext key stored anywhere server-side — same as
`group_key` and the audit key). There is intentionally no `Org.key` column.

## 4. `org_key` lifecycle — generation, sealing, distribution

The `org_key` is born in the **creator's browser** and propagates by sealing for
each subsequent member. There are four touchpoints; all reuse the
circle/audit-key mechanics.

### 4.1 Where the `org_key` is generated

Org creation today (`Orgs.create_org/2` → `Adapters.Web.create_org/2`) is a
plain server-side insert with **no browser crypto** — so unlike circle creation,
there's no existing two-phase commit to piggyback on. Two viable options:

- **Option A (lazy, mirrors §12 audit key) — RECOMMENDED.** The org is created
  server-side as today (no crypto in the create transaction). The `org_key` is
  generated + sealed lazily by the **creator's browser** the first time they land
  on their org dashboard with no `Membership.key` yet (an `EnsureOrgKey` hook,
  analogous to "first admin opens the audit panel"). This keeps the create
  transaction simple and avoids reworking `create_org`. The creator's roster
  simply shows the "set your org name" prompt until they do.
- **Option B (eager, mirrors circle two-phase create).** Rework
  `create_business`/`create_family` submit into a browser-side two-phase commit
  that generates the `org_key`, seals the creator's copy, and posts it with the
  create. More invasive to the create path; defers nothing.

> **Decision needed (Q1):** A vs B. Recommendation: **A** — smaller blast radius,
> matches the already-approved audit-key laziness, and the org create path stays
> a trivial server insert. The seal happens on first dashboard visit.

Either way: `generateKey()` → `org_key`; `sealForUser(orgKeyBytes, creatorPk,
creatorPqPk)` → creator's `Membership.key`; the creator then (or later) sets
their `display_name`.

### 4.2 Sealing for an invited member at accept time

When an invitation is accepted, a new `Membership` row is created
(`accept_invitation/2`, `accept_invitation_record/2`, and the auto-accept path).
The **accepting member's browser** must seal the `org_key` for itself. But the
accepting member doesn't yet hold the `org_key` — only existing members do.

This is the same "add a new member to a circle" problem, solved the same way:
an **existing member who holds the `org_key`** seals it for the newcomer. Two
sub-options:

- **Option 4.2a — seal on accept, by the accepter? ❌** Impossible: the accepter
  can't seal a key they don't have.
- **Option 4.2b — server requests an existing key-holder to seal (deferred) —
  RECOMMENDED.** On accept, the membership row is created with `key = nil`. The
  next time **any member who holds the `org_key`** loads the dashboard, an
  `EnsureOrgKey` hook detects members with `key == nil`, asks the server for
  their public keys (server-authoritative, D1), seals the `org_key` for each, and
  posts the sealed copies. This mirrors the circle "add members" Phase-2 flow and
  the audit-key "seal for new admin" flow. New members see the prompt/placeholder
  until a key-holder visits — typically the inviting admin, who is usually
  active.

> **Decision needed (Q2):** Confirm 4.2b (deferred seal-by-existing-holder).
> Alternative: seal eagerly at invite time by the inviting admin's browser
> (admin holds `org_key`, seals for the invitee's *future* identity) — but the
> invitee's keypair may not exist yet at invite time (they may be a brand-new
> registrant), so deferred-on-presence is the robust choice. Recommendation:
> **4.2b**.

### 4.3 Backfill for existing members

Existing orgs (the family orgs currently in the DB, and any business re-created
during testing) have members with `key == nil`. Backfill is **the same
mechanism as 4.2b**: the first key-holder to visit the dashboard seals for all
`key == nil` members. For the very first org where *nobody* holds the key yet
(all `nil`), the **owner's browser bootstraps** it (4.1 Option A): owner
generates the `org_key`, seals their own copy, then seals for the rest. No
server-side or migration-time key generation (we can't — ZK).

> A data migration cannot generate/seal the `org_key` (that requires a member's
> private key, which the server never has). Backfill is therefore inherently
> client-driven and lazy. This is acceptable and matches the audit-key design.

### 4.4 Summary of seal touchpoints

| When | Who seals | For whom |
|------|-----------|----------|
| Org create (lazy, first dashboard visit) | creator's browser | creator (bootstrap) |
| Invitation accepted | (deferred) next key-holder's browser | the new member |
| Existing members backfill | first key-holder's browser | all `key == nil` members |
| Member removed | — (no reseal; key already known, honest-about-past) | — |

## 5. Onboarding UX — collecting the org display name

The member sets their org persona (e.g. "Mark — Engineering") which is encrypted
with the `org_key` in the browser and stored in `Membership.display_name`. This
is the "you add your organization/family name + username as part of the org ZK
group key" the user described.

- **When:** prompted on the org dashboard when `display_name == nil` (a
  non-blocking inline banner/card: "Set how your team sees you"). Also editable
  anytime from a small "edit org name" affordance on their own roster row.
- **Where the encryption happens:** a tiny form hook (mirroring
  `connection-label-form-hook.js` / `block-reason-form-hook.js`): on submit it
  unseals the member's `org_key` from `Membership.key`, `encryptSecretboxString`
  the typed name, and pushes `save_org_display_name` with the ciphertext. Server
  writes it via an explicit context fn (D4). Never sees plaintext.
- **Validation:** length + allowed-character + expletive checks mirror
  `UserGroup.validate_name/2` (letters/marks/space/'/-, max 160). The blind-index
  is intentionally omitted (no lookup need).

> **Decision needed (Q3):** Is the org display name **required** before a member
> can use the org surface, or optional-with-prompt? Recommendation: **optional
> with a persistent prompt** (don't block productivity; show a neutral
> placeholder until set — §7.4). The user's phrasing ("you add your
> organization/family name and username") suggests collecting it at join; we can
> surface the prompt immediately on first dashboard load.

## 6. Context & server changes (`Mosslet.Orgs`)

All new writes wrapped in `Repo.transaction/1` (the `transaction_on_primary`
shim), per architecture guidelines.

1. **`Membership` schema:** add `:key` + `:display_name` (`Encrypted.Binary,
   redact: true`). Add ZK-oriented changesets (no `cast` of these fields from
   user params, D4):
   - `seal_key_changeset(membership, sealed_key)` — sets `key` (programmatic).
   - `display_name_changeset(membership, encrypted_display_name)` — sets
     `display_name` (ciphertext from the browser), with name validation applied
     to... (see Q3 note — we validate the *plaintext* client-side; server stores
     only ciphertext, so server-side length/expletive checks can't run on the
     ciphertext. Validation is therefore client-side, consistent with all other
     ZK-encrypted name fields).
2. **`Orgs` context fns (server-authoritative, D1):**
   - `members_needing_org_key(org)` → memberships with `key == nil` + their
     users' public keys (for the seal hook).
   - `seal_org_key_for_members(org, sealed_list)` → persists each
     `%{user_id, sealed_key}` to the matching membership's `key`, **only** for
     current members of `org` (drops non-members, D1). Broadcasts
     `org_updated`.
   - `set_org_display_name(membership, encrypted_display_name)` → writes
     `display_name`. Broadcasts `org_updated`.
   - `member_org_key_sealed?(membership)` / roster helpers as needed.
3. **Roster assembly (`business_live/show.ex` + family equivalent):** stop
   calling `resolve_display_name/3` for the encrypted-name fallback. Instead pass
   each member's `Membership.display_name` ciphertext + the viewer's own
   `Membership.key` (sealed `org_key`) to the template for the decrypt hook.
   (Keep "You" for self; optionally still prefer a connected member's personal
   name — see §7.3.)

## 7. Rendering — the `DecryptOrgMembers` hook

### 7.1 Hook (mirrors `DecryptGroupMetadata`)

A new `assets/js/hooks/decrypt-org-members.js`:

- Reads the **viewer's** sealed `org_key` from a data attribute
  (`data-sealed-org-key`, = the viewer's `Membership.key`).
- `unsealContextKey(sealedOrgKey)` → `unwrapKey` → raw `org_key`.
- For each roster row carrying `data-encrypted-display-name`, `decryptWithKey`
  with the `org_key` and write `textContent` into the row's
  `[data-decrypt-org-name]` target.
- Same `mounted`/`updated`/`mosslet:keys-ready` lifecycle as
  `DecryptGroupMetadata`. Registered in `assets/js/hooks/index.js`.

### 7.2 Template

Each member row renders the placeholder server-side (neutral, e.g. "Team
member") and carries the ciphertext + a `[data-decrypt-org-name]` target the hook
fills in once keys are ready. The viewer's sealed `org_key` lives on a single
wrapper element with the hook attached (`phx-hook="DecryptOrgMembers"`).

### 7.3 Layering with the existing personal name (optional, recommended)

Keep `resolve_display_name/3` as a *first-choice* enhancement: if the viewer
*does* have a `UserConnection` to a member, we can still show the personal name
(richer, the name they chose for that relationship). The org display name is the
**fallback for everyone else** (replacing today's "Team member"). "You" stays for
self. This preserves current behavior for connected members and only *adds*
recognition for unconnected ones. (Alternatively, always prefer the org persona
for consistency — Q4.)

> **Decision needed (Q4):** For a member the viewer *is* connected to, show the
> personal connection name (current behavior, richer) or the org persona (uniform
> org identity)? Recommendation: **prefer personal connection name when present,
> fall back to org display name, then neutral placeholder** — strictly additive,
> no regression.

### 7.4 Fallbacks

- `Membership.display_name == nil` (member hasn't set theirs): neutral
  placeholder ("Team member") + for *that member's own* view, the "set your org
  name" prompt.
- Viewer's `Membership.key == nil` (org_key not yet sealed for viewer): the hook
  no-ops; rows show the neutral placeholder until a key-holder seals (§4.2/4.3).
  Honest, non-blocking.

## 8. Security review checklist (applied at implementation)

- [ ] **D1** Seal recipient public keys resolved server-side from
      `Orgs.Membership`; `seal_org_key_for_members/2` drops any non-member
      `user_id`. Tested.
- [ ] **D2** No server self-seal; server never decrypts `display_name` or the
      `org_key`. grep the server path: no `decr_*`/`decrypt_*` on these fields.
- [ ] **D3** Sealing via `sealForUser` (Cat-5) only; reading via
      `unsealContextKey` + `decryptWithKey`. No bespoke KEM.
- [ ] **D4** `key`/`display_name` never in `cast`; written only via explicit ZK
      changesets from browser payloads.
- [ ] **D5** All members' `key` unseal to the same `org_key` (round-trip test:
      two unconnected members decrypt each other's `display_name`).
- [ ] No key material / plaintext name in URL, Oban args, email, or logs (grep
      `Logs.log`, worker args).
- [ ] DB/logs show only ciphertext for `key` + `display_name` (SQL spot-check).
- [ ] Existing `UserConnection` path unchanged; personal-name resolution intact.
- [ ] `mix precommit` clean (no NEW warnings beyond the ~17 known pre-existing).

## 9. Resolved questions

- **Q1 — `org_key` generation → A (lazy).** Generated + sealed by the creator's
  browser on first dashboard visit (no crypto in the org-create transaction),
  mirroring the §12 audit-key laziness.
- **Q2 — New-member seal → 4.2b (deferred).** New membership rows start
  `key == nil`; the next key-holder to load the dashboard seals the `org_key` for
  them, mirroring the circle add-member Phase-2 flow.
- **Q3 — Display name → optional + persistent prompt.** Never blocks; neutral
  placeholder until set; prompt shown on the member's own dashboard.
- **Q4 — Connected members → prefer personal connection name, then org persona,
  then neutral placeholder.** Strictly additive; no regression for connected
  members.
- **Q5 — Family + Business together, one shared ZK identity primitive.** The
  `org_key` + `Membership.key`/`display_name` are **type-agnostic** and shared by
  both org types (one schema, one context seal/set API, one read hook). Org-type
  differences live ONLY in the dashboard feature surface (family vs business),
  never in the crypto/identity layer. Strict no-cross-boundary rule: every roster
  query + seal is `org_id`-scoped (D1), so a family member's `org_key`/display
  name is never visible to a business org and vice versa. DX/maintainability: the
  identity layer is written once and reused; per-type logic is explicit in each
  LiveView, not branched inside the crypto.

## 10. Implementation plan (after sign-off)

1. **Schema & migration:** `mix ecto.gen.migration add_key_and_display_name_to_memberships`;
   add `:key` + `:display_name` to `Orgs.Membership` + ZK changesets (no `cast`).
2. **Context:** `members_needing_org_key/1`, `seal_org_key_for_members/2`,
   `set_org_display_name/2`, roster helpers. All writes via `Repo.transaction/1`;
   broadcast `org_updated`.
3. **JS:** `decrypt-org-members.js` (read) + a small `ensure-org-key` /
   `org-display-name-form-hook.js` (seal + set name). Register in `index.js`.
   Reuse `sealForUser`/`unsealContextKey`/`encryptSecretboxString`.
4. **LiveView wiring:** `business_live/show.ex` (+ family) — seal events, set-name
   event, roster template with hook + ciphertext data attrs + prompt.
5. **Tests:** mirror `family_live_test.exs`/business tests — two unconnected
   members recognize each other (round-trip), non-member can't be sealed,
   placeholder/prompt when unset, ciphertext-only in DB.
6. **Verify:** `mix precommit` + `browser_eval` (two unconnected members see each
   other's org display name; server logs/DB show only ciphertext).

---

**Sign-off status: APPROVED.** Q1–Q5 resolved (§9). Implementing per §10.
