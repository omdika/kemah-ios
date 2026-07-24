//
//  trip_plannerApp.swift
//  trip planner
//
//  Created by handika on 22/07/26.
//

import SwiftUI

// Re-enable swipe-back when the navigation bar is hidden (e.g. TripDetailView).
// SwiftUI's NavigationStack wraps UINavigationController; hiding the bar also
// disables interactivePopGestureRecognizer by default — this restores it.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}

@main
struct trip_plannerApp: App {
    init() {
        GoogleAuth.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
