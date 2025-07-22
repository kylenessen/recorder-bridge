import Cocoa
import UserNotifications
import ServiceManagement

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusBarItem: NSStatusItem!
    private let settings = Settings()
    private var deviceMonitor: DeviceMonitor!
    private var terminationObserver: NSObjectProtocol?
    private let versionChecker = VersionChecker()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusBar()
        setupDeviceMonitoring()
        requestNotificationPermissions()
        setupLaunchAndPersistence()
        versionChecker.checkVersionOnStartup()
        updateMenu()
        
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        deviceMonitor.stopMonitoring()
        cleanupPersistence()
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
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Sony Recorder Helper"
        alert.informativeText = """
        Version \(versionChecker.fullVersionString)
        
        Automatically transfers audio files from Sony IC Recorders to your designated inbox folder.
        
        • Monitors for connected Sony IC Recorder devices
        • Transfers MP3 and LPCM audio files
        • Verifies file integrity before cleanup
        • Runs continuously in the background
        
        System Requirements:
        • macOS 15.0 or later
        • Full Disk Access permission
        
        Copyright © 2025. All rights reserved.
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
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
        
        let loginItemsItem = NSMenuItem(title: getLoginItemsMenuTitle(), action: #selector(toggleLoginItem), keyEquivalent: "")
        loginItemsItem.target = self
        newMenu.addItem(loginItemsItem)
        
        newMenu.addItem(NSMenuItem.separator())
        
        let aboutItem = NSMenuItem(title: "About Sony Recorder Helper", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        newMenu.addItem(aboutItem)
        
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
    
    // MARK: - Launch & Persistence
    
    private func setupLaunchAndPersistence() {
        setupBackgroundOperation()
        setupAutoRestart()
        
        // Register login item if it's the first launch or user preference
        if settings.shouldStartAtLogin && !isLoginItemRegistered() {
            registerLoginItem()
        }
    }
    
    private func setupBackgroundOperation() {
        // Prevent app from terminating when all windows are closed
        NSApp.setActivationPolicy(.accessory)
        
        // Handle system sleep/wake cycles
        let workspace = NSWorkspace.shared
        let notificationCenter = workspace.notificationCenter
        
        notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        
        notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }
    
    private func setupAutoRestart() {
        // Monitor for unexpected termination and setup restart mechanism
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppTermination()
        }
    }
    
    private func cleanupPersistence() {
        // Remove observers
        if let observer = terminationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    @objc private func systemWillSleep() {
        print("System going to sleep - pausing monitoring")
        deviceMonitor.stopMonitoring()
    }
    
    @objc private func systemDidWake() {
        print("System woke up - resuming monitoring")
        deviceMonitor.startMonitoring()
    }
    
    private func handleAppTermination() {
        // This could be expanded to implement restart logic if needed
        print("App is terminating")
    }
    
    // MARK: - Login Item Management
    
    @objc private func toggleLoginItem() {
        if isLoginItemRegistered() {
            unregisterLoginItem()
        } else {
            registerLoginItem()
        }
        updateMenu()
    }
    
    private func getLoginItemsMenuTitle() -> String {
        return isLoginItemRegistered() ? "Remove from Login Items" : "Add to Login Items"
    }
    
    private func isLoginItemRegistered() -> Bool {
        if #available(macOS 13.0, *) {
            // Use modern SMAppService API for macOS 13+
            guard Bundle.main.bundleIdentifier != nil else {
                return false
            }
            let service = SMAppService.mainApp
            return service.status == .enabled
        } else {
            // Fall back to deprecated API for older macOS versions
            guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
                return false
            }
            
            let jobDict = SMCopyAllJobDictionaries(kSMDomainUserLaunchd)?.takeRetainedValue() as? [[String: Any]]
            
            return jobDict?.contains { job in
                guard let label = job["Label"] as? String,
                      let onDemand = job["OnDemand"] as? Bool else {
                    return false
                }
                return label == bundleIdentifier && !onDemand
            } ?? false
        }
    }
    
    private func registerLoginItem() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            print("Failed to get bundle identifier for login item registration")
            return
        }
        
        if #available(macOS 13.0, *) {
            // Use modern SMAppService API for macOS 13+
            let service = SMAppService.mainApp
            do {
                try service.register()
                settings.shouldStartAtLogin = true
                print("Successfully registered login item with SMAppService")
            } catch {
                print("Failed to register login item with SMAppService: \(error)")
                showLoginItemError(isRegistering: true)
            }
        } else {
            // Fall back to deprecated API for older macOS versions
            let success = SMLoginItemSetEnabled(bundleIdentifier as CFString, true)
            if success {
                settings.shouldStartAtLogin = true
                print("Successfully registered login item with legacy API")
            } else {
                print("Failed to register login item with legacy API")
                showLoginItemError(isRegistering: true)
            }
        }
    }
    
    private func unregisterLoginItem() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            print("Failed to get bundle identifier for login item unregistration")
            return
        }
        
        if #available(macOS 13.0, *) {
            // Use modern SMAppService API for macOS 13+
            let service = SMAppService.mainApp
            do {
                try service.unregister()
                settings.shouldStartAtLogin = false
                print("Successfully unregistered login item with SMAppService")
            } catch {
                print("Failed to unregister login item with SMAppService: \(error)")
                showLoginItemError(isRegistering: false)
            }
        } else {
            // Fall back to deprecated API for older macOS versions
            let success = SMLoginItemSetEnabled(bundleIdentifier as CFString, false)
            if success {
                settings.shouldStartAtLogin = false
                print("Successfully unregistered login item with legacy API")
            } else {
                print("Failed to unregister login item with legacy API")
                showLoginItemError(isRegistering: false)
            }
        }
    }
    
    private func showLoginItemError(isRegistering: Bool) {
        let alert = NSAlert()
        alert.messageText = "Login Item Error"
        alert.informativeText = isRegistering 
            ? "Failed to add Sony Recorder Helper to login items. You may need to grant permission in System Preferences > Privacy & Security > Login Items."
            : "Failed to remove Sony Recorder Helper from login items. You can manually remove it in System Preferences > Privacy & Security > Login Items."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
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