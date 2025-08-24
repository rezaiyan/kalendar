import Foundation
import CoreLocation
import SwiftUI

// MARK: - Shared Weather Types (Copy for Main App)
struct SharedWeatherInfo: Codable {
    let weatherCode: Int
    let temperature: Double
    let minTemp: Double
    let maxTemp: Double
    let humidity: Double
    let windSpeed: Double
    let date: Date
}

class SharedWeatherService {
    static let shared = SharedWeatherService()
    
    // Use App Groups for sharing data between main app and widgets
    private let userDefaults = UserDefaults(suiteName: "group.com.alirezaiyan.Kalendar")
    private let weatherDataKey = "SharedWeatherData"
    
    private init() {}
    
    // MARK: - Save Weather Data
    func saveWeatherData(_ weatherData: [String: SharedWeatherInfo]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(weatherData)
            userDefaults?.set(data, forKey: weatherDataKey)
            print("🌐 [SHARED] ✅ Weather data saved to shared container")
        } catch {
            print("🌐 [SHARED] ❌ Failed to save weather data: \(error.localizedDescription)")
        }
    }
}

@MainActor
class WeatherService: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published var weatherData: [String: WeatherInfo] = [:]
    @Published var isLoading = false
    @Published var error: String?
    @Published var shouldShowLocationRequest = false
    
    private let locationManager = CLLocationManager()
    var currentLocation: CLLocation?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        
        // For testing in simulator, set a mock location (San Francisco)
        #if targetEnvironment(simulator)
        currentLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        #endif
        
        // TestFlight-specific optimizations
        #if DEBUG
        print("🌐 [INIT] Debug build - enhanced logging enabled")
        #else
        print("🌐 [INIT] Release/TestFlight build - optimized for production")
        #endif
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() {
        let status = locationManager.authorizationStatus
        
        print("🌐 [LOCATION] 🔐 Current authorization status: \(status.rawValue)")
        #if DEBUG
        print("🌐 [LOCATION] 📱 TestFlight build: NO")
        #else
        print("🌐 [LOCATION] 📱 TestFlight build: YES")
        #endif
        
        switch status {
        case .notDetermined:
            print("🌐 [LOCATION] 📱 Requesting location permission...")
            locationManager.requestWhenInUseAuthorization()
            
            // For TestFlight, add a fallback timer to ensure location is requested
            #if !DEBUG
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if self.currentLocation == nil {
                    print("🌐 [LOCATION] 🔄 TestFlight fallback: requesting location again")
                    self.locationManager.requestWhenInUseAuthorization()
                }
            }
            #endif
            
        case .denied:
            print("🌐 [LOCATION] ❌ Location permission denied - cannot request location")
            error = "Location access required for weather. Please enable in Settings > Privacy & Security > Location Services > Kalendar"
            shouldShowLocationRequest = true
            
            // Try to use mock location for testing (including TestFlight fallback)
            if currentLocation == nil {
                print("🌐 [LOCATION] 🔄 Attempting to use fallback location")
                #if targetEnvironment(simulator)
                currentLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
                print("🌐 [LOCATION] ✅ Mock location set for simulator")
                #else
                // For TestFlight, use a default location as fallback
                currentLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
                print("🌐 [LOCATION] ✅ Fallback location set for TestFlight")
                #endif
                
                Task {
                    await fetchWeatherForCurrentMonth()
                }
            }
            
        case .restricted:
            print("🌐 [LOCATION] ❌ Location access restricted")
            error = "Location access is restricted. Please check your device settings."
            
            // For TestFlight, try fallback location
            if currentLocation == nil {
                print("🌐 [LOCATION] 🔄 TestFlight restricted fallback: using default location")
                currentLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
                Task {
                    await fetchWeatherForCurrentMonth()
                }
            }
            
        case .authorizedWhenInUse, .authorizedAlways:
            print("🌐 [LOCATION] ✅ Location permission granted - requesting location")
            locationManager.requestLocation()
            
        @unknown default:
            print("🌐 [LOCATION] ❓ Unknown authorization status: \(status.rawValue)")
            error = "Unknown location authorization status"
            
            // For TestFlight, try fallback location
            if currentLocation == nil {
                print("🌐 [LOCATION] 🔄 TestFlight unknown status fallback: using default location")
                currentLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
                Task {
                    await fetchWeatherForCurrentMonth()
                }
            }
        }
    }
    
    func fetchWeatherForDates(_ dates: [Date]) async {
        guard let location = currentLocation else {
            // If no location, try to request it and show a helpful message
            print("🌐 [NETWORK] ❌ No location available, requesting location access")
            requestLocation()
            error = "Location not available. Please allow location access in Settings."
            return
        }
        
        print("🌐 [NETWORK] 🚀 Starting weather fetch for \(dates.count) dates")
        print("🌐 [NETWORK] 📍 Using location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        print("🌐 [NETWORK] 📅 Dates to fetch: \(dates.map { formatDate($0) })")
        
        isLoading = true
        error = nil
        
        let overallStartTime = Date()
        var successfulFetches = 0
        var failedFetches = 0
        
        do {
            for (index, date) in dates.enumerated() {
                let dateString = formatDate(date)
                print("🌐 [NETWORK] 📡 [\(index + 1)/\(dates.count)] Fetching weather for \(dateString)")
                
                // Try to fetch weather with retry (enhanced for TestFlight)
                var weather: WeatherInfo?
                var lastError: Error?
                
                #if DEBUG
                let maxAttempts = 2 // Debug build
                #else
                let maxAttempts = 3 // More retries for TestFlight
                #endif
                for attempt in 1...maxAttempts {
                    do {
                        if attempt > 1 {
                            print("🌐 [NETWORK] 🔄 Retry attempt \(attempt)/\(maxAttempts) for \(dateString)")
                        }
                        
                        weather = try await fetchWeatherForDate(date, at: location)
                        break
                    } catch {
                        lastError = error
                        if attempt < maxAttempts {
                            #if DEBUG
                            let waitTime = 1.0 // Debug build
                            #else
                            let waitTime = 2.0 // Longer wait for TestFlight
                            #endif
                            print("🌐 [NETWORK] ⏳ Waiting \(waitTime) seconds before retry for \(dateString)")
                            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                        }
                    }
                }
                
                if let weather = weather {
                    weatherData[dateString] = weather
                    successfulFetches += 1
                    print("🌐 [NETWORK] ✅ Successfully stored weather for \(dateString)")
                    
                    // Save to shared container for widget synchronization
                    saveWeatherDataToSharedContainer()
                } else if let lastError = lastError {
                    failedFetches += 1
                    print("🌐 [NETWORK] ❌ Failed to fetch weather for \(dateString) after all attempts")
                    print("🌐 [NETWORK] 🔍 Final error: \(lastError.localizedDescription)")
                }
            }
        } catch {
            print("🌐 [NETWORK] 💥 Critical error in weather fetching: \(error.localizedDescription)")
            self.error = "Weather error: \(error.localizedDescription)"
        }
        
        let overallEndTime = Date()
        let totalDuration = overallEndTime.timeIntervalSince(overallStartTime)
        
        print("🌐 [NETWORK] 🏁 Weather fetch completed:")
        print("   - Total duration: \(String(format: "%.2f", totalDuration))s")
        print("   - Successful fetches: \(successfulFetches)/\(dates.count)")
        print("   - Failed fetches: \(failedFetches)/\(dates.count)")
        print("   - Success rate: \(String(format: "%.1f", Double(successfulFetches) / Double(dates.count) * 100))%")
        
        isLoading = false
    }
    
    private func fetchWeatherForDate(_ date: Date, at location: CLLocation) async throws -> WeatherInfo {
        let baseURL = "https://api.open-meteo.com/v1/forecast"
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        let urlString = "\(baseURL)?latitude=\(latitude)&longitude=\(longitude)&daily=weather_code,temperature_2m_max,temperature_2m_min,relative_humidity_2m_max,wind_speed_10m_max&timezone=auto&start_date=\(dateString)&end_date=\(dateString)"
        
        guard let url = URL(string: urlString) else {
            print("🌐 [NETWORK] ❌ Invalid URL: \(urlString)")
            throw WeatherError.invalidURL
        }
        
        print("🌐 [NETWORK] 📡 Starting request for date: \(dateString)")
        print("🌐 [NETWORK] 📍 Location: \(latitude), \(longitude)")
        print("🌐 [NETWORK] 🔗 URL: \(urlString)")
        
        let startTime = Date()
        
        // Create a URLSession with timeout and TestFlight optimizations
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0 // Increased timeout for TestFlight
        config.timeoutIntervalForResource = 20.0 // Increased total timeout for TestFlight
        
        // TestFlight-specific network optimizations
        #if !DEBUG
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        print("🌐 [NETWORK] 🚀 TestFlight network optimizations enabled")
        #endif
        
        let session = URLSession(configuration: config)
        
        do {
            let (data, httpResponse) = try await session.data(from: url)
            
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            // Check HTTP response
            if let httpResponse = httpResponse as? HTTPURLResponse {
                print("🌐 [NETWORK] 📊 HTTP Status: \(httpResponse.statusCode)")
                print("🌐 [NETWORK] ⏱️ Request duration: \(String(format: "%.2f", duration))s")
                print("🌐 [NETWORK] 📦 Response size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
                
                guard httpResponse.statusCode == 200 else {
                    print("🌐 [NETWORK] ❌ HTTP Error: \(httpResponse.statusCode)")
                    if let responseHeaders = httpResponse.allHeaderFields as? [String: String] {
                        print("🌐 [NETWORK] 📋 Response headers: \(responseHeaders)")
                    }
                    throw WeatherError.networkError
                }
            }
            
            print("🌐 [NETWORK] ✅ Response received successfully")
            
            let response = try JSONDecoder().decode(WeatherResponse.self, from: data)
            
            // The API returns arrays, so we need to get the first element from each array
            guard !response.daily.time.isEmpty,
                  !response.daily.weather_code.isEmpty,
                  !response.daily.temperature_2m_max.isEmpty,
                  !response.daily.temperature_2m_min.isEmpty,
                  !response.daily.relative_humidity_2m_max.isEmpty,
                  !response.daily.wind_speed_10m_max.isEmpty else {
                print("🌐 [NETWORK] ❌ Empty arrays in response")
                print("🌐 [NETWORK] 📄 Response structure: \(response)")
                throw WeatherError.noData
            }
            
            let weatherCode = response.daily.weather_code[0]
            let maxTemp = response.daily.temperature_2m_max[0]
            let minTemp = response.daily.temperature_2m_min[0]
            let humidity = response.daily.relative_humidity_2m_max[0]
            let windSpeed = response.daily.wind_speed_10m_max[0]
            
            print("🌐 [NETWORK] 🌤️ Weather data parsed successfully:")
            print("   - Weather code: \(weatherCode)")
            print("   - Max temp: \(maxTemp)°C")
            print("   - Min temp: \(minTemp)°C")
            print("   - Humidity: \(humidity)%")
            print("   - Wind speed: \(windSpeed) km/h")
            
            return WeatherInfo(
                weatherCode: weatherCode,
                temperature: maxTemp,
                minTemp: minTemp,
                maxTemp: maxTemp,
                humidity: humidity,
                windSpeed: windSpeed,
                date: date
            )
        } catch let decodingError as DecodingError {
            print("🌐 [NETWORK] ❌ JSON Decoding Error:")
            let errorDescription = String(describing: decodingError)
            print("   - Error details: \(errorDescription)")
            throw WeatherError.networkError
        } catch {
            print("🌐 [NETWORK] ❌ Network Error: \(error.localizedDescription)")
            print("🌐 [NETWORK] 🔍 Error type: \(type(of: error))")
            if let nsError = error as NSError? {
                print("🌐 [NETWORK] 📊 NSError details:")
                print("   - Domain: \(nsError.domain)")
                print("   - Code: \(nsError.code)")
                print("   - User info: \(nsError.userInfo)")
            }
            throw WeatherError.networkError
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // MARK: - TestFlight Optimizations
    func initializeForTestFlight() {
        #if DEBUG
        // Debug build - no special optimizations needed
        #else
        print("🌐 [TESTFLIGHT] 🚀 Initializing TestFlight optimizations...")
        
        // Ensure location manager is properly configured
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 1000 // 1km filter for TestFlight
        
        // Add a small delay to ensure proper initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.requestLocation()
        }
        
        print("🌐 [TESTFLIGHT] ✅ TestFlight optimizations initialized")
        #endif
    }
    
    // MARK: - Error Management
    func clearError() {
        error = nil
    }
    
    // MARK: - Shared Data Management
    private func saveWeatherDataToSharedContainer() {
        // Convert WeatherInfo to SharedWeatherInfo and save to shared container
        let sharedWeatherData = weatherData.mapValues { weatherInfo in
            SharedWeatherInfo(
                weatherCode: weatherInfo.weatherCode,
                temperature: weatherInfo.temperature,
                minTemp: weatherInfo.minTemp,
                maxTemp: weatherInfo.maxTemp,
                humidity: weatherInfo.humidity,
                windSpeed: weatherInfo.windSpeed,
                date: weatherInfo.date
            )
        }
        
        SharedWeatherService.shared.saveWeatherData(sharedWeatherData)
    }
    
    // MARK: - TestFlight Weather Initialization
    func initializeWeatherForTestFlight() async {
        #if DEBUG
        // Debug build - no special initialization needed
        #else
        print("🌐 [TESTFLIGHT] 🌤️ Initializing weather data for TestFlight...")
        
        // Ensure we have a location (use fallback if needed)
        if currentLocation == nil {
            print("🌐 [TESTFLIGHT] 📍 No location available, using fallback")
            currentLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        }
        
        // Fetch weather for current month with TestFlight optimizations
        await fetchWeatherForCurrentMonth()
        
        print("🌐 [TESTFLIGHT] ✅ Weather initialization completed")
        #endif
    }
    
    // MARK: - On-Demand Weather Fetching
    func fetchWeatherForSelectedDate(_ date: Date) async {
        let dateString = formatDate(date)
        
        // Check if we already have weather data for this date
        if weatherData[dateString] != nil {
            print("🌐 [WEATHER] ✅ Weather data already available for \(dateString)")
            return
        }
        
        print("🌐 [WEATHER] 📅 Fetching weather for selected date: \(dateString)")
        
        // Use current location or mock location if available
        guard let location = currentLocation else {
            print("🌐 [WEATHER] ❌ No location available for weather fetch")
            await MainActor.run {
                self.error = "Location not available. Please enable location access."
            }
            return
        }
        
        do {
            let weatherInfo = try await fetchWeatherForDate(date, at: location)
            await MainActor.run {
                weatherData[dateString] = weatherInfo
                error = nil
                print("🌐 [WEATHER] ✅ Successfully fetched weather for \(dateString)")
                
                // Save to shared container for widget synchronization
                saveWeatherDataToSharedContainer()
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to fetch weather for \(dateString): \(error.localizedDescription)"
                print("🌐 [WEATHER] ❌ Failed to fetch weather for \(dateString): \(error)")
            }
        }
    }
    
    // MARK: - Location Manager Delegate Methods
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            if let location = locations.first {
                print("🌐 [LOCATION] 📍 Location updated successfully:")
                print("   - Latitude: \(location.coordinate.latitude)")
                print("   - Longitude: \(location.coordinate.longitude)")
                print("   - Accuracy: \(location.horizontalAccuracy)m")
                print("   - Timestamp: \(location.timestamp)")
                
                currentLocation = location
                await fetchWeatherForCurrentMonth()
            } else {
                print("🌐 [LOCATION] ❌ No valid location in update")
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("🌐 [LOCATION] ❌ Location manager failed:")
            print("   - Error: \(error.localizedDescription)")
            print("   - Error type: \(type(of: error))")
            print("   - Domain: \((error as NSError).domain)")
            print("   - Code: \((error as NSError).code)")
            print("   - User info: \((error as NSError).userInfo)")
            
            // Handle specific location errors
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    print("🌐 [LOCATION] ❌ Location permission denied by user")
                    self.error = "Location access denied. Please enable location access in Settings > Privacy & Security > Location Services > Kalendar"
                case .locationUnknown:
                    print("🌐 [LOCATION] ❌ Location temporarily unavailable")
                    self.error = "Location temporarily unavailable. Please try again."
                default:
                    print("🌐 [LOCATION] ❌ Unknown location error: \(clError.code)")
                    self.error = "Location error: \(clError.localizedDescription)"
                }
            } else {
                self.error = "Location error: \(error.localizedDescription)"
            }
            
            // Try to use mock location for testing if available
            if currentLocation == nil {
                print("🌐 [LOCATION] 🔄 Attempting to use mock location for testing")
                #if targetEnvironment(simulator)
                currentLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
                print("🌐 [LOCATION] ✅ Mock location set for simulator")
                Task {
                    await fetchWeatherForCurrentMonth()
                }
                #endif
            }
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            print("🌐 [LOCATION] 🔄 Authorization status changed to: \(status.rawValue)")
            
            switch status {
            case .denied:
                print("🌐 [LOCATION] ❌ Location access denied by user")
                error = "Location access required for weather. Please enable in Settings > Privacy & Security > Location Services > Kalendar"
                shouldShowLocationRequest = true
                
                // Try to use mock location for testing
                if currentLocation == nil {
                    print("🌐 [LOCATION] 🔄 Attempting to use mock location for testing")
                    #if targetEnvironment(simulator)
                    currentLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
                    print("🌐 [LOCATION] ✅ Mock location set for simulator")
                    await fetchWeatherForCurrentMonth()
                    #endif
                }
            case .restricted:
                print("🌐 [LOCATION] 🚫 Location access restricted")
                error = "Location access is restricted on this device"
                shouldShowLocationRequest = true
            case .authorizedWhenInUse, .authorizedAlways:
                print("🌐 [LOCATION] ✅ Location access granted")
                error = nil
                shouldShowLocationRequest = false
                manager.requestLocation()
            case .notDetermined:
                print("🌐 [LOCATION] 🤔 Location access not determined")
                error = nil
                shouldShowLocationRequest = false
            @unknown default:
                print("🌐 [LOCATION] ❓ Unknown authorization status")
                error = "Unknown location authorization status"
            }
        }
    }
    
    func fetchWeatherForCurrentMonth() async {
        let calendar = Calendar.current
        let today = Date()
        
        // Get weather for the entire current month
        guard let monthInterval = calendar.dateInterval(of: .month, for: today) else {
            print("🌐 [WEATHER] ❌ Failed to get month interval")
            return
        }
        
        let startOfMonth = monthInterval.start
        let endOfMonth = monthInterval.end
        
        // Create array of all dates in the month
        var dates: [Date] = []
        var currentDate = startOfMonth
        
        while currentDate < endOfMonth {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        print("🌐 [WEATHER] 📅 Fetching current month weather:")
        print("   - Month: \(formatDate(today))")
        print("   - Date range: \(formatDate(startOfMonth)) to \(formatDate(endOfMonth))")
        print("   - Total dates: \(dates.count)")
        
        await fetchWeatherForDates(dates)
    }
}

// MARK: - Weather Models
struct WeatherResponse: Codable {
    let daily: DailyData
}

struct DailyData: Codable {
    let time: [String]
    let weather_code: [Int]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
    let relative_humidity_2m_max: [Double]
    let wind_speed_10m_max: [Double]
}

struct WeatherInfo {
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

enum WeatherError: Error, LocalizedError {
    case invalidURL
    case noData
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No weather data available"
        case .networkError:
            return "Network error"
        }
    }
}
