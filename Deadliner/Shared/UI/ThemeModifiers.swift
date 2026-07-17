//
//  ThemeModifiers.swift
//  Deadliner
//
//  Created by Codex on 2026/3/22.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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

private struct DeadlinerTopAtmosphereSceneBackgroundModifier: ViewModifier {
    let progress: CGFloat
    let isAIConfigured: Bool
    let semanticTone: ImmersiveSurfaceTone
    let semanticAccentColor: Color?
    let overlayOpacity: CGFloat

    func body(content: Content) -> some View {
        content
            .background(alignment: .top) {
                ZStack(alignment: .top) {
                    Color(uiColor: .systemGroupedBackground)
                        .ignoresSafeArea()

                    DeadlinerTopAtmosphereBackdrop(
                        progress: progress,
                        isAIConfigured: isAIConfigured,
                        semanticTone: semanticTone,
                        semanticAccentColor: semanticAccentColor
                    )
                    .opacity(overlayOpacity)
                }
            }
    }
}

extension View {
    func optionalTint(_ color: Color?) -> some View {
        modifier(OptionalTintModifier(color: color))
    }

    func deadlinerTopAtmosphereSceneBackground(
        progress: CGFloat,
        isAIConfigured: Bool,
        semanticTone: ImmersiveSurfaceTone,
        semanticAccentColor: Color? = nil,
        overlayOpacity: CGFloat = 1
    ) -> some View {
        modifier(
            DeadlinerTopAtmosphereSceneBackgroundModifier(
                progress: progress,
                isAIConfigured: isAIConfigured,
                semanticTone: semanticTone,
                semanticAccentColor: semanticAccentColor,
                overlayOpacity: overlayOpacity
            )
        )
    }

    @ViewBuilder
    func deadlinerNavigationBarMinimizeOnScrollDown() -> some View {
        if #available(iOS 27.0, *) {
            modifier(DeadlinerNavigationBarMinimizeOnScrollDownModifier())
        } else {
            self
        }
    }

    @ViewBuilder
    func deadlinerScrollEdgeEffect(forceImmersive: Bool = false) -> some View {
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *) {
            modifier(DeadlinerScrollEdgeEffectModifier(forceImmersive: forceImmersive))
        } else {
            self
        }
    }

    @ViewBuilder
    func deadlinerContainerSystemBackground() -> some View {
        #if canImport(UIKit) && !os(watchOS)
        background {
            DeadlinerContainerBackgroundConfigurator(backgroundColor: .systemGroupedBackground)
        }
        #else
        self
        #endif
    }
}

private struct DeadlinerNavigationBarMinimizeOnScrollDownModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27.0, *) {
            content.toolbarMinimizationBehavior(.onScrollDown, for: .statusBar)
        } else {
            content
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

#if canImport(UIKit) && !os(watchOS)
private struct DeadlinerContainerBackgroundConfigurator: UIViewControllerRepresentable {
    let backgroundColor: UIColor

    func makeUIViewController(context: Context) -> Controller {
        Controller(backgroundColor: backgroundColor)
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.updateBackgroundColor(backgroundColor)
    }

    final class Controller: UIViewController {
        private var resolvedBackgroundColor: UIColor

        init(backgroundColor: UIColor) {
            resolvedBackgroundColor = backgroundColor
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func loadView() {
            let view = UIView(frame: .zero)
            view.isHidden = true
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
            self.view = view
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            applyIfPossible()
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            applyIfPossible()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            applyIfPossible()
        }

        func updateBackgroundColor(_ backgroundColor: UIColor) {
            resolvedBackgroundColor = backgroundColor
            applyIfPossible()
        }

        private func applyIfPossible() {
            guard let window = view.window else { return }
            if window.backgroundColor != resolvedBackgroundColor {
                window.backgroundColor = resolvedBackgroundColor
            }
            applyRecursively(to: window.rootViewController)
        }

        private func applyRecursively(to viewController: UIViewController?) {
            guard let viewController else { return }

            if viewController.view.backgroundColor != resolvedBackgroundColor {
                viewController.view.backgroundColor = resolvedBackgroundColor
            }

            for child in viewController.children {
                applyRecursively(to: child)
            }

            applyRecursively(to: viewController.presentedViewController)
        }
    }
}
#endif
