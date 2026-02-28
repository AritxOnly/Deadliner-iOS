//
//  FloatUpRow.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/27.
//

import SwiftUI

struct FloatUpRow<Content: View>: View {
    let index: Int
    var maxLoad: Int = 15
    var enable: Bool = true
    var animateToken: Int = 0
    @ViewBuilder var content: () -> Content

    // 1. 默认设为 false，避免视图刚滑入屏幕时先闪现一下再消失
    @State private var isVisible: Bool = false

    private var delaySeconds: Double {
        guard maxLoad > 0 else { return 0 }
        return Double((index % maxLoad) * 50) / 1000.0
    }

    var body: some View {
        content()
            .opacity(enable ? (isVisible ? 1 : 0) : 1)
            .offset(y: enable ? (isVisible ? 0 : 20) : 0)
            // 2. 依然监听 token
            .task(id: animateToken) {
                guard enable else { return }
                
                // 3. 如果需要重播动画（token改变），先无动画地重置状态
                if isVisible {
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        isVisible = false
                    }
                    // 极短暂地让出主线程，确保 false 状态被 UI 渲染引擎接收
                    try? await Task.sleep(nanoseconds: 10_000_000)
                }
                
                // 4. ✨ 核心修复：把 delay 绑在 Animation 上 ✨
                // 这样不再需要漫长的 Task.sleep 阻塞主线程
                let animation = Animation.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.4)
                                         .delay(delaySeconds)
                
                withAnimation(animation) {
                    isVisible = true
                }
            }
    }
}
