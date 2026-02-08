import SwiftUI
import UIKit
import HotwireNative

final class RootHostViewController: UIViewController {
    private var contentViewController: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    func setContent(_ viewController: UIViewController, animated: Bool) {
        guard contentViewController !== viewController else { return }

        let previousController = contentViewController
        addChild(viewController)
        viewController.view.frame = view.bounds
        viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        if let previousController {
            previousController.willMove(toParent: nil)
            transition(
                from: previousController,
                to: viewController,
                duration: animated ? 0.2 : 0.0,
                options: [.transitionCrossDissolve, .curveEaseInOut],
                animations: nil
            ) { _ in
                previousController.removeFromParent()
                viewController.didMove(toParent: self)
            }
        } else {
            view.addSubview(viewController.view)
            viewController.didMove(toParent: self)
        }

        contentViewController = viewController
    }
}

final class HotwireCoordinator: NSObject, NavigatorDelegate {
    enum AppShell {
        case authentication
        case tabbed
    }

    static let shared = HotwireCoordinator()

    let rootURL: URL
    let signInURL: URL
    private let rootHost = RootHostViewController()

    private var started = false
    private var activeShell: AppShell = .authentication
    private var authNavigator: Navigator?
    private var tabBarController: HotwireTabBarController?

    private override init() {
        // Optional override in Info.plist: BAEHUB_BASE_URL
        if let configuredURL = Bundle.main.object(forInfoDictionaryKey: "BAEHUB_BASE_URL") as? String,
           let url = URL(string: configuredURL) {
            rootURL = url
        } else {
            // Simulator default.
            // For physical device, set BAEHUB_BASE_URL to your Mac LAN URL, e.g. http://192.168.1.10:3000
            rootURL = URL(string: "http://localhost:3000")!
        }

        signInURL = URL(string: "/users/sign_in", relativeTo: rootURL)!.absoluteURL
    }

    func rootViewController() -> UIViewController {
        if !started {
            started = true
            showAuthenticationShell(animated: false)
        }

        return rootHost
    }

    func formSubmissionDidFinish(at url: URL) {
        updateShell(for: url)
    }

    func requestDidFinish(at url: URL) {
        updateShell(for: url)
    }

    private func makeNavigator(name: String, startLocation: URL) -> Navigator {
        Navigator(
            configuration: .init(name: name, startLocation: startLocation),
            delegate: self
        )
    }

    private func showAuthenticationShell(animated: Bool) {
        activeShell = .authentication
        tabBarController = nil

        let navigator = makeNavigator(name: "auth", startLocation: signInURL)
        authNavigator = navigator
        navigator.start()
        rootHost.setContent(navigator.rootViewController, animated: animated)
    }

    private func showTabbedShell(initialURL: URL, animated: Bool) {
        activeShell = .tabbed
        authNavigator = nil

        let tabBarController = HotwireTabBarController(navigatorDelegate: self)
        tabBarController.load(makeTabs())
        configureTabBarAppearance(tabBarController.tabBar)

        if let preferredTabIndex = preferredTabIndex(for: initialURL) {
            tabBarController.selectedIndex = preferredTabIndex
            tabBarController.activeNavigator.route(initialURL, options: .init(action: .replace))
        }

        self.tabBarController = tabBarController
        rootHost.setContent(tabBarController, animated: animated)
    }

    private func makeTabs() -> [HotwireTab] {
        [
            HotwireTab(
                title: "Home",
                image: tabIcon("house.fill"),
                url: URL(string: "/dashboard", relativeTo: rootURL)!.absoluteURL
            ),
            HotwireTab(
                title: "Tasks",
                image: tabIcon("checklist", fallbackSystemName: "checkmark.circle.fill"),
                url: URL(string: "/tasks", relativeTo: rootURL)!.absoluteURL
            ),
            HotwireTab(
                title: "Events",
                image: tabIcon("calendar"),
                url: URL(string: "/events", relativeTo: rootURL)!.absoluteURL
            ),
            HotwireTab(
                title: "Money",
                image: tabIcon("creditcard.fill"),
                url: URL(string: "/expenses", relativeTo: rootURL)!.absoluteURL
            ),
            HotwireTab(
                title: "Settings",
                image: tabIcon("gearshape.fill", fallbackSystemName: "gear"),
                url: URL(string: "/settings", relativeTo: rootURL)!.absoluteURL
            )
        ]
    }

    private func tabIcon(_ systemName: String, fallbackSystemName: String = "circle.fill") -> UIImage {
        UIImage(systemName: systemName) ?? UIImage(systemName: fallbackSystemName)!
    }

    private func configureTabBarAppearance(_ tabBar: UITabBar) {
        let selectedColor = UIColor(red: 0.88, green: 0.11, blue: 0.28, alpha: 1.0)
        let normalColor = UIColor.systemGray

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]

        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
    }

    private func preferredTabIndex(for url: URL) -> Int? {
        let path = url.path

        if path.hasPrefix("/tasks") {
            return 1
        }

        if path.hasPrefix("/events") {
            return 2
        }

        if path.hasPrefix("/expenses") || path.hasPrefix("/settlements") {
            return 3
        }

        if path.hasPrefix("/settings") || path.hasPrefix("/users/edit") {
            return 4
        }

        return 0
    }

    private func isAuthenticationPath(_ path: String) -> Bool {
        path.hasPrefix("/users/sign_in") ||
            path.hasPrefix("/users/sign_up") ||
            path.hasPrefix("/users/password") ||
            path.hasPrefix("/users/confirmation") ||
            path.hasPrefix("/users/unlock")
    }

    private func updateShell(for url: URL) {
        DispatchQueue.main.async {
            if self.isAuthenticationPath(url.path) {
                if self.activeShell != .authentication {
                    self.showAuthenticationShell(animated: true)
                }
                return
            }

            if self.activeShell != .tabbed {
                self.showTabbedShell(initialURL: url, animated: true)
            }
        }
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
