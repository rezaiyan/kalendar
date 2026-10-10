//
//  CalendarView.swift
//  Kalendar
//
//  Month calendar grid with swipe navigation — Liquid Glass
//

import SwiftUI

struct CalendarView: View {
    var viewModel: CalendarViewModel

    /// -1 / 0 / 1 = previous / displayed / next month page.
    @State private var currentPage = 0
    @State private var isNavigating = false

    private static let cellHeight: CGFloat = 44
    private static let rowSpacing: CGFloat = 6
    private static let gridHeight = 6 * cellHeight + 5 * rowSpacing
    /// Long enough for the page animation to settle before the pages are re-centred.
    private static let pageSettleDelay: Duration = .milliseconds(350)

    var body: some View {
        VStack(spacing: 14) {
            header
            weekdayHeader
            pager
        }
        .glassCard(padding: 14)
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.displayedMonth)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            GlassIconButton(systemImage: "chevron.left", accessibilityLabel: "Previous Month") {
                navigate(by: -1)
            }

            Spacer()

            // Reflects the page being shown, so the title updates as soon as a swipe lands.
            Text(viewModel.monthTitle(for: viewModel.monthOffset(currentPage)))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .contentTransition(.numericText())
                .animation(Theme.spring, value: currentPage)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            GlassIconButton(systemImage: "chevron.right", accessibilityLabel: "Next Month") {
                navigate(by: 1)
            }
        }
        .padding(.horizontal, 2)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(viewModel.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol.uppercased())
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Pager

    private var pager: some View {
        TabView(selection: $currentPage) {
            ForEach(-1...1, id: \.self) { offset in
                MonthGridView(
                    days: viewModel.calendarDays(for: viewModel.monthOffset(offset)),
                    viewModel: viewModel,
                    cellHeight: Self.cellHeight,
                    rowSpacing: Self.rowSpacing
                )
                .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: Self.gridHeight)
        .allowsHitTesting(!isNavigating)
        .onChange(of: currentPage) { _, page in
            guard page != 0, !isNavigating else { return }
            commitPage(page)
        }
    }

    private func navigate(by offset: Int) {
        guard !isNavigating else { return }
        withAnimation(Theme.spring) { currentPage = offset }
    }

    /// Once the neighbouring page is fully visible, advance the model and snap back to the centre page
    /// without animation. Both happen in one transaction, so the visible month never changes on screen.
    private func commitPage(_ page: Int) {
        isNavigating = true
        Task { @MainActor in
            try? await Task.sleep(for: Self.pageSettleDelay)
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                // The user may have swiped back to the centre while we waited.
                if currentPage == page {
                    if page > 0 {
                        viewModel.nextMonth()
                    } else {
                        viewModel.previousMonth()
                    }
                }
                currentPage = 0
            }
            isNavigating = false
        }
    }
}

// MARK: - Month Grid

private struct MonthGridView: View {
    let days: [CalendarDay]
    var viewModel: CalendarViewModel
    let cellHeight: CGFloat
    let rowSpacing: CGFloat

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: rowSpacing) {
            ForEach(days) { day in
                let isSelected = viewModel.isSelected(day.date)
                let eventCount = viewModel.eventCount(on: day.date)
                Button {
                    withAnimation(Theme.snappy) { viewModel.selectDate(day.date) }
                } label: {
                    CalendarDayCell(day: day, isSelected: isSelected, eventCount: eventCount, height: cellHeight)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(CalendarDayCell.accessibilityText(for: day, eventCount: eventCount))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let day: CalendarDay
    let isSelected: Bool
    var eventCount: Int = 0
    var height: CGFloat = 44

    @Environment(\.accent) private var accent

    private var busyness: Double { min(Double(eventCount) / 4, 1) }
    private var isHighlighted: Bool { isSelected && day.isCurrentMonth }

    var body: some View {
        VStack(spacing: 4) {
            Text("\(day.day)")
                .font(.system(.body, design: .rounded, weight: day.isToday || isHighlighted ? .bold : .medium))
                .monospacedDigit()
                .foregroundStyle(textStyle)

            Capsule()
                .fill(barStyle)
                .frame(width: 6 + 12 * busyness, height: 3)
                .opacity(eventCount > 0 && day.isCurrentMonth ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background { background }
        .opacity(day.isCurrentMonth ? 1 : 0.3)
    }

    private var textStyle: Color {
        if isHighlighted { return .white }
        if day.isToday { return accent }
        return .primary
    }

    private var barStyle: Color {
        if isHighlighted { return .white.opacity(0.9) }
        switch busyness {
        case ...0.25: return .green
        case ...0.5: return accent
        case ...0.75: return .orange
        default: return .red
        }
    }

    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.cell, style: .continuous)
        if isHighlighted {
            shape
                .fill(accent.gradient)
                .overlay {
                    shape.fill(LinearGradient(colors: [.white.opacity(0.28), .clear], startPoint: .top, endPoint: .center))
                }
                .shadow(color: accent.opacity(0.35), radius: 8, x: 0, y: 4)
        } else if day.isToday && day.isCurrentMonth {
            shape
                .fill(accent.opacity(0.12))
                .overlay { shape.strokeBorder(accent.opacity(0.35), lineWidth: 1) }
        }
    }

    static func accessibilityText(for day: CalendarDay, eventCount: Int) -> String {
        var parts = [day.date.formatted(date: .complete, time: .omitted)]
        if day.isToday { parts.insert("Today", at: 0) }
        if eventCount > 0 { parts.append(eventCount == 1 ? "1 event" : "\(eventCount) events") }
        return parts.joined(separator: ", ")
    }
}
