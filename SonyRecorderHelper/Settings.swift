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
        
        return errors
    }
}