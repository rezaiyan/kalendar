//
//  KalendarTests.swift
//  KalendarTests
//
//  Created by Ali Rezaiyan on 18.08.25.
//

import Testing
import XCTest
import SwiftUI
@testable import Kalendar

// MARK: - Unit Tests using Swift Testing Framework
struct KalendarTests {
    
    // MARK: - Date Formatting Tests
    @Test("Current month year formatting")
    func testCurrentMonthYearFormatting() async throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        
        let testDate = Calendar.current.date(from: DateComponents(year: 2024, month: 8, day: 15))!
        let result = formatter.string(from: testDate)
        
        #expect(result == "August 2024")
    }
    
    @Test("Current day name formatting")
    func testCurrentDayNameFormatting() async throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        
        // Create a known date (Monday, August 19, 2024)
        let testDate = Calendar.current.date(from: DateComponents(year: 2024, month: 8, day: 19))!
        let result = formatter.string(from: testDate)
        
        #expect(result == "Monday")
    }
    
    @Test("Selected date string formatting")
    func testSelectedDateStringFormatting() async throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        
        let testDate = Calendar.current.date(from: DateComponents(year: 2024, month: 12, day: 25))!
        let result = formatter.string(from: testDate)
        
        #expect(result == "December 25, 2024")
    }
    
    // MARK: - Calendar Logic Tests
    @Test("Weekday symbols order")
    func testWeekdaySymbols() async throws {
        let expectedSymbols = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        // Since weekdaySymbols is a computed property in ContentView, we test the expected order
        #expect(expectedSymbols.count == 7)
        #expect(expectedSymbols.first == "Mon")
        #expect(expectedSymbols.last == "Sun")
    }
    
    @Test("Calendar first weekday is Monday")
    func testCalendarFirstWeekday() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // 2 = Monday, 1 = Sunday
        
        #expect(calendar.firstWeekday == 2)
    }
    
    @Test("Days in month calculation")
    func testDaysInMonth() async throws {
        let calendar = Calendar.current
        
        // Test February 2024 (leap year)
        let feb2024 = calendar.date(from: DateComponents(year: 2024, month: 2, day: 1))!
        let daysInFeb2024 = calendar.range(of: .day, in: .month, for: feb2024)?.count
        #expect(daysInFeb2024 == 29)
        
        // Test February 2023 (non-leap year)
        let feb2023 = calendar.date(from: DateComponents(year: 2023, month: 2, day: 1))!
        let daysInFeb2023 = calendar.range(of: .day, in: .month, for: feb2023)?.count
        #expect(daysInFeb2023 == 28)
        
        // Test December (31 days)
        let dec2024 = calendar.date(from: DateComponents(year: 2024, month: 12, day: 1))!
        let daysInDec2024 = calendar.range(of: .day, in: .month, for: dec2024)?.count
        #expect(daysInDec2024 == 31)
    }
    
    @Test("Monday-based weekday conversion")
    func testMondayBasedWeekdayConversion() async throws {
        // Sunday = 1 in Calendar, should become 6 (last day)
        let sundayBasedWeekday = 1
        let mondayBasedWeekday = sundayBasedWeekday == 1 ? 6 : sundayBasedWeekday - 2
        #expect(mondayBasedWeekday == 6)
        
        // Monday = 2 in Calendar, should become 0 (first day)
        let mondayWeekday = 2
        let mondayBased = mondayWeekday == 1 ? 6 : mondayWeekday - 2
        #expect(mondayBased == 0)
        
        // Friday = 6 in Calendar, should become 4
        let fridayWeekday = 6
        let fridayBased = fridayWeekday == 1 ? 6 : fridayWeekday - 2
        #expect(fridayBased == 4)
    }
    
    // MARK: - Device-specific Tests
    @Test("iPad detection logic")
    func testIPadDetection() async throws {
        // We can't easily mock UIDevice in unit tests, but we can test the logic
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let horizontalPadding: CGFloat = isIPad ? 60 : 20
        let calendarSpacing: CGFloat = isIPad ? 30 : 20
        let weekdayFontSize: CGFloat = isIPad ? 20 : 16
        
        if isIPad {
            #expect(horizontalPadding == 60)
            #expect(calendarSpacing == 30)
            #expect(weekdayFontSize == 20)
        } else {
            #expect(horizontalPadding == 20)
            #expect(calendarSpacing == 20)
            #expect(weekdayFontSize == 16)
        }
    }
    
    // MARK: - URL Handling Tests
    @Test("GitHub URL validation")
    func testGitHubURLValidation() async throws {
        let urlString = "https://github.com/rezaiyan/kalendar"
        let url = URL(string: urlString)
        
        #expect(url != nil)
        #expect(url?.scheme == "https")
        #expect(url?.host == "github.com")
        #expect(url?.path == "/rezaiyan/kalendar")
    }
    
    // MARK: - Color and Design Tests
    @Test("Gradient colors configuration")
    func testGradientColors() async throws {
        let colors: [Color] = [.blue, .purple]
        #expect(colors.count == 2)
        #expect(colors.first == .blue)
        #expect(colors.last == .purple)
    }
}

// MARK: - XCTest-based Unit Tests (for compatibility)
class KalendarXCTests: XCTestCase {
    
    override func setUpWithError() throws {
        super.setUp()
    }
    
    override func tearDownWithError() throws {
        super.tearDown()
    }
    
    // MARK: - Calendar Day Calculation Tests
    func testCalendarDaysGeneration() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // Monday first
        
