import SwiftUI
import UIKit
import HotwireNative
import WebKit

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

final class HotwireCoordinator: NSObject, NavigatorDelegate, UITabBarControllerDelegate {
    enum AppShell {
        case authentication
        case tabbed
    }

    static let shared = HotwireCoordinator()
    private static let hasAuthenticatedSessionDefaultsKey = "has_authenticated_session"

    let rootURL: URL
    let signInURL: URL
    private let rootHost = RootHostViewController()

    private var started = false
    private var activeShell: AppShell = .authentication
    private var authNavigator: Navigator?
    private var authWebViewObservation: NSKeyValueObservation?
    private var tabWebViewObservation: NSKeyValueObservation?
    private var tabBarController: HotwireTabBarController?
    private var pendingQuickAddURL: URL?
    private lazy var quickAddBarButtonItem = UIBarButtonItem(
        barButtonSystemItem: .add,
        target: self,
        action: #selector(handleQuickAddTapped)
    )
    private lazy var filterBarButtonItem: UIBarButtonItem = {
        let image = UIImage(systemName: "line.3.horizontal.decrease.circle")
        return UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(handleFilterTapped))
    }()
    private var pendingFilterURL: URL?

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
            if Self.storedHasAuthenticatedSession {
                let dashboardURL = URL(string: "/dashboard", relativeTo: rootURL)!.absoluteURL
                showTabbedShell(initialURL: dashboardURL, animated: false)
            } else {
                showAuthenticationShell(animated: false)
            }
        }

        return rootHost
    }

    func formSubmissionDidFinish(at url: URL) {
        updateShell(for: url)
    }

    func requestDidFinish(at url: URL) {
        updateShell(for: url)
    }

    func handle(proposal: VisitProposal, from navigator: Navigator) -> ProposalResult {
        let destinationURL = proposal.url

        if activeShell == .authentication, !isAuthenticationPath(destinationURL.path) {
            DispatchQueue.main.async {
                self.showTabbedShell(initialURL: destinationURL, animated: true)
            }
            return .reject
        }

        if activeShell == .tabbed, isAuthenticationPath(destinationURL.path), navigator !== authNavigator {
            DispatchQueue.main.async {
                self.showAuthenticationShell(animated: true)
            }
            return .reject
        }

        return .accept
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
        pendingQuickAddURL = nil
        tabWebViewObservation?.invalidate()
        tabWebViewObservation = nil
        Self.storedHasAuthenticatedSession = false

        let navigator = makeNavigator(name: "auth", startLocation: signInURL)
        authNavigator = navigator
        observeAuthenticationWebView(navigator.activeWebView)
        navigator.start()
        rootHost.setContent(navigator.rootViewController, animated: animated)
    }

    private func showTabbedShell(initialURL: URL, animated: Bool) {
        activeShell = .tabbed
        authNavigator = nil
        authWebViewObservation?.invalidate()
        authWebViewObservation = nil
        Self.storedHasAuthenticatedSession = true

        let tabBarController = HotwireTabBarController(navigatorDelegate: self)
        tabBarController.delegate = self
        tabBarController.load(makeTabs())
        configureTabBarAppearance(tabBarController.tabBar)

        if let preferredTabIndex = preferredTabIndex(for: initialURL) {
            tabBarController.selectedIndex = preferredTabIndex
            tabBarController.activeNavigator.route(initialURL, options: .init(action: .replace))
        }

        self.tabBarController = tabBarController
        observeTabbedWebView(tabBarController.activeNavigator.activeWebView)
        rootHost.setContent(tabBarController, animated: animated)
        updateQuickAddButton(for: initialURL)
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

    private func isAppOrigin(_ url: URL) -> Bool {
        guard let candidate = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let root = URLComponents(url: rootURL, resolvingAgainstBaseURL: true)
        else {
            return false
        }

        let candidateScheme = candidate.scheme?.lowercased()
        let rootScheme = root.scheme?.lowercased()
        let candidateHost = candidate.host?.lowercased()
        let rootHost = root.host?.lowercased()

        return candidateScheme == rootScheme &&
            candidateHost == rootHost &&
            effectivePort(for: candidate) == effectivePort(for: root)
    }

    private func effectivePort(for components: URLComponents) -> Int? {
        if let port = components.port {
            return port
        }

        switch components.scheme?.lowercased() {
        case "https":
            return 443
        case "http":
            return 80
        default:
            return nil
        }
    }

    private func observeAuthenticationWebView(_ webView: WKWebView) {
        authWebViewObservation?.invalidate()
        authWebViewObservation = webView.observe(\.url, options: [.initial, .new]) { [weak self] webView, _ in
            guard let self,
                  let currentURL = webView.url,
                  self.isAppOrigin(currentURL)
            else { return }

            DispatchQueue.main.async {
                guard self.activeShell == .authentication else { return }

                if self.activeShell == .authentication, !self.isAuthenticationPath(currentURL.path) {
                    self.showTabbedShell(initialURL: currentURL, animated: true)
                    return
                }

                self.updateShell(for: currentURL)
            }
        }
    }

    private func observeTabbedWebView(_ webView: WKWebView) {
        tabWebViewObservation?.invalidate()
        tabWebViewObservation = webView.observe(\.url, options: [.initial, .new]) { [weak self] webView, _ in
            guard let self,
                  let currentURL = webView.url,
                  self.isAppOrigin(currentURL)
            else { return }

            DispatchQueue.main.async {
                guard self.activeShell == .tabbed else { return }

                if self.activeShell == .tabbed, self.isAuthenticationPath(currentURL.path) {
                    self.showAuthenticationShell(animated: true)
                    return
                }

                self.updateQuickAddButton(for: currentURL)
            }
        }
    }

    private func tabRootURL(for index: Int) -> URL? {
        switch index {
        case 1:
            return URL(string: "/tasks", relativeTo: rootURL)?.absoluteURL
        case 2:
            return URL(string: "/events", relativeTo: rootURL)?.absoluteURL
        case 3:
            return URL(string: "/expenses", relativeTo: rootURL)?.absoluteURL
        default:
            return nil
        }
    }

    private func nativeAddURL(for url: URL) -> URL? {
        switch url.path {
        case "/tasks":
            return URL(string: "/tasks/new", relativeTo: rootURL)?.absoluteURL
        case "/events":
            return URL(string: "/events/new", relativeTo: rootURL)?.absoluteURL
        case "/expenses":
            return URL(string: "/expenses/new", relativeTo: rootURL)?.absoluteURL
        default:
            return nil
        }
    }

    private func nativeFilterURL(for url: URL) -> URL? {
        let path = url.path
        let basePath: String?

        switch path {
        case "/tasks":
            basePath = "/tasks/filters"
        case "/events":
            basePath = "/events/filters"
        case "/expenses":
            basePath = "/expenses/filters"
        default:
            basePath = nil
        }

        guard let basePath else { return nil }

        // Preserve query params so filters pre-populate
        var components = URLComponents(url: rootURL.appendingPathComponent(basePath), resolvingAgainstBaseURL: true)
        if let query = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems, !query.isEmpty {
            components?.queryItems = query
        }

        return components?.url
    }

    private func currentVisitableURLForActiveTab() -> URL? {
        guard let tabBarController else { return nil }

        if let topVisitable = tabBarController.activeNavigator.activeNavigationController.topViewController as? VisitableViewController {
            return topVisitable.currentVisitableURL
        }

        return nil
    }

    private func currentVisitableURLForAuthShell() -> URL? {
        if let topVisitable = authNavigator?.activeNavigationController.topViewController as? VisitableViewController {
            return topVisitable.currentVisitableURL
        }

        return authNavigator?.activeWebView.url
    }

    private func effectiveURL(from callbackURL: URL) -> URL {
        switch activeShell {
        case .authentication:
            return currentVisitableURLForAuthShell() ?? callbackURL
        case .tabbed:
            return currentVisitableURLForActiveTab() ?? callbackURL
        }
    }

    private func updateQuickAddButton(for url: URL?) {
        guard activeShell == .tabbed, let tabBarController else { return }

        let topController = tabBarController.activeNavigator.activeNavigationController.topViewController

        guard let url else {
            pendingQuickAddURL = nil
            pendingFilterURL = nil
            topController?.navigationItem.rightBarButtonItems = nil
            return
        }

        let addURL = nativeAddURL(for: url)
        let filterURL = nativeFilterURL(for: url)

        pendingQuickAddURL = addURL
        pendingFilterURL = filterURL

        var items: [UIBarButtonItem] = []
        if addURL != nil { items.append(quickAddBarButtonItem) }
        if filterURL != nil { items.append(filterBarButtonItem) }

        topController?.navigationItem.rightBarButtonItems = items.isEmpty ? nil : items
    }

    @objc private func handleQuickAddTapped() {
        guard activeShell == .tabbed,
              let tabBarController,
              let addURL = pendingQuickAddURL
        else { return }

        tabBarController.activeNavigator.route(addURL)
    }

    @objc private func handleFilterTapped() {
        guard activeShell == .tabbed,
              let tabBarController,
              let filterURL = pendingFilterURL
        else { return }

        tabBarController.activeNavigator.route(filterURL)
    }

    private func shouldSwitchToAuthenticationShell(for callbackURL: URL) -> Bool {
        guard activeShell == .tabbed else { return true }
        guard isAuthenticationPath(callbackURL.path) else { return false }

        guard let activeURL = currentVisitableURLForActiveTab() else {
            return false
        }

        return isAuthenticationPath(activeURL.path)
    }

    private func updateShell(for url: URL) {
        DispatchQueue.main.async {
            let observedURL = self.effectiveURL(from: url)
            guard self.isAppOrigin(observedURL) else { return }

            if self.isAuthenticationPath(observedURL.path) {
                if self.activeShell == .authentication {
                    return
                }

                if self.shouldSwitchToAuthenticationShell(for: observedURL) {
                    self.showAuthenticationShell(animated: true)
                }
                return
            }

            if self.activeShell != .tabbed {
                self.showTabbedShell(initialURL: observedURL, animated: true)
            } else {
                self.updateQuickAddButton(for: observedURL)
            }
        }
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        guard activeShell == .tabbed,
              let hotwireTabBarController = tabBarController as? HotwireTabBarController
        else { return }

        observeTabbedWebView(hotwireTabBarController.activeNavigator.activeWebView)
        let currentURL = currentVisitableURLForActiveTab() ?? tabRootURL(for: tabBarController.selectedIndex)
        updateQuickAddButton(for: currentURL)
    }

    private static var storedHasAuthenticatedSession: Bool {
        get { UserDefaults.standard.bool(forKey: hasAuthenticatedSessionDefaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasAuthenticatedSessionDefaultsKey) }
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
