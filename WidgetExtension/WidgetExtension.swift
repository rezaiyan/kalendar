//
//  KalendarWidgetExtension.swift
//  KalendarWidgetExtension
//
//  Created by Ali Rezaiyan on 18.08.25.
//

import WidgetKit
import SwiftUI

// MARK: - Local type definitions for Main widget
// Since we can't directly import from Shared folder, we define the types here
struct CalendarDay: Identifiable, Hashable {
    let id = UUID()
    let day: Int
    let isCurrentMonth: Bool
    let monthType: MonthType
    let actualDate: Date // Add the actual date for proper comparison
    
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

struct CalendarEntry: TimelineEntry {
    let date: Date
    let selectedDate: Date
    let currentMonth: String
    let currentDayName: String
    let currentTime: String
    let allCalendarDays: [CalendarDay]
    let weekdaySymbols: [String]
    let initialTime: Date
}

// MARK: - Main Widget Timeline Provider
struct MainWidgetTimelineProvider: TimelineProvider {
    typealias Entry = CalendarEntry
    
    private let calendar: Calendar
    private let timeZone: TimeZone
    
    init(calendar: Calendar = Calendar.current, timeZone: TimeZone = TimeZone.current) {
        var cal = calendar
        cal.firstWeekday = 2 // Monday = 2, Sunday = 1
        cal.timeZone = timeZone
        self.calendar = cal
        self.timeZone = timeZone
    }
    
    func placeholder(in context: Context) -> CalendarEntry {
        let sampleDays = createSampleCalendarDays()
        return CalendarEntry(
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
    
    func getSnapshot(in context: Context, completion: @escaping (CalendarEntry) -> ()) {
        completion(createEntry(for: Date()))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarEntry>) -> ()) {
        var entries: [CalendarEntry] = []
        let now = Date()
        
        // 1. Current entry
        let currentEntry = createEntry(for: now)
        entries.append(currentEntry)
        
        // 2. Multiple refresh points for reliability
        let refreshTimes = calculateRefreshTimes(from: now)
        for refreshTime in refreshTimes {
            let entry = createEntry(for: refreshTime)
            entries.append(entry)
        }
        
        // Use .atEnd policy to ensure refresh when timeline ends
        let timeline = Timeline(entries: entries, policy: .atEnd)
        
        #if DEBUG
        print("📅 Main Widget Timeline created with \(entries.count) entries:")
        for (index, entry) in entries.enumerated() {
            print("  \(index + 1). \(formatDate(entry.date))")
        }
        #endif
        
        completion(timeline)
    }
    
    private func createEntry(for date: Date) -> CalendarEntry {
        let calendarDays = generateCalendarDays(for: date)
        
        // Format date components
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"
        monthFormatter.timeZone = timeZone
        
        let dayNameFormatter = DateFormatter()
        dayNameFormatter.dateFormat = "EEEE"
        dayNameFormatter.timeZone = timeZone
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.timeZone = timeZone
        
        return CalendarEntry(
            date: date,
            selectedDate: date,
            currentMonth: monthFormatter.string(from: date),
            currentDayName: dayNameFormatter.string(from: date),
            currentTime: timeFormatter.string(from: date),
            allCalendarDays: calendarDays,
            weekdaySymbols: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
            initialTime: date
        )
    }
    
    private func calculateRefreshTimes(from startDate: Date) -> [Date] {
        var refreshTimes: [Date] = []
        
        // Calculate next midnight in the widget's timezone
        guard let tomorrowMidnight = nextMidnight(after: startDate) else {
            return []
        }
        
        // Add midnight refresh
        refreshTimes.append(tomorrowMidnight)
        
        // Add additional refresh points for extra reliability
        
        // 1. Next day at 1 AM (in case midnight refresh fails)
        if let oneAM = calendar.date(byAdding: .hour, value: 1, to: tomorrowMidnight) {
            refreshTimes.append(oneAM)
        }
        
        // 2. Next day at 6 AM (for good measure)
        if let sixAM = calendar.date(byAdding: .hour, value: 6, to: tomorrowMidnight) {
            refreshTimes.append(sixAM)
        }
        
        // 3. Next week (for week transitions)
        if let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startDate),
           let nextWeekMidnight = nextMidnight(after: nextWeek) {
            refreshTimes.append(nextWeekMidnight)
        }
        
        // 4. Next month (for month transitions)
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: startDate),
           let nextMonthMidnight = nextMidnight(after: nextMonth) {
            refreshTimes.append(nextMonthMidnight)
        }
        
