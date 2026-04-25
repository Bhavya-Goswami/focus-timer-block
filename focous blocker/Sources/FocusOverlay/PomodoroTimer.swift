import Combine
import Foundation

enum PomodoroPhase: String {
    case focus
    case shortBreak
    case longBreak

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }
}

@MainActor
final class PomodoroTimer: ObservableObject {
    private enum DefaultsKey {
        static let focusMinutes = "pomodoro.focusMinutes"
        static let shortBreakMinutes = "pomodoro.shortBreakMinutes"
        static let longBreakMinutes = "pomodoro.longBreakMinutes"
        static let completedFocusSessions = "pomodoro.completedFocusSessions"
        static let currentPhase = "pomodoro.currentPhase"
        static let remainingSeconds = "pomodoro.remainingSeconds"
    }

    @Published private(set) var remainingSeconds: Int
    @Published private(set) var isRunning = false
    @Published private(set) var currentPhase: PomodoroPhase = .focus
    @Published private(set) var focusMinutes: Int
    @Published private(set) var shortBreakMinutes: Int
    @Published private(set) var longBreakMinutes: Int
    @Published private(set) var completedFocusSessions = 0

    let sessionsBeforeLongBreak: Int
    let minSessionMinutes = 1
    let maxSessionMinutes = 180

    private var ticker: AnyCancellable?
    private var lastTickPersistedAt = Date.distantPast

    init(
        focusMinutes: Int = 25,
        shortBreakMinutes: Int = 5,
        longBreakMinutes: Int = 15,
        sessionsBeforeLongBreak: Int = 4
    ) {
        self.focusMinutes = max(1, focusMinutes)
        self.shortBreakMinutes = max(1, shortBreakMinutes)
        self.longBreakMinutes = max(1, longBreakMinutes)
        self.sessionsBeforeLongBreak = max(2, sessionsBeforeLongBreak)
        self.remainingSeconds = max(1, focusMinutes) * 60
        restorePersistedState()
        isRunning = false
    }

    var formattedRemaining: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func applyCustomMinutes(focus: Int, shortBreak: Int, longBreak: Int) {
        focusMinutes = clampedMinutes(focus)
        shortBreakMinutes = clampedMinutes(shortBreak)
        longBreakMinutes = clampedMinutes(longBreak)
        resetCurrentPhase()
        persistState()
    }

    func start() {
        guard !isRunning else { return }
        if remainingSeconds <= 0 {
            remainingSeconds = durationMinutes(for: currentPhase) * 60
        }

        isRunning = true
        ticker?.cancel()
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
        persistState()
    }

    func pause() {
        isRunning = false
        ticker?.cancel()
        ticker = nil
        persistState()
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    func resetCurrentPhase() {
        pause()
        remainingSeconds = durationMinutes(for: currentPhase) * 60
        persistState()
    }

    func resetCycle() {
        pause()
        currentPhase = .focus
        completedFocusSessions = 0
        remainingSeconds = durationMinutes(for: .focus) * 60
        persistState()
    }

    func skipToNextPhase() {
        pause()
        advanceToNextPhase()
        persistState()
    }

    private func tick() {
        guard isRunning else { return }
        if remainingSeconds > 0 {
            remainingSeconds -= 1
            maybePersistDuringRun()
            return
        }

        advanceToNextPhase()
        start()
    }

    private func advanceToNextPhase() {
        switch currentPhase {
        case .focus:
            completedFocusSessions += 1
            if completedFocusSessions % sessionsBeforeLongBreak == 0 {
                currentPhase = .longBreak
            } else {
                currentPhase = .shortBreak
            }
        case .shortBreak, .longBreak:
            currentPhase = .focus
        }

        remainingSeconds = durationMinutes(for: currentPhase) * 60
        persistState()
    }

    private func durationMinutes(for phase: PomodoroPhase) -> Int {
        switch phase {
        case .focus: return focusMinutes
        case .shortBreak: return shortBreakMinutes
        case .longBreak: return longBreakMinutes
        }
    }

    private func clampedMinutes(_ value: Int) -> Int {
        min(maxSessionMinutes, max(minSessionMinutes, value))
    }

    private func maybePersistDuringRun() {
        let now = Date()
        guard now.timeIntervalSince(lastTickPersistedAt) >= 15 else { return }
        lastTickPersistedAt = now
        persistState()
    }

    private func persistState() {
        let defaults = UserDefaults.standard
        defaults.set(focusMinutes, forKey: DefaultsKey.focusMinutes)
        defaults.set(shortBreakMinutes, forKey: DefaultsKey.shortBreakMinutes)
        defaults.set(longBreakMinutes, forKey: DefaultsKey.longBreakMinutes)
        defaults.set(completedFocusSessions, forKey: DefaultsKey.completedFocusSessions)
        defaults.set(currentPhase.rawValue, forKey: DefaultsKey.currentPhase)
        defaults.set(remainingSeconds, forKey: DefaultsKey.remainingSeconds)
    }

    private func restorePersistedState() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: DefaultsKey.focusMinutes) != nil {
            focusMinutes = clampedMinutes(defaults.integer(forKey: DefaultsKey.focusMinutes))
        }
        if defaults.object(forKey: DefaultsKey.shortBreakMinutes) != nil {
            shortBreakMinutes = clampedMinutes(defaults.integer(forKey: DefaultsKey.shortBreakMinutes))
        }
        if defaults.object(forKey: DefaultsKey.longBreakMinutes) != nil {
            longBreakMinutes = clampedMinutes(defaults.integer(forKey: DefaultsKey.longBreakMinutes))
        }

        let savedCompleted = defaults.integer(forKey: DefaultsKey.completedFocusSessions)
        completedFocusSessions = max(0, savedCompleted)

        if
            let rawPhase = defaults.string(forKey: DefaultsKey.currentPhase),
            let phase = PomodoroPhase(rawValue: rawPhase)
        {
            currentPhase = phase
        }

        let defaultRemaining = durationMinutes(for: currentPhase) * 60
        if defaults.object(forKey: DefaultsKey.remainingSeconds) != nil {
            remainingSeconds = max(0, defaults.integer(forKey: DefaultsKey.remainingSeconds))
        } else {
            remainingSeconds = defaultRemaining
        }
    }
}
