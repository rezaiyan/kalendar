//
//  KalendarUITests.swift
//  KalendarUITests
//
//  Created by Ali Rezaiyan on 18.08.25.
//

import XCTest

final class KalendarUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launch()
        
        // In UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }
    
    override func tearDownWithError() throws {
        app = nil
        super.tearDown()
    }
    
    // MARK: - App Launch Tests
    @MainActor
    func testAppLaunchAndBasicElements() throws {
        // Test that main elements are present
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Today is'")).element.exists)
        XCTAssertTrue(app.buttons["Add Widget to Home Screen"].exists)
        XCTAssertTrue(app.buttons["GitHub"].exists)
    }
    
    @MainActor
    func testCurrentMonthDisplayed() throws {
        // Check if current month is displayed
        let currentDate = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let expectedMonthYear = formatter.string(from: currentDate)
        
        let monthYearText = app.staticTexts[expectedMonthYear]
        XCTAssertTrue(monthYearText.exists, "Current month and year should be displayed")
    }
    
    @MainActor
    func testWeekdayHeadersPresent() throws {
        // Test that all weekday headers are present
        let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        
        for weekday in weekdays {
            XCTAssertTrue(app.staticTexts[weekday].exists, "\(weekday) header should be present")
        }
    }
    
    // MARK: - Calendar Interaction Tests
    @MainActor
    func testCalendarDaySelection() throws {
        // Find and tap on a calendar day (day 15 if it exists)
        let day15Button = app.buttons["15"]
        if day15Button.exists {
            day15Button.tap()
            
            // Check if selected date info is updated
            let selectedDateText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Selected:'")).element
            XCTAssertTrue(selectedDateText.exists, "Selected date should be displayed")
        }
    }
    
    @MainActor
    func testTodayHighlighting() throws {
        // Get current day
        let currentDay = Calendar.current.component(.day, from: Date())
        let todayButton = app.buttons["\(currentDay)"]
        
        // Today should be highlighted/exist
        XCTAssertTrue(todayButton.exists, "Today's date should be displayed as a button")
    }
    
    @MainActor
    func testCalendarDaysClickable() throws {
        // Test that calendar days are clickable
        let allDayButtons = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]+$"))
        let dayButtonCount = allDayButtons.count
        
        XCTAssertGreaterThan(dayButtonCount, 20, "Should have at least 20+ day buttons")
        
        // Test clicking first available day button
        if dayButtonCount > 0 {
            let firstDayButton = allDayButtons.element(boundBy: 0)
            XCTAssertTrue(firstDayButton.isHittable, "Day buttons should be tappable")
            firstDayButton.tap()
        }
    }
    
    // MARK: - Widget Guide Tests
    @MainActor
    func testWidgetGuideButtonTap() throws {
        let widgetButton = app.buttons["Add Widget to Home Screen"]
        XCTAssertTrue(widgetButton.exists, "Widget guide button should exist")
        
        widgetButton.tap()
        
        // Wait for widget guide to appear
        let widgetGuideTitle = app.staticTexts["Add Calendar Widget"]
        let exists = widgetGuideTitle.waitForExistence(timeout: 3.0)
        XCTAssertTrue(exists, "Widget guide should appear after tapping button")
    }
    
    @MainActor
    func testWidgetGuideNavigation() throws {
        // Open widget guide
        app.buttons["Add Widget to Home Screen"].tap()
        
        // Wait for guide to appear
        let widgetGuideTitle = app.staticTexts["Add Calendar Widget"]
        XCTAssertTrue(widgetGuideTitle.waitForExistence(timeout: 3.0))
        
        // Check if all step elements are present
        XCTAssertTrue(app.staticTexts["How to Add Widget"].exists)
        XCTAssertTrue(app.staticTexts["Long Press Home Screen"].exists)
        XCTAssertTrue(app.staticTexts["Tap the Plus Button"].exists)
        XCTAssertTrue(app.staticTexts["Search for Kalendar"].exists)
        XCTAssertTrue(app.staticTexts["Choose Widget Size"].exists)
        
        // Test widget preview section
        XCTAssertTrue(app.staticTexts["Widget Preview"].exists)
        XCTAssertTrue(app.staticTexts["Medium"].exists)
        XCTAssertTrue(app.staticTexts["Large"].exists)
        
        // Test tips section
        XCTAssertTrue(app.staticTexts["Pro Tips"].exists)
        XCTAssertTrue(app.staticTexts["Auto Updates"].exists)
        XCTAssertTrue(app.staticTexts["Beautiful Design"].exists)
        XCTAssertTrue(app.staticTexts["Multiple Sizes"].exists)
        
        // Close the guide
        app.buttons["Done"].tap()
        
        // Verify we're back to main screen
        XCTAssertTrue(app.buttons["Add Widget to Home Screen"].exists)
    }
    
    // MARK: - GitHub Link Test
    @MainActor
    func testGitHubButtonPresent() throws {
        let githubButton = app.buttons["GitHub"]
        XCTAssertTrue(githubButton.exists, "GitHub button should be present")
        XCTAssertTrue(githubButton.isHittable, "GitHub button should be tappable")
    }
    
    // MARK: - Open Source Footer Tests
    @MainActor
    func testOpenSourceFooter() throws {
        // Check open source project footer elements
        XCTAssertTrue(app.staticTexts["Open Source Project"].exists)
        XCTAssertTrue(app.buttons["GitHub"].exists)
    }
    
    // MARK: - Navigation Tests
    @MainActor
    func testNavigationFlow() throws {
        // Start at main screen
        XCTAssertTrue(app.buttons["Add Widget to Home Screen"].exists)
        
        // Navigate to widget guide
        app.buttons["Add Widget to Home Screen"].tap()
        XCTAssertTrue(app.staticTexts["Add Calendar Widget"].waitForExistence(timeout: 3.0))
        
        // Navigate back
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Add Widget to Home Screen"].exists)
    }
    
    // MARK: - Accessibility Tests
    @MainActor
    func testAccessibilityElements() throws {
        // Test that main elements have accessibility identifiers/labels
        let monthYearText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '2024' OR label CONTAINS '2025'")).element
        XCTAssertTrue(monthYearText.exists)
        
        let todayText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Today is'")).element
        XCTAssertTrue(todayText.exists)
        
        // Test button accessibility
        let widgetButton = app.buttons["Add Widget to Home Screen"]
        XCTAssertTrue(widgetButton.exists)
        XCTAssertTrue(widgetButton.isHittable)
    }
    
    // MARK: - Layout Tests
    @MainActor
    func testIPadLayout() throws {
        // Test that layout adapts to different screen sizes
        // This test will behave differently on iPad vs iPhone
        
        let calendar = app.otherElements.containing(.staticText, identifier: "Mon").element
        XCTAssertTrue(calendar.exists, "Calendar grid should be present")
        
        // Check that weekday headers are horizontally arranged
        let monHeader = app.staticTexts["Mon"]
        let tueHeader = app.staticTexts["Tue"]
        
        if monHeader.exists && tueHeader.exists {
            let monFrame = monHeader.frame
            let tueFrame = tueHeader.frame
            
            // Tuesday should be to the right of Monday
            XCTAssertLessThan(monFrame.maxX, tueFrame.minX + 50, "Weekday headers should be horizontally arranged")
        }
    }
    
    // MARK: - State Persistence Tests
    @MainActor
    func testSelectedDatePersistence() throws {
        // Select a date
        let day10Button = app.buttons["10"]
        if day10Button.exists {
            day10Button.tap()
            
            // Check that selection is reflected in UI
            let selectedText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Selected:'")).element
            XCTAssertTrue(selectedText.exists)
            
            // Open and close widget guide to test state persistence
            app.buttons["Add Widget to Home Screen"].tap()
            XCTAssertTrue(app.staticTexts["Add Calendar Widget"].waitForExistence(timeout: 3.0))
            app.buttons["Done"].tap()
            
            // Check that selection is still there
            XCTAssertTrue(selectedText.exists)
        }
    }
    
    // MARK: - Performance Tests
    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    
    @MainActor
    func testScrollPerformance() throws {
        // Test widget guide scrolling performance
        app.buttons["Add Widget to Home Screen"].tap()
        XCTAssertTrue(app.staticTexts["Add Calendar Widget"].waitForExistence(timeout: 3.0))
        
        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric]) {
            let scrollView = app.scrollViews.firstMatch
            if scrollView.exists {
                scrollView.swipeUp()
                scrollView.swipeDown()
            }
        }
        
        app.buttons["Done"].tap()
    }
    
    // MARK: - Error Handling Tests
    @MainActor
    func testErrorStates() throws {
        // Test that app handles edge cases gracefully
        
        // Test rapid tapping doesn't cause crashes
        let widgetButton = app.buttons["Add Widget to Home Screen"]
        for _ in 0..<5 {
            if widgetButton.exists {
                widgetButton.tap()
                if app.buttons["Done"].waitForExistence(timeout: 1.0) {
                    app.buttons["Done"].tap()
                }
            }
        }
        
        // Verify app is still responsive
        XCTAssertTrue(app.buttons["Add Widget to Home Screen"].exists)
    }
    
    // MARK: - Widget Guide Content Tests
    @MainActor
    func testWidgetGuideContentCompleteness() throws {
        app.buttons["Add Widget to Home Screen"].tap()
        XCTAssertTrue(app.staticTexts["Add Calendar Widget"].waitForExistence(timeout: 3.0))
        
        // Test all steps are present with correct numbering
        for stepNumber in 1...4 {
            let stepNumberText = app.staticTexts["\(stepNumber)"]
            XCTAssertTrue(stepNumberText.exists, "Step \(stepNumber) should be present")
        }
        
        // Test step content
        let stepTitles = [
            "Long Press Home Screen",
            "Tap the Plus Button", 
            "Search for Kalendar",
            "Choose Widget Size"
        ]
        
        for title in stepTitles {
            XCTAssertTrue(app.staticTexts[title].exists, "\(title) should be present")
        }
        
        app.buttons["Done"].tap()
    }
}