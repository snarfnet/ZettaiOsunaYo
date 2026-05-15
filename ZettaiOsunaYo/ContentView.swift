import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var game: GameViewModel
    @AppStorage("didStartMobileAds") private var didStartMobileAds = false

    var body: some View {
        ZStack {
            TensionBackground(intensity: game.pulseLevel)
                .ignoresSafeArea()

            Group {
                switch game.state {
                case .resisting:
                    ResistanceView()
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case .failed:
                    ResultView(result: .failed)
                        .transition(.opacity.combined(with: .scale(scale: 1.04)))
                case .survived:
                    ResultView(result: .survived)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(maxWidth: 860)
            .padding(.horizontal, 18)
        }
        .animation(.easeInOut(duration: 0.28), value: game.state)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if didStartMobileAds {
                AdMobBannerSlot()
            } else {
                Color.black.opacity(0.94)
                    .frame(height: 50)
                    .accessibilityHidden(true)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                game.finishWithoutPressing()
            }
        }
    }
}

private struct ResistanceView: View {
    @EnvironmentObject private var game: GameViewModel
    @State private var buttonBreathes = false
    @State private var warningFlicker = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                HeaderPanel()
                ContentSummaryPanel()
                DefenseGamePanel()
                ReactionCardPanel()
                ScenarioDeckPanel()
                DailyTrainingPanel()
                ChallengePanel()
                ModePicker()

                ButtonPanel(
                    buttonBreathes: buttonBreathes,
                    warningFlicker: warningFlicker
                )

                PressureEventPanel()
                CalmActionPanel()
                TipsPanel()
                ProgressPanel()
                AchievementPanel()
                HistoryPanel()
            }
            .padding(.top, 22)
            .padding(.bottom, 30)
        }
        .onAppear {
            buttonBreathes = true
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                warningFlicker = true
            }
        }
        .animation(.easeInOut(duration: max(0.48, 1.2 - game.pulseLevel * 0.58)).repeatForever(autoreverses: true), value: buttonBreathes)
    }
}

private struct HeaderPanel: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text("絶対押すなよ")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("赤いボタンを押さずに、どこまで耐えられるか。")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                StatTile(title: "現在", value: game.elapsedText)
                StatTile(title: "ベスト", value: game.bestText)
                StatTile(title: "冷静", value: game.calmText)
                StatTile(title: "判断", value: game.reactionScoreText)
            }
        }
    }
}

private struct ContentSummaryPanel: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("遊べる内容")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                    Text("任務、3択、緊急イベント、実績を集めて記録を伸ばす")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
                }
                Spacer()
                Label(game.rankTitle, systemImage: "crown.fill")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.yellow.opacity(0.92))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], spacing: 8) {
                ForEach(Array(game.contentSummary.enumerated()), id: \.offset) { pair in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(pair.element.0)
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.white.opacity(0.58))
                        Text(pair.element.1)
                            .font(.title2.monospacedDigit().weight(.black))
                            .foregroundStyle(.white)
                        Text(pair.element.2)
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.white.opacity(0.48))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
                    .padding(10)
                    .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .panelStyle()
    }
}

private struct DefenseGamePanel: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ボタン防衛")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                    Text("安全タイルを処理してスコアを伸ばす。赤い罠は押さない")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(game.defenseScore)")
                        .font(.headline.monospacedDigit().weight(.black))
                        .foregroundStyle(.white)
                    Text("BEST \(game.bestDefenseScore)")
                        .font(.caption2.monospacedDigit().weight(.heavy))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(game.defenseTiles) { tile in
                    Button {
                        game.tapDefenseTile(tile)
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: tile.kind.iconName)
                                .font(.title3.weight(.black))
                            Text(tile.kind.title)
                                .font(.caption.weight(.black))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, minHeight: 66)
                        .background(tileBackground(tile.kind), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(tile.kind == .bonus ? .black : .white)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(tile.kind == .trap ? 0.32 : 0.12), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Label("LIFE \(game.defenseLives)", systemImage: "heart.fill")
                Spacer()
                Label("COMBO \(game.defenseCombo)", systemImage: "bolt.fill")
                Spacer()
                Label("ROUND \(game.defenseRound)", systemImage: "square.grid.3x3.fill")
            }
            .font(.caption.monospacedDigit().weight(.heavy))
            .foregroundStyle(.white.opacity(0.68))

            Text(game.defenseMessage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
        }
        .panelStyle()
    }

    private func tileBackground(_ kind: GameViewModel.DefenseTileKind) -> Color {
        switch kind {
        case .safe:
            return Color.blue.opacity(0.34)
        case .trap:
            return Color.red.opacity(0.5)
        case .bonus:
            return Color.white.opacity(0.9)
        }
    }
}

