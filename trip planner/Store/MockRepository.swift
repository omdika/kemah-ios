//
//  MockRepository.swift
//  trip planner
//
//  In-memory data source seeded from the prototype's `initialTrips()`, adapted
//  to be API_CONTRACT-valid (every budget item has an explicit `paidBy`). Lets
//  the app run end-to-end in the simulator without the FastAPI backend.
//

import Foundation

actor MockRepository: KemahRepository {
    private var currentUser = User(id: "u_irma", name: "Irma", email: "irma@example.com", avatarUrl: nil)
    private var store: [Trip]

    init() {
        store = MockRepository.seed()
    }

    // MARK: Users

    func me() async throws -> User { currentUser }

    // MARK: Trips

    func trips() async throws -> [TripSummary] {
        store.map { trip in
            let items = visibleItems(trip.items)
            let checked = items.filter(\.checked).count
            return TripSummary(
                id: trip.id, name: trip.name, location: trip.location, date: trip.date,
                coverUrl: trip.coverUrl,
                coverUploadedByName: trip.coverUploadedByName, coverUploadedAt: trip.coverUploadedAt,
                mapLink: trip.mapLink, phone: trip.phone, docsLink: trip.docsLink,
                status: trip.status, budgetTarget: trip.budgetTarget, budgetMode: trip.budgetMode,
                participantCount: trip.participants.count,
                checklistProgress: ChecklistProgress(checked: checked, total: items.count)
            )
        }
    }

    func trip(id: String) async throws -> Trip {
        guard let t = store.first(where: { $0.id == id }) else { throw APIError.invalidResponse }
        return visible(t)
    }

    func createTrip(_ body: CreateTripRequest) async throws -> Trip {
        let creator = Participant(id: "p_\(UUID().uuidString.prefix(8))", name: currentUser.name, picForLabel: "Koordinator", headcount: 1)
        let trip = Trip(
            id: "t_\(UUID().uuidString.prefix(8))",
            name: body.name, location: body.location, date: body.date,
            coverUrl: body.coverUrl.isEmpty ? nil : body.coverUrl,
            mapLink: body.mapLink.isEmpty ? nil : body.mapLink,
            phone: body.phone.isEmpty ? nil : body.phone,
            docsLink: body.docsLink.isEmpty ? nil : body.docsLink,
            status: .upcoming, budgetTarget: 0, budgetMode: .auto,
            participants: [creator], items: [], budgetItems: []
        )
        store.insert(trip, at: 0)
        return trip
    }

    func updateTrip(id: String, _ body: UpdateTripRequest) async throws -> Trip {
        try mutate(id) { t in
            if let v = body.name { t.name = v }
            if let v = body.location { t.location = v }
            if let v = body.date { t.date = v }
            if let v = body.mapLink { t.mapLink = v.isEmpty ? nil : v }
            if let v = body.phone { t.phone = v.isEmpty ? nil : v }
            if let v = body.docsLink { t.docsLink = v.isEmpty ? nil : v }
            if let v = body.coverUrl { t.coverUrl = v.isEmpty ? nil : v }
            if let v = body.budgetTarget { t.budgetTarget = v }
            if let v = body.budgetMode { t.budgetMode = v }
            if let v = body.status { t.status = v }
        }
    }

    func deleteTrip(id: String) async throws {
        store.removeAll { $0.id == id }
    }

    // MARK: Participants

    func addParticipant(tripId: String, name: String) async throws -> Participant {
        let p = Participant(id: "p_\(UUID().uuidString.prefix(8))", name: name, picForLabel: "Peserta", headcount: 1)
        _ = try mutate(tripId) { $0.participants.append(p) }
        return p
    }

    func updateParticipant(tripId: String, participantId: String, _ body: UpdateParticipantRequest) async throws -> Participant {
        let t = try mutate(tripId) { trip in
            guard let i = trip.participants.firstIndex(where: { $0.id == participantId }) else { return }
            if let v = body.picForLabel { trip.participants[i].picForLabel = v }
            if let v = body.headcount { trip.participants[i].headcount = max(v, 1) }
        }
        guard let p = t.participants.first(where: { $0.id == participantId }) else { throw APIError.invalidResponse }
        return p
    }

    func deleteParticipant(tripId: String, participantId: String) async throws {
        _ = try mutate(tripId) { $0.participants.removeAll { $0.id == participantId } }
    }

    // MARK: Checklist items

    func addItem(tripId: String, _ body: CreateItemRequest) async throws -> ChecklistItem {
        let item = ChecklistItem(
            id: "i_\(UUID().uuidString.prefix(8))", name: body.name, qty: body.qty,
            pic: body.pic, note: body.note, checked: false, isPersonal: body.isPersonal,
            owner: body.isPersonal ? currentUser.name : nil
        )
        _ = try mutate(tripId) { $0.items.append(item) }
        return item
    }

    func updateItem(tripId: String, itemId: String, _ body: UpdateItemRequest) async throws -> ChecklistItem {
        let t = try mutate(tripId) { trip in
            guard let i = trip.items.firstIndex(where: { $0.id == itemId }) else { return }
            if let v = body.name { trip.items[i].name = v }
            if let v = body.qty { trip.items[i].qty = v }
            if let v = body.pic { trip.items[i].pic = v }
            if let v = body.note { trip.items[i].note = v }
            if let v = body.checked { trip.items[i].checked = v }
            if let v = body.isPersonal {
                trip.items[i].isPersonal = v
                trip.items[i].owner = v ? (trip.items[i].owner ?? currentUser.name) : nil
            }
        }
        guard let item = t.items.first(where: { $0.id == itemId }) else { throw APIError.invalidResponse }
        return item
    }

    func deleteItem(tripId: String, itemId: String) async throws {
        _ = try mutate(tripId) { $0.items.removeAll { $0.id == itemId } }
    }

    // MARK: Budget items

    func addBudgetItem(tripId: String, _ body: CreateBudgetItemRequest) async throws -> BudgetItem {
        let item = BudgetItem(
            id: "b_\(UUID().uuidString.prefix(8))", name: body.name, price: body.price,
            paidBy: body.paidBy, pic: body.pic, splitMode: body.splitMode,
            isPersonal: body.isPersonal, owner: body.isPersonal ? currentUser.name : nil
        )
        _ = try mutate(tripId) { $0.budgetItems.append(item) }
        return item
    }

    func updateBudgetItem(tripId: String, budgetItemId: String, _ body: UpdateBudgetItemRequest) async throws -> BudgetItem {
        let t = try mutate(tripId) { trip in
            guard let i = trip.budgetItems.firstIndex(where: { $0.id == budgetItemId }) else { return }
            if let v = body.name { trip.budgetItems[i].name = v }
            if let v = body.price { trip.budgetItems[i].price = v }
            if let v = body.paidBy { trip.budgetItems[i].paidBy = v }
            if let v = body.pic { trip.budgetItems[i].pic = v.isEmpty ? nil : v }
            if let v = body.splitMode { trip.budgetItems[i].splitMode = v }
            // Invariant: per-orang items never carry a pic (direct-debt semantics require .pic mode).
            if trip.budgetItems[i].splitMode == .orang { trip.budgetItems[i].pic = nil }
            if let v = body.isPersonal {
                trip.budgetItems[i].isPersonal = v
                trip.budgetItems[i].owner = v ? (trip.budgetItems[i].owner ?? currentUser.name) : nil
            }
        }
        guard let item = t.budgetItems.first(where: { $0.id == budgetItemId }) else { throw APIError.invalidResponse }
        return item
    }

    func deleteBudgetItem(tripId: String, budgetItemId: String) async throws {
        _ = try mutate(tripId) { $0.budgetItems.removeAll { $0.id == budgetItemId } }
    }

    // MARK: Invite

    func inviteLink(tripId: String) async throws -> InviteLink {
        InviteLink(url: "https://kemah.app/join/\(tripId)?token=demo\(tripId)")
    }

    func joinTrip(tripId: String, token: String) async throws -> String {
        tripId
    }

    func previewInvite(tripId: String, token: String) async throws -> TripPreview {
        guard let trip = store.first(where: { $0.id == tripId }) else {
            throw APIError.http(status: 404, body: "Trip not found")
        }
        let items = visibleItems(trip.items)
        let checked = items.filter(\.checked).count
        return TripPreview(
            id: trip.id, name: trip.name, location: trip.location, date: trip.date,
            coverUrl: trip.coverUrl,
            participants: trip.participants.map { ParticipantPreview(name: $0.name, picForLabel: $0.picForLabel) },
            checklistProgress: ChecklistProgress(checked: checked, total: items.count)
        )
    }

    // MARK: Split Bill

    func splitBill(tripId: String) async throws -> SplitBillResponse {
        let trip = try await self.trip(id: tripId)
        let result = SplitBillCalculator.compute(participants: trip.participants, budgetItems: trip.budgetItems)
        return SplitBillResponse(
            equalShareLabel: result.equalShareLabel,
            participantCount: result.participantCount,
            perPerson: result.perPerson.map { row in
                SplitBillPerPerson(
                    name: row.name,
                    contribution: row.contribution,
                    share: row.share,
                    balance: row.balance,
                    headcount: row.headcount,
                    poolDetails: row.poolDetails.map {
                        SplitBillPoolDetail(name: $0.name, share: $0.share, paid: $0.paid, budgetItemId: $0.budgetItemId)
                    }
                )
            },
            transfers: result.transfers.map { t in
                SplitBillTransfer(
                    from: t.from,
                    to: t.to,
                    total: t.total,
                    parts: t.parts.map {
                        SplitBillTransferPart(label: $0.label, amount: $0.amount, budgetItemId: $0.budgetItemId)
                    }
                )
            }
        )
    }

    // MARK: Images

    func uploadTripCover(tripId: String, fileData: Data, fileName: String, mimeType: String) async throws -> Trip {
        let t = try mutate(tripId) { trip in
            trip.coverUrl = "mock://cover/\(UUID().uuidString)"
            trip.coverUploadedByName = currentUser.name
            trip.coverUploadedAt = ISO8601DateFormatter().string(from: Date())
        }
        return visible(t)
    }

    func uploadItemImage(tripId: String, itemId: String, fileData: Data, fileName: String, mimeType: String) async throws -> TripImage {
        let image = TripImage(
            id: "img_\(UUID().uuidString.prefix(8))", url: "mock://image/\(UUID().uuidString)",
            uploadedBy: currentUser.id, uploadedByName: currentUser.name,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        _ = try mutate(tripId) { trip in
            guard let i = trip.items.firstIndex(where: { $0.id == itemId }) else { return }
            trip.items[i].images.append(image)
        }
        return image
    }

    func deleteItemImage(tripId: String, itemId: String, imageId: String) async throws {
        _ = try mutate(tripId) { trip in
            guard let i = trip.items.firstIndex(where: { $0.id == itemId }) else { return }
            trip.items[i].images.removeAll { $0.id == imageId }
        }
    }

    func uploadBudgetItemImage(tripId: String, budgetItemId: String, fileData: Data, fileName: String, mimeType: String) async throws -> TripImage {
        let image = TripImage(
            id: "img_\(UUID().uuidString.prefix(8))", url: "mock://image/\(UUID().uuidString)",
            uploadedBy: currentUser.id, uploadedByName: currentUser.name,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        _ = try mutate(tripId) { trip in
            guard let i = trip.budgetItems.firstIndex(where: { $0.id == budgetItemId }) else { return }
            trip.budgetItems[i].images.append(image)
        }
        return image
    }

    func deleteBudgetItemImage(tripId: String, budgetItemId: String, imageId: String) async throws {
        _ = try mutate(tripId) { trip in
            guard let i = trip.budgetItems.firstIndex(where: { $0.id == budgetItemId }) else { return }
            trip.budgetItems[i].images.removeAll { $0.id == imageId }
        }
    }

    // MARK: Helpers

    @discardableResult
    private func mutate(_ id: String, _ change: (inout Trip) -> Void) throws -> Trip {
        guard let idx = store.firstIndex(where: { $0.id == id }) else { throw APIError.invalidResponse }
        change(&store[idx])
        return store[idx]
    }

    /// Mimics the backend's per-user filtering: personal checklist items and
    /// personal expenses are only visible to their owner (the current user).
    private func visibleItems(_ items: [ChecklistItem]) -> [ChecklistItem] {
        items.filter { !$0.isPersonal || $0.owner == currentUser.name }
    }

    private func visibleBudget(_ items: [BudgetItem]) -> [BudgetItem] {
        items.filter { !$0.isPersonal || $0.owner == currentUser.name }
    }

    private func visible(_ trip: Trip) -> Trip {
        var t = trip
        t.items = visibleItems(trip.items)
        t.budgetItems = visibleBudget(trip.budgetItems)
        return t
    }

    // MARK: Seed

    private static func seed() -> [Trip] {
        func p(_ name: String, _ role: String, _ head: Int) -> Participant {
            Participant(id: "p_\(name.lowercased())", name: name, picForLabel: role, headcount: head)
        }
        func item(_ id: String, _ name: String, _ qty: Int, _ pic: String, _ note: String, _ checked: Bool, _ personal: Bool = false, owner: String? = nil) -> ChecklistItem {
            ChecklistItem(id: id, name: name, qty: qty, pic: personal ? nil : pic, note: note, checked: checked, isPersonal: personal, owner: personal ? owner : nil)
        }
        func budget(_ id: String, _ name: String, _ price: Double, paidBy: String, pic: String?, _ mode: SplitMode, personal: Bool = false, owner: String? = nil) -> BudgetItem {
            BudgetItem(id: id, name: name, price: price, paidBy: paidBy, pic: pic, splitMode: mode, isPersonal: personal, owner: personal ? owner : nil)
        }

        let t1 = Trip(
            id: "t1", name: "Camping Gunung Papandayan", location: "Garut, Jawa Barat", date: "2026-08-01",
            coverUrl: nil, mapLink: "https://maps.google.com/?q=Gunung+Papandayan", phone: "081234567890",
            status: .upcoming, budgetTarget: 1_200_000, budgetMode: .manual,
            participants: [
                p("Irma", "Koordinator", 3),
                p("Yuki", "PIC Tenda", 4),
                p("Pepi", "PIC Memasak", 4),
                p("Ria", "PIC Tiket & Logistik", 3),
            ],
            items: [
                item("i1", "Tenda dome 4 orang", 1, "Yuki", "cek patok & pasak lengkap", true),
                item("i2", "Matras alas tenda", 4, "Pepi", "", false),
                item("i3", "Flysheet / terpal", 1, "Yuki", "pinjam punya Doni", false),
                item("i4", "Palu & pasak cadangan", 1, "Yuki", "", false),
                item("i5", "Kompor portable + gas", 1, "Pepi", "", true),
                item("i6", "Nesting alat masak", 1, "Pepi", "udah punya", true),
                item("i7", "Bahan makanan 3 hari", 1, "Ria", "", false),
                item("i8", "Air minum galon", 2, "Pepi", "", false),
                item("i9", "Tiket masuk kawasan", 4, "Ria", "beli online H-3", true),
                item("i10", "Tiket parkir kendaraan", 1, "Yuki", "", false),
                item("i11", "Retribusi camp ground", 1, "Ria", "", false),
                // Personal items — private to their owner. Irma's show for Irma;
                // Yuki's are hidden from everyone but Yuki.
                item("i12", "Baju ganti & jaket hangat", 3, "", "sesuaikan cuaca", false, true, owner: "Irma"),
                item("i13", "Alat mandi pribadi", 1, "", "", false, true, owner: "Irma"),
                item("i14", "Obat pribadi", 1, "", "jangan lupa obat alergi", false, true, owner: "Irma"),
                item("i15", "Kamera & tripod", 1, "", "punya Yuki", false, true, owner: "Yuki"),
            ],
            budgetItems: [
                // Direct-debt example: Irma fronted Yuki's tent → Yuki owes Irma in full.
                budget("b1", "Tenda dome 4 orang", 150_000, paidBy: "Irma", pic: "Yuki", .pic),
                // Pooled Per-PIC (flat per participant): car rental fronted by Irma.
                budget("b2", "Sewa mobil", 200_000, paidBy: "Irma", pic: nil, .pic),
                // Per-Orang (pooled, proportional to headcount).
                budget("b3", "Kompor portable + gas", 85_000, paidBy: "Pepi", pic: nil, .orang),
                budget("b4", "Bahan makanan 3 hari", 250_000, paidBy: "Ria", pic: nil, .orang),
                budget("b5", "Air minum galon", 30_000, paidBy: "Pepi", pic: nil, .orang),
                budget("b6", "Tiket masuk kawasan", 320_000, paidBy: "Ria", pic: nil, .orang),
                budget("b7", "Tiket parkir kendaraan", 20_000, paidBy: "Yuki", pic: nil, .orang),
                budget("b8", "Retribusi camp ground", 50_000, paidBy: "Ria", pic: nil, .orang),
                budget("b9", "Bensin & tol", 100_000, paidBy: "Yuki", pic: nil, .orang),
                // Personal expenses — private, not split. Irma's show for Irma;
                // Yuki's are hidden from Irma.
                budget("bp1", "Jajan & kopi", 45_000, paidBy: "Irma", pic: nil, .orang, personal: true, owner: "Irma"),
                budget("bp2", "Oleh-oleh keluarga", 120_000, paidBy: "Irma", pic: nil, .orang, personal: true, owner: "Irma"),
                budget("bp3", "Sewa kamera", 90_000, paidBy: "Yuki", pic: nil, .orang, personal: true, owner: "Yuki"),
            ]
        )

        // Real trip data — Zenk group, Malang 19-21 Jun 2026 (from expense CSV).
        // Pengeluaran Bersama → .pic (flat per KK, 4 participants, headcount ignored).
        // HTM tickets → direct-debt .pic per person (Irma paid for all; each person owes
        //   their exact amount). Irma's own tickets use pic==paidBy (pooled per-PIC).
        // Soto & Ayam → .orang (per headcount approximation of per-portion split).
        let t2 = Trip(
            id: "t2", name: "Trip Zenk: Malang", location: "Malang, Jawa Timur", date: "2026-06-19",
            coverUrl: nil, mapLink: "https://maps.google.com/?q=Malang+Jawa+Timur", phone: nil,
            status: .selesai, budgetTarget: 9_653_877, budgetMode: .auto,
            participants: [
                p("Irma", "Koordinator", 3),
                p("Yuki", "PIC Dokumentasi", 4),
                p("Devi", "PIC Konsumsi", 4),
                p("Ria", "PIC Tiket & Logistik", 3),
            ],
            items: [
                item("j1", "Tiket Jatim Park 3", 14, "Ria", "beli online H-3", true),
                item("j2", "Tiket Museum Angkut", 14, "Ria", "", true),
                item("j3", "Tiket Taman Safari Prigen", 14, "Ria", "", true),
                item("j4", "Tiket Wisata Kebun Apel", 14, "Ria", "", true),
                item("j5", "Villa", 1, "Devi", "3 malam", true),
                item("j6", "Bekal & bahan masak", 1, "Ria", "", true),
                item("j7", "Snack & minuman", 1, "Yuki", "", true),
            ],
            budgetItems: [
                // ── Pengeluaran Bersama (flat per KK → Per PIC) ──────────────────
                budget("m1",  "Villa",              1_000_000, paidBy: "Devi", pic: nil, .pic),
                budget("m2",  "Bekal",                288_500, paidBy: "Ria",  pic: nil, .pic),
                budget("m3",  "Snack",                137_500, paidBy: "Yuki", pic: nil, .pic),
                budget("m4",  "Perkap bento & masak",  97_500, paidBy: "Yuki", pic: nil, .pic),
                budget("m5",  "Snack klethikan",        91_000, paidBy: "Yuki", pic: nil, .pic),
                budget("m6",  "Makan sopir",           136_000, paidBy: "Ria",  pic: nil, .pic),
                budget("m7",  "Parkir",                 95_000, paidBy: "Ria",  pic: nil, .pic),
                budget("m8",  "Aqua & rokok",           82_000, paidBy: "Ria",  pic: nil, .pic),
                budget("m9",  "Beras",                  36_000, paidBy: "Irma", pic: nil, .pic),
                budget("m10", "Telur",                  50_000, paidBy: "Devi", pic: nil, .pic),
                budget("m11", "Snack (Devi)",           30_000, paidBy: "Devi", pic: nil, .pic),
                budget("m12", "Parkir soto",            10_000, paidBy: "Devi", pic: nil, .pic),
                budget("m13", "Parkir apel",            15_000, paidBy: "Devi", pic: nil, .pic),
                budget("m14", "Parkir bebek",            5_000, paidBy: "Devi", pic: nil, .pic),
                // ── Wisata Kebun Apel (flat per KK → Per PIC) ───────────────────
                budget("m15", "Wisata Kebun Apel",     325_000, paidBy: "Ria",  pic: nil, .pic),
                // ── Jatim Park 3 — per orang (direct debt, Irma bayar semua) ────
                budget("m16a", "Jatim Park 3 – Devi",  673_143, paidBy: "Irma", pic: "Devi",  .pic),
                budget("m16b", "Jatim Park 3 – Ria",   504_857, paidBy: "Irma", pic: "Ria",   .pic),
                budget("m16c", "Jatim Park 3 – Irma",  504_857, paidBy: "Irma", pic: "Irma",  .pic),
                budget("m16d", "Jatim Park 3 – Yuki",  673_143, paidBy: "Irma", pic: "Yuki",  .pic),
                // ── Museum Angkut — per orang (direct debt, Irma bayar semua) ───
                budget("m17a", "Museum Angkut – Devi",  440_000, paidBy: "Irma", pic: "Devi",  .pic),
                budget("m17b", "Museum Angkut – Ria",   330_000, paidBy: "Irma", pic: "Ria",   .pic),
                budget("m17c", "Museum Angkut – Irma",  330_000, paidBy: "Irma", pic: "Irma",  .pic),
                budget("m17d", "Museum Angkut – Yuki",  440_000, paidBy: "Irma", pic: "Yuki",  .pic),
                // ── Taman Safari Prigen — per orang (direct debt, Irma bayar semua)
                budget("m18a", "Safari Prigen – Devi",  822_842, paidBy: "Irma", pic: "Devi",  .pic),
                budget("m18b", "Safari Prigen – Ria",   617_132, paidBy: "Irma", pic: "Ria",   .pic),
                budget("m18c", "Safari Prigen – Irma",  617_132, paidBy: "Irma", pic: "Irma",  .pic),
                budget("m18d", "Safari Prigen – Yuki",  766_272, paidBy: "Irma", pic: "Yuki",  .pic),
                // ── Makan (per headcount approximation) ─────────────────────────
                budget("m20", "Ayam Rocket",           264_000, paidBy: "Irma", pic: nil, .orang),
                budget("m21", "Soto",                  272_000, paidBy: "Ria",  pic: nil, .orang),
            ]
        )

        return [t1, t2]
    }
}
