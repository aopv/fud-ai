//
//  calorietrackerUITests.swift
//  calorietrackerUITests
//
//  Created by Apoorv Darshan on 05/02/26.
//

import XCTest

final class calorietrackerUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-appearanceMode", "light"
        ]
        app.launch()

        let calorieSummary = app.descendants(matching: .any)["neo.home.calorieSummary"]
        XCTAssertTrue(calorieSummary.waitForExistence(timeout: 8))
        XCTAssertTrue(app.otherElements["neo.home.nutrientGrid"].exists)
        XCTAssertTrue(app.buttons["Choose date"].exists)

        for tab in ["Home", "Progress", "Coach", "Settings", "Workouts"] {
            XCTAssertTrue(app.tabBars.buttons[tab].exists, "Missing preserved \(tab) tab")
        }

        let addFood = app.buttons["neo.home.addFood"]
        XCTAssertTrue(addFood.exists)
        addFood.tap()

        XCTAssertTrue(app.buttons["Photo & Scan"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Describe Meal"].exists)
        XCTAssertTrue(app.buttons["Reuse Meal"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
