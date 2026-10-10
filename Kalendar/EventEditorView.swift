//
//  EventEditorView.swift
//  Kalendar
//
//  Create calendar events — Liquid Glass
//

import SwiftUI

struct EventEditorView: View {
    var viewModel: CalendarViewModel

    @Environment(\.dismiss) private var dismiss
    @AppStorage(AccentPalette.storageKey) private var accentColorName = AccentPalette.blue.rawValue
    @FocusState private var titleFocused: Bool

    @State private var title = ""
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay = false
    @State private var notes = ""
    /// Minutes before the event; `nil` means no reminder.
    @State private var reminderMinutes: Int?
    @State private var isSaving = false
    @State private var errorMessage: String?

    /// - Parameters:
    ///   - initialDate: The day (or exact start time) to prefill. A midnight date is treated as "a day".
    ///   - initialEndDate: Optional exact end time; defaults to one hour after the start.
    init(viewModel: CalendarViewModel, initialDate: Date, initialEndDate: Date? = nil) {
        self.viewModel = viewModel

        let start = Self.suggestedStart(for: initialDate)
        let end = initialEndDate.flatMap { $0 > start ? $0 : nil } ?? start.addingTimeInterval(3600)
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: end)
    }

    /// Today → the next full hour; other days → 9 AM; an explicit time is kept as is.
    private static func suggestedStart(for date: Date) -> Date {
        let calendar = Calendar.current
        guard date == calendar.startOfDay(for: date) else { return date }

        if calendar.isDateInToday(date) {
            let now = Date()
            let nextHour = calendar.nextDate(
                after: now,
                matching: DateComponents(minute: 0, second: 0),
                matchingPolicy: .nextTime
            )
            return nextHour ?? now
        }
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
    }

    private var accent: Color { AccentPalette.color(for: accentColorName) }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var datesAreValid: Bool {
        isAllDay
            ? Calendar.current.startOfDay(for: endDate) >= Calendar.current.startOfDay(for: startDate)
            : endDate >= startDate
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty && datesAreValid && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .onSubmit { if canSave { save() } }

                    TextField("Notes", text: $notes, axis: .vertical)
                        .font(.system(.body, design: .rounded))
                        .lineLimit(2...6)
                }

                Section {
                    Toggle(isOn: $isAllDay.animation(Theme.spring)) {
                        Label("All Day", systemImage: "sun.max")
                    }

                    DatePicker(
                        selection: $startDate,
                        displayedComponents: isAllDay ? .date : [.date, .hourAndMinute]
                    ) {
                        Label("Starts", systemImage: "clock")
                    }

                    DatePicker(
                        selection: $endDate,
                        in: startDate...,
                        displayedComponents: isAllDay ? .date : [.date, .hourAndMinute]
                    ) {
                        Label("Ends", systemImage: "clock.badge.checkmark")
                    }
                } footer: {
                    if !datesAreValid {
                        Text("The end must be after the start.")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Picker(selection: $reminderMinutes) {
                        Text("None").tag(Int?.none)
                        if isAllDay {
                            Text("On the day (9 AM)").tag(Int?.some(0))
                        } else {
                            ForEach(ReminderOption.minutes, id: \.self) { minutes in
                                Text(minutes == 0 ? ReminderOption.label(for: minutes) : "\(ReminderOption.label(for: minutes)) before")
                                    .tag(Int?.some(minutes))
                            }
                        }
                    } label: {
                        Label("Alert", systemImage: "bell")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background { AmbientBackground(accent: accent) }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Add") { save() }
                            .fontWeight(.semibold)
                            .disabled(!canSave)
                    }
                }
            }
            .onChange(of: startDate) { oldStart, newStart in
                // Keep the event's duration when the start moves.
                let duration = max(endDate.timeIntervalSince(oldStart), 0)
                endDate = newStart.addingTimeInterval(duration)
            }
            .onChange(of: isAllDay) { _, allDay in
                // Reminder choices differ between all-day and timed events.
                if reminderMinutes != nil { reminderMinutes = allDay ? 0 : 15 }
            }
            .onAppear { titleFocused = true }
            .alert(
                "Couldn't Save Event",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .tint(accent)
        .environment(\.accent, accent)
        .interactiveDismissDisabled(!trimmedTitle.isEmpty || !notes.isEmpty)
    }

    private func save() {
        guard canSave else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await viewModel.createEvent(
                    title: trimmedTitle,
                    startDate: startDate,
                    endDate: endDate,
                    notes: notes,
                    isAllDay: isAllDay,
                    reminderMinutes: reminderMinutes
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
