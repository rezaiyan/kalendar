//
//  EventEditorView.swift
//  Kalendar
//
//  Create and edit calendar events — Liquid Glass
//

import SwiftUI
import UserNotifications

struct EventEditorView: View {
    var viewModel: CalendarViewModel
    let initialDate: Date
    @Environment(\.dismiss) private var dismiss
    @AppStorage("accentColorName") private var accentColorName = "blue"

    @State private var title = ""
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay = false
    @State private var notes = ""
    @State private var reminderEnabled = false
    @State private var reminderMinutes = 15
    @State private var showError = false
    @State private var errorMessage = ""

    init(viewModel: CalendarViewModel, initialDate: Date) {
        self.viewModel = viewModel
        self.initialDate = initialDate

        let cal = Calendar.current
        let start = cal.date(bySettingHour: 9, minute: 0, second: 0, of: initialDate) ?? initialDate
        let end = cal.date(byAdding: .hour, value: 1, to: start) ?? initialDate
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: end)
    }

    private var accent: Color { accentColorFor(accentColorName) }

    var body: some View {
        NavigationStack {
            ZStack {
                // Ambient background
                LinearGradient(
                    colors: [
                        accent.opacity(0.06),
                        Color(.systemGroupedBackground),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                Form {
                    Section {
                        TextField("Event Title", text: $title)
                            .font(.system(.body, design: .rounded))
                        Toggle("All Day", isOn: $isAllDay)
                            .tint(accent)
                    }

                    Section {
                        DatePicker("Starts", selection: $startDate,
                                   displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
                        DatePicker("Ends", selection: $endDate,
                                   displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
                    }

                    Section {
                        TextField("Notes", text: $notes, axis: .vertical)
                            .font(.system(.body, design: .rounded))
                            .lineLimit(3...6)
                    }

                    Section {
                        Toggle("Reminder", isOn: $reminderEnabled)
                            .tint(accent)
                        if reminderEnabled {
                            Picker("Before event", selection: $reminderMinutes) {
                                Text("5 minutes").tag(5)
                                Text("15 minutes").tag(15)
                                Text("30 minutes").tag(30)
                                Text("1 hour").tag(60)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.system(.body, design: .rounded))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveEvent()
                    } label: {
                        Text("Save")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
        .tint(accent)
    }

    private func saveEvent() {
        Task {
            do {
                try await viewModel.createEvent(
                    title: title,
                    startDate: startDate,
                    endDate: endDate,
                    notes: notes.isEmpty ? nil : notes,
                    isAllDay: isAllDay
                )

                if reminderEnabled {
                    scheduleReminder()
                }

                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func scheduleReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Event"
        content.body = "\(title) starts in \(reminderMinutes) minutes"
        content.sound = .default

        let triggerDate = startDate.addingTimeInterval(-TimeInterval(reminderMinutes * 60))
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }
}
