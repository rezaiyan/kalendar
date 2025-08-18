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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                calendarSection
                Spacer()
                widgetGuideSection
            }
            .background(backgroundGradient)
            .navigationBarHidden(true)
            .sheet(isPresented: $showWidgetGuide) {
                WidgetSetupGuide()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Fix for iPad
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(currentMonthYear)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("Today is \(currentDayName)")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
        .padding(.bottom, 30)
    }
    
    // MARK: - Calendar Section
    private var calendarSection: some View {
        VStack(spacing: calendarSpacing) {
            weekdayHeaders
            calendarGrid
        }
        .padding(.horizontal, horizontalPadding)
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
            selectedDate = Calendar.current.date(bySetting: .day, value: day, of: selectedDate) ?? selectedDate
        }) {
            Text("\(day)")
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundColor(day == Calendar.current.component(.day, from: Date()) ? .white : .primary)
                .frame(width: 44, height: 44)
                .background(dayBackground(for: day))
                .overlay(dayOverlay(for: day))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Day Background
    private func dayBackground(for day: Int) -> some View {
        Group {
            if day == Calendar.current.component(.day, from: Date()) {
                Circle()
                    .fill(dayGradient)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.1))
            }
        }
    }
    
    // MARK: - Day Overlay
    private func dayOverlay(for day: Int) -> some View {
        Circle()
            .stroke(day == Calendar.current.component(.day, from: selectedDate) ? Color.blue : Color.clear, lineWidth: 2)
    }
    
    // MARK: - Empty Calendar Day
    private var emptyCalendarDay: some View {
        Text("")
            .frame(width: 44, height: 44)
    }
    
    // MARK: - Widget Guide Section
    private var widgetGuideSection: some View {
        VStack(spacing: 16) {
            // Selected date info
            Text("Selected: \(selectedDateString)")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
            
            // Widget setup button
            Button(action: {
                showWidgetGuide = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.square.on.square")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add Widget to Home Screen")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Get quick access to your calendar")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // MARK: - Open Source Project Footer
            VStack(spacing: 8) {
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                    
                    Text("Open Source Project")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("GitHub") {
                        if let url = URL(string: "https://github.com/rezaiyan/kalendar") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
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
        NavigationView {
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
