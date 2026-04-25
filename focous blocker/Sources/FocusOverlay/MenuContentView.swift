import AppKit
import SwiftUI

private enum AppFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case blocked = "Blocked"
    case available = "Available"

    var id: String { rawValue }
}

struct MenuContentView: View {
    @ObservedObject var store: BlockedAppsStore
    @ObservedObject var pomodoroTimer: PomodoroTimer
    let catalog: AppCatalog

    @State private var apps: [InstalledApp] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var selectedFilter: AppFilter = .all
    @State private var focusInput = "25"
    @State private var shortBreakInput = "5"
    @State private var longBreakInput = "15"
    @State private var loadTask: Task<Void, Never>?

    private var filteredApps: [InstalledApp] {
        let searched = searchText.isEmpty ? apps : apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleID.localizedCaseInsensitiveContains(searchText)
        }

        let scoped: [InstalledApp]
        switch selectedFilter {
        case .all:
            scoped = searched
        case .blocked:
            scoped = searched.filter { store.isBlocked(bundleID: $0.bundleID) }
        case .available:
            scoped = searched.filter { !store.isBlocked(bundleID: $0.bundleID) }
        }

        return scoped.sorted { lhs, rhs in
            let leftBlocked = store.isBlocked(bundleID: lhs.bundleID)
            let rightBlocked = store.isBlocked(bundleID: rhs.bundleID)
            if leftBlocked != rightBlocked { return leftBlocked && !rightBlocked }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var blockedCount: Int {
        store.blockedBundleIDs.count
    }

    private var filteredBundleIDs: [String] {
        filteredApps.map(\.bundleID)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.12),
                    Color(red: 0.04, green: 0.04, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                headerSection
                pomodoroSection
                appControls
                appListSection
                footerSection
            }
            .padding(12)
        }
        .task {
            loadApps()
        }
        .onAppear {
            syncInputsFromTimer()
        }
        .onDisappear {
            loadTask?.cancel()
        }
        .onChange(of: focusInput) { _, newValue in
            focusInput = sanitizedMinuteText(newValue)
        }
        .onChange(of: shortBreakInput) { _, newValue in
            shortBreakInput = sanitizedMinuteText(newValue)
        }
        .onChange(of: longBreakInput) { _, newValue in
            longBreakInput = sanitizedMinuteText(newValue)
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Focus Overlay")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text("\(blockedCount) blocked • \(apps.count) indexed")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer()
            Picker("Filter", selection: $selectedFilter) {
                ForEach(AppFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 230)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var pomodoroSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Pomodoro")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(pomodoroTimer.currentPhase.title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
            }

            HStack(alignment: .firstTextBaseline) {
                Text(pomodoroTimer.formattedRemaining)
                    .font(.system(size: 40, weight: .black, design: .monospaced))
                    .foregroundStyle(pomodoroTimer.isRunning ? .green : .white)
                Spacer()
                Text("Focus done: \(pomodoroTimer.completedFocusSessions)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }

            HStack(spacing: 8) {
                primaryControlButton(pomodoroTimer.isRunning ? "Pause" : "Start") {
                    pomodoroTimer.toggle()
                }
                secondaryControlButton("Reset Phase") {
                    pomodoroTimer.resetCurrentPhase()
                }
                secondaryControlButton("Reset Cycle") {
                    pomodoroTimer.resetCycle()
                }
                secondaryControlButton("Skip") {
                    pomodoroTimer.skipToNextPhase()
                }
            }

            HStack(spacing: 8) {
                CustomMinuteField(label: "Focus", text: $focusInput)
                CustomMinuteField(label: "Short", text: $shortBreakInput)
                CustomMinuteField(label: "Long", text: $longBreakInput)
                primaryControlButton("Apply") {
                    applyCustomMinutes()
                }
                .frame(width: 74)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var appControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("Search app name or bundle id…", text: $searchText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)

                Button {
                    loadApps(forceRefresh: true)
                } label: {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                            .frame(width: 28, height: 20)
                    } else {
                        Text("Refresh")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }

            HStack(spacing: 8) {
                Button("Block Visible") {
                    store.setBlocked(bundleIDs: filteredBundleIDs, isBlocked: true)
                }
                .buttonStyle(.bordered)
                .disabled(filteredBundleIDs.isEmpty)

                Button("Unblock Visible") {
                    store.setBlocked(bundleIDs: filteredBundleIDs, isBlocked: false)
                }
                .buttonStyle(.bordered)
                .disabled(filteredBundleIDs.isEmpty)

                Button("Clear All Blocked") {
                    store.clearAll()
                }
                .buttonStyle(.bordered)
                .disabled(blockedCount == 0)

                Spacer()

                if !searchText.isEmpty {
                    Button("Clear Search") {
                        searchText = ""
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.75))
                }
            }
        }
    }

    private var appListSection: some View {
        Group {
            if isLoading && apps.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Scanning installed apps…")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredApps.isEmpty {
                VStack(spacing: 8) {
                    Text("No matches")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Try changing search or filter")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredApps) { app in
                            AppRowView(
                                app: app,
                                isBlocked: store.isBlocked(bundleID: app.bundleID),
                                onToggle: { value in
                                    store.setBlocked(bundleID: app.bundleID, isBlocked: value)
                                }
                            )
                        }
                    }
                    .padding(10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var footerSection: some View {
        HStack {
            Text("Overlay is active for blocked apps")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .foregroundStyle(.red)
        }
    }

    private func primaryControlButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
    }

    private func secondaryControlButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
    }

    private func applyCustomMinutes() {
        let focus = parsedMinute(from: focusInput, fallback: pomodoroTimer.focusMinutes)
        let shortBreak = parsedMinute(from: shortBreakInput, fallback: pomodoroTimer.shortBreakMinutes)
        let longBreak = parsedMinute(from: longBreakInput, fallback: pomodoroTimer.longBreakMinutes)
        pomodoroTimer.applyCustomMinutes(focus: focus, shortBreak: shortBreak, longBreak: longBreak)
        syncInputsFromTimer()
    }

    private func syncInputsFromTimer() {
        focusInput = String(pomodoroTimer.focusMinutes)
        shortBreakInput = String(pomodoroTimer.shortBreakMinutes)
        longBreakInput = String(pomodoroTimer.longBreakMinutes)
    }

    private func loadApps(forceRefresh: Bool = false) {
        loadTask?.cancel()
        isLoading = true
        loadTask = Task { @MainActor in
            let discovered = await catalog.discoverInstalledApps(forceRefresh: forceRefresh)
            guard !Task.isCancelled else { return }
            apps = discovered
            isLoading = false
        }
    }

    private func parsedMinute(from text: String, fallback: Int) -> Int {
        let parsed = Int(text) ?? fallback
        return min(pomodoroTimer.maxSessionMinutes, max(pomodoroTimer.minSessionMinutes, parsed))
    }

    private func sanitizedMinuteText(_ text: String) -> String {
        let digitsOnly = text.filter(\.isNumber)
        return String(digitsOnly.prefix(3))
    }
}

private struct AppRowView: View {
    let app: InstalledApp
    let isBlocked: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 10) {
            AppIconView(url: app.url)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.white)
                Text(app.bundleID)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Toggle("", isOn: Binding(get: { isBlocked }, set: onToggle))
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isBlocked ? Color.red.opacity(0.17) : Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct AppIconView: View {
    let url: URL

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
            .resizable()
            .interpolation(.high)
            .frame(width: 20, height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

private struct CustomMinuteField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
            TextField("min", text: $text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .frame(width: 62)
                .foregroundStyle(.white)
        }
    }
}
