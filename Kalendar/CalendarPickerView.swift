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
                    .font(.system(.body, design: .rounded))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        viewModel.updateSelectedCalendars(selected)
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded).weight(.semibold))
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
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                if selected.contains(cal.id) {
                    selected.remove(cal.id)
                } else {
                    selected.insert(cal.id)
                }
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: cal.colorHex).opacity(0.8), Color(hex: cal.colorHex)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.4), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .center
                                    )
                                )
                        )
                        .shadow(color: Color(hex: cal.colorHex).opacity(0.4), radius: 3, x: 0, y: 1)
                }

                Text(cal.title)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()

                if selected.contains(cal.id) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.body.weight(.medium))
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
}
