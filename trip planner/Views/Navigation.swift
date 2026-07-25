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
/// TripStore until sign-in completes or the join call resolves. Identifiable
/// so ContentView can drive the guest-preview fullScreenCover off it directly.
struct PendingInvite: Equatable, Identifiable {
    var id: String { tripId + token }
    let tripId: String
    let token: String
}
