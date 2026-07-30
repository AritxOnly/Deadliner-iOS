//
//  KMPOverviewViewModelBridge.swift
//  Deadliner
//
//  MainActor bridge from the shared Overview StateFlow to SwiftUI.
//

#if canImport(Shared)
import Shared

/// Mirrors the proven task/habit bridge boundary. Keeping the Kotlin callback
/// inside this MainActor-owned object avoids passing an unisolated closure from
/// a SwiftUI view model directly into Kotlin/Native.
@MainActor
final class KMPOverviewViewModelBridge {
    private let bridge: IosOverviewStateBridge

    private init(bridge: IosOverviewStateBridge) {
        self.bridge = bridge
    }

    static func make() async -> KMPOverviewViewModelBridge {
        let bridge = await KMPPersistenceRuntime.shared.overviewStateBridge()
        return KMPOverviewViewModelBridge(bridge: bridge)
    }

    /// Requests one KMP snapshot. Database work and aggregation stay off the
    /// SwiftUI executor; KMP delivers this closure back on the main thread.
    func load(onState: @escaping @MainActor (OverviewUiState) -> Void) {
        bridge.load(onState: { state in
            onState(state)
        })
    }

    func close() {
        bridge.close()
    }

    deinit {
        bridge.close()
    }
}
#endif
