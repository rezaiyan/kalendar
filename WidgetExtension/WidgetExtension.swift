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

// MARK: - Deep Links (mirrors the app's DeepLink)

enum WidgetDeepLink {
    private static let scheme = "kalendar"

    /// Opens the app on `date`.
    static func day(_ date: Date) -> URL {
        url(host: "day", date: date)
    }

    /// Opens the event editor on `date`.
    static func newEvent(on date: Date) -> URL {
        url(host: "new", date: date)
    }

    private static func url(host: String, date: Date) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: "t", value: String(Int(date.timeIntervalSince1970)))]
        return components.url ?? URL(fileURLWithPath: "/")
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

    func overlaps(start: Date, end: Date) -> Bool {
        startDate < end && (endDate > start || startDate == start)
    }

    func isOngoing(at date: Date) -> Bool {
        !isAllDay && startDate <= date && endDate > date
    }

    /// "All day", "Now · until 3:00 PM" or "9:00 – 10:00 AM".
    func timeText(at date: Date) -> String {
        if isAllDay { return "All day" }
        if isOngoing(at: date) {
            return "Now · until " + endDate.formatted(date: .omitted, time: .shortened)
        }
        return (startDate..<max(startDate, endDate)).formatted(date: .omitted, time: .shortened)
    }
}

struct KalendarEntry: TimelineEntry {
    let date: Date
    let days: [CalendarWidgetDay]
    let weekdaySymbols: [String]
    /// Events overlapping the entry's day: all-day first, then by start time.
    let todayEvents: [WidgetEvent]
    let tomorrowEvents: [WidgetEvent]
    /// Start of the day after the entry's day.
    let tomorrow: Date

    var monthTitle: String { date.formatted(.dateTime.month(.wide).year()) }

    /// Today's events that haven't finished yet.
    var remainingToday: [WidgetEvent] {
        todayEvents.filter { $0.isAllDay || $0.endDate > date }
    }

    /// The ongoing or next timed event today.
    var nextEvent: WidgetEvent? {
        remainingToday.first { !$0.isAllDay }
    }

    /// What to show in agenda views: the rest of today, or tomorrow once today is done.
    var agenda: Agenda {
        let remaining = remainingToday
        if !remaining.isEmpty { return Agenda(date: date, isTomorrow: false, events: remaining) }
        return Agenda(date: tomorrow, isTomorrow: true, events: tomorrowEvents)
    }

    struct Agenda {
        /// The day the agenda is for; widget taps open this day in the app.
        let date: Date
        let isTomorrow: Bool
        let events: [WidgetEvent]

        var title: String { isTomorrow ? "Tomorrow" : "Today" }
    }
}

// MARK: - Entry Building

enum EntryBuilder {
    static func entry(for date: Date, events: [WidgetEvent], calendar: Calendar) -> KalendarEntry {
        let dayStart = calendar.startOfDay(for: date)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let dayAfterStart = calendar.date(byAdding: .day, value: 1, to: tomorrowStart) ?? tomorrowStart

        return KalendarEntry(
            date: date,
            days: days(for: date, calendar: calendar, events: events),
            weekdaySymbols: weekdaySymbols(calendar: calendar),
            todayEvents: sorted(events.filter { $0.overlaps(start: dayStart, end: tomorrowStart) }),
            tomorrowEvents: sorted(events.filter { $0.overlaps(start: tomorrowStart, end: dayAfterStart) }),
            tomorrow: tomorrowStart
        )
    }

    private static func sorted(_ events: [WidgetEvent]) -> [WidgetEvent] {
        events.sorted { lhs, rhs in
            if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
            return lhs.startDate < rhs.startDate
        }
    }

