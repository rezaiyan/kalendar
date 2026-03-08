//
//  CalendarView.swift
//  Kalendar
//
//  Month calendar grid with swipe navigation — Liquid Glass
//

import SwiftUI

struct CalendarView: View {
    var viewModel: CalendarViewModel

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
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                                )
                        }
                }
                .buttonStyle(LiquidGlassButtonStyle())

                Spacer()

                Text(viewModel.monthTitle)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.monthTitle)

                Spacer()

                Button {
                    navigateNext()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                                )
                        }
                }
                .buttonStyle(LiquidGlassButtonStyle())
            }

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(viewModel.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)

            // Paged calendar grids
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
                if newValue == 1 {
                    viewModel.nextMonth()
                } else {
                    viewModel.previousMonth()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
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

    private var gridHeight: CGFloat {
        6 * 46 + 5 * 6
    }

    private func navigatePrevious() {
        guard !isNavigating else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { currentPage = -1 }
    }

    private func navigateNext() {
        guard !isNavigating else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { currentPage = 1 }
    }
}

// MARK: - Month Grid

private struct MonthGridView: View {
    let days: [CalendarDay]
    var viewModel: CalendarViewModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(days) { day in
                CalendarDayCell(
                    day: day,
                    isSelected: viewModel.isSelected(day.date),
                    hasEvents: viewModel.hasEvents(on: day.date),
                    busyness: viewModel.busynessScore(on: day.date)
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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

            // Busyness bar
            if hasEvents && day.isCurrentMonth {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(busynessColor)
                    .frame(width: busynessBarWidth, height: 3)
            } else {
                Color.clear.frame(width: 5, height: 3)
            }
        }
        .frame(height: 46)
        .frame(maxWidth: .infinity)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(day.isCurrentMonth ? 1 : 0.25)
    }

    private var busynessBarWidth: CGFloat {
        6 + 14 * busyness
    }

    private var busynessColor: Color {
        if day.isToday { return .white.opacity(0.9) }
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
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor)

                // Glass highlight on today cell
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
            .shadow(color: Color.accentColor.opacity(0.4), radius: 8, x: 0, y: 3)
        } else if isSelected && day.isCurrentMonth {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 0.5)
            }
        }
    }
}
