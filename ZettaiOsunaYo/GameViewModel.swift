import Foundation

@MainActor
final class GameViewModel: ObservableObject {
    enum State: Equatable {
        case resisting
        case failed
        case survived
    }

    enum FocusTileKind: String, CaseIterable, Equatable {
        case target
        case decoy
        case bonus

        var title: String {
            switch self {
            case .target: "MATCH"
            case .decoy: "SKIP"
            case .bonus: "BONUS"
            }
        }

        var iconName: String {
            switch self {
            case .target: "scope"
            case .decoy: "xmark"
            case .bonus: "sparkles"
            }
        }
    }

    enum PatternAction: String, CaseIterable, Identifiable {
        case scan
        case count
        case hold
        case switchLane

        var id: String { rawValue }

        var title: String {
            switch self {
            case .scan: "Scan"
            case .count: "Count"
            case .hold: "Hold"
            case .switchLane: "Switch"
            }
        }

        var iconName: String {
            switch self {
            case .scan: "eye.fill"
            case .count: "number"
            case .hold: "pause.fill"
            case .switchLane: "arrow.left.arrow.right"
            }
        }
    }

    struct FocusTile: Identifiable, Equatable {
        let id: Int
        let kind: FocusTileKind
        let label: String
    }

    struct ArcadeMode: Identifiable, Equatable {
        let id: String
        let title: String
        let detail: String
        let iconName: String
    }

    struct Mission: Identifiable, Equatable {
        let id: String
        let title: String
        let detail: String
        let target: Int
        let reward: String
    }

    struct ScenarioCard: Identifiable, Equatable {
        let id: String
        let prompt: String
        let choices: [PatternAction]
        let answer: PatternAction
        let reward: Int
    }

    struct TrainingTip: Identifiable, Equatable {
        let id: String
        let title: String
        let detail: String
        let iconName: String
    }

    struct SessionRecord: Identifiable, Codable, Equatable {
        let id: UUID
        let date: Date
        let modeName: String
        let score: Int
        let note: String
    }

    @Published private(set) var state: State = .resisting
    @Published private(set) var focusTiles: [FocusTile] = []
    @Published private(set) var focusScore = 0
    @Published private(set) var focusCombo = 0
    @Published private(set) var focusLives = 3
    @Published private(set) var focusRound = 1
    @Published private(set) var bestFocusScore = 0
    @Published private(set) var focusMessage = "Tap MATCH tiles, skip decoys, and keep the combo alive."

    @Published private(set) var patternSequence: [PatternAction] = []
    @Published private(set) var patternIndex = 0
    @Published private(set) var patternScore = 0
    @Published private(set) var patternRound = 1
    @Published private(set) var bestPatternScore = 0
    @Published private(set) var patternMessage = "Memorize the shown order, then repeat it."

    @Published private(set) var activeScenario: ScenarioCard?
    @Published private(set) var scenarioScore = 0
    @Published private(set) var solvedScenarioCount = 0
    @Published private(set) var missedScenarioCount = 0
    @Published private(set) var scenarioMessage = "Read the situation and choose the best response."

    @Published private(set) var completedMissionIDs: Set<String> = []
    @Published private(set) var sessions: [SessionRecord] = []

    private let focusKey = "impulse.bestFocus.v1"
    private let patternKey = "impulse.bestPattern.v1"
    private let scenarioKey = "impulse.scenarioScore.v1"
    private let solvedKey = "impulse.solvedScenario.v1"
    private let missedKey = "impulse.missedScenario.v1"
    private let missionsKey = "impulse.completedMissions.v1"
    private let sessionsKey = "impulse.sessions.v1"

    init(audioPlayer: AudioTauntPlaying) {
        _ = audioPlayer
        loadProgress()
        start()
    }

