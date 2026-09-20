# Kemah — Camping Trip Planner (iOS)

> **Version:** 1.8.0 — lihat [`docs/handoff/CHANGELOG.md`](docs/handoff/CHANGELOG.md) untuk riwayat versi. Snapshot lama ada di [`docs/handoff/versions/`](docs/handoff/versions/). Prototype visual referensi ada di [`docs/handoff/reference/`](docs/handoff/reference/).

Aplikasi perencanaan camping trip kelompok: packing checklist, budget tracking dengan split-bill settlement, manajemen peserta, invite, dan sharing. Dibangun native dengan SwiftUI (iOS 16.0+), tanpa third-party dependencies untuk data flow utama.

## Overview

Kemah membantu kelompok camping mengelola trip dari perencanaan hingga settlement biaya. Fitur inti: **Checklist** (Kelompok dengan PIC / Pribadi private), **Budget** (Kelompok + Pribadi, mode Otomatis/Manual), **Split Bill** (settlement engine client-side yang faithful ke prototype), **Peserta** (role, headcount, undang via link), serta **Foto** (cover, item, bukti bayar). App berjalan offline-first via `MockRepository` (default) dan siap switch ke `APIRepository` saat backend REST siap — kontrak API ada di [`docs/handoff/API_CONTRACT.md`](docs/handoff/API_CONTRACT.md).

## Tampilan Aplikasi


| Tampilan | Deskripsi |
|---|---|
| <img width="1920"  alt="image" src="https://github.com/user-attachments/assets/506d9fec-1167-42d5-807d-ebaa0e740f3a" /> | **Halaman Utama — Trip Kamu** — Dashboard personal ("Halo, Irma") dengan indikator **Mode Offline · data tersimpan di perangkat**. Bagian **Akan Datang** menampilkan kartu besar (Camping Gunung Papandayan — Garut, Jawa Barat · 1 Agustus 2026, progress `4/14 siap`, avatar stack, tombol peta & WhatsApp). Bagian **Riwayat** menampilkan trip selesai (Trip to Malang — 19 Juni 2026, aksi Bagikan). Bottom bar Trip/Profil dan FAB `+` untuk "Buat Trip Baru". |
| <img width="1920"  alt="image" src="https://github.com/user-attachments/assets/0109235f-9f98-4c86-8c9a-634037531dc6" /> | **Detail Trip — Checklist** — Header full-bleed (cover + gradient, avatar stack `I Y D ···`, tombol Undang & Lokasi). Tab bar `Checklist / Budget / Peserta` (Checklist aktif). Progress `3/7 beres (43%)` + filter **Kelompok / Pribadi** (segmented control). Caption Kelompok: "Butuh PIC — yang bertanggung jawab bawa" (`3/7`). Item: `Tiket Jatim Park 3 ×14 — PIC: Ria · beli online H-3`, `Tiket Museum Angkut ×14`, `Tiket Taman Safari ×14`, `Tiket Wisata Kebun Apel ×14` (checked), `Villa — PIC: Devi · 3 malam`. FAB `+` tambah item sesuai seksi aktif. |
| <img width="1920" alt="image" src="https://github.com/user-attachments/assets/f57aaa68-f02d-425b-bf3b-b4a6b3d49576" /> | **Detail Trip — Budget** — Kartu **Total Budget Rp9.653.878** dengan toggle **Otomatis / Manual** (Otomatis = 100%, Terpakai Rp9.653.878, progress bar penuh). Daftar **Pengeluaran Kelompok**: `Villa — Dibayar Devi — Rp1.000.000 (Per PIC)`, `Bekal — Dibayar Ria — Rp288.500`, `Snack — Dibayar Yuki — Rp137.500`, `Perkap bento & masak — Dibayar Yuki — Rp97.500`, dst. Tombol **Split Bill** (bar oranye fixed di bawah) untuk ke layar settlement. |
| <img width="1920" alt="image" src="https://github.com/user-attachments/assets/ece106ae-2f2e-495a-88ca-d48e259cdd40" /> | **Detail Trip — Peserta** — Daftar peserta dengan avatar warna (I/oranye, Y/hijau, D/biru, R/ungu): `Irma — Koordinator · 3 orang`, `Yuki — PIC Dokumentasi · 4 orang`, `Devi — PIC Konsumsi · 4 orang`, `Ria — PIC Tiket & Logistik · 3 orang` (ikon hapus merah untuk non-owner). Aksi **Undang Teman** (oranye) dan **Bagikan Ringkasan Trip** (putih). Header sama dengan tab lain. |
| <img width="1920"  alt="image" src="https://github.com/user-attachments/assets/8c20feb1-751a-4003-9efa-b4e9d5dc8998" /> | **Split Bill — Settlement** — Judul "Split Bill". **Ringkasan per Orang**: `Irma — Bayar Rp300.000 · jatah Rp714.482 (3 orang) — −Rp414.482`, `Yuki — Bayar Rp326.000 · jatah Rp752.768 (4 orang) — −Rp426.768`, `Devi — Bayar Rp1.110.000 · jatah Rp752.768 — +Rp357.232`, `Ria — Bayar Rp1.198.500 · jatah Rp714.482 — +Rp484.018`. **Transfer yang Perlu Dilakukan**: `Yuki → Ria Rp426.768 (1 rincian)`, `Irma → Ria Rp57.250`, `Irma → Devi Rp357.232`, `Devi → Irma Rp1.935.985 (3 rincian)` — setiap row expandable untuk breakdown "Bagi rata" vs. direct debt, dengan checkbox tandai lunas. |

