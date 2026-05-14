import Foundation

@MainActor
final class GameViewModel: ObservableObject {
    enum State: Equatable {
        case resisting
        case failed
        case survived
    }

    @Published private(set) var state: State = .resisting
    @Published private(set) var elapsedSeconds: Int = 0
    @Published private(set) var pulseLevel: Double = 0

    private let audioPlayer: AudioTauntPlaying
    private var startedAt = Date()
    private var tickTask: Task<Void, Never>?
    private var normalAudioTask: Task<Void, Never>?

    init(audioPlayer: AudioTauntPlaying) {
        self.audioPlayer = audioPlayer
        start()
    }

    deinit {
        tickTask?.cancel()
        normalAudioTask?.cancel()
    }

    var elapsedText: String {
        formatted(seconds: elapsedSeconds)
    }

    var survivedText: String {
        "あなたは\(formatted(seconds: elapsedSeconds))耐え抜きました"
    }

    func start() {
        state = .resisting
        startedAt = Date()
        elapsedSeconds = 0
        pulseLevel = 0
        audioPlayer.stopLoop()
        startClock()
        startNormalAudioLoop()
    }

    func pressForbiddenButton() {
        guard state == .resisting else { return }
        updateElapsed()
        state = .failed
        tickTask?.cancel()
        normalAudioTask?.cancel()
        audioPlayer.stopOneShot()
        audioPlayer.startPressedLoop()
    }

    func finishWithoutPressing() {
        guard state == .resisting else { return }
        updateElapsed()
        state = .survived
        tickTask?.cancel()
        normalAudioTask?.cancel()
        audioPlayer.stopAll()
    }

    private func startClock() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.25))
                self?.updateElapsed()
            }
        }
    }

    private func startNormalAudioLoop() {
        normalAudioTask?.cancel()
        normalAudioTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let delay = self.nextNormalDelay()
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                self.audioPlayer.playRandomNormalOrWarning(elapsedSeconds: self.elapsedSeconds)
            }
        }
    }

    private func updateElapsed() {
        elapsedSeconds = max(0, Int(Date().timeIntervalSince(startedAt)))
        pulseLevel = min(1, Double(elapsedSeconds) / 180.0)
    }

    private func nextNormalDelay() -> Double {
        switch elapsedSeconds {
        case 0..<30:
            Double.random(in: 8...14)
        case 30..<90:
            Double.random(in: 5...9)
        case 90..<180:
            Double.random(in: 3...6)
        default:
            Double.random(in: 1.6...3.4)
        }
    }

    private func formatted(seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return "\(minutes)分\(seconds)秒"
    }
}
