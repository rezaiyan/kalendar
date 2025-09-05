//
//  WeatherService.swift
//  Kalendar
//
//  Created by Ali Rezaiyan on 18.08.25.
//

import Foundation
import SwiftUI

// MARK: - Weather Models (Open-Meteo API)
struct WeatherResponse: Codable {
    let current: CurrentWeather
    let location: LocationInfo
}

struct CurrentWeather: Codable {
    let temperature_2m: Double
    let relative_humidity_2m: Int
    let weather_code: Int
    let wind_speed_10m: Double
    let wind_direction_10m: Int
}

struct LocationInfo: Codable {
    let name: String
    let country: String
    let timezone: String
}

// MARK: - Weather Code Mapping
struct Weather {
    let id: Int
    let main: String
    let description: String
    let icon: String
    
    init(weatherCode: Int) {
        self.id = weatherCode
        self.main = WeatherCodeMapper.mainCondition(for: weatherCode)
        self.description = WeatherCodeMapper.description(for: weatherCode)
        self.icon = WeatherCodeMapper.icon(for: weatherCode)
    }
}

struct Main: Codable {
    let temp: Double
    let feels_like: Double
    let temp_min: Double
    let temp_max: Double
    let humidity: Int
    
    init(temperature: Double, humidity: Int) {
        self.temp = temperature
        self.feels_like = temperature // Open-Meteo doesn't provide feels_like
        self.temp_min = temperature - 2 // Approximate
        self.temp_max = temperature + 2 // Approximate
        self.humidity = humidity
    }
}

struct Sys: Codable {
    let country: String
    let sunrise: Int
    let sunset: Int
    
    init(country: String) {
        self.country = country
        self.sunrise = 0 // Open-Meteo doesn't provide sunrise/sunset in current weather
        self.sunset = 0
    }
}

// MARK: - Weather Cache
struct WeatherCache {
    let weather: WeatherResponse
    let timestamp: Date
    let city: String
    
    var isValid: Bool {
        // Cache is valid for 1 hour
        Date().timeIntervalSince(timestamp) < 3600
    }
}

// MARK: - Weather Code Mapper
struct WeatherCodeMapper {
    static func mainCondition(for code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1, 2, 3: return "Clouds"
        case 45, 48: return "Fog"
        case 51, 53, 55: return "Drizzle"
        case 61, 63, 65: return "Rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow"
        case 80, 81, 82: return "Rain"
        case 85, 86: return "Snow"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm"
        default: return "Unknown"
        }
    }
    
    static func description(for code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1: return "Mainly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45: return "Fog"
        case 48: return "Depositing rime fog"
        case 51: return "Light drizzle"
        case 53: return "Moderate drizzle"
        case 55: return "Dense drizzle"
        case 61: return "Slight rain"
        case 63: return "Moderate rain"
        case 65: return "Heavy rain"
        case 71: return "Slight snow"
        case 73: return "Moderate snow"
        case 75: return "Heavy snow"
        case 77: return "Snow grains"
        case 80: return "Slight rain showers"
        case 81: return "Moderate rain showers"
        case 82: return "Violent rain showers"
        case 85: return "Slight snow showers"
        case 86: return "Heavy snow showers"
        case 95: return "Thunderstorm"
        case 96: return "Thunderstorm with slight hail"
        case 99: return "Thunderstorm with heavy hail"
        default: return "Unknown"
        }
    }
    
    static func icon(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 71, 73, 75, 77: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.sun.rain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.fill"
        default: return "cloud.fill"
        }
    }
}

// MARK: - Weather Service
class WeatherService: ObservableObject {
    @Published var currentWeather: WeatherResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let baseURL = Config.openMeteoBaseURL
    
    // Default coordinates to try if no location is detected
    private let defaultCoordinates = Config.defaultCoordinates
    private var currentCoordinateIndex = 0
    
    // Caching and session management
    private var weatherCache: WeatherCache?
    private var detectedCity: String?
    private var hasDetectedLocationThisSession = false
    private var hasCalledAPIThisSession = false
    
