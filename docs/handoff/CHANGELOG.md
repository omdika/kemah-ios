# Changelog — Kemah Handoff Docs

All notable changes to the handoff spec (`README.md` + `API_CONTRACT.md`) are recorded here.
Versioning is semantic-ish: MAJOR for breaking model/flow changes, MINOR for new features, PATCH for clarifications.

Each released version is archived verbatim under [`versions/`](./versions/); the files at the handoff root are always the latest.

## [1.8.0] — 2026-07-27

### Changed

**`headcount` minimum turun dari 1 ke 0**
Peserta dengan `headcount: 0` dianggap ikut trip secara administratif tapi tidak menggunakan shared resources (contoh: driver, bayi, koordinator non-aktif). Mereka tidak mendapat porsi dari item Per-Orang, tapi tetap dihitung dalam flat-split Per-PIC (karena Per-PIC dibagi per peserta, bukan per headcount).

#### Frontend (iOS Swift)
- `SplitBill/SplitBillCalculator.swift`: hapus `max(p.headcount, 1)` di baris perhitungan share Per-Orang — gunakan `p.headcount` langsung. Tetap pertahankan `max(totalHeadcount, 1)` untuk guard division-by-zero.
- `Store/MockRepository.swift`: `updateParticipant` — ubah `max(v, 1)` → `max(v, 0)` agar nilai 0 bisa disimpan (tapi negatif tetap ditolak).
- `Views/Sheets.swift`: ubah Stepper dari `in: 1...20` → `in: 0...20`.
- `Views/PesertaTab.swift`: tampilkan `"tidak ikut"` (bukan `"0 orang"`) ketika `headcount == 0`.

#### Backend (FastAPI)
- `PATCH /trips/:tripId/participants/:participantId` — ubah validasi Pydantic field `headcount` dari `ge=1` ke `ge=0`.
- `GET /trips/:tripId/split-bill` — pastikan server-side split-bill calculator tidak clamp headcount ke minimum 1. Peserta dengan `headcount: 0` harus mendapat `share: 0` untuk semua item Per-Orang. Per-PIC flat-split tetap dibagi oleh jumlah peserta (tidak berubah).

#### Auth rules
- Semua peserta bisa update headcount diri sendiri.
- Owner trip bisa update headcount peserta manapun.
- Tidak ada perubahan aturan auth dari v1.7.0.

#### Test scenarios
- **Happy path**: peserta dengan `headcount: 0` mendapat `share: 0` untuk semua item Per-Orang di split-bill.
- **Per-PIC tidak berubah**: peserta dengan `headcount: 0` tetap menanggung 1/N dari item Per-PIC pooled.
- **Edge case — semua headcount 0**: totalHeadcount = 0 → semua share Per-Orang = 0, tidak crash (guard `max(totalHeadcount, 1)`).
- **Stepper**: UI memungkinkan memilih 0 dari edit-peserta sheet.
- **Display**: label di tab Peserta menampilkan "tidak ikut" untuk headcount 0, bukan "0 orang".
- **Error path**: nilai negatif ditolak → mock clamp ke 0, backend return 422.

#### Migration checklist (backend)
```sql
-- Tidak ada perubahan schema database.
-- Hanya perlu update validasi Pydantic dan logika split-bill di application layer.
```
- [ ] Ubah validasi `headcount: int = Field(ge=1)` → `headcount: int = Field(ge=0)` di schema Participant
- [ ] Pastikan fungsi `compute_split_bill()` tidak clamp headcount ke min 1
- [ ] Re-deploy Cloud Run setelah perubahan

---

## [1.7.0] — 2026-07-27

### Added

**`ownerId` — identitas pemilik trip**
- `Trip` dan `TripSummary` mendapatkan field baru `ownerId: string` — userId dari pembuat trip.
- Nilai di-set otomatis saat `POST /trips` dari auth token caller, tidak bisa diubah via PATCH.
- **Database:** `ALTER TABLE trips ADD COLUMN owner_id TEXT NOT NULL DEFAULT '';` lalu isi dengan `created_by` atau user pertama yang join.

**`userId` — link peserta ke akun**
- `Participant` mendapatkan field baru `userId: string | null` — `null` untuk peserta yang ditambahkan manual (belum punya akun terhubung), diisi saat peserta join via invite link.
- **Database:** `ALTER TABLE participants ADD COLUMN user_id TEXT DEFAULT NULL;`

**Hapus peserta — `DELETE /trips/:tripId/participants/:participantId`**
- Endpoint sudah ada sejak v1.0.0, sekarang ditegaskan authorization-nya.
- Hanya pemilik trip (`ownerId == caller userId`) yang boleh menghapus peserta lain.
- Tidak bisa menghapus peserta owner sendiri via endpoint ini (`400`).
- Hard delete: participant record dan semua personal item milik peserta tersebut ikut dihapus.

**Keluar dari trip — `DELETE /trips/:tripId/participants/me`**
- Endpoint baru. Semua peserta **kecuali owner** bisa keluar dari trip.
- Owner mendapat `403` — harus hapus trip (`DELETE /trips/:id`) jika ingin menutup trip.
- Caller diidentifikasi via `userId` dari auth token, dicocokkan ke `participants[].userId`.
- Hard delete: participant record dan semua personal item milik caller ikut dihapus.

