import Foundation
import SwiftUI

// MARK: - Shared Weather Service (Copy for Widget Extension)
class SharedWeatherService {
    static let shared = SharedWeatherService()
    
    // Use App Groups for sharing data between main app and widgets
    private let userDefaults = UserDefaults(suiteName: "group.com.alirezaiyan.Kalendar")
    private let weatherDataKey = "SharedWeatherData"
    
    private init() {}
    
    // MARK: - Get Weather for Date
    func getWeatherForDate(_ date: Date) -> SharedWeatherInfo? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        guard let data = userDefaults?.data(forKey: weatherDataKey) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let weatherData = try decoder.decode([String: SharedWeatherInfo].self, from: data)
            return weatherData[dateString]
        } catch {
            return nil
        }
    }
}

// MARK: - Shared Weather Info (Copy for Widget Extension)
struct SharedWeatherInfo: Codable {
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
    
    var condition: String {
        switch weatherCode {
        case 0: return "Clear"
        case 1: return "Mainly Clear"
        case 2: return "Partly Cloudy"
        case 3: return "Overcast"
        case 45: return "Foggy"
        case 48: return "Rime Fog"
        case 51: return "Light Drizzle"
        case 53: return "Drizzle"
        case 55: return "Heavy Drizzle"
        case 56: return "Freezing Drizzle"
        case 57: return "Heavy Freezing Drizzle"
        case 61: return "Light Rain"
        case 63: return "Rain"
        case 65: return "Heavy Rain"
        case 66: return "Freezing Rain"
        case 67: return "Heavy Freezing Rain"
        case 71: return "Light Snow"
        case 73: return "Snow"
        case 75: return "Heavy Snow"
        case 77: return "Snow Grains"
        case 80: return "Light Rain Showers"
        case 81: return "Rain Showers"
        case 82: return "Heavy Rain Showers"
        case 85: return "Light Snow Showers"
        case 86: return "Heavy Snow Showers"
        case 95: return "Thunderstorm"
        case 96: return "Thunderstorm with Hail"
        case 99: return "Heavy Thunderstorm"
        default: return "Unknown"
        }
    }
}

// MARK: - Weather Models for Widget
struct WidgetWeatherInfo {
    let weatherCode: Int
    let temperature: Double
    let minTemp: Double
    let maxTemp: Double
    let humidity: Double
    let windSpeed: Double
    let date: Date
    
    // MARK: - Computed Properties
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
    
    var condition: String {
        switch weatherCode {
        case 0: return "Clear"
        case 1: return "Mainly Clear"
        case 2: return "Partly Cloudy"
        case 3: return "Overcast"
        case 45: return "Foggy"
        case 48: return "Rime Fog"
        case 51: return "Light Drizzle"
        case 53: return "Drizzle"
        case 55: return "Heavy Drizzle"
        case 56: return "Freezing Drizzle"
        case 57: return "Heavy Freezing Drizzle"
        case 61: return "Light Rain"
        case 63: return "Rain"
        case 65: return "Heavy Rain"
        case 66: return "Freezing Rain"
        case 67: return "Heavy Freezing Rain"
        case 71: return "Light Snow"
        case 73: return "Snow"
        case 75: return "Heavy Snow"
        case 77: return "Snow Grains"
        case 80: return "Light Rain Showers"
        case 81: return "Rain Showers"
        case 82: return "Heavy Rain Showers"
        case 85: return "Light Snow Showers"
        case 86: return "Heavy Snow Showers"
        case 95: return "Thunderstorm"
        case 96: return "Thunderstorm with Hail"
        case 99: return "Heavy Thunderstorm"
        default: return "Unknown"
        }
    }
}

// MARK: - Weather Service for Widget
class WidgetWeatherService {
    static let shared = WidgetWeatherService()
    
    private init() {}
    
