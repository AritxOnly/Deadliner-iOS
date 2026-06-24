//
//  ThemeModifiers.swift
//  Deadliner
//
//  Created by Codex on 2026/3/22.
//

import SwiftUI

enum ScrollEdgeEffectPreference {
    static let useSystemImmersiveKey = "settings.display.use_system_immersive"
    static let defaultUseSystemImmersive = false
}

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
    func deadlinerScrollEdgeEffect(forceImmersive: Bool = true) -> some View {
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *) {
            modifier(DeadlinerScrollEdgeEffectModifier(forceImmersive: forceImmersive))
        } else {
            self
        }
    }
}

private struct DeadlinerScrollEdgeEffectModifier: ViewModifier {
    let forceImmersive: Bool

    @AppStorage(ScrollEdgeEffectPreference.useSystemImmersiveKey)
    private var useSystemImmersive: Bool = ScrollEdgeEffectPreference.defaultUseSystemImmersive

    @ViewBuilder
    func body(content: Content) -> some View {
        if forceImmersive || !useSystemImmersive {
            content.scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            content.scrollEdgeEffectStyle(.automatic, for: .all)
        }
    }
}
