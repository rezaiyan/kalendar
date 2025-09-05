//
//  WeatherComponents.swift
//  Kalendar
//
//  Created by Ali Rezaiyan on 18.08.25.
//

import SwiftUI

// MARK: - Weather Card Section
struct WeatherCardSection: View {
    @ObservedObject var weatherService: WeatherService
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .modifier(LoadingPulseModifier(isLoading: weatherService.isLoading))
                
                Text("Today's Weather")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                
                Spacer()
                
                if weatherService.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .transition(.scale.combined(with: .opacity))
                } else if weatherService.currentWeather != nil || weatherService.errorMessage != nil {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            weatherService.refreshUserLocation()
                        }
                    }) {
                        Image(systemName: "location.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: weatherService.isLoading)
            
            // Weather content with animations
            Group {
                if let weather = weatherService.currentWeather {
                    WeatherCard(weather: weather, weatherService: weatherService)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .top)),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                } else if let errorMessage = weatherService.errorMessage {
                    ErrorCard(message: errorMessage, weatherService: weatherService)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .top)),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                } else {
                    LoadingCard()
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .top)),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                }
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.2), value: weatherService.currentWeather != nil)
            .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.2), value: weatherService.errorMessage != nil)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Weather Card
struct WeatherCard: View {
    let weather: WeatherResponse
    let weatherService: WeatherService
    @State private var animateContent = false
    
    var body: some View {
        let weatherInfo = Weather(weatherCode: weather.current.weather_code)
        
        return VStack(spacing: 0) {
            // Header with weather condition and icon
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(weatherInfo.description.capitalized)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : -20)
                }
                
                Spacer()
                
                Image(systemName: weatherService.getWeatherIcon(for: weatherInfo))
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(weatherService.getWeatherColor(for: weatherInfo))
                    .symbolEffect(.pulse, options: .repeating)
                    .scaleEffect(animateContent ? 1 : 0.5)
                    .rotationEffect(.degrees(animateContent ? 0 : -180))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Temperature display
            HStack(alignment: .top) {
                Text("\(Int(weather.current.temperature_2m))")
                    .font(.system(size: 64, weight: .thin, design: .rounded))
                    .foregroundColor(.primary)
                    .scaleEffect(animateContent ? 1 : 0.8)
                    .opacity(animateContent ? 1 : 0)
                
                Text("°C")
                    .font(.system(size: 24, weight: .light, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                    .opacity(animateContent ? 1 : 0)
                    .offset(x: animateContent ? 0 : -10)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Weather details grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
                ModernWeatherDetail(
                    icon: "thermometer.medium",
                    title: "Feels like",
                    value: "\(Int(weather.current.temperature_2m))°",
                    color: .orange
                )
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.2), value: animateContent)
                
                ModernWeatherDetail(
                    icon: "humidity",
                    title: "Humidity",
                    value: "\(weather.current.relative_humidity_2m)%",
                    color: .blue
                )
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.3), value: animateContent)
                
                ModernWeatherDetail(
                    icon: "wind",
                    title: "Wind",
                    value: "\(Int(weather.current.wind_speed_10m)) km/h",
                    color: .cyan
                )
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.4), value: animateContent)
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
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7, blendDuration: 0.3)) {
                animateContent = true
            }
        }
    }
}

// MARK: - Modern Weather Detail
struct ModernWeatherDetail: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
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
}

// MARK: - Error Card
struct ErrorCard: View {
    let message: String
    let weatherService: WeatherService
    
    var body: some View {
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
                withAnimation(.easeInOut(duration: 0.3)) {
                    weatherService.tryNextDefaultLocation()
                }
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
}

// MARK: - Loading Card
struct LoadingCard: View {
    var body: some View {
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
}


// MARK: - Loading Pulse Modifier
struct LoadingPulseModifier: ViewModifier {
    let isLoading: Bool
    
    func body(content: Content) -> some View {
        if isLoading {
            content
                .symbolEffect(.pulse, options: .repeating)
        } else {
            content
        }
    }
}