    // MARK: - Get Weather for Date
    func getWeatherForDate(_ date: Date) -> WidgetWeatherInfo {
        // Try to get real weather data from shared container first
        if let sharedWeather = SharedWeatherService.shared.getWeatherForDate(date) {
            return WidgetWeatherInfo(
                weatherCode: sharedWeather.weatherCode,
                temperature: sharedWeather.temperature,
                minTemp: sharedWeather.minTemp,
                maxTemp: sharedWeather.maxTemp,
                humidity: sharedWeather.humidity,
                windSpeed: sharedWeather.windSpeed,
                date: sharedWeather.date
            )
        }
        
        // Fallback to realistic weather generation if no shared data available
        return generateRealisticWeather(for: date)
    }
    
    // MARK: - Realistic Weather Generation
    private func generateRealisticWeather(for date: Date) -> WidgetWeatherInfo {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from: date)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 0
        
        // Generate weather based on season and day
        let (weatherCode, temperature, humidity, windSpeed) = generateSeasonalWeather(month: month, day: day, dayOfYear: dayOfYear)
        
        // Calculate min/max temperatures with realistic variation
        let tempVariation = Double.random(in: 3...8)
        let minTemp = temperature - tempVariation
        let maxTemp = temperature + tempVariation
        
        return WidgetWeatherInfo(
            weatherCode: weatherCode,
            temperature: temperature,
            minTemp: minTemp,
            maxTemp: maxTemp,
            humidity: humidity,
            windSpeed: windSpeed,
            date: date
        )
    }
    
    private func generateSeasonalWeather(month: Int, day: Int, dayOfYear: Int) -> (weatherCode: Int, temperature: Double, humidity: Double, windSpeed: Double) {
        // Seasonal temperature ranges (Northern Hemisphere)
        let seasonalTemp: Double
        let seasonalHumidity: Double
        
        switch month {
        case 12, 1, 2: // Winter
            seasonalTemp = Double.random(in: -5...15)
            seasonalHumidity = Double.random(in: 60...85)
        case 3, 4, 5: // Spring
            seasonalTemp = Double.random(in: 8...25)
            seasonalHumidity = Double.random(in: 55...75)
        case 6, 7, 8: // Summer
            seasonalTemp = Double.random(in: 20...35)
            seasonalHumidity = Double.random(in: 45...70)
        case 9, 10, 11: // Fall
            seasonalTemp = Double.random(in: 10...28)
            seasonalHumidity = Double.random(in: 50...80)
        default:
            seasonalTemp = 20.0
            seasonalHumidity = 65.0
        }
        
        // Weather patterns based on day of year and temperature
        let weatherCode: Int
        let windSpeed = Double.random(in: 5...25)
        
        // More realistic weather distribution
        let weatherSeed = (dayOfYear * 31 + month * 17) % 100
        
        if seasonalTemp < 5 { // Cold weather - more snow/freezing conditions
            if weatherSeed < 30 {
                weatherCode = 71 // Light snow
            } else if weatherSeed < 50 {
                weatherCode = 73 // Moderate snow
            } else if weatherSeed < 65 {
                weatherCode = 45 // Foggy
            } else if weatherSeed < 80 {
                weatherCode = 0 // Clear
            } else {
                weatherCode = 2 // Partly cloudy
            }
        } else if seasonalTemp > 25 { // Hot weather - more clear/sunny conditions
            if weatherSeed < 40 {
                weatherCode = 0 // Clear
            } else if weatherSeed < 60 {
                weatherCode = 1 // Mainly clear
            } else if weatherSeed < 75 {
                weatherCode = 2 // Partly cloudy
            } else if weatherSeed < 85 {
                weatherCode = 80 // Light rain showers
            } else {
                weatherCode = 95 // Thunderstorm
            }
        } else { // Moderate weather - balanced distribution
            if weatherSeed < 25 {
                weatherCode = 0 // Clear
            } else if weatherSeed < 40 {
                weatherCode = 1 // Mainly clear
            } else if weatherSeed < 55 {
                weatherCode = 2 // Partly cloudy
            } else if weatherSeed < 65 {
                weatherCode = 3 // Overcast
            } else if weatherSeed < 75 {
                weatherCode = 61 // Light rain
            } else if weatherSeed < 85 {
                weatherCode = 51 // Light drizzle
            } else {
                weatherCode = 45 // Foggy
            }
        }
        
        return (weatherCode: weatherCode, temperature: seasonalTemp, humidity: seasonalHumidity, windSpeed: windSpeed)
    }
}
