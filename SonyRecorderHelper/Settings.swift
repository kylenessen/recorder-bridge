import Foundation

class Settings {
    private let defaults = UserDefaults.standard
    
    var inboxFolder: String? {
        get { defaults.string(forKey: "inboxFolder") }
        set { defaults.set(newValue, forKey: "inboxFolder") }
    }
    
    var deviceNames: [String] {
        get {
            let namesString = defaults.string(forKey: "deviceNames") ?? "IC Recorder"
            return namesString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        set {
            let namesString = newValue.joined(separator: ", ")
            defaults.set(namesString, forKey: "deviceNames")
        }
    }
    
    var autoStartEnabled: Bool {
        get { defaults.bool(forKey: "autoStartEnabled") }
        set { defaults.set(newValue, forKey: "autoStartEnabled") }
    }
    
    func validateSettings() -> [String] {
        var errors: [String] = []
        
        if let inboxPath = inboxFolder {
            let inboxURL = URL(fileURLWithPath: inboxPath)
            
            if !FileManager.default.fileExists(atPath: inboxPath) {
                errors.append("Inbox folder does not exist: \(inboxPath)")
            } else {
                if !FileManager.default.isWritableFile(atPath: inboxPath) {
                    errors.append("Inbox folder is not writable: \(inboxPath)")
                }
            }
        } else {
            errors.append("No inbox folder configured")
        }
        
        if deviceNames.isEmpty {
            errors.append("No device names configured")
        } else {
            for deviceName in deviceNames {
                if deviceName.trimmingCharacters(in: .whitespaces).isEmpty {
                    errors.append("Device name cannot be empty")
                }
            }
        }
        
        return errors
    }
    
    func isConfigurationValid() -> Bool {
        return validateSettings().isEmpty
    }
    
    func getInboxFolderDisplayName() -> String {
        if let inboxPath = inboxFolder {
            return URL(fileURLWithPath: inboxPath).lastPathComponent
        }
        return "Not set"
    }
    
    func getDeviceNamesDisplayString() -> String {
        if deviceNames.isEmpty {
            return "None configured"
        }
        return deviceNames.joined(separator: ", ")
    }
}