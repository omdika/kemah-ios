---
description: Write and run tests for Kemah iOS — latest-change unit tests, or regression tests against real API
---

## Cara panggil
- `/tester` — jalankan keduanya: latest-change test + regression test
- `/tester latest` — hanya test fitur dari latest changelog entry (unit + UI mock)
- `/tester regression` — hanya regression test terhadap real API (butuh backend hidup)

---

## Langkah pertama: baca latest changes

Selalu mulai dengan membaca CHANGELOG.md:
```
docs/handoff/CHANGELOG.md
```
Temukan entry `## [X.Y.Z]` paling atas — itu scope fitur yang harus dicakup test.
Baca detail endpoint dan rules di `API_CONTRACT.md` dan `README.md`.

---

## Mode 1: LATEST-CHANGE TEST (`/tester` atau `/tester latest`)

Test difokuskan pada fitur yang baru diimplementasikan sesuai latest changelog.
Gunakan `MockRepository` — tidak butuh backend hidup.

### Framework
- **Unit test**: `import Testing` + `@Test` di `trip plannerTests/trip_plannerTests.swift`
- **UI test**: `XCUIAutomation` (XCTestCase) di `trip plannerUITests/trip_plannerUITests.swift`
- **Mock**: `MockRepository` (actor, in-memory) — test double resmi, tidak perlu mock lain

### Checklist test per fitur baru

**Model / field baru:**
- [ ] Field bisa di-encode dan decode dari JSON dengan benar
- [ ] Nilai default/nil ditangani dengan benar
- [ ] Field opsional tidak merusak decode response lama (backward compat)

**Logika bisnis baru:**
- [ ] Happy path: input valid → output benar
- [ ] Edge case: nilai kosong / nil / nol
- [ ] Error path: input invalid → error state ter-set, bukan crash

**Split-bill (jika ada perubahan):**
```
Wajib cover semua 4 mode:
□ Per-Orang: share proporsional headcount
□ Per-PIC pooled (pic nil): flat per participant count
□ Self-paid (pic == paidBy): EXCLUDED dari settlement
□ Direct debt (pic != paidBy): fixed 1:1, tidak di-pool
Threshold: balance ±1000 = Lunas, amount ≤500 diabaikan greedy
```

**UI (XCUITest):**
- [ ] Elemen baru bisa ditemukan di layar (waitForExistence)
- [ ] Tap / input menghasilkan perubahan yang terlihat
- [ ] Navigation forward dan back berfungsi

### Pola unit test
```swift
import Testing
@testable import trip_planner

@Test("Nama test yang deskriptif") func namaTest() async throws {
    // Arrange
    let mock = await MockRepository()
    // Act
    let result = ...
    // Assert
    #expect(result == expectedValue)
}
```

### Langkah
1. Tulis unit test untuk setiap item di checklist di atas
2. Tulis UI test happy path untuk fitur baru
3. Jalankan `RunSomeTests` — pilih test yang baru ditulis
4. Jika gagal: fix kode produksi atau fix test, jalankan ulang
5. Semua hijau → lanjut ke mode regression (jika `/tester`)

---

## Mode 2: REGRESSION TEST (`/tester` atau `/tester regression`)

Test terhadap **real API** untuk memastikan perubahan tidak merusak fitur yang sudah ada.
Backend harus hidup dan accessible sebelum mode ini dijalankan.

### Persiapan
Cek `AppConfig.swift` untuk base URL backend. Pastikan:
- `useMock = false` di `TripStore` atau environment yang dipakai
- Token auth tersedia (user sudah login di simulator)
- Simulator: iPhone 17 Pro (UDID: `73B7DCD5-A6A0-4A5D-8AE0-FC014EC3B5AD`)

### Cakupan regression (selalu dijalankan, bukan hanya fitur baru)

| Area | Yang dicek |
|---|---|
| Trip list | `GET /trips` — response decode tanpa error, list muncul di UI |
| Trip detail | `GET /trips/:id` — semua field tampil, cover image load |
| Checklist | Tambah item → muncul di list; centang → status tersimpan |
| Budget | Tambah expense → total terupdate; foto upload → thumbnail muncul |
| Split bill | `GET /trips/:id/split-bill` — response decode, transfer list tampil |
| Peserta | Daftar peserta tampil, avatar stack benar |
| Cover image | Upload → preview update di header dan list card |

### Pola UI test untuk real API
```swift
func testRegressionNamaFitur() throws {
    let app = XCUIApplication()
    app.launchEnvironment["USE_MOCK"] = "false"  // jika ada flag
    app.launch()

    // Tunggu lebih lama karena network
    let tripCard = app.buttons.matching(...).firstMatch
    XCTAssertTrue(tripCard.waitForExistence(timeout: 15))

    // Screenshot di setiap step penting
    add(XCTAttachment(screenshot: app.screenshot()))
}
```

### Langkah
1. Pastikan backend hidup (cek URL di `AppConfig.swift`)
2. Jalankan `RunAllTests` — tangkap semua error
3. Untuk setiap test yang gagal:
   a. Tentukan: bug di iOS atau bug di backend?
   b. iOS bug → fix Swift code → rerun
   c. Backend bug → catat sebagai temuan, jangan fix di iOS
4. Report: semua area regression yang passed / failed

---

## Report akhir

```
Versi ditest: [X.Y.Z]
Mode: latest / regression / keduanya

Latest-change test:
  Unit test: X passed, Y failed
  UI test: X passed, Y failed
  Fitur tercakup: [daftar]

Regression test:
  Trip list: PASS / FAIL
  Trip detail: PASS / FAIL
  Checklist: PASS / FAIL
  Budget: PASS / FAIL
  Split bill: PASS / FAIL
  Peserta: PASS / FAIL
  Cover image: PASS / FAIL

Backend bugs ditemukan: [daftar jika ada]
Siap push: YA / TIDAK
```

## Aturan keras
- Tidak push jika ada test latest-change yang gagal
- Regression failure di backend bukan alasan block push iOS — catat saja
- Jangan skip test dengan `.skip` atau `XCTSkip` tanpa komentar alasan
- Jangan ubah threshold split-bill di test — itu ground truth dari spec
