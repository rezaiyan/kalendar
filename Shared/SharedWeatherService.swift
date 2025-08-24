import Foundation
import SwiftUI

// MARK: - Shared Weather Models
public struct SharedWeatherInfo: Codable {
    public let weatherCode: Int
    public let temperature: Double
    public let minTemp: Double
    public let maxTemp: Double
    public let humidity: Double
    public let windSpeed: Double
    public let date: Date
    
    public init(weatherCode: Int, temperature: Double, minTemp: Double, maxTemp: Double, humidity: Double, windSpeed: Double, date: Date) {
        self.weatherCode = weatherCode
        self.temperature = temperature
        self.minTemp = minTemp
        self.maxTemp = maxTemp
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.date = date
    }
    
    // MARK: - Computed Properties
    public var weatherIcon: String {
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
    
    public var weatherColor: Color {
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
    
    public var condition: String {
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

// MARK: - Shared Weather Service
public class SharedWeatherService: ObservableObject {
    public static let shared = SharedWeatherService()
    
    // Use App Groups for sharing data between main app and widgets
    private let userDefaults = UserDefaults(suiteName: "group.com.alirezaiyan.Kalendar")
    private let weatherDataKey = "SharedWeatherData"
    
    private init() {}
    
    // MARK: - Save Weather Data
    public func saveWeatherData(_ weatherData: [String: SharedWeatherInfo]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(weatherData)
            userDefaults.set(data, forKey: weatherDataKey)
            print("🌐 [SHARED] ✅ Weather data saved to shared container")
        } catch {
            print("🌐 [SHARED] ❌ Failed to save weather data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Load Weather Data
    public func loadWeatherData() -> [String: SharedWeatherInfo] {
        guard let data = userDefaults.data(forKey: weatherDataKey) else {
            print("🌐 [SHARED] ℹ️ No weather data found in shared container")
            return [:]
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let weatherData = try decoder.decode([String: SharedWeatherInfo].self, from: data)
            print("🌐 [SHARED] ✅ Weather data loaded from shared container: \(weatherData.count) entries")
            return weatherData
        } catch {
            print("🌐 [SHARED] ❌ Failed to decode weather data: \(error.localizedDescription)")
            return [:]
        }
    }
    
    // MARK: - Get Weather for Date
    public func getWeatherForDate(_ date: Date) -> SharedWeatherInfo? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        let weatherData = loadWeatherData()
        return weatherData[dateString]
    }
    
    // MARK: - Clear Weather Data
    public func clearWeatherData() {
        userDefaults.removeObject(forKey: weatherDataKey)
        print("🌐 [SHARED] 🗑️ Weather data cleared from shared container")
    }
}
