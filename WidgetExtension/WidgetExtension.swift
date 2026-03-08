//
//  WidgetExtension.swift
//  Kalendar Widget
//
//  Created by Ali Rezaiyan on 18.08.25.
//

import WidgetKit
import SwiftUI
import EventKit

// MARK: - Models

struct CalendarWidgetDay: Identifiable {
    let id: String
    let day: Int
    let date: Date
    let isCurrentMonth: Bool
    let isToday: Bool
}

struct KalendarEntry: TimelineEntry {
    let date: Date
    let days: [CalendarWidgetDay]
    let monthTitle: String
    let todayEvents: [String]
    let nextEvent: String?
}

// MARK: - Timeline Provider

struct KalendarProvider: TimelineProvider {
    private let eventStore = EKEventStore()
    private static let appGroupID = "group.com.alirezaiyan.Kalendar"

    private var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: Self.appGroupID) ?? .standard
    }

    func placeholder(in context: Context) -> KalendarEntry {
        makeEntry(for: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (KalendarEntry) -> Void) {
        completion(makeEntry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KalendarEntry>) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        var entries: [KalendarEntry] = []

        // Entry for right now
        entries.append(makeEntry(for: now))

        // Entries at midnight + 1 AM (DST safety) for the next 3 days
        // This guarantees the correct day is highlighted even if
        // WidgetKit delays the refresh.
        for dayOffset in 1...3 {
            let startOfToday = calendar.startOfDay(for: now)
            if let midnight = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) {
                entries.append(makeEntry(for: midnight))
                // 1 AM entry covers DST transitions (clocks change at 2 AM)
                if let oneAM = calendar.date(byAdding: .hour, value: 1, to: midnight) {
                    entries.append(makeEntry(for: oneAM))
                }
            }
        }

        // Ask WidgetKit to call us again in 3 days
        let refreshDate = calendar.date(byAdding: .day, value: 3, to: calendar.startOfDay(for: now))
            ?? calendar.date(byAdding: .hour, value: 72, to: now)!
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }

    // MARK: - Entry Generation

    private func makeEntry(for date: Date) -> KalendarEntry {
        let defaults = sharedDefaults
        var calendar = Calendar(identifier: .gregorian)
        let startMonday = defaults.object(forKey: "startOfWeekMonday") == nil
            ? true
            : defaults.bool(forKey: "startOfWeekMonday")
        calendar.firstWeekday = startMonday ? 2 : 1

        let selectedIDs: Set<String>? = {
            guard let saved = defaults.stringArray(forKey: "selectedCalendarIDs"), !saved.isEmpty else { return nil }
            return Set(saved)
        }()

        let days = generateDays(for: date, calendar: calendar)

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let monthTitle = formatter.string(from: date)

        let (todayEvents, nextEvent) = fetchEvents(for: date, calendar: calendar, calendarIDs: selectedIDs)

        return KalendarEntry(
            date: date,
            days: days,
            monthTitle: monthTitle,
            todayEvents: todayEvents,
            nextEvent: nextEvent
        )
    }

    private func generateDays(for date: Date, calendar: Calendar) -> [CalendarWidgetDay] {
        let startOfMonth = calendar.dateInterval(of: .month, for: date)?.start ?? date
        let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        // Use the entry date as "today" so future entries highlight the correct day
        let today = date

        let offset: Int
        if calendar.firstWeekday == 2 {
            offset = firstWeekday == 1 ? 6 : firstWeekday - 2
        } else {
            offset = firstWeekday - 1
        }

        var days: [CalendarWidgetDay] = []

        // Previous month padding
        if offset > 0 {
            let prevMonth = calendar.date(byAdding: .month, value: -1, to: date)!
            let prevDays = calendar.range(of: .day, in: .month, for: prevMonth)?.count ?? 30
            for i in (prevDays - offset + 1)...prevDays {
                let d = calendar.date(from: DateComponents(
                    year: calendar.component(.year, from: prevMonth),
                    month: calendar.component(.month, from: prevMonth),
                    day: i
                ))!
                days.append(CalendarWidgetDay(id: "p\(i)", day: i, date: d, isCurrentMonth: false, isToday: false))
            }
        }

        // Current month
        for i in 1...daysInMonth {
            let d = calendar.date(from: DateComponents(
                year: calendar.component(.year, from: startOfMonth),
                month: calendar.component(.month, from: startOfMonth),
                day: i
            ))!
            days.append(CalendarWidgetDay(
                id: "c\(i)", day: i, date: d,
                isCurrentMonth: true,
                isToday: calendar.isDate(d, inSameDayAs: today)
            ))
        }

        // Next month padding (fill to 42 cells)
        let remaining = 42 - days.count
        if remaining > 0 && remaining <= 14 {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: date)!
            for i in 1...remaining {
                let d = calendar.date(from: DateComponents(
                    year: calendar.component(.year, from: nextMonth),
                    month: calendar.component(.month, from: nextMonth),
                    day: i
                ))!
                days.append(CalendarWidgetDay(id: "n\(i)", day: i, date: d, isCurrentMonth: false, isToday: false))
            }
        }

        return days
    }

    private func fetchEvents(for date: Date, calendar: Calendar, calendarIDs: Set<String>?) -> (titles: [String], next: String?) {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return ([], nil) }

        var allTitles: [(title: String, startDate: Date)] = []

        // System calendar events
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .fullAccess || status == .authorized {
            let calendars: [EKCalendar]? = calendarIDs.map { ids in
                eventStore.calendars(for: .event).filter { ids.contains($0.calendarIdentifier) }
            }
            let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
            let ekEvents = eventStore.events(matching: predicate)
            allTitles += ekEvents.map { (title: $0.title ?? "Untitled", startDate: $0.startDate) }
        }

        // Local events from app
        let localEvents = loadLocalEvents(from: start, to: end)
        allTitles += localEvents.map { (title: $0.title, startDate: $0.startDate) }

        allTitles.sort { $0.startDate < $1.startDate }

        let titles = allTitles.prefix(5).map { $0.title }
        let nextEvent = allTitles.first { $0.startDate > date }?.title

        return (titles, nextEvent)
    }

    private func loadLocalEvents(from start: Date, to end: Date) -> [(title: String, startDate: Date, endDate: Date)] {
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupID
        ) ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = container.appendingPathComponent("local_events.json")

        guard let data = try? Data(contentsOf: fileURL),
              let events = try? JSONDecoder().decode([WidgetLocalEvent].self, from: data) else {
            return []
        }

        return events
            .filter { $0.startDate < end && $0.endDate > start }
            .map { (title: $0.title, startDate: $0.startDate, endDate: $0.endDate) }
    }
}

