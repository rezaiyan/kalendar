//
//  DayTimelineView.swift
//  Kalendar
//
//  Visual timeline showing events as blocks — Liquid Glass
//

import SwiftUI

struct DayTimelineView: View {
    var viewModel: CalendarViewModel

    private let dayStartHour = 8
    private let dayEndHour = 22
    private var totalMinutes: CGFloat { CGFloat((dayEndHour - dayStartHour) * 60) }

    var body: some View {
        let events = viewModel.selectedDayEvents.filter { !$0.isAllDay }
        let freeSlots = viewModel.selectedDayFreeSlots

        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("Timeline")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))

                Spacer()

                if !freeSlots.isEmpty {
                    let totalFree = freeSlots.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
                    let hours = Int(totalFree) / 3600
                    let mins = (Int(totalFree) % 3600) / 60
                    Text("\(hours)h \(mins)m free")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.green.opacity(0.1), in: Capsule())
                }
            }

            // Timeline bar
            GeometryReader { geo in
                let width = geo.size.width

                ZStack(alignment: .leading) {
                    // Glass track background
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                        )

                    // Free slot markers
                    ForEach(Array(freeSlots.enumerated()), id: \.offset) { _, slot in
                        let x = xPosition(for: slot.start, width: width)
                        let w = slotWidth(from: slot.start, to: slot.end, totalWidth: width)

                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.green.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color.green.opacity(0.2), lineWidth: 0.5)
                            )
                            .frame(width: max(w, 2), height: 30)
                            .offset(x: x)
                    }

                    // Event blocks with glass effect
                    ForEach(events) { event in
                        let x = xPosition(for: event.startDate, width: width)
                        let w = slotWidth(from: event.startDate, to: event.endDate, totalWidth: width)
                        let color = eventColor(event)

                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(color.opacity(0.75))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [.white.opacity(0.25), .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                            .frame(width: max(w, 4), height: 30)
                            .offset(x: x)
                            .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                    }

                    // Current time indicator
                    if isToday {
                        let nowX = xPosition(for: Date(), width: width)
                        if nowX >= 0 && nowX <= width {
                            Capsule()
                                .fill(Color.red)
                                .frame(width: 2.5, height: 40)
                                .offset(x: nowX)
                                .shadow(color: .red.opacity(0.5), radius: 4, x: 0, y: 0)

                            Circle()
                                .fill(Color.red)
                                .frame(width: 7, height: 7)
                                .shadow(color: .red.opacity(0.5), radius: 3, x: 0, y: 0)
                                .offset(x: nowX - 2.25, y: -20)
                        }
                    }
                }

                // Hour labels
                HStack {
                    ForEach([8, 12, 16, 20], id: \.self) { hour in
                        let label = hour <= 12 ? "\(hour)am" : "\(hour - 12)pm"
                        Text(hour == 12 ? "12pm" : label)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.quaternary)
                            .position(
                                x: xPosition(forHour: hour, width: width),
                                y: 50
                            )
                    }
                }
            }
            .frame(height: 60)

            // Free slot pills
            if !freeSlots.isEmpty && !events.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(freeSlots.enumerated()), id: \.offset) { _, slot in
                            FreeSlotPill(start: slot.start, end: slot.end)
                        }
                    }
                }
            }
        }
        .glassCard()
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.selectedDate)
    }

    // MARK: - Helpers

    private var isToday: Bool {
        Calendar.current.isDateInToday(viewModel.selectedDate)
    }

    private func minutesFromDayStart(_ date: Date) -> CGFloat {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        return CGFloat((hour - dayStartHour) * 60 + minute)
    }

    private func xPosition(for date: Date, width: CGFloat) -> CGFloat {
        let mins = max(0, min(minutesFromDayStart(date), totalMinutes))
        return (mins / totalMinutes) * width
    }

    private func xPosition(forHour hour: Int, width: CGFloat) -> CGFloat {
        let mins = CGFloat((hour - dayStartHour) * 60)
        return (mins / totalMinutes) * width
    }

    private func slotWidth(from start: Date, to end: Date, totalWidth: CGFloat) -> CGFloat {
        let startMins = max(0, minutesFromDayStart(start))
        let endMins = min(totalMinutes, minutesFromDayStart(end))
        let duration = max(0, endMins - startMins)
        return (duration / totalMinutes) * totalWidth
    }

    private func eventColor(_ event: CalendarEvent) -> Color {
        if let hex = event.calendarColorHex {
            return Color(hex: hex)
        }
        return .accentColor
    }
}

// MARK: - Free Slot Pill

private struct FreeSlotPill: View {
    let start: Date
    let end: Date

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }

    private var duration: String {
        let mins = Int(end.timeIntervalSince(start)) / 60
        if mins >= 60 {
            let h = mins / 60
            let m = mins % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(mins)m"
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.green)
                .frame(width: 5, height: 5)
                .shadow(color: .green.opacity(0.5), radius: 2, x: 0, y: 0)

            Text("\(timeFormatter.string(from: start)) - \(timeFormatter.string(from: end))")
                .font(.system(size: 11, design: .rounded))

            Text(duration)
                .font(.system(size: 10, design: .rounded).weight(.medium))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassPill()
    }
}
