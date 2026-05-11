//
//  ExperimentalHomeNavigationTitle.swift
//  Deadliner
//
//  Created by Codex on 2026/5/11.
//

import SwiftUI

enum ExperimentalHomeNavigationTitleStyle {
    case expanded
    case collapsed
}

enum ExperimentalHomeNavigationTitleMetrics {
    static func collapseProgress(for overlayProgress: CGFloat) -> CGFloat {
        let start: CGFloat = 0.48
        let end: CGFloat = 0.8
        return min(max((overlayProgress - start) / (end - start), 0), 1)
    }
}

struct ExperimentalHomeNavigationTitleLabel: View {
    let text: String
    let style: ExperimentalHomeNavigationTitleStyle

    var body: some View {
        Text(text)
            .font(titleFont)
            .fontWidth(fontWidth)
            .tracking(tracking)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .accessibilityAddTraits(.isHeader)
    }

    private var titleFont: Font {
        switch style {
        case .expanded:
            return .system(size: 20, weight: .black, design: .rounded)
        case .collapsed:
            return .system(size: 17, weight: .semibold, design: .rounded)
        }
    }

    private var fontWidth: Font.Width {
        switch style {
        case .expanded:
            return .expanded
        case .collapsed:
            return .standard
        }
    }

    private var tracking: CGFloat {
        switch style {
        case .expanded:
            return 0.5
        case .collapsed:
            return 0
        }
    }
}
