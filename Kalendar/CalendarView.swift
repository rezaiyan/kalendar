//
//  CalendarView.swift
//  Kalendar
//
//  Month calendar grid with swipe navigation
//

import SwiftUI

struct CalendarView: View {
    var viewModel: CalendarViewModel

    // The paging selection always starts at 0 (center). After a swipe
    // we update the model and snap back to center.
    @State private var currentPage = 0
    @State private var isNavigating = false

    var body: some View {
        VStack(spacing: 16) {
            // Month navigation header
            HStack {
                Button {
                    navigatePrevious()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.medium))
                        .contentShape(Rectangle())
                        .frame(width: 44, height: 44)
                }

                Spacer()

                Text(viewModel.monthTitle)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.25), value: viewModel.monthTitle)

                Spacer()

                Button {
                    navigateNext()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.medium))
                        .contentShape(Rectangle())
                        .frame(width: 44, height: 44)
                }
            }

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(viewModel.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Paged calendar grids: previous (-1), current (0), next (1)
            TabView(selection: $currentPage) {
                MonthGridView(
                    days: viewModel.calendarDays(for: viewModel.monthOffset(-1)),
                    viewModel: viewModel
                )
                .tag(-1)

                MonthGridView(
                    days: viewModel.calendarDays,
                    viewModel: viewModel
                )
                .tag(0)

                MonthGridView(
                    days: viewModel.calendarDays(for: viewModel.monthOffset(1)),
                    viewModel: viewModel
                )
                .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: gridHeight)
            .onChange(of: currentPage) { _, newValue in
                guard newValue != 0 else { return }
                guard !isNavigating else { return }
                isNavigating = true
                // Commit the navigation, then snap back to center
                if newValue == 1 {
                    viewModel.nextMonth()
                } else {
                    viewModel.previousMonth()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                // Reset to center page after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    currentPage = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isNavigating = false
                    }
                }
            }
        }
        .glassCard()
    }

    // Fixed height for 6 rows: 44pt cell + 8pt spacing
    private var gridHeight: CGFloat {
        6 * 44 + 5 * 8 // 304
    }

    private func navigatePrevious() {
        guard !isNavigating else { return }
        withAnimation(.easeInOut(duration: 0.25)) { currentPage = -1 }
    }

    private func navigateNext() {
        guard !isNavigating else { return }
        withAnimation(.easeInOut(duration: 0.25)) { currentPage = 1 }
    }
}

// MARK: - Month Grid (single month page)

private struct MonthGridView: View {
    let days: [CalendarDay]
    var viewModel: CalendarViewModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(days) { day in
                CalendarDayCell(
                    day: day,
                    isSelected: viewModel.isSelected(day.date),
                    hasEvents: viewModel.hasEvents(on: day.date),
                    busyness: viewModel.busynessScore(on: day.date)
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectDate(day.date)
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let day: CalendarDay
    let isSelected: Bool
    let hasEvents: Bool
    var busyness: Double = 0

    var body: some View {
        VStack(spacing: 4) {
            Text("\(day.day)")
                .font(.system(.body, design: .rounded, weight: day.isToday ? .bold : .medium))
                .foregroundStyle(textColor)

            // Busyness bar instead of simple dot
            if hasEvents && day.isCurrentMonth {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(busynessColor)
                    .frame(width: busynessBarWidth, height: 3)
            } else {
                Color.clear.frame(width: 5, height: 3)
            }
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .opacity(day.isCurrentMonth ? 1 : 0.3)
    }

    private var busynessBarWidth: CGFloat {
        // Bar grows from 6pt to 20pt based on busyness
        6 + 14 * busyness
    }

    private var busynessColor: Color {
        if day.isToday { return .white }
        if busyness <= 0.25 { return .green }
        if busyness <= 0.5 { return .accentColor }
        if busyness <= 0.75 { return .orange }
        return .red
    }

    private var textColor: Color {
        if day.isToday && day.isCurrentMonth { return .white }
        if isSelected && day.isCurrentMonth { return .accentColor }
        return .primary
    }

    @ViewBuilder
    private var background: some View {
        if day.isToday && day.isCurrentMonth {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor)
        } else if isSelected && day.isCurrentMonth {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
        }
    }
}
