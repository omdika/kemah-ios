# Changelog — Kemah Handoff Docs

All notable changes to the handoff spec (`README.md` + `API_CONTRACT.md`) are recorded here.
Versioning is semantic-ish: MAJOR for breaking model/flow changes, MINOR for new features, PATCH for clarifications.

Each released version is archived verbatim under [`versions/`](./versions/); the files at the handoff root are always the latest.

## [1.3.0] — 2026-07-24

### Changed

**Split Bill Logic — self-paid Per-PIC category (new)**
- Per-PIC items now split into **three** cases (was two):
  1. **Pooled Per-PIC** — `pic` blank/nil. Split flatly by participant count (unchanged).
  2. **Self-paid Per-PIC** *(new)* — `pic` set and equal to `paidBy`. **Excluded from all settlement.** The person already paid for their own cost; no redistribution to other participants. These items do not enter the pool and do not appear in any transfer.
  3. **Direct debt** — `pic` set and different from `paidBy`. Fixed 1:1 debt (unchanged).
- The previous two-case description ("Pooled = `pic` blank **or** equal to `paidBy`") was incorrect and is now corrected. Self-payment is a distinct third case.

**Split Bill — backend-side (now required)**
- `GET /trips/:tripId/split-bill` is now the **required** computation path. The client MUST call this endpoint rather than computing settlement locally. Client-side computation (via `SplitBillCalculator`) remains available as an offline/fallback only.
- Rationale: server-authoritative computation prevents client math divergence as the algorithm evolves; enables server-side audit logs.