## Tentang File Desain

File HTML di `docs/handoff/reference/Kemah Travel App.dc.html` adalah **design reference prototype**, bukan production code. Dibuat sebagai single-file mock interaktif untuk validasi flow dan logika (terutama split-bill). Tugas implementasi adalah **merekreasi pengalaman ini di SwiftUI** dengan komponen native iOS — bukan embed/wrap HTML.

> Catatan: fitur personal-expense & privacy item pribadi v1.1.0 **tidak** tampil di prototype (ditambahkan setelahnya). Bangun dari dokumen handoff ini, bukan dari HTML. Block `<script data-dc-script>` (`computeTransfers`, `buildTripView`) adalah source of truth untuk math settlement v1.0.0.

## Fidelity

**High-fidelity untuk struktur & logika, medium-fidelity untuk visual polish.** Warna, tipografi, spacing, dan copy sudah final untuk build, tapi perlakukan sebagai starting point — prefer kontrol native iOS (nav bar, sheet, share sheet, date picker, SF Symbols) daripada merekonstruksi chrome custom HTML.

## Design Tokens

**Color** (didefinisikan sebagai `oklch()`, konversi ke sRGB hex terdekat di iOS):
- Background: `oklch(0.985 0.006 80)` — warm off-white
- Text primary: `oklch(0.24 0.02 50)` — warm near-black
- Text muted: `oklch(0.55 0.02 50)` / `oklch(0.5 0.02 50)`
- Text subtle: `oklch(0.6 0.02 50)`
- Surface/card: `#fff` di atas warm background
- Accent (theme-selectable):
  - Orange (default): `oklch(0.68 0.19 45)`
  - Green: `oklch(0.62 0.15 150)`
  - Blue: `oklch(0.6 0.16 250)`
- Accent soft tint (active tab/pill): `oklch(0.95 0.03 45)` (sesuai hue theme)
- Positive/credit ("menerima"): `oklch(0.55 0.13 150)` — hijau
- Negative/debit ("bayar"): `oklch(0.6 0.17 45)` — oranye/merah
- Avatar palette (cycle by index): `oklch(0.7 0.19 45)`, `oklch(0.65 0.15 150)`, `oklch(0.65 0.15 240)`, `oklch(0.62 0.16 320)`, `oklch(0.6 0.14 20)`
- Offline dot: `oklch(0.6 0.02 50)` (offline) / `oklch(0.65 0.15 150)` (online)

**Typography**
- Headings: rounded — `ui-rounded, "SF Pro Rounded", system-ui` (iOS: SF Pro Rounded), weight 600–700
- Body: `system-ui` (iOS: SF Pro Text/Display), weight 400–600
- Sizes: 32/24/22/19/17/15/14/13/12/11px → mapping ke iOS type scale (largeTitle/title2/headline/subheadline/footnote/caption)

