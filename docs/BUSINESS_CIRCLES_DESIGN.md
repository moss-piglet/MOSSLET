# 🏢 Mosslet Business Circles — Design Doc (Phase 3c)

> **Status: APPROVED (Q1–Q6 resolved — see §10).**
> This doc is the binding spec for the business-circles portion of EPIC #207,
> Phase 3 (board task #212). Companion doc: `ZK_FILE_SHARING_DESIGN.md` (Phase 3d).

## Guiding philosophy — ZK for businesses

> **For businesses, zero-knowledge means privacy *from us (Mosslet) and from
> outsiders* — while giving the org's own admins full, cryptographically-scoped
> visibility into their own team.** ZK is a shield *around* the business, not a
> wall *inside* it. The org controls its own internal transparency (member
> management, audit logs, file readership); Mosslet and any attacker are simply
> locked out. We never police a business's content (that is a matter for the
> business and, where applicable, governments — not their software vendor). We
> *do* protect businesses from outside threats and malicious/AI-driven attacks
> via client-side defenses and a server that holds only unreadable ciphertext —
> so a breach of Mosslet yields math, not data.

This principle is why an "admin audit log" and "zero-knowledge" are not in
tension here: the audit log's *reader* is the **org admin** (a recipient with
their own keypair), never the server (see §12).

## 0. TL;DR

A **business circle** is an ordinary Mosslet **Group** (a.k.a. "Circle") that is
**scoped to a `:business` org** and **restricted to that org's members**. It
reuses the existing zero-knowledge Group write path **verbatim** — a per-group
`group_key` generated and sealed in the browser via `sealForUser` (Cat-5 hybrid
ML-KEM-1024 + X25519) for each member's public key, with the raw key never
reaching the server.

The *only* additions are:

1. A nullable `org_id` foreign key on `groups` (and a sibling `org` association),
   making a group "business-scoped" when set.
2. **Server-authoritative membership eligibility**: a business circle's members
   may only be drawn from the org's `Orgs.Membership` records. The server
   resolves the eligible recipient set; the browser still does all sealing.
3. A `BusinessLive` dashboard (mirroring `FamilyLive`) at `/app/business` for
   member management, roles, and circle overview.

**Business orgs do NOT use guardianship.** There is no co-sealing to a third
party, no consent records, no transparency-panel-for-surveillance. A business
circle is just a private, org-restricted Mosslet circle. Membership is the only
access-control mechanism, exactly as it is for normal circles.

## 1. Goals & Non-Goals

### Goals

1. Let a `:business` org create **private circles** whose membership is
   restricted to people who are members of that org.
2. **Zero new cryptographic primitives.** Reuse `create_group_zk` /
   `add_group_members_zk` / `UserGroup` recipient sealing exactly as shipped.
3. A `BusinessLive` dashboard for org member management + circle overview,
   mirroring the `FamilyLive` structure and the liquid-metal design system.
4. Server-authoritative eligibility: a tampered client cannot add a non-member
   to a business circle, nor escalate roles beyond what the server allows.
5. Honest, simple access transparency — members can always see who is in a
   circle (this is inherent to the existing UserGroup model; no new mechanism
   needed).

### Non-Goals (explicitly out of scope / forbidden)

- ❌ **No guardianship.** Business orgs never co-seal a member's content for any
  third party. (`Orgs.list_active_guardian_users_for_user/1` is family-only and
  is not consulted on the business path.)
- ❌ **No master key / no server-readable circle content.** The server stores
  only sealed `group_key` copies and ciphertext, identical to existing circles.
- ❌ **No org-wide "read everything" admin power.** An org admin manages
  *membership and billing*, not *content access*. An admin who is not a member
  of a given circle cannot read that circle's content — they would have to be
  added as a normal member (which seals the key for them and is visible to all
  members), exactly like any circle.
- ❌ **No cross-org leakage.** A business circle's `org_id` pins it to one org;
  eligibility queries are always org-scoped.
- ❌ No changes to how personal (non-org) circles work today.

## 2. Terminology

