import Foundation
import Security

class Bridge {
    private static var erlangPort: Int = 0
    private static var authToken: String?
    private static var isRunning = false
    private static var erlangThread: Thread?
    
    static func startErlang(completion: @escaping (Int) -> Void) {
        guard !isRunning else {
            completion(erlangPort)
            return
        }
        
        erlangThread = Thread {
            let port = doStartErlang()
            DispatchQueue.main.async {
                completion(port)
            }
        }
        erlangThread?.name = "ErlangRuntime"
        erlangThread?.start()
    }
    
    private static func doStartErlang() -> Int {
        setEnvironmentVariables()
        
        let bundlePath = Bundle.main.bundlePath
        let relPath = "\(bundlePath)/rel"
        let homePath = documentsDirectory()
        let dataPath = "\(homePath)/mosslet_data"
        
        try? FileManager.default.createDirectory(
            atPath: dataPath,
            withIntermediateDirectories: true
        )
        
        setenv("RELEASE_ROOT", relPath, 1)
        setenv("RELEASE_NAME", "mobile", 1)
        setenv("RELEASE_VSN", releaseVersion(), 1)
        setenv("HOME", homePath, 1)
        setenv("MOSSLET_NATIVE", "true", 1)
        setenv("MOSSLET_MOBILE", "true", 1)
        setenv("MOSSLET_DATA_DIR", dataPath, 1)
        setenv("PHX_SERVER", "true", 1)
        setenv("PORT", "4000", 1)
        
        authToken = getOrCreateAuthToken()
        if let token = authToken {
            setenv("DESKTOP_AUTH_TOKEN", token, 1)
        }
        
        let secretKeyBase = getOrCreateSecretKeyBase()
        setenv("SECRET_KEY_BASE", secretKeyBase, 1)
        
        #if DEBUG
        setenv("MIX_ENV", "dev", 1)
        #else
        setenv("MIX_ENV", "prod", 1)
        #endif
        
        guard let ertsPath = findErtsPath(in: relPath) else {
            print("[Bridge] ERTS not found in \(relPath)")
            return 0
        }
        
        let beamPath = "\(ertsPath)/bin/beam.smp"
        guard FileManager.default.fileExists(atPath: beamPath) else {
            print("[Bridge] BEAM not found at \(beamPath)")
            return 0
        }
        
        print("[Bridge] Starting Erlang VM...")
        print("[Bridge] ERTS: \(ertsPath)")
        print("[Bridge] Release root: \(relPath)")
        
        let bootPath = "\(relPath)/releases/\(releaseVersion())/start"
        let configPath = "\(relPath)/releases/\(releaseVersion())/sys.config"
        let vmArgsPath = "\(relPath)/vm.args"
        
        startBeam(
            beamPath: beamPath,
            bootPath: bootPath,
            configPath: configPath,
            vmArgsPath: vmArgsPath,
            relPath: relPath,
            ertsPath: ertsPath
        )
        
        isRunning = true
        erlangPort = 4000
        
        waitForPhoenix(port: erlangPort, timeout: 30)
        
        return erlangPort
    }
    
    private static func startBeam(
        beamPath: String,
        bootPath: String,
        configPath: String,
        vmArgsPath: String,
        relPath: String,
        ertsPath: String
    ) {
        print("[Bridge] Would start BEAM with:")
        print("[Bridge]   beam: \(beamPath)")
        print("[Bridge]   boot: \(bootPath)")
        print("[Bridge]   config: \(configPath)")
    }
    
    private static func waitForPhoenix(port: Int, timeout: Int) {
        let startTime = Date()
        let url = URL(string: "http://127.0.0.1:\(port)/health")!
        
        while Date().timeIntervalSince(startTime) < Double(timeout) {
            var request = URLRequest(url: url)
            request.timeoutInterval = 1
            
            let semaphore = DispatchSemaphore(value: 0)
            var success = false
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    success = true
                }
                semaphore.signal()
            }.resume()
            
            semaphore.wait()
            
            if success {
                print("[Bridge] Phoenix is ready on port \(port)")
                return
            }
            
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        print("[Bridge] Warning: Phoenix did not respond within \(timeout) seconds")
    }
    
    static func stopErlang() {
        guard isRunning else { return }
        print("[Bridge] Stopping Erlang VM...")
        sendEvent("shutdown")
        isRunning = false
    }
    
    static func sendEvent(_ event: String, data: [String: Any]? = nil) {
        guard erlangPort > 0 else { return }
        print("[Bridge] Event: \(event)")
    }
    
    static func getAuthToken() -> String {
        return authToken ?? ""
    }
    
    static func getPort() -> Int {
        return erlangPort
    }
    
    static func isErlangRunning() -> Bool {
        return isRunning
    }
    
    private static func setEnvironmentVariables() {
        let locale = Locale.current
        if let languageCode = locale.language.languageCode?.identifier {
            setenv("LANG", "\(languageCode).UTF-8", 1)
        }
        
        let tz = TimeZone.current.identifier
        setenv("TZ", tz, 1)
        
        if let bundleId = Bundle.main.bundleIdentifier {
            setenv("MOSSLET_BUNDLE_ID", bundleId, 1)
        }
        
        let device = UIDevice.current
        setenv("MOSSLET_DEVICE_MODEL", device.model, 1)
        setenv("MOSSLET_OS_VERSION", device.systemVersion, 1)
    }
    
    private static func documentsDirectory() -> String {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].path
    }
    
    private static func findErtsPath(in relPath: String) -> String? {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: relPath) else {
            return nil
        }
        
        for item in contents {
            if item.hasPrefix("erts-") {
                return "\(relPath)/\(item)"
            }
        }
        
        return nil
    }
    
    private static func releaseVersion() -> String {
        if let path = Bundle.main.path(forResource: "rel/releases/RELEASES", ofType: nil),
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
        }
        
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.15.0"
    }
    
    private static func getOrCreateAuthToken() -> String {
        let key = "mosslet_desktop_auth_token"
        
        if let existing = Keychain.get(key: key) {
            return existing
        }
        
        let token = generateSecureToken()
        Keychain.save(key: key, value: token)
        return token
    }
    
    private static func getOrCreateSecretKeyBase() -> String {
        let key = "mosslet_secret_key_base"
        
        if let existing = Keychain.get(key: key) {
            return existing
        }
        
        let secretKeyBase = generateSecureToken(length: 64)
        Keychain.save(key: key, value: secretKeyBase)
        return secretKeyBase
    }
    
    private static func generateSecureToken(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
    }
}
