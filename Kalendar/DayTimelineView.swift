//
//  DayTimelineView.swift
//  Kalendar
//
//  Visual timeline showing events as blocks — Liquid Glass
//

import SwiftUI

struct DayTimelineView: View {
    var viewModel: CalendarViewModel
    /// Called when the user taps a free slot, e.g. to create an event there.
    var onSelectSlot: (TimeSlot) -> Void = { _ in }

    @Environment(\.accent) private var accent

    private static let trackHeight: CGFloat = 36
    private static let blockHeight: CGFloat = 28
    private static let labelHours = [8, 12, 16, 20]

    var body: some View {
        let window = viewModel.selectedDayWindow
        let events = viewModel.selectedDayEvents.filter { !$0.isAllDay && overlaps($0, window) }
        let freeSlots = viewModel.selectedDayFreeSlots

        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Timeline") {
                if !freeSlots.isEmpty {
                    Label(Self.durationText(freeSlots.reduce(0) { $0 + $1.duration }) + " free", systemImage: "leaf.fill")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.green.opacity(0.12), in: Capsule())
                }
            }

            // Re-render every minute so the "now" marker keeps moving.
            TimelineView(.periodic(from: .now, by: 60)) { context in
                track(window: window, events: events, freeSlots: freeSlots, now: context.date)
            }
            .frame(height: Self.trackHeight + 20)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary(events: events, freeSlots: freeSlots))

            if !freeSlots.isEmpty && !events.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(freeSlots) { slot in
                            Button { onSelectSlot(slot) } label: {
                                FreeSlotPill(slot: slot)
                            }
                            .buttonStyle(PressableButtonStyle())
                            .accessibilityHint("Creates an event in this free time")
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollClipDisabled()
            }
        }
        .glassCard()
        .animation(Theme.spring, value: viewModel.selectedDate)
    }

    // MARK: - Track

    private func track(window: DateInterval, events: [CalendarEvent], freeSlots: [TimeSlot], now: Date) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let blockY = (Self.trackHeight - Self.blockHeight) / 2

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                            .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                    }
                    .frame(height: Self.trackHeight)

                ForEach(freeSlots) { slot in
                    let frame = blockFrame(start: slot.start, end: slot.end, window: window, width: width, minWidth: 2)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.green.opacity(0.12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.green.opacity(0.25), lineWidth: 0.5)
                        }
                        .frame(width: frame.width, height: Self.blockHeight)
                        .offset(x: frame.minX, y: blockY)
                }

                ForEach(events) { event in
                    let frame = blockFrame(start: event.startDate, end: event.endDate, window: window, width: width, minWidth: 4)
                    let color = event.displayColor(fallback: accent)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(color.opacity(0.8).gradient)
                        .frame(width: frame.width, height: Self.blockHeight)
                        .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                        .offset(x: frame.minX, y: blockY)
                }

                if window.contains(now) {
                    let x = xPosition(for: now, window: window, width: width)
                    Capsule()
                        .fill(Color.red)
                        .frame(width: 2, height: Self.trackHeight + 6)
                        .overlay(alignment: .top) {
                            Circle().fill(Color.red).frame(width: 7, height: 7).offset(y: -3)
                        }
                        .shadow(color: .red.opacity(0.5), radius: 3)
                        .offset(x: x - 1, y: -3)
                }

                ForEach(Self.labelHours, id: \.self) { hour in
                    if let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: window.start) {
                        Text(date.formatted(.dateTime.hour()))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .fixedSize()
                            .position(x: xPosition(for: date, window: window, width: width), y: Self.trackHeight + 12)
                    }
                }
            }
        }
    }

    // MARK: - Geometry

    private func overlaps(_ event: CalendarEvent, _ window: DateInterval) -> Bool {
        event.startDate < window.end && event.endDate > window.start
    }

    private func xPosition(for date: Date, window: DateInterval, width: CGFloat) -> CGFloat {
        guard window.duration > 0 else { return 0 }
        let fraction = date.timeIntervalSince(window.start) / window.duration
        return CGFloat(min(max(fraction, 0), 1)) * width
    }

    /// Horizontal extent of a block, clamped to the window and kept inside the track.
    private func blockFrame(start: Date, end: Date, window: DateInterval, width: CGFloat, minWidth: CGFloat) -> CGRect {
        let minX = xPosition(for: start, window: window, width: width)
        let maxX = xPosition(for: end, window: window, width: width)
        let blockWidth = min(max(maxX - minX, minWidth), width)
        return CGRect(x: min(minX, width - blockWidth), y: 0, width: blockWidth, height: 0)
    }

    // MARK: - Text

    static func durationText(_ interval: TimeInterval) -> String {
        Duration.seconds(Int(interval)).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }

    private func accessibilitySummary(events: [CalendarEvent], freeSlots: [TimeSlot]) -> String {
        let eventPart = events.isEmpty ? "No timed events" : (events.count == 1 ? "1 timed event" : "\(events.count) timed events")
        let free = freeSlots.reduce(0) { $0 + $1.duration }
        return free > 0 ? "\(eventPart), \(Self.durationText(free)) free" : eventPart
    }
}

// MARK: - Free Slot Pill

private struct FreeSlotPill: View {
    let slot: TimeSlot

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)

            Text((slot.start..<slot.end).formatted(date: .omitted, time: .shortened))
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.primary)

            Text(DayTimelineView.durationText(slot.duration))
                .font(.system(size: 11, design: .rounded).weight(.semibold))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassPill()
    }
}
