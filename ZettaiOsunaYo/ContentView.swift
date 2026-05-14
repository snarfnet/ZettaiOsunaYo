import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var game: GameViewModel
    @AppStorage("didStartMobileAds") private var didStartMobileAds = false

    var body: some View {
        ZStack {
            TensionBackground(intensity: game.pulseLevel)
                .ignoresSafeArea()

            switch game.state {
            case .resisting:
                ResistanceView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .failed:
                FailedView()
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
            case .survived:
                SurvivedView()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
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
        VStack(spacing: 34) {
            Spacer(minLength: 24)

            VStack(spacing: 10) {
                Text("絶対押すなよ")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(game.elapsedText)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundStyle(.red.opacity(0.92))
                    .contentTransition(.numericText())
            }

            Spacer(minLength: 18)

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
                .frame(width: 260, height: 260)
                .scaleEffect(buttonBreathes ? 1.055 + game.pulseLevel * 0.035 : 0.985)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("押してはいけない赤いボタン")

            Spacer(minLength: 20)

            Text(warningFlicker ? "見てるぞ" : "指、近い")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))

            Text("AI生成音声を使用")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.36))
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .onAppear {
            buttonBreathes = true
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                warningFlicker = true
            }
        }
        .animation(.easeInOut(duration: max(0.48, 1.2 - game.pulseLevel * 0.58)).repeatForever(autoreverses: true), value: buttonBreathes)
    }
}

private struct FailedView: View {
    @EnvironmentObject private var game: GameViewModel
    @State private var shake = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("押したな")
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundStyle(.red)
                .scaleEffect(shake ? 1.04 : 0.98)

            Text("やると思った。ほんとに押した。")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)

            Text(game.elapsedText)
                .font(.system(size: 34, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            Spacer()

            Button("もう一回耐える") {
                game.start()
            }
            .font(.headline.weight(.heavy))
            .foregroundStyle(.black)
            .padding(.horizontal, 24)
            .padding(.vertical, 15)
            .background(.white, in: Capsule())
            .padding(.bottom, 34)
        }
        .padding(.horizontal, 26)
        .onAppear {
            withAnimation(.linear(duration: 0.08).repeatForever(autoreverses: true)) {
                shake = true
            }
        }
    }
}

private struct SurvivedView: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Text("耐え抜いた")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(game.survivedText)
                .font(.system(size: 25, weight: .heavy, design: .rounded))
                .foregroundStyle(.red.opacity(0.94))
                .multilineTextAlignment(.center)
                .lineSpacing(6)

            Text("押さずに去る。いちばん強い。")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white.opacity(0.68))

            Spacer()

            Button("もう一度") {
                game.start()
            }
            .font(.headline.weight(.heavy))
            .foregroundStyle(.black)
            .padding(.horizontal, 28)
            .padding(.vertical, 15)
            .background(.white, in: Capsule())
            .padding(.bottom, 34)
        }
        .padding(.horizontal, 26)
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
