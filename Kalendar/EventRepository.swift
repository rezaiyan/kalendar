//
//  EventRepository.swift
//  Kalendar
//
//  Event model, error types, and repository abstraction for calendar events
//

import Foundation
import EventKit
import UIKit

// MARK: - Shared Storage

enum SharedStorage {
    static let appGroupID = "group.com.alirezaiyan.Kalendar"
    static let selectedCalendarsKey = "selectedCalendarIDs"
    static let startOfWeekMondayKey = "startOfWeekMonday"
    static let localEventsFileName = "local_events.json"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    /// Week starts on Monday unless the user explicitly turned it off.
    static var startsWeekOnMonday: Bool {
        defaults.object(forKey: startOfWeekMondayKey) as? Bool ?? true
    }

    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? URL.documentsDirectory
    }
}

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
            "Event title cannot be empty"
        case .endBeforeStart:
            "End date must be after start date"
        case .saveFailed(let message):
            message
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
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? SharedStorage.containerURL.appendingPathComponent(SharedStorage.localEventsFileName)
    }

    func loadEvents() -> [CalendarEvent] {
        guard let data = try? Data(contentsOf: fileURL),
              let events = try? JSONDecoder().decode([CalendarEvent].self, from: data) else {
            return []
        }
        return events
    }

    func saveEvents(_ events: [CalendarEvent]) throws {
        let data = try JSONEncoder().encode(events)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func addEvent(_ event: CalendarEvent) throws {
        var events = loadEvents()
        events.append(event)
        try saveEvents(events)
    }

    func deleteEvent(id: String) throws {
        var events = loadEvents()
        events.removeAll { $0.id == id }
        try saveEvents(events)
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

    /// A store created before access was granted never sees calendars, so recreate it once.
    private func refreshStoreIfNeeded() {
        guard !hasRefreshedStore else { return }
        store = EKEventStore()
        hasRefreshedStore = true
    }

    func checkAccess() async -> Bool {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return false }
        refreshStoreIfNeeded()
        return true
    }

    func requestAccess() async -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            let granted = (try? await store.requestFullAccessToEvents()) ?? false
            if granted { refreshStoreIfNeeded() }
            return granted
        case .fullAccess:
            refreshStoreIfNeeded()
            return true
        default:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                await UIApplication.shared.open(url)
            }
            return false
        }
    }

    func availableCalendars() -> [CalendarSource] {
        store.calendars(for: .event)
            .map { cal in
                CalendarSource(
                    id: cal.calendarIdentifier,
                    title: cal.title,
                    colorHex: cal.cgColor.hexString,
                    accountName: cal.source?.title ?? ""
                )
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func fetchEvents(from start: Date, to end: Date, calendarIDs: Set<String>?) async -> [CalendarEvent] {
        let store = self.store
        let selected = calendarIDs.map { ids in
            store.calendars(for: .event).filter { ids.contains($0.calendarIdentifier) }
        }
        // A selection whose calendars no longer exist falls back to all calendars (`nil`), matching the widget.
        let calendars = selected?.isEmpty == false ? selected : nil

        return await Task.detached(priority: .userInitiated) {
            let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
            return store.events(matching: predicate).map { ek in
                // Occurrences of a recurring event share one identifier; make each occurrence unique.
                let baseID = ek.eventIdentifier ?? ek.calendarItemIdentifier
                let title = ek.title ?? ""
                return CalendarEvent(
                    id: "\(baseID)@\(Int(ek.startDate.timeIntervalSince1970))",
                    title: title.isEmpty ? "Untitled" : title,
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
    /// sRGB hex string; converts grayscale / P3 colors first so every calendar keeps its real color.
    var hexString: String {
        let srgb = CGColorSpace(name: CGColorSpace.sRGB).flatMap {
            converted(to: $0, intent: .defaultIntent, options: nil)
        } ?? self
        guard let components = srgb.components, components.count >= 3 else { return "#007AFF" }
        func channel(_ value: CGFloat) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", channel(components[0]), channel(components[1]), channel(components[2]))
    }
}
