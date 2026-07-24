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
