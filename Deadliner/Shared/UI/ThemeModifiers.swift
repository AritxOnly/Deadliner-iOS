//
//  ThemeModifiers.swift
//  Deadliner
//
//  Created by Codex on 2026/3/22.
//

import SwiftUI

private struct OptionalTintModifier: ViewModifier {
    let color: Color?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let color {
            content.tint(color)
        } else {
            content
        }
    }
}

extension View {
    func optionalTint(_ color: Color?) -> some View {
        modifier(OptionalTintModifier(color: color))
    }

    @ViewBuilder
    func deadlinerScrollEdgeEffect() -> some View {
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            self
        }
    }
}
