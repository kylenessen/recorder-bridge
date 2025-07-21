import Cocoa
import UserNotifications

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusBarItem: NSStatusItem!
    private let settings = Settings()
    private var deviceMonitor: DeviceMonitor!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusBar()
        setupDeviceMonitoring()
        requestNotificationPermissions()
        updateMenu()
        
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        deviceMonitor.stopMonitoring()
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "externaldrive", accessibilityDescription: "Sony Recorder Helper")
            button.image?.isTemplate = true
        }
    }
    
    @objc private func configureInboxFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.message = "Choose inbox folder for transferred audio files"
        
        openPanel.begin { response in
            if response == .OK {
                if let url = openPanel.url {
                    self.settings.inboxFolder = url.path
                    self.validateAndShowErrors()
                    self.updateMenu()
                    print("Inbox folder set to: \(url.path)")
                }
            }
        }
    }
    
    @objc private func configureDeviceNames() {
        let alert = NSAlert()
        alert.messageText = "Configure Device Names"
        alert.informativeText = "Enter device names to monitor (comma-separated):"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = settings.getDeviceNamesDisplayString()
        alert.accessoryView = textField
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let deviceNamesArray = textField.stringValue.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            settings.deviceNames = deviceNamesArray
            validateAndShowErrors()
            updateMenu()
            print("Device names set to: \(textField.stringValue)")
        }
    }
    
    private func validateAndShowErrors() {
        let errors = settings.validateSettings()
        if !errors.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Configuration Error"
            alert.informativeText = errors.joined(separator: "\n")
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    private func updateMenu() {
        guard statusBarItem.menu != nil else { return }
        
        let newMenu = NSMenu()
        
        newMenu.addItem(NSMenuItem(title: "Sony Recorder Helper", action: nil, keyEquivalent: ""))
        newMenu.addItem(NSMenuItem.separator())
        
        let configureInboxItem = NSMenuItem(title: "Set Inbox Folder...", action: #selector(configureInboxFolder), keyEquivalent: "")
        configureInboxItem.target = self
        newMenu.addItem(configureInboxItem)
        
        let inboxStatusItem = NSMenuItem(title: "Inbox: \(settings.getInboxFolderDisplayName())", action: nil, keyEquivalent: "")
        inboxStatusItem.isEnabled = false
        newMenu.addItem(inboxStatusItem)
        
        newMenu.addItem(NSMenuItem.separator())
        
        let configureDeviceItem = NSMenuItem(title: "Configure Device Names...", action: #selector(configureDeviceNames), keyEquivalent: "")
        configureDeviceItem.target = self
        newMenu.addItem(configureDeviceItem)
        
        let deviceStatusItem = NSMenuItem(title: "Devices: \(settings.getDeviceNamesDisplayString())", action: nil, keyEquivalent: "")
        deviceStatusItem.isEnabled = false
        newMenu.addItem(deviceStatusItem)
        
        newMenu.addItem(NSMenuItem.separator())
        
        let configurationValid = settings.isConfigurationValid()
        let deviceConnected = deviceMonitor?.isDeviceConnected() ?? false
        
        let statusText: String
        if !configurationValid {
            statusText = "Status: Configuration needed"
        } else if deviceConnected {
            let devices = deviceMonitor?.getConnectedDevices() ?? []
            if devices.count == 1 {
                statusText = "Status: Device connected (\(devices[0].volumeName))"
            } else {
                statusText = "Status: \(devices.count) devices connected"
            }
        } else {
            statusText = "Status: Ready - waiting for device"
        }
        
        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        newMenu.addItem(statusItem)
        
        newMenu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Sony Recorder Helper", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        newMenu.addItem(quitItem)
        
        statusBarItem.menu = newMenu
    }
    
    private func setupDeviceMonitoring() {
        deviceMonitor = DeviceMonitor()
        deviceMonitor.delegate = self
        deviceMonitor.startMonitoring()
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Failed to request notification permissions: \(error)")
            } else if granted {
                print("Notification permissions granted")
            } else {
                print("Notification permissions denied")
            }
        }
    }
}

extension AppDelegate: DeviceMonitorDelegate {
    func deviceDidConnect(_ device: DetectedDevice) {
        DispatchQueue.main.async {
            self.updateMenu()
            print("Device connected delegate called: \(device.volumeName)")
        }
    }
    
    func deviceDidDisconnect(_ device: DetectedDevice) {
        DispatchQueue.main.async {
            self.updateMenu()
            print("Device disconnected delegate called: \(device.volumeName)")
        }
    }
    
    func deviceScanDidComplete(_ device: DetectedDevice, files: [AudioFile]) {
        DispatchQueue.main.async {
            self.updateMenu()
            print("Device scan completed: \(device.volumeName) - \(files.count) files found")
        }
    }
    
    func deviceScanDidFail(_ device: DetectedDevice, error: FileScannerError) {
        DispatchQueue.main.async {
            self.updateMenu()
            print("Device scan failed: \(device.volumeName) - \(error.localizedDescription)")
        }
    }
}