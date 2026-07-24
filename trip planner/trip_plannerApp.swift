//
//  trip_plannerApp.swift
//  trip planner
//
//  Created by handika on 22/07/26.
//

import SwiftUI

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
