//
//  LockScreenCalendarWidget.swift
//  LockScreenCalendarWidget
//
//  Created by Ali Rezaiyan on 19.08.25.
//

import WidgetKit
import SwiftUI

// MARK: - Local Shared Weather Service (Copy for Lock Screen Widget)
private class LocalSharedWeatherService {
    static let shared = LocalSharedWeatherService()
    
    private let userDefaults = UserDefaults.standard
    private let weatherDataKey = "SharedWeatherData"
    
    private init() {}
    
    func getWeatherForDate(_ date: Date) -> LocalSharedWeatherInfo? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        guard let data = userDefaults.data(forKey: weatherDataKey) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let weatherData = try decoder.decode([String: LocalSharedWeatherInfo].self, from: data)
            return weatherData[dateString]
        } catch {
            return nil
        }
    }
}

// MARK: - Local Shared Weather Info (Copy for Lock Screen Widget)
private struct LocalSharedWeatherInfo: Codable {
    let weatherCode: Int
    let temperature: Double
    let minTemp: Double
    let maxTemp: Double
    let humidity: Double
    let windSpeed: Double
    let date: Date
    
    var weatherIcon: String {
        switch weatherCode {
        case 0: return "sun.max.fill" // Clear sky
        case 1: return "sun.max.fill" // Mainly clear
        case 2: return "cloud.sun.fill" // Partly cloudy
        case 3: return "cloud.fill" // Overcast
        case 45: return "cloud.fog.fill" // Foggy
        case 48: return "cloud.fog.fill" // Depositing rime fog
        case 51: return "cloud.drizzle.fill" // Light drizzle
        case 53: return "cloud.drizzle.fill" // Moderate drizzle
        case 55: return "cloud.drizzle.fill" // Dense drizzle
        case 56: return "cloud.sleet.fill" // Light freezing drizzle
        case 57: return "cloud.sleet.fill" // Dense freezing drizzle
        case 61: return "cloud.rain.fill" // Slight rain
        case 63: return "cloud.rain.fill" // Moderate rain
        case 65: return "cloud.heavyrain.fill" // Heavy rain
        case 66: return "cloud.sleet.fill" // Light freezing rain
        case 67: return "cloud.sleet.fill" // Heavy freezing rain
        case 71: return "cloud.snow.fill" // Slight snow fall
        case 73: return "cloud.snow.fill" // Moderate snow fall
        case 75: return "cloud.snow.fill" // Heavy snow fall
        case 77: return "cloud.snow.fill" // Snow grains
        case 80: return "cloud.sun.rain.fill" // Slight rain showers
        case 81: return "cloud.rain.fill" // Moderate rain showers
        case 82: return "cloud.heavyrain.fill" // Violent rain showers
        case 85: return "cloud.snow.fill" // Slight snow showers
        case 86: return "cloud.snow.fill" // Heavy snow showers
        case 95: return "cloud.bolt.rain.fill" // Thunderstorm
        case 96: return "cloud.bolt.rain.fill" // Thunderstorm with slight hail
        case 99: return "cloud.bolt.rain.fill" // Thunderstorm with heavy hail
        default: return "questionmark.circle.fill" // Unknown weather
        }
    }
    
    var weatherColor: Color {
        switch weatherCode {
        case 0: return .orange // Clear sky
        case 1: return .orange // Mainly clear
        case 2: return .yellow // Partly cloudy
        case 3: return .gray // Overcast
        case 45: return .gray // Foggy
        case 48: return .gray // Depositing rime fog
        case 51: return .blue // Light drizzle
        case 53: return .blue // Moderate drizzle
        case 55: return .blue // Dense drizzle
        case 56: return .cyan // Light freezing drizzle
        case 57: return .cyan // Dense freezing drizzle
        case 61: return .blue // Slight rain
        case 63: return .blue // Moderate rain
        case 65: return .blue // Heavy rain
        case 66: return .cyan // Light freezing rain
        case 67: return .cyan // Heavy freezing rain
        case 71: return .cyan // Slight snow fall
        case 73: return .cyan // Moderate snow fall
        case 75: return .cyan // Heavy snow fall
        case 77: return .cyan // Snow grains
        case 80: return .blue // Slight rain showers
        case 81: return .blue // Moderate rain showers
        case 82: return .blue // Violent rain showers
        case 85: return .cyan // Slight snow showers
        case 86: return .cyan // Heavy snow showers
        case 95: return .purple // Thunderstorm
        case 96: return .purple // Thunderstorm with slight hail
        case 99: return .purple // Thunderstorm with heavy hail
        default: return .secondary // Unknown weather
        }
    }
}

