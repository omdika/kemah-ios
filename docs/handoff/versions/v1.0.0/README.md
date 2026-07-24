# Handoff: Kemah — Camping Trip Planner (iOS)

## Overview
Kemah is a trip-planning app for group camping trips: packing checklist, budget tracking with split-bill settlement, participant management, invites, and social sharing. This package documents an interactive HTML prototype (`Kemah Travel App.dc.html`, included for reference) so it can be rebuilt as a real iOS app.

## About the Design Files
The bundled HTML file is a **design reference prototype**, not production code. It was built as a single-file interactive mock to validate flows and logic (especially the split-bill math). The task is to **recreate this experience in the target codebase's real environment** (SwiftUI recommended for iOS-only; React Native/Flutter if Android is also planned) using that platform's native components and patterns — not to embed or wrap the HTML.

## Fidelity
**High-fidelity for structure and logic, medium-fidelity for visual polish.** Colors, type, spacing, and copy are final enough to build from directly, but treat them as a strong starting point rather than pixel law — prefer the target platform's native controls (nav bars, sheets, share sheets, date pickers) over recreating custom HTML chrome.

## Design Tokens

**Color** (defined as CSS `oklch()`, convert to the nearest sRGB hex in-platform):
- Background: `oklch(0.985 0.006 80)` — warm off-white
- Text (primary): `oklch(0.24 0.02 50)` — warm near-black
- Text (muted): `oklch(0.55 0.02 50)` / `oklch(0.5 0.02 50)`
- Text (subtle): `oklch(0.6 0.02 50)`
- Surface/card background: `#fff` on the warm background
- Accent (theme-selectable, pick one as the app's brand color):
  - Orange (default): `oklch(0.68 0.19 45)`
  - Green: `oklch(0.62 0.15 150)`
  - Blue: `oklch(0.6 0.16 250)`
- Accent soft tint (for active tab / pill backgrounds): `oklch(0.95 0.03 45)` (matching hue per theme)
- Positive/credit (settlement "menerima"): `oklch(0.55 0.13 150)` (green)
- Negative/debit (settlement "bayar"): `oklch(0.6 0.17 45)` (orange/red)
- Participant avatar palette (cycled by index): `oklch(0.7 0.19 45)`, `oklch(0.65 0.15 150)`, `oklch(0.65 0.15 240)`, `oklch(0.62 0.16 320)`, `oklch(0.6 0.14 20)`
- Offline indicator dot: `oklch(0.6 0.02 50)` (offline) / `oklch(0.65 0.15 150)` (online)

**Typography**
- Headings: rounded system font — `ui-rounded, "SF Pro Rounded", system-ui` (iOS: use SF Pro Rounded directly), weight 600–700
- Body: `system-ui` (iOS: SF Pro Text/Display), weight 400–600
- Sizes used: 32/24/22/19/17/15/14/13/12/11px (scale down proportionally to iOS type scale: largeTitle/title2/headline/subheadline/footnote/caption)

**Spacing / shape**
- Card radius: 16–20px; pill/button radius: 10–14px; small chip/badge radius: 8–9px; avatars/circular buttons: fully round
- Card shadow: soft, `0 1px 2px rgba(0,0,0,0.04–0.06)` + occasional `0 6–8px 20px rgba(0,0,0,0.05–0.2)` for elevated elements (FAB, trip cards)
- Sheet: bottom sheet, rounded top corners (26px), drag handle bar at top

## Screens / Views

### 1. Login
- Full-bleed hero image area (camping/mountain photo) at top, gradient placeholder behind it (orange→purple diagonal)
- App name "Kemah" (large, rounded heading), one-line tagline below
- Three auth buttons stacked: "Lanjutkan dengan Google" (white bg, colored circular "G" mark), "Lanjutkan dengan Facebook" (white bg), "Masuk dengan Apple" (dark filled, white text/mark) — **on iOS, replace with real `Sign in with Apple` + Google Sign-In SDK buttons per each provider's HIG**
- Small legal footer text
- Tap any button → navigates to Home (mock only; real app authenticates first)

### 2. Home
- Header: "Halo, {name}" small muted line + "Trip Kamu" large heading, circular avatar top-right
- Offline indicator row (dot + "Mode Offline · data tersimpan di perangkat" / "Tersambung · tersinkron"), tap toggles state (mock connectivity demo)
- "Akan Datang" (Upcoming) section: cards with cover photo (user-uploaded), trip name, location + date, participant avatar stack (overlapping circles, max 4 + count), checklist progress ("X/Y siap"), small map-pin and WhatsApp icon buttons if the trip has a saved map link / contact phone
- "Riwayat" (History) section: compact rows for completed trips with a "Bagikan" (Share) quick action
- Floating "+" action button (bottom-right) opens "Buat Trip Baru" sheet
- Bottom 2-tab bar: "Trip" (active) / "Profil" (stub)

### 3. Trip Detail
- Header: cover photo (shared with Home card via same image ref) with dark gradient scrim, back button, trip name + location/date, participant avatar stack, "+ Undang" button, and conditionally "Lihat Peta" (opens the saved Maps URL) / "Chat Admin" (opens `wa.me/<phone>` deep link) pill buttons
- Offline indicator row (same as Home)
- 3-tab segmented bar: **Checklist / Budget / Peserta**

**Checklist tab**
- Overall progress bar + "X/Y beres" + percentage
- Two sections: **Perlengkapan Kelompok** (shared gear — has a PIC/owner field) and **Perlengkapan Pribadi** (personal items — no PIC, just name/qty/note)
- Each item row: checkbox (tap toggles done, fills with accent color + checkmark), name + qty, meta line (PIC + note, or just note for personal items), delete "×"
- Tap item body (not checkbox) → opens edit sheet
- "+ Tambah Barang" button per section opens add sheet pre-set to that section's type
- Add/Edit Item sheet: Kelompok/Pribadi segmented toggle, Name, Qty, PIC field (searchable dropdown of trip participants, hidden when "Pribadi"), Note (optional)

**Budget tab**
- Total Budget card (gradient): **Otomatis/Manual** mode toggle — Otomatis pins the target to the live sum of all expenses (always 100%, no over-budget state); Manual lets the user set a fixed target via an "Edit" button/sheet. Shows spent amount, percentage, progress bar, and an over-budget warning chip when applicable
- "Rincian Pengeluaran" list: every expense (name, payer, amount, a small "Per Orang"/"Per PIC" tag), tap to edit, "×" to delete
- "+ Tambah Pengeluaran" opens Add/Edit Expense sheet:
  - **Per Orang / Per PIC** segmented toggle (see Split Bill Logic below)
  - Name field
  - Optional Qty + Harga Satuan fields that auto-compute the Jumlah (total) field
  - Jumlah (Rp) — the total amount (editable directly or auto-filled)
  - **Dibayar oleh** — primary field, searchable dropdown of participants; who actually paid
  - **Untuk siapa** (optional, Per PIC mode only) — searchable dropdown; who/which PIC group the cost belongs to, if different from the payer. Left blank = belongs to the payer themself
- "Split Bill" entry card (tap) → opens the dedicated Split Bill screen
- Split-bill logic is documented in detail below — this is the most business-critical part to port faithfully

**Peserta tab**
- List of participants: avatar, name, role/PIC label + headcount ("PIC Tenda · 2 orang"), tap row opens "Edit Peran" sheet
- Edit Peran sheet: role text field with quick-select preset chips (Koordinator, PIC Tenda, PIC Masak, PIC Tidur, PIC Tiket, PIC Dokumentasi) + a "Jumlah Orang" stepper (−/count/+, min 1) representing how many people that participant represents (e.g. bringing family)
- "Undang Teman" button opens Invite sheet
- If trip is completed (history), a "Bagikan Ringkasan Trip" button opens the Share sheet

### 4. Split Bill (full screen, pushed from Budget tab)
- Header: back button + centered "Split Bill" title
- Summary banner: "Dibagi N orang · Rp X / orang"
- "Ringkasan per Orang": per-participant row — avatar, name, "Bayar {what they paid} · jatah {their fair share} ({headcount} orang)", and a colored pill showing net balance (green "+ Rp…" if owed money, red "− Rp…" if they owe, "Lunas" if settled)
- "Transfer yang Perlu Dilakukan": minimal-transaction settlement list. Transfers to the **same recipient are merged into one row** (combined total); tapping the row expands a breakdown of what makes up that total (e.g. "Bagi rata" pool share + a named direct expense). A leading circle checkbox lets the user mark a transfer as paid (strikethrough + dimmed row)
- "Bagikan Ringkasan" button (dark) opens the Share sheet

## Split Bill Logic (port this exactly — it's the core value of the app)

Each expense item has: `name`, `price`, `paidBy` (who fronted the money — always set), `pic` (optional — who/what group the cost belongs to, only meaningful in "Per PIC" mode), `splitMode` (`'orang'` | `'pic'`).

**Per Orang items** (e.g. shared food): pooled together (`sharedSpent`). Each participant's fair share = `sharedSpent × (their headcount / sum of all participants' headcount)`. Bigger families/groups (higher headcount) pay proportionally more. Credited to whoever's `paidBy`.

**Per PIC items** split into two cases based on whether `pic` is set and differs from `paidBy`:
- **Pooled Per-PIC** (`pic` blank or equal to `paidBy`) — e.g. a flat per-group cost like car rental. Pooled together (`picSpent`) and divided **flatly by number of participants** (`picSpent / participantCount`) — headcount is ignored here, every PIC/unit pays the same flat share regardless of group size.
- **Direct debt** (`pic` set and different from `paidBy`) — e.g. Dinda paid a specific expense that belongs entirely to Rangga's family. This is NOT pooled or split among everyone — it becomes a fixed 1:1 debt: `pic` owes `paidBy` the full item price.

**Settlement calculation**
1. For each participant, `balance = (Per-Orang contribution − Per-Orang fair share) + (pooled Per-PIC contribution − flat Per-PIC share)`.
2. Run a greedy debt-simplification: sort debtors (negative balance) and creditors (positive balance) by magnitude descending, repeatedly match the largest debtor with the largest creditor, transfer `min(|debt|, credit)`, reduce both, continue until all balances are ~0. This minimizes the number of transactions (standard "splitwise" settlement algorithm).
3. Append the direct-debt transfers (from case above) as-is, not netted through the pool.
4. **Merge transfers by (from, to) pair** — if a person owes the same recipient from multiple sources (pool settlement + a direct debt), show ONE combined row with the total, and let the UI expand it to reveal the itemized parts (each part labeled either "Bagi rata" for pool-derived amounts, or the specific expense name for direct debts).

## Interactions & Behavior
- All sheets are bottom sheets with a scrim backdrop; tapping the backdrop or a "Batal"/"Tutup" action closes them
- Searchable dropdowns (PIC / Dibayar oleh / Untuk siapa fields): typing filters the participant list live; selecting fills the field and closes the dropdown; if no match, the typed text is still accepted as a new name
- Toasts: a small pill at the bottom of the screen, auto-dismisses after ~2.2s, used for every create/update/delete confirmation and for the mocked share actions
- Cover photos: drag-and-drop / file-picker image slot; the same photo shows on both the Home trip card and the Trip Detail header (same underlying image reference)
- Date field in "Buat Trip Baru": native date picker
- Map link field: stored as a real URL; rendered as a tappable pin-icon pill that opens it externally
- Phone field: normalized to international format (leading `0` → `62` country code) and rendered as a WhatsApp deep link (`https://wa.me/<number>`)

## State Management (data model)

```
Trip {
  id, name, location, dateLabel, mapLink, phone, coverId (photo ref),
  status: 'upcoming' | 'selesai',
  budgetTarget: number,
  budgetMode: 'manual' | 'auto',
  participants: [{ name, picForLabel (role), headcount }],
  items: [{ name, qty, pic, note, checked, isPersonal }],
  budgetItems: [{ name, price, pic, paidBy, splitMode }]
}
```
App-level state: current screen/tab, active trip id, all sheet open/closed + form-field state, per-transfer paid/expanded UI state (ephemeral, not persisted), offline/online flag.

## Assets
- Cover photos: user-uploaded (drag-and-drop placeholders in the prototype — wire up a real photo picker + storage)
- No icon font/library used — the prototype draws its few icons (map pin, share, checkmark, copy) as inline SVG; use SF Symbols on iOS instead

## Files
- `Kemah Travel App.dc.html` — the full interactive prototype (single file: template + state/logic). Read the `<script data-dc-script>` block for the exact settlement math (`computeTransfers`, `buildTripView`) if any behavior above is ambiguous.