    var contentSummary: [(String, String, String)] {
        [
            ("Modes", "\(arcadeModes.count)", "play styles"),
            ("Missions", "\(missions.count)", "goals"),
            ("Scenarios", "\(scenarioCards.count)", "cards"),
            ("Tips", "\(trainingTips.count)", "notes"),
            ("Records", "\(sessions.count)", "runs"),
            ("Badges", "\(achievements.count)", "targets")
        ]
    }

    var arcadeModes: [ArcadeMode] {
        [
            ArcadeMode(id: "focus", title: "Focus Grid", detail: "Find matching tiles under pressure.", iconName: "square.grid.3x3.fill"),
            ArcadeMode(id: "pattern", title: "Pattern Relay", detail: "Repeat longer action chains.", iconName: "arrow.triangle.branch"),
            ArcadeMode(id: "scenario", title: "Scenario Cards", detail: "Choose the right response.", iconName: "rectangle.stack.fill"),
            ArcadeMode(id: "daily", title: "Daily Set", detail: "Clear rotating goals.", iconName: "calendar")
        ]
    }

    var missions: [Mission] {
        [
            Mission(id: "focus-40", title: "Focus 40", detail: "Score 40 in Focus Grid.", target: 40, reward: "Steady Eye"),
            Mission(id: "focus-80", title: "Focus 80", detail: "Score 80 in Focus Grid.", target: 80, reward: "Tile Reader"),
            Mission(id: "focus-120", title: "Focus 120", detail: "Score 120 in Focus Grid.", target: 120, reward: "Grid Captain"),
            Mission(id: "combo-5", title: "Combo 5", detail: "Build a 5 chain in Focus Grid.", target: 5, reward: "Chain Starter"),
            Mission(id: "combo-10", title: "Combo 10", detail: "Build a 10 chain in Focus Grid.", target: 10, reward: "Clean Sweep"),
            Mission(id: "pattern-40", title: "Pattern 40", detail: "Score 40 in Pattern Relay.", target: 40, reward: "Memory Warmup"),
            Mission(id: "pattern-80", title: "Pattern 80", detail: "Score 80 in Pattern Relay.", target: 80, reward: "Sequence Pilot"),
            Mission(id: "pattern-120", title: "Pattern 120", detail: "Score 120 in Pattern Relay.", target: 120, reward: "Signal Keeper"),
            Mission(id: "round-4", title: "Round 4", detail: "Reach Pattern Relay round 4.", target: 4, reward: "Pattern Climber"),
            Mission(id: "round-8", title: "Round 8", detail: "Reach Pattern Relay round 8.", target: 8, reward: "Long Memory"),
            Mission(id: "scenario-5", title: "5 Correct", detail: "Solve 5 scenario cards.", target: 5, reward: "Quick Judge"),
            Mission(id: "scenario-12", title: "12 Correct", detail: "Solve 12 scenario cards.", target: 12, reward: "Calm Judge"),
            Mission(id: "scenario-24", title: "24 Correct", detail: "Solve 24 scenario cards.", target: 24, reward: "Case Master"),
            Mission(id: "total-150", title: "Total 150", detail: "Reach 150 combined points.", target: 150, reward: "Arcade Regular"),
            Mission(id: "total-300", title: "Total 300", detail: "Reach 300 combined points.", target: 300, reward: "Arcade Pro"),
            Mission(id: "total-500", title: "Total 500", detail: "Reach 500 combined points.", target: 500, reward: "Impulse Analyst"),
            Mission(id: "no-miss-3", title: "Clean Start", detail: "Finish 3 correct actions in a row.", target: 3, reward: "No Miss"),
            Mission(id: "cards-10", title: "Card Tour", detail: "Try 10 different scenario cards.", target: 10, reward: "Deck Walker"),
            Mission(id: "daily-1", title: "Daily One", detail: "Clear one daily mission.", target: 1, reward: "Today Started"),
            Mission(id: "daily-4", title: "Daily Four", detail: "Clear the daily set.", target: 4, reward: "Daily Clear"),
            Mission(id: "records-3", title: "Three Runs", detail: "Save 3 records.", target: 3, reward: "Recorder"),
            Mission(id: "records-10", title: "Ten Runs", detail: "Save 10 records.", target: 10, reward: "Archivist"),
            Mission(id: "best-200", title: "Best 200", detail: "Set any best score above 200.", target: 200, reward: "Peak Run"),
            Mission(id: "all-round", title: "All Round", detail: "Play all four sections.", target: 4, reward: "Full Tour")
        ]
    }