**Spacing / Shape**
- Card radius: 16–20px; pill/button: 10–14px; chip/badge: 8–9px; avatar/FAB: fully round
- Card shadow: `0 1px 2px rgba(0,0,0,0.04–0.06)` + `0 6–8px 20px rgba(0,0,0,0.05–0.2)` untuk elevated (FAB, kartu trip)
- Sheet: bottom sheet, rounded top 26px, drag handle bar

Di iOS, token diimplementasi di `Theme/` dengan warna adaptive via `UIColor` semantic (`systemGroupedBackground`, `label`, `secondaryLabel`, dll.) sehingga otomatis support **Dark Mode**.

## Screens / Views

### 1. Login
- Full-bleed hero image (camping/mountain) + gradient placeholder oranye→ungu
- Judul "Kemah" (rounded heading besar) + tagline satu baris
- Tiga tombol auth: "Lanjutkan dengan Google" (putih, mark G warna), "Lanjutkan dengan Facebook" (putih), "Masuk dengan Apple" (gelap) — **di iOS ganti dengan `Sign in with Apple` + `GoogleSignIn-iOS` asli** (v1.3.1 Google sudah real via Supabase `POST /auth/v1/token?grant_type=id_token`)
- Footer legal kecil; tap tombol → Home (mock; real app autentikasi dulu)

### 2. Home — *lihat screenshot 01*
- Header: "Halo, {name}" (muted kecil) + "Trip Kamu" (heading besar), avatar bulat kanan atas
- Bar indikator offline (dot + "Mode Offline · data tersimpan di perangkat" / "Tersambung · tersinkron"), tap toggle state (mock)
- **Akan Datang**: kartu dengan cover (upload user), nama trip, lokasi + tanggal, avatar stack (overlap, max 3 + pill `···` sejak v1.3.0), progress checklist ("X/Y siap"), ikon pin peta & WhatsApp jika `mapLink`/`phone` ada
- **Riwayat**: row compact untuk trip `selesai` + aksi "Bagikan"
- FAB `+` (kanan bawah) → sheet "Buat Trip Baru"
- Bottom 2-tab: "Trip" (aktif) / "Profil" (stub)

### 3. Trip Detail
- Header: cover **full-bleed di belakang status bar** (tanpa gap putih, `ignoresSafeArea(.top)`, tinggi ~230pt sejak v1.2.0) dengan scrim gradient gelap, tombol back, nama + lokasi/tanggal, avatar stack, tombol "+ Undang", pill "Lihat Peta" (buka Maps URL) / "Chat Admin" (`wa.me/<phone>`) kondisional
- Bar indikator offline (sama seperti Home)
- Segmented 3-tab: **Checklist / Budget / Peserta**

#### Checklist Tab — *lihat screenshot 02*
- Progress bar overall + "X/Y beres" + persentase
- **Split seksi by PIC (v1.2.0):**
  - **Kelompok** — item dengan `pic` terisi. Caption: "Butuh PIC — yang bertanggung jawab bawa". Counter `done/total` di header seksi.
  - **Pribadi** — item tanpa `pic` (`null`/kosong). Caption: "Dibawa masing-masing peserta sendiri — nggak perlu PIC". Item `isPersonal: true` otomatis masuk sini (tidak pernah punya PIC).
- **Personal privacy (v1.1.0):** item `isPersonal: true` bawa `owner` (server-set) dan hanya dikembalikan ke owner. Peserta lain tidak melihatnya; hitung progress hanya untuk owner.
- Segmented control iOS-style (gray track, white pill geser, label aktif = accent)
- Row item: checkbox (tap toggle, fill accent + checkmark), nama + qty, meta (PIC + note, atau hanya note untuk pribadi), tombol hapus "×", ikon kamera untuk foto
- Tap body item → sheet edit; FAB kanan-bawah tambah item ke seksi aktif (Kelompok tampilkan field PIC dropdown searchable, Pribadi pre-set `isPersonal: true` tanpa PIC)

