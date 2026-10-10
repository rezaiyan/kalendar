//
//  EventTests.swift
//  KalendarTests
//
//  TDD tests for event management
//

import Testing
import Foundation
@testable import Kalendar

// MARK: - Test Helpers

@MainActor
private func makeTestVM() -> (CalendarViewModel, MockEventRepository) {
    let repo = MockEventRepository()
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
    let localStore = LocalEventStore(fileURL: tempURL)
    let vm = CalendarViewModel(eventRepository: repo, localEventStore: localStore)
    vm.calendarAccessGranted = true
    return (vm, repo)
}

// MARK: - Mock Event Repository

@MainActor
final class MockEventRepository: EventRepository {
    var events: [CalendarEvent] = []
    var accessGranted = true

    func checkAccess() async -> Bool {
        accessGranted
    }

    func requestAccess() async -> Bool {
        accessGranted
    }

    func availableCalendars() -> [CalendarSource] {
        []
    }

    func fetchEvents(from start: Date, to end: Date, calendarIDs: Set<String>? = nil) async -> [CalendarEvent] {
        events.filter { event in
            event.startDate < end && event.endDate > start
        }
    }
}

// MARK: - Event Creation Tests

@Suite("Event Creation")
struct EventCreationTests {

    @Test("Creating event with valid data adds it to the event list")
    @MainActor
    func createValidEvent() async throws {
        let (vm, _) = makeTestVM()

        let start = Date()
        let end = start.addingTimeInterval(3600)

        try await vm.createEvent(title: "Team Meeting", startDate: start, endDate: end, notes: nil, isAllDay: false)

        #expect(vm.events.count == 1)
        #expect(vm.events.first?.title == "Team Meeting")
        #expect(vm.events.first?.isLocal == true)
    }

