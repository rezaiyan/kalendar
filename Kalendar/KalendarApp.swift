//
//  KalendarApp.swift
//  Kalendar
//
//  Created by Ali Rezaiyan on 18.08.25.
//

import SwiftUI
import WidgetKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Firebase must be configured on main thread for notifications to work
        FirebaseApp.configure()
        
        // Run push notification setup on background thread to avoid blocking startup
        DispatchQueue.global(qos: .background).async {
            self.setupPushNotifications()
        }
        
        return true
    }
    
    // MARK: - Push Notification Setup
    private func setupPushNotifications() {
        print("🔔 Setting up push notifications...")
        
        // Set messaging delegate
        Messaging.messaging().delegate = self
        
        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Setup notification categories for actions
        NotificationManager.shared.setupNotificationCategories()
        
        // Request notification permissions immediately for notifications to work
        print("🔔 Requesting notification authorization...")
        NotificationManager.shared.requestAuthorization()
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([[.banner, .sound, .badge]])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap through NotificationManager
        let userInfo = response.notification.request.content.userInfo
        NotificationManager.shared.handleNotificationTap(userInfo)
        
        completionHandler()
    }
    
    // MARK: - MessagingDelegate
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration identifier: \(String(describing: fcmToken))")
        
        // Store FCM registration ID in NotificationManager
        if let registrationID = fcmToken {
            NotificationManager.shared.setFCMToken(registrationID)
        }
    }
    
    // MARK: - Remote Notification Handling
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        print("Received remote notification: \(userInfo)")
        
        // Handle the notification data through NotificationManager
        NotificationManager.shared.handleNotificationTap(userInfo)
        
        completionHandler(.newData)
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("Successfully registered for remote notifications")
        
        // Set the APNs device identifier for Firebase
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }
}

@main
struct KalendarApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    init() {
        // Run widget timeline reload on background thread to avoid blocking startup
        DispatchQueue.global(qos: .background).async {
            // Small delay to let UI render first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        
        // Set up a timer to refresh widgets every hour to ensure they stay current
        setupWidgetRefreshTimer()
    }
    
    private func setupWidgetRefreshTimer() {
        // Refresh widgets every hour to ensure they stay current
        // Run timer setup on background thread
        DispatchQueue.global(qos: .background).async {
            Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Handle widget refresh URLs
                    if url.scheme == "kalendar-refresh" {
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Refresh widgets when app becomes active to ensure they're current
                    WidgetCenter.shared.reloadAllTimelines()
                }
                .environmentObject(NotificationManager.shared)
        }
    }
}