// MARK: - Local type definitions for Lock Screen widget
// Since we can't directly import from Shared folder, we define the types here
struct CalendarDay: Identifiable, Hashable {
    let id = UUID()
    let day: Int
    let isCurrentMonth: Bool
    let monthType: MonthType
    
    enum MonthType {
        case previous
        case current
        case next
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        lhs.id == rhs.id
    }
}

struct CalendarEntry: TimelineEntry {
    let date: Date
    let selectedDate: Date
    let currentMonth: String
    let currentDayName: String
    let currentTime: String
    let allCalendarDays: [CalendarDay]
    let weekdaySymbols: [String]
    let initialTime: Date
}

// MARK: - LockScreen Timeline Provider
struct LockScreenTimelineProvider: TimelineProvider {
    typealias Entry = CalendarEntry
    
    private let calendar: Calendar
    private let timeZone: TimeZone
    
    init(calendar: Calendar = Calendar.current, timeZone: TimeZone = TimeZone.current) {
        var cal = calendar
        cal.firstWeekday = 2 // Monday = 2, Sunday = 1
        cal.timeZone = timeZone
        self.calendar = cal
        self.timeZone = timeZone
    }
    
    func placeholder(in context: Context) -> CalendarEntry {
        let sampleDays = createSampleCalendarDays()
        return CalendarEntry(
            date: Date(),
            selectedDate: Date(),
            currentMonth: "August",
            currentDayName: "Monday",
            currentTime: "14:30",
            allCalendarDays: sampleDays,
            weekdaySymbols: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
            initialTime: Date()
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (CalendarEntry) -> ()) {
        completion(createEntry(for: Date()))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarEntry>) -> ()) {
        var entries: [CalendarEntry] = []
        let now = Date()
        
        // 1. Current entry
        let currentEntry = createEntry(for: now)
        entries.append(currentEntry)
        
        // 2. Multiple refresh points for reliability
        let refreshTimes = calculateRefreshTimes(from: now)
        for refreshTime in refreshTimes {
            let entry = createEntry(for: refreshTime)
            entries.append(entry)
        }
        
        // Use .atEnd policy to ensure refresh when timeline ends
        let timeline = Timeline(entries: entries, policy: .atEnd)
        
        #if DEBUG
        print("📅 LockScreen Timeline created with \(entries.count) entries:")
        for (index, entry) in entries.enumerated() {
            print("  \(index + 1). \(formatDate(entry.date))")
        }
        #endif
        
        completion(timeline)
    }
    
    private func createEntry(for date: Date) -> CalendarEntry {
        let calendarDays = generateCalendarDays(for: date)
        
        // Format date components
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"
        monthFormatter.timeZone = timeZone
        
        let dayNameFormatter = DateFormatter()
        dayNameFormatter.dateFormat = "EEEE"
        dayNameFormatter.timeZone = timeZone
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.timeZone = timeZone
        
        return CalendarEntry(
            date: date,
            selectedDate: date,
            currentMonth: monthFormatter.string(from: date),
            currentDayName: dayNameFormatter.string(from: date),
            currentTime: timeFormatter.string(from: date),
            allCalendarDays: calendarDays,
            weekdaySymbols: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
            initialTime: date
        )
    }
    
    private func calculateRefreshTimes(from startDate: Date) -> [Date] {
        var refreshTimes: [Date] = []
        
        // Calculate next midnight in the widget's timezone
        guard let tomorrowMidnight = nextMidnight(after: startDate) else {
            return []
        }
        
        // Add midnight refresh
        refreshTimes.append(tomorrowMidnight)
        
        // Add additional refresh points for extra reliability
        
        // 1. Next day at 1 AM (in case midnight refresh fails)
        if let oneAM = calendar.date(byAdding: .hour, value: 1, to: tomorrowMidnight) {
            refreshTimes.append(oneAM)
        }
        
        // 2. Next day at 6 AM (for good measure)
        if let sixAM = calendar.date(byAdding: .hour, value: 6, to: tomorrowMidnight) {
            refreshTimes.append(sixAM)
        }
        
        // 3. Next week (for week transitions)
        if let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startDate),
           let nextWeekMidnight = nextMidnight(after: nextWeek) {
            refreshTimes.append(nextWeekMidnight)
        }
        
