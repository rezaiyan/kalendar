//
//  DayDetailView.swift
//  Kalendar
//
//  Selected day events panel
//

import SwiftUI

struct DayDetailView: View {
    var viewModel: CalendarViewModel
    let onAddEvent: () -> Void

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(dateFormatter.string(from: viewModel.selectedDate))
                    .font(.system(.headline, design: .rounded))
                    .contentTransition(.numericText())

                Spacer()

                Button(action: onAddEvent) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }

            // Event list
            if viewModel.selectedDayEvents.isEmpty {
                if viewModel.calendarAccessGranted {
                    emptyState
                } else {
                    calendarAccessPrompt
                }
            } else {
                ForEach(viewModel.selectedDayEvents) { event in
                    EventRow(event: event)
                }
            }
        }
        .glassCard()
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedDate)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.largeTitle)
                .foregroundStyle(.quaternary)
            Text("No Events")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Tap + to create an event")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var calendarAccessPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Calendar Access Required")
                .font(.subheadline.weight(.medium))
            Button("Grant Access") {
                Task { await viewModel.requestCalendarAccess() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

// MARK: - Event Row

struct EventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(eventColor)
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                if event.isAllDay {
                    Text("All Day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(timeRange)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var eventColor: Color {
        if let hex = event.calendarColorHex {
            return Color(hex: hex)
        }
        return .accentColor
    }

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))"
    }
}

// MARK: - Color from Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
