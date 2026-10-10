//
//  CalendarViewModel.swift
//  Kalendar
//
//  Core calendar logic with EventRepository abstraction
//

import Foundation
import Observation
import WidgetKit

struct CalendarDay: Identifiable, Hashable {
    let date: Date
    let day: Int
    let isCurrentMonth: Bool
    let isToday: Bool

    var id: Date { date }
}

struct TimeSlot: Identifiable, Hashable {
    let start: Date
    let end: Date

    var id: Date { start }
    var duration: TimeInterval { end.timeIntervalSince(start) }
}

@Observable @MainActor
final class CalendarViewModel {
    /// Always the first day of the displayed month.
    private(set) var displayedMonth: Date
    /// Always the start of the selected day.
    private(set) var selectedDate: Date
    /// The current day; refreshed on significant time changes (midnight, time zone changes).
    private(set) var today: Date
    private(set) var events: [CalendarEvent] = [] {
        didSet { rebuildDayIndex() }
    }
    var calendarAccessGranted = false
    private(set) var availableCalendars: [CalendarSource] = []
    /// Empty means "all calendars".
    private(set) var selectedCalendarIDs: Set<String> = []
    var showCalendarPicker = false

    var startsWeekOnMonday: Bool {
        didSet {
            guard startsWeekOnMonday != oldValue else { return }
            SharedStorage.defaults.set(startsWeekOnMonday, forKey: SharedStorage.startOfWeekMondayKey)
            calendar = Self.makeCalendar(startsWeekOnMonday: startsWeekOnMonday)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Visible window for the timeline and free-slot calculation.
    static let dayStartHour = 8
    static let dayEndHour = 22
    private static let minimumFreeSlot: TimeInterval = 30 * 60

    private(set) var calendar: Calendar
    private let repository: EventRepository
    private let localStore: LocalEventStore
    private let reminders: ReminderScheduling
    private var eventsByDay: [Date: [CalendarEvent]] = [:]
    @ObservationIgnored private var fetchGeneration = 0
    @ObservationIgnored private var fetchTask: Task<Void, Never>?

    // Production init
    convenience init() {
        self.init(
            eventRepository: EKEventRepository(),
            localEventStore: LocalEventStore(),
            reminders: NotificationReminderScheduler()
        )
    }

    // Testable init
    init(
        eventRepository: EventRepository,
        localEventStore: LocalEventStore? = nil,
        reminders: ReminderScheduling? = nil
    ) {
        self.repository = eventRepository
        self.localStore = localEventStore ?? LocalEventStore()
        // Resolved here rather than as a default argument: defaults are evaluated outside the main actor.
        self.reminders = reminders ?? NoopReminderScheduler()

        let startsMonday = SharedStorage.startsWeekOnMonday
        let calendar = Self.makeCalendar(startsWeekOnMonday: startsMonday)
        let now = Date()
        self.startsWeekOnMonday = startsMonday
        self.calendar = calendar
        self.today = calendar.startOfDay(for: now)
        self.selectedDate = calendar.startOfDay(for: now)
        self.displayedMonth = Self.startOfMonth(now, in: calendar)
    }

    private static func makeCalendar(startsWeekOnMonday: Bool) -> Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = startsWeekOnMonday ? 2 : 1
        return calendar
    }

    private static func startOfMonth(_ date: Date, in calendar: Calendar) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    // MARK: - Display Properties

    var monthTitle: String {
        monthTitle(for: displayedMonth)
    }

    func monthTitle(for month: Date) -> String {
        month.formatted(.dateTime.month(.wide).year())
    }

    /// Short weekday symbols ordered by the user's first weekday.
    var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    var calendarDays: [CalendarDay] {
        calendarDays(for: displayedMonth)
    }

    /// A fixed 6-week (42 cell) grid for the month containing `month`, so the layout never jumps.
    func calendarDays(for month: Date) -> [CalendarDay] {
        let cal = calendar
        let monthStart = Self.startOfMonth(month, in: cal)
        let leading = (cal.component(.weekday, from: monthStart) - cal.firstWeekday + 7) % 7
        guard let gridStart = cal.date(byAdding: .day, value: -leading, to: monthStart) else { return [] }

        return (0..<42).compactMap { index in
            guard let date = cal.date(byAdding: .day, value: index, to: gridStart) else { return nil }
            return CalendarDay(
                date: date,
                day: cal.component(.day, from: date),
                isCurrentMonth: cal.isDate(date, equalTo: monthStart, toGranularity: .month),
                isToday: cal.isDate(date, inSameDayAs: today)
            )
        }
    }

    func monthOffset(_ offset: Int) -> Date {
        calendar.date(byAdding: .month, value: offset, to: displayedMonth) ?? displayedMonth
    }

    var isShowingToday: Bool {
        calendar.isDate(selectedDate, inSameDayAs: today)
            && calendar.isDate(displayedMonth, equalTo: today, toGranularity: .month)
    }

    /// All-day events first, then timed events by start time.
    var selectedDayEvents: [CalendarEvent] {
        dayEvents(on: selectedDate)
    }

    func dayEvents(on date: Date) -> [CalendarEvent] {
        (eventsByDay[calendar.startOfDay(for: date)] ?? []).sorted { lhs, rhs in
            if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
            if lhs.startDate != rhs.startDate { return lhs.startDate < rhs.startDate }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    // MARK: - Busyness & Free Slots

    func eventCount(on date: Date) -> Int {
        eventsByDay[calendar.startOfDay(for: date)]?.count ?? 0
    }

    /// Returns a 0...1 busyness score for the given date (4+ events = fully busy).
    func busynessScore(on date: Date) -> Double {
        min(Double(eventCount(on: date)) / 4, 1)
    }

    /// The visible window (8am–10pm) of the selected day.
    var selectedDayWindow: DateInterval {
        let start = calendar.date(bySettingHour: Self.dayStartHour, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        let end = calendar.date(bySettingHour: Self.dayEndHour, minute: 0, second: 0, of: selectedDate) ?? start
        return DateInterval(start: start, end: max(start, end))
    }

    /// Free time slots of at least 30 minutes between timed events within the visible window.
    var selectedDayFreeSlots: [TimeSlot] {
        let window = selectedDayWindow
        let timedEvents = selectedDayEvents
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }

        var slots: [TimeSlot] = []
        var cursor = window.start

        for event in timedEvents {
            let eventStart = min(max(event.startDate, window.start), window.end)
            let eventEnd = min(max(event.endDate, window.start), window.end)
            if cursor < eventStart {
                slots.append(TimeSlot(start: cursor, end: eventStart))
            }
            cursor = max(cursor, eventEnd)
        }

        if cursor < window.end {
            slots.append(TimeSlot(start: cursor, end: window.end))
        }

        return slots.filter { $0.duration >= Self.minimumFreeSlot }
    }

    // MARK: - Queries

    func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    func hasEvents(on date: Date) -> Bool {
        eventCount(on: date) > 0
    }

    // MARK: - Navigation

    func nextMonth() {
        showMonth(monthOffset(1))
    }

    func previousMonth() {
        showMonth(monthOffset(-1))
    }

    func goToToday() {
        refreshToday()
        showMonth(today, selecting: today)
    }

    /// Selects a day; tapping a day of an adjacent month jumps to that month.
    func selectDate(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        if calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month) {
            selectedDate = day
        } else {
            showMonth(day, selecting: day)
        }
    }

    /// Call when the day may have changed (app activation, midnight, time zone change).
    func refreshToday() {
        if calendar.timeZone != TimeZone.current {
            calendar = Self.makeCalendar(startsWeekOnMonday: startsWeekOnMonday)
            selectedDate = calendar.startOfDay(for: selectedDate)
            displayedMonth = Self.startOfMonth(displayedMonth, in: calendar)
            rebuildDayIndex()
        }
        let newToday = calendar.startOfDay(for: Date())
        if newToday != today { today = newToday }
    }

    private func showMonth(_ month: Date, selecting date: Date? = nil) {
        let start = Self.startOfMonth(month, in: calendar)
        let monthChanged = start != displayedMonth
        displayedMonth = start

        if let date {
            selectedDate = calendar.startOfDay(for: date)
        } else if monthChanged {
            // Keep the selection inside the visible month so the detail panel matches the grid.
            let isCurrentMonth = calendar.isDate(today, equalTo: start, toGranularity: .month)
            selectedDate = isCurrentMonth ? today : start
        }

        if monthChanged { reloadEvents() }
    }

    // MARK: - Calendar Access

    /// Silently checks if calendar access was already granted (no prompt).
    func checkExistingAccess() async {
        calendarAccessGranted = await repository.checkAccess()
        if calendarAccessGranted {
            loadCalendars()
        }
        await fetchEvents()
    }

    /// Explicitly requests calendar access (shows the system prompt if needed).
    func requestCalendarAccess() async {
        calendarAccessGranted = await repository.requestAccess()
        guard calendarAccessGranted else { return }
        loadCalendars()
        if availableCalendars.count > 1 && selectedCalendarIDs.isEmpty {
            showCalendarPicker = true
        }
        await fetchEvents()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func updateSelectedCalendars(_ ids: Set<String>) {
        let allIDs = Set(availableCalendars.map(\.id))
        // Selecting everything is stored as "all" so newly added calendars show up automatically.
        let normalized = ids.isSuperset(of: allIDs) ? [] : ids.intersection(allIDs)
        selectedCalendarIDs = normalized
        SharedStorage.defaults.set(Array(normalized), forKey: SharedStorage.selectedCalendarsKey)
        WidgetCenter.shared.reloadAllTimelines()
        reloadEvents()
    }

    private func loadCalendars() {
        availableCalendars = repository.availableCalendars()
        let saved = Set(SharedStorage.defaults.stringArray(forKey: SharedStorage.selectedCalendarsKey) ?? [])
        // Drop calendars that no longer exist; an empty result falls back to "all".
        selectedCalendarIDs = saved.intersection(availableCalendars.map(\.id))
    }

    // MARK: - Fetching

    /// Starts a fetch, cancelling any in-flight one.
    func reloadEvents() {
        fetchTask?.cancel()
        fetchTask = Task { await fetchEvents() }
    }

    /// Fetches the displayed month plus its neighbours, so swiping between months shows data immediately.
    func fetchEvents() async {
        fetchGeneration += 1
        let generation = fetchGeneration

        let start = Self.startOfMonth(monthOffset(-1), in: calendar)
        let end = calendar.date(byAdding: .month, value: 2, to: displayedMonth) ?? displayedMonth

        var merged: [CalendarEvent] = []
        if calendarAccessGranted {
            let ids: Set<String>? = selectedCalendarIDs.isEmpty ? nil : selectedCalendarIDs
            merged += await repository.fetchEvents(from: start, to: end, calendarIDs: ids)
        }
        merged += localStore.fetchEvents(from: start, to: end)

        // A newer fetch started while we were waiting; its result wins.
        guard generation == fetchGeneration, !Task.isCancelled else { return }
        events = merged
    }

    private func rebuildDayIndex() {
        var index: [Date: [CalendarEvent]] = [:]
        for event in events {
            var day = calendar.startOfDay(for: event.startDate)
            // Cap long-running events so a single multi-year event can't stall the index.
            var remaining = 62
            repeat {
                index[day, default: []].append(event)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
                remaining -= 1
            } while day < event.endDate && remaining > 0
        }
        eventsByDay = index
    }

    // MARK: - Event Management

    @discardableResult
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        notes: String?,
        isAllDay: Bool,
        reminderMinutes: Int? = nil
    ) async throws -> CalendarEvent {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { throw EventError.emptyTitle }

        var start = startDate
        var end = endDate
        if isAllDay {
            // All-day events span whole days: [start of first day, start of the day after the last day).
            start = calendar.startOfDay(for: startDate)
            let lastDay = calendar.startOfDay(for: endDate)
            guard lastDay >= start else { throw EventError.endBeforeStart }
            end = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
        } else if endDate < startDate {
            throw EventError.endBeforeStart
        }

        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let event = CalendarEvent(
            title: trimmedTitle,
            startDate: start,
            endDate: end,
            isAllDay: isAllDay,
            notes: trimmedNotes?.isEmpty == false ? trimmedNotes : nil,
            isLocal: true
        )

        do {
            try localStore.addEvent(event)
        } catch {
            throw EventError.saveFailed("Couldn't save the event. \(error.localizedDescription)")
        }

        if let reminderMinutes {
            await reminders.scheduleReminder(for: event, minutesBefore: reminderMinutes)
        }

        await fetchEvents()
        WidgetCenter.shared.reloadAllTimelines()
        return event
    }

    func deleteEvent(id: String) async throws {
        do {
            try localStore.deleteEvent(id: id)
        } catch {
            throw EventError.saveFailed("Couldn't delete the event. \(error.localizedDescription)")
        }
        reminders.cancelReminder(forEventID: id)
        await fetchEvents()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
