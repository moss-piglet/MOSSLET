# 👪 Mosslet Family Guardianship — Design Doc (Phase 2)

> **Status: DRAFT — awaiting user sign-off.**
> No crypto/code is implemented from this doc until it is approved.
> This doc is the binding spec for the guardianship portions of EPIC #207, Phase 2.

## 0. TL;DR

Guardianship lets a **guardian** (e.g. a parent) read a **managed member's**
(e.g. a child's) content **without the server ever seeing plaintext and without
any master key**. It works by reusing the *exact* zero-knowledge write path we
already ship for posts and conversations: when a managed member creates content,
their per-context key (`post_key`, `conversation_key`, …) is **also sealed for
the guardian's PUBLIC key** via the existing `sealForUser` (Cat-5 hybrid
ML-KEM-1024 + X25519). The guardian decrypts later with **their own private
key**.

This is **consent-based co-readership, not surveillance**:

- The server is never a reader. It only stores opaque sealed blobs.
- There is **no master key** and **no silent decryption path** — adding one is
  explicitly forbidden by `ENCRYPTION_ARCHITECTURE.md` and this doc.
- **Consent is required.** An of-age managed member must **explicitly accept** a
  guardianship before any of their content is co-sealed. Until they accept (or if
  they decline), the guardian is never added as a recipient. (Minor/dependent
  accounts the family admin set up are the only exception, and they are still
  always shown in the transparency panel.)
- A managed member (and the guardian) can flip a **privacy toggle** to stop
  sealing *future* content for the guardian. Past content stays shared —
  cryptographically you cannot "un-ring the bell," and we will not pretend
  otherwise in the UI.
- **Mandatory transparency:** the managed member's UI **always** shows exactly
  who can read their content (including each guardian), at all times.

## 1. Goals & Non-Goals

### Goals

1. A guardian can read a managed member's content **with their own keys**, ZK PQ
   end to end.
2. Zero new cryptographic primitives — reuse `sealForUser`/`unsealFromUser` and
   the `UserPost.zk_changeset` recipient pattern verbatim.
3. Honest, always-on transparency for the managed member.
4. A privacy toggle that is **cryptographically truthful** (affects future
   content only).
5. Family-scoped, consent-based, and revocable.

### Non-Goals (explicitly out of scope / forbidden)

- ❌ **No master key.** The server never holds a key that decrypts member
  content.
- ❌ **No silent/covert reading.** Guardianship is never hidden from the member.
- ❌ **No retroactive content seizure** beyond what was already sealed for the
  guardian. Toggling privacy off does not magically grant past content (it
  wasn't sealed for the guardian) and toggling it back off does not revoke past
  content (it was sealed and downloaded).
- ❌ **No location tracking or device monitoring.** This is co-readership of the
  managed member's own Mosslet content (their posts and the DMs they take part
  in) — nothing else.
- ❌ **No silent third-party exposure.** When a managed member's DM with another
  person is co-sealed for a guardian, **all** participants see a banner. We never
  let a guardian read a third party's messages covertly.
- ❌ No changes to how *non-managed* users' content is sealed.

## 2. Terminology

| Term | Meaning |
|------|---------|
| **Family org** | An `Orgs.Org` with `type: :family`. |
| **Guardian** | A family member with `Membership.role: :guardian` (a Mosslet user with their own keypair). |
| **Managed member** | A family member with `Membership.role: :managed_member` whose content is co-sealed for their guardian(s). |
| **Regular member** | `Membership.role: :member` — an adult family member with no guardianship relationship. |
| **Admin** | `Membership.role: :admin` — billing/management. Existing role, unchanged. |
| **Guardianship** | The consent record linking a managed member to a guardian within a family org. |
| **Co-seal** | The act of additionally sealing a managed member's context key for a guardian's public key during the normal browser write path. |

## 3. Threat model & invariants

**Trust boundaries (unchanged from `ENCRYPTION_ARCHITECTURE.md`):**

