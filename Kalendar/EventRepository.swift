//
//  EventRepository.swift
//  Kalendar
//
//  Event model, error types, and repository abstraction for calendar events
//

import Foundation
import EventKit
import UIKit

// MARK: - Calendar Event Model

struct CalendarEvent: Identifiable, Equatable {
    let id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var notes: String?
    var calendarColorHex: String?

    init(id: String = UUID().uuidString, title: String, startDate: Date, endDate: Date, isAllDay: Bool, notes: String? = nil, calendarColorHex: String? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.notes = notes
        self.calendarColorHex = calendarColorHex
    }
}

// MARK: - Event Errors

enum EventError: LocalizedError, Equatable {
    case emptyTitle
    case endBeforeStart
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Event title cannot be empty"
        case .endBeforeStart:
            return "End date must be after start date"
        case .saveFailed(let message):
            return message
        }
    }
}

// MARK: - Event Repository Protocol

@MainActor
protocol EventRepository {
    func requestAccess() async -> Bool
    func fetchEvents(from start: Date, to end: Date) -> [CalendarEvent]
    func createEvent(_ event: CalendarEvent) throws
    func deleteEvent(id: String) throws
}

// MARK: - EventKit Repository (Production)

@MainActor
final class EKEventRepository: EventRepository {
    private var store = EKEventStore()

    private var hasRefreshedStore = false

    func requestAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .notDetermined:
            let granted = (try? await store.requestFullAccessToEvents()) ?? false
            if granted {
                store = EKEventStore()
                hasRefreshedStore = true
            }
            return granted
        case .fullAccess:
            if !hasRefreshedStore {
                store = EKEventStore()
                hasRefreshedStore = true
            }
            return true
        default:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                await UIApplication.shared.open(url)
            }
            return false
        }
    }

    func fetchEvents(from start: Date, to end: Date) -> [CalendarEvent] {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).map { ek in
            CalendarEvent(
                id: ek.eventIdentifier,
                title: ek.title ?? "Untitled",
                startDate: ek.startDate,
                endDate: ek.endDate,
                isAllDay: ek.isAllDay,
                notes: ek.notes,
                calendarColorHex: ek.calendar.cgColor.hexString
            )
        }
    }

    func createEvent(_ event: CalendarEvent) throws {
        guard let calendar = store.defaultCalendarForNewEvents ?? store.calendars(for: .event).first else {
            throw EventError.saveFailed("No calendar available. Please add a calendar account in System Settings > Internet Accounts.")
        }
        let ek = EKEvent(eventStore: store)
        ek.title = event.title
        ek.startDate = event.startDate
        ek.endDate = event.endDate
        ek.isAllDay = event.isAllDay
        ek.notes = event.notes
        ek.calendar = calendar
        try store.save(ek, span: .thisEvent)
    }

    func deleteEvent(id: String) throws {
        guard let ek = store.event(withIdentifier: id) else { return }
        try store.remove(ek, span: .thisEvent)
    }
}

// MARK: - CGColor Hex Helper

private extension CGColor {
    var hexString: String {
        guard let components = components, components.count >= 3 else { return "#007AFF" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