private struct DailyTrainingPanel: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("今日の修行")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                    Text("日替わり4本をクリアして、押さない力を積み上げる")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
                }
                Spacer()
                Text(game.dailyTrainingProgressText)
                    .font(.headline.monospacedDigit().weight(.black))
                    .foregroundStyle(.white)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 126), spacing: 10)], spacing: 10) {
                ForEach(game.dailyTrainingMissions) { mission in
                    Button {
                        game.startMission(mission)
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            Image(systemName: game.completedMissionIDs.contains(mission.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(game.completedMissionIDs.contains(mission.id) ? .green : .white.opacity(0.5))
                            Text(mission.title)
                                .font(.caption.weight(.black))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.74)
                            Text(game.formatted(seconds: mission.targetSeconds))
                                .font(.caption.monospacedDigit().weight(.heavy))
                                .foregroundStyle(.white.opacity(0.56))
                        }
                        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                        .padding(10)
                        .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .panelStyle()
    }
}

private struct ChallengePanel: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("チャレンジ任務")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                    Text("短期戦から長期戦まで、順番にクリアして称号を集める")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
                }
                Spacer()
                Text(game.rankTitle)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                ForEach(game.missions) { mission in
                    MissionButton(mission: mission)
                }
            }
        }
        .panelStyle()
    }
}

private struct MissionButton: View {
    @EnvironmentObject private var game: GameViewModel
    let mission: GameViewModel.ChallengeMission

    private var isActive: Bool {
        game.activeMissionID == mission.id
    }

    private var isComplete: Bool {
        game.completedMissionIDs.contains(mission.id)
    }

    var body: some View {
        Button {
            game.startMission(mission)
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Image(systemName: isComplete ? "checkmark.seal.fill" : "flag.checkered")
                    Text(mission.title)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(game.formatted(seconds: mission.targetSeconds))
                        .font(.caption.monospacedDigit().weight(.black))
                }
                .font(.subheadline.weight(.black))
                .foregroundStyle(.white)

                Text(mission.detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(mission.rewardTitle)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(isComplete ? .green : .white.opacity(0.48))
            }
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .padding(12)
            .background(isActive ? Color.red.opacity(0.42) : Color.white.opacity(isComplete ? 0.12 : 0.07), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? Color.white.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ModePicker: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("モード")
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white.opacity(0.58))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(GameViewModel.Mode.allCases) { mode in
                    Button {
                        game.chooseMode(mode)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(mode.title)
                                .font(.headline.weight(.black))
                                .foregroundStyle(.white)
                            Text(mode.subtitle)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.62))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
                        .padding(12)
                        .background(mode == game.selectedMode ? Color.red.opacity(0.42) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(mode == game.selectedMode ? Color.white.opacity(0.42) : Color.white.opacity(0.12), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .panelStyle()
    }
}

private struct ButtonPanel: View {
    @EnvironmentObject private var game: GameViewModel
    let buttonBreathes: Bool
    let warningFlicker: Bool

    var body: some View {
        VStack(spacing: 18) {
            Text(game.modeGoalText)
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)

            Button {
                game.pressForbiddenButton()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.04, blue: 0.02),
                                    Color(red: 0.58, green: 0.0, blue: 0.0)
                                ],
                                center: .topLeading,
                                startRadius: 20,
                                endRadius: 180
                            )
                        )
                        .shadow(color: .red.opacity(0.62), radius: buttonBreathes ? 42 : 20)
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.2), lineWidth: 3)
                                .padding(8)
                        }

                    VStack(spacing: 8) {
                        Text("押すな")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("DON'T")
                            .font(.system(size: 17, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
                .frame(width: 252, height: 252)
                .scaleEffect(buttonBreathes ? 1.055 + game.pulseLevel * 0.035 : 0.985)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("押してはいけない赤いボタン")

            Text(warningFlicker ? "まだ見てるだけ" : "指、近い")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))

            Button {
                game.finishWithoutPressing()
            } label: {
                Label("押さずに退室して記録", systemImage: "figure.walk.departure")
                    .font(.headline.weight(.heavy))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
        }
        .panelStyle()
    }
}

