//
//  SettingsView.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import SwiftUI

struct SettingsView: View {
    // 使用统一的枚举状态管理
    @AppStorage("userTier") private var userTier: UserTier = .free
    @State private var showProPaywall = false

    var body: some View {
        List {
            // MARK: - 1. 用户信息模块
            VStack(spacing: 4) {
                Button {
                    toggleUserTierForTesting()
                } label: {
                    Image("avatar")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 84, height: 84)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                
                Text("Aritx Zhou") // 占位昵称
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.top, 4)
                
                // 动态徽章展示
                Text(userTier.displayName)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(userTier == .free ? .secondary : .white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Group {
                            switch userTier {
                            case .free:
                                Color.gray.opacity(0.15)
                            case .geek:
                                LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                            case .pro:
                                LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                            }
                        }
                    )
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            
            // MARK: - 2. Deadliner+ 引导横幅
            if userTier != .pro {
                PlusUpsellSection(showPaywall: $showProPaywall)
            }

            // MARK: - 3. 通用与基础设置
            Section("通用") {
                NavigationLink(destination: BehaviorAndDisplayView()) {
                    Label("行为、交互与显示", systemImage: "hand.tap")
                }
                
                // 云同步：如果是 Pro 用户，里面会多出一个 iCloud 选项
                NavigationLink(destination: AccountAndSyncView()) {
                    HStack {
                        Label("账号与云同步", systemImage: "cloud")
                    }
                }
            }

            // MARK: - 4. 效率引擎
            Section("效率引擎") {
                // AI 助手：这是 Deadliner+ 的核心卖点。Free 用户看到 Plus，Geek 用户看到 Pro（吸引他们升级免配置）
                NavigationLink(destination: AISettingsView()) {
                    HStack {
                        Label("Deadliner AI", systemImage: "sparkles")
                        Spacer()
                        if userTier == .free {
                            PlusBadge()
                        } else if userTier == .geek {
                            ProBadge()
                        }
                    }
                }
                
                // 科学记忆：Geek 买断版和 Pro 都能用。所以只对 Free 用户展示 PlusBadge
                NavigationLink(destination: EfficiencySettingsView()) {
                    HStack {
                        Label("科学记忆与复习", systemImage: "chart.line.uptrend.xyaxis")
                        Spacer()
                        if userTier == .free { PlusBadge() }
                    }
                }
            }

            // MARK: - 5. 外观与个性化
            // 个性化：只要是 Deadliner+ 计划（Geek 或 Pro）都能解锁
            Section("个性化") {
                NavigationLink(destination: Text("主题设置开发中...")) {
                    HStack {
                        Label("App 主题", systemImage: "paintbrush")
                        Spacer()
                        if userTier == .free { PlusBadge() }
                    }
                }
                NavigationLink(destination: IconSettingsView()) {
                    HStack {
                        Label("自定义图标", systemImage: "app.dashed")
                        Spacer()
                        if userTier == .free { PlusBadge() }
                    }
                }
            }

            // MARK: - 6. 其他
            Section("关于") {
                Label("版本信息", systemImage: "info.circle")
                Label("开源与隐私协议", systemImage: "hand.raised")
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showProPaywall) {
            ProPaywallView()
                .presentationDetents([.large])
        }
    }
    
    // 测试用快捷方法
    private func toggleUserTierForTesting() {
        switch userTier {
        case .free: userTier = .geek
        case .geek: userTier = .pro
        case .pro: userTier = .free
        }
    }
}
