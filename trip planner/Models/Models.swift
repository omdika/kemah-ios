//
//  Models.swift
//  trip planner
//
//  Domain models for Kemah. Shapes match API_CONTRACT.md exactly so they can be
//  decoded from / encoded to the FastAPI backend without an adapter layer.
//

import Foundation

// MARK: - Enums

enum TripStatus: String, Codable, Hashable {
    case upcoming
    case selesai
}

enum BudgetMode: String, Codable, Hashable {
    case manual
    case auto
}

enum SplitMode: String, Codable, Hashable {
    case orang
    case pic
}

// MARK: - User

struct User: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var email: String
    var avatarUrl: String?
}

// MARK: - Trip (list summary — GET /trips)

struct ChecklistProgress: Codable, Hashable {
    var checked: Int
    var total: Int
}

struct TripSummary: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var location: String
    /// ISO date string, e.g. "2026-08-01".
    var date: String
    var coverUrl: String?
    /// Attribution for `coverUrl`; nil until someone uploads a cover photo.
    var coverUploadedByName: String? = nil
    var coverUploadedAt: String? = nil
    var mapLink: String?
    var phone: String?
    var status: TripStatus
    var budgetTarget: Double
    var budgetMode: BudgetMode
    var participantCount: Int
    var checklistProgress: ChecklistProgress
}

// MARK: - Trip (full detail — GET /trips/:id)

struct Trip: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var location: String
    var date: String
    var coverUrl: String?
    var coverUploadedByName: String? = nil
    var coverUploadedAt: String? = nil
    var mapLink: String?
    var phone: String?
    var status: TripStatus
    var budgetTarget: Double
    var budgetMode: BudgetMode
    var participants: [Participant]
    var items: [ChecklistItem]
    var budgetItems: [BudgetItem]
}

// MARK: - Photo uploads

/// One uploaded photo, attributed to whoever added it.
struct TripImage: Codable, Identifiable, Hashable {
    let id: String
    var url: String
    var uploadedBy: String
    var uploadedByName: String
    var createdAt: String
}

struct Participant: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var picForLabel: String
    var headcount: Int
}

struct ChecklistItem: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var qty: Int
    var pic: String?
    var note: String
    var checked: Bool
    var isPersonal: Bool
    /// Owner of a personal item (server-set from the auth token). Personal items
    /// are only returned to their owner; nil for shared/group items.
    var owner: String?
    var images: [TripImage] = []

    init(id: String, name: String, qty: Int, pic: String?, note: String, checked: Bool,
         isPersonal: Bool, owner: String?, images: [TripImage] = []) {
        self.id = id
        self.name = name
        self.qty = qty
        self.pic = pic
        self.note = note
        self.checked = checked
        self.isPersonal = isPersonal
        self.owner = owner
        self.images = images
    }

    enum CodingKeys: String, CodingKey {
        case id, name, qty, pic, note, checked, isPersonal, owner, images
    }

    // Defensive decode: `images` defaults to [] when the backend omits it
    // (e.g. a not-yet-upgraded server, pre-v1.5.0).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        qty = try c.decode(Int.self, forKey: .qty)
        pic = try c.decodeIfPresent(String.self, forKey: .pic)
        note = try c.decode(String.self, forKey: .note)
        checked = try c.decode(Bool.self, forKey: .checked)
        isPersonal = try c.decodeIfPresent(Bool.self, forKey: .isPersonal) ?? false
        owner = try c.decodeIfPresent(String.self, forKey: .owner)
        images = try c.decodeIfPresent([TripImage].self, forKey: .images) ?? []
    }
}

struct BudgetItem: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var price: Double
    var paidBy: String?
    var pic: String?
    var splitMode: SplitMode
    /// Personal expenses are private to their `owner` and excluded from the
    /// group budget total and the split-bill settlement.
    var isPersonal: Bool
    /// Owner of a personal expense (server-set). nil for group expenses.
    var owner: String?
    var images: [TripImage] = []

    init(id: String, name: String, price: Double, paidBy: String?, pic: String?,
         splitMode: SplitMode, isPersonal: Bool = false, owner: String? = nil, images: [TripImage] = []) {
        self.id = id
        self.name = name
        self.price = price
        self.paidBy = paidBy
        self.pic = pic
        self.splitMode = splitMode
        self.isPersonal = isPersonal
        self.owner = owner
        self.images = images
    }

    enum CodingKeys: String, CodingKey {
        case id, name, price, paidBy, pic, splitMode, isPersonal, owner, images
    }

    // Defensive decode: `isPersonal` defaults to false when the backend omits it.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        price = try c.decode(Double.self, forKey: .price)
        paidBy = try c.decodeIfPresent(String.self, forKey: .paidBy)
        pic = try c.decodeIfPresent(String.self, forKey: .pic)
        splitMode = try c.decode(SplitMode.self, forKey: .splitMode)
        isPersonal = try c.decodeIfPresent(Bool.self, forKey: .isPersonal) ?? false
        owner = try c.decodeIfPresent(String.self, forKey: .owner)
        images = try c.decodeIfPresent([TripImage].self, forKey: .images) ?? []
    }
}

// MARK: - Split Bill (server response shape — GET /trips/:id/split-bill)

struct SplitBillResponse: Codable, Hashable {
    var equalShareLabel: String
    var participantCount: Int
    var perPerson: [SplitBillPerPerson]
    var transfers: [SplitBillTransfer]
}

struct SplitBillPerPerson: Codable, Hashable {
    var name: String
    /// Amount this person actually fronted for pool items (renamed from `paid` in v1.3.0).
    var contribution: Double
    var share: Double
    var balance: Double
    var headcount: Int
    var poolDetails: [SplitBillPoolDetail]
}

/// Per-item pool attribution for one participant (Level B transparency).
struct SplitBillPoolDetail: Codable, Hashable {
    var name: String
    /// This person's fair portion of the item.
    var share: Double
    /// Full item price if this person was the payer, else 0.
    var paid: Double
    /// Source `BudgetItem.id` — lets the UI look up `trip.budgetItems[].images`.
    var budgetItemId: String?
}

struct SplitBillTransfer: Codable, Hashable {
    var from: String
    var to: String
    /// Merged total for this (from, to) pair (renamed from `amount` in v1.3.0).
    var total: Double
    var parts: [SplitBillTransferPart]
}

struct SplitBillTransferPart: Codable, Hashable {
    var label: String
    var amount: Double
    /// Source `BudgetItem.id`; nil for merged "Bagi rata" parts (no single item applies).
    var budgetItemId: String?
}

// MARK: - Invite

struct InviteLink: Codable, Hashable {
    var url: String
}

/// Guest-safe subset of Trip (GET /trips/:id/invite/preview) — no budget/money
/// data, no personal items, no per-item checklist detail. Reachable with just
/// a valid invite token, no sign-in required.
struct TripPreview: Codable, Hashable {
    var id: String
    var name: String
    var location: String
    var date: String
    var coverUrl: String?
    var participants: [ParticipantPreview]
    var checklistProgress: ChecklistProgress
}

struct ParticipantPreview: Codable, Hashable, Identifiable {
    var id: String { name }
    var name: String
    var picForLabel: String
}

// MARK: - Upload

struct UploadResult: Codable, Hashable {
    var url: String
}
