import Foundation
import DiskArbitration
import UserNotifications

protocol DeviceMonitorDelegate: AnyObject {
    func deviceDidConnect(_ device: DetectedDevice)
    func deviceDidDisconnect(_ device: DetectedDevice)
}

struct DetectedDevice {
    let volumePath: String
    let volumeName: String
    let deviceIdentifier: String
}

class DeviceMonitor {
    weak var delegate: DeviceMonitorDelegate?
    private var session: DASession?
    private var connectedDevices: [String: DetectedDevice] = [:]
    private let settings = Settings()
    
    func startMonitoring() {
        guard session == nil else { return }
        
        session = DASessionCreate(kCFAllocatorDefault)
        guard let session = session else {
            print("Failed to create DiskArbitration session")
            return
        }
        
        let context = Unmanaged.passUnretained(self).toOpaque()
        
        DARegisterDiskAppearedCallback(session, nil, diskAppearedCallback, context)
        DARegisterDiskDisappearedCallback(session, nil, diskDisappearedCallback, context)
        
        DASessionScheduleWithRunLoop(session, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        
        print("Device monitoring started")
    }
    
    func stopMonitoring() {
        guard let session = session else { return }
        
        DASessionUnscheduleFromRunLoop(session, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        self.session = nil
        connectedDevices.removeAll()
        
        print("Device monitoring stopped")
    }
    
    fileprivate func handleDiskAppeared(_ disk: DADisk) {
        guard let diskDescription = DADiskCopyDescription(disk) as? [String: Any] else { return }
        
        guard let volumeName = diskDescription[kDADiskDescriptionVolumeNameKey as String] as? String,
              let volumePath = diskDescription[kDADiskDescriptionVolumePathKey as String] as? URL else {
            return
        }
        
        let deviceNames = settings.deviceNames
        let matchesConfiguredDevice = deviceNames.contains { deviceName in
            volumeName.localizedCaseInsensitiveContains(deviceName)
        }
        
        if matchesConfiguredDevice {
            let device = DetectedDevice(
                volumePath: volumePath.path,
                volumeName: volumeName,
                deviceIdentifier: volumePath.path
            )
            
            connectedDevices[device.deviceIdentifier] = device
            
            print("Sony recorder detected: \(volumeName) at \(volumePath.path)")
            
            sendDeviceDetectedNotification(device: device)
            delegate?.deviceDidConnect(device)
        }
    }
    
    fileprivate func handleDiskDisappeared(_ disk: DADisk) {
        guard let diskDescription = DADiskCopyDescription(disk) as? [String: Any] else { return }
        
        guard let volumePath = diskDescription[kDADiskDescriptionVolumePathKey as String] as? URL else {
            return
        }
        
        let deviceIdentifier = volumePath.path
        
        if let device = connectedDevices.removeValue(forKey: deviceIdentifier) {
            print("Sony recorder disconnected: \(device.volumeName)")
            
            sendDeviceDisconnectedNotification(device: device)
            delegate?.deviceDidDisconnect(device)
        }
    }
    
    private func sendDeviceDetectedNotification(device: DetectedDevice) {
        let content = UNMutableNotificationContent()
        content.title = "Sony Recorder Detected"
        content.body = "Device '\(device.volumeName)' connected and ready for file transfer"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "device-detected-\(device.deviceIdentifier)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send device detected notification: \(error)")
            }
        }
    }
    
    private func sendDeviceDisconnectedNotification(device: DetectedDevice) {
        let content = UNMutableNotificationContent()
        content.title = "Sony Recorder Disconnected"
        content.body = "Device '\(device.volumeName)' has been disconnected"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "device-disconnected-\(device.deviceIdentifier)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send device disconnected notification: \(error)")
            }
        }
    }
    
    func getConnectedDevices() -> [DetectedDevice] {
        return Array(connectedDevices.values)
    }
    
    func isDeviceConnected() -> Bool {
        return !connectedDevices.isEmpty
    }
}

private func diskAppearedCallback(disk: DADisk, context: UnsafeMutableRawPointer?) {
    guard let context = context else { return }
    let monitor = Unmanaged<DeviceMonitor>.fromOpaque(context).takeUnretainedValue()
    monitor.handleDiskAppeared(disk)
}

private func diskDisappearedCallback(disk: DADisk, context: UnsafeMutableRawPointer?) {
    guard let context = context else { return }
    let monitor = Unmanaged<DeviceMonitor>.fromOpaque(context).takeUnretainedValue()
    monitor.handleDiskDisappeared(disk)
}