// MARK: - Local Event Decoding (matches CalendarEvent in app)

private struct WidgetLocalEvent: Codable {
    let id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var notes: String?
    var calendarColorHex: String?
    var isLocal: Bool
}

// MARK: - Weekday Symbols

private func weekdaySymbols() -> [String] {
    let defaults = UserDefaults(suiteName: "group.com.alirezaiyan.Kalendar") ?? .standard
    let startMonday = defaults.object(forKey: "startOfWeekMonday") == nil
        ? true
        : defaults.bool(forKey: "startOfWeekMonday")
    return startMonday ? ["M", "T", "W", "T", "F", "S", "S"] : ["S", "M", "T", "W", "T", "F", "S"]
}

// MARK: - Small Widget (Liquid Glass)

struct SmallCalendarView: View {
    let entry: KalendarEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.monthTitle.components(separatedBy: " ").first ?? "")
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)

            Text("\(Calendar.current.component(.day, from: entry.date))")
                .font(.system(size: 48, weight: .bold, design: .rounded))

            Text(dayName(entry.date))
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            if let next = entry.nextEvent {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 5, height: 5)
                    Text(next)
                        .font(.system(.caption2, design: .rounded))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
            } else if !entry.todayEvents.isEmpty {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 5, height: 5)
                    Text("\(entry.todayEvents.count) event\(entry.todayEvents.count == 1 ? "" : "s")")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .containerBackground(for: .widget) {
            ZStack {
                Color(.systemBackground)
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.08), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private func dayName(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }
}

// MARK: - Medium Widget (Liquid Glass)

