//
//  CalendarPickerView.swift
//  Kalendar
//
//  Choose which calendars to display events from
//

import SwiftUI

struct CalendarPickerView: View {
    var viewModel: CalendarViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []

    private var groupedCalendars: [(account: String, calendars: [CalendarSource])] {
        let grouped = Dictionary(grouping: viewModel.availableCalendars) { $0.accountName }
        return grouped.keys.sorted().map { key in
            (account: key.isEmpty ? "Local" : key, calendars: grouped[key]!)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedCalendars, id: \.account) { group in
                    Section(group.account) {
                        ForEach(group.calendars) { cal in
                            calendarRow(cal)
                        }
                    }
                }
            }
            .navigationTitle("Calendars")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Select All") {
                        selected = Set(viewModel.availableCalendars.map(\.id))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        viewModel.updateSelectedCalendars(selected)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selected.isEmpty)
                }
            }
        }
        .onAppear {
            if viewModel.selectedCalendarIDs.isEmpty {
                selected = Set(viewModel.availableCalendars.map(\.id))
            } else {
                selected = viewModel.selectedCalendarIDs
            }
        }
    }

    private func calendarRow(_ cal: CalendarSource) -> some View {
        Button {
            if selected.contains(cal.id) {
                selected.remove(cal.id)
            } else {
                selected.insert(cal.id)
            }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: cal.colorHex))
                    .frame(width: 12, height: 12)
                Text(cal.title)
                    .foregroundStyle(.primary)
                Spacer()
                if selected.contains(cal.id) {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
