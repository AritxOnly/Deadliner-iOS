//
//  SeasonIconCarouselPreview.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/28.
//


import SwiftUI

struct SeasonIconCarouselPreview: View {
    private let icons: [DeadlinerIcon] = [.spring, .summer, .autumn, .winter]

    @State private var idx: Int = 0
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            // 预加载/占位：避免切换时闪烁（可选）
            Image(icons[idx].previewAssetName)
                .resizable()
                .scaledToFill()
        }
        .onAppear {
            // 每 0.9s 切一次；你可以改成 0.6~1.2 的任意值
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    idx = (idx + 1) % icons.count
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        // 可选：减少系统动画设置时的干扰
        .accessibilityHidden(true)
    }
}