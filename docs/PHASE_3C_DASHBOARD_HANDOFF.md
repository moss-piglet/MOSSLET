# Phase 3c Handoff — Business Dashboard (BusinessLive) + Circles UI + Chat

> Paste this into a fresh conversation. It is the focused spec for the **Business
> dashboard** slice of EPIC #207, Phase 3c (board task **#212**).

## Context

Mosslet — Phoenix 1.8 LiveView, ZK post-quantum (Cat-5 ML-KEM-1024) encrypted
social app. **Read FIRST:** `AGENTS.md`, `docs/ENCRYPTION_ARCHITECTURE.md`,
`docs/BUSINESS_CIRCLES_DESIGN.md` (APPROVED), `docs/GUARDIANSHIP_DESIGN.md` (the
pattern we mirror). Obey all guidelines: idiomatic Elixir/Phoenix/Ecto/JS/
Tailwind v4; `<.phx_*>` components; `DESIGN_SYSTEM.md` liquid-metal teal→emerald;
migrations ALWAYS via `mix ecto.gen.migration`; verify with `mix precommit`
(~17 known pre-existing type warnings, NO `--warnings-as-errors`).
`transaction_on_primary` is a plain `transaction/1` shim. Prefer simple,
targeted, maintainable changes. Use `browser_eval` to verify UI behavior (NOT
CSS). This conversation is on Task Board "Mosslet ZK PQE Migration" — manage via
task tools; task #212 is the Phase 3 epic item.

## ALREADY DONE — do NOT redo

**Billing/pricing (3a+3b):** Business plans live in `config/config.exs` +
`config/dev.exs` (real test product id `prod_UgdkpX4fDFkSTx`; `STRIPE_PRICE_
BUSINESS_*` env vars in `.env`). Pricing page + `subscribe_live.ex` handle
Business. Seat machinery (Phase 1) works.

**3c foundation (schema + context) — DONE & GREEN (mix compile + format clean):**

- Migration `priv/repo/migrations/20260611224552_add_org_id_to_groups.exs`:
  nullable `org_id` FK on `groups`, `on_delete: :nilify_all`, indexed. **Already
  migrated.**
- `Mosslet.Groups.Group` (`lib/mosslet/groups/group.ex:25`): added
  `belongs_to :org, Mosslet.Orgs.Org` — programmatic, **never `cast`**.
  `org_id == nil` ⇒ personal circle (unchanged); set ⇒ business circle.
- `Mosslet.Orgs` (`lib/mosslet/orgs.ex`): `list_member_user_ids_by_org/1`,
  `member_of_org?/2` (server-authoritative eligibility, I1).
- `Mosslet.Groups` (`lib/mosslet/groups.ex`):
  - `create_business_circle_zk/5(org, owner, zk_attrs, users, sealed_members)` —
    reuses `create_group_zk/5` verbatim, stamps `org_id`, **filters `users` +
    `sealed_members` to current org members** (I1). Guards `org.type ==
    :business` + creator membership. Returns `{:ok, group}` | `{:error, reason}`.
  - `add_business_circle_members_zk/2` — same eligibility filter on add.
  - `list_business_circles/2(org, user)` — org-scoped confirmed circles (I4).
  - `create_group_zk/4` is now `/5` with optional `org_id` opt — personal path
    unchanged.

**Approved decisions (BUSINESS_CIRCLES_DESIGN.md §10):** Q1 = **any org member**
creates a circle (becomes circle `:owner`); admins manage org membership/billing.
Q2 = reuse the existing circle composer (server stamps `org_id`). Q3 = nilify on
org delete. Q4 = sidebar item shown **only when user has ≥1 business org**. Q5 =
explicit one-click "remove from all circles in this org" offboarding, honest copy.
Q6 = "Business circles". **Business orgs do NOT use guardianship.**

**Deferred (NOT this slice):** ZK admin audit log (own focused slice; §12 of the
circles doc is the binding spec), Phase 3d ZK file sharing, (f) Stripe checkout
browser verification.

## IMPLEMENT (this slice) — mirror FamilyLive exactly

### 1. Routes + nav

- Add to the existing `:require_authenticated_user` live_session in
  `lib/mosslet_web/router.ex` (mirror the family block at ~467-471):
  ```elixir
  live "/business", BusinessLive.Index, :index
  live "/business/new", BusinessLive.Index, :new
  live "/business/:slug", BusinessLive.Show, :show
  ```
- Add a `:business` nav item in `lib/mosslet_web/menus.ex` (mirror the `:family`
  link at ~498: `%{name: :business, label: gettext("Business"),
  path: ~p"/app/business", icon: "hero-building-office"}`). Per Q4, only show it
  when the user belongs to ≥1 business org — check how `main_menu_items/1`
  (menus.ex:44) is built and gate accordingly (look at how/if family is gated;
  if family is always shown, add a membership check for business).

### 2. `MossletWeb.BusinessLive.Index` — mirror `family_live/index.ex` (192 lines)

- `mount` → `assign_businesses/1`: `current_scope.user |> Orgs.list_orgs() |>
  Enum.filter(&(&1.type == :business))`, each `%{org, membership:
  Orgs.get_membership!(user, org.slug), member_count: length(list_members_by_org)}`.
- `handle_params` sets `:page_title`. `<.layout current_page={:business}
  sidebar_current_page={:business} current_scope={@current_scope} type="sidebar">`.
- Empty state + "Create a business" form (`Orgs.create_org(user, %{"name" => name,
  "type" => "business"})`), `show_new`/`create_business` events. Reuse the
  liquid-metal hero/empty-state/card markup from FamilyLive.Index (swap copy +
  `hero-building-office` icon). Add `Mosslet.Logs.log("orgs.create_business", …)`.

