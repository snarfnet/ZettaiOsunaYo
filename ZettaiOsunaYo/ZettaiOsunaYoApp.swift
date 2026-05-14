import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency

@main
struct ZettaiOsunaYoApp: App {
    @StateObject private var game = GameViewModel(audioPlayer: AudioTauntPlayer())
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("didRequestTrackingPermission") private var didRequestTrackingPermission = false
    @AppStorage("didStartMobileAds") private var didStartMobileAds = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(game)
                .onAppear {
                    requestTrackingPermissionIfNeeded()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    requestTrackingPermissionIfNeeded()
                }
        }
    }

    private func requestTrackingPermissionIfNeeded() {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            startMobileAdsIfNeeded()
            return
        }
        guard !didRequestTrackingPermission else { return }
        didRequestTrackingPermission = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            ATTrackingManager.requestTrackingAuthorization { _ in
                DispatchQueue.main.async {
                    startMobileAdsIfNeeded()
                }
            }
        }
    }

    private func startMobileAdsIfNeeded() {
        guard !didStartMobileAds else { return }
        didStartMobileAds = true
        GADMobileAds.sharedInstance().start()
    }
}
