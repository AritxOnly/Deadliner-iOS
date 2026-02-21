//
//  PlusUpsellSection.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/21.
//

import SwiftUI

struct PlusUpsellSection: View {
    // 绑定父视图的弹窗状态
    @Binding var showPaywall: Bool
    
    var body: some View {
        Section {
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.title2)
                        .foregroundColor(.yellow)
                        .symbolEffect(.pulse, options: .repeating)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("解锁 Deadliner+")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("支持独立开发，解锁极客与高阶功能")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
}
