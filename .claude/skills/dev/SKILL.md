---
description: Implement a feature for the Kemah iOS trip planner end-to-end (model → networking → store → UI)
---

## Konteks proyek
- App: Kemah — group camping trip planner, SwiftUI, **iOS 16.0 minimum**
- Source root: `trip planner/trip planner/`
- Spec otoritatif: `docs/handoff/API_CONTRACT.md` dan `docs/handoff/README.md`
  → **Baca ini dulu** sebelum mengubah model, networking, atau split-bill logic
- Backend: plain REST + `Authorization: Bearer <idToken>` — tidak ada Firebase/Supabase SDK
- Default: `MockRepository` (offline, in-memory) — app bisa jalan tanpa backend

## Aturan iOS 16
- DILARANG: `@Observable`, `@Bindable`, `@Environment(Type.self)`, `.onChange(of:initial:_:)` (2-param)
- GUNAKAN: `ObservableObject` + `@Published` + `@EnvironmentObject`
- Combine hanya untuk `TripStore` (sudah ada) — jangan tambahkan di view baru
- Swift async/await untuk semua networking dan store methods

## Arsitektur (ikuti urutan ini)
```
Models/Models.swift          ← struct, Codable, field = API_CONTRACT.md
Networking/APIClient.swift   ← async func + Authorization header
Networking/Requests.swift    ← create/update payload structs
Store/Repository.swift       ← tambah ke protocol KemahRepository
Store/APIRepository.swift    ← implementasi real (panggil APIClient)
Store/MockRepository.swift   ← implementasi mock (in-memory, seeded)
Store/TripStore.swift        ← @Published state + async action methods
Views/                       ← SwiftUI views, @EnvironmentObject store
```

## Aturan kode
- File baru: **wajib gunakan `XcodeWrite`** bukan `Write` — agar masuk Xcode target
- Copy/UI: Bahasa Indonesia ("Tambah", "Simpan", "Batalkan", "Berhasil")
- Tidak ada `force unwrap` (`!`) kecuali sudah ada di kode lama
- Tidak ada comment yang menjelaskan WHAT — hanya WHY jika non-obvious
- Tidak ada fitur tambahan di luar scope yang diminta

## Split-bill (handle dengan sangat hati-hati)
Ubah HANYA jika spec berubah. Selalu cek `README.md` "Split Bill Logic" dan
`reference/Kemah Travel App.dc.html` sebagai ground truth. Test setiap perubahan.

## Langkah wajib setiap implementasi
1. Baca spec: `docs/handoff/API_CONTRACT.md` bagian yang relevan
2. Implementasi layer demi layer (Model → Network → Store → UI)
3. Setelah setiap file: jalankan `XcodeRefreshCodeIssuesInFile`
4. Setelah semua selesai: jalankan `BuildProject`
5. Jika build gagal: fix semua error, build ulang sampai sukses
6. Report: daftar file yang diubah + ringkasan perubahan

## Jangan lupa
- `MockRepository` harus selalu punya data mock yang masuk akal untuk fitur baru
- Setiap endpoint baru di `APIClient` harus ada pasangannya di `KemahRepository` protocol
- State loading/error harus ditangani di `TripStore` (`@Published var isLoading`, `settlementError`, dll)
