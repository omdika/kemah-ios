---
description: Implement the latest spec changes from docs/handoff/ — frontend only, backend only, or both
---

## Cara panggil
- `/dev` — kerjakan frontend (iOS) dan backend sekaligus
- `/dev frontend` — hanya iOS Swift (model, networking, store, UI)
- `/dev backend` — hanya panduan perubahan FastAPI (endpoint, schema, migration)

## Langkah pertama: baca latest changes

Selalu mulai dengan membaca **CHANGELOG.md** untuk menemukan versi terbaru:
```
docs/handoff/CHANGELOG.md
```
Cari entry `## [X.Y.Z]` paling atas — itu adalah spec yang harus diimplementasikan.

Jika entry ditulis oleh `/pm`, ia punya blok terstruktur — gunakan langsung:
- **`#### Frontend (iOS Swift)`** → daftar file dan perubahan yang harus dikerjakan (untuk `/dev frontend`)
- **`#### Backend (FastAPI)`** → endpoint, schema, migration (untuk `/dev backend`)
- **`#### Auth rules`** → siapa boleh/tidak boleh, gunakan untuk validasi di MockRepository dan di instruksi backend

Lalu baca detail lengkap di:
- `docs/handoff/API_CONTRACT.md` — contoh JSON request/response
- `docs/handoff/README.md` — logika bisnis dan aturan

Jangan implementasi fitur yang tidak ada di latest changelog entry.

---

## Mode: FRONTEND (iOS Swift)

Berlaku untuk `/dev` dan `/dev frontend`.

### Aturan iOS 16
- DILARANG: `@Observable`, `@Bindable`, `@Environment(Type.self)`, `.onChange` 2-parameter
- GUNAKAN: `ObservableObject` + `@Published` + `@EnvironmentObject`
- Swift async/await untuk networking — tidak ada Combine di view baru

### Urutan implementasi (ikuti layer ini)
```
1. Models/Models.swift          ← struct baru / field baru, Codable
2. Networking/Requests.swift    ← create/update payload structs
3. Networking/APIClient.swift   ← async func baru + Authorization header
4. Store/Repository.swift       ← tambah ke protocol KemahRepository
5. Store/MockRepository.swift   ← implementasi mock (in-memory, seeded)
6. Store/TripStore.swift        ← @Published state + async action methods
7. Views/                       ← SwiftUI views
```

### Aturan file baru
- **Wajib gunakan `XcodeWrite`** bukan `Write` — agar file masuk Xcode target dan ikut build

### Aturan kode
- Copy/UI: Bahasa Indonesia
- Tidak ada force unwrap (`!`) baru
- Tidak ada comment yang menjelaskan WHAT — hanya WHY jika non-obvious
- Tidak ada fitur tambahan di luar scope latest changelog

### Split-bill (sangat kritis)
Ubah HANYA jika changelog menyebutkan perubahan split-bill.
Ground truth: `README.md` bagian "Split Bill Logic".

### Setiap file selesai
Jalankan `XcodeRefreshCodeIssuesInFile` → fix error → lanjut file berikutnya.
Di akhir semua file: jalankan `BuildProject` → harus sukses sebelum report selesai.

---

## Mode: BACKEND (FastAPI)

Berlaku untuk `/dev` dan `/dev backend`.

Karena backend (FastAPI di Google Cloud) tidak ada di repo ini, output mode backend adalah
**instruksi tertulis** yang bisa langsung dikerjakan developer backend atau Claude di repo backend.

Format output:

### 1. Database migration
```sql
-- Tulis ALTER TABLE / CREATE TABLE yang diperlukan
ALTER TABLE trips ADD COLUMN docs_link TEXT DEFAULT NULL;
```

### 2. Pydantic schema
```python
# Request body baru / perubahan field
class TripCreate(BaseModel):
    ...
    docs_link: str | None = None
```

### 3. Endpoint baru atau perubahan
```python
# Method, path, logic
@router.post("/trips")
async def create_trip(...):
    ...
```

### 4. Rules bisnis
- Filter/validasi apa yang harus diterapkan
- Siapa yang boleh akses (auth check)
- Error response yang diharapkan

### 5. Checklist deploy
- [ ] Migration dijalankan sebelum deploy
- [ ] Environment variable baru (jika ada)
- [ ] `gcloud run deploy` setelah test lokal

---

## Report akhir

Setelah selesai, tulis ringkasan:
```
Versi diimplementasikan: [X.Y.Z]
Mode: frontend / backend / keduanya

Frontend:
- File diubah: ...
- Build: sukses

Backend:
- Migration: ...
- Endpoint baru/berubah: ...
```