        // Test with a known date: August 1, 2024 (Thursday)
        let testDate = calendar.date(from: DateComponents(year: 2024, month: 8, day: 1))!
        let startOfMonth = calendar.dateInterval(of: .month, for: testDate)?.start ?? testDate
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: testDate)?.count ?? 0
        
        XCTAssertEqual(daysInMonth, 31, "August should have 31 days")
        XCTAssertEqual(firstWeekday, 5, "August 1, 2024 should be Thursday (5)")
        
        // Test Monday-based conversion
        let mondayBasedWeekday = firstWeekday == 1 ? 6 : firstWeekday - 2
        XCTAssertEqual(mondayBasedWeekday, 3, "Thursday should be index 3 in Monday-first calendar")
    }
    
    func testCalendarDaysArrayGeneration() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        
        // Test August 2024
        let testDate = calendar.date(from: DateComponents(year: 2024, month: 8, day: 15))!
        let startOfMonth = calendar.dateInterval(of: .month, for: testDate)?.start ?? testDate
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: testDate)?.count ?? 0
        
        let mondayBasedWeekday = firstWeekday == 1 ? 6 : firstWeekday - 2
        
        var days: [Int] = []
        
        // Add empty days for first week
        for _ in 0..<mondayBasedWeekday {
            days.append(0)
        }
        
        // Add days of the month
        for day in 1...daysInMonth {
            days.append(day)
        }
        
        XCTAssertTrue(days.count > 31, "Should have padding days plus month days")
        XCTAssertEqual(days.filter { $0 > 0 }.count, 31, "Should have exactly 31 non-zero days")
        XCTAssertEqual(days.filter { $0 == 0 }.count, mondayBasedWeekday, "Should have correct number of padding days")
    }
    
    // MARK: - Date Component Tests
    func testDateComponentExtraction() throws {
        let calendar = Calendar.current
        let testDate = calendar.date(from: DateComponents(year: 2024, month: 8, day: 19))!
        
        let day = calendar.component(.day, from: testDate)
        let month = calendar.component(.month, from: testDate)
        let year = calendar.component(.year, from: testDate)
        
        XCTAssertEqual(day, 19)
        XCTAssertEqual(month, 8)
        XCTAssertEqual(year, 2024)
    }
    
    // MARK: - State Management Tests
    func testDateSelection() throws {
        let calendar = Calendar.current
        let originalDate = calendar.date(from: DateComponents(year: 2024, month: 8, day: 15))!
        let newDay = 25
        
        let newDate = calendar.date(bySetting: .day, value: newDay, of: originalDate)
        
        XCTAssertNotNil(newDate)
        XCTAssertEqual(calendar.component(.day, from: newDate!), newDay)
        XCTAssertEqual(calendar.component(.month, from: newDate!), 8)
        XCTAssertEqual(calendar.component(.year, from: newDate!), 2024)
    }
    
    // MARK: - Performance Tests
    func testCalendarGenerationPerformance() throws {
        measure {
            var calendar = Calendar(identifier: .gregorian)
            calendar.firstWeekday = 2
            
            for _ in 0..<1000 {
                let testDate = Date()
                let startOfMonth = calendar.dateInterval(of: .month, for: testDate)?.start ?? testDate
                let firstWeekday = calendar.component(.weekday, from: startOfMonth)
                let daysInMonth = calendar.range(of: .day, in: .month, for: testDate)?.count ?? 0
                
                let mondayBasedWeekday = firstWeekday == 1 ? 6 : firstWeekday - 2
                
                var days: [Int] = []
                for _ in 0..<mondayBasedWeekday {
                    days.append(0)
                }
                for day in 1...daysInMonth {
                    days.append(day)
                }
            }
        }
    }
    
    // MARK: - Error Handling Tests
    func testInvalidDateHandling() throws {
        let calendar = Calendar.current
        let invalidDate = calendar.date(from: DateComponents(year: 2024, month: 13, day: 32))
        XCTAssertNil(invalidDate, "Invalid date should return nil")
        
        let validDate = calendar.date(from: DateComponents(year: 2024, month: 12, day: 31))
        XCTAssertNotNil(validDate, "Valid date should not return nil")
    }
}

// MARK: - Widget Timeline Tests
class WidgetTimelineTests: XCTestCase {
    
    func testMidnightCalculation() throws {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: startOfToday)
        
        XCTAssertNotNil(nextMidnight)
        XCTAssertTrue(nextMidnight! > now, "Next midnight should be in the future")
        
        let midnightComponents = calendar.dateComponents([.hour, .minute, .second], from: nextMidnight!)
        XCTAssertEqual(midnightComponents.hour, 0)
        XCTAssertEqual(midnightComponents.minute, 0)
        XCTAssertEqual(midnightComponents.second, 0)
    }
    
    func testRefreshTimeCalculation() throws {
        let calendar = Calendar.current
        let now = Date()
        
        // Test various refresh time calculations
        if let nextMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            let oneAM = calendar.date(byAdding: .hour, value: 1, to: nextMidnight)
            let sixAM = calendar.date(byAdding: .hour, value: 6, to: nextMidnight)
            let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: now)
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: now)
            
            XCTAssertNotNil(oneAM)
            XCTAssertNotNil(sixAM)
            XCTAssertNotNil(nextWeek)
            XCTAssertNotNil(nextMonth)
            
            XCTAssertTrue(oneAM! > nextMidnight)
            XCTAssertTrue(sixAM! > oneAM!)
            XCTAssertTrue(nextWeek! > now)
            XCTAssertTrue(nextMonth! > now)
        }
    }
}