        // 5. Handle Daylight Saving Time transitions
        if let dstTransition = nextDSTTransition(after: startDate) {
            refreshTimes.append(dstTransition)
        }
        
        // Sort and deduplicate
        return Array(Set(refreshTimes)).sorted()
    }
    
    private func nextMidnight(after date: Date) -> Date? {
        // Get the start of the next day in the specified timezone
        let startOfToday = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: startOfToday)
    }
    
    private func nextDSTTransition(after date: Date) -> Date? {
        // Check for DST transitions in the next 3 months
        let threeMonthsLater = calendar.date(byAdding: .month, value: 3, to: date) ?? date
        
        let interval = DateInterval(start: date, end: threeMonthsLater)
        let transitions = timeZone.nextDaylightSavingTimeTransition(after: interval.start)
        
        if let transition = transitions, interval.contains(transition) {
            // Return the midnight after the DST transition
            return nextMidnight(after: transition)
        }
        
        return nil
    }
    
    private func generateCalendarDays(for date: Date) -> [CalendarDay] {
        let startOfMonth = calendar.dateInterval(of: .month, for: date)?.start ?? date
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 0
        
        var allCalendarDays: [CalendarDay] = []
        
        // Convert Sunday=1, Monday=2, etc. to Monday=0, Tuesday=1, etc.
        let mondayBasedWeekday = firstWeekday == 1 ? 6 : firstWeekday - 2
        
        // Previous month days
        if mondayBasedWeekday > 0 {
            let previousMonth = calendar.date(byAdding: .month, value: -1, to: date) ?? date
            let daysInPreviousMonth = calendar.range(of: .day, in: .month, for: previousMonth)?.count ?? 0
            let startDay = daysInPreviousMonth - mondayBasedWeekday + 1
            
            for day in startDay...daysInPreviousMonth {
                allCalendarDays.append(CalendarDay(day: day, isCurrentMonth: false, monthType: .previous, actualDate: calendar.date(from: DateComponents(year: calendar.component(.year, from: previousMonth), month: calendar.component(.month, from: previousMonth), day: day)) ?? Date()))
            }
        }
        
        // Current month days
        for day in 1...daysInMonth {
            allCalendarDays.append(CalendarDay(day: day, isCurrentMonth: true, monthType: .current, actualDate: calendar.date(from: DateComponents(year: calendar.component(.year, from: date), month: calendar.component(.month, from: date), day: day)) ?? Date()))
        }
        
        // Next month days (to complete the grid)
        let totalDaysIncludingCurrent = mondayBasedWeekday + daysInMonth
        let weeksNeeded = Int(ceil(Double(totalDaysIncludingCurrent) / 7.0))
        let totalDaysInGrid = weeksNeeded * 7
        let remainingDays = totalDaysInGrid - totalDaysIncludingCurrent
        
        if remainingDays > 0 {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) ?? date
            let daysInNextMonth = calendar.range(of: .day, in: .month, for: nextMonth)?.count ?? 0
            let maxDaysToShow = min(remainingDays, daysInNextMonth)
            
            for day in 1...maxDaysToShow {
                allCalendarDays.append(CalendarDay(day: day, isCurrentMonth: false, monthType: .next, actualDate: calendar.date(from: DateComponents(year: calendar.component(.year, from: nextMonth), month: calendar.component(.month, from: nextMonth), day: day)) ?? Date()))
            }
        }
        
        return allCalendarDays
    }
    
    private func createSampleCalendarDays() -> [CalendarDay] {
        var sampleDays: [CalendarDay] = []
        let now = Date()
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) ?? now
        
        // Previous month days
        for day in [28, 29, 30, 31] {
            sampleDays.append(CalendarDay(day: day, isCurrentMonth: false, monthType: .previous, actualDate: calendar.date(from: DateComponents(year: calendar.component(.year, from: previousMonth), month: calendar.component(.month, from: previousMonth), day: day)) ?? Date()))
        }
        
        // Current month days
        for day in 1...31 {
            sampleDays.append(CalendarDay(day: day, isCurrentMonth: true, monthType: .current, actualDate: calendar.date(from: DateComponents(year: calendar.component(.year, from: now), month: calendar.component(.month, from: now), day: day)) ?? Date()))
        }
        
        // Next month days
        for day in [1, 2, 3, 4, 5, 6, 7] {
            sampleDays.append(CalendarDay(day: day, isCurrentMonth: false, monthType: .next, actualDate: calendar.date(from: DateComponents(year: calendar.component(.year, from: nextMonth), month: calendar.component(.month, from: nextMonth), day: day)) ?? Date()))
        }
        
        return sampleDays
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}

