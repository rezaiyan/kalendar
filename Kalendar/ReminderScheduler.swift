//
//  ReminderScheduler.swift
//  Kalendar
//
//  Local notification reminders for app-created events
//

import Foundation
import UserNotifications

@MainActor
protocol ReminderScheduling {
    func scheduleReminder(for event: CalendarEvent, minutesBefore: Int) async
    func cancelReminder(forEventID id: String)
}

/// Used by tests and previews.
struct NoopReminderScheduler: ReminderScheduling {
    func scheduleReminder(for event: CalendarEvent, minutesBefore: Int) async {}
    func cancelReminder(forEventID id: String) {}
}

@MainActor
struct NotificationReminderScheduler: ReminderScheduling {
    private var center: UNUserNotificationCenter { .current() }

    /// Hour at which all-day event reminders fire on the day of the event.
    static let allDayReminderHour = 9

    /// Requests permission on first use; silently skips reminders that would fire in the past.
    func scheduleReminder(for event: CalendarEvent, minutesBefore: Int) async {
        let fireDate = Self.fireDate(for: event, minutesBefore: minutesBefore)
        guard fireDate > Date(), await isAuthorized() else { return }

        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = Self.body(for: event, minutesBefore: minutesBefore)
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        // The event ID is the request ID, so deleting the event can cancel its reminder.
        let request = UNNotificationRequest(identifier: event.id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func cancelReminder(forEventID id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    private func isAuthorized() async -> Bool {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    static func fireDate(for event: CalendarEvent, minutesBefore: Int) -> Date {
        if event.isAllDay {
            return Calendar.current.date(bySettingHour: allDayReminderHour, minute: 0, second: 0, of: event.startDate)
                ?? event.startDate
        }
        return event.startDate.addingTimeInterval(-TimeInterval(minutesBefore * 60))
    }

    private static func body(for event: CalendarEvent, minutesBefore: Int) -> String {
        if event.isAllDay {
            return "Today · All day"
        }
        let time = event.startDate.formatted(date: .omitted, time: .shortened)
        return minutesBefore == 0 ? "Starting now · \(time)" : "Starts in \(ReminderOption.label(for: minutesBefore)) · \(time)"
    }
}

// MARK: - Reminder Options

enum ReminderOption {
    static let minutes = [0, 5, 10, 15, 30, 60, 120, 1440]

    static func label(for minutes: Int) -> String {
        switch minutes {
        case 0: return "At time of event"
        case 1440: return "1 day"
        default:
            let duration = Duration.seconds(minutes * 60)
            return duration.formatted(.units(allowed: [.hours, .minutes], width: .wide))
        }
    }
}
