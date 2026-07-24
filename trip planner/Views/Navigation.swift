//
//  Navigation.swift
//  trip planner
//
//  Navigation routes pushed onto the app's NavigationStack.
//

import Foundation

enum Route: Hashable {
    case trip(String)
    case splitBill
}

/// A parsed `kemah://join/...` (or future Universal Link) invite, held by
/// TripStore until sign-in completes or the join call resolves.
struct PendingInvite: Equatable {
    let tripId: String
    let token: String
}