    @Test("Creating event with empty title throws emptyTitle error")
    @MainActor
    func createEventEmptyTitle() async {
        let (vm, _) = makeTestVM()

        let start = Date()
        let end = start.addingTimeInterval(3600)

        do {
            try await vm.createEvent(title: "", startDate: start, endDate: end, notes: nil, isAllDay: false)
            Issue.record("Expected emptyTitle error")
        } catch let error as EventError {
            #expect(error == .emptyTitle)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(vm.events.isEmpty)
    }

    @Test("Creating event with whitespace-only title throws emptyTitle error")
    @MainActor
    func createEventWhitespaceTitle() async {
        let (vm, _) = makeTestVM()

        let start = Date()
        let end = start.addingTimeInterval(3600)

        do {
            try await vm.createEvent(title: "   ", startDate: start, endDate: end, notes: nil, isAllDay: false)
            Issue.record("Expected emptyTitle error")
        } catch let error as EventError {
            #expect(error == .emptyTitle)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(vm.events.isEmpty)
    }

    @Test("Creating event where end date is before start date throws endBeforeStart error")
    @MainActor
    func createEventEndBeforeStart() async {
        let (vm, _) = makeTestVM()

        let start = Date()
        let end = start.addingTimeInterval(-3600)

        do {
            try await vm.createEvent(title: "Meeting", startDate: start, endDate: end, notes: nil, isAllDay: false)
            Issue.record("Expected endBeforeStart error")
        } catch let error as EventError {
            #expect(error == .endBeforeStart)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(vm.events.isEmpty)
    }

    @Test("All-day event allows same start and end date without error")
    @MainActor
    func createAllDayEvent() async throws {
        let (vm, _) = makeTestVM()

        let date = Date()

        try await vm.createEvent(title: "Holiday", startDate: date, endDate: date, notes: nil, isAllDay: true)

        #expect(vm.events.count == 1)
        #expect(vm.events.first?.isAllDay == true)
        #expect(vm.events.first?.title == "Holiday")
    }

    @Test("Event stores notes correctly")
    @MainActor
    func createEventWithNotes() async throws {
        let (vm, _) = makeTestVM()

        let start = Date()
        let end = start.addingTimeInterval(3600)

        try await vm.createEvent(title: "Meeting", startDate: start, endDate: end, notes: "Bring laptop", isAllDay: false)

        #expect(vm.events.first?.notes == "Bring laptop")
    }

    @Test("Creating multiple events preserves all of them")
    @MainActor
    func createMultipleEvents() async throws {
        let (vm, _) = makeTestVM()

        let start = Date()
        let end = start.addingTimeInterval(3600)

        try await vm.createEvent(title: "Event 1", startDate: start, endDate: end, notes: nil, isAllDay: false)
        try await vm.createEvent(title: "Event 2", startDate: start, endDate: end, notes: nil, isAllDay: false)
        try await vm.createEvent(title: "Event 3", startDate: start, endDate: end, notes: nil, isAllDay: false)

        #expect(vm.events.count == 3)
    }
}

// MARK: - Event Deletion Tests

@Suite("Event Deletion")
struct EventDeletionTests {

    @Test("Deleting event removes it from the list")
    @MainActor
    func deleteEvent() async throws {
        let (vm, _) = makeTestVM()

        let start = Date()
        let end = start.addingTimeInterval(3600)
        try await vm.createEvent(title: "To Delete", startDate: start, endDate: end, notes: nil, isAllDay: false)
        #expect(vm.events.count == 1)

        let eventId = vm.events.first!.id
        try await vm.deleteEvent(id: eventId)

        #expect(vm.events.isEmpty)
    }

    @Test("Deleting one event keeps others intact")
    @MainActor
    func deleteOneOfMany() async throws {
        let (vm, _) = makeTestVM()

        let start = Date()
        let end = start.addingTimeInterval(3600)
        try await vm.createEvent(title: "Keep", startDate: start, endDate: end, notes: nil, isAllDay: false)
        try await vm.createEvent(title: "Delete", startDate: start, endDate: end, notes: nil, isAllDay: false)

        let deleteId = vm.events.first { $0.title == "Delete" }!.id
        try await vm.deleteEvent(id: deleteId)

        #expect(vm.events.count == 1)
        #expect(vm.events.first?.title == "Keep")
    }
}

// MARK: - Event Query Tests

@Suite("Event Queries")
struct EventQueryTests {

    @Test("hasEvents returns true for a date that has events")
    @MainActor
    func hasEventsOnDate() async throws {
        let (vm, _) = makeTestVM()

        let today = Date()
        let start = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: today)!
        let end = start.addingTimeInterval(3600)

        try await vm.createEvent(title: "Morning Meeting", startDate: start, endDate: end, notes: nil, isAllDay: false)
        await vm.fetchEvents()

        #expect(vm.hasEvents(on: today))
    }

    @Test("hasEvents returns false for a date without events")
    @MainActor
    func noEventsOnDate() async throws {
        let (vm, _) = makeTestVM()

        let cal = Calendar.current
        let today = Date()
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

        let start = cal.date(bySettingHour: 10, minute: 0, second: 0, of: today)!
        let end = start.addingTimeInterval(3600)
        try await vm.createEvent(title: "Today Only", startDate: start, endDate: end, notes: nil, isAllDay: false)
        await vm.fetchEvents()

        #expect(!vm.hasEvents(on: tomorrow))
    }

    @Test("selectedDayEvents only returns events for the selected date")
    @MainActor
    func selectedDayEventsFiltered() async throws {
        let (vm, _) = makeTestVM()

        let cal = Calendar.current
        let today = Date()
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

        let s1 = cal.date(bySettingHour: 10, minute: 0, second: 0, of: today)!
        try await vm.createEvent(title: "Today Event", startDate: s1, endDate: s1.addingTimeInterval(3600), notes: nil, isAllDay: false)

        let s2 = cal.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow)!
        try await vm.createEvent(title: "Tomorrow Event", startDate: s2, endDate: s2.addingTimeInterval(3600), notes: nil, isAllDay: false)

        vm.selectDate(today)
        await vm.fetchEvents()

        #expect(vm.selectedDayEvents.count == 1)
        #expect(vm.selectedDayEvents.first?.title == "Today Event")
    }

    @Test("selectedDayEvents are sorted by start time")
    @MainActor
    func selectedDayEventsSorted() async throws {
        let (vm, _) = makeTestVM()

        let cal = Calendar.current
        let today = Date()

        let afternoon = cal.date(bySettingHour: 14, minute: 0, second: 0, of: today)!
        try await vm.createEvent(title: "Afternoon", startDate: afternoon, endDate: afternoon.addingTimeInterval(3600), notes: nil, isAllDay: false)

        let morning = cal.date(bySettingHour: 9, minute: 0, second: 0, of: today)!
        try await vm.createEvent(title: "Morning", startDate: morning, endDate: morning.addingTimeInterval(3600), notes: nil, isAllDay: false)

        vm.selectDate(today)
        await vm.fetchEvents()

        #expect(vm.selectedDayEvents.count == 2)
        #expect(vm.selectedDayEvents[0].title == "Morning")
        #expect(vm.selectedDayEvents[1].title == "Afternoon")
    }
}

// MARK: - Regression Tests

@Suite("Calendar Behaviour")
struct CalendarBehaviourTests {

