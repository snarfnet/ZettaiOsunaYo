import AVFoundation
import Foundation

@MainActor
protocol AudioTauntPlaying {
    func playRandomNormalOrWarning(elapsedSeconds: Int)
    func startPressedLoop()
    func stopOneShot()
    func stopLoop()
    func stopAll()
}

@MainActor
final class AudioTauntPlayer: NSObject, AudioTauntPlaying, AVAudioPlayerDelegate {
    private var oneShotPlayer: AVAudioPlayer?
    private var loopPlayer: AVAudioPlayer?
    private var pressedLoopTask: Task<Void, Never>?

    private lazy var normalURLs = urls(prefix: "normal_")
    private lazy var warningURLs = urls(prefix: "warning_")
    private lazy var pressedURLs = urls(prefix: "pressed_")

    override init() {
        super.init()
        configureSession()
    }

    func playRandomNormalOrWarning(elapsedSeconds: Int) {
        let pool: [URL]
        if elapsedSeconds >= 60, !warningURLs.isEmpty, Bool.random() {
            pool = warningURLs
        } else if normalURLs.isEmpty {
            pool = warningURLs
        } else {
            pool = normalURLs
        }

        guard let url = pool.randomElement() else { return }
        playOneShot(url)
    }

    func startPressedLoop() {
        pressedLoopTask?.cancel()
        pressedLoopTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if let url = self.pressedURLs.randomElement() {
                    self.playLoopClip(url)
                    let duration = self.loopPlayer?.duration ?? 2.4
                    try? await Task.sleep(for: .seconds(max(1.0, duration + 0.35)))
                } else {
                    try? await Task.sleep(for: .seconds(3))
                }
            }
        }
    }

    func stopOneShot() {
        oneShotPlayer?.stop()
        oneShotPlayer = nil
    }

    func stopLoop() {
        pressedLoopTask?.cancel()
        loopPlayer?.stop()
        loopPlayer = nil
    }

    func stopAll() {
        stopOneShot()
        stopLoop()
    }

    private func configureSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error.localizedDescription)")
        }
    }

    private func playOneShot(_ url: URL) {
        do {
            oneShotPlayer = try AVAudioPlayer(contentsOf: url)
            oneShotPlayer?.delegate = self
            oneShotPlayer?.prepareToPlay()
            oneShotPlayer?.play()
        } catch {
            print("Audio playback failed: \(url.lastPathComponent)")
        }
    }

    private func playLoopClip(_ url: URL) {
        do {
            loopPlayer = try AVAudioPlayer(contentsOf: url)
            loopPlayer?.delegate = self
            loopPlayer?.prepareToPlay()
            loopPlayer?.play()
        } catch {
            print("Pressed audio playback failed: \(url.lastPathComponent)")
        }
    }

    private func urls(prefix: String) -> [URL] {
        let allMP3s = (Bundle.main.urls(forResourcesWithExtension: "mp3", subdirectory: nil) ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "mp3", subdirectory: "Audio") ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "mp3", subdirectory: "Resources/Audio") ?? [])

        return allMP3s
            .filter { $0.lastPathComponent.hasPrefix(prefix) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
