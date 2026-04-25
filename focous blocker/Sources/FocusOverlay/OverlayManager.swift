import AppKit
import Combine
import SwiftUI

@MainActor
final class OverlayManager {
    private let blockedAppsStore: BlockedAppsStore
    private let pomodoroTimer: PomodoroTimer
    private var cancellables = Set<AnyCancellable>()
    private var observers: [NSObjectProtocol] = []
    private var overlayControllers: [OverlayWindowController] = []
    private var currentBlockedPID: pid_t?
    private var currentBlockedName: String?
    private var previousApp: NSRunningApplication?

    init(blockedAppsStore: BlockedAppsStore, pomodoroTimer: PomodoroTimer) {
        self.blockedAppsStore = blockedAppsStore
        self.pomodoroTimer = pomodoroTimer
        subscribeToWorkspaceEvents()
        subscribeToBlockedList()
        subscribeToTimerUpdates()
        refreshOverlayForFrontmostApp()
    }

    deinit {
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    private func subscribeToWorkspaceEvents() {
        let nc = NSWorkspace.shared.notificationCenter

        observers.append(
            nc.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard
                    let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                else { return }
                Task { @MainActor [weak self] in
                    self?.handleActivatedApp(app)
                }
            }
        )

        observers.append(
            nc.addObserver(
                forName: NSWorkspace.didTerminateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard
                    let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                else { return }
                Task { @MainActor [weak self] in
                    self?.handleTerminatedApp(app)
                }
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.rebuildOverlayIfNeeded()
                }
            }
        )
    }

    private func subscribeToBlockedList() {
        blockedAppsStore.$blockedBundleIDs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshOverlayForFrontmostApp()
            }
            .store(in: &cancellables)
    }

    private func subscribeToTimerUpdates() {
        pomodoroTimer.$remainingSeconds
            .combineLatest(pomodoroTimer.$isRunning, pomodoroTimer.$currentPhase)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                self?.refreshOverlayTimerState()
            }
            .store(in: &cancellables)
    }

    private func handleActivatedApp(_ app: NSRunningApplication) {
        guard !isSelfApp(app) else { return }

        if isBlocked(app) {
            showOverlay(for: app)
            return
        }

        previousApp = app
        hideOverlay()
    }

    private func handleTerminatedApp(_ app: NSRunningApplication) {
        if app.processIdentifier == currentBlockedPID {
            hideOverlay()
        }
        if app.processIdentifier == previousApp?.processIdentifier {
            previousApp = nil
        }
    }

    private func refreshOverlayForFrontmostApp() {
        guard let frontmost = NSWorkspace.shared.frontmostApplication, !isSelfApp(frontmost) else {
            hideOverlay()
            return
        }

        if isBlocked(frontmost) {
            showOverlay(for: frontmost)
        } else {
            previousApp = frontmost
            hideOverlay()
        }
    }

    private func showOverlay(for app: NSRunningApplication) {
        guard app.bundleIdentifier != nil else { return }
        currentBlockedPID = app.processIdentifier
        currentBlockedName = app.localizedName ?? "App"

        if overlayControllers.isEmpty {
            overlayControllers = makeOverlayControllers()
        } else {
            overlayControllers.forEach {
                $0.update(
                    appName: currentBlockedName ?? "App",
                    previousAppName: previousApp?.localizedName,
                    timerText: pomodoroTimer.formattedRemaining,
                    timerIsRunning: pomodoroTimer.isRunning,
                    phaseTitle: pomodoroTimer.currentPhase.title
                )
            }
        }

        overlayControllers.forEach { $0.show() }
    }

    private func rebuildOverlayIfNeeded() {
        guard overlayControllers.isEmpty == false else { return }
        hideOverlayWindowsOnly()
        overlayControllers = makeOverlayControllers()
        overlayControllers.forEach { $0.show() }
    }

    private func refreshOverlayTimerState() {
        guard !overlayControllers.isEmpty else { return }
        overlayControllers.forEach {
            $0.updateTimer(
                timerText: pomodoroTimer.formattedRemaining,
                timerIsRunning: pomodoroTimer.isRunning,
                phaseTitle: pomodoroTimer.currentPhase.title
            )
        }
    }

    private func hideOverlayWindowsOnly() {
        overlayControllers.forEach { $0.hide() }
        overlayControllers.removeAll()
    }

    private func hideOverlay() {
        currentBlockedPID = nil
        currentBlockedName = nil
        hideOverlayWindowsOnly()
    }

    private func quitBlockedApp() {
        guard let pid = currentBlockedPID, let app = NSRunningApplication(processIdentifier: pid) else {
            hideOverlay()
            return
        }
        _ = app.terminate()
        hideOverlay()
        activatePreviousApp()
    }

    private func activatePreviousApp() {
        guard let previousApp, !previousApp.isTerminated else {
            hideOverlay()
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"), configuration: NSWorkspace.OpenConfiguration())
            return
        }
        hideOverlay()
        previousApp.activate(options: [.activateAllWindows])
    }

    private func isBlocked(_ app: NSRunningApplication) -> Bool {
        guard let bundleID = app.bundleIdentifier else { return false }
        return blockedAppsStore.isBlocked(bundleID: bundleID)
    }

    private func isSelfApp(_ app: NSRunningApplication) -> Bool {
        app.processIdentifier == ProcessInfo.processInfo.processIdentifier
    }

    private func makeOverlayControllers() -> [OverlayWindowController] {
        let appName = currentBlockedName ?? "App"
        let previousName = previousApp?.localizedName
        let timerText = pomodoroTimer.formattedRemaining
        let timerIsRunning = pomodoroTimer.isRunning
        let phaseTitle = pomodoroTimer.currentPhase.title

        return NSScreen.screens.map { screen in
            OverlayWindowController(
                screen: screen,
                appName: appName,
                previousAppName: previousName,
                timerText: timerText,
                timerIsRunning: timerIsRunning,
                phaseTitle: phaseTitle,
                onQuitApp: { [weak self] in
                    self?.quitBlockedApp()
                },
                onBackToPrevious: { [weak self] in
                    self?.activatePreviousApp()
                }
            )
        }
    }
}

