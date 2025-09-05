//
//  Config.swift
//  Kalendar
//
//  Created by Ali Rezaiyan on 18.08.25.
//

import Foundation

struct Config {
    // MARK: - API Keys
    static let openWeatherAPIKey = APIKeys.openWeatherAPIKey
    
    // MARK: - API Configuration
    static let openWeatherBaseURL = "https://api.openweathermap.org/data/2.5"
    static let openWeatherGeocodingURL = "https://api.openweathermap.org/geo/1.0/direct"
    
    // MARK: - Default Coordinates (fallback when no location is available)
    static let defaultCoordinates: [(name: String, lat: Double, lon: Double)] = [
        ("New York", 40.7128, -74.0060),
        ("London", 51.5074, -0.1278),
        ("Tokyo", 35.6762, 139.6503),
        ("Paris", 48.8566, 2.3522),
        ("Sydney", -33.8688, 151.2093)
    ]
}
