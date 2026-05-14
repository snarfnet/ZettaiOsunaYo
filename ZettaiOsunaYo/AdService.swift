import SwiftUI
import GoogleMobileAds

enum AdUnitID {
    static var bottomBanner: String {
        Bundle.main.object(forInfoDictionaryKey: "ZETTAI_BOTTOM_BANNER_AD_UNIT_ID") as? String
            ?? "ca-app-pub-3940256099942544/2934735716"
    }
}

struct AdMobBannerSlot: View {
    var body: some View {
        AdMobBannerView(unitID: AdUnitID.bottomBanner)
            .frame(height: 50)
            .background(Color.black.opacity(0.94))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(height: 1)
            }
            .accessibilityLabel("広告")
    }
}

private struct AdMobBannerView: UIViewRepresentable {
    let unitID: String

    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = unitID

        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = windowScene.windows.first?.rootViewController {
                banner.rootViewController = root
                banner.load(GADRequest())
            }
        }

        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {}
}
