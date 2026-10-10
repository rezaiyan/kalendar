//
//  Theme.swift
//  Kalendar
//
//  Liquid Glass design system for Kalendar
//

import SwiftUI

// MARK: - Design Tokens

enum Theme {
    enum Radius {
        static let card: CGFloat = 28
        static let cell: CGFloat = 14
        static let chip: CGFloat = 10
    }

    enum Spacing {
        static let cardPadding: CGFloat = 18
        static let section: CGFloat = 16
        static let gutter: CGFloat = 16
    }

    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.82)
    static let snappy = Animation.spring(response: 0.28, dampingFraction: 0.72)
}

// MARK: - Accent Palette

enum AccentPalette: String, CaseIterable, Identifiable {
    case blue, indigo, purple, pink, red, orange, green, teal

    static let storageKey = "accentColorName"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .red: .red
        case .orange: .orange
        case .green: .green
        case .teal: .teal
        }
    }

    var displayName: String { rawValue.capitalized }

    /// Resolves a stored raw value, falling back to blue for unknown values.
    static func color(for name: String) -> Color {
        (AccentPalette(rawValue: name) ?? .blue).color
    }
}

// MARK: - Glass Card

struct GlassCard: ViewModifier {
    var padding: CGFloat = Theme.Spacing.cardPadding
    var cornerRadius: CGFloat = Theme.Radius.card

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .padding(padding)
            .background {
                shape
                    .fill(.ultraThinMaterial)
                    .overlay {
                        shape.fill(
                            LinearGradient(
                                colors: [.white.opacity(0.18), .white.opacity(0.02), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                    }
                    .overlay {
                        shape.strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.45), .white.opacity(0.08), .white.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.6
                        )
                    }
            }
            .shadow(color: .black.opacity(0.07), radius: 18, x: 0, y: 10)
            .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Glass Pill

struct GlassPill: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .top, endPoint: .bottom))
                    }
                    .overlay {
                        Capsule(style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                    }
            }
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Pressable Button Style

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(Theme.snappy, value: configuration.isPressed)
    }
}

// MARK: - Glass Icon Button

struct GlassIconButton: View {
    let systemImage: String
    let accessibilityLabel: LocalizedStringKey
    var size: CGFloat = 36
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: size, height: size)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay { Circle().strokeBorder(.white.opacity(0.3), lineWidth: 0.5) }
                }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Card Header

struct CardHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.headline, design: .rounded))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
    }
}

// MARK: - Ambient Background

struct AmbientBackground: View {
    let accent: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)

            RadialGradient(
                colors: [accent.opacity(colorScheme == .dark ? 0.28 : 0.18), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 520
            )

            RadialGradient(
                colors: [accent.opacity(colorScheme == .dark ? 0.16 : 0.10), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 460
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - View Extensions

extension View {
    func glassCard(padding: CGFloat = Theme.Spacing.cardPadding, cornerRadius: CGFloat = Theme.Radius.card) -> some View {
        modifier(GlassCard(padding: padding, cornerRadius: cornerRadius))
    }

    func glassPill() -> some View {
        modifier(GlassPill())
    }
}

// MARK: - Color from Hex

extension Color {
    /// Creates a color from a `#RRGGBB` or `RRGGBB` string. Invalid input yields the system blue.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# ").union(.whitespacesAndNewlines))
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else {
            self = .blue
            return
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

// MARK: - Accent Environment

private struct AccentColorKey: EnvironmentKey {
    static let defaultValue: Color = .blue
}

extension EnvironmentValues {
    /// The user-selected accent color (the asset `AccentColor` does not follow the user's choice).
    var accent: Color {
        get { self[AccentColorKey.self] }
        set { self[AccentColorKey.self] = newValue }
    }
}

// MARK: - Event Color

extension CalendarEvent {
    /// The event's calendar color, or `fallback` when it has none (app-created events).
    func displayColor(fallback: Color) -> Color {
        calendarColorHex.map(Color.init(hex:)) ?? fallback
    }
}
