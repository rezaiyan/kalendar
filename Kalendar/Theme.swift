//
//  Theme.swift
//  Kalendar
//
//  Liquid Glass design system for Kalendar
//

import SwiftUI

// MARK: - Liquid Glass Card Modifier

struct LiquidGlassCard: ViewModifier {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                ZStack {
                    // Base glass layer
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    // Inner highlight gradient (specular reflection)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.25),
                                    .white.opacity(0.05),
                                    .clear,
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )

                    // Subtle border glow
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.5),
                                    .white.opacity(0.1),
                                    .white.opacity(0.05),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
            }
            .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Liquid Glass Pill (for smaller interactive elements)

struct LiquidGlassPill: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.2),
                                    .clear,
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Capsule(style: .continuous)
                        .strokeBorder(
                            .white.opacity(0.3),
                            lineWidth: 0.5
                        )
                }
            }
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Floating Button Style

struct LiquidGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    func glassCard(padding: CGFloat = 16, cornerRadius: CGFloat = 24) -> some View {
        modifier(LiquidGlassCard(padding: padding, cornerRadius: cornerRadius))
    }

    func glassPill() -> some View {
        modifier(LiquidGlassPill())
    }

    func glowingAccent(_ color: Color, radius: CGFloat = 12) -> some View {
        shadow(color: color.opacity(0.3), radius: radius, x: 0, y: 4)
    }
}

// MARK: - Accent Color Helper

func accentColorFor(_ name: String) -> Color {
    switch name {
    case "purple": return .purple
    case "orange": return .orange
    case "red": return .red
    case "green": return .green
    case "pink": return .pink
    case "indigo": return .indigo
    default: return .blue
    }
}
