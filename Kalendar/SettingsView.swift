//
//  SettingsView.swift
//  Kalendar
//
//  User preferences and app info
//

import SwiftUI

struct SettingsView: View {
@AppStorage("startOfWeekMonday") private var startMonday = true
    @AppStorage("accentColorName") private var accentColorName = "blue"
    @Environment(\.dismiss) private var dismiss

    private let accentColors = ["blue", "purple", "indigo", "orange", "red", "green", "pink"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Calendar") {
                    Toggle("Week starts on Monday", isOn: $startMonday)
                }

Section("Appearance") {
                    HStack {
                        Text("Accent Color")
                        Spacer()
                        HStack(spacing: 8) {
                            ForEach(accentColors, id: \.self) { name in
                                Circle()
                                    .fill(accentColorFor(name))
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary.opacity(accentColorName == name ? 0.8 : 0), lineWidth: 2)
                                            .padding(1)
                                    )
                                    .scaleEffect(accentColorName == name ? 1.15 : 1.0)
                                    .animation(.easeInOut(duration: 0.2), value: accentColorName)
                                    .onTapGesture {
                                        accentColorName = name
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                            }
                        }
                    }
                }

                Section("About") {
                    Link(destination: URL(string: "https://github.com/rezaiyan/kalendar")!) {
                        HStack {
                            Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                            Spacer()
                            Text("GitHub")
                                .foregroundStyle(.secondary)
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)

                    HStack {
                        Text("Version")
                        Spacer()
                        Text("2.0.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Built with")
                        Spacer()
                        Text("SwiftUI")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(accentColorFor(accentColorName))
    }
}

#Preview {
    SettingsView()
}
