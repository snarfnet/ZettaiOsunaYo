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
                ModePicker()

                ButtonPanel(
                    buttonBreathes: buttonBreathes,
                    warningFlicker: warningFlicker
                )

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
                StatTile(title: "称号", value: game.rankTitle)
            }
        }
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
                        Spacer()
                        Text(session.resultText)
                            .foregroundStyle(.white.opacity(0.62))
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
