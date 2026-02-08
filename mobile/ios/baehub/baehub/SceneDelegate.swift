import UIKit
import HotwireNative

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  private let rootURL = URL(string: "http://localhost:3000")!
  private lazy var navigator = Navigator(
    configuration: .init(name: "main", startLocation: rootURL)
  )

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }

    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = navigator.rootViewController
    self.window = window
    window.makeKeyAndVisible()

    navigator.start()
  }
}
