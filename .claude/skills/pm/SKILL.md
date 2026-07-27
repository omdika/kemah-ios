---
description: Project manager — terima deskripsi fitur, tulis tech spec terstruktur di handoff docs, siapkan untuk dev dan tester
---

## Cara panggil
- `/pm <deskripsi fitur>` — langsung tulis spec berdasarkan deskripsi
- `/pm` — interaktif: tanya pengguna dulu sebelum tulis spec

---

## Tujuan

Skill ini dijalankan **SEBELUM** `/dev` dan `/tester`.

Output-nya adalah perubahan di `docs/handoff/` dengan format terstruktur sehingga:
- `/dev frontend` tahu persis file Swift apa yang perlu diubah
- `/dev backend` tahu persis endpoint, schema, dan migration yang perlu dibuat
- `/tester latest` tahu persis skenario apa yang harus diuji (tidak perlu derive sendiri)

---

## Langkah

### 1. Baca state spec saat ini

Baca dulu file berikut sebelum apapun:
```
docs/handoff/CHANGELOG.md   ← ambil versi terbaru untuk increment
docs/handoff/README.md      ← pahami fitur yang sudah ada
docs/handoff/API_CONTRACT.md ← pahami endpoint yang sudah ada
```

### 2. Klarifikasi (jika perlu)

Tanya pengguna jika ada ambiguitas:
- Siapa yang bisa akses? (semua peserta / owner saja / pemilik item)
- Apakah ada data yang dihapus permanen (hard delete) atau disembunyikan (soft delete)?
- Apakah mengubah field yang sudah ada → ini MAJOR version
- Apakah fitur baru tanpa breaking → MINOR version
- Apakah hanya klarifikasi → PATCH version

Jika deskripsi sudah cukup jelas, langsung ke langkah 3 tanpa tanya.

### 3. Tentukan versi baru

Baca versi terakhir di CHANGELOG.md → increment:
- `MAJOR` jika hapus field, ubah tipe, atau ubah nama field yang sudah ada
- `MINOR` jika tambah endpoint baru, tambah field opsional, atau fitur baru non-breaking
- `PATCH` jika hanya klarifikasi spec atau perbaikan typo

### 4. Rancang spec dengan 5 blok wajib

Setiap feature yang ditambahkan ke CHANGELOG **harus** punya 5 blok ini:

```
#### Frontend (iOS Swift)
Daftar perubahan spesifik per file:
- `Models/Models.swift`: struct/field apa yang berubah
- `Networking/APIClient.swift`: fungsi baru apa
- `Store/Repository.swift`: protocol method baru
- `Store/MockRepository.swift`: implementasi mock
- `Store/TripStore.swift`: action + computed property baru
- `Views/NamaView.swift`: UI baru (tombol, sheet, alert)

#### Backend (FastAPI)
Instruksi spesifik:
- Migration SQL yang harus dijalankan
- Pydantic schema baru/berubah
- Endpoint baru: METHOD /path — behavior
- Filter/query logic

#### Auth rules
Siapa boleh dan tidak boleh (dengan HTTP status):
- Boleh: [peran/kondisi]
- Tidak boleh: [peran/kondisi] → HTTP [4xx] dengan alasan

#### Test scenarios (untuk /tester)
Daftar skenario konkret:
- Happy path: [kondisi input] → [output yang diharapkan]
- Edge case: [kondisi boundary] → [behavior]
- Error path: [input invalid / unauthorized] → [error yang diharapkan]

#### Migration checklist (backend)
```sql
-- SQL yang harus dijalankan sebelum deploy
ALTER TABLE ... ADD COLUMN ...;
```
- [ ] Migration dijalankan sebelum deploy
- [ ] Field baru diisi untuk data lama (UPDATE jika perlu)
```

### 5. Tulis ke handoff docs

Update **3 file** ini:

**`docs/handoff/CHANGELOG.md`**
- Tambahkan entry baru di paling atas
- Format: `## [X.Y.Z] — YYYY-MM-DD`
- Isi semua 5 blok wajib