**Split Bill API response — shape update (breaking)**
- `perPerson[].paid` renamed to `perPerson[].contribution` — "contribution" is clearer (it's what they fronted, not what they owe).
- `transfers[].amount` renamed to `transfers[].total` — disambiguates from `parts[].amount` at the nested level.
- `perPerson[].headcount` added (was missing from response; needed for display in "Ringkasan per Orang").
- `perPerson[].poolDetails` added — Level B pool transparency: per-item `{ name, share, paid }` breakdown for the "Bagi rata" expansion in the transfer list. `share` = this person's fair portion of the item; `paid` = full item price if this person was the payer, else 0.

**UI — Dark mode**
- `Theme.background` and `Theme.surface` now use `UIColor` adaptive semantic colors (`systemGroupedBackground`, `secondarySystemGroupedBackground`) so all screens, sheets, and card backgrounds adapt automatically to light/dark mode.
- `Theme.textPrimary`, `textMuted`, `textSubtle` now use `UIColor.label`, `secondaryLabel`, `tertiaryLabel`.
- `Theme.neutralPillBg` → `UIColor.tertiarySystemGroupedBackground`.
- Text field pill backgrounds (`LabeledField`, `SearchableParticipantField`) changed from `Theme.background` to `Theme.surface` so fields are visually distinct from the page background in both modes.

**UI — AvatarStack overflow**
- `AvatarStack` now shows a maximum of 3 avatars (was 4). If more participants exist, a "···" pill is appended instead of a "+N" count label. This prevents the stack from overlapping the back button on Trip Detail.

### Notes
- Seed data is unchanged from 1.2.0 — self-paid items (e.g. "Safari Prigen – Irma" where `pic == paidBy == "Irma"`) were already present; they are now correctly excluded from settlement by the updated logic.
- CLAUDE.md updated to reflect corrected Per-PIC category definitions.

---

## [1.2.0] — 2026-07-23

### Changed

**Checklist tab — section split logic**
- "Kelompok" section now shows items **with an assigned PIC** (`pic` not empty); "Pribadi" shows items **without a PIC** (`pic` null/empty). Previously split was by `isPersonal` flag.
- Personal items (`isPersonal: true`) naturally fall into "Pribadi" since they never carry a PIC.
- Each section has its own add button: Kelompok opens the add sheet pre-set to Kelompok (PIC field visible); Pribadi pre-sets to Pribadi (personal/private, no PIC).
- Section header renamed to match: "Butuh PIC — yang bertanggung jawab bawa" (Kelompok) and "Dibawa masing-masing peserta sendiri — nggak perlu PIC" (Pribadi), each with a done/total counter.
- Segmented toggle uses iOS-native style: gray track, sliding white pill, active label = accent color, inactive label = muted gray.
- A single floating action button (FAB, bottom-right) replaces separate per-section add buttons; FAB defaults to the currently active section.

**Split Bill — transfer expansion**
- `hasParts` is now `true` for **all** transfers (even single-part ones). Previously only transfers with more than one part were expandable. Every transfer row shows a chevron and can be tapped to reveal its itemized breakdown.

**UI — Budget card**
- Reduced vertical padding and inner spacing; Rp amount font scaled down (30pt → 24pt); progress bar thinner (8px → 6px). Card is visually slimmer without losing information.

**UI — Trip Detail header**
- Cover photo now extends full-bleed behind the status bar / Dynamic Island (`ScrollView.ignoresSafeArea(edges: .top)`). Cover frame height adjusted to 230pt to compensate.

**UI — Split Bill CTA bar**
- Redesigned as a slim fixed bottom bar (height 40pt, orange fill extends into safe area via `ignoresSafeArea`).
- Content centered: `[↔ icon] Split Bill [›]`.
- Shadow casts upward (accent-colored, `y: -6`) to visually lift the bar off the screen.
- Replaced the previous full-width button with heavy padding.

**Seed data (MockRepository — dev only)**
- Trip 2 replaced with "Trip Zenk: Malang" (19–21 Jun 2026, real CSV budget).
  - Participants: Irma (hc 3), Yuki (hc 4), Devi (hc 4), Ria (hc 3).
  - Shared costs (villa, transport, meals, etc.) as flat Per-PIC items.
  - Wisata tickets (JTP3, Museum Angkut, Safari Prigen) as 12 direct-debt items (one per participant per venue, all paid by Irma, per-person amounts).
  - budgetTarget: Rp 9,653,877; budgetMode: `.auto`.

### Notes
- No API endpoints or request/response shapes changed in this version.
- `API_CONTRACT.md` version badge updated to 1.2.0 for consistency; the contract itself is unchanged.

## [1.1.0] — 2026-07-22

### Added
- **Personal expenses (Budget tab).** A private "Pengeluaran Pribadi" section, separate from group expenses. Personal expenses are visible only on their owner's login, are **excluded from the group budget total and the split-bill settlement**, and have no split mechanism — only a "Bagikan Ringkasan" share action.
  - Data model: `budgetItems[].isPersonal` (bool, default `false`) and `budgetItems[].owner` (server-set from the auth token; `null` for group expenses).
  - Add/Edit Expense sheet gains a **Kelompok / Pribadi** toggle; in Pribadi mode the split-mode / "Dibayar oleh" / "Untuk siapa" fields are hidden.
- **Private personal checklist items.** "Perlengkapan Pribadi" items are now visible only on the owner's login (previously shown to everyone).
  - Data model: `items[].owner` (server-set when `isPersonal: true`; `null` otherwise).

### Changed
- **Split Bill Logic** gained "Step 0 — exclude personal": all `isPersonal` items are dropped before any settlement math.
- `GET /trips` and `GET /trips/:id` responses are now filtered per caller — a participant never receives another user's personal `items`/`budgetItems`.
- `GET /trips/:tripId/split-bill` computes over group expenses only.
- Realtime section: subscriptions must enforce the same per-owner visibility.

### Notes
- The reference prototype (`reference/Kemah Travel App.dc.html`) reflects **v1.0.0** scope and does not demonstrate the privacy features; build them from the README, not the HTML.

## [1.0.0] — 2026-07-22 (initial handoff)

### Added
- Initial handoff: Login, Home, Trip Detail (Checklist / Budget / Peserta), and the dedicated Split Bill screen.
- Full split-bill settlement spec (per-orang headcount-proportional, pooled per-PIC flat, direct-debt 1:1, greedy simplification, merge-by-(from,to)).
- REST API contract for users, trips, participants, checklist items, budget items, split bill, invite, and photo upload.
- Design tokens (oklch colors, typography, spacing/shape).
- Interactive reference prototype `Kemah Travel App.dc.html`.
