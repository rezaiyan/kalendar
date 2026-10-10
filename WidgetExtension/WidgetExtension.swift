//
//  WidgetExtension.swift
//  Kalendar Widget
//
//  Created by Ali Rezaiyan on 18.08.25.
//

import EventKit
import SwiftUI
import WidgetKit

// MARK: - Shared Storage (mirrors the app's SharedStorage)

private enum WidgetStorage {
    static let appGroupID = "group.com.alirezaiyan.Kalendar"
    static let selectedCalendarsKey = "selectedCalendarIDs"
    static let startOfWeekMondayKey = "startOfWeekMonday"
    static let localEventsFileName = "local_events.json"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static var startsWeekOnMonday: Bool {
        defaults.object(forKey: startOfWeekMondayKey) as? Bool ?? true
    }

    static var localEventsURL: URL {
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? URL.documentsDirectory
        return container.appendingPathComponent(localEventsFileName)
    }

    static func calendar() -> Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = startsWeekOnMonday ? 2 : 1
        return calendar
    }
}

// MARK: - Models

struct CalendarWidgetDay: Identifiable {
    let date: Date
    let day: Int
    let isCurrentMonth: Bool
    let isToday: Bool
    let hasEvents: Bool

    var id: Date { date }
}

struct WidgetEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let colorHex: String?

    var color: Color { colorHex.map(Color.init(widgetHex:)) ?? .accentColor }
}

struct KalendarEntry: TimelineEntry {
    let date: Date
    let days: [CalendarWidgetDay]
    let weekdaySymbols: [String]
    /// Events overlapping the entry's day: all-day first, then by start time.
    let todayEvents: [WidgetEvent]
    /// The next timed event that has not started yet.
    let nextEvent: WidgetEvent?

    var monthTitle: String { date.formatted(.dateTime.month(.wide).year()) }
}

// MARK: - Timeline Provider

struct KalendarProvider: TimelineProvider {
    private let eventStore = EKEventStore()

