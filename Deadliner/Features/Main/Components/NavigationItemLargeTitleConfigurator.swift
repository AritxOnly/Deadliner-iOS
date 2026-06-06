//
//  NavigationItemLargeTitleConfigurator.swift
//  Deadliner
//
//  Created by Codex on 2026/5/13.
//

import SwiftUI
import UIKit

struct NavigationItemLargeTitleConfigurator: UIViewControllerRepresentable {
    let largeTitle: String?

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.updateLargeTitle(largeTitle)
    }

    final class Controller: UIViewController {
        private var pendingLargeTitle: String?

        override func loadView() {
            let view = UIView(frame: .zero)
            view.isHidden = true
            view.isUserInteractionEnabled = false
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

        func updateLargeTitle(_ largeTitle: String?) {
            pendingLargeTitle = largeTitle
            applyIfPossible()
        }

        private func applyIfPossible() {
            guard let parent else { return }
            guard #available(iOS 26.0, *) else { return }
            if parent.navigationItem.largeTitle != pendingLargeTitle {
                parent.navigationItem.largeTitle = pendingLargeTitle
            }
        }
    }
}

extension View {
    @ViewBuilder
    func navigationLargeTitleOverride(_ largeTitle: String?) -> some View {
        background {
            NavigationItemLargeTitleConfigurator(largeTitle: largeTitle)
        }
    }
}
