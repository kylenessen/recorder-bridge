import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusBarItem: NSStatusItem!
    private let settings = Settings()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusBar()
        updateMenu()
        
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        
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
        guard let menu = statusBarItem.menu else { return }
        
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
        
        let statusText = settings.isConfigurationValid() ? "Status: Ready" : "Status: Configuration needed"
        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        newMenu.addItem(statusItem)
        
        newMenu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Sony Recorder Helper", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        newMenu.addItem(quitItem)
        
        statusBarItem.menu = newMenu
    }
}