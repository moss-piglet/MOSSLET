# Safe Org Deletion — Design (Task #227)

Status: **DRAFT — awaiting sign-off**
Relates: EPIC #207, pairs with #225. Specs: ENCRYPTION_ARCHITECTURE.md, BUSINESS_CIRCLES_DESIGN.md, ZK_FILE_SHARING_DESIGN.md.

## Problem

There is no owner-facing UI to delete a Family/Business org. The only code path,
`Orgs.delete_org/1` → `Repo.delete(org)` (`orgs/adapters/web.ex:107`), is a bare row
delete that relies entirely on DB FK `ON DELETE`. That is **dangerous and incomplete**:

- `groups.org_id` is `:nilify_all` → deleting an org **orphans its business circles**
  (they silently become personal circles), keeping circle posts, replies, messages,
  and shared files alive and re-homed. Privacy + data-integrity gap.
- `shared_files.org_id` is `:delete_all` → the DB rows vanish but the **Tigris blobs are
  orphaned** (never deleted from object storage).
- `billing_customers.org_id` is `:delete_all` → the local Customer/Subscription rows
  cascade away, but **Stripe is never told to cancel** anything.
- No re-auth gate, no confirmation, no audit log, no export-first UX.

## Goals

Deleting an org must TRULY remove everything that could have been shared inside it,
preserve the ZK PQ (Cat-5) model (only ciphertext/key material is destroyed; never logs
secrets; no server master key), and be high-friction + owner-only + irreversible-with-warning.

## Decisions needing sign-off

### D1 — Billing teardown (IMPORTANT)
The org's seat plan currently lives on the **owner's personal `:user` customer**
(`orgs.ex:860 owner_org_subscription/1`), NOT an `:org`-source customer. That same
`:user` customer also covers the owner's **personal account** (their non-org Mosslet use).

> **Proposed:** On org delete, cancel **only an `:org`-source** subscription/customer if
> one exists (forward-compatible; none today). **Do NOT cancel the owner's `:user`
> subscription** — that would wrongly kill their personal account coverage. Instead, surface
> a clear note in the modal: *"Your Business plan is billed to your personal account and is
> NOT cancelled by deleting this organization. Manage or cancel it in Billing."* with a link.
> If billing later moves to an `:org` customer, this code already cancels it.

Alternative (if you prefer): refuse deletion while a matching `:user` plan is active and
tell the owner to cancel billing first. **I recommend the proposed approach** (delete the
org regardless; never touch personal billing; tell the truth in the UI).

### D2 — Circle (group) teardown
> **Proposed:** Before deleting the org row, explicitly `Groups.delete_group/1` each circle
> from `Groups.list_org_business_circles/1`. `delete_group/1` already calls
> `Files.delete_all_for_group/1` (Tigris) then cascades user_groups/messages/posts/
> shared_files via FK. This guarantees no orphaned `org_id=NULL` circles. (Plus a belt-and-
> suspenders `Files.delete_all_for_org/1` for any non-circle org files.)

### D3 — Export-first
> **Proposed:** The confirm modal *encourages but does not force* an export. We link to the
> existing ZK export (`/app/users/manage-data`). There is **no org-wide export today**;
> building one is out of scope for #227 (note as follow-up under #229). The modal copy makes
> clear data is irretrievable after deletion.

### D4 — Re-auth + confirm UX
> **Proposed:** Mirror `DeleteAccountLive`: password re-auth via
> `User.valid_password?/2` (Argon2). ADD a type-to-confirm field requiring the user to type
> the org name (we have `org.name` decrypted in the dashboard already). Owner-only via
> `Orgs.owner?/2` (created_by_id) — stricter than `:admin`.

### D5 — Where the UI lives
> **Proposed:** A "Danger Zone" card at the bottom of **BusinessLive.Show** (and FamilyLive.Show)
> visible only to the owner, opening a confirm modal. Server re-checks owner + password + name
> on submit (never trust the client). On success → `push_navigate` to `/app/business` (or
> `/app/family`) with a flash.

## Teardown order (server, owner-gated, audited)

`Orgs.delete_org_safely(org, owner, password)`:
1. Re-assert `Orgs.owner?(org, owner.id)`; verify `User.valid_password?(owner, password)`.
   On failure → `{:error, :unauthorized}` / `{:error, :invalid_password}` (no teardown).
2. Cancel `:org`-source subscription if present (provider cancel_immediately + local).
   Never touch the owner's `:user` subscription (D1).
3. Tear down circles: `Enum.each(Groups.list_org_business_circles(org), &Groups.delete_group/1)`
   (Tigris blobs + cascades). Then `Files.delete_all_for_org(org.id)` for any stragglers.
4. `Repo.transaction_on_primary(fn -> Repo.delete(org) end)` → FK cascades memberships,
   invitations, guardianships, billing_customer, logs, remaining shared_file rows.
5. `Mosslet.Logs.log("orgs.delete", %{user: owner, org_id: org.id})` (ids only, no secrets).

Steps 2–4 are best-effort-then-authoritative: blob/Stripe failures are logged (no secrets)
but do not block the DB delete (mirrors `delete_group/1` / `delete_account` best-effort blob
cleanup). The org row delete is the source-of-truth "it's gone" moment.

## ZK invariants
Only ciphertext + sealed key material is destroyed. No plaintext, file_key, group_key,
org_key, session key, or password ever reaches a log, URL, or Oban arg. Password is verified
in-process and discarded.

## Tests
- `Orgs` unit: `delete_org_safely/3` happy path (org + circles + files gone, owner `:user`
  sub UNTOUCHED), wrong password → `:invalid_password` + nothing deleted, non-owner →
  `:unauthorized` + nothing deleted, circles fully torn down (no orphaned `org_id=NULL`).
- LiveView: Danger Zone hidden for non-owner admin; shown for owner; submit with wrong
  password shows error + org still exists; correct password + matching name → org deleted +
  redirect.
- `mix precommit` GREEN.

## Out of scope (follow-ups)
- Org-wide ZK data export (suggest under #229).
- Changing the FK `groups.org_id` from `:nilify_all` to `:delete_all` — NOT needed since we
  explicitly delete circles first; leaving `:nilify_all` is safer for the (rare) admin
  offboarding path that intentionally re-homes a circle. **No migration required.**