private struct ReactionCardPanel: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("誘惑ジャッジ")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                    Text("状況を読んで、押さないための一手を選ぶ")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
                }
                Spacer()
                Label("\(game.solvedReactionCount)正解", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.green.opacity(0.92))
            }

            if let card = game.activeReactionCard {
                Text(card.prompt)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 10) {
                    ForEach(card.choices) { action in
                        Button {
                            game.answerReaction(action)
                        } label: {
                            Label(action.title, systemImage: action.iconName)
                                .font(.caption.weight(.black))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(.white, in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(.black)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(game.reactionMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
        .panelStyle()
    }
}

private struct ScenarioDeckPanel: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("誘惑カード一覧")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                    Text("好きな状況を選ぶと、上のジャッジ問題に出題される")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
                }
                Spacer()
                Text("\(game.reactionCards.count)枚")
                    .font(.caption.monospacedDigit().weight(.black))
                    .foregroundStyle(.white.opacity(0.7))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                ForEach(game.featuredReactionCards) { card in
                    Button {
                        game.selectReactionCard(card)
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Image(systemName: card.correctAction.iconName)
                                Text("+\(card.reward)")
                                    .font(.caption.monospacedDigit().weight(.black))
                                Spacer()
                            }
                            .foregroundStyle(.white.opacity(0.64))

                            Text(card.prompt)
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(.white)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 94, alignment: .topLeading)
                        .padding(11)
                        .background(card.id == game.activeReactionCard?.id ? Color.red.opacity(0.38) : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(card.id == game.activeReactionCard?.id ? Color.white.opacity(0.42) : Color.white.opacity(0.1), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .panelStyle()
    }
}

private struct PressureEventPanel: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("緊急イベント")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                Spacer()
                Label("最高\(game.bestEventStreak)コンボ", systemImage: "bolt.fill")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.yellow.opacity(0.92))
            }

            if let event = game.activePressureEvent {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2.weight(.black))
                        .foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.headline.weight(.black))
                            .foregroundStyle(.white)
                        Text(event.detail)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    Spacer()
                    Label(event.requiredAction.title, systemImage: event.requiredAction.iconName)
                        .font(.caption.weight(.black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.white, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(12)
                .background(Color.red.opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.72))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("次の誘惑に備える")
                            .font(.headline.weight(.black))
                            .foregroundStyle(.white)
                        Text("途中で出る指示に合う行動を選ぶと、冷静ポイントとコンボが伸びます。")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.58))
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .panelStyle()
    }
}

private struct CalmActionPanel: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("押さないための行動")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                    Text("使うと冷静ポイントが増え、緊張ゲージの上昇を少し抑える")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
                }
                Spacer()
                if game.calmActionCooldown > 0 {
                    Text("\(game.calmActionCooldown)秒")
                        .font(.caption.monospacedDigit().weight(.black))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            HStack(spacing: 10) {
                ForEach(GameViewModel.CalmAction.allCases) { action in
                    Button {
                        game.performCalmAction(action)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: action.iconName)
                                .font(.title3.weight(.bold))
                            Text(action.title)
                                .font(.caption.weight(.heavy))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                            Text("+\(action.points)")
                                .font(.caption2.monospacedDigit().weight(.black))
                                .foregroundStyle(.white.opacity(0.56))
                        }
                        .frame(maxWidth: .infinity, minHeight: 78)
                        .background(game.canUseCalmAction ? Color.white.opacity(0.1) : Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(game.canUseCalmAction ? .white : .white.opacity(0.42))
                    }
                    .buttonStyle(.plain)
                    .disabled(!game.canUseCalmAction)
                }
            }
        }
        .panelStyle()
    }
}

private struct TipsPanel: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("攻略メモ")
                .font(.headline.weight(.black))
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                ForEach(game.trainingTips) { tip in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: tip.iconName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white.opacity(0.72))
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tip.title)
                                .font(.caption.weight(.black))
                                .foregroundStyle(.white)
                            Text(tip.detail)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.56))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
                    .padding(10)
                    .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .panelStyle()
    }
}

