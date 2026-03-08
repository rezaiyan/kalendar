//
//  DayDetailView.swift
//  Kalendar
//
//  Selected day events panel — Liquid Glass
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
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.accentColor)
                        .frame(width: 32, height: 32)
                        .background {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                                )
                        }
                        .shadow(color: Color.accentColor.opacity(0.2), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(LiquidGlassButtonStyle())
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
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.selectedDate)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            Text("No Events")
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(.secondary)
            Text("Tap + to create an event")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var calendarAccessPrompt: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Calendar Access Required")
                .font(.system(.subheadline, design: .rounded).weight(.medium))
            Button {
                Task { await viewModel.requestCalendarAccess() }
            } label: {
                Text("Grant Access")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .glassPill()
            }
            .buttonStyle(LiquidGlassButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Event Row

struct EventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 12) {
            // Glass color indicator
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [eventColor.opacity(0.9), eventColor.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4, height: 38)
                .shadow(color: eventColor.opacity(0.4), radius: 3, x: 0, y: 0)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .lineLimit(1)

                if event.isAllDay {
                    Text("All Day")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                } else {
                    Text(timeRange)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(eventColor.opacity(0.06))
        )
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