    init() {
        print("🏁 WeatherService: Initializing with Open-Meteo API (no API key required)")
        
        // Check if we have valid cached weather data
        if let cache = weatherCache, cache.isValid {
            print("✅ WeatherService: Using cached weather data for \(cache.city)")
            DispatchQueue.main.async {
                self.currentWeather = cache.weather
            }
            return
        }
        
        // Only detect location once per session
        if !hasDetectedLocationThisSession {
            detectUserLocationOnce { [weak self] coordinates in
                if let coords = coordinates {
                    print("✅ WeatherService: Detected user's coordinates: \(coords.lat), \(coords.lon)")
                    self?.fetchWeatherOncePerSession(lat: coords.lat, lon: coords.lon)
                } else {
                    print("❌ WeatherService: Could not detect user's location, using default")
                    // Fallback to New York coordinates
                    self?.fetchWeatherOncePerSession(lat: 40.7128, lon: -74.0060) // New York
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    // Optimized method that respects session limits and caching
    private func fetchWeatherOncePerSession(lat: Double, lon: Double) {
        // Check cache first (using coordinates as cache identifier)
        if let cache = weatherCache, cache.isValid {
            print("✅ WeatherService: Using cached weather for coordinates \(lat), \(lon)")
            DispatchQueue.main.async {
                self.currentWeather = cache.weather
            }
            return
        }
        
        // Check if we've already made an API call this session
        if hasCalledAPIThisSession {
            print("⚠️ WeatherService: API call already made this session, using cached data or skipping")
            return
        }
        
        print("🌤️ WeatherService: Making optimized API call for coordinates \(lat), \(lon)")
        hasCalledAPIThisSession = true
        
        // Ensure loading state is updated on main thread
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        fetchWeatherForCoordinates(lat: lat, lon: lon)
    }
    
    
    func tryNextDefaultLocation() {
        currentCoordinateIndex = (currentCoordinateIndex + 1) % defaultCoordinates.count
        let nextLocation = defaultCoordinates[currentCoordinateIndex]
        
        print("🔄 WeatherService: Trying next default location: \(nextLocation.name)")
        
        // Check cache first
        if let cache = weatherCache, cache.isValid {
            print("✅ WeatherService: Using cached weather for next location: \(nextLocation.name)")
            DispatchQueue.main.async {
                self.currentWeather = cache.weather
            }
            return
        }
        
        // Only make API call if we haven't already this session
        if !hasCalledAPIThisSession {
            fetchWeatherOncePerSession(lat: nextLocation.lat, lon: nextLocation.lon)
        } else {
            print("⚠️ WeatherService: API call limit reached, cannot try next location")
        }
    }
    
    // Refresh weather for user's current location (respects session limits)
    func refreshUserLocation() {
        // Check if we have valid cached data
        if let cache = weatherCache, cache.isValid {
            print("✅ WeatherService: Using cached weather data")
            DispatchQueue.main.async {
                self.currentWeather = cache.weather
            }
            return
        }
        
        // Only make API call if we haven't already this session
        if !hasCalledAPIThisSession {
            print("🔄 WeatherService: Refreshing user location...")
            
            // Try to detect location again (will use cached detection if already done)
            detectUserLocationOnce { [weak self] coordinates in
                if let coords = coordinates {
                    print("✅ WeatherService: Using coordinates for refresh: \(coords.lat), \(coords.lon)")
                    self?.fetchWeatherOncePerSession(lat: coords.lat, lon: coords.lon)
                } else {
                    print("❌ WeatherService: Could not get coordinates, using default (New York)")
                    self?.fetchWeatherOncePerSession(lat: 40.7128, lon: -74.0060)
                }
            }
        } else {
            print("⚠️ WeatherService: API call limit reached for this session")
        }
    }
    
    // MARK: - Private Methods
    
    
    // Detect user's location using multiple methods (once per session)
    private func detectUserLocationOnce(completion: @escaping ((lat: Double, lon: Double)?) -> Void) {
        // Only detect location once per session
        if hasDetectedLocationThisSession {
            print("⚠️ WeatherService: Location already detected this session")
            completion(nil) // We don't store coordinates, so return nil
            return
        }
        
        hasDetectedLocationThisSession = true
        print("🌍 WeatherService: Detecting user location using multiple methods...")
        
        // Method 1: Try IP geolocation first (most accurate)
        detectLocationViaIP { [weak self] coordinates in
            if let coords = coordinates {
                print("✅ WeatherService: Got coordinates from IP: \(coords.lat), \(coords.lon)")
                completion(coords)
            } else {
                print("🔄 WeatherService: IP geolocation failed, trying device-based detection...")
                // Method 2: Fallback to device timezone + locale
                let deviceCoords = self?.detectLocationFromDevice()
                if let coords = deviceCoords {
                    print("✅ WeatherService: Got coordinates from device: \(coords.lat), \(coords.lon)")
                    completion(coords)
        } else {
                    print("❌ WeatherService: All location detection methods failed")
                    completion(nil)
                }
            }
        }
    }
    
    // Method 1: IP-based geolocation
    private func detectLocationViaIP(completion: @escaping ((lat: Double, lon: Double)?) -> Void) {
        print("🌐 WeatherService: Trying IP geolocation...")
        
        // Using ipinfo.io - free service with good accuracy
        guard let url = URL(string: "https://ipinfo.io/json") else {
            print("❌ WeatherService: Invalid IP geolocation URL")
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ WeatherService: IP geolocation error: \(error)")
                completion(nil)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 WeatherService: IP geolocation HTTP status: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                print("❌ WeatherService: No IP geolocation data received")
                completion(nil)
                return
            }
            
            print("🌐 WeatherService: IP geolocation data received: \(data.count) bytes")
            
            do {
                let locationResponse = try JSONDecoder().decode(IPLocationResponse.self, from: data)
                print("✅ WeatherService: IP geolocation success: \(locationResponse.city), \(locationResponse.region), \(locationResponse.country)")
                
                // Return the coordinates directly
                if let coordinates = locationResponse.coordinates {
                    print("✅ WeatherService: Extracted IP coordinates: \(coordinates.lat), \(coordinates.lon)")
                    completion(coordinates)
            } else {
                    print("❌ WeatherService: Could not extract coordinates from IP response")
                    completion(nil)
                }
            } catch {
                print("❌ WeatherService: IP geolocation decode error: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🌐 WeatherService: Raw IP response: \(responseString)")
                }
                completion(nil)
            }
        }.resume()
    }
    
    // Method 2: Device-based location detection (timezone + locale)
    private func detectLocationFromDevice() -> (lat: Double, lon: Double)? {
        print("📱 WeatherService: Trying device-based location detection...")
        
        // Get timezone identifier
        let timezone = TimeZone.current
        let timezoneID = timezone.identifier
        print("📱 WeatherService: Device timezone: \(timezoneID)")
        
        // Get locale information
        let locale = Locale.current
        let countryCode = locale.region?.identifier ?? "US"
        let languageCode = locale.language.languageCode?.identifier ?? "en"
        print("📱 WeatherService: Device locale: \(countryCode), language: \(languageCode)")
        
        // Map timezone to approximate coordinates
        let coordinates = getCoordinatesFromTimezone(timezoneID, countryCode: countryCode)
        
        if let coords = coordinates {
            print("✅ WeatherService: Mapped timezone to coordinates: \(coords.lat), \(coords.lon)")
        } else {
            print("❌ WeatherService: Could not map timezone to coordinates")
        }
        
        return coordinates
    }
    
    // Map timezone and country to approximate coordinates
    private func getCoordinatesFromTimezone(_ timezoneID: String, countryCode: String) -> (lat: Double, lon: Double)? {
        print("🗺️ WeatherService: Mapping timezone \(timezoneID) + country \(countryCode)")
        
        // Major timezone to coordinates mapping
        let timezoneCoordinates: [String: (lat: Double, lon: Double)] = [
            // North America
            "America/New_York": (40.7128, -74.0060),      // New York
            "America/Chicago": (41.8781, -87.6298),        // Chicago
            "America/Denver": (39.7392, -104.9903),        // Denver
            "America/Los_Angeles": (34.0522, -118.2437),   // Los Angeles
            "America/Phoenix": (33.4484, -112.0740),       // Phoenix
            "America/Toronto": (43.6532, -79.3832),        // Toronto
            "America/Vancouver": (49.2827, -123.1207),     // Vancouver
            "America/Mexico_City": (19.4326, -99.1332),    // Mexico City
            
            // Europe
            "Europe/London": (51.5074, -0.1278),           // London
            "Europe/Paris": (48.8566, 2.3522),             // Paris
            "Europe/Berlin": (52.5200, 13.4050),           // Berlin
            "Europe/Rome": (41.9028, 12.4964),             // Rome
            "Europe/Madrid": (40.4168, -3.7038),           // Madrid
            "Europe/Amsterdam": (52.3676, 4.9041),         // Amsterdam
            "Europe/Stockholm": (59.3293, 18.0686),        // Stockholm
            "Europe/Moscow": (55.7558, 37.6176),           // Moscow
            
            // Asia
            "Asia/Tokyo": (35.6762, 139.6503),             // Tokyo
            "Asia/Shanghai": (31.2304, 121.4737),          // Shanghai
            "Asia/Hong_Kong": (22.3193, 114.1694),         // Hong Kong
            "Asia/Singapore": (1.3521, 103.8198),          // Singapore
            "Asia/Seoul": (37.5665, 126.9780),             // Seoul
            "Asia/Mumbai": (19.0760, 72.8777),             // Mumbai
            "Asia/Dubai": (25.2048, 55.2708),              // Dubai
            "Asia/Bangkok": (13.7563, 100.5018),           // Bangkok
            
            // Australia/Oceania
            "Australia/Sydney": (-33.8688, 151.2093),      // Sydney
            "Australia/Melbourne": (-37.8136, 144.9631),   // Melbourne
            "Australia/Perth": (-31.9505, 115.8605),       // Perth
            "Pacific/Auckland": (-36.8485, 174.7633),      // Auckland
            
            // South America
            "America/Sao_Paulo": (-23.5505, -46.6333),     // São Paulo
            "America/Buenos_Aires": (-34.6118, -58.3960),  // Buenos Aires
            "America/Lima": (-12.0464, -77.0428),          // Lima
            
            // Africa
            "Africa/Cairo": (30.0444, 31.2357),            // Cairo
            "Africa/Lagos": (6.5244, 3.3792),              // Lagos
            "Africa/Johannesburg": (-26.2041, 28.0473),    // Johannesburg
            
            // Middle East
            "Asia/Jerusalem": (31.7683, 35.2137),          // Jerusalem
            "Asia/Tehran": (35.6892, 51.3890),             // Tehran
        ]
        
        // Try exact timezone match first
        if let coords = timezoneCoordinates[timezoneID] {
            print("✅ WeatherService: Found exact timezone match")
            return coords
        }
        
        // Try partial timezone matching
        for (timezone, coords) in timezoneCoordinates {
            if timezoneID.contains(timezone.components(separatedBy: "/").last ?? "") {
                print("✅ WeatherService: Found partial timezone match")
                return coords
            }
        }
        
        // Fallback to country-based coordinates
        let countryCoordinates: [String: (lat: Double, lon: Double)] = [
            "US": (39.8283, -98.5795),      // United States center
            "CA": (56.1304, -106.3468),     // Canada center
            "GB": (55.3781, -3.4360),       // United Kingdom center
            "DE": (51.1657, 10.4515),       // Germany center
            "FR": (46.2276, 2.2137),        // France center
            "JP": (36.2048, 138.2529),      // Japan center
            "AU": (-25.2744, 133.7751),     // Australia center
            "CN": (35.8617, 104.1954),      // China center
            "IN": (20.5937, 78.9629),       // India center
            "BR": (-14.2350, -51.9253),     // Brazil center
        ]
        
        if let coords = countryCoordinates[countryCode] {
            print("✅ WeatherService: Using country-based coordinates for \(countryCode)")
            return coords
        }
        
        print("❌ WeatherService: No mapping found for timezone or country")
        return nil
    }
    
    
    private func fetchWeatherForCoordinates(lat: Double, lon: Double) {
        // Open-Meteo API URL for current weather
        let urlString = "\(baseURL)/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m&timezone=auto"
        
        guard let url = URL(string: urlString) else {
            print("❌ WeatherService: Invalid weather URL")
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Invalid URL"
            }
            return
        }
        
        print("🌤️ WeatherService: Weather URL: \(url)")
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("❌ WeatherService: Weather network error: \(error)")
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.errorMessage = "Network error: \(error.localizedDescription)"
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌤️ WeatherService: Weather HTTP status: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                print("❌ WeatherService: No weather data received")
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.errorMessage = "No data received"
                }
                return
            }
            