#### Budget Tab — *lihat screenshot 03*
- Kartu **Total Budget** (gradient): toggle **Otomatis/Manual** — Otomatis = target terkunci ke sum live semua **pengeluaran kelompok** (selalu 100%, tanpa over-budget); Manual = user set target via sheet Edit. Tampilkan spent, persentase, progress bar, chip warning over-budget. **Pengeluaran pribadi tidak masuk total ini.**
- **Pengeluaran Kelompok**: list (nama, payer, amount, tag "Per Orang"/"Per PIC"), tap edit, "×" hapus, foto receipt
- **Pengeluaran Pribadi (v1.1.0)**: seksi terpisah private milik user login — hanya owner lihat (filter by token), tag "Pribadi" + hint "Hanya terlihat olehmu · tidak dibagi", **tanpa mekanisme split**, tampilkan "Total pribadi" + aksi **Bagikan Ringkasan** (teks ringkas pengeluaran pribadi)
- Sheet Tambah/Edit: toggle **Kelompok / Pribadi** (atas). Saat Pribadi: toggle split, "Dibayar oleh", "Untuk siapa" disembunyikan — implisit dibayar & dimiliki user. Mode Kelompok: toggle **Per Orang / Per PIC**, field Nama, Qty + Harga Satuan auto-hit Jumlah, Jumlah (Rp), **Dibayar oleh** (dropdown searchable), **Untuk siapa** (opsional, mode Per PIC, kosong = milik payer sendiri)
- **Bar "Split Bill" (v1.2.0)**: fixed di bawah layar (slim, oranye fill sampai safe area, shadow ke atas `y:-6`, konten center `[↔] Split Bill [›]`). FAB `+` di atas bar untuk tambah expense. Tap bar → push layar Split Bill.

#### Peserta Tab — *lihat screenshot 04*
- List peserta: avatar, nama, label role + headcount ("PIC Tenda · 2 orang", `headcount: 0` tampil "tidak ikut" sejak v1.8.0), tap row → sheet "Edit Peran" (field role + chip preset: Koordinator, PIC Tenda, PIC Masak, dll. + stepper Jumlah Orang −/+/count, min 0 sejak v1.8.0)
- Tombol **Undang Teman** → sheet Invite; jika trip `selesai`, tombol **Bagikan Ringkasan Trip** → Share sheet
- Aturan v1.7.0: `ownerId` (pembuat trip) + `Participant.userId` (link ke akun, `null` jika manual). Hapus peserta (`DELETE /participants/:id`) hanya owner, tidak bisa hapus diri sendiri; Keluar dari trip (`DELETE /participants/me`) untuk non-owner (owner tidak tampilkan tombol keluar).

### 4. Split Bill — *lihat screenshot 05*
- Header: back + judul "Split Bill" center
- Ringkasan banner: "Dibagi N orang · Rp X / orang"
- **Ringkasan per Orang**: row per peserta — avatar, nama, "Bayar {paid} · jatah {share} ({headcount} orang)", pill balance (hijau `+ Rp…` jika piutang, merah `− Rp…` jika utang, "Lunas" jika ±1000)
- **Transfer yang Perlu Dilakukan**: minimal-transaction settlement, **merge per pasangan (from, to)** jadi satu row (total gabungan); **setiap row expandable** (chevron selalu tampil, v1.2.0) → breakdown item ("Bagi rata" untuk pool, atau nama expense untuk direct debt). Checkbox bulat di leading untuk tandai lunas (strikethrough + dimmed).
- Tombol **Bagikan Ringkasan** (gelap) → Share sheet
- Hanya pengeluaran kelompok yang dihitung; `isPersonal: true` diexclude sepenuhnya.

## Split Bill Logic — handle with care

Field per expense: `name`, `price`, `paidBy` (selalu ada, fallback `paidBy || pic`), `pic` (opsional), `splitMode` (`'orang' | 'pic'`), `isPersonal` + `owner` (v1.1.0).

**Step 0 — exclude personal (v1.1.0):** drop semua `isPersonal: true` sebelum hitung.

**Per Orang** (mis. makan bersama): pool `sharedSpent`. Jatah per peserta = `sharedSpent × (headcount / sumHeadcount)`. Headcount `0` (v1.8.0) → jatah `0` untuk item Per-Orang; guard `max(totalHeadcount, 1)` cegah div-by-zero. Di-credit ke `paidBy`.

