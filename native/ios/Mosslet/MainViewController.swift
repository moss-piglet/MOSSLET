import UIKit
import WebKit

protocol MainViewControllerDelegate: AnyObject {
    func mainViewController(_ controller: MainViewController, didReceiveMessage message: [String: Any])
}

class MainViewController: UIViewController {
    weak var delegate: MainViewControllerDelegate?
    private(set) var webView: WKWebView!
    private let serverPort: Int
    private var webViewConfig: WKWebViewConfiguration?
    
    init(serverPort: Int) {
        self.serverPort = serverPort
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with config: WKWebViewConfiguration) {
        self.webViewConfig = config
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        loadApp()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateSafeAreaInsets()
    }
    
    private func setupWebView() {
        let config = webViewConfig ?? WKWebViewConfiguration()
        
        config.preferences.javaScriptEnabled = true
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        
        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.backgroundColor = UIColor(named: "AppBackground") ?? .systemBackground
        webView.isOpaque = false
        
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        
        view.addSubview(webView)
    }
    
    private func loadApp() {
        let urlString = "http://localhost:\(serverPort)"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue(Bridge.authToken(), forHTTPHeaderField: "X-Desktop-Auth")
        webView.load(request)
    }
    
    private func updateSafeAreaInsets() {
        let insets = view.safeAreaInsets
        let js = """
            document.documentElement.style.setProperty('--safe-area-top', '\(insets.top)px');
            document.documentElement.style.setProperty('--safe-area-bottom', '\(insets.bottom)px');
            document.documentElement.style.setProperty('--safe-area-left', '\(insets.left)px');
            document.documentElement.style.setProperty('--safe-area-right', '\(insets.right)px');
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
    
    func reload() {
        loadApp()
    }
}

extension MainViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        if url.host == "localhost" {
            decisionHandler(.allow)
        } else if url.scheme == "mailto" || url.scheme == "tel" {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        } else if navigationAction.navigationType == .linkActivated {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateSafeAreaInsets()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("WebView navigation failed: \(error.localizedDescription)")
    }
}

extension MainViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            UIApplication.shared.open(url)
        }
        return nil
    }
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler()
        })
        present(alert, animated: true)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completionHandler(false)
        })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler(true)
        })
        present(alert, animated: true)
    }
}

extension MainViewController: JsonBridgeDelegate {
    func jsonBridge(_ bridge: JsonBridge, didReceiveMessage message: [String: Any]) {
        delegate?.mainViewController(self, didReceiveMessage: message)
    }
}
