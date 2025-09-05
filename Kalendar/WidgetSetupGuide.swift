//
//  WidgetSetupGuide.swift
//  Kalendar
//
//  Created by Ali Rezaiyan on 18.08.25.
//

import SwiftUI

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