            print("🌤️ WeatherService: Weather data received: \(data.count) bytes")
            
            do {
                let openMeteoResponse = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
                print("✅ WeatherService: Open-Meteo decode success: \(openMeteoResponse.current.temperature_2m)°C")
                
                // Get city name using reverse geocoding
                self?.getCityName(from: lat, lon: lon) { cityName in
                    // Convert Open-Meteo response to our WeatherResponse format with city name
                    let weatherResponse = self?.convertOpenMeteoToWeatherResponse(openMeteoResponse, lat: lat, lon: lon, cityName: cityName)
                    
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        self?.currentWeather = weatherResponse
                        self?.errorMessage = nil
                        
                        // Cache the weather data
                        if let weather = weatherResponse {
                            self?.weatherCache = WeatherCache(
                                weather: weather,
                                timestamp: Date(),
                                city: cityName
                            )
                            print("💾 WeatherService: Cached weather data for \(cityName)")
                        }
                    }
                }
            } catch {
                print("❌ WeatherService: Weather decode error: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🌤️ WeatherService: Raw weather response: \(responseString)")
                }
                
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.errorMessage = "Failed to get weather data. Please try again."
                }
            }
        }.resume()
    }
    
    // Convert Open-Meteo response to our WeatherResponse format
    private func convertOpenMeteoToWeatherResponse(_ response: OpenMeteoResponse, lat: Double, lon: Double, cityName: String) -> WeatherResponse {
        let current = response.current
        
        let location = LocationInfo(
            name: cityName,
            country: "Unknown",
            timezone: "UTC"
        )
        
        return WeatherResponse(
            current: CurrentWeather(
                temperature_2m: current.temperature_2m,
                relative_humidity_2m: current.relative_humidity_2m,
                weather_code: current.weather_code,
                wind_speed_10m: current.wind_speed_10m,
                wind_direction_10m: current.wind_direction_10m
            ),
            location: location
        )
    }
    
    // MARK: - Reverse Geocoding
    private func getCityName(from lat: Double, lon: Double, completion: @escaping (String) -> Void) {
        let urlString = "https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=\(lat)&longitude=\(lon)&localityLanguage=en"
        
        guard let url = URL(string: urlString) else {
            completion("Unknown Location")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ WeatherService: Reverse geocoding error: \(error)")
                completion("Unknown Location")
                return
            }
            
            guard let data = data else {
                completion("Unknown Location")
                return
            }
            
            do {
                let geocodingResponse = try JSONDecoder().decode(ReverseGeocodingResponse.self, from: data)
                if let result = geocodingResponse.results.first {
                    completion(result.displayName)
                } else {
                    completion("Unknown Location")
                }
            } catch {
                print("❌ WeatherService: Reverse geocoding decode error: \(error)")
                completion("Unknown Location")
            }
        }.resume()
    }
    
    // MARK: - Helper Methods
    func getWeatherIcon(for weather: Weather) -> String {
        return weather.icon
    }
    
    func getWeatherColor(for weather: Weather) -> Color {
        switch weather.id {
        case 0: return .yellow
        case 1, 2: return .orange
        case 3: return .gray
        case 45, 48: return .gray
        case 51, 53, 55: return .blue
        case 61, 63, 65: return .blue
        case 71, 73, 75, 77: return .white
        case 80, 81, 82: return .blue
        case 85, 86: return .white
        case 95, 96, 99: return .purple
        default: return .gray
        }
    }
}


    // MARK: - Open-Meteo API Response
struct OpenMeteoResponse: Codable {
    let current: OpenMeteoCurrent
}

struct OpenMeteoCurrent: Codable {
    let temperature_2m: Double
    let relative_humidity_2m: Int
    let weather_code: Int
    let wind_speed_10m: Double
    let wind_direction_10m: Int
}

// MARK: - Reverse Geocoding Response
struct ReverseGeocodingResponse: Codable {
    let results: [GeocodingResult]
}

struct GeocodingResult: Codable {
    let name: String
    let country: String
    let admin1: String?
    let admin2: String?
    
    var displayName: String {
        if let admin1 = admin1, !admin1.isEmpty {
            return "\(name), \(admin1)"
        } else {
            return "\(name), \(country)"
        }
    }
}

// MARK: - IP Geolocation Response
struct IPLocationResponse: Codable {
    let city: String
    let region: String
    let country: String
    let loc: String // "latitude,longitude"
    let timezone: String
    
    var coordinates: (lat: Double, lon: Double)? {
        let parts = loc.split(separator: ",")
        guard parts.count == 2,
              let lat = Double(parts[0]),
              let lon = Double(parts[1]) else {
            return nil
        }
        return (lat: lat, lon: lon)
    }
}
