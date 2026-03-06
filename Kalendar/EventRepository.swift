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

struct CalendarEvent: Identifiable, Equatable, Codable {
    let id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var notes: String?
    var calendarColorHex: String?
    var isLocal: Bool

    init(id: String = UUID().uuidString, title: String, startDate: Date, endDate: Date, isAllDay: Bool, notes: String? = nil, calendarColorHex: String? = nil, isLocal: Bool = false) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.notes = notes
        self.calendarColorHex = calendarColorHex
        self.isLocal = isLocal
    }
}

// MARK: - Calendar Source Model

struct CalendarSource: Identifiable, Hashable {
    let id: String
    let title: String
    let colorHex: String
    let accountName: String
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

// MARK: - Event Repository Protocol (read-only from system calendars)

@MainActor
protocol EventRepository {
    func checkAccess() async -> Bool
    func requestAccess() async -> Bool
    func availableCalendars() -> [CalendarSource]
    func fetchEvents(from start: Date, to end: Date, calendarIDs: Set<String>?) async -> [CalendarEvent]
}

// MARK: - Local Event Store (app-created events)

@MainActor
final class LocalEventStore {
    private static let fileName = "local_events.json"

    private static var defaultFileURL: URL {
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.alirezaiyan.Kalendar"
        ) ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return container.appendingPathComponent(fileName)
    }

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
    }

    func loadEvents() -> [CalendarEvent] {
        guard let data = try? Data(contentsOf: fileURL),
              let events = try? JSONDecoder().decode([CalendarEvent].self, from: data) else {
            return []
        }
        return events
    }

    func saveEvents(_ events: [CalendarEvent]) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func addEvent(_ event: CalendarEvent) {
        var events = loadEvents()
        events.append(event)
        saveEvents(events)
    }

    func deleteEvent(id: String) {
        var events = loadEvents()
        events.removeAll { $0.id == id }
        saveEvents(events)
    }

    func fetchEvents(from start: Date, to end: Date) -> [CalendarEvent] {
        loadEvents().filter { $0.startDate < end && $0.endDate > start }
    }
}

// MARK: - EventKit Repository (read-only)

@MainActor
final class EKEventRepository: EventRepository {
    private var store = EKEventStore()
    private var hasRefreshedStore = false

    func checkAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .fullAccess {
            if !hasRefreshedStore {
                store = EKEventStore()
                hasRefreshedStore = true
            }
            return true
        }
        return false
    }

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

    func availableCalendars() -> [CalendarSource] {
        store.calendars(for: .event).map { cal in
            CalendarSource(
                id: cal.calendarIdentifier,
                title: cal.title,
                colorHex: cal.cgColor.hexString,
                accountName: cal.source?.title ?? ""
            )
        }.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func fetchEvents(from start: Date, to end: Date, calendarIDs: Set<String>?) async -> [CalendarEvent] {
        let store = self.store
        let calendars: [EKCalendar]? = calendarIDs.map { ids in
            store.calendars(for: .event).filter { ids.contains($0.calendarIdentifier) }
        }
        return await Task.detached {
            let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
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
        }.value
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
