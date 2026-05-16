import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var game: GameViewModel
    @AppStorage("didStartMobileAds") private var didStartMobileAds = false

    var body: some View {
        ZStack {
            LabBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    HeaderPanel()
                    SectionPicker()

                    switch selectedSection {
                    case .play:
                        ModeOverviewPanel()
                        FocusGridPanel()
                        PatternRelayPanel()
                    case .missions:
                        DailyMissionPanel()
                        MissionPanel()
                    case .cards:
                        ScenarioPanel()
                        TipsPanel()
                    case .records:
                        SummaryPanel()
                        AchievementPanel()
                        HistoryPanel()
                    }
                }
                .frame(maxWidth: 900)
                .padding(.horizontal, 18)
                .padding(.top, 22)
                .padding(.bottom, 30)
                .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if didStartMobileAds {
                AdMobBannerSlot()
            } else {
                Color.black.opacity(0.94)
                    .frame(height: 50)
                    .accessibilityHidden(true)
            }
        }
    }

    @State private var selectedSection: Section = .play

    private enum Section: String, CaseIterable, Identifiable {
        case play
        case missions
        case cards
        case records

        var id: String { rawValue }

        var title: String {
            switch self {
            case .play: "Play"
            case .missions: "Goals"
            case .cards: "Cards"
            case .records: "Records"
            }
        }

        var iconName: String {
            switch self {
            case .play: "gamecontroller.fill"
            case .missions: "checklist"
            case .cards: "rectangle.stack.fill"
            case .records: "chart.bar.fill"
            }
        }
    }

    @ViewBuilder
    private func SectionPicker() -> some View {
        HStack(spacing: 8) {
            ForEach(Section.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: section.iconName)
                            .font(.headline.weight(.black))
                        Text(section.title)
                            .font(.caption.weight(.black))
                    }
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(selectedSection == section ? Color.white.opacity(0.92) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(selectedSection == section ? .black : .white)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct HeaderPanel: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text("Impulse Lab")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("A reflex, memory, and judgment arcade for short daily runs.")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                StatTile(title: "Focus", value: "\(game.bestFocusScore)")
                StatTile(title: "Pattern", value: "\(game.bestPatternScore)")
                StatTile(title: "Cards", value: "\(game.solvedScenarioCount)")
                StatTile(title: "Rank", value: game.rankTitle)
            }
        }
    }
}

private struct ModeOverviewPanel: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle(title: "Arcade Modes", subtitle: "Four ways to train quick decisions.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                ForEach(game.arcadeModes) { mode in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: mode.iconName)
                            .font(.title3.weight(.black))
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mode.title)
                                .font(.caption.weight(.black))
                            Text(mode.detail)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.58))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
                    .padding(10)
                    .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .panelStyle()
    }
}

private struct FocusGridPanel: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PanelTitle(title: "Focus Grid", subtitle: game.focusMessage)
                Spacer()
                Label("\(game.focusLives)", systemImage: "heart.fill")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.pink)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(game.focusTiles) { tile in
                    Button {
                        game.tapFocusTile(tile)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: tile.kind.iconName)
                                .font(.title3.weight(.black))
                            Text(tile.label)
                                .font(.title3.monospacedDigit().weight(.black))
                            Text(tile.kind.title)
                                .font(.caption2.weight(.heavy))
                        }
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(tileColor(tile.kind), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                StatTile(title: "Score", value: "\(game.focusScore)")
                StatTile(title: "Combo", value: "\(game.focusCombo)")
                StatTile(title: "Best", value: "\(game.bestFocusScore)")
            }
        }
        .panelStyle()
    }

    private func tileColor(_ kind: GameViewModel.FocusTileKind) -> Color {
        switch kind {
        case .target: Color.teal.opacity(0.42)
        case .decoy: Color.gray.opacity(0.28)
        case .bonus: Color.orange.opacity(0.42)
        }
    }
}

