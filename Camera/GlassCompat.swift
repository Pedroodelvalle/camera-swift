//
//  GlassCompat.swift
//  Camera
//
//  Lightweight compatibility shims to approximate Liquid Glass visuals
//  on SDKs where the native APIs may not be available.
//

import SwiftUI

struct GlassCircleButtonStyle: ButtonStyle {
    var isProminent: Bool = false
    var accentColor: Color = Color.blue

    func makeBody(configuration: Configuration) -> some View {
        let baseBackground = Circle()
            .fill(Color.white.opacity(isProminent ? 0.18 : 0.10))
            .background(.ultraThinMaterial, in: Circle())

        let overlayStroke = Circle()
            .stroke(Color.white.opacity(isProminent ? 0.35 : 0.18), lineWidth: isProminent ? 1.2 : 1)

        let accent = Circle()
            .fill(isProminent ? accentColor.opacity(0.35) : Color.clear)

        return configuration.label
            .background(baseBackground)
            .background(accent)
            .overlay(overlayStroke)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GlassCapsuleBackground: ViewModifier {
    var cornerRadius: CGFloat = 10
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

extension View {
    func glassCapsuleBackground(cornerRadius: CGFloat = 10) -> some View {
        modifier(GlassCapsuleBackground(cornerRadius: cornerRadius))
    }
}


