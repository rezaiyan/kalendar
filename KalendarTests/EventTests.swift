//
//  EventTests.swift
//  KalendarTests
//
//  TDD tests for event management
//

import Testing
import Foundation
@testable import Kalendar

// MARK: - Mock Event Repository

@MainActor
final class MockEventRepository: EventRepository {
    var events: [CalendarEvent] = []
    var accessGranted = true
    var shouldFailOnSave = false

    func requestAccess() async -> Bool {
        accessGranted
    }

    func fetchEvents(from start: Date, to end: Date) -> [CalendarEvent] {
        events.filter { event in
            event.startDate < end && event.endDate > start
        }
    }

    func createEvent(_ event: CalendarEvent) throws {
        if shouldFailOnSave {
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Save failed"])
        }
        events.append(event)
    }

    func deleteEvent(id: String) throws {
        events.removeAll { $0.id == id }
    }
}

// MARK: - Event Creation Tests

@Suite("Event Creation")
struct EventCreationTests {

    @Test("Creating event with valid data adds it to the event list")
    @MainActor
    func createValidEvent() async throws {
        let repo = MockEventRepository()
        let vm = CalendarViewModel(eventRepository: repo)
        vm.calendarAccessGranted = true

        let start = Date()
        let end = start.addingTimeInterval(3600)

        try vm.createEvent(title: "Team Meeting", startDate: start, endDate: end, notes: nil, isAllDay: false)

        #expect(repo.events.count == 1)
        #expect(repo.events.first?.title == "Team Meeting")
    }

    @Test("Creating event with empty title throws emptyTitle error")
    @MainActor
    func createEventEmptyTitle() async {
        let repo = MockEventRepository()
        let vm = CalendarViewModel(eventRepository: repo)
        vm.calendarAccessGranted = true

        let start = Date()
        let end = start.addingTimeInterval(3600)

        #expect(throws: EventError.emptyTitle) {
            try vm.createEvent(title: "", startDate: start, endDate: end, notes: nil, isAllDay: false)
        }
        #expect(repo.events.isEmpty)
    }

    @Test("Creating event with whitespace-only title throws emptyTitle error")
    @MainActor
    func createEventWhitespaceTitle() async {
        let repo = MockEventRepository()
        let vm = CalendarViewModel(eventRepository: repo)
        vm.calendarAccessGranted = true

        let start = Date()
        let end = start.addingTimeInterval(3600)

        #expect(throws: EventError.emptyTitle) {
            try vm.createEvent(title: "   ", startDate: start, endDate: end, notes: nil, isAllDay: false)
        }
        #expect(repo.events.isEmpty)
    }

    @Test("Creating event where end date is before start date throws endBeforeStart error")
    @MainActor
    func createEventEndBeforeStart() async {
        let repo = MockEventRepository()
        let vm = CalendarViewModel(eventRepository: repo)
        vm.calendarAccessGranted = true

        let start = Date()
        let end = start.addingTimeInterval(-3600)

        #expect(throws: EventError.endBeforeStart) {
            try vm.createEvent(title: "Meeting", startDate: start, endDate: end, notes: nil, isAllDay: false)
        }
        #expect(repo.events.isEmpty)
    }

    @Test("All-day event allows same start and end date without error")
    @MainActor
    func createAllDayEvent() async throws {
        let repo = MockEventRepository()
        let vm = CalendarViewModel(eventRepository: repo)
        vm.calendarAccessGranted = true

        let date = Date()

        try vm.createEvent(title: "Holiday", startDate: date, endDate: date, notes: nil, isAllDay: true)

        #expect(repo.events.count == 1)
        #expect(repo.events.first?.isAllDay == true)
        #expect(repo.events.first?.title == "Holiday")
    }

    @Test("Event stores notes correctly")
    @MainActor
    func createEventWithNotes() async throws {
        let repo = MockEventRepository()
        let vm = CalendarViewModel(eventRepository: repo)
        vm.calendarAccessGranted = true

        let start = Date()
        let end = start.addingTimeInterval(3600)

        try vm.createEvent(title: "Meeting", startDate: start, endDate: end, notes: "Bring laptop", isAllDay: false)

        #expect(repo.events.first?.notes == "Bring laptop")
    }

    @Test("Creating multiple events preserves all of them")
    @MainActor
    func createMultipleEvents() async throws {
        let repo = MockEventRepository()
        let vm = CalendarViewModel(eventRepository: repo)
        vm.calendarAccessGranted = true

        let start = Date()
        let end = start.addingTimeInterval(3600)

        try vm.createEvent(title: "Event 1", startDate: start, endDate: end, notes: nil, isAllDay: false)
        try vm.createEvent(title: "Event 2", startDate: start, endDate: end, notes: nil, isAllDay: false)
        try vm.createEvent(title: "Event 3", startDate: start, endDate: end, notes: nil, isAllDay: false)

        #expect(repo.events.count == 3)
    }

    @Test("Repository save failure propagates as saveFailed error")
    @MainActor
    func createEventRepoFailure() async {
        let repo = MockEventRepository()
        repo.shouldFailOnSave = true
        let vm = CalendarViewModel(eventRepository: repo)
        vm.calendarAccessGranted = true

        let start = Date()
        let end = start.addingTimeInterval(3600)

        #expect(throws: EventError.self) {
            try vm.createEvent(title: "Meeting", startDate: start, endDate: end, notes: nil, isAllDay: false)
        }
    }
}

