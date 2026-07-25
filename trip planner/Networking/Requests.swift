//
//  Requests.swift
//  trip planner
//
//  Request payloads for the Kemah REST endpoints. PATCH bodies use optionals so
//  only the provided subset of fields is encoded (partial update semantics).
//

import Foundation

// MARK: - Trips

struct CreateTripRequest: Encodable {
    var name: String
    var location: String
    /// ISO date "YYYY-MM-DD".
    var date: String
    var mapLink: String
    var phone: String
    var docsLink: String
    var coverUrl: String
}

struct UpdateTripRequest: Encodable {
    var name: String?
    var location: String?
    var date: String?
    var mapLink: String?
    var phone: String?
    var docsLink: String?
    var coverUrl: String?
    var budgetTarget: Double?
    var budgetMode: BudgetMode?
    var status: TripStatus?
}

// MARK: - Participants

struct CreateParticipantRequest: Encodable {
    var name: String
}

struct UpdateParticipantRequest: Encodable {
    var picForLabel: String?
    var headcount: Int?
}

// MARK: - Checklist items

struct CreateItemRequest: Encodable {
    var name: String
    var qty: Int
    var pic: String?
    var note: String
    var isPersonal: Bool
}

struct UpdateItemRequest: Encodable {
    var name: String?
    var qty: Int?
    var pic: String?
    var note: String?
    var checked: Bool?
    var isPersonal: Bool?
}

// MARK: - Budget items

struct CreateBudgetItemRequest: Encodable {
    var name: String
    var price: Double
    var paidBy: String?
    var pic: String?
    var splitMode: SplitMode
    /// When true this is a private personal expense; the backend sets `owner`
    /// from the auth token and excludes it from the group total & split bill.
    var isPersonal: Bool = false
}

struct UpdateBudgetItemRequest: Encodable {
    var name: String?
    var price: Double?
    var paidBy: String?
    var pic: String?
    var splitMode: SplitMode?
    var isPersonal: Bool?
}

// MARK: - Invite

struct JoinRequest: Encodable {
    var token: String
}
