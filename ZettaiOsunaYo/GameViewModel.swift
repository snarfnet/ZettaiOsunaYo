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

    struct PressureEvent: Identifiable, Equatable {
        let id: String
        let title: String
        let detail: String
        let requiredAction: CalmAction
        let bonus: Int
    }

    struct ReactionCard: Identifiable, Equatable {
        let id: String
        let prompt: String
        let choices: [CalmAction]
        let correctAction: CalmAction
        let reward: Int
    }

    struct TrainingTip: Identifiable, Equatable {
        let id: String
        let title: String
        let detail: String
        let iconName: String
    }

    enum DefenseTileKind: String, Equatable {
        case safe
        case trap
        case bonus

        var title: String {
            switch self {
            case .safe: "回避"
            case .trap: "押すな"
            case .bonus: "冷静"
            }
        }

        var iconName: String {
            switch self {
            case .safe: "shield.fill"
            case .trap: "hand.tap.fill"
            case .bonus: "sparkles"
            }
        }
    }

    struct DefenseTile: Identifiable, Equatable {
        let id: Int
        let kind: DefenseTileKind
    }

    @Published private(set) var state: State = .resisting
    @Published private(set) var elapsedSeconds: Int = 0
    @Published private(set) var pulseLevel: Double = 0
    @Published private(set) var sessions: [SessionRecord] = []
    @Published private(set) var calmScore: Int = 0
    @Published private(set) var calmActionCooldown: Int = 0
    @Published private(set) var completedMissionIDs: Set<String> = []
    @Published private(set) var activeMissionID: String?
    @Published private(set) var activePressureEvent: PressureEvent?
    @Published private(set) var eventStreak: Int = 0
    @Published private(set) var bestEventStreak: Int = 0
    @Published private(set) var counteredEventIDs: Set<String> = []
    @Published private(set) var activeReactionCard: ReactionCard?
    @Published private(set) var solvedReactionCount: Int = 0
    @Published private(set) var wrongReactionCount: Int = 0
    @Published private(set) var reactionMessage = "状況を読んで、押さない選択を選ぶ"
    @Published private(set) var defenseTiles: [DefenseTile] = []
    @Published private(set) var defenseScore: Int = 0
    @Published private(set) var defenseCombo: Int = 0
    @Published private(set) var bestDefenseScore: Int = 0
    @Published private(set) var defenseLives: Int = 3
    @Published private(set) var defenseRound: Int = 1
    @Published private(set) var defenseMessage = "青い回避タイルと冷静タイルを処理。赤い罠は押さない。"
    @Published var selectedMode: Mode = .thirty

    private let audioPlayer: AudioTauntPlaying
    private var startedAt = Date()
    private var tickTask: Task<Void, Never>?
    private var normalAudioTask: Task<Void, Never>?
    private var pressureEventTask: Task<Void, Never>?
    private var lastCalmActionSecond = -99
    private let sessionsKey = "zettai.sessions.v2"
    private let modeKey = "zettai.selectedMode.v2"
    private let completedMissionsKey = "zettai.completedMissions.v1"
    private let counteredEventsKey = "zettai.counteredEvents.v1"
    private let bestEventStreakKey = "zettai.bestEventStreak.v1"
    private let solvedReactionCountKey = "zettai.solvedReactionCount.v1"
    private let wrongReactionCountKey = "zettai.wrongReactionCount.v1"
    private let bestDefenseScoreKey = "zettai.bestDefenseScore.v1"

    init(audioPlayer: AudioTauntPlaying) {
        self.audioPlayer = audioPlayer
        loadProgress()
        start()
    }

    deinit {
        tickTask?.cancel()
        normalAudioTask?.cancel()
        pressureEventTask?.cancel()
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

    var contentSummary: [(String, String, String)] {
        [
            ("任務", "\(missions.count)", "段階チャレンジ"),
            ("誘惑", "\(reactionCards.count)", "3択カード"),
            ("防衛", "\(bestDefenseScore)", "最高スコア"),
            ("イベント", "\(pressureEvents.count)", "緊急対処"),
            ("実績", "\(achievements.count)", "称号と記録")
        ]
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
            ChallengeMission(id: "endurance-180", title: "3分の静寂", detail: "限界耐久で3分。称号更新を狙う。", mode: .endurance, targetSeconds: 180, rewardTitle: "押さない達人"),
            ChallengeMission(id: "quick-reset", title: "リセット我慢", detail: "失敗後すぐ押したい気持ちを15秒止める。", mode: .thirty, targetSeconds: 15, rewardTitle: "仕切り直し上手"),
            ChallengeMission(id: "silent-40", title: "無音の40秒", detail: "静かな間こそ危ない。画面を見すぎない。", mode: .classic, targetSeconds: 40, rewardTitle: "沈黙の番人"),
            ChallengeMission(id: "blink-55", title: "点滅55秒", detail: "赤い変化に釣られず、呼吸で流す。", mode: .classic, targetSeconds: 55, rewardTitle: "赤信号スルー"),
            ChallengeMission(id: "count-70", title: "数えて70秒", detail: "3秒数える行動を軸に耐える。", mode: .endurance, targetSeconds: 70, rewardTitle: "カウント職人"),
            ChallengeMission(id: "friend-80", title: "友だちの煽り", detail: "人に見られているつもりで80秒。", mode: .chaos, targetSeconds: 80, rewardTitle: "挑発無効"),
            ChallengeMission(id: "focus-100", title: "視線外し100秒", detail: "目をそらす行動を使って長めに耐える。", mode: .endurance, targetSeconds: 100, rewardTitle: "視線コントロール"),
            ChallengeMission(id: "calm-120", title: "冷静120", detail: "冷静ポイントを稼ぎながら2分。", mode: .endurance, targetSeconds: 120, rewardTitle: "心拍管理人"),
            ChallengeMission(id: "no-action-30", title: "無操作30秒", detail: "あえて行動ボタンも使わず30秒。", mode: .thirty, targetSeconds: 30, rewardTitle: "手ぶら勝利"),
            ChallengeMission(id: "late-game-150", title: "終盤150秒", detail: "後半の強い圧に備えて粘る。", mode: .endurance, targetSeconds: 150, rewardTitle: "終盤耐性"),
            ChallengeMission(id: "chaos-180", title: "煽り3分", detail: "煽り強めで3分。かなりしぶとい人向け。", mode: .chaos, targetSeconds: 180, rewardTitle: "挑発の壁"),
            ChallengeMission(id: "classic-240", title: "4分の赤", detail: "クラシックで4分。ボタンと同居する。", mode: .classic, targetSeconds: 240, rewardTitle: "赤の同居人"),
            ChallengeMission(id: "endurance-300", title: "5分耐久", detail: "長期戦の到達点。集中を切らさない。", mode: .endurance, targetSeconds: 300, rewardTitle: "絶対王者")
        ]
    }

    var pressureEvents: [PressureEvent] {
        [
            PressureEvent(id: "finger-close", title: "指が近い", detail: "画面から目を外して誘惑を切る", requiredAction: .lookAway, bonus: 14),
            PressureEvent(id: "voice-bait", title: "今なら押せる", detail: "3秒数えて反射を止める", requiredAction: .count, bonus: 16),
            PressureEvent(id: "red-flash", title: "赤い点滅", detail: "深呼吸でゲージを落ち着かせる", requiredAction: .breathe, bonus: 12),
            PressureEvent(id: "silent-gap", title: "静かすぎる", detail: "3秒数えて次の煽りに備える", requiredAction: .count, bonus: 15),
            PressureEvent(id: "button-grow", title: "ボタン巨大化", detail: "目をそらして存在感を下げる", requiredAction: .lookAway, bonus: 13),
            PressureEvent(id: "heartbeat", title: "鼓動が早い", detail: "深呼吸で手を止める", requiredAction: .breathe, bonus: 18),
            PressureEvent(id: "tiny-button", title: "押しやすいサイズ", detail: "小さい罠は数えて見送る", requiredAction: .count, bonus: 12),
            PressureEvent(id: "near-clear", title: "あと少し", detail: "油断しそうな終盤は目をそらす", requiredAction: .lookAway, bonus: 17),
            PressureEvent(id: "double-voice", title: "二重の声", detail: "深呼吸で音の圧を下げる", requiredAction: .breathe, bonus: 15),
            PressureEvent(id: "fake-finish", title: "終わった気がする", detail: "3秒数えて画面を確認する", requiredAction: .count, bonus: 14),
            PressureEvent(id: "red-shadow", title: "赤い影", detail: "視線を外して反射を切る", requiredAction: .lookAway, bonus: 16),
            PressureEvent(id: "fast-pulse", title: "高速パルス", detail: "深呼吸でテンポを戻す", requiredAction: .breathe, bonus: 19),
            PressureEvent(id: "tap-memory", title: "押した記憶", detail: "数えて指の癖を止める", requiredAction: .count, bonus: 13),
            PressureEvent(id: "screen-glare", title: "画面が光る", detail: "目をそらして光を逃がす", requiredAction: .lookAway, bonus: 14),
            PressureEvent(id: "last-second", title: "最後の1秒感", detail: "深呼吸で早押しを防ぐ", requiredAction: .breathe, bonus: 20),
            PressureEvent(id: "thumb-warm", title: "親指が熱い", detail: "3秒数えて手を離す", requiredAction: .count, bonus: 18)
        ]
    }

    var reactionCards: [ReactionCard] {
        [
            ReactionCard(id: "fake-safe", prompt: "ボタンが小さくなった。今なら押しても平気そう。", choices: [.count, .breathe, .lookAway], correctAction: .count, reward: 20),
            ReactionCard(id: "voice-order", prompt: "音声が『押すな』を連呼。逆に押したくなってきた。", choices: [.breathe, .count, .lookAway], correctAction: .breathe, reward: 18),
            ReactionCard(id: "red-pulse", prompt: "赤い光が強く点滅。画面から目が離れない。", choices: [.lookAway, .breathe, .count], correctAction: .lookAway, reward: 22),
            ReactionCard(id: "friend-dare", prompt: "友だちが『ここで押せる？』と煽ってきた。", choices: [.count, .lookAway, .breathe], correctAction: .count, reward: 17),
            ReactionCard(id: "silent-room", prompt: "急に静かになった。次の音に反応しそう。", choices: [.breathe, .lookAway, .count], correctAction: .breathe, reward: 16),
            ReactionCard(id: "thumb-hover", prompt: "親指がボタンの上で止まっている。", choices: [.lookAway, .count, .breathe], correctAction: .lookAway, reward: 21),
            ReactionCard(id: "almost-clear", prompt: "残り数秒。勝った気がして指が動きそう。", choices: [.breathe, .count, .lookAway], correctAction: .count, reward: 19),
            ReactionCard(id: "small-button", prompt: "ボタンが小さく見える。危険度が低そうに見える。", choices: [.count, .lookAway, .breathe], correctAction: .count, reward: 18),
            ReactionCard(id: "big-button", prompt: "ボタンが画面いっぱいに迫ってくる。", choices: [.lookAway, .breathe, .count], correctAction: .lookAway, reward: 24),
            ReactionCard(id: "fake-rule", prompt: "『一回だけならセーフ』という文字が出た。", choices: [.count, .breathe, .lookAway], correctAction: .count, reward: 23),
            ReactionCard(id: "fast-heart", prompt: "心拍が早くなり、すぐ決めたくなる。", choices: [.breathe, .lookAway, .count], correctAction: .breathe, reward: 20),
            ReactionCard(id: "red-afterimage", prompt: "赤い残像が目に残っている。", choices: [.lookAway, .count, .breathe], correctAction: .lookAway, reward: 19),
            ReactionCard(id: "score-greed", prompt: "押したら隠しボーナスがありそうに見える。", choices: [.count, .lookAway, .breathe], correctAction: .count, reward: 22),
            ReactionCard(id: "quiet-win", prompt: "何も起きない。退屈で押したくなってきた。", choices: [.breathe, .count, .lookAway], correctAction: .breathe, reward: 17),
            ReactionCard(id: "voice-soft", prompt: "優しい声で『押してもいいよ』と言われた。", choices: [.count, .breathe, .lookAway], correctAction: .count, reward: 21),
            ReactionCard(id: "finger-slip", prompt: "指が滑ってボタンに近づいた。", choices: [.lookAway, .count, .breathe], correctAction: .lookAway, reward: 20),
            ReactionCard(id: "screen-freeze", prompt: "画面が止まったように見える。触って確認したい。", choices: [.count, .breathe, .lookAway], correctAction: .count, reward: 18),
            ReactionCard(id: "friend-laugh", prompt: "横で笑われた。焦って何かしたくなる。", choices: [.breathe, .count, .lookAway], correctAction: .breathe, reward: 19),
            ReactionCard(id: "timer-hide", prompt: "タイマーが隠れた。あと何秒か気になる。", choices: [.count, .lookAway, .breathe], correctAction: .count, reward: 16),
            ReactionCard(id: "red-ring", prompt: "赤いリングが広がって、中央を見てしまう。", choices: [.lookAway, .breathe, .count], correctAction: .lookAway, reward: 23),
            ReactionCard(id: "almost-touch", prompt: "押していないのに、押した感覚だけがある。", choices: [.breathe, .count, .lookAway], correctAction: .breathe, reward: 18),
            ReactionCard(id: "new-record", prompt: "新記録が近い。ここで欲を出しそう。", choices: [.count, .lookAway, .breathe], correctAction: .count, reward: 25),
            ReactionCard(id: "advice-bait", prompt: "攻略メモが『押して確認』と言っている気がする。", choices: [.lookAway, .breathe, .count], correctAction: .lookAway, reward: 22),
            ReactionCard(id: "double-tap", prompt: "二回押せば逆に勝ち、という謎の理屈が浮かんだ。", choices: [.breathe, .count, .lookAway], correctAction: .breathe, reward: 24)
        ]
    }

    var featuredReactionCards: [ReactionCard] {
        Array(reactionCards.prefix(12))
    }

    var trainingTips: [TrainingTip] {
        [
            TrainingTip(id: "breathe-first", title: "最初は深呼吸", detail: "緊張ゲージが上がる前に呼吸で余裕を作る。", iconName: "wind"),
            TrainingTip(id: "look-away", title: "見すぎない", detail: "赤いボタンを注視すると押したくなる。", iconName: "eye.slash.fill"),
            TrainingTip(id: "count-three", title: "3秒だけ待つ", detail: "反射で押しそうな時は数える。", iconName: "timer"),
            TrainingTip(id: "mission-order", title: "短い任務から", detail: "10秒、30秒、45秒の順で慣れる。", iconName: "list.number"),
            TrainingTip(id: "chaos-later", title: "煽り強めは後で", detail: "記録を作ってから挑むと続きやすい。", iconName: "flame.fill"),
            TrainingTip(id: "record-mood", title: "失敗も記録", detail: "押した回数も履歴に残るので次に活かす。", iconName: "clock.arrow.circlepath")
        ]
    }

    var dailyTrainingMissions: [ChallengeMission] {
        let all = missions
        guard !all.isEmpty else { return [] }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return (0..<4).map { all[(day + $0 * 2) % all.count] }
    }

    var dailyTrainingProgressText: String {
        let done = dailyTrainingMissions.filter { completedMissionIDs.contains($0.id) }.count
        return "\(done)/\(dailyTrainingMissions.count)"
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

    var counteredEventCount: Int {
        counteredEventIDs.count
    }

    var reactionScoreText: String {
        "\(solvedReactionCount)問"
    }

    var modeGoalText: String {
        if let mission = activeMission {
            return "\(mission.title): \(formatted(seconds: mission.targetSeconds))まで耐える"
        }
        if let target = selectedMode.targetSeconds {
            return "\(formatted(seconds: target))まで耐える"
        } else {
            return "押さずに退室すると記録"
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
            ("全任務", completedMissionCount >= missions.count),
            ("対処3", counteredEventCount >= 3),
            ("コンボ5", bestEventStreak >= 5),
            ("判断5", solvedReactionCount >= 5),
            ("判断20", solvedReactionCount >= 20),
            ("任務12", completedMissionCount >= 12),
            ("対処10", counteredEventCount >= 10),
            ("冷静100", sessions.contains { ($0.calmScore ?? 0) >= 100 }),
            ("5分", bestSeconds >= 300),
            ("防衛50", bestDefenseScore >= 50),
            ("防衛100", bestDefenseScore >= 100)
        ]
    }

    func start() {
        state = .resisting
        startedAt = Date()
        elapsedSeconds = 0
        pulseLevel = 0
        calmScore = 0
        calmActionCooldown = 0
        activePressureEvent = nil
        eventStreak = 0
        activeReactionCard = reactionCards.randomElement()
        reactionMessage = "状況を読んで、押さない選択を選ぶ"
        defenseScore = 0
        defenseCombo = 0
        defenseLives = 3
        defenseRound = 1
        defenseMessage = "青い回避タイルと冷静タイルを処理。赤い罠は押さない。"
        refreshDefenseBoard()
        lastCalmActionSecond = -99
        audioPlayer.stopLoop()
        startClock()
        startNormalAudioLoop()
        startPressureEventLoop()
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
        if let event = activePressureEvent, event.requiredAction == action {
            calmScore += action.points + event.bonus
            eventStreak += 1
            bestEventStreak = max(bestEventStreak, eventStreak)
            counteredEventIDs.insert(event.id)
            activePressureEvent = nil
            persistCounteredEvents()
        } else {
            calmScore += action.points
            if activePressureEvent != nil {
                eventStreak = 0
            }
        }
        updateElapsed()
    }

    func answerReaction(_ action: CalmAction) {
        guard let card = activeReactionCard, state == .resisting else { return }
        if action == card.correctAction {
            solvedReactionCount += 1
            calmScore += card.reward
            eventStreak += 1
            bestEventStreak = max(bestEventStreak, eventStreak)
            reactionMessage = "正解。\(action.title)で誘惑を切りました"
        } else {
            wrongReactionCount += 1
            eventStreak = 0
            pulseLevel = min(1, pulseLevel + 0.16)
            reactionMessage = "惜しい。今回は\(card.correctAction.title)が安全でした"
        }
        persistReactionStats()
        activeReactionCard = nextReactionCard(after: card)
    }

    func selectReactionCard(_ card: ReactionCard) {
        guard state == .resisting else { return }
        activeReactionCard = card
        reactionMessage = "この誘惑への対処を選んでください"
    }

    func tapDefenseTile(_ tile: DefenseTile) {
        guard state == .resisting else { return }
        switch tile.kind {
        case .safe:
            defenseScore += 8 + defenseCombo
            defenseCombo += 1
            calmScore += 2
            defenseMessage = "回避成功。赤い罠には触らない。"
        case .bonus:
            defenseScore += 15 + defenseCombo
            defenseCombo += 2
            calmScore += 6
            pulseLevel = max(0, pulseLevel - 0.08)
            defenseMessage = "冷静ボーナス。緊張を少し下げました。"
        case .trap:
            defenseLives -= 1
            defenseCombo = 0
            pulseLevel = min(1, pulseLevel + 0.2)
            defenseMessage = defenseLives > 0 ? "赤い罠です。残り\(defenseLives)回。" : "罠を押しました。防衛失敗。"
            if defenseLives <= 0 {
                bestDefenseScore = max(bestDefenseScore, defenseScore)
                persistDefenseStats()
                pressForbiddenButton()
                return
            }
        }
        defenseRound += 1
        bestDefenseScore = max(bestDefenseScore, defenseScore)
        persistDefenseStats()
        refreshDefenseBoard()
    }

    func pressForbiddenButton() {
        guard state == .resisting else { return }
        updateElapsed()
        state = .failed
        saveSession(succeeded: false)
        tickTask?.cancel()
        normalAudioTask?.cancel()
        pressureEventTask?.cancel()
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
        counteredEventIDs = []
        bestEventStreak = 0
        solvedReactionCount = 0
        wrongReactionCount = 0
        bestDefenseScore = 0
        persistSessions()
        persistCompletedMissions()
        persistCounteredEvents()
        persistReactionStats()
        persistDefenseStats()
        start()
    }

    func applyScreenshotPreset(_ preset: String) {
        tickTask?.cancel()
        normalAudioTask?.cancel()
        pressureEventTask?.cancel()
        audioPlayer.stopAll()

        let sampleSessions = [
            SessionRecord(id: UUID(), date: Date(), mode: .thirty, seconds: 30, succeeded: true, calmScore: 44, missionTitle: "30秒の壁"),
            SessionRecord(id: UUID(), date: Date(), mode: .classic, seconds: 64, succeeded: true, calmScore: 57, missionTitle: "冷静キープ"),
            SessionRecord(id: UUID(), date: Date(), mode: .chaos, seconds: 24, succeeded: false, calmScore: 18, missionTitle: "煽り強め入門")
        ]
        sessions = sampleSessions
        completedMissionIDs = Set(["first-10", "first-30", "calm-45", "chaos-45", "minute", "endurance-90", "quick-reset", "silent-40"])
        counteredEventIDs = Set(["finger-close", "voice-bait", "red-flash", "heartbeat", "near-clear", "double-voice"])
        solvedReactionCount = 18
        wrongReactionCount = 3
        defenseScore = 86
        defenseCombo = 7
        bestDefenseScore = 142
        defenseLives = 3
        defenseRound = 9
        defenseTiles = [
            DefenseTile(id: 0, kind: .safe), DefenseTile(id: 1, kind: .trap), DefenseTile(id: 2, kind: .safe),
            DefenseTile(id: 3, kind: .bonus), DefenseTile(id: 4, kind: .safe), DefenseTile(id: 5, kind: .trap),
            DefenseTile(id: 6, kind: .safe), DefenseTile(id: 7, kind: .bonus), DefenseTile(id: 8, kind: .safe)
        ]
        defenseMessage = "安全タイルを連続処理中。赤い罠は避ける。"
        bestEventStreak = 5
        activeMissionID = "first-30"
        selectedMode = .thirty
        activeReactionCard = reactionCards.first { $0.id == "red-pulse" } ?? reactionCards.first
        activePressureEvent = pressureEvents.first { $0.id == "red-flash" }
        reactionMessage = "正しい行動を選ぶとコンボが伸びます"

        switch preset {
        case "missions":
            state = .resisting
            elapsedSeconds = 8
            calmScore = 21
            pulseLevel = 0.22
            activeMissionID = "chaos-120"
        case "actions":
            state = .resisting
            elapsedSeconds = 64
            calmScore = 56
            pulseLevel = 0.55
            activeReactionCard = reactionCards.first { $0.id == "thumb-hover" } ?? reactionCards.first
            activePressureEvent = pressureEvents.first { $0.id == "finger-close" }
        case "failed":
            state = .failed
            elapsedSeconds = 24
            calmScore = 18
            pulseLevel = 0.86
        case "survived":
            state = .survived
            elapsedSeconds = 180
            calmScore = 91
            pulseLevel = 0.18
        default:
            state = .resisting
            elapsedSeconds = 18
            calmScore = 24
            pulseLevel = 0.42
        }
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
        pressureEventTask?.cancel()
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

    private func startPressureEventLoop() {
        pressureEventTask?.cancel()
        pressureEventTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let baseDelay = self.selectedMode == .chaos ? 7.0 : 11.0
                try? await Task.sleep(for: .seconds(baseDelay + Double.random(in: 0...5)))
                guard !Task.isCancelled, self.state == .resisting else { return }
                self.activePressureEvent = self.pressureEvents.randomElement()
            }
        }
    }

    private func nextReactionCard(after card: ReactionCard) -> ReactionCard? {
        let candidates = reactionCards.filter { $0.id != card.id }
        return candidates.randomElement() ?? reactionCards.randomElement()
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
        if let countered = UserDefaults.standard.array(forKey: counteredEventsKey) as? [String] {
            counteredEventIDs = Set(countered)
        }
        bestEventStreak = UserDefaults.standard.integer(forKey: bestEventStreakKey)
        solvedReactionCount = UserDefaults.standard.integer(forKey: solvedReactionCountKey)
        wrongReactionCount = UserDefaults.standard.integer(forKey: wrongReactionCountKey)
        bestDefenseScore = UserDefaults.standard.integer(forKey: bestDefenseScoreKey)
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

    private func persistCounteredEvents() {
        UserDefaults.standard.set(Array(counteredEventIDs), forKey: counteredEventsKey)
        UserDefaults.standard.set(bestEventStreak, forKey: bestEventStreakKey)
    }

    private func persistReactionStats() {
        UserDefaults.standard.set(solvedReactionCount, forKey: solvedReactionCountKey)
        UserDefaults.standard.set(wrongReactionCount, forKey: wrongReactionCountKey)
        UserDefaults.standard.set(bestEventStreak, forKey: bestEventStreakKey)
    }

    private func persistDefenseStats() {
        UserDefaults.standard.set(bestDefenseScore, forKey: bestDefenseScoreKey)
    }

    private func refreshDefenseBoard() {
        let trapCount = min(4, 1 + defenseRound / 4)
        let bonusIndex = Int.random(in: 0..<9)
        var trapIndices = Set<Int>()
        while trapIndices.count < trapCount {
            let index = Int.random(in: 0..<9)
            if index != bonusIndex {
                trapIndices.insert(index)
            }
        }
        defenseTiles = (0..<9).map { index in
            let kind: DefenseTileKind
            if index == bonusIndex {
                kind = .bonus
            } else if trapIndices.contains(index) {
                kind = .trap
            } else {
                kind = .safe
            }
            return DefenseTile(id: defenseRound * 10 + index, kind: kind)
        }
    }

    func formatted(seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