    @Test("All-day events are normalized to whole days")
    @MainActor
    func allDayEventSpansWholeDays() async throws {
        let (vm, _) = makeTestVM()
        let cal = vm.calendar
        let afternoon = cal.date(bySettingHour: 15, minute: 30, second: 0, of: Date())!

        let event = try await vm.createEvent(title: "Trip", startDate: afternoon, endDate: afternoon, notes: nil, isAllDay: true)

        #expect(event.startDate == cal.startOfDay(for: afternoon))
        #expect(event.endDate == cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: afternoon)))
    }

    @Test("All-day event whose last day is before its first day is rejected")
    @MainActor
    func allDayEndBeforeStart() async {
        let (vm, _) = makeTestVM()
        let today = Date()
        let yesterday = vm.calendar.date(byAdding: .day, value: -1, to: today)!

        await #expect(throws: EventError.endBeforeStart) {
            try await vm.createEvent(title: "Trip", startDate: today, endDate: yesterday, notes: nil, isAllDay: true)
        }
    }

    @Test("Multi-day events appear on every day they span")
    @MainActor
    func multiDayEventOnEachDay() async throws {
        let (vm, _) = makeTestVM()
        let cal = vm.calendar
        let start = cal.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
        let end = cal.date(byAdding: .hour, value: 6, to: start)!

        try await vm.createEvent(title: "Night Shift", startDate: start, endDate: end, notes: nil, isAllDay: false)

        let nextDay = cal.date(byAdding: .day, value: 1, to: start)!
        #expect(vm.hasEvents(on: start))
        #expect(vm.hasEvents(on: nextDay))
    }

    @Test("Changing month keeps the selected day inside the displayed month")
    @MainActor
    func navigationKeepsSelectionInMonth() {
        let (vm, _) = makeTestVM()

        vm.nextMonth()
        #expect(vm.calendar.isDate(vm.selectedDate, equalTo: vm.displayedMonth, toGranularity: .month))

        vm.previousMonth()
        vm.previousMonth()
        #expect(vm.calendar.isDate(vm.selectedDate, equalTo: vm.displayedMonth, toGranularity: .month))

        vm.goToToday()
        #expect(vm.isShowingToday)
    }

    @Test("Selecting a day of an adjacent month navigates to that month")
    @MainActor
    func selectingAdjacentMonthDayNavigates() {
        let (vm, _) = makeTestVM()
        let nextMonthDay = vm.calendar.date(byAdding: .month, value: 1, to: vm.displayedMonth)!

        vm.selectDate(nextMonthDay)

        #expect(vm.calendar.isDate(vm.displayedMonth, equalTo: nextMonthDay, toGranularity: .month))
        #expect(vm.isSelected(nextMonthDay))
    }

    @Test("Month grid always has 6 full weeks starting on the first weekday", arguments: [true, false])
    @MainActor
    func gridStartsOnFirstWeekday(startsMonday: Bool) {
        let (vm, _) = makeTestVM()
        let original = vm.startsWeekOnMonday
        defer { vm.startsWeekOnMonday = original }

        vm.startsWeekOnMonday = startsMonday

        for offset in 0..<12 {
            let days = vm.calendarDays(for: vm.monthOffset(offset))
            #expect(days.count == 42)
            #expect(vm.calendar.component(.weekday, from: days[0].date) == (startsMonday ? 2 : 1))
            #expect(Set(days.map(\.id)).count == 42)
        }
        #expect(vm.weekdaySymbols.first == vm.calendar.shortStandaloneWeekdaySymbols[startsMonday ? 1 : 0])
    }

    @Test("Free slots skip time taken by events")
    @MainActor
    func freeSlotsAroundEvents() async throws {
        let (vm, _) = makeTestVM()
        let cal = vm.calendar
        let today = Date()
        let tenAM = cal.date(bySettingHour: 10, minute: 0, second: 0, of: today)!
        let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: today)!

        try await vm.createEvent(title: "Focus", startDate: tenAM, endDate: noon, notes: nil, isAllDay: false)
        vm.selectDate(today)

        let slots = vm.selectedDayFreeSlots
        #expect(slots.count == 2)
        #expect(slots.first?.end == tenAM)
        #expect(slots.last?.start == noon)
    }
}
