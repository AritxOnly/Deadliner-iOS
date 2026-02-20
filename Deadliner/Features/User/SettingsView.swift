//
//  SettingsView.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section("通用") {
                NavigationLink {
                    AccountAndSyncView()
                } label: {
                    Label("账号与同步", systemImage: "person.crop.circle")
                }

                Label("通知设置", systemImage: "bell")
                Label("默认主页", systemImage: "house")
            }

            Section("外观") {
                Label("主题", systemImage: "paintbrush")
                Label("图标", systemImage: "app")
            }

            Section("关于") {
                Label("版本信息", systemImage: "info.circle")
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}
