//
//  DayTimelineView.swift
//  Kalendar
//
//  Visual timeline showing events as blocks with free slots highlighted
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

        VStack(alignment: .leading, spacing: 8) {
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
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                }
            }

            // Timeline bar
            GeometryReader { geo in
                let width = geo.size.width

                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 32)

                    // Free slot markers
                    ForEach(Array(freeSlots.enumerated()), id: \.offset) { _, slot in
                        let x = xPosition(for: slot.start, width: width)
                        let w = slotWidth(from: slot.start, to: slot.end, totalWidth: width)

                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.green.opacity(0.15))
                            .frame(width: max(w, 2), height: 28)
                            .offset(x: x)
                    }

                    // Event blocks
                    ForEach(events) { event in
                        let x = xPosition(for: event.startDate, width: width)
                        let w = slotWidth(from: event.startDate, to: event.endDate, totalWidth: width)

                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(eventColor(event).opacity(0.85))
                            .frame(width: max(w, 4), height: 28)
                            .offset(x: x)
                    }

                    // Current time indicator
                    if isToday {
                        let nowX = xPosition(for: Date(), width: width)
                        if nowX >= 0 && nowX <= width {
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 2, height: 36)
                                .offset(x: nowX)

                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                                .offset(x: nowX - 2, y: -18)
                        }
                    }
                }

                // Hour labels
                HStack {
                    ForEach([8, 12, 16, 20], id: \.self) { hour in
                        let label = hour <= 12 ? "\(hour)am" : "\(hour - 12)pm"
                        Text(hour == 12 ? "12pm" : label)
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .position(
                                x: xPosition(forHour: hour, width: width),
                                y: 46
                            )
                    }
                }
            }
            .frame(height: 56)

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
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedDate)
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

            Text("\(timeFormatter.string(from: start)) - \(timeFormatter.string(from: end))")
                .font(.system(size: 11, design: .rounded))

            Text(duration)
                .font(.system(size: 10, design: .rounded).weight(.medium))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.green.opacity(0.1), in: Capsule())
    }
}
