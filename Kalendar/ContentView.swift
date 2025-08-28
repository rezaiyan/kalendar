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
    @State private var showLocationRequest = false
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
                    
                    // MARK: - Weather Summary Section
                    weatherSummarySection
                    
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
            .sheet(isPresented: $showLocationRequest) {
                LocationRequestView(weatherService: weatherService)
            }
            .onAppear {
                // Initialize TestFlight optimizations if needed
                weatherService.initializeForTestFlight()
                
                // Request location and fetch weather
                weatherService.requestLocation()
                Task {
                    // For TestFlight, use specialized initialization
                    await weatherService.initializeWeatherForTestFlight()
                    
                    // Fallback to regular fetch if TestFlight init didn't work
                    if weatherService.weatherData.isEmpty {
                        await weatherService.fetchWeatherForCurrentMonth()
                    }
                }
                
                // iPad-specific: Ensure UI updates are processed
                if isIPad {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // Force a UI refresh on iPad
                        withAnimation(.easeInOut(duration: 0.3)) {
                            // This will trigger a UI refresh
                        }
                    }
                }
            }
            .onChange(of: weatherService.shouldShowLocationRequest) { shouldShow in
                if shouldShow {
                    showLocationRequest = true
                }
            }
        }
    }
    
    // MARK: - Weather Summary Section
    private var weatherSummarySection: some View {
        VStack(spacing: 20) {
            if weatherService.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading weather...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 24)
                .transition(.opacity.combined(with: .scale))
            } else if let selectedWeather = getWeatherForSelectedDay() {
                VStack(spacing: 16) {
                    // Selected date header
                    HStack {
                        Text("Weather for \(formatSelectedDate())")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                        
                        Spacer()
                        
                        if isToday(Calendar.current.component(.day, from: selectedDate)) {
                            Text("Today")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .clipShape(Capsule())
                                .padding(.trailing, 16)
                        }
                    }
                    
                    // Weather details
                    HStack(spacing: 16) {
                        // Weather icon and condition
                        VStack(spacing: 8) {
                            Image(systemName: selectedWeather.icon)
                                .font(.system(size: 40, weight: .medium))
                                .foregroundColor(selectedWeather.color)
                                .frame(width: 40, height: 40)
                                .contentShape(Rectangle())
                            Text(selectedWeather.condition)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(width: 80, alignment: .center)
                        
                        // Temperature
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(Int(selectedWeather.temperature))°")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(width: 60, alignment: .leading)
                        
                        // High and Low Temperature
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                HStack(spacing: 3) {
                                    Image(systemName: "thermometer.sun.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.red)
                                    Text("\(Int(selectedWeather.maxTemp))°")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                
                                HStack(spacing: 3) {
                                    Image(systemName: "thermometer.snowflake")
                                        .font(.system(size: 11))
                                        .foregroundColor(.blue)
                                    Text("\(Int(selectedWeather.minTemp))°")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            }
                            Text("High / Low")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(width: 90, alignment: .leading)
                        
                        Spacer()
                        
                        // Additional weather info
                        VStack(alignment: .trailing, spacing: 6) {
                            if let humidity = selectedWeather.humidity {
                                HStack(spacing: 3) {
                                    Image(systemName: "humidity")
                                        .font(.system(size: 11))
                                        .foregroundColor(.blue)
                                    Text("\(Int(humidity))%")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            }
                            
                            if let windSpeed = selectedWeather.windSpeed {
                                HStack(spacing: 3) {
                                    Image(systemName: "wind")
                                        .font(.system(size: 11))
                                        .foregroundColor(.blue)
                                    Text("\(Int(windSpeed)) km/h")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            }
                        }
                        .frame(width: 70, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))
            } else {
                // No weather data available
                VStack(spacing: 12) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                    
                    Text("Weather data not available")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("Select a date to fetch weather information")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    // Show loading state if we're fetching weather
                    if weatherService.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Fetching weather...")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.vertical, 24)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedDate)
        .animation(.easeInOut(duration: 0.3), value: weatherService.isLoading)
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
                
                // Fetch weather for the selected date if not already available
                Task {
                    await weatherService.fetchWeatherForSelectedDate(selectedDate)
                }
            }
        }) {
            VStack(spacing: 4) {
                Text("\(day)")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(isToday(day) ? .white : .primary)
                
                // Weather icon for the day
                if let weatherIcon = weatherIconForDay(day) {
                    Image(systemName: weatherIcon.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(weatherIcon.color)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                        .transition(.scale.combined(with: .opacity))
                }
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
            .animation(.easeInOut(duration: 0.2), value: weatherIconForDay(day)?.icon)
            .animation(.easeInOut(duration: 0.2), value: isSelectedDay(day))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Weather Icon Helper
    private func weatherIconForDay(_ day: Int) -> (icon: String, color: Color)? {
        guard day > 0 else { return nil }
        
        let calendar = Calendar.current
        let today = Date()
        let currentMonth = calendar.component(.month, from: today)
        let currentYear = calendar.component(.year, from: today)
        
        guard let date = calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: day)) else {
            return nil
        }
        
        let dateString = formatDate(date)
        
        // Check if we have weather data for this date
        guard let weatherInfo = weatherService.weatherData[dateString] else {
            return nil
        }
        
        return (icon: weatherInfo.weatherIcon, color: weatherInfo.weatherColor)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
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
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                Text("Add Widget to Home Screen")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            Text("Long press on your home screen, tap the + button, search for 'Kalendar', and add the widget to see your calendar and weather at a glance.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            Button(action: {
                showWidgetGuide = true
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16))
                    Text("Learn More")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Open Source Footer
    private var openSourceFooter: some View {
        VStack(spacing: 16) {
            Divider()
                .background(Color.gray.opacity(0.3))
            
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                    
                    Text("Open Source Project")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                Text("Kalendar is built with ❤️ and open source. Feel free to contribute, report issues, or star the project.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 16) {
                    Link(destination: URL(string: "https://github.com/rezaiyan/kalendar")!) {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.system(size: 14))
                            Text("View on GitHub")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    
                    Link(destination: URL(string: "https://github.com/rezaiyan/kalendar/blob/main/LICENSE")!) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 14))
                            Text("License")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
    
    // MARK: - Weather Helper Functions
    private func getWeatherForSelectedDay() -> (icon: String, color: Color, condition: String, temperature: Double, minTemp: Double, maxTemp: Double, humidity: Double?, windSpeed: Double?)? {
        let dateString = formatDate(selectedDate)
        
        guard let weatherInfo = weatherService.weatherData[dateString] else {
            // Clear any previous error when selecting a date without weather data
            if weatherService.error != nil {
                weatherService.clearError()
            }
            return nil
        }
        
        // Clear any previous error when weather data is found
        if weatherService.error != nil {
            weatherService.clearError()
        }
        
        return (
            icon: weatherInfo.weatherIcon,
            color: weatherInfo.weatherColor,
            condition: weatherInfo.condition,
            temperature: weatherInfo.temperature,
            minTemp: weatherInfo.minTemp,
            maxTemp: weatherInfo.maxTemp,
            humidity: weatherInfo.humidity,
            windSpeed: weatherInfo.windSpeed
        )
    }
    
    private func formatSelectedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: selectedDate)
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Widget Setup Guide
struct WidgetSetupGuide: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    stepSection
                    widgetPreviewSection
                    tipsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add Widget")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus.square.on.square.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Add Calendar Widget")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("Get quick access to your calendar right from your home screen")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }
    
    private var stepSection: some View {
        VStack(spacing: 20) {
            Text("How to Add Widget")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                StepItem(
                    number: "1",
                    title: "Long Press Home Screen",
                    description: "Press and hold anywhere on your home screen until apps start jiggling",
                    icon: "hand.tap"
                )
                
                StepItem(
                    number: "2",
                    title: "Tap the Plus Button",
                    description: "Look for the + button in the top-left corner and tap it",
                    icon: "plus.circle.fill"
                )
                
                StepItem(
                    number: "3",
                    title: "Search for Kalendar",
                    description: "Type 'Kalendar' in the search bar to find your widget",
                    icon: "magnifyingglass"
                )
                
                StepItem(
                    number: "4",
                    title: "Choose Widget Size",
                    description: "Select Medium or Large size and tap 'Add Widget'",
                    icon: "rectangle.3.group"
                )
            }
        }
    }
    
    private var widgetPreviewSection: some View {
        VStack(spacing: 16) {
            Text("Widget Preview")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                // Medium widget preview
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .frame(width: 120, height: 80)
                        .overlay(
                            VStack(spacing: 4) {
                                Text("August 2025")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.primary)
                                Text("Today is Monday")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                                HStack(spacing: 2) {
                                    ForEach(0..<7, id: \.self) { _ in
                                        Circle()
                                            .fill(Color.blue.opacity(0.3))
                                            .frame(width: 6, height: 6)
                                    }
                                }
                            }
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    Text("Medium")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Large widget preview
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .frame(width: 120, height: 120)
                        .overlay(
                            VStack(spacing: 6) {
                                Text("August 2025")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.primary)
                                Text("Today is Monday")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                                    ForEach(0..<21, id: \.self) { _ in
                                        Circle()
                                            .fill(Color.blue.opacity(0.3))
                                            .frame(width: 8, height: 8)
                                    }
                                }
                            }
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    Text("Large")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var tipsSection: some View {
        VStack(spacing: 16) {
            Text("Pro Tips")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                TipItem(
                    icon: "clock",
                    title: "Auto Updates",
                    description: "Widget automatically updates to show current month and highlights today's date"
                )
                
                TipItem(
                    icon: "paintbrush",
                    title: "Beautiful Design",
                    description: "Matches your app's design with gradients and modern typography"
                )
                
                TipItem(
                    icon: "iphone",
                    title: "Multiple Sizes",
                    description: "Choose Medium for compact view or Large for detailed calendar"
                )
            }
        }
    }
    
}

// MARK: - Step Item
struct StepItem: View {
    let number: String
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Step number
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Text(number)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            // Step content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Text(description)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Tip Item
struct TipItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Location Request View
struct LocationRequestView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var weatherService: WeatherService
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with gradient background
                headerSection
                
                // Content section
                contentSection
                
                Spacer()
                
                // Action buttons
                actionButtons
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Location icon with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "location.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.white)
            }
            .shadow(color: .blue.opacity(0.3), radius: 12, x: 0, y: 6)
            
            VStack(spacing: 8) {
                Text("Location Access Required")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("To provide accurate weather information, we need access to your location")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.top, 40)
        .padding(.bottom, 30)
        .background(
            LinearGradient(
                colors: [Color(.systemGray6), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var contentSection: some View {
        VStack(spacing: 24) {
            // Benefits section
            VStack(spacing: 16) {
                Text("Why Location Access?")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                VStack(spacing: 12) {
                    BenefitRow(
                        icon: "thermometer",
                        title: "Accurate Weather",
                        description: "Get weather data specific to your exact location"
                    )
                    
                    BenefitRow(
                        icon: "clock",
                        title: "Real-time Updates",
                        description: "Weather information updates automatically"
                    )
                    
                    BenefitRow(
                        icon: "map",
                        title: "Local Forecast",
                        description: "See weather predictions for your area"
                    )
                }
            }
            .padding(.horizontal, 20)
            
            // Privacy note
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                    
                    Text("Your Privacy Matters")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Text("We only use your location to fetch weather data. Your location is never stored or shared with third parties.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            // Enable location button
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Enable Location Access")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            
            // Continue without location button
            Button(action: {
                weatherService.shouldShowLocationRequest = false
                dismiss()
            }) {
                Text("Continue Without Location")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
}

// MARK: - Benefit Row
struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    ContentView()
}
