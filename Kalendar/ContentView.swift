//
//  ContentView.swift
//  Kalendar
//
//  Created by Ali Rezaiyan on 18.08.25.
//

import EventKit
import SwiftUI

/// Initial values for the event editor sheet.
struct EventDraft: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date?
}

struct ContentView: View {
    @State private var viewModel = CalendarViewModel()
    @State private var showSettings = false
    @State private var draft: EventDraft?
    @AppStorage(AccentPalette.storageKey) private var accentColorName = AccentPalette.blue.rawValue
    @Environment(\.scenePhase) private var scenePhase

    private var accent: Color { AccentPalette.color(for: accentColorName) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.section) {
                    CalendarView(viewModel: viewModel)

                    DayTimelineView(viewModel: viewModel) { slot in
                        draft = EventDraft(start: slot.start, end: min(slot.end, slot.start.addingTimeInterval(3600)))
                    }

                    DayDetailView(viewModel: viewModel) {
                        draft = EventDraft(start: viewModel.selectedDate, end: nil)
                    }
                }
                .padding(.horizontal, Theme.Spacing.gutter)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background { AmbientBackground(accent: accent) }
            .navigationTitle("Kalendar")
            .toolbar { toolbarContent }
            .sheet(isPresented: $showSettings) {
                SettingsView(viewModel: viewModel)
            }
            .sheet(item: $draft) { draft in
                EventEditorView(viewModel: viewModel, initialDate: draft.start, initialEndDate: draft.end)
            }
            .sheet(isPresented: $viewModel.showCalendarPicker) {
                CalendarPickerView(viewModel: viewModel)
            }
        }
        .tint(accent)
        .environment(\.accent, accent)
        .sensoryFeedback(.selection, trigger: viewModel.selectedDate)
        .task {
            await viewModel.checkExistingAccess()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            viewModel.refreshToday()
            Task { await viewModel.checkExistingAccess() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
            Task { await viewModel.checkExistingAccess() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            viewModel.refreshToday()
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                withAnimation(Theme.spring) { viewModel.goToToday() }
            } label: {
                Text("Today")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .glassPill()
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(viewModel.isShowingToday)
            .opacity(viewModel.isShowingToday ? 0.5 : 1)
            .animation(Theme.snappy, value: viewModel.isShowingToday)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            GlassIconButton(systemImage: "plus", accessibilityLabel: "New Event") {
                draft = EventDraft(start: viewModel.selectedDate, end: nil)
            }
            GlassIconButton(systemImage: "gearshape", accessibilityLabel: "Settings") {
                showSettings = true
            }
        }
    }
}

#Preview {
    ContentView()
}
