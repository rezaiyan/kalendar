//
//  WeatherService.swift
//  Kalendar
//
//  Created by Ali Rezaiyan on 18.08.25.
//

import Foundation
import SwiftUI

// MARK: - Weather Models
struct WeatherResponse: Codable {
    let weather: [Weather]
    let main: Main
    let name: String
    let sys: Sys
}

struct Weather: Codable {
    let id: Int
    let main: String
    let description: String
    let icon: String
}

struct Main: Codable {
    let temp: Double
    let feels_like: Double
    let temp_min: Double
    let temp_max: Double
    let humidity: Int
}

struct Sys: Codable {
    let country: String
    let sunrise: Int
    let sunset: Int
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

// MARK: - Weather Service
class WeatherService: ObservableObject {
    @Published var currentWeather: WeatherResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiKey = Config.openWeatherAPIKey
    private let baseURL = Config.openWeatherBaseURL
    
    // Default coordinates to try if no location is detected
    private let defaultCoordinates = Config.defaultCoordinates
    private var currentCoordinateIndex = 0
    
    // Caching and session management
    private var weatherCache: WeatherCache?
    private var detectedCity: String?
    private var hasDetectedLocationThisSession = false
    private var hasCalledAPIThisSession = false
    
    init() {
        print("🏁 WeatherService: Initializing with cache optimization")
        
        // Validate API key format
        validateAPIKey()
        
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
        // Check cache first (using coordinates as cache key)
        let cacheKey = "\(lat),\(lon)"
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
    
    // Validate API key format and provide helpful feedback
    private func validateAPIKey() {
        print("🔑 WeatherService: Validating API key...")
        
        if apiKey.isEmpty {
            print("❌ WeatherService: API key is empty!")
            DispatchQueue.main.async {
                self.errorMessage = "API key is not configured. Please add your OpenWeather API key."
            }
            return
        }
        
        // OpenWeather API keys are typically 32 characters long and contain only alphanumeric characters
        if apiKey.count != 32 {
            print("⚠️ WeatherService: API key length is \(apiKey.count), expected 32 characters")
        }
        
        let validCharacters = CharacterSet.alphanumerics
        if apiKey.rangeOfCharacter(from: validCharacters.inverted) != nil {
            print("⚠️ WeatherService: API key contains invalid characters")
        }
        
        print("🔑 WeatherService: API key format check complete (length: \(apiKey.count))")
    }
    
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
        guard let url = URL(string: "\(baseURL)/weather?lat=\(lat)&lon=\(lon)&appid=\(apiKey)&units=metric") else {
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
                let weatherResponse = try JSONDecoder().decode(WeatherResponse.self, from: data)
                print("✅ WeatherService: Weather decode success: \(weatherResponse.name), \(weatherResponse.main.temp)°C")
                
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.currentWeather = weatherResponse
                    self?.errorMessage = nil
                    
                    // Cache the weather data
                    self?.weatherCache = WeatherCache(
                        weather: weatherResponse,
                        timestamp: Date(),
                        city: weatherResponse.name
                    )
                    print("💾 WeatherService: Cached weather data for \(weatherResponse.name)")
                }
            } catch {
                print("❌ WeatherService: Weather decode error: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🌤️ WeatherService: Raw weather response: \(responseString)")
                    
                    // Check for specific API errors
                    if responseString.contains("\"cod\":401") {
                        print("🔑 WeatherService: API key error detected")
                        DispatchQueue.main.async {
                            self?.isLoading = false
                            self?.errorMessage = "Invalid API key. Please check your OpenWeather API key."
                        }
                        return
                    } else if responseString.contains("\"cod\":429") {
                        print("⚠️ WeatherService: Rate limit exceeded")
                        DispatchQueue.main.async {
                            self?.isLoading = false
                            self?.errorMessage = "API rate limit exceeded. Please try again later."
                        }
                        return
                    } else if responseString.contains("\"cod\":404") {
                        print("🗺️ WeatherService: Location not found")
                        DispatchQueue.main.async {
                            self?.isLoading = false
                            self?.errorMessage = "Location not found. Trying next location..."
                        }
                        return
                    }
                }
                
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.errorMessage = "Failed to get weather data. Please try again."
                }
            }
        }.resume()
    }
    
    // MARK: - Helper Methods
    func getWeatherIcon(for weather: Weather) -> String {
        switch weather.icon {
        case "01d", "01n": return "sun.max.fill"
        case "02d", "02n": return "cloud.sun.fill"
        case "03d", "03n": return "cloud.fill"
        case "04d", "04n": return "cloud.fill"
        case "09d", "09n": return "cloud.rain.fill"
        case "10d", "10n": return "cloud.sun.rain.fill"
        case "11d", "11n": return "cloud.bolt.fill"
        case "13d", "13n": return "cloud.snow.fill"
        case "50d", "50n": return "cloud.fog.fill"
        default: return "cloud.fill"
        }
    }
    
    func getWeatherColor(for weather: Weather) -> Color {
        switch weather.icon {
        case "01d", "01n": return .yellow
        case "02d", "02n": return .orange
        case "03d", "03n", "04d", "04n": return .gray
        case "09d", "09n", "10d", "10n": return .blue
        case "11d", "11n": return .purple
        case "13d", "13n": return .white
        case "50d", "50n": return .gray
        default: return .gray
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