    var scenarioCards: [ScenarioCard] {
        [
            ScenarioCard(id: "noisy-room", prompt: "The screen is busy and several targets appear at once.", choices: [.scan, .count, .hold], answer: .scan, reward: 14),
            ScenarioCard(id: "fast-choice", prompt: "A quick choice appears before you have checked the label.", choices: [.hold, .switchLane, .count], answer: .hold, reward: 16),
            ScenarioCard(id: "many-numbers", prompt: "A number pattern is shown with one missing step.", choices: [.count, .scan, .switchLane], answer: .count, reward: 18),
            ScenarioCard(id: "lane-change", prompt: "The target moves from the left lane to the right lane.", choices: [.switchLane, .hold, .scan], answer: .switchLane, reward: 18),
            ScenarioCard(id: "blurred-icon", prompt: "An icon is hard to read, but the surrounding labels are clear.", choices: [.scan, .hold, .count], answer: .scan, reward: 15),
            ScenarioCard(id: "false-start", prompt: "The first tile looks correct, then changes at the last moment.", choices: [.hold, .scan, .count], answer: .hold, reward: 20),
            ScenarioCard(id: "wide-board", prompt: "The board grows wider on iPad and the target is near the edge.", choices: [.scan, .switchLane, .count], answer: .scan, reward: 16),
            ScenarioCard(id: "rhythm-break", prompt: "A steady rhythm breaks for one step.", choices: [.count, .hold, .switchLane], answer: .count, reward: 17),
            ScenarioCard(id: "double-signal", prompt: "Two signals appear, but only the second one matches the rule.", choices: [.switchLane, .scan, .hold], answer: .switchLane, reward: 19),
            ScenarioCard(id: "low-time", prompt: "Time feels low and the next step is unclear.", choices: [.hold, .count, .scan], answer: .hold, reward: 16),
            ScenarioCard(id: "hidden-order", prompt: "The sequence is correct, but the order is reversed.", choices: [.count, .scan, .switchLane], answer: .count, reward: 20),
            ScenarioCard(id: "bonus-trap", prompt: "A bonus appears next to a decoy.", choices: [.scan, .hold, .switchLane], answer: .scan, reward: 18),
            ScenarioCard(id: "late-switch", prompt: "The active lane switches after two actions.", choices: [.switchLane, .count, .hold], answer: .switchLane, reward: 19),
            ScenarioCard(id: "same-label", prompt: "Two tiles share a label, but only one has the matching icon.", choices: [.scan, .count, .hold], answer: .scan, reward: 18),
            ScenarioCard(id: "long-chain", prompt: "The next pattern has six steps.", choices: [.count, .hold, .scan], answer: .count, reward: 17),
            ScenarioCard(id: "pause-window", prompt: "A short pause gives you time to confirm the rule.", choices: [.hold, .switchLane, .scan], answer: .hold, reward: 15),
            ScenarioCard(id: "side-target", prompt: "The target is not centered and the decoy is louder.", choices: [.scan, .switchLane, .hold], answer: .scan, reward: 18),
            ScenarioCard(id: "memory-slip", prompt: "You forgot the third action in the relay.", choices: [.count, .hold, .switchLane], answer: .count, reward: 16),
            ScenarioCard(id: "rule-change", prompt: "The rule changes from shape to number.", choices: [.switchLane, .scan, .hold], answer: .switchLane, reward: 20),
            ScenarioCard(id: "final-step", prompt: "The final step looks easy and invites a rushed answer.", choices: [.hold, .count, .scan], answer: .hold, reward: 19),
            ScenarioCard(id: "quiet-board", prompt: "Nothing moves for a moment, then one tile changes.", choices: [.scan, .hold, .count], answer: .scan, reward: 15),
            ScenarioCard(id: "mirror-row", prompt: "The row mirrors itself and the center tile is neutral.", choices: [.count, .switchLane, .hold], answer: .count, reward: 17),
            ScenarioCard(id: "wrong-lane", prompt: "You started in the wrong lane.", choices: [.switchLane, .hold, .scan], answer: .switchLane, reward: 18),
            ScenarioCard(id: "dense-set", prompt: "A dense set of small labels appears on iPad.", choices: [.scan, .count, .hold], answer: .scan, reward: 16),
            ScenarioCard(id: "bonus-chain", prompt: "A bonus can extend the chain, but only after the match.", choices: [.hold, .scan, .count], answer: .scan, reward: 20),
            ScenarioCard(id: "step-gap", prompt: "There is a gap between step two and step three.", choices: [.count, .hold, .switchLane], answer: .count, reward: 16),
            ScenarioCard(id: "edge-case", prompt: "The correct answer sits at the edge of the layout.", choices: [.scan, .switchLane, .hold], answer: .scan, reward: 18),
            ScenarioCard(id: "recovery", prompt: "You made one mistake and need to restart cleanly.", choices: [.hold, .count, .scan], answer: .hold, reward: 15)
        ]
    }

