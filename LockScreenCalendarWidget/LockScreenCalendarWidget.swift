//
//  LockScreenCalendarWidget.swift
//  LockScreenCalendarWidget
//
//  Created by Ali Rezaiyan on 19.08.25.
//

import WidgetKit
import SwiftUI

// MARK: - Local type definitions for LockScreen widget
// Since we can't directly import from Shared folder, we define the types here
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

// MARK: - LockScreen Timeline Provider
struct LockScreenTimelineProvider: TimelineProvider {
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
        print("📅 LockScreen Timeline created with \(entries.count) entries:")
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
                allCalendarDays.append(CalendarDay(day: day, isCurrentMonth: false, monthType: .previous))
            }
        }
        
        // Current month days
        for day in 1...daysInMonth {
            allCalendarDays.append(CalendarDay(day: day, isCurrentMonth: true, monthType: .current))
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
                allCalendarDays.append(CalendarDay(day: day, isCurrentMonth: false, monthType: .next))
            }
        }
        
        return allCalendarDays
    }
    
    private func createSampleCalendarDays() -> [CalendarDay] {
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

// MARK: - Lock Screen Calendar Widget Entry View
struct LockScreenCalendarWidgetEntryView: View {
    var entry: CalendarEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            LockScreenSmallView(entry: entry)
        case .systemMedium:
            LockScreenMediumView(entry: entry)
        default:
            LockScreenSmallView(entry: entry)
        }
    }
}

// MARK: - Lock Screen Small View
struct LockScreenSmallView: View {
    let entry: CalendarEntry
    
    var body: some View {
        VStack(spacing: 6) {
            // Current date prominently displayed
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: entry.date))")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(entry.currentMonth)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            // Day of week
            Text(entry.currentDayName)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(lockScreenBackground)
        .widgetURL(URL(string: "kalendar://calendar"))
    }
    
    private var lockScreenBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.quaternary, lineWidth: 0.5)
            )
    }
}

// MARK: - Lock Screen Medium View
struct LockScreenMediumView: View {
    let entry: CalendarEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Left side: Large current date
            VStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: entry.date))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(entry.currentMonth)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            // Right side: Mini calendar preview
            VStack(spacing: 6) {
                // Weekday headers (very compact)
                HStack(spacing: 0) {
                    ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { index, day in
                        Text(day)
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Mini 2x2 calendar grid showing current week
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                    ForEach(0..<14, id: \.self) { index in
                        if index < entry.allCalendarDays.count {
                            let calendarDay = entry.allCalendarDays[index]
                            miniDayView(for: calendarDay.day, isCurrentMonth: calendarDay.isCurrentMonth)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(lockScreenBackground)
        .widgetURL(URL(string: "kalendar://calendar"))
    }
    
    private func miniDayView(for day: Int, isCurrentMonth: Bool) -> some View {
        Text("\(day)")
            .font(.system(size: 8, weight: .medium, design: .rounded))
            .foregroundColor(day == Calendar.current.component(.day, from: entry.date) ? .white : (isCurrentMonth ? .primary : .secondary))
            .opacity(isCurrentMonth ? 1.0 : 0.4)
            .frame(width: 14, height: 14)
            .background(
                Group {
                    if day == Calendar.current.component(.day, from: entry.date) {
                        miniDayGradient
                    } else {
                        Color.clear
                    }
                }
            )
            .clipShape(Circle())
    }
    
    private var miniDayGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var lockScreenBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.quaternary, lineWidth: 0.5)
            )
    }
}

// MARK: - Lock Screen Calendar Widget
struct LockScreenCalendarWidget: Widget {
    let kind: String = "LockScreenCalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenTimelineProvider()) { entry in
            if #available(iOS 17.0, *) {
                LockScreenCalendarWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                LockScreenCalendarWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Lock Screen Calendar")
        .description("Compact calendar for lock screen")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews
#Preview(as: .systemSmall) {
    LockScreenCalendarWidget()
} timeline: {
    CalendarEntry(
        date: Date(),
        selectedDate: Date(),
        currentMonth: "August",
        currentDayName: "Monday",
        currentTime: "14:30",
        allCalendarDays: [
            CalendarDay(day: 28, isCurrentMonth: false, monthType: .previous),
            CalendarDay(day: 29, isCurrentMonth: false, monthType: .previous),
            CalendarDay(day: 30, isCurrentMonth: false, monthType: .previous),
            CalendarDay(day: 31, isCurrentMonth: false, monthType: .previous),
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

#Preview(as: .systemMedium) {
    LockScreenCalendarWidget()
} timeline: {
    CalendarEntry(
        date: Date(),
        selectedDate: Date(),
        currentMonth: "August",
        currentDayName: "Monday",
        currentTime: "14:30",
        allCalendarDays: [
            CalendarDay(day: 28, isCurrentMonth: false, monthType: .previous),
            CalendarDay(day: 29, isCurrentMonth: false, monthType: .previous),
            CalendarDay(day: 30, isCurrentMonth: false, monthType: .previous),
            CalendarDay(day: 31, isCurrentMonth: false, monthType: .previous),
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
