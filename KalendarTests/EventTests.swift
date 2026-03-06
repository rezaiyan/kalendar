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