| Term | Meaning |
|------|---------|
| **Business org** | An `Orgs.Org` with `type: :business`. |
| **Org member** | A user with an `Orgs.Membership` row in that org (`role: :admin` or `:member`). |
| **Business circle** | A `Groups.Group` with a non-nil `org_id` pointing at a `:business` org. |
| **Circle member** | A user with a `Groups.UserGroup` row for that group (the existing model). |
| **Circle role** | The existing `UserGroup.role` (`:owner`, `:admin`, `:moderator`, `:member`). Distinct from org role. |

> **Two role systems, kept separate and unchanged:** `Orgs.Membership.role`
> governs *org* membership/billing; `UserGroup.role` governs *circle* moderation.
> A business circle simply requires that every circle member is also an org
> member. We do not merge or auto-sync the two role enums.

## 3. Threat model & invariants

**Trust boundaries (unchanged from `ENCRYPTION_ARCHITECTURE.md`):**

- Server sees: Cloak-wrapped, then `sealForUser`-sealed `group_key` blobs and
  ciphertext circle content. **Never plaintext circle content. Never the
  `group_key` in the clear.**
- Browser (member's device) seals the `group_key` per eligible recipient and
  decrypts circle content with the member's own private key.

**Invariants (CI/review checklist):**

1. **I1 — Membership-gated recipients are server-authoritative.** The set of
   users a business `group_key` may be sealed for is derived **server-side**
   from `Orgs.Membership` of the circle's `org_id`. The browser seals only for
   the public keys the server hands it (`sealForUser` recipient list), never a
   client-chosen set. A tampered client cannot add a non-org-member.
2. **I2 — No third-party co-seal.** The business path never appends a guardian
   or any non-member recipient. (`append_guardian_recipient_keys/2` is **not**
   called for business circles.)
3. **I3 — No master/server read key.** The server never seals a circle key for
   itself and never unseals circle content. Identical to existing private
   circles.
4. **I4 — Org scoping is enforced on every query.** Listing/joining/adding to a
   business circle always filters by `org_id` and verifies org membership.
5. **I5 — Same crypto everywhere.** Sealing uses `sealForUser` with each
   recipient's `key_pair["public"]` + `pq_public_key`. No bespoke KEM.

## 4. How it maps onto the EXISTING ZK Group write path

The existing ZK circle flow (already shipped — `groups.ex:387 create_group_zk`,
`groups.ex:481 add_group_members_zk`, `group-metadata-form-hook.js`) is:

1. **Browser, phase 1** (`_encryptAndCreate`): `generateKey()` → `group_key`;
   encrypt name/description with `group_key`; seal the owner's copy
   `sealForUser(keyBytes, authorPk, authorPqPk)`; `pushEvent("create_group_zk", …)`.
2. **Server** inserts the `Group` + owner `UserGroup`, then returns each
   eligible member's `%{user_id, public_key, pq_public_key}` to the browser.
3. **Browser, phase 2** (`_sealKeyForMembersAndFinalize`): seals `group_key` for
   each member via `sealForUser(keyBytes, member.public_key, member.pq_public_key)`;
   `pushEvent("finalize_group_zk", %{sealed_members: […]})`.
4. **Server** persists each `UserGroup.member_changeset_zk` (sealed key + ZK
   name/moniker/avatar). **Raw `group_key` never reaches the server.**

### 4.1 The business change (minimal)

The *only* server-side change is **where the candidate member list comes from**
and **stamping `org_id`**:

- **Personal circle (today):** candidate members come from the creator's
  connections (`Accounts` user-connections).
- **Business circle (new):** candidate members come from
  `Orgs.list_members_by_org(org)` — **server-authoritative** (I1). The
  `create_group_zk` server step:
  1. verifies the creator is a member (preferably `:admin`) of the
     `:business` org,
  2. stamps the new `Group` with `org_id`,
  3. resolves the member candidate public keys **only** from that org's
     memberships,
  4. then proceeds through the *identical* phase-2 sealing loop.

`add_group_members_zk` gets the same guard: every `member["user_id"]` in
`sealed_members` must correspond to a current member of the circle's `org_id`,
or the server drops it (it already skips unknown/duplicate ids — we add the
org-membership check alongside that).

> ⚠️ **Server-authoritative recipient resolution (I1).** The browser seals for
> whatever public keys the server returns in phase 2. By resolving those public
> keys **only** from `Orgs.Membership` of the circle's org, a tampered client
> cannot inject a non-member: even if it forged a `sealed_members` entry, the
> server would reject the unknown/ineligible `user_id` before insert. (This is
> the same defense the guardianship design used: browser seals, server chooses
> the set.)

### 4.2 Reading — already works for free

A business-circle member reads content via the **existing** Group read path
(`getCachedGroupKey` → unseal with their own keys → decrypt name/description/
messages/posts). No new read code. The circle simply appears in their normal
Circles list; the dashboard additionally groups business circles under the org.

## 5. Data model

Follows `ENCRYPTION_ARCHITECTURE.md`: enums/booleans/FKs are plaintext system
data; human text stays encrypted. Migration via `mix ecto.gen.migration`.

### 5.1 `Groups.Group` — add `org_id` (the only schema change)

Add a **nullable** `belongs_to :org`:

```elixir
# in schema "groups"
belongs_to :org, Mosslet.Orgs.Org   # nil => personal circle; set => business circle
```

- `org_id == nil` → a personal circle, behaves exactly as today (no behavior
  change for the 100% of existing rows).
- `org_id != nil` → a business circle, restricted to that org's members.
- Set **explicitly in the context** at create time (never via `cast` — it's a
  programmatic, security-relevant field, per Ecto guidelines). It is **not**
  user-editable afterward (no `cast(:org_id)` in any changeset).

Migration: `add :org_id, references(:orgs, type: :binary_id, on_delete: :nilify_all), null: true` + index. (On org deletion we nilify rather than cascade-delete circles, so member content is never silently destroyed — admins delete circles explicitly. Open question Q3.)

### 5.2 No new join tables, no new roles

- **Membership eligibility** uses the existing `Orgs.Membership` rows. No new
  table.
- **Circle membership/access** uses the existing `Groups.UserGroup` rows
  (sealed `group_key` + circle role). No new table.
- **Circle roles** reuse the existing `UserGroup` `@roles [:admin, :member,
  :moderator, :owner]`. No new enum.

### 5.3 No new fields on `User` or `Org`

`Org.type == :business` (already in the enum) is the only org-level flag needed.

## 6. Context & query changes (`Mosslet.Groups`, `Mosslet.Orgs`)

All new/changed writes wrapped in `Repo.transaction/1` (the
`transaction_on_primary` shim), per architecture guidelines.

1. **`Groups.create_group_zk/5` (extend arity or add business variant):**
   accept an optional `org` (or `org_id`). When present:
   - assert creator is an `:admin` (or at least `:member` — Q1) of that
     `:business` org,
   - put `org_id` on the `Group` changeset (context, not `cast`),
   - resolve the candidate member public keys from
     `Orgs.list_members_by_org(org)` (server-authoritative).
   - Prefer a thin wrapper (`create_business_circle_zk/…`) over overloading the
     personal path, to keep the personal path untouched.

2. **`Groups.add_group_members_zk/2`:** when `group.org_id` is set, filter
   `sealed_members` to user_ids that are current members of `group.org_id`
   (server-authoritative eligibility) in addition to the existing
   unknown/duplicate filtering.

3. **`Groups.list_business_circles/2`** (new): list circles where
   `org_id == org.id` that the user is a member of (joins `user_groups`),
   org-scoped (I4).

4. **`Orgs` helpers** (mostly exist): `list_members_by_org/1`,
   `get_membership!/2`. Add `member_of_org?/2` (user_id, org) returning boolean
   for the eligibility guard, if not already trivially derivable.

No changes to the personal-circle code paths.

## 7. UX — `BusinessLive` dashboard

Mirrors `FamilyLive` (`lib/mosslet_web/live/family_live/{index,show}.ex`) and the
liquid-metal teal→emerald design system. Routes inside the existing
`:require_authenticated_user` live_session, mirroring the family block:

```elixir
live "/business", BusinessLive.Index, :index
live "/business/new", BusinessLive.Index, :new
live "/business/:slug", BusinessLive.Show, :show
```

(Circle creation/management can live on the Show page or reuse the existing
circle composer scoped to the org — Q2.)

### 7.1 `BusinessLive.Index`

- Lists the user's `:business` orgs (`Orgs.list_orgs(user) |> filter type ==
  :business`), each with member count and the user's org role badge.
- Inviting empty state + "Create a business" form (creates an `Org` with
  `type: "business"`), mirroring `FamilyLive.Index`.
- Liquid-metal hero header, card hover/shimmer, emerald focus states — reuse the
  Family redesign components for visual consistency.

### 7.2 `BusinessLive.Show` (`/app/business/:slug`)

- Guards `org.type == :business` (redirect otherwise), loads `org` + `membership`
  via `Orgs.get_org!/2` + `Orgs.get_membership!/2`.
- **Members panel:** org members with role badges (Admin / Member); admin actions
  to invite members, change org role (reuse `Orgs.update_membership/2`), remove
  members (reuse `delete_membership`). Reuses the existing org invitation flow.
- **Business circles panel:** lists this org's business circles
  (`Groups.list_business_circles/2`) the user belongs to, with member preview
  rows. "New circle" entry point (org-scoped circle composer). Each circle links
  into the existing circle Show page (which already renders ZK content).
- **No guardianship UI.** (That panel is family-only.)

### 7.3 Sidebar nav

Add a `:business` nav item in `lib/mosslet_web/menus.ex` (mirroring the `:family`
link at `menus.ex:498`), e.g. `%{name: :business, label: gettext("Business"),
path: ~p"/app/business", icon: "hero-building-office"}`, inserted into
`main_menu_items/1`. Active-state handling is automatic via `current_page`.

> **Visibility (Q4):** Should the Business nav item always show, or only when the
> user has at least one `:business` org membership? Proposed default: show only
> when the user belongs to ≥1 business org (keeps the sidebar clean for the
> majority who never use it), same as we can do for Family.

## 8. Permissions & lifecycle (RESOLVED)

- **Who can create a business circle? (Q1 = any org member.)** Any **org member**
  can create a circle within their business org; the creator becomes the circle
  `:owner` (existing UserGroup model). Org admins additionally manage org
  membership & billing. Rationale: teams self-organize; admin-gated channel
  creation is the #1 adoption-killer.
- **Adding circle members:** only users who are **current org members** may be
  sealed in (I1). Removing a user from the org does **not** retroactively strip
  their `group_key` from circles they already belong to (you can't un-ring the
  bell — same honesty principle as guardianship). **(Q5 = explicit one-click
  revoke.)** The dashboard offers a one-click "remove from all circles in this
  org" action when offboarding a member — but with honest copy ("can't recall
  copies already downloaded"); never a silent retroactive crypto claim.
- **Deleting a circle / org: (Q3 = nilify, preserve content.)** Deleting a
  business circle deletes its `Group` + `UserGroup` rows (existing behavior).
  Deleting an org **nilifies** `org_id` on its circles (they become
  orphaned personal-style circles owned by their owner) rather than destroying
  member content. Rationale: a business buyer's worst fear is "we cancelled and
  lost everything" — we never silently destroy content.

## 9. Security review checklist (applied at implementation)

- [ ] **I1** Business-circle recipient public keys are resolved **server-side**
      from `Orgs.Membership` of the circle's `org_id`; browser seals only for
      the server-provided set. Tampered client cannot inject a non-member.
      Tested.
- [ ] **I2** The business path never calls `append_guardian_recipient_keys/2`
      and never appends any non-member recipient.
- [ ] **I3** No server self-seal and no server-side unseal of business-circle
      content anywhere.
- [ ] **I4** Every list/join/add query for business circles is filtered by
      `org_id` and verifies org membership. Tested.
- [ ] **I5** Sealing uses `sealForUser` with each recipient's
      `key_pair["public"]` + `pq_public_key`; no bespoke KEM path.
- [ ] **I6 (audit)** ZK audit-log events are sealed for org **admins** only
      (their public keys), never the server. Server stores opaque blobs + sealed
      keys. No server-side decryption of audit content. Tested.
- [ ] `org_id` is set in the context, never via `cast` (programmatic field).
- [ ] All new DB writes wrapped in `Repo.transaction/1` shim.
- [ ] Personal-circle (org_id nil) behavior unchanged; existing rows unaffected.
- [ ] `mix precommit` clean (no NEW warnings beyond the ~17 known pre-existing).

## 10. Resolved questions

- **Q1 — Circle creation rights → ANY ORG MEMBER** (creator becomes circle
  owner); org admins manage org membership/billing.
- **Q2 — Circle composer → REUSE** the existing circle create/edit composer; the
  server stamps `org_id` (resolved server-side, never client-supplied).
- **Q3 — Org deletion → NILIFY** `org_id` on circles (preserve content; never
  silent destruction).
- **Q4 — Sidebar visibility → ONLY WHEN** the user belongs to ≥1 business org.
- **Q5 — Removing an org member → EXPLICIT** one-click "remove from all circles
  in this org" action, with honest "can't recall downloads" copy; never silent.
- **Q6 — Naming → "Business circles"** (matches plan + nav + config copy).

## 11. P0 scope additions for Phase 3 (approved)

These ship in Phase 3 because they are cheap given existing ZK infrastructure and
directly drive business adoption/retention. Each reuses crypto we already ship.

### 11.1 Onboarding wizard (P0)

A guided first-run flow on `BusinessLive` for a new business org:
**create org → name it → invite teammates → create first business circle →
(optionally) share first file**. Reuses the existing org create + invitation +
ZK circle-create flows; this is primarily UX wiring on top of `FamilyLive`
patterns. Goal: a team is productive within the first 10 minutes.

### 11.2 ZK admin audit log (P0 — DEFERRED to its own focused slice; see §12 for the crypto)

A read-only, **org-admin-only**, zero-knowledge activity log of business actions
(member added/removed, role changed, circle created, file shared/revoked).
Metadata + a human-readable description, sealed for admins' keys only. Gives
businesses real accountability **without** Mosslet (or attackers) being able to
read it. This is the concrete realization of the guiding philosophy.

> **Sequencing note (approved):** The ZK audit log is the most novel crypto
> surface in Phase 3c (new per-org audit context key, per-admin sealing, the
> non-admin-actor detail nuance in §12.2). Per the Option-1 decision, the core
> business surface (dashboard, circles, chat, onboarding, offboarding) ships
> first, **verified green**, and the audit log is implemented as its own focused
> follow-up slice (likely alongside or just after Phase 3d). The §12 design is
> the binding spec when that slice begins; nothing here changes.

### 11.3 Basic circle chat (P0) — surface existing ZK group chat

A "private business circle" that cannot communicate feels incomplete. Phase 3
**surfaces the already-shipped ZK group chat** (`GroupMessage`, browser-side
encrypted with the `group_key`, with ZK `@mention` rendering — tasks #67/#69/#70/
#121) **inside the business-circle UI**. This is mostly UI exposure of existing
ZK messaging — **no new crypto**. Threaded replies, read receipts, and
announcements are noted as P1 (next phase), not Phase 3.

## 12. ZK admin audit log — cryptographic design (P0)

The audit log applies the **exact** `context_key` + `sealForUser` recipient
pattern, with the org's **admins** as the recipient cohort (never the server).

### 12.1 Data model

- **`Orgs.OrgAuditKey`** (one per org, lazily created): the per-org audit context
  exists only as sealed copies — there is no plaintext key stored server-side.
- **`Orgs.UserOrgAuditKey`** (table `user_org_audit_keys`): mirrors
  `UserPost`/`UserGroup`.

  | Field | Type | Notes |
  |-------|------|-------|
  | `org_id` | `belongs_to Org` | |
  | `user_id` | `belongs_to User` | an **admin** of the org (set programmatically). |
  | `key` | `Encrypted.Binary` | the `org_audit_key` sealed for this admin via `sealForUser`. |
  | | | `unique_constraint([:org_id, :user_id])` |

- **`Orgs.AuditEvent`** (table `org_audit_events`):

  | Field | Type | Notes |
  |-------|------|-------|
  | `org_id` | `belongs_to Org` | |
  | `actor_id` | `belongs_to User` | who performed the action (system metadata). |
  | `action` | `:string` (plaintext enum-like) | e.g. `"member_added"`, `"circle_created"`, `"file_shared"`, `"file_revoked"`, `"role_changed"`, `"member_removed"`. Non-sensitive system category. |
  | `encrypted_detail` | `Encrypted.Binary` | a browser-encrypted (`org_audit_key`) human-readable description / target reference. |
  | `inserted_at` | timestamp | when it happened. |

> **Key generation timing.** When an org's **first admin** opens the audit panel
> (or the first auditable action occurs), the browser generates the
> `org_audit_key`, seals it for every current admin, and persists the
> `UserOrgAuditKey` rows (server-authoritative admin set — resolved from
> `Orgs.Membership role == :admin`). When a new admin is added later, an existing
> admin's browser seals the `org_audit_key` for the new admin (same add-member
> pattern as circles). Demoting an admin removes their `UserOrgAuditKey` (no
> future audit access; honest about the past).

### 12.2 Write path (recording an event)

Most auditable actions originate from an admin's browser action already (creating
a circle, changing a role, sharing/revoking a file). The admin's browser, which
holds the `org_audit_key` (unsealed via their own private key), encrypts the
event detail with the `org_audit_key` and pushes the opaque blob + plaintext
`action` category + `actor_id`. The server stores it; **the server never sees the
detail**.

> **Events that originate from a non-admin** (e.g. a regular member creates a
> circle): we record the **plaintext system category + actor + timestamp**
> (which are non-sensitive system metadata, like any DB audit), and the
> `encrypted_detail` is sealed using the **same `org_audit_key`** — which the
> acting member does *not* need to hold, because the *detail* can be reconstructed
> client-side by an admin from the already-ZK-readable target (the circle they're
> an admin-recipient of), OR we record a minimal detail the actor can encrypt if
> they happen to hold the key. To keep this simple and strictly ZK in Phase 3,
> the **detail is optional**: when the actor cannot encrypt for the audit key, we
> store only the plaintext system category + actor + timestamp (still a useful,
> non-sensitive audit trail) and the admin UI renders the human description from
> data the admin can already decrypt (e.g. the circle name via their own
> membership). **No plaintext sensitive content is ever stored.** (Implementation
> detail to finalize during 3c-audit; the invariant — server never reads
> sensitive audit detail — is fixed.)

### 12.3 Read path (admin views the log)

An admin's browser unseals the `org_audit_key` (their `UserOrgAuditKey.key` →
`unsealFromUser` with their own keys), lists `AuditEvent` rows for the org,
decrypts each `encrypted_detail` client-side, and renders the activity feed.
Non-admins never receive a `UserOrgAuditKey` and cannot read the log.

### 12.4 Audit invariants

- Audit content is readable **only** by org admins (recipients), **never** the
  server (I6).
- The admin recipient set is **server-authoritative** (derived from
  `Membership role == :admin`).
- Demotion/removal stops future audit access; past entries stay (honest).

### 12.5 Implemented label model (Tasks #212 / #352 / #353)

The shipped implementation simplifies §12.1's `org_audit_key` to **reuse the
org's existing `org_key`** as the audit read key — the same per-org key the
OrgMembers roster, org announcements, and org display-names already seal for
every member. This avoids a second key-generation/sealing handshake while
preserving I6: the `org_key` exists only as per-user sealed copies, never in
plaintext server-side, and is held by org members/admins (the audit panel is
gated to owner/admin viewers).

- **`Orgs.AuditEvent.encrypted_label`** (`:string`, nullable, **not**
  Cloak-wrapped — it is *already* `org_key` ciphertext produced by the actor's
  browser). The server stores it opaquely and can never read it (I6). One
  generic slot, reused per action; the UI falls back to a generic, name-free
  server-side phrase (`audit_action_label/1`) when absent.

- **Per-action label source** (all client-encrypted under `org_key`; never
  plaintext to the server):

  | Action | Label | ZK source (producer) |
  |--------|-------|----------------------|
  | `circle_created` / `circle_updated` / `circle_deleted` | circle name | group_key→org_key re-encrypt in `GroupMetadataFormHook` / `CircleMetadataEditHook` / `CircleAuditLabel` |
  | `circle_role_changed` (per-circle role) | circle name | `CircleAuditLabel` (cached on the open manage panel) |
  | `role_changed` (org-level role) | new role (`"Admin"`/`"Member"`) | `OrgRoleAuditLabel` precomputes both, server picks by role |
  | `file_shared` | filename | `SharedFileHook` re-encrypts the filename under org_key at upload, carried through `finalize_shared_file` |
  | `file_revoked` | filename | `DecryptSharedFileName` re-encrypts the (already-decrypted) filename under org_key, cached by file id; the `delete_shared_file` producer attaches it |
  | `member_invited` | invited email | `InviteAuditLabel` encrypts the email on submit (email is non-secret to the server, but the label channel stays uniform) |
  | `member_added` / `member_removed` / `display_name_changed` | — (no label) | the audit panel's member directory resolves the actor/target name from each membership's `org_key`-encrypted display name |

  Per-circle role changes use a distinct `circle_role_changed` category (vs the
  org-level `role_changed`) so the client can render the right sentence
  ("…role in the circle 'X'" vs "…role to Admin") from the same single label
  slot without ambiguity.

## 13. Implementation plan

1. **Schema & migrations (no UI):**
   - `mix ecto.gen.migration add_org_id_to_groups`: add nullable `org_id` FK +
     index (`on_delete: :nilify_all`). Add `belongs_to :org` to `Groups.Group`
     (no `cast`).
   - `mix ecto.gen.migration create_org_audit`: `user_org_audit_keys` +
     `org_audit_events` tables. `Orgs.UserOrgAuditKey` + `Orgs.AuditEvent`
     schemas (key material only on `UserOrgAuditKey.key`).
2. **Context (no UI):**
   - `Groups.create_business_circle_zk/…` (stamps `org_id` + resolves org-member
     recipients server-side). Org-eligibility guard in `add_group_members_zk/2`
     when `org_id` set. `Groups.list_business_circles/2`; `Orgs.member_of_org?/2`.
   - `Orgs` audit context: `ensure_org_audit_key_sealed_for_admins/…`,
     `record_audit_event/…`, `list_audit_events/…`, `list_audit_admins/1`,
     `seal_audit_key_for_new_admin/…`, `remove_audit_access/…`. All writes via
     `Repo.transaction/1`.
3. **BusinessLive dashboard:** `Index` + `Show` mirroring FamilyLive; org member
   management (reusing existing invitation/membership flows); **onboarding
   wizard** (11.1); **business-circles panel** with **basic circle chat**
   surfaced (11.3); **ZK admin audit panel** (12); explicit offboarding action
   (Q5); liquid-metal styling.
4. **Routes + nav:** add `/app/business*` routes in the existing live_session;
   add `:business` menu item (shown only when ≥1 business org — Q4).
5. **JS:** a small audit hook (seal `org_audit_key` for admins / decrypt events)
   reusing `sealForUser`/`unsealFromUser`; reuse the existing group chat hooks
   for circle chat (no new chat crypto).
6. **Tests:** LiveView tests mirroring `family_live_test.exs` (onboarded_user +
   log_in + get_key; letters-only names, avoid reserved names like "admin").
   Cover: org-scoped listing, eligibility enforcement (non-member cannot be
   added), no-guardianship, ZK create/add round-trip, audit readable only by
   admins, circle chat round-trip.
7. **Verify:** `mix precommit`, browser walkthrough, security checklist §9.

---

**Sign-off status: APPROVED.** Q1–Q6 resolved (§10); P0 additions (onboarding,
ZK audit log, basic circle chat) approved (§11–12). Implementing in the order in
§13.
