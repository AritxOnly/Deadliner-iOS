//
//  DeadlinerApp.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/13.
//

import SwiftUI

private enum AppReleaseGate {
    static let unlockGeekForCurrentRelease = false
}

@main
struct DeadlinerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("selectedAppIcon") private var selectedAppIconRaw: String = DeadlinerIcon.deadlinerDefault.rawValue
    @AppStorage("userTier") private var userTier: UserTier = .free
    @StateObject private var themeStore = ThemeStore()
    
    init() {
        // Keep only logs for current app launch session.
        AILog.clearForNewLaunchSession()
        SyncDebugLog.clearForNewLaunchSession()
        IconDebugLog.clearForNewLaunchSession()

        // Capture process stdout/stderr and mirror to AI log file without changing Rust side.
        AIStdStreamCapture.shared.startIfNeeded()
        AILog.log("[Session] New launch session started")
        SyncDebugLog.log("[Session] New launch session started")
        do {
            try KMPSharedDatabaseBootstrap.prepareIfNeeded()
        } catch {
            SyncDebugLog.log("[KMP] Shared database bootstrap failed: \(error.localizedDescription)")
        }
        PhoneWatchSyncBridge.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(themeStore)
                .task {
                    // Adopt an already-migrated KMP database before deciding
                    // whether a one-time legacy import is still needed.
                    _ = await KMPPersistenceExperiment.adoptExistingStoreIfPresent()
                    _ = await KMPTaskHabitMigrationExperiment.adoptExistingStoreIfPresent()

                    do {
                        try await DeadlinerCoreBridge.shared.initializeIfNeeded()
                    } catch {
                        AILog.log("Core init failed on launch task: \(error.localizedDescription)")
                        SyncDebugLog.log("Core init failed on launch task: \(error.localizedDescription)")
                        assertionFailure("DB init failed: \(error)")
                    }

                    do {
                        if let report = try await KMPPersistenceExperiment.prepareOnLaunchIfEnabled() {
                            let message =
                                "[KMP] Category migration valid=\(report.isValid) source=\(report.sourceCount) "
                                    + "imported=\(report.importedCount) updated=\(report.updatedCount)"
                            SyncDebugLog.log(message)
                            print(message)
                        }
                    } catch {
                        SyncDebugLog.log("[KMP] Category migration failed: \(error.localizedDescription)")
                    }

                    // Keep the first frame responsive on upgraded devices.
                    // Feature stores are KMP-only and receive a change event
                    // after the background import completes.
                    _Concurrency.Task(priority: .utility) {
                        await KMPTaskHabitMigrationExperiment.ensureReadyForRuntime()
                    }

                    #if DEBUG
                    // This scans both SwiftData and KMP stores in full. Keep it
                    // out of release startup, especially on upgraded devices.
                    await KMPTaskHabitMigrationDiagnostics.logLegacyComparison()
                    #endif

                    if AppReleaseGate.unlockGeekForCurrentRelease {
                        userTier = .geek
                    } else if userTier == .pro {
                        userTier = .geek
                    }

                    // 请求通知权限
                    NotificationManager.shared.requestAuthorization()

                    // 启动时自动校验一次会员权益（先本地，后限时网络），弱网不阻塞体验
                    await StoreManager.shared.refreshEntitlementsOnLaunch()
                    
                    await KMPTaskReminderScheduler.shared.scheduleRefresh()
                    await KMPHabitReminderScheduler.shared.scheduleRefresh()
                    await PhoneWatchSyncBridge.shared.pushLatestSnapshot(reason: "launchTask")
                }
                .onAppear {
                    // 启动时也跑一次（有时不会立刻触发 scenePhase 变化）
                    applyAutoSeasonIconIfNeeded()
                    Task {
                        do {
                            try await DeadlinerCoreBridge.shared.initializeIfNeeded()
                            await KMPTaskReminderScheduler.shared.scheduleRefresh()
                            await KMPHabitReminderScheduler.shared.scheduleRefresh()
                            await PhoneWatchSyncBridge.shared.pushLatestSnapshot(reason: "onAppear")
                        } catch {
                            AILog.log("Core init failed on appear: \(error.localizedDescription)")
                            SyncDebugLog.log("Core init failed on appear: \(error.localizedDescription)")
                            assertionFailure("DB init failed on appear: \(error)")
                        }
                    }
                }
                .onChange(of: scenePhase) { phase in
                    // 回到前台时刷新一次即可
                    guard phase == .active else { return }
                    applyAutoSeasonIconIfNeeded()
                    Task { await StoreManager.shared.refreshEntitlementsOnLaunch() }
                    Task {
                        do {
                            try await DeadlinerCoreBridge.shared.initializeIfNeeded()
                            await KMPTaskReminderScheduler.shared.scheduleRefresh()
                            await KMPHabitReminderScheduler.shared.scheduleRefresh()
                            await PhoneWatchSyncBridge.shared.pushLatestSnapshot(reason: "sceneActive")
                        } catch {
                            AILog.log("Core init failed on active: \(error.localizedDescription)")
                            SyncDebugLog.log("Core init failed on active: \(error.localizedDescription)")
                            assertionFailure("DB init failed on active: \(error)")
                        }
                    }
                }

            
        }
    }
    
    private func applyAutoSeasonIconIfNeeded() {
        guard UIApplication.shared.supportsAlternateIcons else { return }

        let selected = DeadlinerIcon(rawValue: selectedAppIconRaw) ?? .deadlinerDefault
        guard selected == .autoSeason else { return }

        // 目标：当前季节对应的图标
        let s = SeasonUtils.season(for: Date())
        let target = {
            switch s {
            case .spring: return DeadlinerIcon.spring
            case .summer: return DeadlinerIcon.summer
            case .autumn: return DeadlinerIcon.autumn
            case .winter: return DeadlinerIcon.winter
            }
        }()
        let targetName = target.alternateIconName

        // 当前系统图标
        let currentName = UIApplication.shared.alternateIconName
        let currentIcon: DeadlinerIcon = {
            if currentName == nil { return .deadlinerDefault }
            return DeadlinerIcon(rawValue: currentName!) ?? .deadlinerDefault
        }()

        // 已经是目标则不重复调用
        guard currentIcon != target else { return }

        UIApplication.shared.setAlternateIconName(targetName, completionHandler: nil)
    }

}