**`docs/handoff/API_CONTRACT.md`**
- Tambahkan endpoint baru dengan contoh request/response JSON
- Tandai field baru dengan `[vX.Y.Z]`
- Tandai field yang dihapus dengan `[Removed in vX.Y.Z]`

**`docs/handoff/README.md`**
- Tambahkan ke section yang relevan (State Management, Split Bill Logic, dll)
- Tulis logika bisnis baru jika ada aturan yang kompleks

### 6. Konfirmasi ke pengguna

Setelah selesai, tampilkan ringkasan:

```
Spec v[X.Y.Z] selesai.

Perubahan:
- CHANGELOG.md: entry [X.Y.Z] ditambahkan
- API_CONTRACT.md: [N endpoint berubah / field baru]
- README.md: [section yang diupdate]

Langkah selanjutnya:
- /dev frontend  → implementasi iOS
- /dev backend   → instruksi FastAPI
- /dev           → keduanya sekaligus
```

---

## Format CHANGELOG entry (template lengkap)

```markdown
## [X.Y.Z] — YYYY-MM-DD

### Added / Changed / Removed

**Judul fitur yang deskriptif**
Satu kalimat penjelasan tujuan fitur ini.

#### Frontend (iOS Swift)
- `Models/Models.swift`: tambah `fieldBaru: Tipe? = nil` ke struct `NamaStruct`
- `Networking/APIClient.swift`: tambah `func namaFungsi(param: Tipe) async throws -> ReturnType`
- `Store/Repository.swift`: tambah `func namaFungsi(...) async throws` ke protocol `KemahRepository`
- `Store/MockRepository.swift`: implementasi mock `namaFungsi` — behavior in-memory
- `Store/TripStore.swift`: action `func namaAction() async`, computed `var isNama: Bool`
- `Views/NamaView.swift`: [deskripsi UI yang ditambahkan — tombol, sheet, alert, dll]

#### Backend (FastAPI)
- `POST /trips/:tripId/nama` — [deskripsi endpoint]
  - Request: `{ "field": "type" }`
  - Response: `{ "field": "type" }`
- Migration: lihat Migration checklist di bawah
- Pydantic: tambah `field_baru: str | None = None` ke `TripResponse`

#### Auth rules
- Boleh: semua peserta yang authenticated
- Tidak boleh: pengguna yang bukan peserta trip → 403 Forbidden
- Tidak boleh: [kondisi lain] → [HTTP status] — [alasan]

#### Test scenarios
- **Happy path**: [user valid] memanggil [aksi] → [hasil: data tersimpan / response 200]
- **Edge case**: [kondisi nil/kosong] → [default behavior]
- **Error — unauthorized**: [user yang tidak boleh] → [HTTP 403 + pesan error]
- **Error — not found**: [resource tidak ada] → [HTTP 404]
- **Cascade**: [aksi trigger cascade] → [data terkait ikut terhapus/berubah]

#### Migration checklist (backend)
```sql
ALTER TABLE nama_tabel ADD COLUMN field_baru TEXT DEFAULT NULL;
-- Isi untuk data lama jika perlu:
UPDATE nama_tabel SET field_baru = '...' WHERE field_baru IS NULL;
```
- [ ] Migration dijalankan di production sebelum deploy versi baru
- [ ] Data lama diisi dengan nilai default yang masuk akal
```

---

## Aturan keras

- **Selalu isi 5 blok** (Frontend / Backend / Auth rules / Test scenarios / Migration checklist) — tidak boleh ada blok yang dilewati
- **Jangan duplikasi** field atau endpoint yang sudah ada — cek README dan API_CONTRACT dulu
- **Test scenarios harus konkret** — bukan "test bahwa fitur berfungsi", tapi kondisi spesifik + expected output
- **Auth rules harus eksplisit** — setiap endpoint punya "siapa boleh" dan "siapa tidak boleh + HTTP code"
- **Konfirmasi sebelum `/dev`** — jangan langsung implement, beri pengguna kesempatan review spec dulu
- **Tanggal CHANGELOG** — selalu gunakan tanggal hari ini (YYYY-MM-DD)
