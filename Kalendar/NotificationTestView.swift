//
//  NotificationTestView.swift
//  Kalendar
//
//  Created by Ali Rezaiyan on 29.08.25.
//

import SwiftUI

struct NotificationTestView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Notification Status
                VStack(alignment: .leading, spacing: 10) {
                    Text("Notification Status")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: notificationManager.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(notificationManager.isAuthorized ? .green : .red)
                        Text(notificationManager.isAuthorized ? "Authorized" : "Not Authorized")
                            .foregroundColor(notificationManager.isAuthorized ? .green : .red)
                    }
                    
                    if let fcmToken = notificationManager.fcmToken {
                        Text("FCM Token: \(String(fcmToken.prefix(20)))...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // Test Buttons
                VStack(spacing: 15) {
                    Button("Request Permission") {
                        notificationManager.requestAuthorization()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Test Local Notification (5s)") {
                        testLocalNotification()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!notificationManager.isAuthorized)
                    
                    Button("Test Local Notification (Date)") {
                        testScheduledNotification()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!notificationManager.isAuthorized)
                    
                    Button("Clear Badge") {
                        notificationManager.clearBadge()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!notificationManager.isAuthorized)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Notification Test")
            .alert("Notification", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func testLocalNotification() {
        notificationManager.scheduleLocalNotification(
            title: "Test Notification",
            body: "This is a test notification from Kalendar!",
            timeInterval: 5
        )
        
        alertMessage = "Local notification scheduled for 5 seconds from now"
        showingAlert = true
    }
    
    private func testScheduledNotification() {
        let futureDate = Date().addingTimeInterval(10)
        notificationManager.scheduleLocalNotification(
            title: "Scheduled Notification",
            body: "This notification was scheduled for a specific time!",
            date: futureDate
        )
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        alertMessage = "Notification scheduled for \(formatter.string(from: futureDate))"
        showingAlert = true
    }
}

#Preview {
    NotificationTestView()
        .environmentObject(NotificationManager.shared)
}
