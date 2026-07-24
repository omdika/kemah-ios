//
//  trip_plannerApp.swift
//  trip planner
//
//  Created by handika on 22/07/26.
//

import SwiftUI
import GoogleSignIn

@main
struct trip_plannerApp: App {
    init() {
        GoogleAuth.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