// MARK: - Main Calendar Widget
struct WidgetExtension: Widget {
    let kind: String = "KalendarWidgetExtension"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MainWidgetTimelineProvider()) { entry in
            KalendarWidgetExtensionEntryView(entry: entry)
        }
        .configurationDisplayName("Kalendar")
        .description("Beautiful monthly calendar widget")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct KalendarWidgetExtensionEntryView: View {
    var entry: CalendarEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallContentView(entry: entry)
            case .systemMedium:
                MediumContentView(entry: entry)
            case .systemLarge:
                LargeContentView(entry: entry)
            default:
                LargeContentView(entry: entry)
            }
        }
        .widgetBackground(backgroundColor(for: colorScheme))
    }
    
    private func backgroundColor(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light:
            return Color(.systemBackground)
        case .dark:
            return Color(.systemBackground)
        @unknown default:
            return Color(.systemBackground)
        }
    }
}



// MARK: - Small Widget Content View
struct SmallContentView: View {
    let entry: CalendarEntry
    
    var body: some View {
        VStack(spacing: 8) {
            // Compact header
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.currentDayName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(entry.currentMonth)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Compact calendar grid (3x3 showing current week + next week preview)
            compactCalendarGrid
            
            Spacer()
        }
        .padding(6)
    }
    
