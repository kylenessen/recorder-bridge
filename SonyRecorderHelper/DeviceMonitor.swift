import Foundation
import DiskArbitration
import UserNotifications

protocol DeviceMonitorDelegate: AnyObject {
    func deviceDidConnect(_ device: DetectedDevice)
    func deviceDidDisconnect(_ device: DetectedDevice)
    func deviceScanDidComplete(_ device: DetectedDevice, files: [AudioFile])
    func deviceScanDidFail(_ device: DetectedDevice, error: FileScannerError)
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
    private let fileScanner = FileScanner()
    private let fileTransferEngine = FileTransferEngine()
    
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
        
        fileScanner.delegate = self
        fileTransferEngine.delegate = self
        
        print("Device monitoring started")
    }
    
    func stopMonitoring() {
        guard let session = session else { return }
        
        DASessionUnscheduleFromRunLoop(session, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        self.session = nil
        connectedDevices.removeAll()
        fileScanner.stopScanning()
        
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
            
            fileScanner.scanDevice(device)
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

extension DeviceMonitor: FileScannerDelegate {
    func scanDidStart(for device: DetectedDevice) {
        print("Started scanning device: \(device.volumeName)")
    }
    
    func scanDidComplete(for device: DetectedDevice, files: [AudioFile]) {
        print("Scan completed for \(device.volumeName): found \(files.count) audio files")
        
        if !files.isEmpty {
            let content = UNMutableNotificationContent()
            content.title = "Audio Files Found"
            content.body = "Found \(files.count) audio files on '\(device.volumeName)'. Starting transfer..."
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: "files-found-\(device.deviceIdentifier)",
                content: content,
                trigger: nil
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Failed to send files found notification: \(error)")
                }
            }
            
            Task {
                let _ = await fileTransferEngine.transferFiles(files, from: device)
            }
        } else {
            let content = UNMutableNotificationContent()
            content.title = "No Audio Files"
            content.body = "No audio files found on '\(device.volumeName)'"
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: "no-files-\(device.deviceIdentifier)",
                content: content,
                trigger: nil
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Failed to send no files notification: \(error)")
                }
            }
        }
        
        delegate?.deviceScanDidComplete(device, files: files)
    }
    
    func scanDidFail(for device: DetectedDevice, error: FileScannerError) {
        print("Scan failed for \(device.volumeName): \(error.localizedDescription)")
        
        let content = UNMutableNotificationContent()
        content.title = "Scan Failed"
        content.body = "Could not scan '\(device.volumeName)': \(error.localizedDescription)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "scan-failed-\(device.deviceIdentifier)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send scan failed notification: \(error)")
            }
        }
        
        delegate?.deviceScanDidFail(device, error: error)
    }
}

extension DeviceMonitor: FileTransferEngineDelegate {
    func transferDidStart(for device: DetectedDevice, totalFiles: Int) {
        print("Transfer started for \(device.volumeName): \(totalFiles) files")
        
        let content = UNMutableNotificationContent()
        content.title = "Transfer Started"
        content.body = "Transferring \(totalFiles) files from '\(device.volumeName)'"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "transfer-started-\(device.deviceIdentifier)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send transfer started notification: \(error)")
            }
        }
    }
    
    func transferDidProgress(for device: DetectedDevice, currentFile: Int, totalFiles: Int, fileName: String) {
        print("Transfer progress for \(device.volumeName): \(currentFile)/\(totalFiles) - \(fileName)")
    }
    
    func transferDidComplete(for device: DetectedDevice, result: TransferResult) {
        print("Transfer completed for \(device.volumeName): \(result.transferredCount) files transferred, success: \(result.success)")
        
        let content = UNMutableNotificationContent()
        
        if result.success {
            content.title = "Transfer Complete"
            content.body = "Successfully transferred \(result.transferredCount) files from '\(device.volumeName)'"
            content.sound = .default
        } else {
            content.title = "Transfer Completed with Errors"
            let errorCount = result.errors.count
            content.body = "Transferred \(result.transferredCount) files from '\(device.volumeName)' with \(errorCount) errors"
            content.sound = .default
        }
        
        let request = UNNotificationRequest(
            identifier: "transfer-complete-\(device.deviceIdentifier)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send transfer complete notification: \(error)")
            }
        }
    }
    
    func transferDidFail(for device: DetectedDevice, error: TransferError) {
        print("Transfer failed for \(device.volumeName): \(error.localizedDescription)")
        
        let content = UNMutableNotificationContent()
        content.title = "Transfer Failed"
        content.body = "Transfer from '\(device.volumeName)' failed: \(error.localizedDescription)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "transfer-failed-\(device.deviceIdentifier)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send transfer failed notification: \(error)")
            }
        }
    }
}