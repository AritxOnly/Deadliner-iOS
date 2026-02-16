//
//  AddEntrySheetContent.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import SwiftUI

struct AddEntrySheet: View {
    var body: some View {
        List {
            Section("Create") {
                Label("新建任务", systemImage: "checkmark.circle")
                Label("新建习惯", systemImage: "repeat.circle")
            }
            Section("Quick") {
                Label("用 Deadliner AI 导入", systemImage: "apple.intelligence")
            }
        }
    }
}
