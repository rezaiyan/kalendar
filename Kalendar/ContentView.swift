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
                    weatherCardSection
                    
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
                // UI is already optimized for iPad, no need for artificial delays
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
    
    // MARK: - Weather Card Section
    private var weatherCardSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                
                Text("Today's Weather")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                
                Spacer()
                
                if weatherService.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button(action: {
                        weatherService.refreshUserLocation()
                    }) {
                        Image(systemName: "location.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    }
                }
            }
            
            if let weather = weatherService.currentWeather {
                weatherCard(weather: weather)
            } else if let errorMessage = weatherService.errorMessage {
                errorCard(message: errorMessage)
            } else {
                loadingCard
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Weather Card
    private func weatherCard(weather: WeatherResponse) -> some View {
        let weatherInfo = Weather(weatherCode: weather.current.weather_code)
        
        return VStack(spacing: 0) {
            // Header with weather condition and icon
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(weatherInfo.description.capitalized)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Image(systemName: weatherService.getWeatherIcon(for: weatherInfo))
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(weatherService.getWeatherColor(for: weatherInfo))
                    .symbolEffect(.pulse, options: .repeating)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Temperature display
            HStack(alignment: .top) {
                Text("\(Int(weather.current.temperature_2m))")
                    .font(.system(size: 64, weight: .thin, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("°C")
                    .font(.system(size: 24, weight: .light, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Weather details grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
                modernWeatherDetail(
                    icon: "thermometer.medium",
                    title: "Feels like",
                    value: "\(Int(weather.current.temperature_2m))°",
                    color: .orange
                )
                
                modernWeatherDetail(
                    icon: "humidity",
                    title: "Humidity",
                    value: "\(weather.current.relative_humidity_2m)%",
                    color: .blue
                )
                
                modernWeatherDetail(
                    icon: "wind",
                    title: "Wind",
                    value: "\(Int(weather.current.wind_speed_10m)) km/h",
                    color: .cyan
                )
            }
            .padding(.horizontal, 20)
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
    
    // MARK: - Modern Weather Detail
    private func modernWeatherDetail(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(color)
            }
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text(value)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    
    // MARK: - Legacy Weather Detail (kept for compatibility)
    private func weatherDetail(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.blue)
            
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Error Card
    private func errorCard(message: String) -> some View {
        VStack(spacing: 0) {
            // Header with icon and title
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weather Unavailable")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Connection Error")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .opacity(0.8)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Error message
            Text(message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
            
            // Retry button
            Button("Try Again") {
                weatherService.tryNextDefaultLocation()
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.orange, .orange.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
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
    
    // MARK: - Loading Card
    private var loadingCard: some View {
        VStack(spacing: 0) {
            // Header with icon and title
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Loading Weather")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Please wait...")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .opacity(0.8)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Loading message
            Text("Fetching current weather data...")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
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


#Preview {
    ContentView()
}
