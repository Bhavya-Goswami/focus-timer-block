import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let iconImage = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = iconImage
        }
    }
}

@main
struct FocusOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Focus Overlay", systemImage: "eye.slash.fill") {
            MenuContentView(
                store: model.blockedAppsStore,
                pomodoroTimer: model.pomodoroTimer,
                catalog: model.appCatalog
            )
                .frame(width: 560, height: 760)
                .task {
                    model.start()
                }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: model.blockedAppsStore)
                .frame(width: 320, height: 200)
                .task {
                    model.start()
                }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var store: BlockedAppsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus Overlay")
                .font(.title3.weight(.semibold))
            Text("Blocked apps: \(store.blockedBundleIDs.count)")
                .foregroundStyle(.secondary)
            Text("Use the menu bar icon to search and toggle blocked apps.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(16)
    }
}
