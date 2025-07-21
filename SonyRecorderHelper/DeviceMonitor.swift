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
    private let notificationManager = NotificationManager.shared
    
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
            
            notificationManager.sendDeviceNotification(device: device, connected: true)
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
            
            notificationManager.sendDeviceNotification(device: device, connected: false)
            delegate?.deviceDidDisconnect(device)
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
        notificationManager.sendScanNotification(device: device, status: "started")
    }
    
    func scanDidComplete(for device: DetectedDevice, files: [AudioFile]) {
        print("Scan completed for \(device.volumeName): found \(files.count) audio files")
        
        notificationManager.sendScanNotification(device: device, status: "completed", fileCount: files.count)
        
        if !files.isEmpty {
            Task {
                let _ = await fileTransferEngine.transferFiles(files, from: device)
            }
        }
        
        delegate?.deviceScanDidComplete(device, files: files)
    }
    
    func scanDidFail(for device: DetectedDevice, error: FileScannerError) {
        print("Scan failed for \(device.volumeName): \(error.localizedDescription)")
        
        notificationManager.sendScanNotification(device: device, status: "failed", error: error.localizedDescription)
        
        delegate?.deviceScanDidFail(device, error: error)
    }
}

extension DeviceMonitor: FileTransferEngineDelegate {
    func transferDidStart(for device: DetectedDevice, totalFiles: Int) {
        print("Transfer started for \(device.volumeName): \(totalFiles) files")
        notificationManager.sendTransferNotification(device: device, status: "started", totalFiles: totalFiles)
    }
    
    func transferDidProgress(for device: DetectedDevice, currentFile: Int, totalFiles: Int, fileName: String) {
        print("Transfer progress for \(device.volumeName): \(currentFile)/\(totalFiles) - \(fileName)")
        notificationManager.sendTransferNotification(device: device, status: "progress", currentFile: currentFile, totalFiles: totalFiles, fileName: fileName)
    }
    
    func transferDidComplete(for device: DetectedDevice, result: TransferResult) {
        print("Transfer completed for \(device.volumeName): \(result.transferredCount) files transferred, success: \(result.success)")
        notificationManager.sendTransferNotification(device: device, status: "completed", result: result)
    }
    
    func transferDidFail(for device: DetectedDevice, error: TransferError) {
        print("Transfer failed for \(device.volumeName): \(error.localizedDescription)")
        notificationManager.sendTransferNotification(device: device, status: "failed", error: error.localizedDescription)
    }
}