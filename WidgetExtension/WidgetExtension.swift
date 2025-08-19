//
//  KalendarWidgetExtension.swift
//  KalendarWidgetExtension
//
//  Created by Ali Rezaiyan on 18.08.25.
//

import WidgetKit
import SwiftUI

struct WidgetExtension: Widget {
    let kind: String = "KalendarWidgetExtension"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            KalendarWidgetExtensionEntryView(entry: entry)
        }
        .configurationDisplayName("Kalendar")
        .description("Beautiful monthly calendar widget")
        .supportedFamilies([.systemLarge])
    }
}

struct Provider: TimelineProvider {
    typealias Entry = SimpleEntry
    
    // Create a shared calendar instance for the provider
    private let calendar = Calendar.current
    
    func placeholder(in context: Context) -> SimpleEntry {
        // Create sample calendar days for preview
        var sampleDays: [CalendarDay] = []
        
        // Previous month days
        for day in [28, 29, 30, 31] {
            sampleDays.append(CalendarDay(day: day, isCurrentMonth: false, monthType: .previous))
        }
        
        // Current month days
        for day in 1...31 {
            sampleDays.append(CalendarDay(day: day, isCurrentMonth: true, monthType: .current))
        }
        
        // Next month days
        for day in [1, 2, 3, 4, 5, 6, 7] {
            sampleDays.append(CalendarDay(day: day, isCurrentMonth: false, monthType: .next))
        }
        
        return SimpleEntry(
            date: Date(),
            selectedDate: Date(),
            currentMonth: "August",
            currentDayName: "Monday",
            currentTime: "14:30",
            allCalendarDays: sampleDays,
            weekdaySymbols: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
            initialTime: Date()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = createEntry(for: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        var entries: [SimpleEntry] = []

        let now = Date()
        
        // Create entry for current time
        let currentEntry = createEntry(for: now)
        entries.append(currentEntry)
        
        // Add entry for midnight to handle day changes
        if let midnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 1, to: now)!) {
            let midnightEntry = createEntry(for: midnight)
            entries.append(midnightEntry)
        }
        
        // Add entry for next month to handle month changes
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) {
            let nextMonthEntry = createEntry(for: nextMonth)
            entries.append(nextMonthEntry)
        }

        // Use .atEnd policy to refresh when timeline ends
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    

    

    
    private func createEntry(for date: Date) -> SimpleEntry {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // 2 = Monday, 1 = Sunday
        
        let startOfMonth = calendar.dateInterval(of: .month, for: date)?.start ?? date
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 0
        
        var days: [Int] = []
        var previousMonthDays: [Int] = []
        var nextMonthDays: [Int] = []
        
        // Convert Sunday=1, Monday=2, etc. to Monday=0, Tuesday=1, etc.
        // Sunday=1 → 0, Monday=2 → 1, Tuesday=3 → 2, etc.
        let mondayBasedWeekday = firstWeekday == 1 ? 6 : firstWeekday - 2
        
        // Calculate days needed from previous month to fill first week
        if mondayBasedWeekday > 0 {
            let previousMonth = calendar.date(byAdding: .month, value: -1, to: date) ?? date
            let daysInPreviousMonth = calendar.range(of: .day, in: .month, for: previousMonth)?.count ?? 0
            let startDay = daysInPreviousMonth - mondayBasedWeekday + 1
            
            for day in startDay...daysInPreviousMonth {
                previousMonthDays.append(day)
            }
        }
        
        // Add days of the current month
        for day in 1...daysInMonth {
            days.append(day)
        }
        
        // Calculate days needed from next month to complete the grid
        // Ensure we always show complete weeks (multiples of 7)
        let totalDaysIncludingCurrent = mondayBasedWeekday + daysInMonth
        let weeksNeeded = Int(ceil(Double(totalDaysIncludingCurrent) / 7.0))
        let totalDaysInGrid = weeksNeeded * 7
        let remainingDays = totalDaysInGrid - totalDaysIncludingCurrent
        
        // Debug: Print calendar calculation details
        print("Calendar Debug - Date: \(date)")
        print("  First weekday: \(firstWeekday) -> Monday-based: \(mondayBasedWeekday)")
        print("  Days in month: \(daysInMonth)")
        print("  Previous month days: \(previousMonthDays.count)")
        print("  Current month days: \(days.count)")
        print("  Total including current: \(totalDaysIncludingCurrent)")
        print("  Weeks needed: \(weeksNeeded)")
        print("  Total grid: \(totalDaysInGrid)")
        print("  Remaining days: \(remainingDays)")
        print("  Next month days: \(nextMonthDays.count)")
        
        if remainingDays > 0 {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) ?? date
            let daysInNextMonth = calendar.range(of: .day, in: .month, for: nextMonth)?.count ?? 0
            let maxDaysToShow = min(remainingDays, daysInNextMonth)
            
            for day in 1...maxDaysToShow {
                nextMonthDays.append(day)
            }
        }
        
        // Build the complete calendar grid with metadata
        var allCalendarDays: [CalendarDay] = []
        
        // Add previous month days
        for day in previousMonthDays {
            allCalendarDays.append(CalendarDay(day: day, isCurrentMonth: false, monthType: .previous))
        }
        
        // Add current month days
        for day in days {
            allCalendarDays.append(CalendarDay(day: day, isCurrentMonth: true, monthType: .current))
        }
        
        // Add next month days
        for day in nextMonthDays {
            allCalendarDays.append(CalendarDay(day: day, isCurrentMonth: false, monthType: .next))
        }
        
        let formatter = DateFormatter()
        // Use current locale for other formatting
        formatter.locale = Locale.current
        
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"
        
