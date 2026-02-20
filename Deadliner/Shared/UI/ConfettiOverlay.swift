//
//  ConfettiOverlay.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/18.
//

import SwiftUI
import Combine

// MARK: - 1. 控制器
@MainActor
final class ConfettiController: ObservableObject {
    @Published fileprivate var triggerTick: Int = 0
    
    /// 触发喷发
    func fire() {
        triggerTick += 1
    }
}

// MARK: - 2. 粒子模型 (物理逻辑)
struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    let color: Color
    
    // 旋转与 3D 效果参数
    var rotation: Angle = .degrees(Double.random(in: 0...360))
    var tilt: Double = Double.random(in: 0...Double.pi * 2)
    var wobble: Double = Double.random(in: 0...Double.pi * 2)
    var opacity: Double = 1.0
    
    static let gravity = 0.5  // 重力
    static let drag = 0.96    // 空气阻力
    
    mutating func update() {
        // 阻尼系数微调，让它在空中停留更久
        vx *= 0.97
        vy *= 0.97
        
        // 减小重力数值，让“放得更高”
        vy += 0.45
        
        x += vx
        y += vy
        
        rotation += .degrees(vx * 2)
        tilt += 0.1
        wobble += 0.1
        opacity -= 0.006 // 消失速度变慢一点
    }
}

// MARK: - 3. 视图组件
struct ConfettiOverlay: View {
    @ObservedObject var controller: ConfettiController
    @State private var particles: [ConfettiParticle] = []
    
    // 使用稳定的 Timer 驱动物理引擎
    let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            SwiftUI.Canvas { context, size in
                for p in particles {
                    context.drawLayer { ctx in
                        let wobbleX = sin(p.wobble) * 10
                        ctx.translateBy(x: p.x + wobbleX, y: p.y)
                        ctx.rotate(by: p.rotation)
                        ctx.scaleBy(x: 1, y: cos(p.tilt))
                        ctx.opacity = p.opacity
                        ctx.fill(Path(CGRect(x: -5, y: -5, width: 10, height: 10)), with: .color(p.color))
                    }
                }
            }
            .onReceive(controller.$triggerTick) { tick in
                // 关键点：只有 tick 大于初始值 0 才会触发
                if tick > 0 {
                    spawnParticles(in: geometry.size)
                }
            }
            .onReceive(timer) { _ in
                updateParticles(viewSize: geometry.size)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private func spawnParticles(in size: CGSize) {
        for _ in 0..<120 {
            let angle = Double.random(in: 240...300) * (.pi / 180)
            // 增加力度范围：30...50 之间通常能冲到屏幕中上方
            let velocity = Double.random(in: 30...55)
            
            let p = ConfettiParticle(
                x: size.width / 2,
                y: size.height + 10, // 从屏幕底部外侧开始
                vx: cos(angle) * velocity,
                vy: sin(angle) * velocity,
                color: [.blue, .purple, .pink, .green, .yellow, .orange, .red].randomElement()!
            )
            particles.append(p)
        }
    }

    private func updateParticles(viewSize: CGSize) {
        if particles.isEmpty { return }
        
        for i in particles.indices.reversed() {
            particles[i].update()
            
            // 性能优化：如果粒子已经完全透明或掉出屏幕下方太远，则移除
            if particles[i].opacity <= 0 || particles[i].y > viewSize.height + 100 {
                particles.remove(at: i)
            }
        }
    }
}
