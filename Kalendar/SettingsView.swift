//
//  SettingsView.swift
//  Kalendar
//
//  User preferences and app info — Liquid Glass
//

import SwiftUI
import WidgetKit

struct SettingsView: View {
    var viewModel: CalendarViewModel?
    @AppStorage("startOfWeekMonday", store: UserDefaults(suiteName: CalendarViewModel.appGroupID))
    private var startMonday = true
    @AppStorage("accentColorName") private var accentColorName = "blue"
    @Environment(\.dismiss) private var dismiss
    @State private var showCalendarPicker = false

    private let accentColors = ["blue", "purple", "indigo", "orange", "red", "green", "pink"]

    private var accent: Color { accentColorFor(accentColorName) }

    var body: some View {
        NavigationStack {
            ZStack {
                // Ambient background
                LinearGradient(
                    colors: [
                        accent.opacity(0.06),
                        Color(.systemGroupedBackground),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                Form {
                    Section("Calendar") {
                        Toggle("Week starts on Monday", isOn: $startMonday)
                            .tint(accent)
                        if let vm = viewModel, vm.calendarAccessGranted {
                            Button {
                                showCalendarPicker = true
                            } label: {
                                HStack {
                                    Text("Calendars")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(vm.selectedCalendarIDs.isEmpty ? "All" : "\(vm.selectedCalendarIDs.count)")")
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 3)
                                        .background(.ultraThinMaterial, in: Capsule())
                                    Image(systemName: "chevron.right")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }

                    Section("Appearance") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Accent Color")
                            HStack(spacing: 10) {
                                ForEach(accentColors, id: \.self) { name in
                                    let color = accentColorFor(name)
                                    let isActive = accentColorName == name

                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [color.opacity(0.9), color],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 28, height: 28)
                                            .overlay(
                                                Circle()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [.white.opacity(0.4), .clear],
                                                            startPoint: .topLeading,
                                                            endPoint: .center
                                                        )
                                                    )
                                            )

                                        if isActive {
                                            Circle()
                                                .strokeBorder(.white, lineWidth: 2.5)
                                                .frame(width: 28, height: 28)

                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .shadow(color: isActive ? color.opacity(0.5) : .clear, radius: 6, x: 0, y: 3)
                                    .scaleEffect(isActive ? 1.15 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: accentColorName)
                                    .onTapGesture {
                                        accentColorName = name
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Section("About") {
                        Link(destination: URL(string: "https://github.com/rezaiyan/kalendar")!) {
                            HStack {
                                Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                                Spacer()
                                Text("GitHub")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Image(systemName: "arrow.up.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .foregroundStyle(.primary)

                        HStack {
                            Text("Version")
                            Spacer()
                            Text("2.1.0")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Built with")
                            Spacer()
                            Text("SwiftUI")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: .rounded).weight(.semibold))
                }
            }
        }
        .tint(accent)
        .onChange(of: startMonday) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        .sheet(isPresented: $showCalendarPicker) {
            if let vm = viewModel {
                CalendarPickerView(viewModel: vm)
            }
        }
    }
}

#Preview {
    SettingsView()
}
