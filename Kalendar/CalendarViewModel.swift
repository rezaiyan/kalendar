//
//  CalendarViewModel.swift
//  Kalendar
//
//  Core calendar logic with EventRepository abstraction
//

import Foundation
import Observation
import WidgetKit

struct CalendarDay: Identifiable {
    let id: String
    let date: Date
    let day: Int
    let isCurrentMonth: Bool
    let isToday: Bool
}

@Observable @MainActor
final class CalendarViewModel {
    var displayedMonth = Date()
    var selectedDate = Date()
    var events: [CalendarEvent] = []
    var calendarAccessGranted = false
    var availableCalendars: [CalendarSource] = []
    var selectedCalendarIDs: Set<String> = [] {
        didSet { persistSelectedCalendars() }
    }
    var showCalendarPicker = false

    private let repository: EventRepository
    private let localStore: LocalEventStore
    static let appGroupID = "group.com.alirezaiyan.Kalendar"
    private static let selectedCalendarsKey = "selectedCalendarIDs"

    private static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    private func persistSelectedCalendars() {
        Self.sharedDefaults.set(Array(selectedCalendarIDs), forKey: Self.selectedCalendarsKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func loadSelectedCalendars() {
        if let saved = Self.sharedDefaults.stringArray(forKey: Self.selectedCalendarsKey) {
            selectedCalendarIDs = Set(saved)
        }
    }

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        let defaults = Self.sharedDefaults
        let startMonday = defaults.object(forKey: "startOfWeekMonday") == nil
            ? true
            : defaults.bool(forKey: "startOfWeekMonday")
        cal.firstWeekday = startMonday ? 2 : 1
        return cal
    }

    // Production init
    convenience init() {
        self.init(eventRepository: EKEventRepository(), localEventStore: LocalEventStore())
    }

    // Testable init
    init(eventRepository: EventRepository, localEventStore: LocalEventStore? = nil) {
        self.repository = eventRepository
        self.localStore = localEventStore ?? LocalEventStore()
    }

    // MARK: - Display Properties

    var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    var weekdaySymbols: [String] {
        let symbols = Calendar.current.shortWeekdaySymbols
        if calendar.firstWeekday == 2 {
            return Array(symbols[1...]) + [symbols[0]]
        }
        return symbols
    }

    var calendarDays: [CalendarDay] {
        generateCalendarDays(for: displayedMonth)
    }

    func calendarDays(for month: Date) -> [CalendarDay] {
        generateCalendarDays(for: month)
    }

    func monthTitle(for month: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }

    func monthOffset(_ offset: Int) -> Date {
        calendar.date(byAdding: .month, value: offset, to: displayedMonth) ?? displayedMonth
    }

    var selectedDayEvents: [CalendarEvent] {
        events.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: selectedDate)
        }.sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Busyness & Free Slots

    func eventCount(on date: Date) -> Int {
        events.filter { calendar.isDate($0.startDate, inSameDayAs: date) }.count
    }

    /// Returns a 0...1 busyness score for the given date
    func busynessScore(on date: Date) -> Double {
        let count = eventCount(on: date)
        guard count > 0 else { return 0 }
        // 1 event = 0.25, 2 = 0.5, 3 = 0.75, 4+ = 1.0
        return min(Double(count) / 4.0, 1.0)
    }

    /// Free time slots for the selected day (between non-all-day events, 8am-10pm)
    var selectedDayFreeSlots: [(start: Date, end: Date)] {
        let cal = calendar
        let dayStart = cal.date(bySettingHour: 8, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        let dayEnd = cal.date(bySettingHour: 22, minute: 0, second: 0, of: selectedDate) ?? selectedDate

        let timedEvents = selectedDayEvents
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }

        guard !timedEvents.isEmpty else {
            return [(start: dayStart, end: dayEnd)]
        }

        var slots: [(start: Date, end: Date)] = []
        var cursor = dayStart

        for event in timedEvents {
            let eventStart = max(event.startDate, dayStart)
            let eventEnd = min(event.endDate, dayEnd)

            if cursor < eventStart {
                slots.append((start: cursor, end: eventStart))
            }
            cursor = max(cursor, eventEnd)
        }

        if cursor < dayEnd {
            slots.append((start: cursor, end: dayEnd))
        }

        // Only return slots >= 30 minutes
        return slots.filter { $0.end.timeIntervalSince($0.start) >= 1800 }
    }

    // MARK: - Queries

    func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    func hasEvents(on date: Date) -> Bool {
        events.contains { calendar.isDate($0.startDate, inSameDayAs: date) }
    }