struct MediumCalendarView: View {
    let entry: KalendarEntry
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        HStack(spacing: 8) {
            // Mini calendar
            VStack(spacing: 2) {
                Text(entry.monthTitle)
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .lineLimit(1)

                HStack(spacing: 0) {
                    ForEach(weekdaySymbols().indices, id: \.self) { i in
                        Text(weekdaySymbols()[i])
                            .font(.system(size: 7, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                    }
                }

                LazyVGrid(columns: columns, spacing: 1) {
                    ForEach(entry.days) { day in
                        ZStack {
                            if day.isToday {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 14, height: 14)
                            }
                            Text("\(day.day)")
                                .font(.system(size: 9, weight: day.isToday ? .bold : .regular, design: .rounded))
                                .foregroundStyle(
                                    day.isCurrentMonth
                                        ? (day.isToday ? Color.white : Color.primary)
                                        : Color.secondary.opacity(0.25)
                                )
                        }
                        .frame(width: 16, height: 14)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            // Glass divider
            RoundedRectangle(cornerRadius: 0.5)
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.secondary.opacity(0.2), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1)
                .padding(.vertical, 4)

            // Events
            VStack(alignment: .leading, spacing: 3) {
                Text("Today")
                    .font(.system(.caption2, design: .rounded).weight(.bold))

                if entry.todayEvents.isEmpty {
                    Text("No events")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entry.todayEvents.prefix(4), id: \.self) { title in
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 1, style: .continuous)
                                .fill(Color.accentColor)
                                .frame(width: 2.5, height: 10)
                            Text(title)
                                .font(.system(size: 10, design: .rounded))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .containerBackground(for: .widget) {
            ZStack {
                Color(.systemBackground)
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.06), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

// MARK: - Large Widget (Liquid Glass)

struct LargeCalendarView: View {
    let entry: KalendarEntry
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            // Month title
            Text(entry.monthTitle)
                .font(.system(.headline, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdaySymbols().indices, id: \.self) { i in
                    Text(weekdaySymbols()[i])
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(entry.days) { day in
                    ZStack {
                        if day.isToday {
                            Circle()
                                .fill(Color.accentColor)
                        }
                        Text("\(day.day)")
                            .font(.system(size: 13, weight: day.isToday ? .bold : .regular, design: .rounded))
                            .foregroundStyle(
                                day.isCurrentMonth
                                    ? (day.isToday ? Color.white : Color.primary)
                                    : Color.secondary.opacity(0.25)
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                }
            }

            // Glass divider
            RoundedRectangle(cornerRadius: 0.5)
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.secondary.opacity(0.2), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            // Events
            VStack(alignment: .leading, spacing: 5) {
                Text("Today's Events")
                    .font(.system(.caption, design: .rounded).weight(.bold))

                if entry.todayEvents.isEmpty {
                    Text("No events scheduled")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entry.todayEvents.prefix(3), id: \.self) { title in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                .fill(Color.accentColor)
                                .frame(width: 3, height: 14)
                            Text(title)
                                .font(.system(.caption, design: .rounded))
                                .lineLimit(1)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding()
        .containerBackground(for: .widget) {
            ZStack {
                Color(.systemBackground)
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.06), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

// MARK: - Lock Screen Widgets (Liquid Glass)

struct LockScreenCircularView: View {
    let entry: KalendarEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text("\(Calendar.current.component(.day, from: entry.date))")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(shortMonth(entry.date))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .textCase(.uppercase)
            }
        }
        .containerBackground(.background, for: .widget)
    }

    private func shortMonth(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: date)
    }
}

struct LockScreenRectangularView: View {
    let entry: KalendarEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                Text(dayAndMonth(entry.date))
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
            }

            if let next = entry.nextEvent {
                Text(next)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .lineLimit(2)
            } else if !entry.todayEvents.isEmpty {
                Text("\(entry.todayEvents.count) event\(entry.todayEvents.count == 1 ? "" : "s") today")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                Text("No upcoming events")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.background, for: .widget)
    }

    private func dayAndMonth(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }
}

// MARK: - Widget Definition

struct WidgetExtension: Widget {
    let kind = "KalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KalendarProvider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Kalendar")
        .description("Your calendar at a glance")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
        ])
    }
}

struct WidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: KalendarEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallCalendarView(entry: entry)
        case .systemMedium:
            MediumCalendarView(entry: entry)
        case .systemLarge:
            LargeCalendarView(entry: entry)
        case .accessoryCircular:
            LockScreenCircularView(entry: entry)
        case .accessoryRectangular:
            LockScreenRectangularView(entry: entry)
        default:
            MediumCalendarView(entry: entry)
        }
    }
}