    private var compactCalendarGrid: some View {
        VStack(spacing: 4) {
            // Weekday headers (abbreviated)
            HStack(spacing: 0) {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { index, day in
                    Text(day)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Compact 3x3 grid showing current week and next week preview
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 1) {
                ForEach(0..<21, id: \.self) { index in
                    if index < entry.allCalendarDays.count {
                        let calendarDay = entry.allCalendarDays[index]
                        compactDayView(for: calendarDay.day, isCurrentMonth: calendarDay.isCurrentMonth)
                    }
                }
            }
        }
    }
    
    private func compactDayView(for day: Int, isCurrentMonth: Bool) -> some View {
        VStack(spacing: 2) {
            Text("\(day)")
                .font(.system(size: 11, weight: isCurrentDay(day, isCurrentMonth: isCurrentMonth) ? .bold : .medium, design: .rounded))
                .foregroundColor(isCurrentDay(day, isCurrentMonth: isCurrentMonth) ? .white : (isCurrentMonth ? .primary : .secondary))
                .opacity(isCurrentMonth ? 1.0 : 0.4)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            if isCurrentMonth {
                let mockDate = createMockDate(for: day)
                let weather = WidgetWeatherService.shared.getWeatherForDate(mockDate)
                Image(systemName: weather.weatherIcon)
                    .font(.system(size: 9))
                    .foregroundColor(weather.weatherColor)
                    .frame(width: 10, height: 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .padding(2)
        .background(
            Group {
                if isCurrentDay(day, isCurrentMonth: isCurrentMonth) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                } else {
                    Color.clear
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
    
    private func isCurrentDay(_ day: Int, isCurrentMonth: Bool) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        
        // Get the current day, month, and year
        let currentDay = calendar.component(.day, from: today)
        let currentMonth = calendar.component(.month, from: today)
        let currentYear = calendar.component(.year, from: today)
        
        // Check if this day number matches today's day number
        // AND if the widget is showing the current month
        let entryMonth = calendar.component(.month, from: entry.date)
        let entryYear = calendar.component(.year, from: entry.date)
        
        // Only highlight if it's the current day AND the widget is showing the current month
        // AND the day is actually from the current month (not previous/next month)
        return day == currentDay && currentMonth == entryMonth && currentYear == entryYear && isCurrentMonth
    }
    
    private func createMockDate(for day: Int) -> Date {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: entry.date)
        let currentYear = calendar.component(.year, from: entry.date)
        return calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: day)) ?? entry.date
    }
    
    private var dayGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Medium Widget Content View
struct MediumContentView: View {
    let entry: CalendarEntry
    
    var body: some View {
        HStack(spacing: 10) {
            // Left side: Date info
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.currentDayName)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(entry.currentMonth)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                
                Text(entry.currentTime)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right side: Compact calendar
            VStack(spacing: 6) {
                // Weekday headers
                HStack(spacing: 0) {
                    ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { index, day in
                        Text(day)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // 4x4 calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                    ForEach(0..<28, id: \.self) { index in
                        if index < entry.allCalendarDays.count {
                            let calendarDay = entry.allCalendarDays[index]
                            mediumDayView(for: calendarDay.day, isCurrentMonth: calendarDay.isCurrentMonth)
                        }
                    }
                }
            }
        }
        .padding(10)
    }
    
    private func mediumDayView(for day: Int, isCurrentMonth: Bool) -> some View {
        VStack(spacing: 3) {
            Text("\(day)")
                .font(.system(size: 12, weight: isCurrentDay(day, isCurrentMonth: isCurrentMonth) ? .bold : .medium, design: .rounded))
                .foregroundColor(isCurrentDay(day, isCurrentMonth: isCurrentMonth) ? .white : (isCurrentMonth ? .primary : .secondary))
                .opacity(isCurrentMonth ? 1.0 : 0.4)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            if isCurrentMonth {
                let mockDate = createMockDate(for: day)
                let weather = WidgetWeatherService.shared.getWeatherForDate(mockDate)
                Image(systemName: weather.weatherIcon)
                    .font(.system(size: 10))
                    .foregroundColor(weather.weatherColor)
                    .frame(width: 12, height: 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .padding(3)
        .background(
            Group {
                if isCurrentDay(day, isCurrentMonth: isCurrentMonth) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                } else {
                    Color.clear
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private func isCurrentDay(_ day: Int, isCurrentMonth: Bool) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        
        // Get the current day, month, and year
        let currentDay = calendar.component(.day, from: today)
        let currentMonth = calendar.component(.month, from: today)
        let currentYear = calendar.component(.year, from: today)
        
        // Check if this day number matches today's day number
        // AND if the widget is showing the current month
        let entryMonth = calendar.component(.month, from: entry.date)
        let entryYear = calendar.component(.year, from: entry.date)
        
        // Only highlight if it's the current day AND the widget is showing the current month
        // AND the day is actually from the current month (not previous/next month)
        return day == currentDay && currentMonth == entryMonth && currentYear == entryYear && isCurrentMonth
    }
    
    private func createMockDate(for day: Int) -> Date {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: entry.date)
        let currentYear = calendar.component(.year, from: entry.date)
        return calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: day)) ?? entry.date
    }
    
    private var dayGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Large Widget (Replicates ContentView with larger sizes)
struct LargeContentView: View {
    let entry: CalendarEntry
    
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
        VStack(spacing: 4) {
            Text("\(day)")
                .font(.system(size: 15, weight: isCurrentDay(day, isCurrentMonth: isCurrentMonth) ? .bold : .medium, design: .rounded))
                .foregroundColor(isCurrentDay(day, isCurrentMonth: isCurrentMonth) ? .white : (isCurrentMonth ? .primary : .secondary))
                .opacity(isCurrentMonth ? 1.0 : 0.4)
            
            if isCurrentMonth {
                let mockDate = createMockDate(for: day)
                let weather = WidgetWeatherService.shared.getWeatherForDate(mockDate)
                Image(systemName: weather.weatherIcon)
                    .font(.system(size: 12))
                    .foregroundColor(weather.weatherColor)
            }
        }
        .frame(width: 28, height: 32)
        .padding(4)
        .background(dayBackground(for: day, isCurrentMonth: isCurrentMonth))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(dayBorder(for: day, isCurrentMonth: isCurrentMonth))
    }
    
    private func isCurrentDay(_ day: Int, isCurrentMonth: Bool) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        
        // Get the current day, month, and year
        let currentDay = calendar.component(.day, from: today)
        let currentMonth = calendar.component(.month, from: today)
        let currentYear = calendar.component(.year, from: today)
        
        // Check if this day number matches today's day number
        // AND if the widget is showing the current month
        let entryMonth = calendar.component(.month, from: entry.date)
        let entryYear = calendar.component(.year, from: entry.date)
        
        // Only highlight if it's the current day AND the widget is showing the current month
        // AND the day is actually from the current month (not previous/next month)
        return day == currentDay && currentMonth == entryMonth && currentYear == entryYear && isCurrentMonth
    }
    
    private func createMockDate(for day: Int) -> Date {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: entry.date)
        let currentYear = calendar.component(.year, from: entry.date)
        return calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: day)) ?? entry.date
    }
    
    // MARK: - Day Background (Same as ContentView)
    private func dayBackground(for day: Int, isCurrentMonth: Bool) -> some View {
        Group {
            if isCurrentDay(day, isCurrentMonth: isCurrentMonth) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else {
                Color.clear
            }
        }
    }
    
    // MARK: - Day Border (Same as ContentView)
    private func dayBorder(for day: Int, isCurrentMonth: Bool) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(Color.clear, lineWidth: 0)
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

#Preview(as: .systemSmall) {
    WidgetExtension()
} timeline: {
    CalendarEntry(
        date: Date(),
        selectedDate: Date(),
        currentMonth: "August",
        currentDayName: "Monday",
        currentTime: "14:30",
        allCalendarDays: [
            CalendarDay(day: 28, isCurrentMonth: false, monthType: .previous, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) - 1, day: 28)) ?? Date()),
            CalendarDay(day: 29, isCurrentMonth: false, monthType: .previous, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) - 1, day: 29)) ?? Date()),
            CalendarDay(day: 30, isCurrentMonth: false, monthType: .previous, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) - 1, day: 30)) ?? Date()),
            CalendarDay(day: 31, isCurrentMonth: false, monthType: .previous, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) - 1, day: 31)) ?? Date()),
            CalendarDay(day: 1, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 1)) ?? Date()),
            CalendarDay(day: 2, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 2)) ?? Date()),
            CalendarDay(day: 3, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 3)) ?? Date()),
            CalendarDay(day: 4, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 4)) ?? Date()),
            CalendarDay(day: 5, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 5)) ?? Date()),
            CalendarDay(day: 6, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 6)) ?? Date()),
            CalendarDay(day: 7, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 7)) ?? Date()),
            CalendarDay(day: 8, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 8)) ?? Date()),
            CalendarDay(day: 9, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 9)) ?? Date()),
            CalendarDay(day: 10, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 10)) ?? Date()),
            CalendarDay(day: 11, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 11)) ?? Date()),
            CalendarDay(day: 12, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 12)) ?? Date()),
            CalendarDay(day: 13, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 13)) ?? Date()),
            CalendarDay(day: 14, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 14)) ?? Date()),
            CalendarDay(day: 15, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 15)) ?? Date()),
            CalendarDay(day: 16, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 16)) ?? Date()),
            CalendarDay(day: 17, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 17)) ?? Date()),
            CalendarDay(day: 18, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 18)) ?? Date()),
            CalendarDay(day: 19, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 19)) ?? Date()),
            CalendarDay(day: 20, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 20)) ?? Date()),
            CalendarDay(day: 21, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 21)) ?? Date()),
            CalendarDay(day: 22, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 22)) ?? Date()),
            CalendarDay(day: 23, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 23)) ?? Date()),
            CalendarDay(day: 24, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 24)) ?? Date()),
            CalendarDay(day: 25, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 25)) ?? Date()),
            CalendarDay(day: 26, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 26)) ?? Date()),
            CalendarDay(day: 27, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 27)) ?? Date()),
            CalendarDay(day: 28, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 28)) ?? Date()),
            CalendarDay(day: 29, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 29)) ?? Date()),
            CalendarDay(day: 30, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 30)) ?? Date()),
            CalendarDay(day: 31, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 31)) ?? Date()),
            CalendarDay(day: 1, isCurrentMonth: false, monthType: .next, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) + 1, day: 1)) ?? Date()),
            CalendarDay(day: 2, isCurrentMonth: false, monthType: .next, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) + 1, day: 2)) ?? Date()),
            CalendarDay(day: 3, isCurrentMonth: false, monthType: .next, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) + 1, day: 3)) ?? Date()),
            CalendarDay(day: 4, isCurrentMonth: false, monthType: .next, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) + 1, day: 4)) ?? Date()),
            CalendarDay(day: 5, isCurrentMonth: false, monthType: .next, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) + 1, day: 5)) ?? Date()),
            CalendarDay(day: 6, isCurrentMonth: false, monthType: .next, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) + 1, day: 6)) ?? Date()),
            CalendarDay(day: 7, isCurrentMonth: false, monthType: .next, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) + 1, day: 7)) ?? Date())
        ],
        weekdaySymbols: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
        initialTime: Date()
    )
}