- Server sees: Cloak-wrapped, then `sealForUser`-sealed blobs. **Never plaintext
  of non-public content. Never any context key in the clear.**
- Browser (member's device) sees: plaintext while the member is composing, and
  the member's own private key (decrypted from session key).
- Guardian's browser sees: plaintext of co-sealed content after unsealing with
  the guardian's own private key.

**Invariants we must preserve (CI/review checklist):**

1. **I1 — No master key.** No server-held key ever decrypts a managed member's
   content. Co-sealing happens in the *member's browser* for the *guardian's
   public key*.
2. **I2 — No silent path.** Every co-seal target is reflected in the member's
   transparency panel. If a guardian can read it, the member can see that.
3. **I3 — Consent is recorded and revocable.** A guardianship is an explicit DB
   record; revoking it stops future co-seals immediately.
4. **I4 — Honesty about the past.** The privacy toggle and revocation only stop
   *future* co-seals. The UI states this plainly.
5. **I5 — Same crypto everywhere.** Co-sealing uses `sealForUser` with the
   guardian's `key_pair["public"]` + `pq_public_key`, identical to any other
   recipient. No special "guardian KEM."

## 4. How it maps onto the EXISTING ZK write path

The app already gathers recipient public keys **server-side** and pushes them to
the browser, which seals the context key per recipient and pushes back sealed
keys. We extend that single, well-tested path. **No new crypto code.**

### 4.1 Posts (the canonical path)

Today (verbatim, `lib/mosslet_web/live/timeline_live/index.ex`):

1. `save_post_encrypted` builds `recipient_keys` from `shared_users`
   (`%{user_id, public_key, pq_public_key}`) and `push_event("encrypt_post_fields", %{… recipient_keys: …})`.
2. Browser (`post-form-hook.js`) seals `post_key` for the author and **each
   recipient** via `sealForUser(keyBytes, recipient.public_key, recipient.pq_public_key)`,
   then `pushEvent("finalize_post_encrypted", %{sealed_recipient_keys: [...]})`.
3. `Timeline.create_shared_user_posts/4` persists each
   `UserPost.zk_changeset(%{key: sealed_key, post_id, user_id})`.

**Guardianship change:** in `add_shared_users_list_for_new_post/3` (the existing
server-side `shared_users` resolver), when the **author is a managed member**
with active, non-paused guardianship(s), **append each active guardian** to
`shared_users` as `%{user_id: guardian_user_id}`. From there everything is
unchanged — the guardian becomes a normal recipient, gets a `UserPost` row with
a `post_key` sealed *by the member's browser* for the *guardian's public key*.

> ⚠️ This append must be **server-authoritative** (driven by the guardianship
> records), not client-supplied, so a tampered client cannot remove a guardian
> nor inject one. The member's browser still does the sealing (ZK), but it
> cannot *choose* the guardian set.

The repost/share path (`Mosslet.Helpers.build_repost_encrypt_request/3`) gets the
same server-side guardian append, for symmetry.

### 4.2 Conversations (Q1/Q2 resolved), groups, journals

- **Conversations (Q2 = all DMs, both directions):** once a managed member has an
  **active** guardianship, **every** conversation they participate in — whether
  they *start* it or *join* one started by someone else — co-seals the
  `conversation_key` for the active guardian(s). This is what lets a guardian
  actually protect a managed member, since the risky DMs are usually the ones
  *initiated by someone else*. The managed member controls this entirely through
  the consent decision (§6.3) and the privacy toggle.

  Mechanism: when a conversation involving a managed member is created (the
  `start-conversation.js` per-recipient seal loop), the server-authoritative
  recipient list includes the managed member's active guardian(s), so the
  `conversation_key` is sealed for the guardian exactly like any other
  participant. For conversations created *before* consent, only **future
  messages'** access follows the same "future only" honesty rule (the guardian
  is added going forward; we do not retro-seal historical keys silently — see
  §4.2.1).

  > **Third-party transparency (I2 — mandatory).** The *other* participant in a
  > DM is not the managed member; their messages become readable by the guardian.
  > We must **never** do this silently. Every conversation that co-seals for a
  > guardian shows a clear, persistent banner to **all** participants:
  > *"[Managed member]'s guardian can read this conversation."* This preserves
  > the no-silent-path invariant on all sides while still giving the guardian
  > full protective visibility.

