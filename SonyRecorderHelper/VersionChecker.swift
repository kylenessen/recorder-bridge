import Foundation

class VersionChecker {
    private let currentVersion: String
    private let userDefaults = UserDefaults.standard
    
    private enum UserDefaultsKeys {
        static let lastVersionCheckDate = "LastVersionCheckDate"
        static let lastNotifiedVersion = "LastNotifiedVersion"
        static let versionCheckInterval = TimeInterval(7 * 24 * 60 * 60) // 7 days
    }
    
    init() {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            self.currentVersion = version
        } else {
            self.currentVersion = "1.0"
        }
    }
    
    var appVersion: String {
        return currentVersion
    }
    
    var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var fullVersionString: String {
        return "\(currentVersion) (\(buildNumber))"
    }
    
    func shouldCheckForUpdates() -> Bool {
        let lastCheck = userDefaults.object(forKey: UserDefaultsKeys.lastVersionCheckDate) as? Date ?? Date.distantPast
        let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
        return timeSinceLastCheck >= UserDefaultsKeys.versionCheckInterval
    }
    
    func recordVersionCheck() {
        userDefaults.set(Date(), forKey: UserDefaultsKeys.lastVersionCheckDate)
    }
    
    func hasNotifiedForVersion(_ version: String) -> Bool {
        let lastNotified = userDefaults.string(forKey: UserDefaultsKeys.lastNotifiedVersion) ?? ""
        return lastNotified == version
    }
    
    func recordVersionNotification(_ version: String) {
        userDefaults.set(version, forKey: UserDefaultsKeys.lastNotifiedVersion)
    }
    
    func getVersionInfo() -> [String: Any] {
        var info: [String: Any] = [:]
        
        if let infoPlist = Bundle.main.infoDictionary {
            info["version"] = infoPlist["CFBundleShortVersionString"]
            info["build"] = infoPlist["CFBundleVersion"]
            info["identifier"] = infoPlist["CFBundleIdentifier"]
            info["name"] = infoPlist["CFBundleName"]
        }
        
        info["macOS"] = ProcessInfo.processInfo.operatingSystemVersionString
        info["architecture"] = ProcessInfo.processInfo.machineArchitecture
        
        return info
    }
    
    func checkVersionOnStartup() {
        let currentLaunchCount = userDefaults.integer(forKey: "LaunchCount")
        userDefaults.set(currentLaunchCount + 1, forKey: "LaunchCount")
        
        let isFirstLaunch = currentLaunchCount == 0
        if isFirstLaunch {
            Logger.shared.log("First launch of Sony Recorder Helper \(fullVersionString)")
            userDefaults.set(currentVersion, forKey: "FirstLaunchVersion")
        }
        
        let lastVersion = userDefaults.string(forKey: "LastRunVersion") ?? ""
        if lastVersion != currentVersion {
            Logger.shared.log("Version updated from \(lastVersion.isEmpty ? "new install" : lastVersion) to \(currentVersion)")
            userDefaults.set(currentVersion, forKey: "LastRunVersion")
            
            if !lastVersion.isEmpty && !isFirstLaunch {
                handleVersionUpdate(from: lastVersion, to: currentVersion)
            }
        }
    }
    
    private func handleVersionUpdate(from oldVersion: String, to newVersion: String) {
        Logger.shared.log("Handling version update from \(oldVersion) to \(newVersion)")
        
        NotificationManager.shared.showUpdateNotification(
            title: "Sony Recorder Helper Updated",
            message: "Updated to version \(newVersion). The app is ready to use."
        )
    }
}

private extension ProcessInfo {
    var machineArchitecture: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        return machine ?? "unknown"
    }
}