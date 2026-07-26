//
//  trip_plannerUITests.swift
//  trip plannerUITests
//

import XCTest

final class trip_plannerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func snap(_ name: String, app: XCUIApplication) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
    }

    @MainActor
    func testNavigateToSplitBill() throws {
        let app = XCUIApplication()
        app.launch()

        // Wait for home screen to fully load
        sleep(5)
        snap("01_home_screen", app: app)

        // In SwiftUI card lists the trip cards show up as buttons.
        // Try several strategies to tap the first trip card.
        var navigated = false

        // Strategy 1: find a button whose label contains the trip name
        let tripButton = app.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] 'Papandayan' OR label CONTAINS[c] 'Zenk' OR label CONTAINS[c] 'Camping'"
        )).firstMatch
        if tripButton.waitForExistence(timeout: 5) {
            tripButton.tap()
            navigated = true
        }

        // Strategy 2: find by static text and use its coordinate to tap the card
        if !navigated {
            let txt = app.staticTexts.matching(NSPredicate(
                format: "label CONTAINS[c] 'Papandayan' OR label CONTAINS[c] 'Zenk' OR label CONTAINS[c] 'Camping'"
            )).firstMatch
            if txt.waitForExistence(timeout: 5) {
                txt.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                navigated = true
            }
        }

        sleep(4)
        snap("02_after_tap_trip", app: app)

        // Check if we're in TripDetail (back button or nav title should appear)
        let backBtn = app.buttons.matching(NSPredicate(
            format: "label == 'Back' OR label CONTAINS[c] 'chevron'"
        )).firstMatch

        if !backBtn.waitForExistence(timeout: 6) {
            snap("03_navigation_failed", app: app)
            XCTFail("Failed to navigate into a trip")
            return
        }

        snap("04_trip_detail", app: app)

        // Tap Budget tab
        let budgetTab = app.buttons["Budget"]
        XCTAssertTrue(budgetTab.waitForExistence(timeout: 8), "Budget tab not found")
        budgetTab.tap()
        sleep(2)
        snap("05_budget_tab", app: app)

        // Tap Split Bill bar at the bottom
        let splitBtn = app.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] 'Split'"
        )).firstMatch
        XCTAssertTrue(splitBtn.waitForExistence(timeout: 8), "Split Bill button not found")
        splitBtn.tap()

        // Wait for API response or loading to complete
        sleep(8)
        snap("06_split_bill_result", app: app)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