        // 4. Next month (for month transitions)
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: startDate),
           let nextMonthMidnight = nextMidnight(after: nextMonth) {
            refreshTimes.append(nextMonthMidnight)
        }
        
        // 5. Handle Daylight Saving Time transitions
        if let dstTransition = nextDSTTransition(after: startDate) {
            refreshTimes.append(dstTransition)
        }
        
        // Sort and deduplicate
        return Array(Set(refreshTimes)).sorted()
    }
    
    private func nextMidnight(after date: Date) -> Date? {
        // Get the start of the next day in the specified timezone
        let startOfToday = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: startOfToday)
    }
    
    private func nextDSTTransition(after date: Date) -> Date? {
        // Check for DST transitions in the next 3 months
        let threeMonthsLater = calendar.date(byAdding: .month, value: 3, to: date) ?? date
        
        let interval = DateInterval(start: date, end: threeMonthsLater)
        let transitions = timeZone.nextDaylightSavingTimeTransition(after: interval.start)
        
        if let transition = transitions, interval.contains(transition) {
            // Return the midnight after the DST transition
            return nextMidnight(after: transition)
        }
        
        return nil
    }
    
    private func generateCalendarDays(for date: Date) -> [CalendarDay] {
        let startOfMonth = calendar.dateInterval(of: .month, for: date)?.start ?? date
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 0
        
        var allCalendarDays: [CalendarDay] = []
        
        // Convert Sunday=1, Monday=2, etc. to Monday=0, Tuesday=1, etc.
        let mondayBasedWeekday = firstWeekday == 1 ? 6 : firstWeekday - 2
        
        // Previous month days
        if mondayBasedWeekday > 0 {
            let previousMonth = calendar.date(byAdding: .month, value: -1, to: date) ?? date
            let daysInPreviousMonth = calendar.range(of: .day, in: .month, for: previousMonth)?.count ?? 0
            let startDay = daysInPreviousMonth - mondayBasedWeekday + 1
            
            for day in startDay...daysInPreviousMonth {
                allCalendarDays.append(CalendarDay(day: day, isCurrentMonth: false, monthType: .previous))
            }
        }
        
        // Current month days
        for day in 1...daysInMonth {
            allCalendarDays.append(CalendarDay(day: day, isCurrentMonth: true, monthType: .current))
        }
        
        // Next month days (to complete the grid)
        let totalDaysIncludingCurrent = mondayBasedWeekday + daysInMonth
        let weeksNeeded = Int(ceil(Double(totalDaysIncludingCurrent) / 7.0))
        let totalDaysInGrid = weeksNeeded * 7
        let remainingDays = totalDaysInGrid - totalDaysIncludingCurrent
        
        if remainingDays > 0 {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) ?? date
            let daysInNextMonth = calendar.range(of: .day, in: .month, for: nextMonth)?.count ?? 0
            let maxDaysToShow = min(remainingDays, daysInNextMonth)
            
            for day in 1...maxDaysToShow {
                allCalendarDays.append(CalendarDay(day: day, isCurrentMonth: false, monthType: .next))
            }
        }
        
        return allCalendarDays
    }
    
    private func createSampleCalendarDays() -> [CalendarDay] {
        var sampleDays: [CalendarDay] = []
        
        // Previous month days
        for day in [28, 29, 30, 31] {
            sampleDays.append(CalendarDay(day: day, isCurrentMonth: false, monthType: .previous))
        }
        
        // Current month days
        for day in 1...31 {
            sampleDays.append(CalendarDay(day: day, isCurrentMonth: true, monthType: .current))
        }
        
        // Next month days
        for day in [1, 2, 3, 4, 5, 6, 7] {
            sampleDays.append(CalendarDay(day: day, isCurrentMonth: false, monthType: .next))
        }
        
        return sampleDays
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
    
    // MARK: - Weather Helper Functions
    private func getWeatherForDate(_ date: Date) -> (weatherIcon: String, weatherColor: Color) {
        // Try to get real weather data from shared container first
        if let sharedWeather = SharedWeatherService.shared.getWeatherForDate(date) {
            return (weatherIcon: sharedWeather.weatherIcon, weatherColor: sharedWeather.weatherColor)
        }
        
        // Fallback to realistic weather generation if no shared data available
        return generateRealisticWeather(for: date)
    }
    
    private func generateRealisticWeather(for date: Date) -> (weatherIcon: String, weatherColor: Color) {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 0
        
        // Generate weather based on season
        let weatherCode = generateSeasonalWeatherCode(month: month, dayOfYear: dayOfYear)
        
        // Map weather code to icon and color
        let (icon, color) = mapWeatherCodeToIconAndColor(weatherCode)
        
        return (weatherIcon: icon, weatherColor: color)
    }
    
    private func generateSeasonalWeatherCode(month: Int, dayOfYear: Int) -> Int {
        // Seasonal weather patterns (Northern Hemisphere)
        let weatherSeed = (dayOfYear * 31 + month * 17) % 100
        
        switch month {
        case 12, 1, 2: // Winter
            if weatherSeed < 30 {
                return 71 // Light snow
            } else if weatherSeed < 50 {
                return 73 // Moderate snow
            } else if weatherSeed < 65 {
                return 45 // Foggy
            } else if weatherSeed < 80 {
                return 0 // Clear
            } else {
                return 2 // Partly cloudy
            }
        case 3, 4, 5: // Spring
            if weatherSeed < 25 {
                return 0 // Clear
            } else if weatherSeed < 45 {
                return 1 // Mainly clear
            } else if weatherSeed < 60 {
                return 2 // Partly cloudy
            } else if weatherSeed < 75 {
                return 61 // Light rain
            } else if weatherSeed < 85 {
                return 51 // Light drizzle
            } else {
                return 45 // Foggy
            }
        case 6, 7, 8: // Summer
            if weatherSeed < 40 {
                return 0 // Clear
            } else if weatherSeed < 60 {
                return 1 // Mainly clear
            } else if weatherSeed < 75 {
                return 2 // Partly cloudy
            } else if weatherSeed < 85 {
                return 80 // Light rain showers
            } else {
                return 95 // Thunderstorm
            }
        case 9, 10, 11: // Fall
            if weatherSeed < 30 {
                return 0 // Clear
            } else if weatherSeed < 50 {
                return 2 // Partly cloudy
            } else if weatherSeed < 65 {
                return 3 // Overcast
            } else if weatherSeed < 80 {
                return 61 // Light rain
            } else {
                return 45 // Foggy
            }
        default:
            return 2 // Partly cloudy
        }
    }
    
    private func mapWeatherCodeToIconAndColor(_ weatherCode: Int) -> (icon: String, color: Color) {
        switch weatherCode {
        case 0: return ("sun.max.fill", .orange) // Clear sky
        case 1: return ("sun.max.fill", .orange) // Mainly clear
        case 2: return ("cloud.sun.fill", .yellow) // Partly cloudy
        case 3: return ("cloud.fill", .gray) // Overcast
        case 45: return ("cloud.fog.fill", .gray) // Foggy
        case 48: return ("cloud.fog.fill", .gray) // Depositing rime fog
        case 51: return ("cloud.drizzle.fill", .blue) // Light drizzle
        case 53: return ("cloud.drizzle.fill", .blue) // Moderate drizzle
        case 55: return ("cloud.drizzle.fill", .blue) // Dense drizzle
        case 56: return ("cloud.sleet.fill", .cyan) // Light freezing drizzle
        case 57: return ("cloud.sleet.fill", .cyan) // Dense freezing drizzle
        case 61: return ("cloud.rain.fill", .blue) // Slight rain
        case 63: return ("cloud.rain.fill", .blue) // Moderate rain
        case 65: return ("cloud.heavyrain.fill", .blue) // Heavy rain
        case 66: return ("cloud.sleet.fill", .cyan) // Light freezing rain
        case 67: return ("cloud.sleet.fill", .cyan) // Heavy freezing rain
        case 71: return ("cloud.snow.fill", .cyan) // Slight snow fall
        case 73: return ("cloud.snow.fill", .cyan) // Moderate snow fall
        case 75: return ("cloud.snow.fill", .cyan) // Heavy snow fall
        case 77: return ("cloud.snow.fill", .cyan) // Snow grains
        case 80: return ("cloud.sun.rain.fill", .blue) // Slight rain showers
        case 81: return ("cloud.rain.fill", .blue) // Moderate rain showers
        case 82: return ("cloud.heavyrain.fill", .blue) // Violent rain showers
        case 85: return ("cloud.snow.fill", .cyan) // Slight snow showers
        case 86: return ("cloud.snow.fill", .cyan) // Heavy snow showers
        case 95: return ("cloud.bolt.rain.fill", .purple) // Thunderstorm
        case 96: return ("cloud.bolt.rain.fill", .purple) // Thunderstorm with slight hail
        case 99: return ("cloud.bolt.rain.fill", .purple) // Thunderstorm with heavy hail
        default: return ("questionmark.circle.fill", .secondary) // Unknown weather
        }
    }
    
    private func getMockWeatherForDate(_ date: Date) -> (weatherIcon: String, weatherColor: Color) {
        // Fallback to simple mock weather if needed
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 0
        
        let weatherIcon: String
        switch dayOfYear % 7 {
        case 0:
            weatherIcon = "sun.max.fill"
        case 1:
            weatherIcon = "cloud.sun.fill"
        case 2:
            weatherIcon = "cloud.fill"
        case 3:
            weatherIcon = "cloud.rain.fill"
        case 4:
            weatherIcon = "cloud.snow.fill"
        case 5:
            weatherIcon = "cloud.bolt.rain.fill"
        default:
            weatherIcon = "cloud.sun.fill"
        }
        
        return (weatherIcon, .orange) // Default to orange for simplicity
    }
}

