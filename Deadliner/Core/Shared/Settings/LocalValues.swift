//
//  LocalValues.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import Foundation

actor LocalValues {
    static let shared = LocalValues()

    // 如果未来要做 App Group（Widget 共享），把 suiteName 换成你的 group id
    // private let defaults = UserDefaults(suiteName: "group.com.yourcompany.deadliner")!
    private let defaults = UserDefaults.standard

    private init() {
        registerDefaults()
    }

    // MARK: - Keys

    private enum Key {
        static let cloudSyncEnabled = "settings.cloud_sync_enabled"
        static let basicMode = "settings.basic_mode"
        static let autoArchiveDays = "settings.auto_archive_days"

        static let webdavURL = "settings.webdav.url"
        static let webdavUser = "settings.webdav.user"
        static let webdavPass = "settings.webdav.pass"

        // 你后面还可以继续加：
        // static let themeMode = "settings.theme_mode"
        // static let language = "settings.language"
    }

    // MARK: - DTO

    struct WebDAVAuth: Sendable {
        let user: String?
        let pass: String?
    }

    struct WebDAVConfig: Sendable {
        let url: String
        let auth: WebDAVAuth
    }

    // MARK: - Defaults

    private func registerDefaults() {
        defaults.register(defaults: [
            Key.cloudSyncEnabled: true,
            Key.basicMode: false,
            Key.autoArchiveDays: 7
        ])
    }

    // MARK: - Cloud Sync

    func getCloudSyncEnabled() -> Bool {
        defaults.bool(forKey: Key.cloudSyncEnabled)
    }

    func setCloudSyncEnabled(_ value: Bool) {
        defaults.set(value, forKey: Key.cloudSyncEnabled)
    }

    // MARK: - Basic Mode

    func getBasicMode() -> Bool {
        defaults.bool(forKey: Key.basicMode)
    }

    func setBasicMode(_ value: Bool) {
        defaults.set(value, forKey: Key.basicMode)
    }

    // MARK: - Auto Archive

    func getAutoArchiveDays() -> Int {
        let v = defaults.integer(forKey: Key.autoArchiveDays)
        return max(0, v) // 防御：不允许负数
    }

    func setAutoArchiveDays(_ days: Int) {
        defaults.set(max(0, days), forKey: Key.autoArchiveDays)
    }

    // MARK: - WebDAV

    func getWebDAVURL() -> String? {
        let s = defaults.string(forKey: Key.webdavURL)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (s?.isEmpty == false) ? s : nil
    }

    func setWebDAVURL(_ url: String?) {
        let trimmed = url?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let t = trimmed, !t.isEmpty {
            defaults.set(t, forKey: Key.webdavURL)
        } else {
            defaults.removeObject(forKey: Key.webdavURL)
        }
    }

    func getWebDAVAuth() -> WebDAVAuth {
        .init(
            user: defaults.string(forKey: Key.webdavUser),
            pass: defaults.string(forKey: Key.webdavPass)
        )
    }

    func setWebDAVAuth(user: String?, pass: String?) {
        if let user, !user.isEmpty {
            defaults.set(user, forKey: Key.webdavUser)
        } else {
            defaults.removeObject(forKey: Key.webdavUser)
        }

        if let pass, !pass.isEmpty {
            defaults.set(pass, forKey: Key.webdavPass)
        } else {
            defaults.removeObject(forKey: Key.webdavPass)
        }
    }

    func clearWebDAVAuth() {
        defaults.removeObject(forKey: Key.webdavUser)
        defaults.removeObject(forKey: Key.webdavPass)
    }

    func getWebDAVConfig() -> WebDAVConfig? {
        guard let url = getWebDAVURL() else { return nil }
        let auth = getWebDAVAuth()
        return .init(url: url, auth: auth)
    }

    // MARK: - Debug / Maintenance

    func resetAllSettings() {
        let keys: [String] = [
            Key.cloudSyncEnabled,
            Key.basicMode,
            Key.autoArchiveDays,
            Key.webdavURL,
            Key.webdavUser,
            Key.webdavPass
        ]
        keys.forEach { defaults.removeObject(forKey: $0) }
        registerDefaults()
    }
}
