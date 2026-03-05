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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    CalendarView(viewModel: viewModel)

                    DayTimelineView(viewModel: viewModel)

                    DayDetailView(viewModel: viewModel, onAddEvent: { showEventEditor = true })
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Kalendar")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showEventEditor = true } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button { viewModel.goToToday() } label: {
                            Text("Today")
                                .font(.subheadline.weight(.medium))
                        }
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showEventEditor) {
                EventEditorView(viewModel: viewModel, initialDate: viewModel.selectedDate)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                if !viewModel.calendarAccessGranted {
                    Task { await viewModel.requestCalendarAccess() }
                }
            }
        }
        .tint(accentColorFor(accentColorName))
    }
}

#Preview {
    ContentView()
}