    func placeholder(in context: Context) -> KalendarEntry {
        makeEntry(for: Date(), includeEvents: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (KalendarEntry) -> Void) {
        completion(makeEntry(for: Date(), includeEvents: !context.isPreview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KalendarEntry>) -> Void) {
        let calendar = WidgetStorage.calendar()
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        var dates: [Date] = [now]

        // Refresh as each of today's events starts, so "next event" never goes stale.
        let current = makeEntry(for: now)
        dates += current.todayEvents
            .filter { !$0.isAllDay && $0.startDate > now }
            .map(\.startDate)

        // Midnight entries for the next 3 days guarantee the right day is highlighted
        // even if WidgetKit delays the refresh. `startOfDay` already accounts for DST.
        for offset in 1...3 {
            if let midnight = calendar.date(byAdding: .day, value: offset, to: startOfToday) {
                dates.append(calendar.startOfDay(for: midnight))
            }
        }

        var entries = [current]
        entries += Set(dates.dropFirst()).sorted().map { makeEntry(for: $0) }

        let refreshDate = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now.addingTimeInterval(86_400)
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }

    // MARK: - Entry Generation

    private func makeEntry(for date: Date, includeEvents: Bool = true) -> KalendarEntry {
        let calendar = WidgetStorage.calendar()
        let monthEvents = includeEvents ? fetchEvents(inMonthOf: date, calendar: calendar) : []

        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let todayEvents = monthEvents
            .filter { $0.startDate < dayEnd && ($0.endDate > dayStart || $0.startDate == dayStart) }
            .sorted { lhs, rhs in
                lhs.isAllDay != rhs.isAllDay ? lhs.isAllDay : lhs.startDate < rhs.startDate
            }

        return KalendarEntry(
            date: date,
            days: generateDays(for: date, calendar: calendar, events: monthEvents),
            weekdaySymbols: weekdaySymbols(calendar: calendar),
            todayEvents: todayEvents,
            nextEvent: todayEvents.first { !$0.isAllDay && $0.startDate > date }
        )
    }

    private func weekdaySymbols(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    /// A fixed 6-week grid for the month containing `date`.
    private func generateDays(for date: Date, calendar: Calendar, events: [WidgetEvent]) -> [CalendarWidgetDay] {
        guard let monthStart = calendar.dateInterval(of: .month, for: date)?.start else { return [] }
        let leading = (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -leading, to: monthStart) else { return [] }

        return (0..<42).compactMap { index in
            guard let day = calendar.date(byAdding: .day, value: index, to: gridStart),
                  let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            return CalendarWidgetDay(
                date: day,
                day: calendar.component(.day, from: day),
                isCurrentMonth: calendar.isDate(day, equalTo: monthStart, toGranularity: .month),
                isToday: calendar.isDate(day, inSameDayAs: date),
                hasEvents: events.contains { $0.startDate < next && ($0.endDate > day || $0.startDate == day) }
            )
        }
    }

    private func fetchEvents(inMonthOf date: Date, calendar: Calendar) -> [WidgetEvent] {
        guard let month = calendar.dateInterval(of: .month, for: date) else { return [] }
        return fetchSystemEvents(from: month.start, to: month.end) + loadLocalEvents(from: month.start, to: month.end)
    }

    private func fetchSystemEvents(from start: Date, to end: Date) -> [WidgetEvent] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }

        let savedIDs = Set(WidgetStorage.defaults.stringArray(forKey: WidgetStorage.selectedCalendarsKey) ?? [])
        let selected = eventStore.calendars(for: .event).filter { savedIDs.contains($0.calendarIdentifier) }
        // No (or only stale) saved selection means "all calendars", matching the app.
        let calendars: [EKCalendar]? = selected.isEmpty ? nil : selected

        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return eventStore.events(matching: predicate).map { event in
            let baseID = event.eventIdentifier ?? event.calendarItemIdentifier
            let title = event.title ?? ""
            return WidgetEvent(
                id: "\(baseID)@\(Int(event.startDate.timeIntervalSince1970))",
                title: title.isEmpty ? "Untitled" : title,
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                colorHex: event.calendar.cgColor.widgetHexString
            )
        }
    }

    private func loadLocalEvents(from start: Date, to end: Date) -> [WidgetEvent] {
        guard let data = try? Data(contentsOf: WidgetStorage.localEventsURL),
              let events = try? JSONDecoder().decode([WidgetLocalEvent].self, from: data) else {
            return []
        }
        return events
            .filter { $0.startDate < end && $0.endDate > start }
            .map {
                WidgetEvent(
                    id: $0.id,
                    title: $0.title,
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    isAllDay: $0.isAllDay,
                    colorHex: $0.calendarColorHex
                )
            }
    }
}

// MARK: - Local Event Decoding (matches CalendarEvent in app)

private struct WidgetLocalEvent: Decodable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarColorHex: String?
}

// MARK: - Color Helpers

