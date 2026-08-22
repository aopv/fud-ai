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

        for tab in ["home", "progress", "coach", "settings", "workouts"] {
            let destination = app.buttons["nav.\(tab)"]
            XCTAssertTrue(destination.exists, "Missing bottom-bar \(tab) destination")
            destination.tap()
            XCTAssertTrue(destination.isSelected, "Bottom bar did not select \(tab)")
        }
        let quickAdd = app.buttons["nav.quickAdd"]
        XCTAssertTrue(quickAdd.exists, "Missing bottom-bar quick action")
        XCTAssertTrue(quickAdd.isHittable, "Bottom-bar quick action is obstructed")

        app.buttons["nav.coach"].tap()
        let coachInput = app.textFields.firstMatch
        XCTAssertTrue(coachInput.waitForExistence(timeout: 3))
        XCTAssertTrue(coachInput.isHittable, "Coach composer is obstructed by bottom navigation")

        app.buttons["nav.home"].tap()
        XCTAssertTrue(calorieSummary.waitForExistence(timeout: 3))

        let addFood = app.buttons["neo.home.addFood"]
        XCTAssertTrue(addFood.exists)
        addFood.tap()

        let addFoodPanel = app.descendants(matching: .any)["neo.glassChoice.addFood"]
        XCTAssertTrue(addFoodPanel.waitForExistence(timeout: 3))

        let photoAndScan = app.buttons["neo.glassChoice.addFood.photoScan"]
        XCTAssertTrue(photoAndScan.exists)
        XCTAssertTrue(app.buttons["neo.glassChoice.addFood.describe"].exists)
        XCTAssertTrue(app.buttons["neo.glassChoice.addFood.reuse"].exists)

        photoAndScan.tap()
        XCTAssertTrue(app.buttons["neo.glassChoice.addFood.camera"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["neo.glassChoice.addFood.photos"].exists)
        XCTAssertTrue(app.buttons["neo.glassChoice.addFood.barcode"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
