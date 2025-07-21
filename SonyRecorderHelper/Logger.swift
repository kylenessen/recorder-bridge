import Foundation
import os.log

class Logger {
    private let log = OSLog(subsystem: "com.recorder.bridge.SonyRecorderHelper", category: "general")
    
    static let shared = Logger()
    
    private init() {}
    
    func info(_ message: String) {
        os_log("%{public}@", log: log, type: .info, message)
    }
    
    func error(_ message: String) {
        os_log("%{public}@", log: log, type: .error, message)
    }
    
    func debug(_ message: String) {
        os_log("%{public}@", log: log, type: .debug, message)
    }
    
    func warning(_ message: String) {
        os_log("%{public}@", log: log, type: .default, message)
    }
}