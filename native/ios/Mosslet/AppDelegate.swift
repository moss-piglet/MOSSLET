import UIKit
import WebKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var bridge: JsonBridge?
    var webView: WKWebView?
    
    private var serverPort: Int = 0
    private var erlangStarted = false
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        
        let loadingVC = LoadingViewController()
        window?.rootViewController = loadingVC
        window?.makeKeyAndVisible()
        
        startErlangRuntime { [weak self] port in
            self?.serverPort = port
            self?.erlangStarted = true
            DispatchQueue.main.async {
                self?.showMainApp()
            }
        }
        
        return true
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
        
        mainVC.configure(with: config)
        
        window?.rootViewController = mainVC
        webView = mainVC.webView
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
