# Handoff: Kemah — Camping Trip Planner (iOS)

> **Version:** 1.3.0 — see [`CHANGELOG.md`](./CHANGELOG.md) for history. Older snapshots live under [`versions/`](./versions/). The visual reference prototype is in [`reference/`](./reference/).

## Overview
Kemah is a trip-planning app for group camping trips: packing checklist, budget tracking with split-bill settlement, participant management, invites, and social sharing. This package documents an interactive HTML prototype (`reference/Kemah Travel App.dc.html`, included for reference) so it can be rebuilt as a real iOS app.

## About the Design Files
The bundled HTML file is a **design reference prototype**, not production code. It was built as a single-file interactive mock to validate flows and logic (especially the split-bill math). The task is to **recreate this experience in the target codebase's real environment** (SwiftUI recommended for iOS-only; React Native/Flutter if Android is also planned) using that platform's native components and patterns — not to embed or wrap the HTML.

> Note: the v1.1.0 personal-expense and personal-item-privacy features (see the changelog) are **not** shown in the reference prototype — they were added after it. Build them from this document, not the HTML.

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
- Header: cover photo extends **full-bleed behind the status bar** (no white gap at the top) with a dark gradient scrim, back button, trip name + location/date, participant avatar stack, "+ Undang" button, and conditionally "Lihat Peta" (opens the saved Maps URL) / "Chat Admin" (opens `wa.me/<phone>` deep link) pill buttons. **[v1.2.0]** Cover height ~230pt, ScrollView ignores top safe area.
- Offline indicator row (same as Home)
- 3-tab segmented bar: **Checklist / Budget / Peserta**

**Checklist tab**
- Overall progress bar + "X/Y beres" + percentage
- **[v1.2.0] Section split by PIC presence:**
  - **Kelompok** — items with an assigned PIC (`pic` not null/empty). Caption: "Butuh PIC — yang bertanggung jawab bawa". These are shared gear items where one participant is responsible.
  - **Pribadi** — items with no PIC (`pic` null/empty). Caption: "Dibawa masing-masing peserta sendiri — nggak perlu PIC". Personal (`isPersonal: true`) items naturally land here since they never carry a PIC.
  - Each section header shows a done/total counter on the right (e.g. "5/15").
  - Previous split by `isPersonal` flag is now implicit: personal items (no PIC by definition) always appear in Pribadi.
- **[v1.1.0] Personal items are private.** Items with `isPersonal: true` carry a server-set `owner` and are returned only to that owner. Other participants never see them. Personal items count toward the owner's own progress total only.
- Section toggle: iOS-style segmented control — gray track, white sliding pill, active label = accent color, inactive = muted gray.
- Each item row: checkbox (tap toggles done, fills with accent color + checkmark), name + qty, meta line (PIC + note, or just note for personal items), delete "×"
- Tap item body (not checkbox) → opens edit sheet
- A single floating action button (FAB, bottom-right) adds an item to the currently active section. Kelompok section opens the add sheet with PIC field visible; Pribadi opens with `isPersonal: true` pre-set (private, no PIC).
- Add/Edit Item sheet: Kelompok/Pribadi segmented toggle, Name, Qty, PIC field (searchable dropdown of trip participants, hidden when "Pribadi"), Note (optional)