    private static func weekdaySymbols(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    /// A fixed 6-week grid for the month containing `date`.
    private static func days(for date: Date, calendar: Calendar, events: [WidgetEvent]) -> [CalendarWidgetDay] {
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
                hasEvents: events.contains { $0.overlaps(start: day, end: next) }
            )
        }
    }

    /// Realistic sample content for the widget gallery and previews.
    static func sample(at date: Date = Date()) -> KalendarEntry {
        let calendar = WidgetStorage.calendar()
        func at(_ hour: Int, _ minute: Int = 0, dayOffset: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: date) ?? date
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
        let events = [
            WidgetEvent(id: "1", title: "Design Review", startDate: at(10), endDate: at(11), isAllDay: false, colorHex: "#5E5CE6"),
            WidgetEvent(id: "2", title: "Lunch with Sam", startDate: at(12, 30), endDate: at(13, 30), isAllDay: false, colorHex: "#FF9F0A"),
            WidgetEvent(id: "3", title: "Yoga", startDate: at(18), endDate: at(19), isAllDay: false, colorHex: "#30D158"),
            WidgetEvent(id: "4", title: "Team Standup", startDate: at(9, dayOffset: 1), endDate: at(9, 15, dayOffset: 1),
                        isAllDay: false, colorHex: "#0A84FF"),
        ]
        return entry(for: date, events: events, calendar: calendar)
    }
}

// MARK: - Timeline Provider

struct KalendarProvider: TimelineProvider {
    private let eventStore = EKEventStore()

    /// Upper bound on timeline entries; WidgetKit only needs a handful per day.
    private static let maxEntries = 40

    func placeholder(in context: Context) -> KalendarEntry {
        EntryBuilder.sample()
    }

