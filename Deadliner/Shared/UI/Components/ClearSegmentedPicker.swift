//
//  ClearSegmentedPicker.swift
//  Deadliner
//
//  Created by Codex on 2026/6/24.
//

import SwiftUI
import UIKit

private struct TabWidthPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]

    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private struct TextWidthPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]

    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

public struct ClearSegmentedPicker: View {
    public enum IndicatorStyle: Equatable {
        case contentWidth
        case segmentWidth(inset: CGFloat)
    }

    public let tabs: [String]
    public let icons: [String]?
    public let colors: [Color]?
    public let indicatorStyle: IndicatorStyle
    @Binding var currentTab: Int

    private let indicatorSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    private let indicatorBaseHeight: CGFloat = 44
    private let indicatorMorphHeight: CGFloat = 4
    private let indicatorMorphWidth: CGFloat = 8

    @State private var tabWidths: [Int: CGFloat] = [:]
    @State private var textWidths: [Int: CGFloat] = [:]
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var indicatorMorphProgress: CGFloat = 0
    @State private var symbolEffectTriggers: [Int: Int] = [:]
    @State private var visualTab: Int

    public init(
        tabs: [String],
        icons: [String]? = nil,
        colors: [Color]? = nil,
        indicatorStyle: IndicatorStyle = .contentWidth,
        currentTab: Binding<Int>
    ) {
        self.tabs = tabs
        self.icons = icons
        self.colors = colors
        self.indicatorStyle = indicatorStyle
        self._currentTab = currentTab
        self._visualTab = State(initialValue: currentTab.wrappedValue)
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            if let indicatorWidth {
                // TODO: Revisit native glass interaction if SwiftUI exposes it for custom moving indicators.
                ZStack {
                    Capsule(style: .continuous)
                        .fill(currentIndicatorColor.opacity(0.24))

                    Capsule(style: .continuous)
                        .fill(.clear)
                        .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))

                    Capsule(style: .continuous)
                        .strokeBorder(currentIndicatorColor.opacity(0.22), lineWidth: 1)
                }
                .frame(
                    width: max(indicatorWidth - currentIndicatorWidthCompression, 0),
                    height: indicatorBaseHeight + currentIndicatorHeightExpansion
                )
                .offset(x: calculateIndicatorOffset() + (currentIndicatorWidthCompression / 2))
                .animation(isDragging ? nil : indicatorSpring, value: visualTab)
                .animation(isDragging ? nil : indicatorSpring, value: dragOffset)
                .animation(isDragging ? nil : indicatorSpring, value: indicatorMorphProgress)
                .zIndex(0)
            }

            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    segmentLabel(index: index, title: tab, selected: visualTab == index)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                        .background(
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: TabWidthPreferenceKey.self,
                                    value: [index: geometry.size.width]
                                )
                            }
                        )
                        .onTapGesture {
                            if selectTab(index) {
                                UISelectionFeedbackGenerator().selectionChanged()
                            }
                        }
                }
            }
            .zIndex(1)

            if let indicatorWidth {
                Rectangle()
                    .fill(.clear)
                    .frame(
                        width: max(indicatorWidth - currentIndicatorWidthCompression, 0),
                        height: indicatorBaseHeight + currentIndicatorHeightExpansion
                    )
                    .contentShape(Rectangle())
                    .offset(x: calculateIndicatorOffset() + (currentIndicatorWidthCompression / 2))
                    .animation(isDragging ? nil : indicatorSpring, value: visualTab)
                    .animation(isDragging ? nil : indicatorSpring, value: dragOffset)
                    .animation(isDragging ? nil : indicatorSpring, value: indicatorMorphProgress)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                isDragging = true
                                indicatorMorphProgress = 0
                                dragOffset = clampedDragOffset(for: gesture.translation.width)
                            }
                            .onEnded { _ in
                                if endDrag() {
                                    UISelectionFeedbackGenerator().selectionChanged()
                                }
                            }
                    )
                    .zIndex(2)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .onPreferenceChange(TabWidthPreferenceKey.self) { tabWidths = $0 }
        .onPreferenceChange(TextWidthPreferenceKey.self) { textWidths = $0 }
        .onChange(of: currentTab) { _, newValue in
            guard !isDragging, visualTab != newValue else { return }
            visualTab = newValue
        }
    }

    private var indicatorWidth: CGFloat? {
        indicatorWidth(for: visualTab)
    }

    private var currentIndicatorColor: Color {
        guard let colors, !colors.isEmpty else { return .white }
        return blendedTabColor(weights: tabs.indices.map { tabActivation(for: $0) }, fallbackIndex: visualTab)
    }

    private var currentIndicatorWidthCompression: CGFloat {
        indicatorMorphWidth * indicatorMorphProgress
    }

    private var currentIndicatorHeightExpansion: CGFloat {
        indicatorMorphHeight * indicatorMorphProgress
    }

    private func indicatorWidth(for index: Int) -> CGFloat? {
        switch indicatorStyle {
        case .contentWidth:
            return textWidths[index]
        case let .segmentWidth(inset):
            guard let tabWidth = tabWidths[index] else { return nil }
            return max(tabWidth - (inset * 2), 0)
        }
    }

    private func baseIndicatorOffset() -> CGFloat {
        baseIndicatorOffset(for: visualTab)
    }

    private func baseIndicatorOffset(for index: Int) -> CGFloat {
        guard !tabWidths.isEmpty else { return 0 }
        let previousWidth = (0..<index).reduce(CGFloat.zero) { partialResult, previousIndex in
            partialResult + (tabWidths[previousIndex] ?? 0)
        }
        let currentWidth = tabWidths[index] ?? 0

        switch indicatorStyle {
        case .contentWidth:
            let selectedTextWidth = textWidths[index] ?? 0
            return previousWidth + (currentWidth - selectedTextWidth) / 2
        case let .segmentWidth(inset):
            return previousWidth + inset
        }
    }

    private func calculateIndicatorOffset() -> CGFloat {
        baseIndicatorOffset() + dragOffset
    }

    private func indicatorCenterX() -> CGFloat {
        calculateIndicatorOffset() + (indicatorWidth ?? 0) / 2
    }

    private func tabCenterX(for index: Int) -> CGFloat {
        baseIndicatorOffset(for: index) + (indicatorWidth(for: index) ?? 0) / 2
    }

    private func nearestNeighborDistance(for index: Int) -> CGFloat {
        let center = tabCenterX(for: index)
        let leftDistance = index > 0 ? abs(center - tabCenterX(for: index - 1)) : nil
        let rightDistance = index < tabs.count - 1 ? abs(tabCenterX(for: index + 1) - center) : nil
        return min(leftDistance ?? .greatestFiniteMagnitude, rightDistance ?? .greatestFiniteMagnitude)
    }

    private func tabActivation(for index: Int) -> CGFloat {
        guard tabs.indices.contains(index) else { return 0 }
        guard tabs.count > 1 else { return index == visualTab ? 1 : 0 }

        let distance = abs(indicatorCenterX() - tabCenterX(for: index))
        let influenceRange = max(nearestNeighborDistance(for: index), 1)
        return max(0, min(1, 1 - (distance / influenceRange)))
    }

    private func segmentLabel(index: Int, title: String, selected: Bool) -> some View {
        HStack(spacing: 6) {
            if let icons, index < icons.count {
                segmentIcon(name: icons[index], index: index)
            }

            Text(title)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 10)
        .foregroundStyle(labelForegroundColor(for: index, selected: selected))
        .background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: TextWidthPreferenceKey.self,
                    value: [index: geometry.size.width]
                )
            }
        )
    }

    private func labelForegroundColor(for index: Int, selected: Bool) -> Color {
        guard let colors, colors.indices.contains(index) else {
            return selected ? .primary : .secondary
        }

        let activeUIColor = UIColor(colors[index])
        let inactiveUIColor = UIColor.secondaryLabel
        return Color(
            uiColor: interpolateColor(
                from: inactiveUIColor,
                to: activeUIColor,
                progress: tabActivation(for: index)
            )
        )
    }

    @ViewBuilder
    private func segmentIcon(name: String, index: Int) -> some View {
        Image(systemName: name)
            .font(.subheadline.weight(.medium))
            .symbolEffect(.bounce, options: .nonRepeating, value: symbolEffectTriggers[index, default: 0])
    }

    private func clampedDragOffset(for proposedOffset: CGFloat) -> CGFloat {
        guard let indicatorWidth else { return 0 }
        let totalWidth = tabWidths.values.reduce(CGFloat.zero, +)
        let baseOffset = baseIndicatorOffset()
        let minOffset = -baseOffset
        let maxOffset = totalWidth - indicatorWidth - baseOffset
        return min(max(proposedOffset, minOffset), maxOffset)
    }

    private func nearestTabIndex(for proposedOffset: CGFloat) -> Int {
        let targetMidX = proposedOffset + (indicatorWidth(for: visualTab) ?? 0) / 2

        var bestIndex = visualTab
        var bestDistance = CGFloat.greatestFiniteMagnitude

        for index in tabs.indices {
            let midX = baseIndicatorOffset(for: index) + (indicatorWidth(for: index) ?? 0) / 2
            let distance = abs(midX - targetMidX)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }

        return bestIndex
    }

    private func selectTab(_ index: Int) -> Bool {
        guard visualTab != index else { return false }
        indicatorMorphProgress = 1
        let didChange = updateSelection(to: index)
        withAnimation(indicatorSpring) {
            indicatorMorphProgress = 0
        }
        return didChange
    }

    private func endDrag() -> Bool {
        let absoluteOffset = baseIndicatorOffset() + dragOffset
        let targetIndex = nearestTabIndex(for: absoluteOffset)
        let didChange = updateSelection(to: targetIndex)
        let targetBaseOffset = baseIndicatorOffset(for: targetIndex)

        dragOffset = absoluteOffset - targetBaseOffset
        isDragging = false
        indicatorMorphProgress = 1

        withAnimation(indicatorSpring) {
            dragOffset = 0
            indicatorMorphProgress = 0
        }
        return didChange
    }

    @discardableResult
    private func updateSelection(to index: Int) -> Bool {
        guard visualTab != index else { return false }
        visualTab = index
        symbolEffectTriggers[index, default: 0] += 1
        if currentTab != index {
            DispatchQueue.main.async {
                if currentTab != index {
                    withAnimation(.smooth(duration: 0.24, extraBounce: 0)) {
                        currentTab = index
                    }
                }
            }
        }
        return true
    }

    private func blendedTabColor(weights: [CGFloat], fallbackIndex: Int) -> Color {
        guard let colors, !colors.isEmpty else { return .white }

        let uiColors = colors.map(UIColor.init)
        let weightedColors = zip(uiColors, weights).filter { $0.1 > 0.001 }
        guard !weightedColors.isEmpty else {
            return Color(uiColor: uiColors[min(max(fallbackIndex, 0), uiColors.count - 1)])
        }

        let totalWeight = weightedColors.reduce(CGFloat.zero) { $0 + $1.1 }
        let normalized = weightedColors.map { ($0.0, $0.1 / max(totalWeight, 0.001)) }

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        for (uiColor, weight) in normalized {
            let components = uiColor.rgbaComponents
            red += components.red * weight
            green += components.green * weight
            blue += components.blue * weight
            alpha += components.alpha * weight
        }

        return Color(
            uiColor: UIColor(
                red: red,
                green: green,
                blue: blue,
                alpha: alpha
            )
        )
    }

    private func interpolateColor(from: UIColor, to: UIColor, progress: CGFloat) -> UIColor {
        let t = min(max(progress, 0), 1)
        let fromComponents = from.rgbaComponents
        let toComponents = to.rgbaComponents

        return UIColor(
            red: fromComponents.red + (toComponents.red - fromComponents.red) * t,
            green: fromComponents.green + (toComponents.green - fromComponents.green) * t,
            blue: fromComponents.blue + (toComponents.blue - fromComponents.blue) * t,
            alpha: fromComponents.alpha + (toComponents.alpha - fromComponents.alpha) * t
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension UIColor {
    var rgbaComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return (red, green, blue, alpha)
        }

        var white: CGFloat = 0
        if getWhite(&white, alpha: &alpha) {
            return (white, white, white, alpha)
        }

        return (0, 0, 0, 1)
    }
}
