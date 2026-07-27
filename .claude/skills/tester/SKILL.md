---
description: Write and run tests for the Kemah iOS trip planner, then verify all pass before pushing
---

## Framework
- **Unit test**: `import Testing` + `@Test` — bukan XCTest
  File: `trip plannerTests/trip_plannerTests.swift`
- **UI test**: `XCUIAutomation` (XCTestCase)
  File: `trip plannerUITests/trip_plannerUITests.swift`
- **Mock**: `MockRepository` (actor, in-memory) adalah satu-satunya test double resmi
  → Jangan mock networking atau URLSession secara langsung
- **Simulator**: iPhone 17 Pro (UDID: `73B7DCD5-A6A0-4A5D-8AE0-FC014EC3B5AD`)

## Yang SELALU harus ditest

### Setiap fitur baru
- Happy path: input valid → output benar
- Error path: input kosong / network error → state error ter-set
- State reset: setelah dismiss sheet, state kembali bersih

### Split-bill (wajib jika ada perubahan kalkulasi)
Cek semua 4 mode split:
```swift
// 1. Per-Orang: proporsional headcount
// 2. Per-PIC pooled (pic nil/blank): flat per participant
// 3. Self-paid (pic == paidBy): EXCLUDED dari settlement
// 4. Direct debt (pic != paidBy): fixed 1:1
```
Cek threshold: balance ±1000 = Lunas, amount ≤500 diabaikan greedy matcher.

### UI test checklist
- Navigasi ke fitur bisa ditemukan (button/tab ada di layar)
- Input menghasilkan perubahan yang terlihat di UI
- Back navigation kembali ke halaman yang benar

## Pola unit test (Testing framework)
```swift
import Testing
@testable import trip_planner

@Test func namaTest() async throws {
    // Arrange
    let mock = MockRepository()
    // Act
    let result = ...
    // Assert
    #expect(result == expectedValue)
}
```

## Pola UI test
```swift
func testNamaFitur() throws {
    let app = XCUIApplication()
    app.launch()
    // tunggu elemen dengan waitForExistence(timeout:)
    // screenshot dengan add(XCTAttachment(screenshot: app.screenshot()))
    // assert dengan XCTAssertTrue / XCTAssertEqual
}
```

## Langkah wajib
1. Tulis unit test untuk logic baru
2. Tulis UI test untuk happy path
3. Jalankan `RunAllTests` (atau `RunSomeTests` untuk subset cepat)
4. Jika ada yang gagal:
   a. Baca error message dengan teliti
   b. Fix di kode produksi atau fix test jika test-nya salah
   c. Jalankan ulang — ulangi sampai semua hijau
5. Konfirmasi: "Semua test hijau. Siap push."

## Setelah semua hijau
```bash
git add <file-yang-diubah>
git commit -m "feat/fix: <deskripsi singkat>"
git push origin main
```

## Yang TIDAK boleh dilakukan
- Jangan skip test dengan `.skip` atau `XCTSkip` tanpa alasan jelas
- Jangan mock `MockRepository` — sudah ada dan dipakai langsung
- Jangan ubah threshold split-bill (±1000 / ≤500) di test — itu ground truth dari spec
- Jangan push jika masih ada test yang gagal
