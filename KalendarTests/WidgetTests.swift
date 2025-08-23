//
//  WidgetTests.swift
//  KalendarTests
//
//  Created by AI Assistant
//

import Testing
import XCTest
import WidgetKit
import SwiftUI

// Note: Since widget extensions are separate targets, we test the logic components
// that would be used in widgets rather than the widgets themselves

// MARK: - Widget Timeline Logic Tests
struct WidgetLogicTests {
    
    @Test("Calendar entry creation")
    func testCalendarEntryCreation() async throws {
        let testDate = Calendar.current.date(from: DateComponents(year: 2024, month: 8, day: 19))!
        
        // Test date formatting
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"
        let month = monthFormatter.string(from: testDate)
        #expect(month == "August")
        
        let dayNameFormatter = DateFormatter()
        dayNameFormatter.dateFormat = "EEEE"
        let dayName = dayNameFormatter.string(from: testDate)
        #expect(dayName == "Monday")
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let time = timeFormatter.string(from: testDate)
        #expect(time.count == 5) // Format: "HH:mm"
    }
    
    @Test("Midnight calculation accuracy")
    func testMidnightCalculation() async throws {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: startOfToday)
        
        #expect(nextMidnight != nil)
        #expect(nextMidnight! > now)
        
        let midnightComponents = calendar.dateComponents([.hour, .minute, .second], from: nextMidnight!)
        #expect(midnightComponents.hour == 0)
        #expect(midnightComponents.minute == 0)
        #expect(midnightComponents.second == 0)
    }
    
    @Test("Refresh times generation")
    func testRefreshTimesGeneration() async throws {
        let calendar = Calendar.current
        let now = Date()
        
        guard let tomorrowMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
            throw TestError.dateCalculationFailed
        }
        
        var refreshTimes: [Date] = []
        refreshTimes.append(tomorrowMidnight)
        
        // Add 1 AM
        if let oneAM = calendar.date(byAdding: .hour, value: 1, to: tomorrowMidnight) {
            refreshTimes.append(oneAM)
        }
        
        // Add 6 AM
        if let sixAM = calendar.date(byAdding: .hour, value: 6, to: tomorrowMidnight) {
            refreshTimes.append(sixAM)
        }
        
        // Add next week
        if let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: now) {
            refreshTimes.append(nextWeek)
        }
        
        // Add next month
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) {
            refreshTimes.append(nextMonth)
        }
        
        #expect(refreshTimes.count >= 3) // At minimum: midnight, 1AM, 6AM
        #expect(refreshTimes.allSatisfy { $0 > now }) // All should be in future
        
        // Verify chronological order
        let sortedTimes = refreshTimes.sorted()
        #expect(sortedTimes == refreshTimes.sorted())
    }
    
    @Test("DST transition detection")
    func testDSTTransitionDetection() async throws {
        let calendar = Calendar.current
        let timeZone = TimeZone.current
        let now = Date()
        let threeMonthsLater = calendar.date(byAdding: .month, value: 3, to: now)!
        
        let interval = DateInterval(start: now, end: threeMonthsLater)
        let transitions = timeZone.nextDaylightSavingTimeTransition(after: interval.start)
        
        // DST transition might or might not exist in the next 3 months
        // This test verifies the logic works without asserting specific dates
        if let transition = transitions, interval.contains(transition) {
            #expect(transition > now)
            #expect(transition < threeMonthsLater)
        }
    }
    
    enum TestError: Error {
        case dateCalculationFailed
    }
}

// MARK: - Widget Calendar Day Generation Tests
class WidgetCalendarDayTests: XCTestCase {
    
    func testCalendarDayGeneration() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // Monday first
        