#Preview(as: .systemMedium) {
    WidgetExtension()
} timeline: {
    CalendarEntry(
        date: Date(),
        selectedDate: Date(),
        currentMonth: "August",
        currentDayName: "Monday",
        currentTime: "14:30",
        allCalendarDays: [
            CalendarDay(day: 28, isCurrentMonth: false, monthType: .previous, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) - 1, day: 28)) ?? Date()),
            CalendarDay(day: 29, isCurrentMonth: false, monthType: .previous, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) - 1, day: 29)) ?? Date()),
            CalendarDay(day: 30, isCurrentMonth: false, monthType: .previous, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) - 1, day: 30)) ?? Date()),
            CalendarDay(day: 31, isCurrentMonth: false, monthType: .previous, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) - 1, day: 31)) ?? Date()),
            CalendarDay(day: 1, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 1)) ?? Date()),
            CalendarDay(day: 2, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 2)) ?? Date()),
            CalendarDay(day: 3, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 3)) ?? Date()),
            CalendarDay(day: 4, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 4)) ?? Date()),
            CalendarDay(day: 5, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 5)) ?? Date()),
            CalendarDay(day: 6, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 6)) ?? Date()),
            CalendarDay(day: 7, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 7)) ?? Date()),
            CalendarDay(day: 8, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 8)) ?? Date()),
            CalendarDay(day: 9, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 9)) ?? Date()),
            CalendarDay(day: 10, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 10)) ?? Date()),
            CalendarDay(day: 11, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 11)) ?? Date()),
            CalendarDay(day: 12, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 12)) ?? Date()),
            CalendarDay(day: 13, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 13)) ?? Date()),
            CalendarDay(day: 14, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 14)) ?? Date()),
            CalendarDay(day: 15, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 15)) ?? Date()),
            CalendarDay(day: 16, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 16)) ?? Date()),
            CalendarDay(day: 17, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 17)) ?? Date()),
            CalendarDay(day: 18, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 18)) ?? Date()),
            CalendarDay(day: 19, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 19)) ?? Date()),
            CalendarDay(day: 20, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 20)) ?? Date()),
            CalendarDay(day: 21, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 21)) ?? Date()),
            CalendarDay(day: 22, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 22)) ?? Date()),
            CalendarDay(day: 23, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 23)) ?? Date()),
            CalendarDay(day: 24, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 24)) ?? Date()),
            CalendarDay(day: 25, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 25)) ?? Date()),
            CalendarDay(day: 26, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 26)) ?? Date()),
            CalendarDay(day: 27, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 27)) ?? Date()),
            CalendarDay(day: 28, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 28)) ?? Date()),
            CalendarDay(day: 29, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 29)) ?? Date()),
            CalendarDay(day: 30, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 30)) ?? Date()),
            CalendarDay(day: 31, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 31)) ?? Date()),
            CalendarDay(day: 1, isCurrentMonth: false, monthType: .next, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) + 1, day: 1)) ?? Date()),
            CalendarDay(day: 2, isCurrentMonth: false, monthType: .next, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) + 1, day: 2)) ?? Date()),
            CalendarDay(day: 3, isCurrentMonth: false, monthType: .next, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) + 1, day: 3)) ?? Date()),
            CalendarDay(day: 4, isCurrentMonth: false, monthType: .next, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) + 1, day: 4)) ?? Date()),
            CalendarDay(day: 5, isCurrentMonth: false, monthType: .next, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) + 1, day: 5)) ?? Date()),
            CalendarDay(day: 6, isCurrentMonth: false, monthType: .next, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) + 1, day: 6)) ?? Date()),
            CalendarDay(day: 7, isCurrentMonth: false, monthType: .next, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) + 1, day: 7)) ?? Date())
        ],
        weekdaySymbols: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
        initialTime: Date()
    )
}