**Per PIC** — tiga kasus:
- **Pooled Per-PIC** (`pic` kosong/nil) — mis. sewa mobil: pool `picSpent`, bagi **flat per peserta** (`picSpent / participantCount`), headcount diabaikan.
- **Self-paid Per-PIC** (`pic` terisi dan `pic == paidBy`): **exclude dari settlement** — sudah lunas sendiri, tidak masuk pool & tidak generate transfer.
- **Direct debt** (`pic` terisi dan `pic != paidBy`): bukan pool — utang 1:1 tetap: `pic` owes `paidBy` full `price`.

**Settlement:**
1. Drop self-paid (`pic == paidBy`).
2. Per peserta: `balance = (kontribusi Per-Orang − jatah Per-Orang) + (kontribusi pooled Per-PIC − share flat)`.
3. Greedy debt simplification: sort debtor (negatif) & creditor (positif) by magnitude desc, match terbesar ↔ terbesar, transfer `min(|debt|, credit)`, kurangi keduanya, ulang sampai ~0. Ignore amount ≤ 500.
4. Append direct-debt transfers apa adanya (tidak di-net via pool).
5. **Merge transfer by (from, to)** — gabung total, UI expand tampilkan parts.

**Threshold:** balance dalam ±1000 = "Lunas"; matcher abaikan ≤ 500. Implementasi ada di `SplitBill/SplitBillCalculator.swift` — port faithful dari `computeTransfers` di prototype. Threshold & fallback `paidBy || pic` adalah load-bearing — jangan ubah tanpa rujuk README handoff.

## Interaksi & Behavior

- Semua sheet adalah bottom sheet dengan scrim; tap backdrop atau "Batal"/"Tutup" menutup
- Dropdown searchable (PIC / Dibayar oleh / Untuk siapa): filter live saat ketik, pilih isi field & tutup; jika no match, teks ketikan tetap diterima sebagai nama baru
- Toast: pill kecil bawah layar, auto-dismiss ~2.2s untuk konfirmasi create/update/delete & share mock
- Cover foto: slot drag-and-drop / file picker; foto sama tampil di kartu Home & header Detail (satu referensi)
- Field tanggal Buat Trip: native date picker; `mapLink` URL real → pill pin yang buka eksternal; `phone` normalize `0` → `62` → deep link `https://wa.me/<number>`
- Foto (v1.5.0): cover / item checklist / item budget bisa punya galeri foto (`images[]`), upload via `POST /.../images` (multipart `file`), hanya uploader bisa hapus (`DELETE /.../images/:imageId`), peserta yang bisa lihat entity boleh upload.

## State Management (Data Model)

```swift
Trip {
  id, name, location, dateLabel, mapLink, phone, docsLink, coverUrl,
  coverUploadedByName, coverUploadedAt,
  status: 'upcoming' | 'selesai',
  budgetTarget: number,
  budgetMode: 'manual' | 'auto',
  ownerId: string,                                                          // v1.7.0
  participants: [{ id, userId?, name, picForLabel, headcount }],            // userId v1.7.0, headcount min 0 sejak v1.8.0
  items: [{ id, name, qty, pic, note, checked, isPersonal, owner?, images[] }], // owner v1.1.0, images v1.5.0
  budgetItems: [{ id, name, price, pic, paidBy, splitMode, isPersonal, owner?, images[] }]
}
```

- `items[].owner` / `budgetItems[].owner` (v1.1.0): di-set server dari auth token saat `isPersonal: true`; `null` untuk grup. Backend hanya kembalikan personal ke owner; client jangan render personal milik orang lain. `MockRepository.visible(_:)` enforce filter per-user ini.
- `Trip.ownerId` (v1.7.0): userId pembuat, set saat `POST /trips`, immutable. Hanya owner bisa hapus peserta lain; owner tidak bisa keluar via `DELETE /me` (harus hapus trip).
- App-level state: screen/tab aktif, active trip id, sheet open/closed + form state, per-transfer paid/expanded (ephemeral), flag offline/online.

## Arsitektur Proyek

