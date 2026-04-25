import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    let blockedAppsStore = BlockedAppsStore()
    let appCatalog = AppCatalog()
    let pomodoroTimer = PomodoroTimer()
    private var overlayManager: OverlayManager?

    func start() {
        guard overlayManager == nil else { return }
        OverlayFont.registerIfNeeded()
        overlayManager = OverlayManager(
            blockedAppsStore: blockedAppsStore,
            pomodoroTimer: pomodoroTimer
        )
    }
}