- **Family circles (Q1 — SHIPPED, Task #271):** the dedicated **family shared
  circle** (`FamilyLive.CircleShow`) co-seals for guardians behind the identical
  pattern. When a managed member is added to a family circle, the active
  guardians of that member (derived server-side from `Guardianship` records — I1)
  are folded into the circle group-key seal payload (`OrgCircleSupport`), so the
  circle's `group_key` is co-sealed for each guardian's public key — they become
  transparent co-reading members (shown in the roster + a mandatory "a guardian
  can read this family circle" notice, I2). No master key, no silent path. The
  transparency panel lists family circles among the covered surfaces.
- **Personal Circles & Journals (still deferred):** personal-circle authorship
  and personal journals remain out of scope and can be added later behind the
  same pattern. The transparency panel always states exactly which surfaces are
  currently covered, so members are never misled about scope.

#### 4.2.1 Conversation co-seal timing

- New conversation (managed member + others), guardianship active → guardian is a
  recipient from creation. Banner shown.
- Existing conversation, guardianship becomes active later → guardian is added as
  a participant going forward (future messages). We do **not** silently re-seal
  the historical `conversation_key` behind participants' backs; instead, adding
  the guardian to an existing conversation is itself surfaced (the banner appears
  and participants see the guardian join). Honest "future only" semantics (I4).

### 4.3 Reading (guardian side) — already works for free

A guardian reading co-sealed content uses the **existing** read path
(`DecryptPost` / `getCachedPostKey` → `unsealContextKey` → `unsealFromUser` with
the guardian's own keys). Because the guardian has a real `UserPost` row, the
content simply appears in their normal feeds/relationships. We will surface it in
a dedicated **"Family" view** rather than mixed silently into their main timeline
(see §6.4), to keep the relationship explicit and honest on both sides.

## 5. Data model

All new schema fields follow `ENCRYPTION_ARCHITECTURE.md`: enums/booleans/role
flags are plaintext system data; any human-entered text is encrypted. Migrations
created with `mix ecto.gen.migration` for correct timestamps.

### 5.1 `Orgs.Membership` — add roles

Extend the existing role enum (today `~w(admin member)a`):

```elixir
@role_options ~w(admin member guardian managed_member)a
```

- `:admin` and `:member` unchanged.
- `:guardian` — can be a guardian for managed members in the same org.
- `:managed_member` — content is co-sealed for assigned guardian(s).

A user can hold exactly one membership row per org (existing
`unique_constraint([:org_id, :user_id])`). Role transitions validated in the
context (e.g. you cannot demote the last admin — existing rule preserved).

### 5.2 New schema: `Orgs.Guardianship` (the consent record)

New table `orgs_guardianships` (binary_id, follows `Mosslet.Schema`):

| Field | Type | Notes |
|-------|------|-------|
| `org_id` | `belongs_to Org` | scope: must be `type: :family`. |
| `guardian_membership_id` | `belongs_to Membership` | role must be `:guardian`. |
| `managed_membership_id` | `belongs_to Membership` | role must be `:managed_member`. |
| `status` | `Ecto.Enum [:pending, :active, :paused, :declined]` default depends on flow | plaintext system flag. `:pending` = awaiting managed-member consent (no co-sealing yet). `:active` = consented, co-sealing on. `:paused` = privacy toggle ON (stop future co-seals). `:declined` = managed member refused. |
| `requires_consent` | `:boolean` default `true` | `false` only when the managed member cannot self-consent (a minor account the family admin set up); see §7. |
| `established_at` | `:utc_datetime` | nullable; set when the link is created. |
| `consented_at` | `:utc_datetime` | nullable; set when the managed member accepts. |
| `paused_at` | `:utc_datetime` | nullable; set when paused. |
| `timestamps()` | | |

**Consent gate (I3):** co-sealing only happens when `status == :active`. A
`:pending` or `:declined` guardianship is **never** co-sealed — the server never
appends that guardian to `recipient_keys`. This makes "consent-based"
cryptographically true, not just a label.

Constraints:

- `unique_constraint([:guardian_membership_id, :managed_membership_id])`.
- Both memberships must belong to the **same** `org_id` (validated in context).
- Guardian and managed member must be **distinct users**.

> We store the *consent relationship*, never any key material. The actual
> co-sealing is ephemeral and happens per-content in the browser. Pausing a
> guardianship simply means the server stops appending that guardian to
> `recipient_keys`.

### 5.3 No new fields on `User`

Guardianship is **org-scoped**, not a global user property — a user could be a
managed member in one family org and a regular adult elsewhere (rare, but the
model shouldn't forbid it). All guardianship state lives on `Membership` +
`Guardianship`.

## 6. UX / transparency (mandatory)

### 6.1 Family org dashboard (`type: :family`)

- Members list with role badges (Admin / Guardian / Managed member / Member).
- For each managed member: which guardian(s) currently co-read, and the
  guardianship `status`.
- Admin actions: invite member, assign/revoke guardian↔managed links, change
  roles (with confirmation modals explaining the crypto consequences).

### 6.2 Transparency panel (managed member's own view) — ALWAYS visible

On the managed member's dashboard/profile and **inline on the post composer**, a
persistent, non-dismissible panel:

> **Who can read what you share here**
> Your guardians can read posts and conversations you create in Mosslet, using
> their own private key. Mosslet's servers can't read them.
> - 👤 **[Guardian name]** — can read your future posts & conversations.
> - 🔒 Privacy is **on/off** for new content. [Toggle]
> *Turning privacy on stops sharing **new** content with your guardian. Things
> you already shared stay shared — that can't be undone.*

The composer shows a small, honest inline chip when a guardian will be a
recipient of the post being written (same spirit as the existing recipient
chips), so there is **no surprise** at the moment of authorship (I2).

### 6.3 Consent + privacy toggle

**Consent first (required — we advertise "consent-based"):**

- When an admin creates a guardian↔managed link for an **of-age managed member**
  who controls their own account, the guardianship starts as `:pending`. The
  managed member sees a clear **consent request** ("[Guardian] would like to be
  able to read posts and conversations you create here. They'll use their own
  key — Mosslet still can't read them. You can pause or stop this any time.")
  with **Accept** / **Decline**. Co-sealing begins **only** after they accept
  (`status: :active`, `consented_at` set). Declining sets `:declined` and
  nothing is ever co-sealed.
- For a **minor account** the family admin set up (the member can't self-
  consent), `requires_consent: false` and the link may start `:active`. This is
  honest guardianship of a dependent account — and the managed member's
  transparency panel still always shows it (I2), so it is never hidden.

**Privacy toggle (member AND guardian can pause):**

- **Member toggle:** flips an `:active` guardianship to `:paused` → `paused_at`
  set → server stops appending the guardian to `recipient_keys`.
- **Guardian toggle:** a guardian may also pause (e.g. "I don't need to see this
  anymore"), same effect.
- Re-enabling sets `status: :active` again; only content created while active is
  ever co-sealed.
- UI copy is explicit about the "future only" semantics (I4). We never imply
  past content is revoked or retrievable.

### 6.4 Guardian's reading surface

A dedicated **"Family"** section/feed where co-sealed content from managed
members appears, clearly labeled (e.g. "Shared with you as [name]'s guardian").
Not silently merged into the main timeline — the relationship is explicit on
both ends.

## 7. Roles, permissions, lifecycle

- **Who can establish guardianship?** A family-org **admin** assigns a
  guardian↔managed link. Establishing the link requires the managed member to be
  an existing member of the org (invited + accepted). For minors who can't self-
  manage an account, the family admin (typically the parent) sets up the managed
  member's account during invite/onboarding — but the **member's own keypair**
  is still what's used; the guardian is a *separate recipient*, never the holder
  of the member's key.
- **Consent is required for of-age managed members (Q3 = required).** Such a link
  starts `:pending` and **only** begins co-sealing after the managed member
  explicitly **accepts** (see §6.3). Declining = `:declined`, never co-sealed.
  Minor/dependent accounts (`requires_consent: false`) may start `:active`, but
  transparency is always on regardless.
- **Consent surfacing:** in every case the managed member's transparency panel
  makes the guardianship impossible to hide (I2).
- **Revocation:** removing the guardianship (or removing either membership)
  stops future co-seals. We do **not** delete already-created `UserPost` rows
  for the guardian (I4 honesty; deleting them would be a misleading "we undid
  it" gesture and is also racy). Admin UI states this.

## 8. Security review checklist (to be applied at implementation)

- [ ] **I1** Guardian append is server-authoritative and only ever adds public
      keys to `recipient_keys`; no server-side unseal of member content is
      added anywhere.
- [ ] **I2** Every co-seal target appears in the transparency panel + composer
      chip. Tested.
- [ ] **I2b** Every DM co-sealed for a guardian shows a persistent banner to
      **all** participants (third party is never read silently). Tested.
- [ ] **I3** Co-sealing happens **only** for `:active` guardianships. `:pending`,
      `:declined`, and `:paused` are never co-sealed. Pausing/revoking is
      reflected within the same request cycle for subsequent posts.
- [ ] **I4** All toggle/revoke copy states "future content only; past stays
      shared."
- [ ] **I5** Co-seal uses `sealForUser` with the guardian's
      `key_pair["public"]` + `pq_public_key`; no bespoke KEM path.
- [ ] Of-age managed members must **accept** before any co-sealing (consent gate).
- [ ] Guardian set cannot be altered by a tampered client (server derives it
      from `Guardianship` records, not from client params).
- [ ] All new DB writes wrapped in `Repo.transaction/1` (the
      `transaction_on_primary` shim) per architecture guidelines.
- [ ] `mix precommit` clean (no NEW warnings beyond the 17 known pre-existing).

## 9. Open questions for sign-off

- **Q1 — Surfaces in Phase 2 — RESOLVED + EXTENDED:** Phase 2 co-seals **posts +
  DM conversations** involving the managed member. **Family circles now also
  co-seal** (Task #271) behind the identical pattern — see §4.2. Personal Circles
  and journals remain deferred to a later phase.
- **Q2 — DMs the member joins vs. starts — RESOLVED (all DMs, both directions):**
  once consent is active, **every** DM the managed member participates in
  co-seals for the guardian (started by the member *or* by someone else), so the
  guardian can protect the managed member. **Mandatory:** every such conversation
  shows a persistent banner to **all** participants ("[Managed member]'s guardian
  can read this conversation") — the third party is never read in secret (I2).
- **Q3 — Consent — RESOLVED (consent required):** Of-age managed members **must
  explicitly accept** a guardianship before any co-sealing. The guardianship
  starts `:pending` and only becomes `:active` on accept; declining = `:declined`
  (never co-sealed). Minor/dependent accounts (`requires_consent: false`) may
  start `:active` but are always shown in the transparency panel. This makes
  "consent-based guardianship" (as advertised on the pricing page)
  cryptographically true.
- **Q4 — Max managed members / guardians per member — RESOLVED (defaults
  accepted):** No hard cap beyond seats; a managed member may have multiple
  guardians, each a distinct recipient.
- **Q5 — Naming — RESOLVED (defaults accepted):** **Guardian / Managed member**.

## 10. Implementation plan (only after sign-off)

1. **Schema & context (no UI):**
   - Migration: add `:guardian`, `:managed_member` to `orgs_memberships.role`
     check/enum usage; create `orgs_guardianships` table
     (`mix ecto.gen.migration`).
   - `Orgs.Guardianship` schema + changesets (consent record only).
   - `Orgs` context: `establish_guardianship/…` (starts `:pending` for of-age,
     `:active` for `requires_consent: false`), `accept_guardianship/…`,
     `decline_guardianship/…`, `pause_guardianship/…`, `resume_guardianship/…`,
     `revoke_guardianship/…`, `list_active_guardians_for/1` (returns guardian
     users w/ public keys — `:active` only), `list_guardianships_by_org/1`. All
     writes via `Repo.transaction/1`.
2. **Write-path injection (the only crypto-adjacent change, all public-key):**
   - **Posts:** in `add_shared_users_list_for_new_post/3` and
     `build_repost_encrypt_request/3`, append the managed-member author's active
     guardian users to `shared_users`/`recipient_keys`. Server-authoritative;
     browser still seals.
   - **Conversations (both directions):** when a conversation involving a managed
     member (with an active guardianship) is created, append that member's active
     guardian(s) to the server-authoritative recipient list the
     `start-conversation.js` seal loop consumes — regardless of who started the
     conversation. Surface the third-party banner (I2b) to all participants.
3. **Family UI:**
   - Family org dashboard, member management, role assignment.
   - Consent request flow (accept/decline) for of-age managed members.
   - Managed-member transparency panel (always visible) + composer chip.
   - Conversation "guardian can read this" banner for all participants.
   - Privacy toggle (member + guardian), with honest copy.
   - Guardian "Family" reading surface.
4. **Checkout wiring:** seat selector + Family checkout end-to-end (already
   plumbed by Phase 1; verify in browser).
5. **Verify:** `mix precommit`, browser walkthrough, security checklist §8.

---

**Sign-off status: APPROVED (Q1–Q5 resolved).** Q3 = consent required; Q4/Q5 =
defaults; Q1 = posts + conversations (groups/journals deferred); Q2 = all DMs
both directions + mandatory third-party banner. Implementing in the order in §10.

## 11. Safety & anti-abuse (Task #273)

Guardianship can be misused (a guardian surveilling, coercing, or harvesting a
managed member — especially a minor). MOSSLET's crypto already forbids covert
reading (I1/I2), but a managed member still needs an **independent, always-
reachable way to get help** that a guardian cannot intercept or co-read.

We deliberately **do not** build an in-app abuse-report/escalation channel into
MOSSLET. Under our ZK model we cannot meaningfully investigate or adjudicate
abuse, and acting as the intermediary would be a liability and a false promise.
Instead we **route people to established, independent help organizations and
government agencies** that are trained and available 24/7.

**Implementation:**

- **Public `/safety` page** (`MossletWeb.PublicLive.Safety`). Being public, it is
  reachable without signing in and is **structurally impossible for a guardian to
  co-read** — guardianship co-read only ever covers a managed member's own ZK
  content (posts/DMs), never a static public page. It is area-aware: a US ZIP
  resolves to a state label (cosmetic) and surfaces national, auto-routing
  hotlines (988, Childhelp, National DV Hotline, Crisis Text Line, NCMEC,
  StopBullying.gov); any other country routes to maintained global directories
  (Find A Helpline, Child Helpline International) + local emergency services.
- **Data** lives in `Mosslet.Safety` (curated, with a documented bias against
  shipping per-country hotline numbers we can't keep accurate). The ZIP is
  resolved in-memory only and is **never stored or sent to a third party**.
- **Discoverability:** an in-app **Support** sidebar entry for *all* plans
  (personal/family/business) → `/support` → which links to `/safety`; a discreet
  **"Feeling unsafe? Get confidential help"** link in the managed member's
  always-visible transparency panel → `/safety`; and footer links.
- **Terms of Service** (`/terms`, §2 User Conduct) explicitly state that using
  guardianship to surveil/coerce/control/harvest a family member (incl. a minor)
  violates the Terms, and point to `/safety`.

This keeps the honest invariants intact (no silent path, member-visible
controls) while giving managed members a real, guardian-independent path to help.
