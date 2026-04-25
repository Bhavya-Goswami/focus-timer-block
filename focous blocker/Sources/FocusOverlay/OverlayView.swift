import SwiftUI

struct OverlayView: View {
    @ObservedObject var model: OverlayScreenModel
    let onQuitApp: () -> Void
    let onBackToPrevious: () -> Void

    @State private var animateIn = false

    var body: some View {
        ZStack {
            Color.black.opacity(animateIn ? 0.86 : 0)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(model.phaseTitle.uppercased())
                        .font(OverlayFont.font(size: 24, weight: .semibold))
                        .foregroundStyle(model.timerIsRunning ? .green : .orange)
                    Spacer()
                    Text(model.timerStatusLine.uppercased())
                        .font(OverlayFont.font(size: 16))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                Text("\(model.appName.lowercased())\nblocked")
                    .font(OverlayFont.font(size: 92, weight: .bold))
                    .foregroundStyle(.white)
                    .lineSpacing(-12)
                    .tracking(0.8)

                Spacer()

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        actionButton("Quit \(model.appName)", color: .red, action: onQuitApp)
                        actionButton(previousButtonTitle, color: .white, action: onBackToPrevious)
                            .disabled(model.previousAppName == nil)
                            .opacity(model.previousAppName == nil ? 0.4 : 1)
                    }
                    Spacer()
                    Text(model.timerText)
                        .font(OverlayFont.font(size: 154, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.2), radius: 10)
                        .offset(y: 8)
                }
            }
            .padding(.horizontal, 86)
            .padding(.vertical, 56)
            .blur(radius: animateIn ? 0 : 10)
            .opacity(animateIn ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) {
                animateIn = true
            }
        }
    }

    private func actionButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(OverlayFont.font(size: 32, weight: .medium))
            .foregroundStyle(color)
    }

    private var previousButtonTitle: String {
        if let previousAppName = model.previousAppName {
            return "Back to \(previousAppName)"
        }
        return "No Previous App"
    }
}

@MainActor
final class OverlayScreenModel: ObservableObject {
    @Published var appName: String
    @Published var previousAppName: String?
    @Published var timerText: String
    @Published var timerIsRunning: Bool
    @Published var phaseTitle: String

    init(
        appName: String,
        previousAppName: String?,
        timerText: String,
        timerIsRunning: Bool,
        phaseTitle: String
    ) {
        self.appName = appName
        self.previousAppName = previousAppName
        self.timerText = timerText
        self.timerIsRunning = timerIsRunning
        self.phaseTitle = phaseTitle
    }

    var timerStatusLine: String {
        timerIsRunning ? "time remaining" : "timer paused"
    }
}
