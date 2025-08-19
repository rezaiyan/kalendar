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
        SimpleEntry(
            date: Date(),
            selectedDate: Date(),
            currentMonth: "August",
            currentDayName: "Monday",
            currentTime: "14:30",
            calendarDays: Array(1...31),
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
        
        // Convert Sunday=1, Monday=2, etc. to Monday=0, Tuesday=1, etc.
        // Sunday=1 → 0, Monday=2 → 1, Tuesday=3 → 2, etc.
        let mondayBasedWeekday = firstWeekday == 1 ? 6 : firstWeekday - 2
        
        // Add empty days for first week
        for _ in 0..<mondayBasedWeekday {
            days.append(0)
        }
        
        // Add days of the month
        for day in 1...daysInMonth {
            days.append(day)
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
            calendarDays: days,
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
    let calendarDays: [Int]
    let weekdaySymbols: [String]
    let initialTime: Date // Store the initial time for local updates
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
            ForEach(entry.calendarDays, id: \.self) { day in
                if day > 0 {
                    calendarDayView(for: day)
                } else {
                    emptyCalendarDay
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Calendar Day View (Same as ContentView, larger)
    private func calendarDayView(for day: Int) -> some View {
        Text("\(day)")
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundColor(day == Calendar.current.component(.day, from: entry.date) ? .white : .primary)
            .frame(width: 28, height: 28)
            .background(dayBackground(for: day))
            .overlay(dayOverlay(for: day))
    }
    
    // MARK: - Day Background (Same as ContentView)
    private func dayBackground(for day: Int) -> some View {
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
    private func dayOverlay(for day: Int) -> some View {
        Circle()
            .stroke(Color.blue, lineWidth: 1.5)
    }
    
    // MARK: - Empty Calendar Day (Same as ContentView)
    private var emptyCalendarDay: some View {
        Text("")
            .frame(width: 28, height: 28)
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
        calendarDays: Array(1...31),
        weekdaySymbols: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
        initialTime: Date()
    )
}