    var trainingTips: [TrainingTip] {
        [
            TrainingTip(id: "read-rule", title: "Read the rule first", detail: "Look at the target label before touching the grid.", iconName: "text.magnifyingglass"),
            TrainingTip(id: "short-chain", title: "Chunk patterns", detail: "Treat long sequences as groups of two.", iconName: "link"),
            TrainingTip(id: "use-pause", title: "Use the pause", detail: "A short hold beats a rushed miss.", iconName: "pause.circle.fill"),
            TrainingTip(id: "wide-layout", title: "Scan edges", detail: "On iPad, targets may sit far from the center.", iconName: "ipad"),
            TrainingTip(id: "combo-care", title: "Protect combos", detail: "Combo value grows faster than single taps.", iconName: "bolt.fill"),
            TrainingTip(id: "review-log", title: "Check records", detail: "Recent runs show which mode needs practice.", iconName: "list.bullet.rectangle")
        ]
    }

    var dailyMissions: [Mission] {
        guard !missions.isEmpty else { return [] }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return (0..<4).map { missions[(day + $0 * 3) % missions.count] }
    }

    var dailyProgressText: String {
        "\(dailyMissions.filter { completedMissionIDs.contains($0.id) }.count)/\(dailyMissions.count)"
    }

    var totalScore: Int {
        focusScore + patternScore + scenarioScore
    }

    var bestOverallScore: Int {
        max(bestFocusScore, bestPatternScore, sessions.map(\.score).max() ?? 0)
    }

    var rankTitle: String {
        switch bestOverallScore {
        case 0..<60: "Starter"
        case 60..<140: "Focused"
        case 140..<260: "Sharp"
        case 260..<420: "Expert"
        default: "Master"
        }
    }