        let dayNameFormatter = DateFormatter()
        dayNameFormatter.dateFormat = "EEEE"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        return SimpleEntry(
            date: date,
            selectedDate: date,
            currentMonth: monthFormatter.string(from: date),
            currentDayName: dayNameFormatter.string(from: date),
            currentTime: timeFormatter.string(from: date),
            allCalendarDays: allCalendarDays,
            weekdaySymbols: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
            initialTime: date // Store the initial time for local updates
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let selectedDate: Date
    let currentMonth: String
    let currentDayName: String
    let currentTime: String
    let allCalendarDays: [CalendarDay] // All days in the grid with metadata
    let weekdaySymbols: [String]
    let initialTime: Date // Store the initial time for local updates
}

// Helper struct for calendar days with unique identifiers
struct CalendarDay: Identifiable, Hashable {
    let id = UUID()
    let day: Int
    let isCurrentMonth: Bool
    let monthType: MonthType
    
    enum MonthType {
        case previous
        case current
        case next
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        lhs.id == rhs.id
    }
}

struct KalendarWidgetExtensionEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        LargeContentView(entry: entry)
    }
}



// MARK: - Large Widget (Replicates ContentView with larger sizes)
struct LargeContentView: View {
    let entry: SimpleEntry
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            calendarSection
            Spacer()
            bottomInfoSection
        }
        .padding(12)
    }
    
    // MARK: - Header Section (Same as ContentView, larger)
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                            Text(entry.currentDayName)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(entry.currentMonth)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        
        Spacer()
        }
        .padding(.top, 12)
        .padding(.bottom, 20)
    }
    
    // MARK: - Calendar Section (Same as ContentView, larger)
    private var calendarSection: some View {
        VStack(spacing: 16) {
            weekdayHeaders
            calendarGrid
        }
    }
    
    // MARK: - Weekday Headers (Same as ContentView, larger)
    private var weekdayHeaders: some View {
        HStack(spacing: 0) {
            ForEach(entry.weekdaySymbols, id: \.self) { day in
                Text(day)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Calendar Grid (Same as ContentView, larger)
    private var calendarGrid: some View {
        LazyVGrid(columns: calendarColumns, spacing: 6) {
            ForEach(entry.allCalendarDays) { calendarDay in
                calendarDayView(for: calendarDay.day, isCurrentMonth: calendarDay.isCurrentMonth)
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Calendar Day View (Same as ContentView, larger)
    private func calendarDayView(for day: Int, isCurrentMonth: Bool) -> some View {
        Text("\(day)")
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundColor(day == Calendar.current.component(.day, from: entry.date) ? .white : (isCurrentMonth ? .primary : .secondary))
            .opacity(isCurrentMonth ? 1.0 : 0.4)
            .frame(width: 28, height: 28)
            .background(dayBackground(for: day, isCurrentMonth: isCurrentMonth))
            .overlay(dayOverlay(for: day, isCurrentMonth: isCurrentMonth))
    }
    
    // MARK: - Day Background (Same as ContentView)
    private func dayBackground(for day: Int, isCurrentMonth: Bool) -> some View {
        Group {
            if day == Calendar.current.component(.day, from: entry.date) {
                Circle()
                    .fill(dayGradient)
            } else {
                // No background for non-today days
                Color.clear
            }
        }
    }
    
    // MARK: - Day Overlay (Same as ContentView)
    private func dayOverlay(for day: Int, isCurrentMonth: Bool) -> some View {
        Circle()
            .stroke(isCurrentMonth ? Color.blue : Color.gray.opacity(0.3), lineWidth: isCurrentMonth ? 1.5 : 1.0)
    }
    

    
    // MARK: - Bottom Info Section (Same as ContentView, larger)
    private var bottomInfoSection: some View {
        VStack(spacing: 10) {
            // Empty space for visual balance
        }
        .padding(.bottom, 12)
    }
    
    // MARK: - Background Gradient (Same as ContentView)
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(.systemBackground), Color(.systemGray6)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Day Gradient (Same as ContentView)
    private var dayGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Calendar Columns (Same as ContentView)
    private var calendarColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    }
    
}



#Preview(as: .systemLarge) {
    WidgetExtension()
} timeline: {
    SimpleEntry(
        date: Date(),
        selectedDate: Date(),
        currentMonth: "August",
        currentDayName: "Monday",
        currentTime: "14:30",
        allCalendarDays: [
            // Previous month days (faded)
            CalendarDay(day: 28, isCurrentMonth: false, monthType: .previous),
            CalendarDay(day: 29, isCurrentMonth: false, monthType: .previous),
            CalendarDay(day: 30, isCurrentMonth: false, monthType: .previous),
            CalendarDay(day: 31, isCurrentMonth: false, monthType: .previous),
            
            // Current month days
            CalendarDay(day: 1, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 2, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 3, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 4, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 5, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 6, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 7, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 8, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 9, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 10, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 11, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 12, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 13, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 14, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 15, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 16, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 17, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 18, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 19, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 20, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 21, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 22, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 23, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 24, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 25, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 26, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 27, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 28, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 29, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 30, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 31, isCurrentMonth: true, monthType: .current),
            
            // Next month days (faded)
            CalendarDay(day: 1, isCurrentMonth: false, monthType: .next),
            CalendarDay(day: 2, isCurrentMonth: false, monthType: .next),
            CalendarDay(day: 3, isCurrentMonth: false, monthType: .next),
            CalendarDay(day: 4, isCurrentMonth: false, monthType: .next),
            CalendarDay(day: 5, isCurrentMonth: false, monthType: .next),
            CalendarDay(day: 6, isCurrentMonth: false, monthType: .next),
            CalendarDay(day: 7, isCurrentMonth: false, monthType: .next)
        ],
        weekdaySymbols: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
        initialTime: Date()
    )
}