// MARK: - Lock Screen Calendar Widget Entry View
struct LockScreenCalendarWidgetEntryView: View {
    var entry: CalendarEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            LockScreenSmallView(entry: entry)
        case .systemMedium:
            LockScreenMediumView(entry: entry)
        default:
            LockScreenSmallView(entry: entry)
        }
    }
}

// MARK: - Lock Screen Small View
struct LockScreenSmallView: View {
    let entry: CalendarEntry
    
    var body: some View {
        VStack(spacing: 6) {
            // Current date prominently displayed
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: entry.date))")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(entry.currentMonth)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            // Weather icon for today
            let todayWeather = getWeatherForDate(entry.date)
            Image(systemName: todayWeather.weatherIcon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(todayWeather.weatherColor)
            
            // Day of week
            Text(entry.currentDayName)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(lockScreenBackground)
        .widgetURL(URL(string: "kalendar://calendar"))
    }
    
    private func getMockWeatherForDate(_ date: Date) -> (weatherIcon: String, weatherColor: Color) {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from: date)
        
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 0
        
        let weatherIcon: String
        switch dayOfYear % 7 {
        case 0:
            weatherIcon = "sun.max.fill"
        case 1:
            weatherIcon = "cloud.sun.fill"
        case 2:
            weatherIcon = "cloud.fill"
        case 3:
            weatherIcon = "cloud.rain.fill"
        case 4:
            weatherIcon = "cloud.snow.fill"
        case 5:
            weatherIcon = "cloud.bolt.rain.fill"
        default:
            weatherIcon = "cloud.sun.fill"
        }
        
