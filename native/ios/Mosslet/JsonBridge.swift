import Foundation
import WebKit

protocol JsonBridgeDelegate: AnyObject {
    func jsonBridge(_ bridge: JsonBridge, didReceiveMessage message: [String: Any])
}

class JsonBridge: NSObject {
    weak var delegate: JsonBridgeDelegate?
    private let handlerName = "nativeBridge"
    
    init(config: WKWebViewConfiguration) {
        super.init()
        config.userContentController.add(self, name: handlerName)
        injectBridgeScript(into: config)
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
}

extension JsonBridge: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == handlerName,
              let body = message.body as? [String: Any] else {
            return
        }
        delegate?.jsonBridge(self, didReceiveMessage: body)
    }
}
