//
//  ContentView.swift
//  Kalendar
//
//  Created by Ali Rezaiyan on 18.08.25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedDate = Date()
    @State private var showWidgetGuide = false
    @StateObject private var weatherService = WeatherService()
    
    // MARK: - iPad-Specific Layout Properties
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    private var horizontalPadding: CGFloat {
        isIPad ? 60 : 20
    }
    
    private var calendarSpacing: CGFloat {
        isIPad ? 30 : 20
    }
    
    private var weekdayFontSize: CGFloat {
        isIPad ? 20 : 16
    }
    
    private var calendarColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: isIPad ? 12 : 8), count: 7)
    }
    
    private var calendarDaySize: CGFloat {
        isIPad ? 60 : 44
    }
    
    private var calendarDayHeight: CGFloat {
        isIPad ? 70 : 50
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // MARK: - Calendar Section
                    calendarSection
                    
                    // MARK: - Weather Card Section
                    WeatherCardSection(weatherService: weatherService)
                    
                    // MARK: - Widget Guide Section
                    widgetGuideSection
                    
                    // MARK: - Open Source Footer
                    openSourceFooter
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 24)
                .animation(.easeInOut(duration: 0.4), value: selectedDate)
            }
            .scrollIndicators(.hidden, axes: .vertical)
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Kalendar")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemBackground))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sheet(isPresented: $showWidgetGuide) {
                WidgetSetupGuide()
            }
            .onAppear {
                // UI is immediately available - all heavy operations run on background threads
            }
        }
    }
    
    // MARK: - Calendar Section
    private var calendarSection: some View {
        VStack(spacing: 24) {
            // Month and day info
            VStack(spacing: 8) {
                Text(currentMonthYear)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(currentDayName)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            // Weekday headers
            weekdayHeaders
            
            // Calendar grid
            calendarGrid
        }
    }
    
    // MARK: - Weekday Headers
    private var weekdayHeaders: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { day in
                Text(day)
                    .font(.system(size: weekdayFontSize, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Calendar Grid
    private var calendarGrid: some View {
        LazyVGrid(columns: calendarColumns, spacing: 8) {
            ForEach(calendarDays, id: \.self) { day in
                if day > 0 {
                    calendarDayButton(for: day)
                } else {
                    emptyCalendarDay
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Calendar Day Button
    private func calendarDayButton(for day: Int) -> some View {
        Button(action: {
            // Calculate the selected date based on the current month and selected day
            let calendar = Calendar.current
            let today = Date()
            let currentMonth = calendar.component(.month, from: today)
            let currentYear = calendar.component(.year, from: today)
            
            if let selectedDateComponents = calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: day)) {
                selectedDate = selectedDateComponents
            }
        }) {
            VStack(spacing: 4) {
                Text("\(day)")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(isToday(day) ? .white : .primary)
            }
            .frame(width: calendarDaySize, height: calendarDayHeight)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isToday(day) ? Color.blue : Color(.systemGray6)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelectedDay(day) ? Color.blue : Color.clear,
                        lineWidth: 2
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isSelectedDay(day))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    
    // MARK: - Day Background
    private func dayBackground(for day: Int) -> some View {
        Group {
            if isToday(day) {
                // Today's background with gradient
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else if isSelectedDay(day) {
                // Selected day with subtle background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
            } else {
                // Regular day with minimal background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.clear)
            }
        }
    }
    
    // MARK: - Day Border
    private func dayBorder(for day: Int) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(
                isSelectedDay(day) && !isToday(day) ? Color.blue.opacity(0.6) : Color.clear,
                lineWidth: 1.5
            )
    }
    
    // MARK: - Helper Functions
    private func isToday(_ day: Int) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        let currentMonth = calendar.component(.month, from: today)
        let currentYear = calendar.component(.year, from: today)
        let currentDay = calendar.component(.day, from: today)
        
        return day == currentDay
    }
    
    private func isSelectedDay(_ day: Int) -> Bool {
        let calendar = Calendar.current
        let selectedMonth = calendar.component(.month, from: selectedDate)
        let selectedYear = calendar.component(.year, from: selectedDate)
        let selectedDay = calendar.component(.day, from: selectedDate)
        
        let today = Date()
        let currentMonth = calendar.component(.month, from: today)
        let currentYear = calendar.component(.year, from: today)
        
        return day == selectedDay && selectedMonth == currentMonth && selectedYear == currentYear
    }
    
    // MARK: - Empty Calendar Day
    private var emptyCalendarDay: some View {
        Text("")
            .frame(width: calendarDaySize, height: calendarDayHeight)
    }
    
    
    // MARK: - Widget Guide Section
    private var widgetGuideSection: some View {
        VStack(spacing: 0) {
            // Header with icon and title
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "info.circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add Widget to Home Screen")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Widget Guide")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .opacity(0.8)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Description
            Text("Long press on your home screen, tap the + button, search for 'Kalendar', and add the widget to see your calendar at a glance.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
            
            // Action button
            Button(action: {
                showWidgetGuide = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                    Text("Learn More")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(.systemBackground),
                            Color(.systemGray6).opacity(0.3)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.8),
                                    Color.clear
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    // MARK: - Open Source Footer
    private var openSourceFooter: some View {
        VStack(spacing: 0) {
            // Header with icon and title
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.red)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Open Source Project")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Built with ❤️")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .opacity(0.8)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Description
            Text("Kalendar is built with ❤️ and open source. Feel free to contribute, report issues, or star the project.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
            
            // Action buttons
            HStack(spacing: 12) {
                Link(destination: URL(string: "https://github.com/rezaiyan/kalendar")!) {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .font(.system(size: 16, weight: .medium))
                        Text("GitHub")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                }
                
                Link(destination: URL(string: "https://github.com/rezaiyan/kalendar/blob/main/LICENSE")!) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 16, weight: .medium))
                        Text("License")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(.systemBackground),
                            Color(.systemGray6).opacity(0.3)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.8),
                                    Color.clear
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    // MARK: - Background Gradient
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(.systemBackground), Color(.systemGray6)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Day Gradient
    private var dayGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    

    
    // MARK: - Computed Properties
    private var currentMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
    
    private var currentDayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }
    
    private var selectedDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: selectedDate)
    }
    
    private var weekdaySymbols: [String] {
        // Force Monday-first order regardless of locale
        return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    }
    
    private var calendarDays: [Int] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // 2 = Monday, 1 = Sunday
        
        let startOfMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: Date())?.count ?? 0
        
        var days: [Int] = []
        
        // Convert Sunday=1, Monday=2, etc. to Monday=0, Tuesday=1, etc.
        // Sunday=1 → 0, Monday=2 → 1, Tuesday=3 → 2, etc.
        let mondayBasedWeekday = firstWeekday == 1 ? 6 : firstWeekday - 2
        
        // Add empty days for first week
        for _ in 0..<mondayBasedWeekday {
            days.append(0)
        }
        
        // Add days of the month
        for day in 1...daysInMonth {
            days.append(day)
        }
        
        return days
    }
    
}



#Preview {
    ContentView()
}