// MARK: - Widget Background Extension
extension View {
    func widgetBackground(_ backgroundColor: Color) -> some View {
        if #available(iOS 17.0, *) {
            return self
                .containerBackground(for: .widget) {
                    backgroundColor
                }
        } else {
            return self
                .background(backgroundColor)
        }
    }
}

#Preview(as: .systemLarge) {
    WidgetExtension()
} timeline: {
    CalendarEntry(
        date: Date(),
        selectedDate: Date(),
        currentMonth: "August",
        currentDayName: "Monday",
        currentTime: "14:30",
        allCalendarDays: [
            // Previous month days (faded)
            CalendarDay(day: 28, isCurrentMonth: false, monthType: .previous, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) - 1, day: 28)) ?? Date()),
            CalendarDay(day: 29, isCurrentMonth: false, monthType: .previous, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) - 1, day: 29)) ?? Date()),
            CalendarDay(day: 30, isCurrentMonth: false, monthType: .previous, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) - 1, day: 30)) ?? Date()),
            CalendarDay(day: 31, isCurrentMonth: false, monthType: .previous, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) - 1, day: 31)) ?? Date()),
            
            // Current month days
            CalendarDay(day: 1, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 1)) ?? Date()),
            CalendarDay(day: 2, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 2)) ?? Date()),
            CalendarDay(day: 3, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 3)) ?? Date()),
            CalendarDay(day: 4, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 4)) ?? Date()),
            CalendarDay(day: 5, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 5)) ?? Date()),
            CalendarDay(day: 6, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 6)) ?? Date()),
            CalendarDay(day: 7, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 7)) ?? Date()),
            CalendarDay(day: 8, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 8)) ?? Date()),
            CalendarDay(day: 9, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 9)) ?? Date()),
            CalendarDay(day: 10, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 10)) ?? Date()),
            CalendarDay(day: 11, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 11)) ?? Date()),
            CalendarDay(day: 12, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 12)) ?? Date()),
            CalendarDay(day: 13, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 13)) ?? Date()),
            CalendarDay(day: 14, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 14)) ?? Date()),
            CalendarDay(day: 15, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 15)) ?? Date()),
            CalendarDay(day: 16, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 16)) ?? Date()),
            CalendarDay(day: 17, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 17)) ?? Date()),
            CalendarDay(day: 18, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 18)) ?? Date()),
            CalendarDay(day: 19, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 19)) ?? Date()),
            CalendarDay(day: 20, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 20)) ?? Date()),
            CalendarDay(day: 21, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 21)) ?? Date()),
            CalendarDay(day: 22, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 22)) ?? Date()),
            CalendarDay(day: 23, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 23)) ?? Date()),
            CalendarDay(day: 24, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 24)) ?? Date()),
            CalendarDay(day: 25, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 25)) ?? Date()),
            CalendarDay(day: 26, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 26)) ?? Date()),
            CalendarDay(day: 27, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 27)) ?? Date()),
            CalendarDay(day: 28, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 28)) ?? Date()),
            CalendarDay(day: 29, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 29)) ?? Date()),
            CalendarDay(day: 30, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 30)) ?? Date()),
            CalendarDay(day: 31, isCurrentMonth: true, monthType: .current, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()), day: 31)) ?? Date()),
            
            // Next month days (faded)
            CalendarDay(day: 1, isCurrentMonth: false, monthType: .next, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) + 1, day: 1)) ?? Date()),
            CalendarDay(day: 2, isCurrentMonth: false, monthType: .next, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) + 1, day: 2)) ?? Date()),
            CalendarDay(day: 3, isCurrentMonth: false, monthType: .next, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) + 1, day: 3)) ?? Date()),
            CalendarDay(day: 4, isCurrentMonth: false, monthType: .next, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) + 1, day: 4)) ?? Date()),
            CalendarDay(day: 5, isCurrentMonth: false, monthType: .next, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) + 1, day: 5)) ?? Date()),
            CalendarDay(day: 6, isCurrentMonth: false, monthType: .next, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) + 1, day: 6)) ?? Date()),
            CalendarDay(day: 7, isCurrentMonth: false, monthType: .next, actualDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()) + 1, day: 7)) ?? Date())
        ],
        weekdaySymbols: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
        initialTime: Date()
    )
}