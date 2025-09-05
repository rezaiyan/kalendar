//
//  NotificationManager.swift
//  Kalendar
//
//  Created by Ali Rezaiyan on 29.08.25.
//

import Foundation
import UserNotifications
import FirebaseMessaging
import UIKit

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var fcmToken: String?
    
    private init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    func requestAuthorization() {
        print("🔔 NotificationManager: Requesting authorization...")
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]
        
        UNUserNotificationCenter.current().requestAuthorization(options: options) { [weak self] granted, error in
            DispatchQueue.main.async {
                print("🔔 NotificationManager: Authorization result - granted: \(granted)")
                self?.isAuthorized = granted
                if granted {
                    print("🔔 NotificationManager: Registering for remote notifications...")
                    self?.registerForRemoteNotifications()
                } else {
                    print("🔔 NotificationManager: Authorization denied")
                }
            }
            
            if let error = error {
                print("🔔 NotificationManager: Error requesting authorization: \(error)")
            }
        }
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Remote Notifications
    private func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    // MARK: - Local Notifications
    func scheduleLocalNotification(title: String, body: String, timeInterval: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling local notification: \(error)")
            }
        }
    }
    
    func scheduleLocalNotification(title: String, body: String, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling local notification: \(error)")
            }
        }
    }
    
    // MARK: - Calendar Event Notifications
    func scheduleEventReminder(eventTitle: String, eventDate: Date, reminderMinutes: Int = 15) {
        let content = UNMutableNotificationContent()
        content.title = "Event Reminder"
        content.body = "\(eventTitle) starts in \(reminderMinutes) minutes"
        content.sound = .default
        content.categoryIdentifier = "EVENT_REMINDER"
        
        let reminderDate = eventDate.addingTimeInterval(-TimeInterval(reminderMinutes * 60))
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: "event_\(eventTitle)_\(reminderMinutes)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling event reminder: \(error)")
            }
        }
    }
    
    // MARK: - FCM Token Management
    func setFCMToken(_ registrationID: String) {
        DispatchQueue.main.async {
            self.fcmToken = registrationID
        }
        
        // Here you would typically send the registration ID to your backend
        sendRegistrationIDToServer(registrationID)
    }
    
    private func sendRegistrationIDToServer(_ registrationID: String) {
        // TODO: Implement sending FCM registration ID to your backend
        // This is where you'd make an API call to associate the ID with the user
        print("FCM Registration ID to send to server: \(registrationID)")
    }
    
    // MARK: - Notification Handling
    func handleNotificationTap(_ userInfo: [AnyHashable: Any]) {
        // Handle notification tap based on the notification data
        print("Handling notification tap with data: \(userInfo)")
        
        // Parse notification type and handle accordingly
        if let notificationType = userInfo["type"] as? String {
            switch notificationType {
            case "event_reminder":
                handleEventReminder(userInfo)
            case "general":
                handleGeneralNotification(userInfo)
            default:
                print("Unknown notification type: \(notificationType)")
            }
        } else {
            // Default handling for notifications without type
            handleGeneralNotification(userInfo)
        }
    }
    
    private func handleEventReminder(_ userInfo: [AnyHashable: Any]) {
        // Handle event reminder notifications
        if let eventId = userInfo["event_id"] as? String {
            print("Handling event reminder for event: \(eventId)")
            // Navigate to event details or perform specific action
        }
    }
    
    
    private func handleGeneralNotification(_ userInfo: [AnyHashable: Any]) {
        // Handle general notifications
        print("Handling general notification")
        // Perform default action or show general content
    }
    
    // MARK: - Badge Management
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    func setBadge(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
        UIApplication.shared.applicationIconBadgeNumber = count
    }
    
    // MARK: - Notification Categories
    func setupNotificationCategories() {
        let eventReminderCategory = UNNotificationCategory(
            identifier: "EVENT_REMINDER",
            actions: [
                UNNotificationAction(
                    identifier: "VIEW_EVENT",
                    title: "View Event",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "SNOOZE",
                    title: "Snooze 5 min",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([eventReminderCategory])
    }
    
    // MARK: - Utility Methods
    func getPendingNotifications(completion: @escaping ([UNNotificationRequest]) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            completion(requests)
        }
    }
    
    func removeAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func removeNotification(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
