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
        // Move Firebase initialization to background thread to avoid blocking startup
        DispatchQueue.global(qos: .background).async {
            FirebaseApp.configure()
            
            // Set up push notifications on background thread
            DispatchQueue.main.async {
                self.setupPushNotifications()
            }
        }
        
        return true
    }
    
    // MARK: - Push Notification Setup
    private func setupPushNotifications() {
        // Set messaging delegate
        Messaging.messaging().delegate = self
        
        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Setup notification categories for actions (non-blocking)
        NotificationManager.shared.setupNotificationCategories()
        
        // Defer notification permission request to avoid blocking startup
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NotificationManager.shared.requestAuthorization()
        }
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
        print("Firebase registration token: \(String(describing: fcmToken))")
        
        // Store FCM token in NotificationManager
        if let token = fcmToken {
            NotificationManager.shared.setFCMToken(token)
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
        
        // Set the APNs token for Firebase
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
        // Defer widget timeline reload to avoid blocking startup
        // This will run after the UI is presented
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            WidgetCenter.shared.reloadAllTimelines()
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
                .environmentObject(NotificationManager.shared)
        }
    }
}