    // MARK: - Navigation

    func nextMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
        Task { await fetchEvents() }
    }

    func previousMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
        Task { await fetchEvents() }
    }

    func goToToday() {
        displayedMonth = Date()
        selectedDate = Date()
        Task { await fetchEvents() }
    }

    func selectDate(_ date: Date) {
        selectedDate = date
    }

    // MARK: - Event Management

    /// Silently checks if calendar access was already granted (no prompt)
    func checkExistingAccess() async {
        calendarAccessGranted = await repository.checkAccess()
        if calendarAccessGranted {
            availableCalendars = repository.availableCalendars()
            loadSelectedCalendars()
            await fetchEvents()
        }
    }

    /// Explicitly requests calendar access (shows system prompt if needed)
    func requestCalendarAccess() async {
        calendarAccessGranted = await repository.requestAccess()
        if calendarAccessGranted {
            availableCalendars = repository.availableCalendars()
            loadSelectedCalendars()
            if selectedCalendarIDs.isEmpty {
                showCalendarPicker = true
            } else {
                await fetchEvents()
            }
        }
    }

    func updateSelectedCalendars(_ ids: Set<String>) {
        selectedCalendarIDs = ids
        Task { await fetchEvents() }
    }

    func fetchEvents() async {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return }
        var merged: [CalendarEvent] = []
        if calendarAccessGranted {
            let ids: Set<String>? = selectedCalendarIDs.isEmpty ? nil : selectedCalendarIDs
            merged += await repository.fetchEvents(from: interval.start, to: interval.end, calendarIDs: ids)
        }
        merged += localStore.fetchEvents(from: interval.start, to: interval.end)
        events = merged
    }

    func createEvent(title: String, startDate: Date, endDate: Date, notes: String?, isAllDay: Bool) async throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else {
            throw EventError.emptyTitle
        }
        if !isAllDay && endDate < startDate {
            throw EventError.endBeforeStart
        }

        let event = CalendarEvent(
            title: trimmedTitle,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            notes: notes,
            isLocal: true
        )

        localStore.addEvent(event)
        await fetchEvents()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func deleteEvent(id: String) async throws {
        localStore.deleteEvent(id: id)
        await fetchEvents()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Calendar Grid Generation

    private func generateCalendarDays(for month: Date) -> [CalendarDay] {
        let cal = calendar
        let startOfMonth = cal.dateInterval(of: .month, for: month)?.start ?? Date()
        let daysInMonth = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        let firstWeekday = cal.component(.weekday, from: startOfMonth)
        let today = Date()

        let offset: Int
        if cal.firstWeekday == 2 {
            offset = firstWeekday == 1 ? 6 : firstWeekday - 2
        } else {
            offset = firstWeekday - 1
        }

        var days: [CalendarDay] = []

        // Previous month padding
        if offset > 0 {
            let prevMonth = cal.date(byAdding: .month, value: -1, to: month)!
            let prevDaysCount = cal.range(of: .day, in: .month, for: prevMonth)?.count ?? 30
            for i in (prevDaysCount - offset + 1)...prevDaysCount {
                let date = cal.date(from: DateComponents(
                    year: cal.component(.year, from: prevMonth),
                    month: cal.component(.month, from: prevMonth),
                    day: i
                ))!
                days.append(CalendarDay(id: "p\(i)", date: date, day: i, isCurrentMonth: false, isToday: false))
            }
        }

        // Current month days
        for i in 1...daysInMonth {
            let date = cal.date(from: DateComponents(
                year: cal.component(.year, from: startOfMonth),
                month: cal.component(.month, from: startOfMonth),
                day: i
            ))!
            days.append(CalendarDay(
                id: "c\(i)",
                date: date,
                day: i,
                isCurrentMonth: true,
                isToday: cal.isDate(date, inSameDayAs: today)
            ))
        }

        // Next month padding to fill grid (up to 42 cells = 6 rows)
        let remaining = 42 - days.count
        if remaining > 0 && remaining <= 14 {
            let nextMonth = cal.date(byAdding: .month, value: 1, to: month)!
            for i in 1...remaining {
                let date = cal.date(from: DateComponents(
                    year: cal.component(.year, from: nextMonth),
                    month: cal.component(.month, from: nextMonth),
                    day: i
                ))!
                days.append(CalendarDay(id: "n\(i)", date: date, day: i, isCurrentMonth: false, isToday: false))
            }
        }

        return days
    }
}