### Migration checklist (backend)
```sql
ALTER TABLE trips ADD COLUMN owner_id TEXT NOT NULL DEFAULT '';
ALTER TABLE participants ADD COLUMN user_id TEXT DEFAULT NULL;
-- Isi owner_id untuk trip yang sudah ada (contoh: ambil dari participant pertama)
UPDATE trips SET owner_id = (
  SELECT user_id FROM participants
  WHERE trip_id = trips.id AND user_id IS NOT NULL
  ORDER BY created_at ASC LIMIT 1
) WHERE owner_id = '';
```

---

## [1.6.0] — 2026-07-25

### Added

**`docsLink` — link dokumentasi trip (Google Drive, Notion, dll)**
- `Trip` dan `TripSummary` mendapatkan field `docsLink: string | null`. Default `null`.
- `POST /trips` request body menerima `docsLink` (string, boleh kosong).
- `PATCH /trips/:id` menerima `docsLink`. Kirim `""` untuk menghapus link. Bersifat optional — field ini hanya di-update jika disertakan dalam request body (PATCH semantics biasa).
- **Database:** tambahkan kolom `docs_link TEXT DEFAULT NULL` di tabel `trips`.
- **Migrasi:** `ALTER TABLE trips ADD COLUMN docs_link TEXT DEFAULT NULL;`

**Client-only (tidak ada perubahan endpoint):**
- Multiple photo selection di PhotosPicker (maks 10 foto sekaligus per upload action).
- Download foto ke galeri device dari modal gallery.
- Share foto via iOS share sheet dari modal gallery.
- Layout photo strip dipindahkan ke trailing side (di bawah harga) — konsisten di Checklist, Budget, dan Split Bill.

### Notes
- `docsLink` adalah URL bebas — bisa Google Drive, Notion, PDF, atau apapun. Tidak ada validasi format di server selain memastikan nilainya string.
- Tidak ada breaking change pada response shape yang sudah ada.

---

## [1.5.0] — 2026-07-25

### Added

**Photo uploads — trip cover, checklist items, budget items**
- `POST /trips/:tripId/cover` (multipart) — sets/replaces the trip's cover photo with uploader attribution (`coverUploadedByName`/`coverUploadedAt` on `Trip`/`TripSummary`).
- `POST /trips/:tripId/items/:itemId/images` / `DELETE .../images/:imageId` — checklist item photo gallery.
- `POST /trips/:tripId/budget-items/:itemId/images` / `DELETE .../images/:imageId` — budget item photo gallery (e.g. receipts).
- Every uploaded image carries `uploadedBy`/`uploadedByName`/`createdAt`; only the uploader can delete their own image. Any participant who can see the entity (group item, or a personal item they own) can upload to it.
- `items[]`/`budgetItems[]` responses gain an `images[]` array (oldest first).
- `GET /trips/:tripId/split-bill` — `poolDetails[]` and direct-debt `transfers[].parts[]` gain `budgetItemId`, so the client can cross-reference `trip.budgetItems[].images` to show photos next to a settlement line without a new endpoint. `null` on merged "Bagi rata" parts (no single source item).
- New table `trip_images` (checklist/budget galleries) + `trips.cover_uploaded_by`/`cover_uploaded_by_name`/`cover_uploaded_at` columns — see `sql/migrations/002_add_images.sql`.
- `POST /uploads` (the old generic single-file upload) is unchanged and still available for one-off use, but the new attached-upload endpoints are preferred going forward since they persist attribution.

## [1.4.1] — 2026-07-25

### Added

**Invite links now resolve to something even without Universal Links**
- Invite links now point at this backend's own Cloud Run URL (`https://kemah-sg-....run.app/join/:tripId`) instead of the unowned `kemah.app` placeholder — no domain purchase needed, since a Cloud Run service's default URL is already a real, backend-controlled HTTPS domain.
- `GET /.well-known/apple-app-site-association` — added so Universal Links can be turned on later with zero backend changes, once a paid Apple Developer account exists (Associated Domains requires it; not available today).
- `GET /join/:tripId` — new fallback landing page. Since Universal Links can't intercept yet, tapping an invite link always opens this in Safari first; it auto-attempts the `kemah://` custom scheme (silently no-ops if the app isn't installed) with a visible "Buka di App Kemah" button as backup, and an honest "not on the App Store yet" message otherwise. Validates the token before revealing the trip name.

## [1.4.0] — 2026-07-24

### Added

**Guest mode — preview a trip before signing in**
- `GET /trips/:tripId/invite/preview?token=...` — new unauthenticated endpoint. Anyone holding an invite link can see a narrow preview (name, location, date, cover, participants, checklist progress count) without signing in first.
- Deliberately excludes budget/money data, personal items, and per-item checklist detail — those still require actually joining (`POST /join`, which still requires login).
- iOS: opening an invite link now always shows a read-only preview sheet first, regardless of auth state, with a context-appropriate CTA ("Lanjutkan dengan Google" if signed out, "Gabung Trip Ini" if already signed in) rather than immediately forcing the login screen.

## [1.3.1] — 2026-07-24

### Changed

**Auth — Google Sign-In implemented (iOS)**
- The Login screen's "Lanjutkan dengan Google" button now performs real Google Sign-In (`GoogleSignIn-iOS`) instead of the mocked entry.
- Client exchanges the resulting Google ID token for a Supabase session directly via Supabase's REST token endpoint (`grant_type=id_token`) — no Supabase SDK added, consistent with the app's plain-REST networking convention.
- No wire-format changes to any endpoint in this doc; this codifies the exact mechanism the Auth section already specified generically.
- Facebook and Apple buttons are still mocked; only Google is wired to a real provider so far.

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
