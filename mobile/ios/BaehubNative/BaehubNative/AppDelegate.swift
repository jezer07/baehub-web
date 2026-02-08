import UIKit
import HotwireNative

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  // Update for your environment:
  // - Simulator: http://localhost:3000
  // - Device: http://<your-lan-ip>:3000
  private let ROOT_URL = URL(string: "http://localhost:3000")!

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    let localPathConfigURL = Bundle.main.url(forResource: "path-configuration", withExtension: "json")!
    let remotePathConfigURL = ROOT_URL.appending(path: "/configurations/ios_v1.json")

    Hotwire.loadPathConfiguration(from: [
      .file(localPathConfigURL),
      .server(remotePathConfigURL)
    ])

    return true
  }

  func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }
}
