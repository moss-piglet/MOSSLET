import Foundation
import WebKit

protocol JsonBridgeDelegate: AnyObject {
    func jsonBridge(_ bridge: JsonBridge, didReceiveMessage message: [String: Any])
}

protocol JsonBridgePushDelegate: AnyObject {
    func requestPushPermission()
    func getPushPermissionStatus(completion: @escaping (String) -> Void)
}

class JsonBridge: NSObject {
    weak var delegate: JsonBridgeDelegate?
    weak var pushDelegate: JsonBridgePushDelegate?
    private let handlerName = "nativeBridge"
    private weak var webView: WKWebView?
    
    init(config: WKWebViewConfiguration) {
        super.init()
        config.userContentController.add(self, name: handlerName)
        injectBridgeScript(into: config)
    }
    
    func setWebView(_ webView: WKWebView) {
        self.webView = webView
    }
    
    private func injectBridgeScript(into config: WKWebViewConfiguration) {
        let script = """
            window.MossletNative = {
                postMessage: function(message) {
                    window.webkit.messageHandlers.nativeBridge.postMessage(message);
                },
                
                openURL: function(url) {
                    this.postMessage({ action: 'open_url', url: url });
                },
                
                share: function(text, url) {
                    this.postMessage({ action: 'share', text: text, url: url });
                },
                
                haptic: function(style) {
                    this.postMessage({ action: 'haptic', style: style || 'medium' });
                },
                
                isNative: function() {
                    return true;
                },
                
                getPlatform: function() {
                    return 'ios';
                },
                
                // Push notification methods
                push: {
                    requestPermission: function() {
                        window.webkit.messageHandlers.nativeBridge.postMessage({ action: 'push_request_permission' });
                    },
                    
                    getPermissionStatus: function() {
                        window.webkit.messageHandlers.nativeBridge.postMessage({ action: 'push_get_permission_status' });
                    },
                    
                    // Callbacks set by JS
                    onPermissionResult: null,
                    onPermissionStatus: null,
                    onTokenReceived: null,
                    onTokenError: null,
                    onNotificationReceived: null,
                    onNotificationTapped: null
                }
            };
            
            window.dispatchEvent(new CustomEvent('mosslet-native-ready'));
        """
        
        let userScript = WKUserScript(
            source: script,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(userScript)
    }
    
    func notifyPushPermissionResult(granted: Bool) {
        let script = """
            if (window.MossletNative && window.MossletNative.push.onPermissionResult) {
                window.MossletNative.push.onPermissionResult(\(granted));
            }
            window.dispatchEvent(new CustomEvent('mosslet-push-permission', { detail: { granted: \(granted) } }));
        """
        executeJavaScript(script)
    }
    
    func notifyPushPermissionStatus(_ status: String) {
        let script = """
            if (window.MossletNative && window.MossletNative.push.onPermissionStatus) {
                window.MossletNative.push.onPermissionStatus('\(status)');
            }
            window.dispatchEvent(new CustomEvent('mosslet-push-permission-status', { detail: { status: '\(status)' } }));
        """
        executeJavaScript(script)
    }
    
    func notifyPushTokenReceived(_ token: String) {
        let script = """
            if (window.MossletNative && window.MossletNative.push.onTokenReceived) {
                window.MossletNative.push.onTokenReceived('\(token)');
            }
            window.dispatchEvent(new CustomEvent('mosslet-push-token', { detail: { token: '\(token)' } }));
        """
        executeJavaScript(script)
    }
    
    func notifyPushRegistrationFailed(_ error: String) {
        let escapedError = error.replacingOccurrences(of: "'", with: "\\'")
        let script = """
            if (window.MossletNative && window.MossletNative.push.onTokenError) {
                window.MossletNative.push.onTokenError('\(escapedError)');
            }
            window.dispatchEvent(new CustomEvent('mosslet-push-token-error', { detail: { error: '\(escapedError)' } }));
        """
        executeJavaScript(script)
    }
    
    func notifyPushReceived(_ data: [String: Any], foreground: Bool) {
        if let jsonData = try? JSONSerialization.data(withJSONObject: data),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let script = """
                var data = \(jsonString);
                if (window.MossletNative && window.MossletNative.push.onNotificationReceived) {
                    window.MossletNative.push.onNotificationReceived(data, \(foreground));
                }
                window.dispatchEvent(new CustomEvent('mosslet-push-received', { detail: { data: data, foreground: \(foreground) } }));
            """
            executeJavaScript(script)
        }
    }
    
    func notifyPushTapped(_ data: [String: Any]) {
        if let jsonData = try? JSONSerialization.data(withJSONObject: data),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let script = """
                var data = \(jsonString);
                if (window.MossletNative && window.MossletNative.push.onNotificationTapped) {
                    window.MossletNative.push.onNotificationTapped(data);
                }
                window.dispatchEvent(new CustomEvent('mosslet-push-tapped', { detail: { data: data } }));
            """
            executeJavaScript(script)
        }
    }
    
    private func executeJavaScript(_ script: String) {
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(script) { _, error in
                if let error = error {
                    print("JavaScript execution error: \(error)")
                }
            }
        }
    }
}

extension JsonBridge: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == handlerName,
              let body = message.body as? [String: Any] else {
            return
        }
        
        guard let action = body["action"] as? String else {
            delegate?.jsonBridge(self, didReceiveMessage: body)
            return
        }
        
        switch action {
        case "push_request_permission":
            pushDelegate?.requestPushPermission()
        case "push_get_permission_status":
            pushDelegate?.getPushPermissionStatus { [weak self] status in
                self?.notifyPushPermissionStatus(status)
            }
        default:
            delegate?.jsonBridge(self, didReceiveMessage: body)
        }
    }
}
