---
description: Update the Kemah tech spec (API contract + README) before implementing a new feature
---

## Tujuan
Skill ini dijalankan SEBELUM `/dev`. Output-nya adalah perubahan di `docs/handoff/` yang menjadi kontrak antara iOS client dan FastAPI backend.

## File yang diubah
- `docs/handoff/API_CONTRACT.md` — endpoint baru, perubahan request/response shape, field baru/dihapus
- `docs/handoff/README.md` — logika bisnis, aturan split-bill, deskripsi fitur
- `docs/handoff/CHANGELOG.md` — catat versi baru dan apa yang berubah

## Aturan penulisan spec

### Endpoint baru
Tulis dalam format:
```
## NamaFitur (`METHOD /path/:param`)

**Request body:**
```json
{ "field": "type" }
```

**Response:**
```json
{ "field": "type" }
```

**Rules:**
- Aturan bisnis spesifik
- Siapa yang boleh akses (auth)
- Error cases
```

### Perubahan model
- Field baru: tambahkan dengan `**[vX.Y.Z]**` tag
- Field dihapus: tulis `**[Removed]**` + catatan mengapa
- Field opsional: tandai `?` atau `optional`

### Versi
Format: `vMAJOR.MINOR.PATCH`
- MAJOR: breaking change (hapus field, ubah tipe)
- MINOR: fitur baru (tambah endpoint, tambah field opsional)
- PATCH: bugfix spec (klarifikasi, typo)

## Langkah
1. Pahami fitur yang diminta
2. Tentukan endpoint baru atau perubahan yang diperlukan
3. Tulis perubahan di `API_CONTRACT.md`
4. Update `README.md` jika ada logika bisnis baru
5. Tambah entry di `CHANGELOG.md` dengan versi baru
6. Konfirmasi: "Spec selesai. Siap jalankan `/dev`?"