**Budget tab**
- Total Budget card (gradient): **Otomatis/Manual** mode toggle — Otomatis pins the target to the live sum of all **group** expenses (always 100%, no over-budget state); Manual lets the user set a fixed target via an "Edit" button/sheet. Shows spent amount, percentage, progress bar, and an over-budget warning chip when applicable. **Personal expenses are excluded from this card's total.**
- **Pengeluaran Kelompok** list: every group expense (name, payer, amount, a small "Per Orang"/"Per PIC" tag), tap to edit, "×" to delete
- **[v1.1.0] Pengeluaran Pribadi** — a separate section for the logged-in user's **private** expenses:
  - Only visible on the owner's login (server-set `owner`, filtered per token), tagged "Pribadi", with a lock hint ("Hanya terlihat olehmu · tidak dibagi ke peserta lain")
  - **No split-bill mechanism** — personal expenses are never pooled, split, or netted into any transfer
  - Shows a running "Total pribadi" and a **"Bagikan Ringkasan"** share action (a plain text summary of the user's own personal expenses) — sharing is the only output
  - "+ Tambah Pengeluaran Pribadi" opens the expense sheet pre-set to Pribadi
- "+ Tambah Pengeluaran" (group) opens Add/Edit Expense sheet:
  - **Kelompok / Pribadi** segmented toggle (top). When **Pribadi**: the split-mode toggle, "Dibayar oleh", and "Untuk siapa" fields are hidden — a personal expense is implicitly paid by, owned by, and private to the current user
  - **Per Orang / Per PIC** segmented toggle (Kelompok only — see Split Bill Logic below)
  - Name field
  - Optional Qty + Harga Satuan fields that auto-compute the Jumlah (total) field
  - Jumlah (Rp) — the total amount (editable directly or auto-filled)
  - **Dibayar oleh** — primary field, searchable dropdown of participants; who actually paid (Kelompok only)
  - **Untuk siapa** (optional, Per PIC mode only) — searchable dropdown; who/which PIC group the cost belongs to, if different from the payer. Left blank = belongs to the payer themself
- **[v1.2.0] "Split Bill" CTA bar**: fixed to the bottom of the screen (slim, accent-colored, orange fills safe area). Content centered: `[↔] Split Bill [›]`. Casts an upward shadow. A floating "+" FAB (bottom-right, above the bar) opens the add expense sheet. Tapping the bar → pushes the dedicated Split Bill screen.
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
- "Transfer yang Perlu Dilakukan": minimal-transaction settlement list. Transfers to the **same recipient are merged into one row** (combined total); **[v1.2.0] every transfer row is expandable** (chevron always shown) — tapping reveals the itemized breakdown (e.g. "Bagi rata" for pool-derived shares, or the specific expense name for direct debts). A leading circle checkbox lets the user mark a transfer as paid (strikethrough + dimmed row)
- "Bagikan Ringkasan" button (dark) opens the Share sheet
- **[v1.1.0] Only group expenses participate here.** Personal expenses (`isPersonal: true`) are excluded entirely from every calculation on this screen.

## Split Bill Logic (port this exactly — it's the core value of the app)

Each expense item has: `name`, `price`, `paidBy` (who fronted the money — always set), `pic` (optional — who/what group the cost belongs to, only meaningful in "Per PIC" mode), `splitMode` (`'orang'` | `'pic'`), and **[v1.1.0]** `isPersonal` (bool) + `owner` (set when personal).

**Step 0 — exclude personal (v1.1.0).** Before any split math, drop every item with `isPersonal: true`. Personal expenses are private to their owner and never split, pooled, or netted. Only group expenses (`isPersonal: false`) enter the algorithm below.

**Per Orang items** (e.g. shared food): pooled together (`sharedSpent`). Each participant's fair share = `sharedSpent × (their headcount / sum of all participants' headcount)`. Bigger families/groups (higher headcount) pay proportionally more. Credited to whoever's `paidBy`.

**Per PIC items** split into **three** cases based on `pic` and `paidBy`:

- **Pooled Per-PIC** (`pic` blank/nil) — e.g. a flat per-group cost like car rental. Pooled together (`picSpent`) and divided **flatly by number of participants** (`picSpent / participantCount`) — headcount is ignored here, every participant pays the same flat share regardless of group size.
- **Self-paid Per-PIC** (`pic` set and equal to `paidBy`, non-empty) — **excluded from all settlement.** The person already paid for their own cost; no redistribution to other participants. These items do not enter the pool and generate no transfer. Example: Irma pays her own ticket and marks `pic = paidBy = "Irma"`.
- **Direct debt** (`pic` set and different from `paidBy`) — e.g. Dinda paid a specific expense that belongs entirely to Rangga's family. NOT pooled or split — a fixed 1:1 debt: `pic` owes `paidBy` the full item price.

**Settlement calculation**
1. Drop self-paid Per-PIC items (`pic == paidBy`) — they are already settled and must not enter any pool or debt.
2. For each participant, `balance = (Per-Orang contribution − Per-Orang fair share) + (pooled Per-PIC contribution − flat Per-PIC share)`.
3. Run a greedy debt-simplification: sort debtors (negative balance) and creditors (positive balance) by magnitude descending, repeatedly match the largest debtor with the largest creditor, transfer `min(|debt|, credit)`, reduce both, continue until all balances are ~0. This minimizes the number of transactions (standard "splitwise" settlement algorithm).
4. Append the direct-debt transfers (from case above) as-is, not netted through the pool.
5. **Merge transfers by (from, to) pair** — if a person owes the same recipient from multiple sources (pool settlement + a direct debt), show ONE combined row with the total, and let the UI expand it to reveal the itemized parts (each part labeled either "Bagi rata" for pool-derived amounts, or the specific expense name for direct debts).

**Thresholds:** balances within ±1000 are considered "Lunas" (settled); the greedy matcher ignores amounts ≤ 500.

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
  items: [{ name, qty, pic, note, checked, isPersonal, owner? }],           // owner set for personal items (v1.1.0)
  budgetItems: [{ name, price, pic, paidBy, splitMode, isPersonal, owner? }] // isPersonal + owner added (v1.1.0)
}
```
- **`items[].owner` / `budgetItems[].owner` (v1.1.0):** set (server-side, from the auth token) when `isPersonal: true`; `null` for shared/group entries. The backend must return personal entries **only** to their owner. The client must never render another user's personal entries.
- App-level state: current screen/tab, active trip id, all sheet open/closed + form-field state, per-transfer paid/expanded UI state (ephemeral, not persisted), offline/online flag.

