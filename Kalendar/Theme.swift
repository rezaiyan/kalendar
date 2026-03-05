//
//  Theme.swift
//  Kalendar
//
//  Modern design system for Kalendar
//

import SwiftUI

// MARK: - Glass Card Modifier

struct GlassCard: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

extension View {
    func glassCard(padding: CGFloat = 16) -> some View {
        modifier(GlassCard(padding: padding))
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
