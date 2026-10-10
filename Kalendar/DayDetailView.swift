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

    @State private var pendingDeletion: CalendarEvent?
    @State private var errorMessage: String?

    var body: some View {
        let events = viewModel.selectedDayEvents

        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: title, subtitle: subtitle(count: events.count)) {
                GlassIconButton(systemImage: "plus", accessibilityLabel: "New Event", size: 32, action: onAddEvent)
            }

            if events.isEmpty {
                emptyState
            } else {
                VStack(spacing: 8) {
                    ForEach(events) { event in
                        EventRow(event: event)
                            .contextMenu {
                                if event.isLocal {
                                    Button(role: .destructive) {
                                        pendingDeletion = event
                                    } label: {
                                        Label("Delete Event", systemImage: "trash")
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
            }

            if !viewModel.calendarAccessGranted {
                calendarAccessPrompt
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .animation(Theme.spring, value: viewModel.selectedDate)
        .animation(Theme.spring, value: events.map(\.id))
        .confirmationDialog(
            "Delete \u{201C}\(pendingDeletion?.title ?? "")\u{201D}?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { event in
            Button("Delete Event", role: .destructive) { delete(event) }
        } message: { _ in
            Text("This event will be removed from Kalendar.")
        }
        .alert(
            "Something Went Wrong",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Header Text

    private var title: String {
        let calendar = viewModel.calendar
        let date = viewModel.selectedDate
        let dayText = date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        if calendar.isDateInToday(date) { return "Today · " + date.formatted(.dateTime.month(.wide).day()) }
        if calendar.isDateInTomorrow(date) { return "Tomorrow · " + date.formatted(.dateTime.month(.wide).day()) }
        return dayText
    }

    private func subtitle(count: Int) -> String {
        switch count {
        case 0: "Nothing scheduled"
        case 1: "1 event"
        default: "\(count) events"
        }
    }

    // MARK: - States

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
            Text("A free day")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
            Text("Tap + to plan something.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private var calendarAccessPrompt: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.title2)
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 2) {
                Text("Connect your calendars")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text("See all your events in one place.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                Task { await viewModel.requestCalendarAccess() }
            } label: {
                Text("Connect")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.tint, in: Capsule())
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(12)
        .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func delete(_ event: CalendarEvent) {
        pendingDeletion = nil
        Task {
            do {
                try await viewModel.deleteEvent(id: event.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Event Row

struct EventRow: View {
    let event: CalendarEvent

    @Environment(\.accent) private var accent

    private var color: Color { event.displayColor(fallback: accent) }

    var body: some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(color.gradient)
                .frame(width: 4)
                .frame(maxHeight: .infinity)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .lineLimit(2)

                Text(timeDescription)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                if let notes = event.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if event.isLocal {
                Image(systemName: "iphone")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Created in Kalendar")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var timeDescription: String {
        let calendar = Calendar.current
        let start = event.startDate
        let end = max(event.endDate, event.startDate)

        if event.isAllDay {
            // All-day end dates are exclusive (local) or 23:59:59 (EventKit); both mean "through the previous instant".
            let lastDay = calendar.startOfDay(for: end.addingTimeInterval(-1))
            guard lastDay > calendar.startOfDay(for: start) else { return "All day" }
            return "All day · " + (start..<lastDay).formatted(.interval.month(.abbreviated).day())
        }
        // An event ending exactly at midnight still belongs to the day it started.
        let effectiveEnd = end > start ? end.addingTimeInterval(-1) : end
        if calendar.isDate(start, inSameDayAs: effectiveEnd) {
            return (start..<end).formatted(date: .omitted, time: .shortened)
        }
        return (start..<end).formatted(date: .abbreviated, time: .shortened)
    }
}
