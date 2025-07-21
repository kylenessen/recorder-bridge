import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusBarItem: NSStatusItem!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusBar()
        setupMenu()
        
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
    
    private func setupMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Sony Recorder Helper", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        let configureInboxItem = NSMenuItem(title: "Set Inbox Folder...", action: #selector(configureInboxFolder), keyEquivalent: "")
        configureInboxItem.target = self
        menu.addItem(configureInboxItem)
        
        let configureDeviceItem = NSMenuItem(title: "Configure Device Names...", action: #selector(configureDeviceNames), keyEquivalent: "")
        configureDeviceItem.target = self
        menu.addItem(configureDeviceItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let statusItem = NSMenuItem(title: "Status: Ready", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Sony Recorder Helper", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusBarItem.menu = menu
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
                    UserDefaults.standard.set(url.path, forKey: "inboxFolder")
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
        textField.stringValue = UserDefaults.standard.string(forKey: "deviceNames") ?? "IC Recorder"
        alert.accessoryView = textField
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            UserDefaults.standard.set(textField.stringValue, forKey: "deviceNames")
            print("Device names set to: \(textField.stringValue)")
        }
    }
}