## Assets
- Cover photos: user-uploaded (drag-and-drop placeholders in the prototype — wire up a real photo picker + storage)
- No icon font/library used — the prototype draws its few icons (map pin, share, checkmark, copy) as inline SVG; use SF Symbols on iOS instead

## Files
- `reference/Kemah Travel App.dc.html` — the full interactive prototype (single file: template + state/logic). Read the `<script data-dc-script>` block for the exact settlement math (`computeTransfers`, `buildTripView`) if any behavior above is ambiguous. (Reflects v1.0.0 scope; no personal-privacy features.)

---

## Seed Data (Dev / QA)

Data di bawah adalah seed yang digunakan `MockRepository` di iOS app. Backend developer dapat menggunakan ini untuk seed database awal agar iOS app langsung bisa konek dan menghasilkan settlement yang deterministic dan bisa diverifikasi.

**Logged-in user (default mock session)**
```json
{ "id": "u_irma", "name": "Irma", "email": "irma@example.com", "avatarUrl": null }
```

---

### Trip 1 — Camping Gunung Papandayan

```json
{
  "id": "t1",
  "name": "Camping Gunung Papandayan",
  "location": "Garut, Jawa Barat",
  "date": "2026-08-01",
  "coverUrl": null,
  "mapLink": "https://maps.google.com/?q=Gunung+Papandayan",
  "phone": "081234567890",
  "status": "upcoming",
  "budgetTarget": 1200000,
  "budgetMode": "manual"
}
```

**Participants**
| id | name | picForLabel | headcount |
|---|---|---|---|
| p_irma | Irma | Koordinator | 3 |
| p_yuki | Yuki | PIC Tenda | 4 |
| p_pepi | Pepi | PIC Memasak | 4 |
| p_ria | Ria | PIC Tiket & Logistik | 3 |

**Checklist Items** (group — visible to all)
| id | name | qty | pic | note | checked |
|---|---|---|---|---|---|
| i1 | Tenda dome 4 orang | 1 | Yuki | cek patok & pasak lengkap | ✓ |
| i2 | Matras alas tenda | 4 | Pepi | | |
| i3 | Flysheet / terpal | 1 | Yuki | pinjam punya Doni | |
| i4 | Palu & pasak cadangan | 1 | Yuki | | |
| i5 | Kompor portable + gas | 1 | Pepi | | ✓ |
| i6 | Nesting alat masak | 1 | Pepi | udah punya | ✓ |
| i7 | Bahan makanan 3 hari | 1 | Ria | | |
| i8 | Air minum galon | 2 | Pepi | | |
| i9 | Tiket masuk kawasan | 4 | Ria | beli online H-3 | ✓ |
| i10 | Tiket parkir kendaraan | 1 | Yuki | | |
| i11 | Retribusi camp ground | 1 | Ria | | |

**Checklist Items** (personal — private, visible only to owner)
| id | name | qty | owner | note |
|---|---|---|---|---|
| i12 | Baju ganti & jaket hangat | 3 | Irma | sesuaikan cuaca |
| i13 | Alat mandi pribadi | 1 | Irma | |
| i14 | Obat pribadi | 1 | Irma | jangan lupa obat alergi |
| i15 | Kamera & tripod | 1 | Yuki | punya Yuki |

**Budget Items** (group)
| id | name | price (Rp) | paidBy | pic | splitMode | keterangan |
|---|---|---|---|---|---|---|
| b1 | Tenda dome 4 orang | 150.000 | Irma | Yuki | pic | Direct debt — Yuki owes Irma |
| b2 | Sewa mobil | 200.000 | Irma | null | pic | Pooled flat (per KK) |
| b3 | Kompor portable + gas | 85.000 | Pepi | null | orang | Pooled per headcount |
| b4 | Bahan makanan 3 hari | 250.000 | Ria | null | orang | |
| b5 | Air minum galon | 30.000 | Pepi | null | orang | |
| b6 | Tiket masuk kawasan | 320.000 | Ria | null | orang | |
| b7 | Tiket parkir kendaraan | 20.000 | Yuki | null | orang | |
| b8 | Retribusi camp ground | 50.000 | Ria | null | orang | |
| b9 | Bensin & tol | 100.000 | Yuki | null | orang | |

