//
//  LockScreenCalendarWidget.swift
//  LockScreenCalendarWidget
//
//  Created by Ali Rezaiyan on 19.08.25.
//

import WidgetKit
import SwiftUI

// MARK: - Calendar Day Helper
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

// MARK: - Calendar Entry
struct SimpleEntry: TimelineEntry {
    let date: Date
    let selectedDate: Date
    let currentMonth: String
    let currentDayName: String
    let currentTime: String
    let allCalendarDays: [CalendarDay]
    let weekdaySymbols: [String]
    let initialTime: Date
}

// MARK: - Timeline Provider
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
        let totalDaysIncludingCurrent = mondayBasedWeekday + daysInMonth
        let weeksNeeded = Int(ceil(Double(totalDaysIncludingCurrent) / 7.0))
        let totalDaysInGrid = weeksNeeded * 7
        let remainingDays = totalDaysInGrid - totalDaysIncludingCurrent
        
        if remainingDays > 0 {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) ?? date
            let daysInNextMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 0
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
            initialTime: date
        )
    }
}

// MARK: - Lock Screen Calendar Widget Entry View
struct LockScreenCalendarWidgetEntryView: View {
    var entry: SimpleEntry
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
    let entry: SimpleEntry
    
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
    let entry: SimpleEntry
    
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
                    ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
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
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
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
    SimpleEntry(
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
    SimpleEntry(
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
