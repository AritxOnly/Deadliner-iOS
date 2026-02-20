//
//  UserPanelSheetContent.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import SwiftUI

struct UserPanelSheet: View {
    @Binding var selectedModule: MainModule

    var body: some View {
        List {
            Section("导航") {
                ForEach(MainModule.allCases) { module in
                    Button {
                        selectedModule = module
                    } label: {
                        Label(module.title, systemImage: module.systemImage)
                    }
                }
            }

            Section("设置") {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label("设置", systemImage: "gearshape")
                }
            }

            Section("账户") {
                Label("用户信息", systemImage: "person.text.rectangle")
                Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
        .navigationTitle("个人面板")
        .navigationBarTitleDisplayMode(.inline)
    }
}