**Budget Items** (personal — private, not split)
| id | name | price (Rp) | paidBy | owner |
|---|---|---|---|---|
| bp1 | Jajan & kopi | 45.000 | Irma | Irma |
| bp2 | Oleh-oleh keluarga | 120.000 | Irma | Irma |
| bp3 | Sewa kamera | 90.000 | Yuki | Yuki |

---

### Trip 2 — Trip Zenk: Malang

Data riil dari CSV pengeluaran grup Zenk, Malang 19–21 Jun 2026.

```json
{
  "id": "t2",
  "name": "Trip Zenk: Malang",
  "location": "Malang, Jawa Timur",
  "date": "2026-06-19",
  "coverUrl": null,
  "mapLink": "https://maps.google.com/?q=Malang+Jawa+Timur",
  "phone": null,
  "status": "selesai",
  "budgetTarget": 9653877,
  "budgetMode": "auto"
}
```

**Participants**
| id | name | picForLabel | headcount |
|---|---|---|---|
| p_irma | Irma | Koordinator | 3 |
| p_yuki | Yuki | PIC Dokumentasi | 4 |
| p_devi | Devi | PIC Konsumsi | 4 |
| p_ria | Ria | PIC Tiket & Logistik | 3 |

**Checklist Items**
| id | name | qty | pic | note | checked |
|---|---|---|---|---|---|
| j1 | Tiket Jatim Park 3 | 14 | Ria | beli online H-3 | ✓ |
| j2 | Tiket Museum Angkut | 14 | Ria | | ✓ |
| j3 | Tiket Taman Safari Prigen | 14 | Ria | | ✓ |
| j4 | Tiket Wisata Kebun Apel | 14 | Ria | | ✓ |
| j5 | Villa | 1 | Devi | 3 malam | ✓ |
| j6 | Bekal & bahan masak | 1 | Ria | | ✓ |
| j7 | Snack & minuman | 1 | Yuki | | ✓ |

**Budget Items — Pengeluaran Bersama** (flat per KK → `splitMode: "pic"`, pic: null)
| id | name | price (Rp) | paidBy |
|---|---|---|---|
| m1 | Villa | 1.000.000 | Devi |
| m2 | Bekal | 288.500 | Ria |
| m3 | Snack | 137.500 | Yuki |
| m4 | Perkap bento & masak | 97.500 | Yuki |
| m5 | Snack klethikan | 91.000 | Yuki |
| m6 | Makan sopir | 136.000 | Ria |
| m7 | Parkir | 95.000 | Ria |
| m8 | Aqua & rokok | 82.000 | Ria |
| m9 | Beras | 36.000 | Irma |
| m10 | Telur | 50.000 | Devi |
| m11 | Snack (Devi) | 30.000 | Devi |
| m12 | Parkir soto | 10.000 | Devi |
| m13 | Parkir apel | 15.000 | Devi |
| m14 | Parkir bebek | 5.000 | Devi |
| m15 | Wisata Kebun Apel | 325.000 | Ria |

**Budget Items — Tiket HTM** (`splitMode: "pic"`, direct debt — semua dibayar Irma)

> `pic == paidBy` = pooled per-PIC (Irma menanggung bagiannya sendiri). `pic != paidBy` = direct debt (pic owes Irma penuh).

| id | name | price (Rp) | paidBy | pic |
|---|---|---|---|---|
| m16a | Jatim Park 3 – Devi | 673.143 | Irma | Devi |
| m16b | Jatim Park 3 – Ria | 504.857 | Irma | Ria |
| m16c | Jatim Park 3 – Irma | 504.857 | Irma | Irma |
| m16d | Jatim Park 3 – Yuki | 673.143 | Irma | Yuki |
| m17a | Museum Angkut – Devi | 440.000 | Irma | Devi |
| m17b | Museum Angkut – Ria | 330.000 | Irma | Ria |
| m17c | Museum Angkut – Irma | 330.000 | Irma | Irma |
| m17d | Museum Angkut – Yuki | 440.000 | Irma | Yuki |
| m18a | Safari Prigen – Devi | 822.842 | Irma | Devi |
| m18b | Safari Prigen – Ria | 617.132 | Irma | Ria |
| m18c | Safari Prigen – Irma | 617.132 | Irma | Irma |
| m18d | Safari Prigen – Yuki | 766.272 | Irma | Yuki |

**Budget Items — Makan** (`splitMode: "orang"`, per headcount)
| id | name | price (Rp) | paidBy |
|---|---|---|---|
| m20 | Ayam Rocket | 264.000 | Irma |
| m21 | Soto | 272.000 | Ria |

**Total group budget Trip 2:** Rp 9.653.877 (budgetMode: auto → target = sum aktual)
