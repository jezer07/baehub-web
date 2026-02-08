import SwiftUI
import UIKit
import HotwireNative

final class HotwireCoordinator {
    static let shared = HotwireCoordinator()

    let rootURL: URL
    private var started = false
    lazy var navigator = Navigator(configuration: .init(name: "main", startLocation: rootURL))

    private init() {
        // Optional override in Info.plist: BAEHUB_BASE_URL
        if let configuredURL = Bundle.main.object(forInfoDictionaryKey: "BAEHUB_BASE_URL") as? String,
           let url = URL(string: configuredURL) {
            rootURL = url
        } else {
            // Simulator default.
            // For physical device, set BAEHUB_BASE_URL to your Mac LAN URL, e.g. http://192.168.1.10:3000
            rootURL = URL(string: "http://localhost:3000")!
        }
    }

    func rootViewController() -> UIViewController {
        if !started {
            started = true
            navigator.start()
        }
        return navigator.rootViewController
    }
}

struct ContentView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        HotwireCoordinator.shared.rootViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

#Preview {
    ContentView()
}