### 3. `MossletWeb.BusinessLive.Show` — mirror `family_live/show.ex` (522 lines)

- `mount` `%{"slug" => slug}`: `Orgs.get_org!(user, slug)` +
  `Orgs.get_membership!(user, slug)`; **guard `org.type == :business`** (redirect
  to `~p"/app/business"` otherwise); assign `:org`, `:membership`, `:page_title`,
  `:invite_form`; then `assign_business_data/1`.
- `assign_business_data/1`: `@members` (with role badges via a new
  `BusinessComponents.business_role_badge` — only `:admin`/`:member` matter),
  `@circles = Groups.list_business_circles(org, user)`, `@can_manage? =
  membership.role == :admin`. Resolve member display names the same way
  FamilyLive.Show does (`resolve_display_name/3` via
  `get_user_connection_between_users` + `get_decrypted_connection_name`, using
  `current_scope.user` + `current_scope.key`).
- **Member management** (admin only): reuse existing org flows —
  `invite_member` (`Orgs.create_invitation` / `build_invitation`), `change_role`
  (`Orgs.update_membership`), remove (`Orgs.delete_membership`). Copy the
  invite_form + role <select> markup from FamilyLive.Show.
  - **NOTE:** dev invites of fake emails (example.com) fail `EmailChecker` MX
    check — that's task #213, not a bug here. Test with a real confirmed user or
    enable EmailChecker dev-mode config.
- **Business circles panel:** list `@circles` (decrypt name via existing
  `DecryptGroupMetadata` hook path — circles already render ZK content on the
  existing circle Show page). "New circle" entry point → reuse the existing
  circle composer but server-stamp `org_id` (Q2). Each circle links to the
  EXISTING circle Show route (which already does ZK chat + members). **Do not
  rebuild circle internals** — just create (via `create_business_circle_zk`) and
  link out.
- **Offboarding (Q5):** an explicit "Remove from organization" per-member action
  for admins. (The "remove from all circles" crypto-honest action can be a button
  that removes their `UserGroup` rows in this org's circles — wire it to
  `Groups.remove_group_members/2` per circle, or stub with a TODO if it balloons;
  keep it honest in copy: "can't recall content already downloaded.")

### 4. `MossletWeb.BusinessComponents` (new, mirror `family_components.ex`)

- `business_role_badge/1` (Admin/Member). Keep it tiny. Import into
  `mosslet_web.ex` html_helpers if you use it across modules.

### 5. Circle chat (P0) — SURFACE existing ZK chat, no new crypto

The existing circle Show page already has ZK `GroupMessage` chat + `@mentions`
(tasks #67/#69/#70/#121). For this slice, **just ensure business circles link to
that existing circle Show experience** so chat works out of the box. No new chat
code. (If the existing circle Show needs an `org_id`-aware tweak to display
properly, make it minimal.)

### 6. Tests — mirror `test/mosslet_web/live/family_live_test.exs`

Use `onboarded_user` + `log_in` + `get_key` helpers; **names must be letters
only, avoid reserved names like "admin"** (see `Group.validate_allowed_name`).
Cover: business Index lists only `:business` orgs; create business org; Show
guards non-business; member list renders; **eligibility — a non-org-member
cannot be added to a business circle** (assert `create_business_circle_zk` drops
them); `list_business_circles` is org-scoped; no guardianship UI on business.
Add context tests for `create_business_circle_zk/5` +
`add_business_circle_members_zk/2` + `Orgs.member_of_org?/2`.

## Verify

`mix precommit` (drop `--warnings-as-errors`; ~17 known pre-existing warnings
OK). Then `browser_eval`: create a business org, see it in the sidebar (only
when ≥1 business org), open Show, see member mgmt + circles panel, create a
circle, click into it and confirm the existing ZK chat loads.

## When done

Update board task #212 with progress. Then either continue to the **ZK admin
audit-log slice** (§12 of `BUSINESS_CIRCLES_DESIGN.md`) or **Phase 3d ZK file
sharing** (`ZK_FILE_SHARING_DESIGN.md`, APPROVED), and finally (f) verify
Business `?seats=` → SubscribeController → `Stripe.checkout/7` end-to-end with
`stripe listen` running (confirm a `business-*` row in `billing_subscriptions`).

## Grounding file index

| Concern | Path |
|---|---|
| FamilyLive (mirror) | `lib/mosslet_web/live/family_live/{index,show,feed}.ex` |
| Family components (mirror) | `lib/mosslet_web/components/family_components.ex` |
| Router family block | `lib/mosslet_web/router.ex` (~467-471) |
| Nav menu | `lib/mosslet_web/menus.ex` (main `:44`, family link `:498`) |
| Groups context (business fns) | `lib/mosslet/groups.ex` (`create_business_circle_zk`, `list_business_circles`, `add_business_circle_members_zk`) |
| Orgs context | `lib/mosslet/orgs.ex` (`member_of_org?`, `list_member_user_ids_by_org`, `create_org`, `list_members_by_org`, invitations, memberships) |
| Group schema | `lib/mosslet/groups/group.ex` (`belongs_to :org`) |
| ZK group create hook | `assets/js/hooks/group-metadata-form-hook.js` |
| Family test (mirror) | `test/mosslet_web/live/family_live_test.exs` |

Be idiomatic with Elixir/Phoenix/LiveView/Ecto/JS/Tailwind; simple and targeted;
preserve ZK privacy, security, performance, maintainability, and UI/UX.
