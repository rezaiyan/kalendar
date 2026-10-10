//
//  SettingsView.swift
//  Kalendar
//
//  User preferences and app info — Liquid Glass
//

import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: CalendarViewModel
    @AppStorage(AccentPalette.storageKey) private var accentColorName = AccentPalette.blue.rawValue
    @Environment(\.dismiss) private var dismiss
    @State private var showCalendarPicker = false

    private var accent: Color { AccentPalette.color(for: accentColorName) }

    private static let sourceURL = URL(string: "https://github.com/rezaiyan/kalendar")

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(version) (\($0))" } ?? version
    }

    var body: some View {
        NavigationStack {
            Form {
                calendarSection
                appearanceSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background { AmbientBackground(accent: accent) }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showCalendarPicker) {
                CalendarPickerView(viewModel: viewModel)
            }
        }
        .tint(accent)
        .environment(\.accent, accent)
    }

    // MARK: - Sections

    private var calendarSection: some View {
        Section("Calendar") {
            Toggle(isOn: $viewModel.startsWeekOnMonday) {
                Label("Week Starts on Monday", systemImage: "calendar.day.timeline.left")
            }

            if viewModel.calendarAccessGranted {
                Button {
                    showCalendarPicker = true
                } label: {
                    HStack {
                        Label("Calendars", systemImage: "square.stack")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(selectedCalendarsSummary)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            } else {
                Button {
                    Task { await viewModel.requestCalendarAccess() }
                } label: {
                    Label("Connect Calendars", systemImage: "calendar.badge.plus")
                }
            }
        }
    }

    private var selectedCalendarsSummary: String {
        let count = viewModel.selectedCalendarIDs.count
        return count == 0 ? "All" : "\(count) of \(viewModel.availableCalendars.count)"
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            VStack(alignment: .leading, spacing: 14) {
                Label("Accent Color", systemImage: "paintpalette")

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: AccentPalette.allCases.count), spacing: 8) {
                    ForEach(AccentPalette.allCases) { palette in
                        AccentSwatch(color: palette.color, isSelected: palette.rawValue == accentColorName) {
                            withAnimation(Theme.snappy) { accentColorName = palette.rawValue }
                        }
                        .accessibilityLabel(palette.displayName)
                    }
                }
            }
            .padding(.vertical, 6)
            .sensoryFeedback(.selection, trigger: accentColorName)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            if let url = Self.sourceURL {
                Link(destination: url) {
                    HStack {
                        Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("GitHub")
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            LabeledContent {
                Text(appVersion).monospacedDigit()
            } label: {
                Label("Version", systemImage: "info.circle")
            }
        }
    }
}

// MARK: - Accent Swatch

private struct AccentSwatch: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.gradient)
                .overlay {
                    Circle().fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .topLeading, endPoint: .center))
                }
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(3)
                .overlay {
                    Circle().strokeBorder(isSelected ? color : .clear, lineWidth: 2)
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 34)
                .shadow(color: isSelected ? color.opacity(0.45) : .clear, radius: 6, x: 0, y: 3)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    SettingsView(viewModel: CalendarViewModel())
}
