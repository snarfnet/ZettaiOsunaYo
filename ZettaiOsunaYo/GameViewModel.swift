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
        let calmScore: Int?
        let missionTitle: String?

        var resultText: String {
            succeeded ? "耐え抜いた" : "押した"
        }
    }

    struct ChallengeMission: Identifiable, Equatable {
        let id: String
        let title: String
        let detail: String
        let mode: Mode
        let targetSeconds: Int
        let rewardTitle: String
    }

    enum CalmAction: String, CaseIterable, Identifiable {
        case breathe
        case lookAway
        case count

        var id: String { rawValue }

        var title: String {
            switch self {
            case .breathe: "深呼吸"
            case .lookAway: "目をそらす"
            case .count: "3秒数える"
            }
        }

        var iconName: String {
            switch self {
            case .breathe: "wind"
            case .lookAway: "eye.slash.fill"
            case .count: "timer"
            }
        }

        var points: Int {
            switch self {
            case .breathe: 3
            case .lookAway: 4
            case .count: 5
            }
        }
    }

    @Published private(set) var state: State = .resisting
    @Published private(set) var elapsedSeconds: Int = 0
    @Published private(set) var pulseLevel: Double = 0
    @Published private(set) var sessions: [SessionRecord] = []
    @Published private(set) var calmScore: Int = 0
    @Published private(set) var calmActionCooldown: Int = 0
    @Published private(set) var completedMissionIDs: Set<String> = []
    @Published private(set) var activeMissionID: String?
    @Published var selectedMode: Mode = .thirty

    private let audioPlayer: AudioTauntPlaying
    private var startedAt = Date()
    private var tickTask: Task<Void, Never>?
    private var normalAudioTask: Task<Void, Never>?
    private var lastCalmActionSecond = -99
    private let sessionsKey = "zettai.sessions.v2"
    private let modeKey = "zettai.selectedMode.v2"
    private let completedMissionsKey = "zettai.completedMissions.v1"

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

    var missions: [ChallengeMission] {
        [
            ChallengeMission(id: "first-10", title: "初級 10秒", detail: "まずは短く。赤いボタンを見ても動かない。", mode: .thirty, targetSeconds: 10, rewardTitle: "冷静な親指"),
            ChallengeMission(id: "first-30", title: "30秒の壁", detail: "煽りを聞きながら30秒耐える。", mode: .thirty, targetSeconds: 30, rewardTitle: "ボタン警戒員"),
            ChallengeMission(id: "calm-45", title: "冷静キープ", detail: "押さないアクションを使いながら45秒。", mode: .classic, targetSeconds: 45, rewardTitle: "深呼吸マスター"),
            ChallengeMission(id: "chaos-45", title: "煽り強め入門", detail: "圧が早く上がるモードで45秒。", mode: .chaos, targetSeconds: 45, rewardTitle: "耳を貸さない人"),
            ChallengeMission(id: "minute", title: "1分耐久", detail: "1分を越えると、ボタンの存在感が変わる。", mode: .classic, targetSeconds: 60, rewardTitle: "鉄の指先"),
            ChallengeMission(id: "endurance-90", title: "長期戦 90秒", detail: "急がず、押さず、淡々と耐える。", mode: .endurance, targetSeconds: 90, rewardTitle: "退室の達人"),
            ChallengeMission(id: "chaos-120", title: "赤い誘惑", detail: "煽り強めで2分。ここからが本番。", mode: .chaos, targetSeconds: 120, rewardTitle: "不動の人"),
            ChallengeMission(id: "endurance-180", title: "3分の静寂", detail: "限界耐久で3分。称号更新を狙う。", mode: .endurance, targetSeconds: 180, rewardTitle: "押さない達人")
        ]
    }

    var activeMission: ChallengeMission? {
        guard let activeMissionID else { return nil }
        return missions.first { $0.id == activeMissionID }
    }

    var completedMissionCount: Int {
        completedMissionIDs.count
    }

    var calmText: String {
        "\(calmScore) pt"
    }

    var canUseCalmAction: Bool {
        calmActionCooldown == 0 && state == .resisting
    }

    var modeGoalText: String {
        if let mission = activeMission {
            return "\(mission.title): \(formatted(seconds: mission.targetSeconds))まで耐える"
        }
        if let target = selectedMode.targetSeconds {
            "\(formatted(seconds: target))まで耐える"
        } else {
            "押さずに退室すると記録"
        }
    }

    var progress: Double {
        guard let target = currentTargetSeconds else {
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
            ("10戦", sessions.count >= 10),
            ("冷静50", sessions.contains { ($0.calmScore ?? 0) >= 50 }),
            ("任務4", completedMissionCount >= 4),
            ("全任務", completedMissionCount >= missions.count)
        ]
    }

    func start() {
        state = .resisting
        startedAt = Date()
        elapsedSeconds = 0
        pulseLevel = 0
        calmScore = 0
        calmActionCooldown = 0
        lastCalmActionSecond = -99
        audioPlayer.stopLoop()
        startClock()
        startNormalAudioLoop()
    }

    func chooseMode(_ mode: Mode) {
        activeMissionID = nil
        selectedMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: modeKey)
        start()
    }

    func startMission(_ mission: ChallengeMission) {
        activeMissionID = mission.id
        selectedMode = mission.mode
        UserDefaults.standard.set(mission.mode.rawValue, forKey: modeKey)
        start()
    }

    func performCalmAction(_ action: CalmAction) {
        guard canUseCalmAction else { return }
        lastCalmActionSecond = elapsedSeconds
        calmScore += action.points
        updateElapsed()
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
        completedMissionIDs = []
        persistSessions()
        persistCompletedMissions()
        start()
    }

    private func completeChallenge() {
        state = .survived
        if let activeMission, elapsedSeconds >= activeMission.targetSeconds {
            completedMissionIDs.insert(activeMission.id)
            persistCompletedMissions()
        }
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
                if let target = self.currentTargetSeconds, self.elapsedSeconds >= target {
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
        calmActionCooldown = max(0, 6 - (elapsedSeconds - lastCalmActionSecond))
        let scaled = Double(elapsedSeconds) * selectedMode.pressureScale
        let calmReduction = Double(calmScore) * 3.0
        pulseLevel = min(1, max(0, scaled - calmReduction) / 180.0)
    }

    private var currentTargetSeconds: Int? {
        activeMission?.targetSeconds ?? selectedMode.targetSeconds
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
            succeeded: succeeded,
            calmScore: calmScore,
            missionTitle: activeMission?.title
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
        if let completed = UserDefaults.standard.array(forKey: completedMissionsKey) as? [String] {
            completedMissionIDs = Set(completed)
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

    private func persistCompletedMissions() {
        UserDefaults.standard.set(Array(completedMissionIDs), forKey: completedMissionsKey)
    }

    func formatted(seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
