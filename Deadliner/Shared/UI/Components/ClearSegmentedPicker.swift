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
    @Environment(\.colorScheme) private var colorScheme

    private let indicatorSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    private let indicatorReleaseSpring = Animation.spring(response: 0.4, dampingFraction: 0.68, blendDuration: 0.12)
    private let pickerInsets: CGFloat = 6
    private let segmentHorizontalPadding: CGFloat = 10
    private let segmentVerticalPadding: CGFloat = 12
    private let segmentLabelFont: Font = .system(.body, design: .rounded).weight(.semibold)
    private let segmentIconFont: Font = .system(.body, design: .rounded).weight(.semibold)
    private let indicatorBaseHeight: CGFloat = 44
    private let indicatorPressHeight: CGFloat = 6
    private let indicatorTapMorphProgress: CGFloat = 0.22
    private let indicatorTapPressDuration: TimeInterval = 0.16
    private let indicatorMorphHeight: CGFloat = 4
    private let indicatorMorphWidth: CGFloat = 8

    @State private var tabWidths: [Int: CGFloat] = [:]
    @State private var textWidths: [Int: CGFloat] = [:]
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var indicatorMorphProgress: CGFloat = 0
    @State private var visualTab: Int
    @State private var isProgrammaticIndicatorPressed = false
    @State private var indicatorProgrammaticPressReleaseWorkItem: DispatchWorkItem?
    @GestureState private var isIndicatorPressed = false

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
                ZStack {
                    Capsule(style: .continuous)
                        .fill(.clear)
                        .glassEffect(currentIndicatorGlass, in: Capsule(style: .continuous))
                }
                .frame(
                    width: max(indicatorWidth - currentIndicatorWidthCompression, 0),
                    height: indicatorBaseHeight + currentIndicatorHeightExpansion
                )
                .offset(x: currentIndicatorOffset())
                .scaleEffect(isIndicatorPressedLikeState ? 1.015 : 1, anchor: .center)
                .animation(isDragging ? nil : indicatorSpring, value: visualTab)
                .animation(isDragging ? nil : indicatorSpring, value: dragOffset)
                .animation(isDragging ? nil : indicatorSpring, value: indicatorMorphProgress)
                .animation(indicatorSpring, value: isIndicatorPressedLikeState)
                .zIndex(0)
            }

            labelsRow(isOverlay: false)
                .zIndex(1)

            if let indicatorWidth {
                labelsRow(isOverlay: true)
                    .mask(alignment: .leading) {
                        indicatorMask(width: indicatorWidth)
                    }
                    .animation(isDragging ? nil : indicatorSpring, value: visualTab)
                    .animation(isDragging ? nil : indicatorSpring, value: dragOffset)
                    .animation(isDragging ? nil : indicatorSpring, value: indicatorMorphProgress)
                    .animation(indicatorSpring, value: isIndicatorPressedLikeState)
                    .allowsHitTesting(false)
                    .zIndex(2)
            }

            if let indicatorWidth {
                Rectangle()
                    .fill(.clear)
                    .frame(
                        width: max(indicatorWidth - currentIndicatorWidthCompression, 0),
                        height: indicatorBaseHeight + currentIndicatorHeightExpansion
                    )
                    .contentShape(Rectangle())
                    .offset(x: currentIndicatorOffset())
                    .animation(isDragging ? nil : indicatorSpring, value: visualTab)
                    .animation(isDragging ? nil : indicatorSpring, value: dragOffset)
                    .animation(isDragging ? nil : indicatorSpring, value: indicatorMorphProgress)
                    .gesture(indicatorDragGesture)
                    .zIndex(3)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: pickerContentHeight)
        .padding(pickerInsets)
        .onPreferenceChange(TabWidthPreferenceKey.self) { tabWidths = $0 }
        .onPreferenceChange(TextWidthPreferenceKey.self) { textWidths = $0 }
        .onChange(of: currentTab) { _, newValue in
            guard !isDragging, visualTab != newValue else { return }
            visualTab = newValue
        }
    }

    private var indicatorDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isIndicatorPressed) { _, state, _ in
                state = true
            }
            .onChanged { gesture in
                isDragging = true
                indicatorMorphProgress = min(abs(gesture.translation.width) / max(indicatorWidth ?? 1, 1), 0.35)
                dragOffset = clampedDragOffset(for: gesture.translation.width)
            }
            .onEnded { _ in
                if endDrag() {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
    }

    private func labelsRow(isOverlay: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                segmentLabel(index: index, title: tab, selected: visualTab == index, isOverlay: isOverlay)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: TabWidthPreferenceKey.self,
                                value: isOverlay ? [:] : [index: geometry.size.width]
                            )
                        }
                    )
                    .onTapGesture {
                        guard !isOverlay else { return }
                        if selectTab(index) {
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                    }
            }
        }
    }

    private func indicatorMask(width: CGFloat) -> some View {
        Capsule(style: .continuous)
            .frame(
                width: max(width - currentIndicatorWidthCompression, 0),
                height: indicatorBaseHeight + currentIndicatorHeightExpansion
            )
            .offset(x: currentIndicatorOffset())
            .scaleEffect(isIndicatorPressedLikeState ? 1.015 : 1, anchor: .center)
    }

    private var isIndicatorInteracting: Bool {
        isDragging || isIndicatorPressed || isProgrammaticIndicatorPressed
    }

    private var pickerContentHeight: CGFloat {
        indicatorBaseHeight + indicatorPressHeight + indicatorMorphHeight
    }

    private var currentIndicatorGlass: Glass {
        .regular
            .tint(currentIndicatorColor.opacity(isIndicatorInteracting ? 0.2 : 0.12))
            .interactive(isIndicatorInteracting)
    }

    private func currentIndicatorOffset() -> CGFloat {
        calculateIndicatorOffset() + (currentIndicatorWidthCompression / 2)
    }

    private var indicatorPressWidthCompression: CGFloat {
        isIndicatorPressedLikeState ? 4 : 0
    }

    private var indicatorPressHeightExpansion: CGFloat {
        isIndicatorPressedLikeState ? indicatorPressHeight : 0
    }

    private var indicatorStretchWidthCompression: CGFloat {
        indicatorMorphWidth * indicatorMorphProgress
    }

    private var indicatorStretchHeightExpansion: CGFloat {
        indicatorMorphHeight * indicatorMorphProgress
    }

    private var currentIndicatorWidthCompression: CGFloat {
        indicatorPressWidthCompression + indicatorStretchWidthCompression
    }

    private var currentIndicatorHeightExpansion: CGFloat {
        indicatorPressHeightExpansion + indicatorStretchHeightExpansion
    }

    private var indicatorWidth: CGFloat? {
        indicatorWidth(for: visualTab)
    }

    private var currentIndicatorColor: Color {
        guard let colors, !colors.isEmpty else { return .white }
        return blendedTabColor(weights: tabs.indices.map { tabActivation(for: $0) }, fallbackIndex: visualTab)
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

    private func segmentLabel(index: Int, title: String, selected: Bool, isOverlay: Bool) -> some View {
        HStack(spacing: 6) {
            if let icons, index < icons.count {
                segmentIcon(name: icons[index])
            }

            Text(title)
                .font(segmentLabelFont)
        }
        .padding(.horizontal, segmentHorizontalPadding)
        .padding(.vertical, segmentVerticalPadding)
        .foregroundStyle(labelForegroundColor(for: index, selected: selected, isOverlay: isOverlay))
        .background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: TextWidthPreferenceKey.self,
                    value: isOverlay ? [:] : [index: geometry.size.width]
                )
            }
        )
    }

    private func labelForegroundColor(for index: Int, selected: Bool, isOverlay: Bool) -> Color {
        if isOverlay {
            return overlayLabelColor(for: index, selected: selected)
        }

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

    private func overlayLabelColor(for index: Int, selected: Bool) -> Color {
        guard let colors, colors.indices.contains(index) else {
            return selected ? .primary : .secondary
        }

        let activeUIColor = UIColor(colors[index])
        let liftedActive = interpolateColor(
            from: activeUIColor,
            to: colorScheme == .dark ? .white : .black,
            progress: 0.32
        )
        let inactiveUIColor = UIColor.secondaryLabel.withAlphaComponent(0.74)

        return Color(
            uiColor: interpolateColor(
                from: inactiveUIColor,
                to: liftedActive,
                progress: tabActivation(for: index)
            )
        )
    }

    @ViewBuilder
    private func segmentIcon(name: String) -> some View {
        Image(systemName: name)
            .font(segmentIconFont)
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
        triggerProgrammaticIndicatorPress()
        return updateSelection(to: index)
    }

    private func endDrag() -> Bool {
        let absoluteOffset = baseIndicatorOffset() + dragOffset
        let targetIndex = nearestTabIndex(for: absoluteOffset)
        let didChange = updateSelection(to: targetIndex)
        let targetBaseOffset = baseIndicatorOffset(for: targetIndex)

        dragOffset = absoluteOffset - targetBaseOffset
        isDragging = false
        indicatorMorphProgress = 1

        withAnimation(indicatorReleaseSpring) {
            dragOffset = 0
            indicatorMorphProgress = 0
        }
        return didChange
    }

    private var isIndicatorPressedLikeState: Bool {
        isIndicatorPressed || isProgrammaticIndicatorPressed
    }

    private func triggerProgrammaticIndicatorPress() {
        isProgrammaticIndicatorPressed = true
        indicatorMorphProgress = max(indicatorMorphProgress, indicatorTapMorphProgress)
        indicatorProgrammaticPressReleaseWorkItem?.cancel()

        let releaseWorkItem = DispatchWorkItem {
            withAnimation(indicatorSpring) {
                isProgrammaticIndicatorPressed = false
                indicatorMorphProgress = 0
            }
        }
        indicatorProgrammaticPressReleaseWorkItem = releaseWorkItem

        DispatchQueue.main.asyncAfter(deadline: .now() + indicatorTapPressDuration, execute: releaseWorkItem)
    }

    @discardableResult
    private func updateSelection(to index: Int) -> Bool {
        guard visualTab != index else { return false }
        visualTab = index
        if currentTab != index {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                currentTab = index
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
