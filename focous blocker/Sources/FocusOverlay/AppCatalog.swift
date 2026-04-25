import AppKit
import Foundation

struct InstalledApp: Identifiable, Hashable {
    let bundleID: String
    let name: String
    let url: URL

    var id: String { bundleID }
}

final class AppCatalog {
    private let appRoots: [URL] = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/System/Applications"),
        URL(fileURLWithPath: "/System/Applications/Utilities"),
        URL(fileURLWithPath: "\(NSHomeDirectory())/Applications")
    ]
    private var cachedApps: [InstalledApp] = []
    private var hasLoadedCache = false

    func discoverInstalledApps(forceRefresh: Bool = false) async -> [InstalledApp] {
        if !forceRefresh, hasLoadedCache {
            return cachedApps
        }

        let discovered = await Task.detached(priority: .userInitiated) { [appRoots] in
            var deduped: [String: InstalledApp] = [:]
            let fileManager = FileManager.default
            let resourceKeys: Set<URLResourceKey> = [.isApplicationKey, .localizedNameKey]

            for root in appRoots {
                guard let urls = try? fileManager.contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: Array(resourceKeys),
                    options: [.skipsHiddenFiles]
                ) else {
                    continue
                }

                for url in urls where url.pathExtension.lowercased() == "app" {
                    let bundle = Bundle(url: url)
                    let bundleID = bundle?.bundleIdentifier ?? url.path
                    let appName = (try? url.resourceValues(forKeys: resourceKeys).localizedName)
                        ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                        ?? url.deletingPathExtension().lastPathComponent

                    deduped[bundleID] = InstalledApp(bundleID: bundleID, name: appName, url: url)
                }
            }

            return deduped.values.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }.value

        cachedApps = discovered
        hasLoadedCache = true
        return discovered
    }
}
