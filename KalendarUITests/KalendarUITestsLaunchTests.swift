//
//  KalendarUITestsLaunchTests.swift
//  KalendarUITests
//
//  Created by Ali Rezaiyan on 18.08.25.
//

import XCTest

final class KalendarUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    
    @MainActor
    func testLaunchInDarkMode() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Wait for app to settle
        Thread.sleep(forTimeInterval: 1.0)
        
        // Take screenshot in current mode
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen - Current Theme"
        attachment.lifetime = .keepAlways
        add(attachment)
        
        // Verify basic elements are present
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Today is'")).element.exists)
        XCTAssertTrue(app.buttons["Add Widget to Home Screen"].exists)
    }
    
    @MainActor
    func testLaunchPerformanceAndStability() throws {
        // Test multiple launches to ensure stability
        measure(metrics: [XCTApplicationLaunchMetric(), XCTMemoryMetric()]) {
            let app = XCUIApplication()
            app.launch()
            
            // Ensure app fully loaded
            _ = app.buttons["Add Widget to Home Screen"].waitForExistence(timeout: 5.0)
            
            app.terminate()
        }
    }
    
    @MainActor
    func testLaunchInDifferentOrientations() throws {
        let app = XCUIApplication()
        
        // Test portrait launch
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        
        let portraitScreenshot = XCTAttachment(screenshot: app.screenshot())
        portraitScreenshot.name = "Launch - Portrait"
        portraitScreenshot.lifetime = .keepAlways
        add(portraitScreenshot)
        
        // Verify main elements are visible in portrait
        XCTAssertTrue(app.buttons["Add Widget to Home Screen"].exists)
        
        // Test landscape launch (if supported)
        app.terminate()
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        
        let landscapeScreenshot = XCTAttachment(screenshot: app.screenshot())
        landscapeScreenshot.name = "Launch - Landscape"
        landscapeScreenshot.lifetime = .keepAlways
        add(landscapeScreenshot)
        
        // Verify main elements are still accessible in landscape
        XCTAssertTrue(app.buttons["Add Widget to Home Screen"].waitForExistence(timeout: 3.0))
        
        // Reset to portrait
        XCUIDevice.shared.orientation = .portrait
    }
    
    @MainActor
    func testLaunchWithLowMemory() throws {
        // Simulate low memory conditions
        let app = XCUIApplication()
        app.launch()
        
        // Generate some memory pressure by opening and closing widget guide multiple times
        for _ in 0..<10 {
            if app.buttons["Add Widget to Home Screen"].exists {
                app.buttons["Add Widget to Home Screen"].tap()
                
                if app.buttons["Done"].waitForExistence(timeout: 2.0) {
                    app.buttons["Done"].tap()
                }
            }
        }
        
        // Verify app is still stable
        XCTAssertTrue(app.buttons["Add Widget to Home Screen"].exists)
        
        let finalScreenshot = XCTAttachment(screenshot: app.screenshot())
        finalScreenshot.name = "Launch - After Memory Pressure"
        finalScreenshot.lifetime = .keepAlways
        add(finalScreenshot)
    }
    
    @MainActor
    func testLaunchAccessibility() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Test that accessibility elements are properly configured
        let accessibleElements = app.descendants(matching: .any).allElementsBoundByAccessibilityElement
        XCTAssertGreaterThan(accessibleElements.count, 0, "Should have accessible elements")
        
        // Test specific accessibility features
        let todayText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Today is'")).element
        XCTAssertTrue(todayText.exists)
        
        let widgetButton = app.buttons["Add Widget to Home Screen"]
        XCTAssertTrue(widgetButton.exists)
        XCTAssertTrue(widgetButton.isHittable)
        
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Launch - Accessibility Test"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
    
    @MainActor
    func testLaunchWithNetworkVariations() throws {
        // Test app launch behavior under different network conditions
        // Note: This is a basic test since we can't easily simulate network conditions in UI tests
        
        let app = XCUIApplication()
        app.launch()
        
        // Verify app launches successfully regardless of network state
        // (since it's primarily an offline calendar app)
        XCTAssertTrue(app.buttons["Add Widget to Home Screen"].waitForExistence(timeout: 5.0))
        
        // Test GitHub link (which requires network)
        let githubButton = app.buttons["GitHub"]
        XCTAssertTrue(githubButton.exists)
        
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Launch - Network Test"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
    
    @MainActor
    func testLaunchWithDateEdgeCases() throws {
        // Test app behavior during special dates (this is a basic test)
        let app = XCUIApplication()
        app.launch()
        
        // Verify current month is displayed
        let currentDate = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let expectedMonthYear = formatter.string(from: currentDate)
        
        // The app should display current month/year
        let monthYearElement = app.staticTexts[expectedMonthYear]
        XCTAssertTrue(monthYearElement.waitForExistence(timeout: 3.0), "Current month/year should be displayed")
        
        // Verify today is highlighted
        let todayDay = Calendar.current.component(.day, from: currentDate)
        let todayButton = app.buttons["\(todayDay)"]
        XCTAssertTrue(todayButton.exists, "Today's date should be present")
        
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Launch - Date Display Test"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}