private extension Color {
    init(widgetHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else {
            self = .blue
            return
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

private extension CGColor {
    var widgetHexString: String {
        let srgb = CGColorSpace(name: CGColorSpace.sRGB).flatMap {
            converted(to: $0, intent: .defaultIntent, options: nil)
        } ?? self
        guard let components = srgb.components, components.count >= 3 else { return "#007AFF" }
        func channel(_ value: CGFloat) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", channel(components[0]), channel(components[1]), channel(components[2]))
    }
}

// MARK: - Shared Widget Pieces

private struct WidgetBackground: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(
                colors: [Color.accentColor.opacity(0.12), .clear, Color.accentColor.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct EventLine: View {
    let event: WidgetEvent
    var fontSize: CGFloat = 11

    var body: some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(event.color)
                .frame(width: 3, height: fontSize + 3)
            Text(event.title)
                .font(.system(size: fontSize, weight: .medium, design: .rounded))
                .lineLimit(1)
            Spacer(minLength: 2)
            Text(event.isAllDay ? "All day" : event.startDate.formatted(date: .omitted, time: .shortened))
                .font(.system(size: fontSize - 1, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
        }
    }
}

private struct MonthGrid: View {
    let entry: KalendarEntry
    let fontSize: CGFloat
    let cellHeight: CGFloat
    var showsEventDots = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                ForEach(Array(entry.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: fontSize - 2, weight: .semibold, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(entry.days) { day in
                    ZStack {
                        if day.isToday {
                            Circle()
                                .fill(Color.accentColor.gradient)
                                .frame(width: cellHeight, height: cellHeight)
                        }
                        Text("\(day.day)")
                            .font(.system(size: fontSize, weight: day.isToday ? .bold : .regular, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(dayColor(day))

                        if showsEventDots && day.hasEvents && day.isCurrentMonth && !day.isToday {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 3, height: 3)
                                .offset(y: cellHeight / 2 - 1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: cellHeight)
                }
            }
        }
    }

    private func dayColor(_ day: CalendarWidgetDay) -> Color {
        if day.isToday { return .white }
        return day.isCurrentMonth ? .primary : .secondary.opacity(0.35)
    }
}

// MARK: - Small Widget

struct SmallCalendarView: View {
    let entry: KalendarEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.date.formatted(.dateTime.weekday(.wide)).uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.tint)

            Text(entry.date.formatted(.dateTime.day()))
                .font(.system(size: 50, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)

            Spacer(minLength: 4)

            if let next = entry.nextEvent {
                VStack(alignment: .leading, spacing: 2) {
                    Text(next.startDate.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 5) {
                        Capsule().fill(next.color).frame(width: 3, height: 12)
                        Text(next.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .lineLimit(2)
                    }
                }
            } else {
                Text(summary)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { WidgetBackground() }
    }

    private var summary: String {
        switch entry.todayEvents.count {
        case 0: "No events today"
        case 1: "1 event today"
        default: "\(entry.todayEvents.count) events today"
        }
    }
}

// MARK: - Medium Widget

struct MediumCalendarView: View {
    let entry: KalendarEntry

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date.formatted(.dateTime.month(.wide)))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.tint)
                MonthGrid(entry: entry, fontSize: 9, cellHeight: 13)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.date.formatted(.dateTime.weekday(.wide).day()))
                    .font(.system(size: 12, weight: .bold, design: .rounded))

                if entry.todayEvents.isEmpty {
                    Spacer(minLength: 0)
                    Label("No events", systemImage: "sparkles")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                } else {
                    ForEach(entry.todayEvents.prefix(4)) { event in
                        EventLine(event: event, fontSize: 11)
                    }
                    if entry.todayEvents.count > 4 {
                        Text("+\(entry.todayEvents.count - 4) more")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .containerBackground(for: .widget) { WidgetBackground() }
    }
}

// MARK: - Large Widget

struct LargeCalendarView: View {
    let entry: KalendarEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.monthTitle)
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Text(entry.date.formatted(.dateTime.weekday(.wide)))
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.tint)
            }

            MonthGrid(entry: entry, fontSize: 13, cellHeight: 26, showsEventDots: true)

            Divider().opacity(0.5)

            VStack(alignment: .leading, spacing: 6) {
                if entry.todayEvents.isEmpty {
                    Label("Nothing scheduled today", systemImage: "sparkles")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entry.todayEvents.prefix(3)) { event in
                        EventLine(event: event, fontSize: 12)
                    }
                    if entry.todayEvents.count > 3 {
                        Text("+\(entry.todayEvents.count - 3) more")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .containerBackground(for: .widget) { WidgetBackground() }
    }
}

// MARK: - Lock Screen Widgets

struct LockScreenCircularView: View {
    let entry: KalendarEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: -2) {
                Text(entry.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                Text(entry.date.formatted(.dateTime.day()))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
        }
        .widgetAccentable()
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct LockScreenRectangularView: View {
    let entry: KalendarEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(entry.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .widgetAccentable()

            if let next = entry.nextEvent {
                Text(next.title)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .lineLimit(1)
                Text(next.startDate.formatted(date: .omitted, time: .shortened))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                Text(entry.todayEvents.isEmpty ? "No upcoming events" : "No more events today")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct LockScreenInlineView: View {
    let entry: KalendarEntry

    var body: some View {
        if let next = entry.nextEvent {
            Text("\(next.startDate.formatted(date: .omitted, time: .shortened)) \(next.title)")
        } else {
            Text(entry.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
        }
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
            .accessoryInline,
        ])
    }
}

struct WidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: KalendarEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallCalendarView(entry: entry)
        case .systemLarge:
            LargeCalendarView(entry: entry)
        case .accessoryCircular:
            LockScreenCircularView(entry: entry)
        case .accessoryRectangular:
            LockScreenRectangularView(entry: entry)
        case .accessoryInline:
            LockScreenInlineView(entry: entry)
        default:
            MediumCalendarView(entry: entry)
        }
    }
}