```
Models/         — Trip, Participant, ChecklistItem, BudgetItem, split-bill DTOs
                Field & shape match API_CONTRACT.md agar JSON decode tanpa adapter.
                GET /trips → TripSummary (participantCount, checklistProgress); GET /trips/:id → Trip full
Networking/     — APIClient (async/await REST, Authorization: Bearer <idToken> via TokenProvider, multipart upload)
                Requests.swift payloads create/update; PATCH body optional-only encoding. Tanpa Firebase/Supabase SDK — plain REST.
Store/          — KemahRepository protocol → APIRepository (real backend) + MockRepository (actor, in-memory, seed dari prototype)
                Mock adalah default agar app jalan di simulator tanpa backend; UI hanya depend ke protocol.
SplitBill/      — SplitBillCalculator (faithful port JS prototype, core value app), Formatters (rp(), waLinkFor())
Theme/          — Design tokens oklch → sRGB hex, accent themes, avatar palette cycle-index, CardBackground modifier, adaptive dark/light
Views/          — SwiftUI screens & sheets (Login, Home, TripDetail, ChecklistTab, BudgetTab, PesertaTab, SplitBill, Sheets)
```

`TripStore` adalah `ObservableObject` (`@Published` + `import Combine`, terpaksa karena target iOS 16) di-inject via `@EnvironmentObject`. Logic app pakai SwiftUI + async/await, hindari Combine untuk data flow.

## Tech Stack

- **SwiftUI** — iOS 16.0+ (tanpa `@Observable`/`@Bindable`/`@Environment(Type.self)`, tanpa `onChange` 2-param, tanpa `.spring(duration:)`)
- **Swift Concurrency** — async/await untuk semua data flow
- **No third-party dependencies** — murni native iOS (GoogleSignIn-iOS hanya untuk auth Google, sesuai kontrak)
- Copy/UI bahasa **Indonesia** ("Buat Trip Baru", "Perlengkapan Kelompok", "Bagi rata", dll.)

## Menjalankan

1. Buka `trip planner.xcodeproj` di Xcode 15+
2. Pilih simulator / device
3. Build & Run — tanpa konfigurasi tambahan (MockRepository aktif by default)

Ganti ke backend real: inject `APIRepository` di `TripStore` (butuh `idToken` dari Google/Apple → Supabase session `access_token` sebagai Bearer).

Tests: `RunAllTests` / `RunSomeTests` / `GetTestList` via xcode-tools MCP; framework `Testing` (`import Testing`, `@Test`).

## Handoff Docs

Spesifikasi lengkap ada di [`docs/handoff/`](docs/handoff/):

| File | Isi |
|---|---|
| `README.md` | Spec UI, split bill logic, design tokens, state model, seed data |
| `API_CONTRACT.md` | REST endpoints, request/response shapes, auth Bearer, privacy rules |
| `CHANGELOG.md` | Riwayat perubahan spec per versi (v1.0.0 → v1.8.0) |
| `versions/` | Snapshot per versi |
| `reference/Kemah Travel App.dc.html` | Prototype visual + logika referensi (script `computeTransfers`) |

Versi spec saat ini: **v1.8.0**

## Seed Data

Mock session default: user **Irma** (`u_irma`). Dua trip (lihat detail lengkap di `docs/handoff/README.md` § Seed Data):

- **Camping Gunung Papandayan** (t1, upcoming, 1 Agu 2026, manual Rp1.200.000) — 4 peserta (Irma Koordinator 3, Yuki PIC Tenda 4, Pepi PIC Memasak 4, Ria PIC Tiket 3), 11 item kelompok + 4 personal (Irma/Yuki), 9 budget grup + 3 personal
- **Trip Zenk: Malang** (t2, selesai, 19 Jun 2026, auto Rp9.653.877) — 4 peserta (Irma 3, Yuki 4, Devi 4, Ria 3), 7 checklist, 15 pengeluaran bersama flat Per-PIC + 12 tiket HTM direct-debt (semua dibayar Irma, `pic == paidBy` = self-paid, `pic != paidBy` = debt) + 2 makan Per-Orang. Data riil CSV Zenk — settlement deterministik untuk verifikasi.

> Backend dev dapat seed DB dengan data di atas agar iOS langsung konek dan hitung settlement identik.

## Assets

- Cover foto: user-uploaded (photo picker + storage); tampil sama di kartu Home & header Detail
- Ikon: SF Symbols (prototype pakai inline SVG untuk pin/share/check/copy)
