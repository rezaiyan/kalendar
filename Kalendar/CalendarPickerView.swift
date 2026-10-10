//
//  CalendarPickerView.swift
//  Kalendar
//
//  Choose which calendars to display — Liquid Glass
//

import SwiftUI

struct CalendarPickerView: View {
    var viewModel: CalendarViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AccentPalette.storageKey) private var accentColorName = AccentPalette.blue.rawValue
    @State private var selected: Set<String> = []

    private var allIDs: Set<String> { Set(viewModel.availableCalendars.map(\.id)) }
    private var allSelected: Bool { selected.isSuperset(of: allIDs) }

    private var groupedCalendars: [(account: String, calendars: [CalendarSource])] {
        Dictionary(grouping: viewModel.availableCalendars, by: \.accountName)
            .map { account, calendars in (account: account.isEmpty ? "Other" : account, calendars: calendars) }
            .sorted { $0.account.localizedCaseInsensitiveCompare($1.account) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.availableCalendars.isEmpty {
                    ContentUnavailableView(
                        "No Calendars",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Add a calendar account in the Settings app.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        Button(allSelected ? "Deselect All" : "Select All") {
                            withAnimation(Theme.snappy) {
                                selected = allSelected ? [] : allIDs
                            }
                        }
                    }

                    ForEach(groupedCalendars, id: \.account) { group in
                        Section(group.account) {
                            ForEach(group.calendars) { calendar in
                                calendarRow(calendar)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Calendars")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        viewModel.updateSelectedCalendars(selected)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selected.isEmpty && !viewModel.availableCalendars.isEmpty)
                }
            }
            .sensoryFeedback(.selection, trigger: selected)
        }
        .tint(AccentPalette.color(for: accentColorName))
        .onAppear {
            selected = viewModel.selectedCalendarIDs.isEmpty ? allIDs : viewModel.selectedCalendarIDs
        }
    }

    private func calendarRow(_ calendar: CalendarSource) -> some View {
        let isOn = selected.contains(calendar.id)
        let color = Color(hex: calendar.colorHex)

        return Button {
            withAnimation(Theme.snappy) {
                if isOn {
                    selected.remove(calendar.id)
                } else {
                    selected.insert(calendar.id)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(color.gradient)
                    .frame(width: 14, height: 14)
                    .shadow(color: color.opacity(0.4), radius: 3, x: 0, y: 1)

                Text(calendar.title)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
