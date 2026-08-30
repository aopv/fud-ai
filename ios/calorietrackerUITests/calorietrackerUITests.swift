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
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testSpeechProviderPickerShowsCurrentRegistry() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-selectedSpeechProvider", "Native iOS (On-Device)",
        ]
        app.launch()

        let settings = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8))
        settings.tap()

        let speechSection = app.staticTexts["Speech-to-Text"]
        for _ in 0..<12 where !speechSection.exists {
            app.swipeUp()
        }
        XCTAssertTrue(speechSection.waitForExistence(timeout: 3))

        let providerPicker = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Native iOS")
        ).firstMatch
        for _ in 0..<3 where !providerPicker.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(providerPicker.waitForExistence(timeout: 3))
        providerPicker.tap()

        for provider in [
            "Native iOS (On-Device)",
            "Gemini Audio",
            "OpenAI GPT-Transcribe",
            "Groq (Whisper)",
            "Mistral Voxtral",
            "Deepgram",
            "AssemblyAI",
        ] {
            let providerButton = app.buttons[provider]
            if !providerButton.exists {
                app.swipeUp()
            }
            XCTAssertTrue(providerButton.waitForExistence(timeout: 3), "Missing \(provider)")
        }
    }

    @MainActor
    func testSeparateTextProviderSettingsAreVisibleAndIndependent() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-separateTextProviderEnabled", "YES",
            "-selectedTextAIProvider", "DeepSeek",
            "-selectedTextAIModel", "deepseek-v4-flash",
        ]
        app.launch()

        let settings = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8))
        settings.tap()

        let textProviderSection = app.staticTexts["Text AI"]
        for _ in 0..<10 where !textProviderSection.exists {
            app.swipeUp()
        }
        XCTAssertTrue(textProviderSection.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["AI & Voice"].exists)
        XCTAssertEqual(app.switches["Use Separate Text Provider"].value as? String, "1")
        XCTAssertTrue(app.staticTexts["DeepSeek"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["deepseek-v4-flash"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testAppleIntelligenceAppearsAsTextProvider() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-separateTextProviderEnabled", "YES",
            "-selectedTextAIProvider", "Apple Intelligence (On-Device)",
            "-selectedTextAIModel", "System Language Model",
        ]
        app.launch()

        let settings = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8))
        settings.tap()

        let textProviderSection = app.staticTexts["Text AI"]
        for _ in 0..<10 where !textProviderSection.exists {
            app.swipeUp()
        }
        XCTAssertTrue(textProviderSection.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Apple Intelligence (On-Device)"].waitForExistence(timeout: 3))
        let systemModel = app.staticTexts["System Language Model"]
        for _ in 0..<4 where !systemModel.exists {
            app.swipeUp()
        }
        XCTAssertTrue(systemModel.waitForExistence(timeout: 3))
    }

    @MainActor
    func testWaterTrackingUsesFixedFourthHomePillar() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-waterTrackingEnabled", "YES",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Water"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["View More"].waitForExistence(timeout: 3))
        app.staticTexts["View More"].tap()

        XCTAssertTrue(app.navigationBars["Nutrition Details"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Protein, Carbs, Fat, Water"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.staticTexts["Water stays fixed as the fourth Home pillar while Water Tracking is enabled."]
                .waitForExistence(timeout: 3)
        )

        app.staticTexts["Home Nutrient Cards"].tap()
        XCTAssertTrue(app.navigationBars["Home Nutrients"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Choose 3 Nutrients"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Water"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testWaterLogAppearsInDiaryAndCanBeDeleted() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-waterTrackingEnabled", "YES",
        ]
        app.launch()

        let addButton = app.buttons["home.add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 8))
        addButton.tap()
        XCTAssertTrue(app.buttons["Water"].waitForExistence(timeout: 3))
        app.buttons["Water"].tap()
        XCTAssertTrue(app.buttons["1 Glass (~250 ml)"].waitForExistence(timeout: 3))
        app.buttons["1 Glass (~250 ml)"].tap()

        let waterRows = app.otherElements.matching(identifier: "water.log.row")
        for _ in 0..<8 where waterRows.count == 0 {
            app.swipeUp()
        }
        XCTAssertGreaterThan(waterRows.count, 0)
        let countBeforeDelete = waterRows.count
        waterRows.firstMatch.swipeLeft()
        let deleteButton = app.buttons["Delete"]
        if deleteButton.waitForExistence(timeout: 2) {
            deleteButton.tap()
        }
        XCTAssertEqual(waterRows.count, countBeforeDelete - 1)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
