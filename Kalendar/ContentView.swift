//
//  ContentView.swift
//  Kalendar
//
//  Created by Ali Rezaiyan on 18.08.25.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = CalendarViewModel()
    @State private var showSettings = false
    @State private var showEventEditor = false
    @AppStorage("accentColorName") private var accentColorName = "blue"

    private var accent: Color { accentColorFor(accentColorName) }

    var body: some View {
        NavigationStack {
            ZStack {
                // Ambient background gradient
                LinearGradient(
                    colors: [
                        accent.opacity(0.08),
                        Color(.systemBackground).opacity(0.5),
                        accent.opacity(0.04),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        CalendarView(viewModel: viewModel)

                        DayTimelineView(viewModel: viewModel)

                        DayDetailView(viewModel: viewModel, onAddEvent: { showEventEditor = true })
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Kalendar")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showEventEditor = true } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.medium))
                            .foregroundStyle(accent)
                            .padding(8)
                            .background {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                                    )
                            }
                    }
                    .buttonStyle(LiquidGlassButtonStyle())
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button { viewModel.goToToday() } label: {
                            Text("Today")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .glassPill()
                        }
                        .buttonStyle(LiquidGlassButtonStyle())

                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                                .font(.body.weight(.medium))
                                .foregroundStyle(accent)
                                .padding(8)
                                .background {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                                        )
                                }
                        }
                        .buttonStyle(LiquidGlassButtonStyle())
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(viewModel: viewModel)
            }
            .sheet(isPresented: $showEventEditor) {
                EventEditorView(viewModel: viewModel, initialDate: viewModel.selectedDate)
            }
            .sheet(isPresented: $viewModel.showCalendarPicker) {
                CalendarPickerView(viewModel: viewModel)
            }
            .task {
                await viewModel.checkExistingAccess()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                Task { await viewModel.checkExistingAccess() }
            }
        }
        .tint(accent)
    }
}

#Preview {
    ContentView()
}
