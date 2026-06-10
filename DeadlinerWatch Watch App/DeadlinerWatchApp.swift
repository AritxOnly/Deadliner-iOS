import SwiftUI

@main
struct DeadlinerWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchBoardHomeView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            WatchSessionBridge.shared.requestRefresh()
        }
    }
}
