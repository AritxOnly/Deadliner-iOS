//
//  IconSettingsView.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/22.
//

import SwiftUI
import UIKit

// MARK: - App Icon Model
enum DeadlinerIcon: String, CaseIterable, Identifiable {
    case deadlinerDefault = "DeadlinerDefault"
    case blackGold        = "DeadlinerBlackGold"
    case pixel            = "DeadlinerPixel"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .deadlinerDefault: return "默认"
        case .blackGold:        return "黑金"
        case .pixel:            return "像素"
        }
    }

    /// setAlternateIconName 需要传的 name：
    /// - nil 表示恢复主图标（Primary Icon）
    var alternateIconName: String? {
        switch self {
        case .deadlinerDefault:
            return nil
        case .blackGold:
            return "DeadlinerBlackGold"
        case .pixel:
            return "DeadlinerPixel"
        }
    }

    /// Settings 里展示用的预览图（建议你在 Assets 里放 3 张 128/256 的预览 PNG）
    /// 比如：IconPreview-DeadlinerDefault / -DeadlinerBlackGold / -DeadlinerPixel
    var previewAssetName: String {
        "IconPreview-\(rawValue)"
    }
}

// MARK: - View
struct IconSettingsView: View {
    @AppStorage("selectedAppIcon") private var selectedAppIconRaw: String = DeadlinerIcon.deadlinerDefault.rawValue
    @State private var isApplying = false
    @State private var errorMessage: String?

    private var selectedIcon: DeadlinerIcon {
        get { DeadlinerIcon(rawValue: selectedAppIconRaw) ?? .deadlinerDefault }
        set { selectedAppIconRaw = newValue.rawValue }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("选择你喜欢的 Deadliner 图标。更换后会立即生效。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if !UIApplication.shared.supportsAlternateIcons {
                        Text("当前系统不支持自定义图标。")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("图标") {
                ForEach(DeadlinerIcon.allCases) { icon in
                    Button {
                        apply(icon)
                    } label: {
                        HStack(spacing: 12) {
                            Image(icon.previewAssetName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            Text(icon.displayName)
                                .foregroundStyle(.primary)

                            Spacer()

                            if isApplying && icon == selectedIcon {
                                ProgressView()
                            } else if icon == selectedIcon {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isApplying)
                }
            }
        }
        .navigationTitle("自定义图标")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // 进入页面时，尽量和系统当前 icon 对齐（防止用户在系统层面改过/或你后续扩展）
            syncFromSystemIconIfPossible()
        }
    }

    private func apply(_ icon: DeadlinerIcon) {
        guard UIApplication.shared.supportsAlternateIcons else {
            errorMessage = "系统不支持自定义图标。"
            return
        }

        // 已是当前选中则不重复调用
        if icon == selectedIcon { return }

        isApplying = true
        errorMessage = nil

        UIApplication.shared.setAlternateIconName(icon.alternateIconName) { error in
            DispatchQueue.main.async {
                self.isApplying = false
                if let error {
                    // 回滚 UI 选择（避免“存了但没改成功”）
                    self.errorMessage = "更换失败：\(error.localizedDescription)"
                    // 不改 selectedAppIconRaw，让它保持旧值更安全
                } else {
                    // 成功后再落盘
                    self.selectedAppIconRaw = icon.rawValue
                }
            }
        }
    }

    private func syncFromSystemIconIfPossible() {
        guard UIApplication.shared.supportsAlternateIcons else { return }

        let current = UIApplication.shared.alternateIconName
        // current == nil 代表 primary
        if current == nil {
            selectedAppIconRaw = DeadlinerIcon.deadlinerDefault.rawValue
        } else if current == "DeadlinerBlackGold" {
            selectedAppIconRaw = DeadlinerIcon.blackGold.rawValue
        } else if current == "DeadlinerPixel" {
            selectedAppIconRaw = DeadlinerIcon.pixel.rawValue
        }
        // 其他未知值：不动，避免误覆盖
    }
}
