//
//  KMPTaskListViewModelBridge.swift
//  Deadliner
//
//  MainActor bridge from the shared TaskListViewModel StateFlow to SwiftUI.
//

#if canImport(Shared)
import Shared

@MainActor
final class KMPTaskListViewModelBridge {
    private let bridge: IosTaskListStateBridge

    private init(bridge: IosTaskListStateBridge) {
        self.bridge = bridge
    }

    static func make() async -> KMPTaskListViewModelBridge {
        let bridge = await KMPPersistenceRuntime.shared.taskListStateBridge()
        return KMPTaskListViewModelBridge(bridge: bridge)
    }

    func start(onState: @escaping @MainActor (TaskListUiState) -> Void) {
        bridge.start(onState: { state in
            onState(state)
        })
    }

    func refresh() {
        bridge.refresh()
    }

    deinit {
        bridge.close()
    }
}
#endif
