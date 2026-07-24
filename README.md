# Kemah — iOS App

Aplikasi perencanaan camping trip kelompok. Packing checklist, budget tracking dengan split-bill settlement, manajemen peserta, dan undang teman.

## Tech Stack

- **SwiftUI** — iOS 16.0+
- **Swift Concurrency** — async/await untuk semua data flow
- **No third-party dependencies** — murni native iOS

## Features

- **Checklist** — dua seksi (Kelompok dengan PIC / Pribadi tanpa PIC), progress bar, item pribadi yang hanya terlihat owner
- **Budget** — pengeluaran kelompok + pengeluaran pribadi (private, tidak masuk split bill), mode otomatis/manual target
- **Split Bill** — settlement engine client-side:
  - Per Orang: proporsional berdasarkan `headcount`
  - Pooled Per-PIC (`pic` kosong): flat per peserta
  - Self-paid (`pic == paidBy`): dikecualikan dari settlement
  - Direct debt (`pic != paidBy`): utang 1:1
  - Greedy debt simplification, merge transfer per pasangan (from, to)
  - Level B transparency: breakdown per-item di setiap transfer
- **Peserta** — manajemen peserta, role, headcount, undang via link
- **Dark mode** — adaptive colors via UIKit semantic colors

## Architecture

```
Models/         — Trip, Participant, ChecklistItem, BudgetItem, split-bill DTOs
Networking/     — APIClient (async/await REST, Bearer token), Requests (PATCH payloads)
Store/          — KemahRepository protocol → APIRepository + MockRepository (actor)
SplitBill/      — SplitBillCalculator (port dari prototype JS), Formatters
Theme/          — Design tokens, adaptive dark/light colors, CardBackground modifier
Views/          — SwiftUI screens & sheets
```

`MockRepository` adalah default — app langsung berjalan di simulator tanpa backend. Ganti ke `APIRepository` di `TripStore` saat backend siap.

## Menjalankan

1. Buka `trip planner.xcodeproj` di Xcode 15+
2. Pilih target simulator atau device
3. Build & Run — tidak perlu konfigurasi tambahan (MockRepository aktif by default)

## Handoff Docs

Spesifikasi lengkap ada di [`docs/handoff/`](docs/handoff/):

| File | Isi |
|---|---|
| `README.md` | Spec UI, split bill logic, design tokens |
| `API_CONTRACT.md` | REST endpoints, request/response shapes |
| `CHANGELOG.md` | Riwayat perubahan spec per versi |
| `versions/` | Snapshot per versi |

Versi spec saat ini: **v1.3.0**

## Seed Data

Mock session default: user **Irma** (`u_irma`). Dua trip tersedia:
- **Camping Gunung Papandayan** — upcoming, 4 peserta, checklist + budget mix
- **Trip Zenk: Malang** — selesai, data riil dari CSV (Jun 2026), settlement dengan tiket HTM sebagai direct debt

Detail seed ada di `docs/handoff/README.md` bagian "Seed Data".