    func getSnapshot(in context: Context, completion: @escaping (KalendarEntry) -> Void) {
        if context.isPreview {
            completion(EntryBuilder.sample())
            return
        }
        let calendar = WidgetStorage.calendar()
        let now = Date()
        completion(EntryBuilder.entry(for: now, events: fetchEvents(around: now, calendar: calendar), calendar: calendar))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KalendarEntry>) -> Void) {
        let calendar = WidgetStorage.calendar()
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let horizon = calendar.date(byAdding: .day, value: 3, to: startOfToday) ?? now.addingTimeInterval(3 * 86_400)
        let events = fetchEvents(around: now, calendar: calendar)

        // Re-render whenever an event starts or ends, so "Now" and "next" are always accurate,
        // and at each midnight so the right day is highlighted even if a refresh is delayed.
        var dates = Set<Date>()
        for event in events where !event.isAllDay {
            for boundary in [event.startDate, event.endDate] where boundary > now && boundary <= horizon {
                dates.insert(boundary)
            }
        }
        for offset in 1...3 {
            if let midnight = calendar.date(byAdding: .day, value: offset, to: startOfToday) {
                dates.insert(midnight)
            }
        }

        let entryDates = [now] + dates.sorted().prefix(Self.maxEntries - 1)
        let entries = entryDates.map { EntryBuilder.entry(for: $0, events: events, calendar: calendar) }

        let refreshDate = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now.addingTimeInterval(86_400)
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }

    // MARK: - Fetching

    /// The current month plus the next few days, enough for the grid and every agenda in the timeline.
    private func fetchEvents(around date: Date, calendar: Calendar) -> [WidgetEvent] {
        guard let month = calendar.dateInterval(of: .month, for: date) else { return [] }
        let soon = calendar.date(byAdding: .day, value: 5, to: calendar.startOfDay(for: date)) ?? month.end
        let end = max(month.end, soon)
        return fetchSystemEvents(from: month.start, to: end) + loadLocalEvents(from: month.start, to: end)
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

// MARK: - Building Blocks

/// Weekday in accent caps above a large day number.
private struct DateBadge: View {
    let date: Date
    var daySize: CGFloat = 34

    var body: some View {
        VStack(alignment: .leading, spacing: -2) {
            Text(date.formatted(.dateTime.weekday(.wide)).uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.tint)
                .widgetAccentable()
                .lineLimit(1)
            Text(date.formatted(.dateTime.day()))
                .font(.system(size: daySize, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
    }
}

private struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
    }
}

/// A colored bar, the title and the time of an event.
private struct EventRow: View {
    let event: WidgetEvent
    let now: Date
    var compact = false

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(event.color)
                .frame(width: 3)
                .widgetAccentable()

            VStack(alignment: .leading, spacing: 0) {
                Text(event.title)
                    .font(.system(size: compact ? 12 : 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(event.timeText(at: now))
                    .font(.system(size: compact ? 10 : 11, weight: .medium, design: .rounded))
                    .foregroundStyle(event.isOngoing(at: now) ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Shows up to `limit` rows; when there are more, the last row becomes "+N more".
private struct AgendaList: View {
    let events: [WidgetEvent]
    let now: Date
    let limit: Int
    var compact = false
    /// When set, each row opens this day in the app.
    var linkDate: Date?

    var body: some View {
        let shown = events.count > limit ? max(limit - 1, 1) : limit
        VStack(alignment: .leading, spacing: compact ? 5 : 7) {
            ForEach(events.prefix(shown)) { event in
                if let linkDate {
                    Link(destination: WidgetDeepLink.day(linkDate)) {
                        EventRow(event: event, now: now, compact: compact)
                    }
                } else {
                    EventRow(event: event, now: now, compact: compact)
                }
            }
            if events.count > shown {
                Text("+\(events.count - shown) more")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 9)
            }
        }
    }
}

private struct EmptyAgenda: View {
    let agenda: KalendarEntry.Agenda

    var body: some View {
        Label(agenda.isTomorrow ? "Nothing planned" : "No more events", systemImage: "checkmark.circle")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
    }
}

/// A small round "+" that opens the event editor.
private struct AddEventLink: View {
    let date: Date

    var body: some View {
        Link(destination: WidgetDeepLink.newEvent(on: date)) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor))
                .widgetAccentable()
        }
        .accessibilityLabel("New Event")
    }
}

private struct MonthGrid: View {
    let entry: KalendarEntry
    let fontSize: CGFloat
    let cellHeight: CGFloat
    var showsEventDots = false
    var linksToDays = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                ForEach(Array(entry.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: max(fontSize - 3, 7), weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(entry.days) { day in
                    if linksToDays {
                        Link(destination: WidgetDeepLink.day(day.date)) { cell(day) }
                    } else {
                        cell(day)
                    }
                }
            }
        }
    }

    private func cell(_ day: CalendarWidgetDay) -> some View {
        ZStack {
            if day.isToday {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: cellHeight - 1, height: cellHeight - 1)
                    .widgetAccentable()
            }
            Text("\(day.day)")
                .font(.system(size: fontSize, weight: day.isToday ? .bold : .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(day.isToday ? AnyShapeStyle(.white) : (day.isCurrentMonth ? AnyShapeStyle(.primary) : AnyShapeStyle(.quaternary)))

            if showsEventDots && day.hasEvents && day.isCurrentMonth && !day.isToday {
                Circle()
                    .fill(.secondary)
                    .frame(width: 3, height: 3)
                    .offset(y: cellHeight / 2 - 2)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: cellHeight)
    }
}

private extension View {
    func widgetBackground() -> some View {
        containerBackground(for: .widget) { Color(.systemBackground) }
    }
}

// MARK: - Small: Up Next

struct SmallCalendarView: View {
    let entry: KalendarEntry

    var body: some View {
        let agenda = entry.agenda
        VStack(alignment: .leading, spacing: 6) {
            DateBadge(date: entry.date)

            Spacer(minLength: 0)

            if agenda.events.isEmpty {
                EmptyAgenda(agenda: agenda)
            } else {
                if agenda.isTomorrow { SectionLabel(text: agenda.title) }
                AgendaList(events: agenda.events, now: entry.date, limit: agenda.isTomorrow ? 1 : 2, compact: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetBackground()
        .widgetURL(WidgetDeepLink.day(agenda.date))
    }
}

// MARK: - Medium: Day + Agenda

struct MediumCalendarView: View {
    let entry: KalendarEntry

    var body: some View {
        let agenda = entry.agenda
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                DateBadge(date: entry.date, daySize: 42)
                Text(entry.date.formatted(.dateTime.month(.wide)))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(countText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 92, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel(text: agenda.title)
                    Spacer()
                    AddEventLink(date: entry.date)
                }
                if agenda.events.isEmpty {
                    EmptyAgenda(agenda: agenda)
                } else {
                    AgendaList(events: agenda.events, now: entry.date, limit: 3, linkDate: agenda.date)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetBackground()
        .widgetURL(WidgetDeepLink.day(entry.date))
    }

    private var countText: String {
        switch entry.todayEvents.count {
        case 0: "No events today"
        case 1: "1 event today"
        default: "\(entry.todayEvents.count) events today"
        }
    }
}

// MARK: - Large: Month + Agenda

struct LargeCalendarView: View {
    let entry: KalendarEntry

    var body: some View {
        let agenda = entry.agenda
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.date.formatted(.dateTime.weekday(.wide)).uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.tint)
                        .widgetAccentable()
                    Text(entry.monthTitle)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                Spacer()
                AddEventLink(date: entry.date)
            }

            MonthGrid(entry: entry, fontSize: 13, cellHeight: 23, showsEventDots: true, linksToDays: true)

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                SectionLabel(text: agenda.title)
                if agenda.events.isEmpty {
                    EmptyAgenda(agenda: agenda)
                } else {
                    AgendaList(events: agenda.events, now: entry.date, limit: 3, linkDate: agenda.date)
                }
            }

            Spacer(minLength: 0)
        }
        .widgetBackground()
        .widgetURL(WidgetDeepLink.day(entry.date))
    }
}

// MARK: - Small: Month

struct SmallMonthView: View {
    let entry: KalendarEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.date.formatted(.dateTime.month(.wide)).uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.tint)
                .widgetAccentable()
            MonthGrid(entry: entry, fontSize: 10, cellHeight: 14, showsEventDots: true)
        }
        .widgetBackground()
        .widgetURL(WidgetDeepLink.day(entry.date))
    }
}

// MARK: - Lock Screen

struct LockScreenCircularView: View {
    let entry: KalendarEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: -2) {
                Text(entry.date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .widgetAccentable()
                Text(entry.date.formatted(.dateTime.day()))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(WidgetDeepLink.day(entry.date))
    }
}

struct LockScreenRectangularView: View {
    let entry: KalendarEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let next = entry.nextEvent {
                Text(next.isOngoing(at: entry.date) ? "NOW" : next.startDate.formatted(date: .omitted, time: .shortened))
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .widgetAccentable()
                Text(next.title)
                    .font(.system(.headline, design: .rounded))
                    .lineLimit(1)
                Text(next.isOngoing(at: entry.date)
                     ? "until " + next.endDate.formatted(date: .omitted, time: .shortened)
                     : entry.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text(entry.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .widgetAccentable()
                Text(entry.todayEvents.isEmpty ? "No events today" : "No more events")
                    .font(.system(.headline, design: .rounded))
                    .lineLimit(1)
                if let first = entry.tomorrowEvents.first {
                    Text("Tomorrow: \(first.title)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(WidgetDeepLink.day(entry.date))
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

// MARK: - Widget Definitions

/// The main widget. The kind stays "KalendarWidget" so widgets users already placed keep working.
struct WidgetExtension: Widget {
    let kind = "KalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KalendarProvider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Up Next")
        .description("Today's agenda and what's coming next.")
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

struct MonthWidget: Widget {
    let kind = "KalendarMonthWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KalendarProvider()) { entry in
            SmallMonthView(entry: entry)
        }
        .configurationDisplayName("Month")
        .description("The whole month at a glance.")
        .supportedFamilies([.systemSmall])
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

// MARK: - Previews

#Preview("Up Next", as: .systemSmall) {
    WidgetExtension()
} timeline: {
    EntryBuilder.sample()
}

#Preview("Agenda", as: .systemMedium) {
    WidgetExtension()
} timeline: {
    EntryBuilder.sample()
}

#Preview("Month + Agenda", as: .systemLarge) {
    WidgetExtension()
} timeline: {
    EntryBuilder.sample()
}

#Preview("Month", as: .systemSmall) {
    MonthWidget()
} timeline: {
    EntryBuilder.sample()
}

#Preview("Lock Screen", as: .accessoryRectangular) {
    WidgetExtension()
} timeline: {
    EntryBuilder.sample()
}