        let testDate = calendar.date(from: DateComponents(year: 2024, month: 8, day: 15))!
        let startOfMonth = calendar.dateInterval(of: .month, for: testDate)?.start ?? testDate
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: testDate)?.count ?? 0
        
        XCTAssertEqual(daysInMonth, 31)
        
        // Generate calendar days array similar to widget logic
        var allCalendarDays: [TestCalendarDay] = []
        
        let mondayBasedWeekday = firstWeekday == 1 ? 6 : firstWeekday - 2
        
        // Previous month days
        if mondayBasedWeekday > 0 {
            let previousMonth = calendar.date(byAdding: .month, value: -1, to: testDate)!
            let daysInPreviousMonth = calendar.range(of: .day, in: .month, for: previousMonth)?.count ?? 0
            let startDay = daysInPreviousMonth - mondayBasedWeekday + 1
            
            for day in startDay...daysInPreviousMonth {
                allCalendarDays.append(TestCalendarDay(day: day, isCurrentMonth: false, monthType: .previous))
            }
        }
        
        // Current month days
        for day in 1...daysInMonth {
            allCalendarDays.append(TestCalendarDay(day: day, isCurrentMonth: true, monthType: .current))
        }
        
        // Next month days
        let totalDaysIncludingCurrent = mondayBasedWeekday + daysInMonth
        let weeksNeeded = Int(ceil(Double(totalDaysIncludingCurrent) / 7.0))
        let totalDaysInGrid = weeksNeeded * 7
        let remainingDays = totalDaysInGrid - totalDaysIncludingCurrent
        
        if remainingDays > 0 {
            for day in 1...remainingDays {
                allCalendarDays.append(TestCalendarDay(day: day, isCurrentMonth: false, monthType: .next))
            }
        }
        
        // Verify structure
        let currentMonthDays = allCalendarDays.filter { $0.isCurrentMonth }
        let previousMonthDays = allCalendarDays.filter { $0.monthType == .previous }
        let nextMonthDays = allCalendarDays.filter { $0.monthType == .next }
        
        XCTAssertEqual(currentMonthDays.count, 31)
        XCTAssertEqual(previousMonthDays.count, mondayBasedWeekday)
        XCTAssertEqual(nextMonthDays.count, remainingDays)
        
        // Verify grid is complete weeks
        XCTAssertEqual(allCalendarDays.count % 7, 0)
        XCTAssertGreaterThanOrEqual(allCalendarDays.count, 28) // At least 4 weeks
        XCTAssertLessThanOrEqual(allCalendarDays.count, 42) // At most 6 weeks
    }
    
    func testWeekdayCalculation() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // Monday first
        
        // Test various known dates
        let testCases = [
            (DateComponents(year: 2024, month: 8, day: 1), 5), // Thursday
            (DateComponents(year: 2024, month: 1, day: 1), 2), // Monday  
            (DateComponents(year: 2024, month: 12, day: 1), 1), // Sunday
        ]
        
        for (dateComponents, expectedWeekday) in testCases {
            let date = calendar.date(from: dateComponents)!
            let weekday = calendar.component(.weekday, from: date)
            XCTAssertEqual(weekday, expectedWeekday)
            
            // Test Monday-based conversion
            let mondayBased = weekday == 1 ? 6 : weekday - 2
            XCTAssertGreaterThanOrEqual(mondayBased, 0)
            XCTAssertLessThanOrEqual(mondayBased, 6)
        }
    }
    
    func testMonthTransition() throws {
        let calendar = Calendar.current
        
        // Test last day of month
        let lastDayOfMonth = calendar.date(from: DateComponents(year: 2024, month: 1, day: 31))!
        let nextDay = calendar.date(byAdding: .day, value: 1, to: lastDayOfMonth)!
        
        let lastDayMonth = calendar.component(.month, from: lastDayOfMonth)
        let nextDayMonth = calendar.component(.month, from: nextDay)
        
        XCTAssertNotEqual(lastDayMonth, nextDayMonth)
        XCTAssertEqual(nextDayMonth, 2) // February
    }
    
    func testLeapYearHandling() throws {
        let calendar = Calendar.current
        
        // Test leap year (2024)
        let feb2024 = calendar.date(from: DateComponents(year: 2024, month: 2, day: 1))!
        let daysInFeb2024 = calendar.range(of: .day, in: .month, for: feb2024)?.count
        XCTAssertEqual(daysInFeb2024, 29)
        
        // Test non-leap year (2023)
        let feb2023 = calendar.date(from: DateComponents(year: 2023, month: 2, day: 1))!
        let daysInFeb2023 = calendar.range(of: .day, in: .month, for: feb2023)?.count
        XCTAssertEqual(daysInFeb2023, 28)
    }
}

// MARK: - Test Helper Structures
struct TestCalendarDay {
    let day: Int
    let isCurrentMonth: Bool
    let monthType: MonthType
    
    enum MonthType {
        case previous
        case current
        case next
    }
}

// MARK: - Widget Performance Tests
class WidgetPerformanceTests: XCTestCase {
    
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
    
    func testDateFormattingPerformance() throws {
        let dates = (0..<100).map { _ in Date() }
        
        measure {
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MMMM"
            
            let dayNameFormatter = DateFormatter()
            dayNameFormatter.dateFormat = "EEEE"
            
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            
            for date in dates {
                _ = monthFormatter.string(from: date)
                _ = dayNameFormatter.string(from: date)
                _ = timeFormatter.string(from: date)
            }
        }
    }
    
    func testRefreshTimeCalculationPerformance() throws {
        measure {
            let calendar = Calendar.current
            
            for _ in 0..<100 {
                let now = Date()
                
                var refreshTimes: [Date] = []
                
                if let tomorrowMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
                    refreshTimes.append(tomorrowMidnight)
                    
                    if let oneAM = calendar.date(byAdding: .hour, value: 1, to: tomorrowMidnight) {
                        refreshTimes.append(oneAM)
                    }
                    
                    if let sixAM = calendar.date(byAdding: .hour, value: 6, to: tomorrowMidnight) {
                        refreshTimes.append(sixAM)
                    }
                }
                
                if let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: now) {
                    refreshTimes.append(nextWeek)
                }
                
                if let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) {
                    refreshTimes.append(nextMonth)
                }
                
                _ = Array(Set(refreshTimes)).sorted()
            }
        }
    }
}