@MainActor
final class OverlayWindowController: NSWindowController {
    private let screen: NSScreen
    private let hostingController: NSHostingController<OverlayView>
    private let screenModel: OverlayScreenModel
    private let onQuitApp: () -> Void
    private let onBackToPrevious: () -> Void

    init(
        screen: NSScreen,
        appName: String,
        previousAppName: String?,
        timerText: String,
        timerIsRunning: Bool,
        phaseTitle: String,
        onQuitApp: @escaping () -> Void,
        onBackToPrevious: @escaping () -> Void
    ) {
        self.screen = screen
        self.onQuitApp = onQuitApp
        self.onBackToPrevious = onBackToPrevious
        self.screenModel = OverlayScreenModel(
            appName: appName,
            previousAppName: previousAppName,
            timerText: timerText,
            timerIsRunning: timerIsRunning,
            phaseTitle: phaseTitle
        )
        self.hostingController = NSHostingController(
            rootView: OverlayView(
                model: screenModel,
                onQuitApp: onQuitApp,
                onBackToPrevious: onBackToPrevious
            )
        )

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.ignoresMouseEvents = false
        window.hasShadow = false
        window.contentViewController = hostingController
        window.setFrame(screen.frame, display: true)

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(
        appName: String,
        previousAppName: String?,
        timerText: String,
        timerIsRunning: Bool,
        phaseTitle: String
    ) {
        screenModel.appName = appName
        screenModel.previousAppName = previousAppName
        screenModel.timerText = timerText
        screenModel.timerIsRunning = timerIsRunning
        screenModel.phaseTitle = phaseTitle
    }

    func updateTimer(timerText: String, timerIsRunning: Bool, phaseTitle: String) {
        screenModel.timerText = timerText
        screenModel.timerIsRunning = timerIsRunning
        screenModel.phaseTitle = phaseTitle
    }

    func show() {
        guard let window else { return }
        window.setFrame(screen.frame, display: true)
        window.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }
}