    var achievements: [(String, Bool)] {
        [
            ("Focus 50", bestFocusScore >= 50),
            ("Focus 100", bestFocusScore >= 100),
            ("Focus 200", bestFocusScore >= 200),
            ("Combo 5", focusCombo >= 5 || sessions.contains { $0.note.contains("combo") }),
            ("Pattern 50", bestPatternScore >= 50),
            ("Pattern 100", bestPatternScore >= 100),
            ("Pattern 200", bestPatternScore >= 200),
            ("Round 5", patternRound >= 5),
            ("Scenario 5", solvedScenarioCount >= 5),
            ("Scenario 12", solvedScenarioCount >= 12),
            ("Scenario 24", solvedScenarioCount >= 24),
            ("Total 150", totalScore >= 150 || sessions.contains { $0.score >= 150 }),
            ("Total 300", totalScore >= 300 || sessions.contains { $0.score >= 300 }),
            ("Daily 1", dailyMissions.contains { completedMissionIDs.contains($0.id) }),
            ("Daily Set", dailyMissions.allSatisfy { completedMissionIDs.contains($0.id) }),
            ("Missions 6", completedMissionIDs.count >= 6),
            ("Missions 12", completedMissionIDs.count >= 12),
            ("Missions All", completedMissionIDs.count >= missions.count),
            ("Records 3", sessions.count >= 3),
            ("Records 10", sessions.count >= 10),
            ("Few Misses", missedScenarioCount <= 3 && solvedScenarioCount >= 8),
            ("Card Tour", solvedScenarioCount + missedScenarioCount >= 10),
            ("Peak 200", bestOverallScore >= 200),
            ("Peak 400", bestOverallScore >= 400)
        ]
    }

    var recentSessions: [SessionRecord] {
        Array(sessions.prefix(6))
    }

    func start() {
        state = .resisting
        focusScore = 0
        focusCombo = 0
        focusLives = 3
        focusRound = 1
        focusMessage = "Tap MATCH tiles, skip decoys, and keep the combo alive."
        refreshFocusBoard()

        patternScore = 0
        patternIndex = 0
        patternRound = 1
        patternMessage = "Memorize the shown order, then repeat it."
        refreshPatternSequence()

        activeScenario = scenarioCards.randomElement()
        scenarioMessage = "Read the situation and choose the best response."
    }

    func tapFocusTile(_ tile: FocusTile) {
        guard state == .resisting else { return }
        switch tile.kind {
        case .target:
            focusScore += 10 + focusCombo
            focusCombo += 1
            focusMessage = "Match found. Combo \(focusCombo)."
        case .bonus:
            focusScore += 18 + focusCombo
            focusCombo += 2
            focusLives = min(5, focusLives + 1)
            focusMessage = "Bonus secured. Extra focus gained."
        case .decoy:
            focusLives -= 1
            focusCombo = 0
            focusMessage = focusLives > 0 ? "Decoy hit. \(focusLives) lives left." : "Round ended. Save the run and restart."
            if focusLives <= 0 {
                saveSession(modeName: "Focus Grid", score: focusScore, note: "Ended by decoy")
                state = .failed
            }
        }
        focusRound += 1
        bestFocusScore = max(bestFocusScore, focusScore)
        persistScores()
        evaluateMissions()
        if state == .resisting {
            refreshFocusBoard()
        }
    }

    func tapPatternAction(_ action: PatternAction) {
        guard state == .resisting, !patternSequence.isEmpty else { return }
        if action == patternSequence[patternIndex] {
            patternScore += 12 + patternIndex * 3
            patternIndex += 1
            if patternIndex >= patternSequence.count {
                patternRound += 1
                patternMessage = "Pattern complete. Next round is longer."
                bestPatternScore = max(bestPatternScore, patternScore)
                persistScores()
                evaluateMissions()
                refreshPatternSequence()
            } else {
                patternMessage = "Correct. Continue the chain."
            }
        } else {
            patternScore = max(0, patternScore - 10)
            patternIndex = 0
            patternMessage = "Order missed. Restart this sequence."
        }
        bestPatternScore = max(bestPatternScore, patternScore)
        persistScores()
    }

    func answerScenario(_ action: PatternAction) {
        guard let card = activeScenario, state == .resisting else { return }
        if action == card.answer {
            solvedScenarioCount += 1
            scenarioScore += card.reward
            scenarioMessage = "Correct. \(action.title) was the clean response."
        } else {
            missedScenarioCount += 1
            scenarioScore = max(0, scenarioScore - 4)
            scenarioMessage = "Missed. Best response: \(card.answer.title)."
        }
        persistScenario()
        evaluateMissions()
        activeScenario = nextScenario(after: card)
    }