        return (weatherIcon, .orange) // Default to orange for simplicity
    }
    
    private var lockScreenBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.quaternary, lineWidth: 0.5)
            )
    }
}

// MARK: - Lock Screen Medium View
struct LockScreenMediumView: View {
    let entry: CalendarEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Left side: Large current date
            VStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: entry.date))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(entry.currentMonth)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            // Right side: Mini calendar preview
            VStack(spacing: 6) {
                // Weekday headers (very compact)
                HStack(spacing: 0) {
                    ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { index, day in
                        Text(day)
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Mini 2x2 calendar grid showing current week
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                    ForEach(0..<14, id: \.self) { index in
                        if index < entry.allCalendarDays.count {
                            let calendarDay = entry.allCalendarDays[index]
                            miniDayView(for: calendarDay.day, isCurrentMonth: calendarDay.isCurrentMonth)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(lockScreenBackground)
        .widgetURL(URL(string: "kalendar://calendar"))
    }
    
    private func miniDayView(for day: Int, isCurrentMonth: Bool) -> some View {
        VStack(spacing: 0) {
            Text("\(day)")
                .font(.system(size: 8, weight: day == Calendar.current.component(.day, from: entry.date) ? .bold : .medium, design: .rounded))
                .foregroundColor(day == Calendar.current.component(.day, from: entry.date) ? .white : (isCurrentMonth ? .primary : .secondary))
                .opacity(isCurrentMonth ? 1.0 : 0.4)
            
            if isCurrentMonth {
                let mockDate = createMockDate(for: day)
                let weather = getWeatherForDate(mockDate)
                Image(systemName: weather.weatherIcon)
                    .font(.system(size: 4, weight: .medium))
                    .foregroundColor(weather.weatherColor)
                    .opacity(day == Calendar.current.component(.day, from: entry.date) ? 0.9 : 0.8)
            }
        }
        .frame(width: 14, height: 16)
        .background(
            Group {
                if day == Calendar.current.component(.day, from: entry.date) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                } else {
                    Color.clear
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
    
    private func createMockDate(for day: Int) -> Date {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: entry.date)
        let currentYear = calendar.component(.year, from: entry.date)
        return calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: day)) ?? entry.date
    }
    
    private func getMockWeatherForDate(_ date: Date) -> (weatherIcon: String, weatherColor: Color) {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from: date)
        
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 0
        
        let weatherIcon: String
        switch dayOfYear % 7 {
        case 0:
            weatherIcon = "sun.max.fill"
        case 1:
            weatherIcon = "cloud.sun.fill"
        case 2:
            weatherIcon = "cloud.fill"
        case 3:
            weatherIcon = "cloud.rain.fill"
        case 4:
            weatherIcon = "cloud.snow.fill"
        case 5:
            weatherIcon = "cloud.bolt.rain.fill"
        default:
            weatherIcon = "cloud.sun.fill"
        }
        
        return (weatherIcon, .orange) // Default to orange for simplicity
    }
    
    private var miniDayGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var lockScreenBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.quaternary, lineWidth: 0.5)
            )
    }
}