private struct PatternRelayPanel: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle(title: "Pattern Relay", subtitle: game.patternMessage)

            HStack(spacing: 7) {
                ForEach(Array(game.patternSequence.enumerated()), id: \.offset) { index, action in
                    VStack(spacing: 4) {
                        Image(systemName: action.iconName)
                            .font(.caption.weight(.black))
                        Text("\(index + 1)")
                            .font(.caption2.monospacedDigit().weight(.black))
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(index < game.patternIndex ? Color.green.opacity(0.44) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(GameViewModel.PatternAction.allCases) { action in
                    Button {
                        game.tapPatternAction(action)
                    } label: {
                        Label(action.title, systemImage: action.iconName)
                            .font(.caption.weight(.black))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                StatTile(title: "Score", value: "\(game.patternScore)")
                StatTile(title: "Round", value: "\(game.patternRound)")
                StatTile(title: "Best", value: "\(game.bestPatternScore)")
            }
        }
        .panelStyle()
    }
}

private struct ScenarioPanel: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle(title: "Scenario Cards", subtitle: game.scenarioMessage)

            if let card = game.activeScenario {
                Text(card.prompt)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                    ForEach(card.choices) { action in
                        Button {
                            game.answerScenario(action)
                        } label: {
                            Label(action.title, systemImage: action.iconName)
                                .font(.caption.weight(.black))
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Color.indigo.opacity(0.30), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 8) {
                StatTile(title: "Correct", value: "\(game.solvedScenarioCount)")
                StatTile(title: "Miss", value: "\(game.missedScenarioCount)")
                StatTile(title: "Score", value: "\(game.scenarioScore)")
            }
        }
        .panelStyle()
    }
}

private struct DailyMissionPanel: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PanelTitle(title: "Daily Set", subtitle: "A rotating four-goal practice list.")
                Spacer()
                Text(game.dailyProgressText)
                    .font(.headline.monospacedDigit().weight(.black))
                    .foregroundStyle(.white)
            }

            ForEach(game.dailyMissions) { mission in
                MissionRow(mission: mission)
            }
        }
        .panelStyle()
    }
}

private struct MissionPanel: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle(title: "Goal Library", subtitle: "\(game.missions.count) goals across the arcade.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], spacing: 8) {
                ForEach(game.missions) { mission in
                    MissionRow(mission: mission)
                }
            }

            Button {
                game.saveCurrentRun()
            } label: {
                Label("Save Current Run", systemImage: "tray.and.arrow.down.fill")
                    .font(.headline.weight(.black))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
        }
        .panelStyle()
    }
}

private struct MissionRow: View {
    @EnvironmentObject private var game: GameViewModel
    let mission: GameViewModel.Mission

    var body: some View {
        let done = game.completedMissionIDs.contains(mission.id)
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.seal.fill" : "circle")
                .font(.headline.weight(.black))
                .foregroundStyle(done ? .green : .white.opacity(0.55))
            VStack(alignment: .leading, spacing: 3) {
                Text(mission.title)
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white)
                Text(mission.detail)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
                Text(mission.reward)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.yellow.opacity(0.9))
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .background(done ? Color.green.opacity(0.18) : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct TipsPanel: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle(title: "Practice Notes", subtitle: "Short hints for better runs.")
            ForEach(game.trainingTips) { tip in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: tip.iconName)
                        .font(.headline.weight(.black))
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tip.title)
                            .font(.caption.weight(.black))
                        Text(tip.detail)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.58))
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .panelStyle()
    }
}

private struct SummaryPanel: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle(title: "Content Summary", subtitle: "Progress saved on device.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], spacing: 8) {
                ForEach(Array(game.contentSummary.enumerated()), id: \.offset) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.element.0)
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.white.opacity(0.58))
                        Text(item.element.1)
                            .font(.title2.monospacedDigit().weight(.black))
                            .foregroundStyle(.white)
                        Text(item.element.2)
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.white.opacity(0.48))
                    }
                    .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
                    .padding(10)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .panelStyle()
    }
}

private struct AchievementPanel: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle(title: "Badges", subtitle: "\(game.achievements.count) unlock targets.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                ForEach(Array(game.achievements.enumerated()), id: \.offset) { item in
                    let unlocked = item.element.1
                    Label(item.element.0, systemImage: unlocked ? "star.fill" : "star")
                        .font(.caption.weight(.black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(unlocked ? Color.yellow.opacity(0.24) : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .panelStyle()
    }
}

private struct HistoryPanel: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle(title: "Run History", subtitle: "Recent scores and notes.")
            if game.recentSessions.isEmpty {
                Text("Save a run to start the history.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            } else {
                ForEach(game.recentSessions) { session in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.modeName)
                                .font(.caption.weight(.black))
                            Text(session.note)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.58))
                        }
                        Spacer()
                        Text("\(session.score)")
                            .font(.headline.monospacedDigit().weight(.black))
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            Button(role: .destructive) {
                game.resetProgress()
            } label: {
                Label("Reset Progress", systemImage: "arrow.counterclockwise")
                    .font(.caption.weight(.black))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .panelStyle()
    }
}

private struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.white.opacity(0.54))
            Text(value)
                .font(.headline.monospacedDigit().weight(.black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct PanelTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(Color.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }
}

private extension View {
    func panelStyle() -> some View {
        modifier(PanelModifier())
    }
}

private struct LabBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.07, blue: 0.09),
                Color(red: 0.08, green: 0.12, blue: 0.13),
                Color(red: 0.11, green: 0.09, blue: 0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            GeometryReader { proxy in
                let step = max(44, proxy.size.width / 12)
                Path { path in
                    var x: CGFloat = 0
                    while x <= proxy.size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                        x += step
                    }
                    var y: CGFloat = 0
                    while y <= proxy.size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                        y += step
                    }
                }
                .stroke(Color.white.opacity(0.035), lineWidth: 1)
            }
        }
    }
}
