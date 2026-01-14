import Foundation
import Security

class Bridge {
    private static var erlangPort: Int = 0
    private static var authToken: String?
    
    static func startErlang() -> Int {
        setEnvironmentVariables()
        
        let bundlePath = Bundle.main.bundlePath
        let relPath = "\(bundlePath)/rel"
        let homePath = documentsDirectory()
        
        setenv("RELEASE_ROOT", relPath, 1)
        setenv("HOME", homePath, 1)
        setenv("MOSSLET_DESKTOP", "true", 1)
        setenv("MOSSLET_DATA_DIR", homePath, 1)
        
        authToken = generateAuthToken()
        if let token = authToken {
            setenv("DESKTOP_AUTH_TOKEN", token, 1)
        }
        
        let startScript = "\(relPath)/bin/mosslet"
        
        guard FileManager.default.fileExists(atPath: startScript) else {
            print("Release not found at \(startScript)")
            return 0
        }
        
        erlangPort = startErlangProcess(relPath: relPath)
        return erlangPort
    }
    
    static func stopErlang() {
        sendEvent("shutdown")
    }
    
    static func sendEvent(_ event: String) {
        guard erlangPort > 0 else { return }
        print("Sending event to Elixir: \(event)")
    }
    
    static func authToken() -> String {
        return authToken ?? ""
    }
    
    private static func setEnvironmentVariables() {
        let locale = Locale.current
        if let languageCode = locale.language.languageCode?.identifier {
            setenv("LANG", "\(languageCode).UTF-8", 1)
        }
        
        let tz = TimeZone.current.identifier
        setenv("TZ", tz, 1)
    }
    
    private static func documentsDirectory() -> String {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].path
    }
    
    private static func generateAuthToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
    }
    
    private static func startErlangProcess(relPath: String) -> Int {
        return 4000
    }
}
