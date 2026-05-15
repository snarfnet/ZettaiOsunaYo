import Foundation

@MainActor
final class GameViewModel: ObservableObject {
    enum State: Equatable {
        case resisting
        case failed
        case survived
    }

    enum Mode: String, CaseIterable, Identifiable, Codable {
        case classic
        case thirty
        case endurance
        case chaos

        var id: String { rawValue }

        var title: String {
            switch self {
            case .classic:
                return "クラシック"
            case .thirty:
                return "30秒チャレンジ"
            case .endurance:
                return "限界耐久"
            case .chaos:
                return "煽り強め"
            }
        }

        var shortTitle: String {
            switch self {
            case .classic:
                return "通常"
            case .thirty:
                return "30秒"
            case .endurance:
                return "耐久"
            case .chaos:
                return "強め"
            }
        }

        var subtitle: String {
            switch self {
            case .classic:
                return "好きなタイミングで退室。押したら負け。"
            case .thirty:
                return "30秒耐えたら勝ち。初回におすすめ。"
            case .endurance:
                return "3分を越えると称号が変わる長期戦。"
            case .chaos:
                return "声と演出の圧が早く上がる上級者向け。"
            }
        }

        var targetSeconds: Int? {
            switch self {
            case .classic, .chaos:
                return nil
            case .thirty:
                return 30
            case .endurance:
                return 180
            }
        }

        var pressureScale: Double {
            switch self {
            case .classic:
                return 1.0
            case .thirty:
                return 1.25
            case .endurance:
                return 0.72
            case .chaos:
                return 1.75
            }
        }
    }

    struct SessionRecord: Identifiable, Codable, Equatable {
        let id: UUID
        let date: Date
        let mode: Mode
        let seconds: Int
        let succeeded: Bool

        var resultText: String {
            succeeded ? "耐え抜いた" : "押した"
        }
    }

    @Published private(set) var state: State = .resisting
    @Published private(set) var elapsedSeconds: Int = 0
    @Published private(set) var pulseLevel: Double = 0
    @Published private(set) var sessions: [SessionRecord] = []
    @Published var selectedMode: Mode = .thirty

    private let audioPlayer: AudioTauntPlaying
    private var startedAt = Date()
    private var tickTask: Task<Void, Never>?
    private var normalAudioTask: Task<Void, Never>?
    private let sessionsKey = "zettai.sessions.v2"
    private let modeKey = "zettai.selectedMode.v2"

    init(audioPlayer: AudioTauntPlaying) {
        self.audioPlayer = audioPlayer
        loadProgress()
        start()
    }

    deinit {
        tickTask?.cancel()
        normalAudioTask?.cancel()
    }

    var elapsedText: String {
        formatted(seconds: elapsedSeconds)
    }

    var bestSeconds: Int {
        sessions.map(\.seconds).max() ?? 0
    }

    var bestText: String {
        bestSeconds == 0 ? "--:--" : formatted(seconds: bestSeconds)
    }

    var clearCount: Int {
        sessions.filter(\.succeeded).count
    }

    var pressCount: Int {
        sessions.filter { !$0.succeeded }.count
    }

    var recentSessions: [SessionRecord] {
        Array(sessions.prefix(5))
    }

    var modeGoalText: String {
        if let target = selectedMode.targetSeconds {
            "\(formatted(seconds: target))まで耐える"
        } else {
            "押さずに退室すると記録"
        }
    }

    var progress: Double {
        guard let target = selectedMode.targetSeconds else {
            return min(1, Double(elapsedSeconds) / 180.0)
        }
        return min(1, Double(elapsedSeconds) / Double(target))
    }

    var rankTitle: String {
        switch bestSeconds {
        case 0..<30: "見習い"
        case 30..<60: "ボタン警戒員"
        case 60..<180: "鉄の指先"
        case 180..<300: "押さない達人"
        default: "絶対王者"
        }
    }

    var survivedText: String {
        let base = "\(elapsedText) 耐えました"
        guard let target = selectedMode.targetSeconds else { return base }
        return elapsedSeconds >= target ? "\(base)。目標達成です。" : base
    }

    var achievements: [(String, Bool)] {
        [
            ("30秒", bestSeconds >= 30),
            ("1分", bestSeconds >= 60),
            ("3分", bestSeconds >= 180),
            ("5勝", clearCount >= 5),
            ("10戦", sessions.count >= 10)
        ]
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

    func chooseMode(_ mode: Mode) {
        selectedMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: modeKey)
        start()
    }

    func pressForbiddenButton() {
        guard state == .resisting else { return }
        updateElapsed()
        state = .failed
        saveSession(succeeded: false)
        tickTask?.cancel()
        normalAudioTask?.cancel()
        audioPlayer.stopOneShot()
        audioPlayer.startPressedLoop()
    }

    func finishWithoutPressing() {
        guard state == .resisting else { return }
        updateElapsed()
        completeChallenge()
    }

    func resetProgress() {
        sessions = []
        persistSessions()
        start()
    }

    private func completeChallenge() {
        state = .survived
        saveSession(succeeded: true)
        tickTask?.cancel()
        normalAudioTask?.cancel()
        audioPlayer.stopAll()
    }

    private func startClock() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.25))
                guard let self else { return }
                self.updateElapsed()
                if let target = self.selectedMode.targetSeconds, self.elapsedSeconds >= target {
                    self.completeChallenge()
                    return
                }
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
        let scaled = Double(elapsedSeconds) * selectedMode.pressureScale
        pulseLevel = min(1, scaled / 180.0)
    }

    private func nextNormalDelay() -> Double {
        let scale = selectedMode == .chaos ? 0.62 : 1.0
        let range: ClosedRange<Double>
        switch elapsedSeconds {
        case 0..<30:
            range = 8...14
        case 30..<90:
            range = 5...9
        case 90..<180:
            range = 3...6
        default:
            range = 1.6...3.4
        }
        return Double.random(in: range) * scale
    }

    private func saveSession(succeeded: Bool) {
        let record = SessionRecord(
            id: UUID(),
            date: Date(),
            mode: selectedMode,
            seconds: elapsedSeconds,
            succeeded: succeeded
        )
        sessions.insert(record, at: 0)
        sessions = Array(sessions.prefix(30))
        persistSessions()
    }

    private func loadProgress() {
        if let rawMode = UserDefaults.standard.string(forKey: modeKey),
           let mode = Mode(rawValue: rawMode) {
            selectedMode = mode
        }
        guard let data = UserDefaults.standard.data(forKey: sessionsKey),
              let decoded = try? JSONDecoder().decode([SessionRecord].self, from: data) else {
            return
        }
        sessions = decoded
    }

    private func persistSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }

    func formatted(seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