    func completeMission(_ mission: Mission) {
        completedMissionIDs.insert(mission.id)
        persistMissions()
    }

    func saveCurrentRun() {
        let score = totalScore
        saveSession(modeName: "Arcade Mix", score: score, note: "focus \(focusScore), pattern \(patternScore), cards \(scenarioScore)")
        evaluateMissions()
    }

    func resetProgress() {
        focusScore = 0
        patternScore = 0
        scenarioScore = 0
        bestFocusScore = 0
        bestPatternScore = 0
        solvedScenarioCount = 0
        missedScenarioCount = 0
        completedMissionIDs = []
        sessions = []
        persistScores()
        persistScenario()
        persistMissions()
        persistSessions()
        start()
    }

    func applyScreenshotPreset(_ preset: String) {
        state = .resisting
        sessions = [
            SessionRecord(id: UUID(), date: Date(), modeName: "Focus Grid", score: 184, note: "combo 11"),
            SessionRecord(id: UUID(), date: Date(), modeName: "Pattern Relay", score: 156, note: "round 7"),
            SessionRecord(id: UUID(), date: Date(), modeName: "Scenario Cards", score: 128, note: "12 correct")
        ]
        completedMissionIDs = Set(["focus-40", "focus-80", "combo-5", "pattern-40", "pattern-80", "scenario-5", "scenario-12", "total-150"])
        focusScore = 92
        focusCombo = 7
        focusLives = 3
        focusRound = 10
        bestFocusScore = 184
        patternScore = 74
        patternRound = 6
        patternIndex = 1
        bestPatternScore = 156
        patternSequence = [.scan, .count, .hold, .switchLane]
        scenarioScore = 66
        solvedScenarioCount = 12
        missedScenarioCount = 2
        activeScenario = scenarioCards.first { $0.id == "wide-board" } ?? scenarioCards.first
        focusTiles = [
            FocusTile(id: 0, kind: .target, label: "A1"),
            FocusTile(id: 1, kind: .decoy, label: "B4"),
            FocusTile(id: 2, kind: .bonus, label: "C2"),
            FocusTile(id: 3, kind: .target, label: "A2"),
            FocusTile(id: 4, kind: .decoy, label: "D1"),
            FocusTile(id: 5, kind: .target, label: "A3"),
            FocusTile(id: 6, kind: .bonus, label: "C3"),
            FocusTile(id: 7, kind: .target, label: "A4"),
            FocusTile(id: 8, kind: .decoy, label: "B2")
        ]
        focusMessage = "Screenshot run: scan the grid and keep the match chain."
        patternMessage = "Screenshot run: repeat the visible relay order."
        scenarioMessage = "Screenshot run: choose the response that fits the situation."

        if preset == "failed" {
            state = .failed
            focusLives = 0
            focusMessage = "Run ended after a decoy. Review and restart."
        } else if preset == "survived" {
            state = .survived
            saveCurrentRun()
        }
    }

    private func refreshFocusBoard() {
        let labels = ["A1", "A2", "A3", "A4", "B1", "B2", "C1", "C2", "D1", "E1"]
        focusTiles = (0..<9).map { index in
            let roll = Int.random(in: 0..<10)
            let kind: FocusTileKind
            if roll < 5 {
                kind = .target
            } else if roll < 8 {
                kind = .decoy
            } else {
                kind = .bonus
            }
            return FocusTile(id: focusRound * 10 + index, kind: kind, label: labels.randomElement() ?? "A1")
        }
        if !focusTiles.contains(where: { $0.kind == .target }) {
            focusTiles[0] = FocusTile(id: focusRound * 10, kind: .target, label: "A1")
        }
    }

    private func refreshPatternSequence() {
        let length = min(8, 3 + patternRound / 2)
        patternSequence = (0..<length).map { _ in PatternAction.allCases.randomElement() ?? .scan }
        patternIndex = 0
    }

