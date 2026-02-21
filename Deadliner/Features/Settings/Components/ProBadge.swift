//
//  ProBadge.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/21.
//

import SwiftUI

// MARK: - Pro 徽标 (橙红渐变)
struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Capsule())
    }
}

// MARK: - Geek 徽标 (蓝紫渐变)
struct GeekBadge: View {
    var body: some View {
        Text("GEEK")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Capsule())
    }
}

// MARK: - Plus 徽标 (Deadliner+ 通用高级徽标)
struct PlusBadge: View {
    var body: some View {
        HStack(spacing: 2) {
            Text("PLUS")
            Image(systemName: "plus")
                .font(.system(size: 8, weight: .black))
        }
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            // 使用深邃的紫黑/蓝黑渐变，代表它是所有高级特权的集合
            LinearGradient(colors: [Color(white: 0.3), Color(white: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(Capsule())
    }
}
