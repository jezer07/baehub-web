import UIKit
import HotwireNative

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        let remotePathConfigURL = URL(
            string: "/configurations/ios_v1.json",
            relativeTo: HotwireCoordinator.shared.rootURL
        )!.absoluteURL

        if let localPathConfigURL = Bundle.main.url(forResource: "path-configuration", withExtension: "json") {
            Hotwire.loadPathConfiguration(from: [
                .file(localPathConfigURL),
                .server(remotePathConfigURL)
            ])
        } else {
            Hotwire.loadPathConfiguration(from: [ .server(remotePathConfigURL) ])
        }

        return true
    }
}