    private func nextScenario(after card: ScenarioCard) -> ScenarioCard? {
        guard let index = scenarioCards.firstIndex(of: card) else { return scenarioCards.randomElement() }
        return scenarioCards[(index + 1) % scenarioCards.count]
    }

    private func evaluateMissions() {
        for mission in missions {
            let complete: Bool
            switch mission.id {
            case "focus-40": complete = bestFocusScore >= 40
            case "focus-80": complete = bestFocusScore >= 80
            case "focus-120": complete = bestFocusScore >= 120
            case "combo-5": complete = focusCombo >= 5
            case "combo-10": complete = focusCombo >= 10
            case "pattern-40": complete = bestPatternScore >= 40
            case "pattern-80": complete = bestPatternScore >= 80
            case "pattern-120": complete = bestPatternScore >= 120
            case "round-4": complete = patternRound >= 4
            case "round-8": complete = patternRound >= 8
            case "scenario-5": complete = solvedScenarioCount >= 5
            case "scenario-12": complete = solvedScenarioCount >= 12
            case "scenario-24": complete = solvedScenarioCount >= 24
            case "total-150": complete = totalScore >= 150 || sessions.contains { $0.score >= 150 }
            case "total-300": complete = totalScore >= 300 || sessions.contains { $0.score >= 300 }
            case "total-500": complete = totalScore >= 500 || sessions.contains { $0.score >= 500 }
            case "no-miss-3": complete = solvedScenarioCount >= 3 && missedScenarioCount == 0
            case "cards-10": complete = solvedScenarioCount + missedScenarioCount >= 10
            case "daily-1": complete = dailyMissions.contains { completedMissionIDs.contains($0.id) }
            case "daily-4": complete = dailyMissions.allSatisfy { completedMissionIDs.contains($0.id) }
            case "records-3": complete = sessions.count >= 3
            case "records-10": complete = sessions.count >= 10
            case "best-200": complete = bestOverallScore >= 200
            case "all-round": complete = focusScore > 0 && patternScore > 0 && solvedScenarioCount + missedScenarioCount > 0 && sessions.count > 0
            default: complete = false
            }
            if complete {
                completedMissionIDs.insert(mission.id)
            }
        }
        persistMissions()
    }

    private func saveSession(modeName: String, score: Int, note: String) {
        sessions.insert(SessionRecord(id: UUID(), date: Date(), modeName: modeName, score: score, note: note), at: 0)
        sessions = Array(sessions.prefix(20))
        persistSessions()
    }

    private func loadProgress() {
        bestFocusScore = UserDefaults.standard.integer(forKey: focusKey)
        bestPatternScore = UserDefaults.standard.integer(forKey: patternKey)
        scenarioScore = UserDefaults.standard.integer(forKey: scenarioKey)
        solvedScenarioCount = UserDefaults.standard.integer(forKey: solvedKey)
        missedScenarioCount = UserDefaults.standard.integer(forKey: missedKey)
        if let missionArray = UserDefaults.standard.array(forKey: missionsKey) as? [String] {
            completedMissionIDs = Set(missionArray)
        }
        if let data = UserDefaults.standard.data(forKey: sessionsKey),
           let decoded = try? JSONDecoder().decode([SessionRecord].self, from: data) {
            sessions = decoded
        }
    }

    private func persistScores() {
        UserDefaults.standard.set(bestFocusScore, forKey: focusKey)
        UserDefaults.standard.set(bestPatternScore, forKey: patternKey)
    }

    private func persistScenario() {
        UserDefaults.standard.set(scenarioScore, forKey: scenarioKey)
        UserDefaults.standard.set(solvedScenarioCount, forKey: solvedKey)
        UserDefaults.standard.set(missedScenarioCount, forKey: missedKey)
    }

    private func persistMissions() {
        UserDefaults.standard.set(Array(completedMissionIDs), forKey: missionsKey)
    }

    private func persistSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }
}
