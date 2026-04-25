import Foundation
import Combine

@MainActor
final class BlockedAppsStore: ObservableObject {
    @Published private(set) var blockedBundleIDs: Set<String>

    private let defaultsKey = "blockedBundleIDs"

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        blockedBundleIDs = Set(saved)
    }

    func isBlocked(bundleID: String) -> Bool {
        blockedBundleIDs.contains(bundleID)
    }

    func setBlocked(bundleID: String, isBlocked: Bool) {
        if isBlocked {
            blockedBundleIDs.insert(bundleID)
        } else {
            blockedBundleIDs.remove(bundleID)
        }
        persist()
    }

    func setBlocked(bundleIDs: [String], isBlocked: Bool) {
        for bundleID in bundleIDs {
            if isBlocked {
                blockedBundleIDs.insert(bundleID)
            } else {
                blockedBundleIDs.remove(bundleID)
            }
        }
        persist()
    }

    func clearAll() {
        blockedBundleIDs.removeAll()
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(Array(blockedBundleIDs).sorted(), forKey: defaultsKey)
    }
}