private struct ProgressPanel: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("緊張ゲージ")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(game.progress * 100))%")
                    .font(.headline.monospacedDigit().weight(.heavy))
                    .foregroundStyle(.red.opacity(0.95))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule()
                        .fill(LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width * game.progress)
                }
            }
            .frame(height: 12)

            HStack {
                Label("\(game.clearCount)勝", systemImage: "checkmark.seal.fill")
                Spacer()
                Label("\(game.pressCount)回押した", systemImage: "hand.tap.fill")
            }
            .font(.caption.weight(.heavy))
            .foregroundStyle(.white.opacity(0.68))
        }
        .panelStyle()
    }
}

private struct AchievementPanel: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("実績")
                .font(.headline.weight(.black))
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 94), spacing: 8)], spacing: 8) {
                ForEach(game.achievements, id: \.0) { title, unlocked in
                    HStack(spacing: 6) {
                        Image(systemName: unlocked ? "star.fill" : "star")
                        Text(title)
                    }
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(unlocked ? .white : .white.opacity(0.42))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(unlocked ? Color.red.opacity(0.34) : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .panelStyle()
    }
}

private struct HistoryPanel: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("最近の挑戦")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                Spacer()
                Button("リセット") {
                    game.resetProgress()
                }
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white.opacity(0.54))
            }

            if game.recentSessions.isEmpty {
                Text("まだ記録がありません。まずは30秒チャレンジへ。")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                ForEach(game.recentSessions) { session in
                    HStack {
                        Image(systemName: session.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(session.succeeded ? .green : .red)
                        Text(session.mode.shortTitle)
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(.white)
                        if let missionTitle = session.missionTitle {
                            Text(missionTitle)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.48))
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(session.resultText)
                            .foregroundStyle(.white.opacity(0.62))
                        Text("+\(session.calmScore ?? 0)")
                            .font(.caption.monospacedDigit().weight(.heavy))
                            .foregroundStyle(.white.opacity(0.48))
                        Text(game.formatted(seconds: session.seconds))
                            .font(.subheadline.monospacedDigit().weight(.heavy))
                            .foregroundStyle(.white)
                    }
                    .font(.subheadline)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .panelStyle()
    }
}

private struct ResultView: View {
    enum Result {
        case failed
        case survived
    }

    @EnvironmentObject private var game: GameViewModel
    let result: Result
    @State private var shake = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                VStack(spacing: 12) {
                    Text(result == .failed ? "押したな" : "耐え抜いた")
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundStyle(result == .failed ? .red : .white)
                        .scaleEffect(result == .failed && shake ? 1.04 : 1.0)
                        .multilineTextAlignment(.center)

                    Text(result == .failed ? "やると思った。でも記録は残した。" : game.survivedText)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.center)

                    Text(game.elapsedText)
                        .font(.system(size: 38, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .panelStyle()

                ProgressPanel()
                AchievementPanel()
                HistoryPanel()

                Button {
                    game.start()
                } label: {
                    Label("もう一度挑戦", systemImage: "arrow.clockwise")
                        .font(.headline.weight(.heavy))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(.white, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 24)
            }
            .padding(.top, 22)
        }
        .onAppear {
            if result == .failed {
                withAnimation(.linear(duration: 0.08).repeatForever(autoreverses: true)) {
                    shake = true
                }
            }
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.white.opacity(0.52))
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct PanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.11), lineWidth: 1)
            }
    }
}

private extension View {
    func panelStyle() -> some View {
        modifier(PanelModifier())
    }
}

private struct TensionBackground: View {
    let intensity: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let pulse = (sin(time * (1.5 + intensity * 4.2)) + 1) / 2

            ZStack {
                Color.black

                RadialGradient(
                    colors: [
                        .red.opacity(0.12 + pulse * 0.16 + intensity * 0.18),
                        .black.opacity(0.98)
                    ],
                    center: .center,
                    startRadius: 20,
                    endRadius: 430
                )

                Rectangle()
                    .fill(.red.opacity(0.04 + intensity * 0.08))
                    .mask {
                        VStack(spacing: 10) {
                            ForEach(0..<42, id: \.self) { _ in
                                Rectangle().frame(height: 1)
                            }
                        }
                    }
                    .opacity(0.7 + pulse * 0.3)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GameViewModel(audioPlayer: PreviewAudioPlayer()))
}

@MainActor
private final class PreviewAudioPlayer: AudioTauntPlaying {
    func playRandomNormalOrWarning(elapsedSeconds: Int) {}
    func startPressedLoop() {}
    func stopOneShot() {}
    func stopLoop() {}
    func stopAll() {}
}
