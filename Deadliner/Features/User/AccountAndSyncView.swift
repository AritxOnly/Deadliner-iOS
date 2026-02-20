//
//  AccountAndSyncView.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import SwiftUI

struct AccountAndSyncView: View {
    @State private var cloudSyncEnabled = true
    @State private var basicMode = false

    @State private var webdavURL = ""
    @State private var webdavUser = ""
    @State private var webdavPass = ""

    @State private var autoArchiveDays = 7

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var message: String?
    @State private var showMessage = false

    var body: some View {
        Form {
            Section("同步开关") {
                Toggle("启用云同步", isOn: $cloudSyncEnabled)
                Toggle("Basic 模式（禁用云同步行为）", isOn: $basicMode)
            }

            Section("WebDAV") {
                TextField("服务器 URL（https://...）", text: $webdavURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("用户名（可选）", text: $webdavUser)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("密码（可选）", text: $webdavPass)

                Button("清空 WebDAV 凭据", role: .destructive) {
                    Task { await clearWebDAV() }
                }
            }

            Section("自动归档") {
                Stepper(value: $autoArchiveDays, in: 0...365) {
                    HStack {
                        Text("归档天数")
                        Spacer()
                        Text("\(autoArchiveDays) 天")
                            .foregroundStyle(.secondary)
                    }
                }
                Text("0 表示关闭自动归档")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        Text("保存设置")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSaving || isLoading)
            }

            Section("说明") {
                Text("URL 为空时不会创建同步服务。保存后可在首页触发一次手动同步验证配置。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("账号与同步")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
        .alert("提示", isPresented: $showMessage) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    // MARK: - Actions

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }

        cloudSyncEnabled = await LocalValues.shared.getCloudSyncEnabled()
        basicMode = await LocalValues.shared.getBasicMode()
        autoArchiveDays = await LocalValues.shared.getAutoArchiveDays()

        if let cfg = await LocalValues.shared.getWebDAVConfig() {
            webdavURL = cfg.url
            webdavUser = cfg.auth.user ?? ""
            webdavPass = cfg.auth.pass ?? ""
        } else {
            webdavURL = ""
            webdavUser = ""
            webdavPass = ""
        }
    }

    @MainActor
    private func save() async {
        let trimmedURL = webdavURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedURL.isEmpty, !isLikelyValidURL(trimmedURL) {
            message = "WebDAV URL 格式不合法，请输入 http(s):// 开头的地址"
            showMessage = true
            return
        }

        isSaving = true
        defer { isSaving = false }

        await LocalValues.shared.setCloudSyncEnabled(cloudSyncEnabled)
        await LocalValues.shared.setBasicMode(basicMode)
        await LocalValues.shared.setAutoArchiveDays(autoArchiveDays)

        await LocalValues.shared.setWebDAVURL(trimmedURL.isEmpty ? nil : trimmedURL)
        await LocalValues.shared.setWebDAVAuth(
            user: webdavUser.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : webdavUser.trimmingCharacters(in: .whitespacesAndNewlines),
            pass: webdavPass.isEmpty ? nil : webdavPass
        )

        message = "设置已保存"
        showMessage = true
    }

    @MainActor
    private func clearWebDAV() async {
        await LocalValues.shared.setWebDAVURL(nil)
        await LocalValues.shared.clearWebDAVAuth()

        webdavURL = ""
        webdavUser = ""
        webdavPass = ""

        message = "WebDAV 配置已清空"
        showMessage = true
    }

    private func isLikelyValidURL(_ s: String) -> Bool {
        guard let u = URL(string: s),
              let scheme = u.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              u.host != nil else {
            return false
        }
        return true
    }
}