// MARK: - Event Deletion Tests

@Suite("Event Deletion")
struct EventDeletionTests {

    @Test("Deleting event removes it from the list")
    @MainActor
    func deleteEvent() async throws {
        let repo = MockEventRepository()
        let vm = CalendarViewModel(eventRepository: repo)
        vm.calendarAccessGranted = true

        let start = Date()
        let end = start.addingTimeInterval(3600)
        try vm.createEvent(title: "To Delete", startDate: start, endDate: end, notes: nil, isAllDay: false)
        #expect(repo.events.count == 1)

        let eventId = repo.events.first!.id
        try vm.deleteEvent(id: eventId)

        #expect(repo.events.isEmpty)
    }

    @Test("Deleting one event keeps others intact")
    @MainActor
    func deleteOneOfMany() async throws {
        let repo = MockEventRepository()
        let vm = CalendarViewModel(eventRepository: repo)
        vm.calendarAccessGranted = true

        let start = Date()
        let end = start.addingTimeInterval(3600)
        try vm.createEvent(title: "Keep", startDate: start, endDate: end, notes: nil, isAllDay: false)
        try vm.createEvent(title: "Delete", startDate: start, endDate: end, notes: nil, isAllDay: false)

        let deleteId = repo.events.first { $0.title == "Delete" }!.id
        try vm.deleteEvent(id: deleteId)

        #expect(repo.events.count == 1)
        #expect(repo.events.first?.title == "Keep")
    }
}

// MARK: - Event Query Tests

@Suite("Event Queries")
struct EventQueryTests {

    @Test("hasEvents returns true for a date that has events")
    @MainActor
    func hasEventsOnDate() async throws {
        let repo = MockEventRepository()
        let vm = CalendarViewModel(eventRepository: repo)
        vm.calendarAccessGranted = true

        let today = Date()
        let start = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: today)!
        let end = start.addingTimeInterval(3600)

        try vm.createEvent(title: "Morning Meeting", startDate: start, endDate: end, notes: nil, isAllDay: false)
        vm.fetchEvents()

        #expect(vm.hasEvents(on: today))
    }

    @Test("hasEvents returns false for a date without events")
    @MainActor
    func noEventsOnDate() async throws {
        let repo = MockEventRepository()
        let vm = CalendarViewModel(eventRepository: repo)
        vm.calendarAccessGranted = true

        let cal = Calendar.current
        let today = Date()
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

        let start = cal.date(bySettingHour: 10, minute: 0, second: 0, of: today)!
        let end = start.addingTimeInterval(3600)
        try vm.createEvent(title: "Today Only", startDate: start, endDate: end, notes: nil, isAllDay: false)
        vm.fetchEvents()

        #expect(!vm.hasEvents(on: tomorrow))
    }

    @Test("selectedDayEvents only returns events for the selected date")
    @MainActor
    func selectedDayEventsFiltered() async throws {
        let repo = MockEventRepository()
        let vm = CalendarViewModel(eventRepository: repo)
        vm.calendarAccessGranted = true

        let cal = Calendar.current
        let today = Date()
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

        let s1 = cal.date(bySettingHour: 10, minute: 0, second: 0, of: today)!
        try vm.createEvent(title: "Today Event", startDate: s1, endDate: s1.addingTimeInterval(3600), notes: nil, isAllDay: false)

        let s2 = cal.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow)!
        try vm.createEvent(title: "Tomorrow Event", startDate: s2, endDate: s2.addingTimeInterval(3600), notes: nil, isAllDay: false)

        vm.selectDate(today)
        vm.fetchEvents()

        #expect(vm.selectedDayEvents.count == 1)
        #expect(vm.selectedDayEvents.first?.title == "Today Event")
    }

    @Test("selectedDayEvents are sorted by start time")
    @MainActor
    func selectedDayEventsSorted() async throws {
        let repo = MockEventRepository()
        let vm = CalendarViewModel(eventRepository: repo)
        vm.calendarAccessGranted = true

        let cal = Calendar.current
        let today = Date()

        let afternoon = cal.date(bySettingHour: 14, minute: 0, second: 0, of: today)!
        try vm.createEvent(title: "Afternoon", startDate: afternoon, endDate: afternoon.addingTimeInterval(3600), notes: nil, isAllDay: false)

        let morning = cal.date(bySettingHour: 9, minute: 0, second: 0, of: today)!
        try vm.createEvent(title: "Morning", startDate: morning, endDate: morning.addingTimeInterval(3600), notes: nil, isAllDay: false)

        vm.selectDate(today)
        vm.fetchEvents()

        #expect(vm.selectedDayEvents.count == 2)
        #expect(vm.selectedDayEvents[0].title == "Morning")
        #expect(vm.selectedDayEvents[1].title == "Afternoon")
    }
}