// MARK: - Lock Screen Calendar Widget
struct LockScreenCalendarWidget: Widget {
    let kind: String = "LockScreenCalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenTimelineProvider()) { entry in
            if #available(iOS 17.0, *) {
                LockScreenCalendarWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                LockScreenCalendarWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Lock Screen Calendar")
        .description("Compact calendar for lock screen")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews
#Preview(as: .systemSmall) {
    LockScreenCalendarWidget()
} timeline: {
    CalendarEntry(
        date: Date(),
        selectedDate: Date(),
        currentMonth: "August",
        currentDayName: "Monday",
        currentTime: "14:30",
        allCalendarDays: [
            CalendarDay(day: 28, isCurrentMonth: false, monthType: .previous),
            CalendarDay(day: 29, isCurrentMonth: false, monthType: .previous),
            CalendarDay(day: 30, isCurrentMonth: false, monthType: .previous),
            CalendarDay(day: 31, isCurrentMonth: false, monthType: .previous),
            CalendarDay(day: 1, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 2, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 3, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 4, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 5, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 6, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 7, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 8, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 9, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 10, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 11, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 12, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 13, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 14, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 15, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 16, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 17, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 18, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 19, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 20, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 21, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 22, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 23, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 24, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 25, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 26, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 27, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 28, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 29, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 30, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 31, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 1, isCurrentMonth: false, monthType: .next),
            CalendarDay(day: 2, isCurrentMonth: false, monthType: .next),
            CalendarDay(day: 3, isCurrentMonth: false, monthType: .next),
            CalendarDay(day: 4, isCurrentMonth: false, monthType: .next),
            CalendarDay(day: 5, isCurrentMonth: false, monthType: .next),
            CalendarDay(day: 6, isCurrentMonth: false, monthType: .next),
            CalendarDay(day: 7, isCurrentMonth: false, monthType: .next)
        ],
        weekdaySymbols: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
        initialTime: Date()
    )
}

#Preview(as: .systemMedium) {
    LockScreenCalendarWidget()
} timeline: {
    CalendarEntry(
        date: Date(),
        selectedDate: Date(),
        currentMonth: "August",
        currentDayName: "Monday",
        currentTime: "14:30",
        allCalendarDays: [
            CalendarDay(day: 28, isCurrentMonth: false, monthType: .previous),
            CalendarDay(day: 29, isCurrentMonth: false, monthType: .previous),
            CalendarDay(day: 30, isCurrentMonth: false, monthType: .previous),
            CalendarDay(day: 31, isCurrentMonth: false, monthType: .previous),
            CalendarDay(day: 1, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 2, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 3, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 4, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 5, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 6, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 7, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 8, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 9, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 10, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 11, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 12, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 13, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 14, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 15, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 16, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 17, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 18, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 19, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 20, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 21, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 22, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 23, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 24, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 25, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 26, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 27, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 28, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 29, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 30, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 31, isCurrentMonth: true, monthType: .current),
            CalendarDay(day: 1, isCurrentMonth: false, monthType: .next),
            CalendarDay(day: 2, isCurrentMonth: false, monthType: .next),
            CalendarDay(day: 3, isCurrentMonth: false, monthType: .next),
            CalendarDay(day: 4, isCurrentMonth: false, monthType: .next),
            CalendarDay(day: 5, isCurrentMonth: false, monthType: .next),
            CalendarDay(day: 6, isCurrentMonth: false, monthType: .next),
            CalendarDay(day: 7, isCurrentMonth: false, monthType: .next)
        ],
        weekdaySymbols: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
        initialTime: Date()
    )
}
