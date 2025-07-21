import Foundation
import UserNotifications

enum NotificationCategory {
    case deviceDetected
    case deviceDisconnected
    case scanStarted
    case scanCompleted
    case scanFailed
    case transferStarted
    case transferProgress
    case transferCompleted
    case transferFailed
    case error
}

class NotificationManager: NSObject {
    static let shared = NotificationManager()
    
    private var permissionsGranted = false
    private var activeNotifications: Set<String> = []
    private let maxActiveNotifications = 5
    
    override init() {
        super.init()
        setupNotificationCenter()
        requestNotificationPermissions()
    }
    
    private func setupNotificationCenter() {
        UNUserNotificationCenter.current().delegate = self
    }
    
    private func requestNotificationPermissions() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.permissionsGranted = granted
                if granted {
                    print("Notification permissions granted")
                } else if let error = error {
                    print("Notification permission error: \(error)")
                } else {
                    print("Notification permissions denied by user")
                }
            }
        }
    }
    
    func sendDeviceNotification(device: DetectedDevice, connected: Bool) {
        let category: NotificationCategory = connected ? .deviceDetected : .deviceDisconnected
        let title = connected ? "Sony Recorder Detected" : "Sony Recorder Disconnected"
        let body = connected ? 
            "Device '\(device.volumeName)' connected and ready for file transfer" :
            "Device '\(device.volumeName)' has been disconnected"
        
        let identifier = "\(category)-\(device.deviceIdentifier)"
        sendNotification(title: title, body: body, identifier: identifier, category: category)
    }
    
    func sendScanNotification(device: DetectedDevice, status: String, fileCount: Int? = nil, error: String? = nil) {
        var title: String
        var body: String
        var category: NotificationCategory
        
        switch status {
        case "started":
            title = "Scanning Device"
            body = "Scanning '\(device.volumeName)' for audio files..."
            category = .scanStarted
        case "completed":
            let count = fileCount ?? 0
            title = count > 0 ? "Audio Files Found" : "No Audio Files"
            body = count > 0 ? 
                "Found \(count) audio files on '\(device.volumeName)'. Starting transfer..." :
                "No audio files found on '\(device.volumeName)'"
            category = .scanCompleted
        case "failed":
            title = "Scan Failed"
            body = "Could not scan '\(device.volumeName)': \(error ?? "Unknown error")"
            category = .scanFailed
        default:
            return
        }
        
        let identifier = "\(category)-\(device.deviceIdentifier)"
        sendNotification(title: title, body: body, identifier: identifier, category: category)
    }
    
    func sendTransferNotification(device: DetectedDevice, status: String, currentFile: Int? = nil, totalFiles: Int? = nil, fileName: String? = nil, result: TransferResult? = nil, error: String? = nil) {
        var title: String
        var body: String
        var category: NotificationCategory
        
        switch status {
        case "started":
            let count = totalFiles ?? 0
            title = "Transfer Started"
            body = "Transferring \(count) files from '\(device.volumeName)'"
            category = .transferStarted
        case "progress":
            guard let current = currentFile, let total = totalFiles, let file = fileName else { return }
            title = "Transferring Files"
            body = "\(current)/\(total): \(file)"
            category = .transferProgress
        case "completed":
            guard let result = result else { return }
            if result.success {
                title = "Transfer Complete"
                body = "Successfully transferred \(result.transferredCount) files from '\(device.volumeName)'"
            } else {
                title = "Transfer Completed with Errors"
                let errorCount = result.errors.count
                body = "Transferred \(result.transferredCount) files from '\(device.volumeName)' with \(errorCount) errors"
            }
            category = .transferCompleted
        case "failed":
            title = "Transfer Failed"
            body = "Transfer from '\(device.volumeName)' failed: \(error ?? "Unknown error")"
            category = .transferFailed
        default:
            return
        }
        
        let identifier = "\(category)-\(device.deviceIdentifier)"
        
        if category == .transferProgress {
            sendNotification(title: title, body: body, identifier: identifier, category: category, sound: false)
        } else {
            sendNotification(title: title, body: body, identifier: identifier, category: category)
        }
    }
    
    func sendErrorNotification(title: String, message: String) {
        let identifier = "error-\(Date().timeIntervalSince1970)"
        sendNotification(title: title, body: message, identifier: identifier, category: .error)
    }
    
    private func sendNotification(title: String, body: String, identifier: String, category: NotificationCategory, sound: Bool = true) {
        guard permissionsGranted else {
            print("Notification not sent - permissions not granted: \(title)")
            return
        }
        
        cleanupOldNotifications()
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = String(describing: category)
        
        if sound {
            content.sound = .default
        }
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                print("Failed to send notification '\(title)': \(error)")
            } else {
                self?.activeNotifications.insert(identifier)
            }
        }
    }
    
    private func cleanupOldNotifications() {
        if activeNotifications.count >= maxActiveNotifications {
            let center = UNUserNotificationCenter.current()
            center.getDeliveredNotifications { [weak self] notifications in
                guard let self = self else { return }
                
                let oldNotifications = notifications
                    .sorted { $0.date < $1.date }
                    .prefix(notifications.count - self.maxActiveNotifications + 1)
                
                let identifiersToRemove = oldNotifications.map { $0.request.identifier }
                center.removeDeliveredNotifications(withIdentifiers: identifiersToRemove)
                
                DispatchQueue.main.async {
                    for identifier in identifiersToRemove {
                        self.activeNotifications.remove(identifier)
                    }
                }
            }
        }
    }
    
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        activeNotifications.removeAll()
    }
    
    func clearNotifications(withPrefix prefix: String) {
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let identifiersToRemove = notifications
                .map { $0.request.identifier }
                .filter { $0.hasPrefix(prefix) }
            
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiersToRemove)
            
            DispatchQueue.main.async { [weak self] in
                for identifier in identifiersToRemove {
                    self?.activeNotifications.remove(identifier)
                }
            }
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        print("User interacted with notification: \(identifier)")
        
        activeNotifications.remove(identifier)
        
        completionHandler()
    }
}