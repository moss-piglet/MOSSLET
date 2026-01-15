import UIKit
import WebKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var bridge: JsonBridge?
    var webView: WKWebView?
    
    private var serverPort: Int = 0
    private var erlangStarted = false
    private var pendingDeviceToken: String?
    private var pendingDeepLink: URL?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        
        let loadingVC = LoadingViewController()
        window?.rootViewController = loadingVC
        window?.makeKeyAndVisible()
        
        UNUserNotificationCenter.current().delegate = self
        
        if let url = launchOptions?[.url] as? URL {
            pendingDeepLink = url
        }
        
        startErlangRuntime { [weak self] port in
            self?.serverPort = port
            self?.erlangStarted = true
            DispatchQueue.main.async {
                self?.showMainApp()
            }
        }
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        handleDeepLink(url)
        return true
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }
        
        handleDeepLink(url)
        return true
    }
    
    private func handleDeepLink(_ url: URL) {
        guard erlangStarted, let webView = webView else {
            pendingDeepLink = url
            return
        }
        
        let path = extractPath(from: url)
        bridge?.notifyDeepLinkReceived(url.absoluteString, path: path)
        
        navigateWebView(to: path)
    }
    
    private func extractPath(from url: URL) -> String {
        if url.scheme == "mosslet" {
            return url.path.isEmpty ? "/" : url.path
        } else {
            return url.path
        }
    }
    
    private func navigateWebView(to path: String) {
        guard let webView = webView else { return }
        
        let js = """
            (function() {
                if (window.liveSocket && window.liveSocket.main) {
                    window.liveSocket.main.pushEvent('navigate', { path: '\(path.replacingOccurrences(of: "'", with: "\\'"))' });
                } else {
                    window.location.href = 'http://localhost:\(serverPort)\(path)';
                }
            })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        notifyElixir(event: "app_will_resign_active")
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        notifyElixir(event: "app_did_enter_background")
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        notifyElixir(event: "app_will_enter_foreground")
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        notifyElixir(event: "app_did_become_active")
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        notifyElixir(event: "app_will_terminate")
        stopErlangRuntime()
    }
    
    private func showMainApp() {
        let mainVC = MainViewController(serverPort: serverPort)
        mainVC.delegate = self
        
        let config = WKWebViewConfiguration()
        bridge = JsonBridge(config: config)
        bridge?.delegate = mainVC
        bridge?.pushDelegate = self
        
        mainVC.configure(with: config)
        
        window?.rootViewController = mainVC
        webView = mainVC.webView
        
        if let token = pendingDeviceToken {
            bridge?.notifyPushTokenReceived(token)
            pendingDeviceToken = nil
        }
        
        if let deepLink = pendingDeepLink {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.handleDeepLink(deepLink)
            }
            pendingDeepLink = nil
        }
    }
    
    private func startErlangRuntime(completion: @escaping (Int) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let port = Bridge.startErlang()
            completion(port)
        }
    }
    
    private func stopErlangRuntime() {
        Bridge.stopErlang()
    }
    
    private func notifyElixir(event: String) {
        guard erlangStarted else { return }
        Bridge.sendEvent(event)
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        
        if let bridge = bridge {
            bridge.notifyPushTokenReceived(token)
        } else {
            pendingDeviceToken = token
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
        bridge?.notifyPushRegistrationFailed(error.localizedDescription)
    }
}

extension AppDelegate: MainViewControllerDelegate {
    func mainViewController(_ controller: MainViewController, didReceiveMessage message: [String: Any]) {
        guard let action = message["action"] as? String else { return }
        
        switch action {
        case "open_url":
            if let urlString = message["url"] as? String,
               let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        case "share":
            if let text = message["text"] as? String {
                let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                controller.present(activityVC, animated: true)
            }
        case "haptic":
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        default:
            break
        }
    }
}

extension AppDelegate: JsonBridgePushDelegate {
    func requestPushPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                    self?.bridge?.notifyPushPermissionResult(granted: true)
                } else {
                    self?.bridge?.notifyPushPermissionResult(granted: false)
                }
            }
        }
    }
    
    func getPushPermissionStatus(completion: @escaping (String) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized:
                    completion("granted")
                case .denied:
                    completion("denied")
                case .notDetermined:
                    completion("not_determined")
                case .provisional:
                    completion("provisional")
                case .ephemeral:
                    completion("ephemeral")
                @unknown default:
                    completion("unknown")
                }
            }
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        
        if let data = userInfo["data"] as? [String: Any] {
            bridge?.notifyPushReceived(data, foreground: true)
        }
        
        completionHandler([.banner, .badge, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        if let data = userInfo["data"] as? [String: Any] {
            bridge?.notifyPushTapped(data)
            
            if let path = data["path"] as? String {
                navigateWebView(to: path)
            }
        }
        
        completionHandler()
    }
}
