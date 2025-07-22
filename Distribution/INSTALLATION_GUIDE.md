# Sony Recorder Helper - Installation Guide

Sony Recorder Helper is a macOS menu bar utility that automatically transfers audio files from Sony IC Recorders to your designated inbox folder.

## System Requirements

- **macOS 15.0** or later
- **Full Disk Access** permissions (required for device access)
- Sony IC Recorder device with USB connection

## Installation Methods

### Option 1: Simple Installation (Recommended)

1. **Download** the `SonyRecorderHelper.dmg` file
2. **Double-click** the DMG file to mount it
3. **Drag** Sony Recorder Helper to your Applications folder
4. **Eject** the DMG file
5. **Continue to Setup** (see below)

### Option 2: Package Installer

1. **Download** the `SonyRecorderHelper-Installer.pkg` file
2. **Double-click** the installer package
3. **Follow** the installation wizard prompts
4. **Enter** your administrator password when prompted
5. **Continue to Setup** (see below)

## Initial Setup

### Step 1: Grant Full Disk Access

Sony Recorder Helper requires Full Disk Access to read files from your Sony IC Recorder.

1. **Open** System Settings (System Preferences on older macOS)
2. **Navigate** to Privacy & Security → Full Disk Access
3. **Click** the lock icon and enter your password
4. **Click** the + button to add an application
5. **Navigate** to Applications and select Sony Recorder Helper
6. **Ensure** the checkbox next to Sony Recorder Helper is checked
7. **Close** System Settings

> **Why Full Disk Access?** Sony IC Recorders appear as external USB drives. macOS requires Full Disk Access permission to read files from external storage devices automatically.

### Step 2: First Launch

1. **Launch** Sony Recorder Helper from Applications
2. **Right-click** the menu bar icon (🎵 or similar)
3. **Select** "Set Inbox Folder" to choose where files will be transferred
4. **Optionally** configure device names if your recorder has a different name

### Step 3: Test the Connection

1. **Connect** your Sony IC Recorder to your Mac via USB
2. **Wait** for the device detection notification
3. **Files** will automatically transfer to your inbox folder
4. **Notification** will confirm when transfer is complete

## Configuration Options

Access configuration by right-clicking the menu bar icon:

### Inbox Folder
- **Purpose**: Destination folder for transferred audio files
- **Default**: Documents folder
- **Recommendation**: Create a dedicated "Audio Recordings" folder

### Device Names
- **Purpose**: Customize which USB volumes to monitor
- **Default**: "IC Recorder"
- **Note**: Some Sony models may have different volume names

## Troubleshooting

### App Won't Start
- **Check**: macOS version compatibility (15.0+ required)
- **Verify**: Full Disk Access permission is granted
- **Try**: Restart the app after granting permissions

### Device Not Detected
- **Verify**: USB connection is secure
- **Check**: Device name matches configuration
- **Ensure**: Device is powered on and not in recording mode
- **Test**: Device appears in Finder when connected

### Files Not Transferring
- **Confirm**: Inbox folder is accessible and writable
- **Check**: Sufficient disk space available
- **Verify**: Files are MP3 or LPCM (.wav) format
- **Look for**: Error notifications with specific details

### Permission Issues
- **Re-grant**: Full Disk Access permission
- **Restart**: Sony Recorder Helper after permission changes
- **Check**: macOS security settings haven't changed

## Security & Privacy

### What Permissions Are Used
- **Full Disk Access**: Required to read files from USB devices
- **Notifications**: Optional, for transfer status updates
- **Files & Folders**: Access to your chosen inbox folder

### Data Handling
- **No Internet**: App operates completely offline
- **No Data Collection**: No usage analytics or personal data collected
- **Local Only**: All operations happen on your Mac

### Code Signing & Notarization
- **Developer ID**: App is signed with Apple Developer ID
- **Notarized**: Verified by Apple for security
- **Gatekeeper**: Passes all macOS security checks

## Advanced Configuration

### Auto-Start at Login
Sony Recorder Helper automatically adds itself to login items. To disable:
1. Open System Settings → General → Login Items
2. Find Sony Recorder Helper in the list
3. Toggle off or remove the entry

### Folder Structure
- **Source**: Files maintain original names from recorder
- **Destination**: All files placed directly in inbox folder (flattened)
- **Conflicts**: Duplicate names handled by Finder (numbered copies)

## Getting Help

### Built-in Help
- Right-click menu bar icon for quick options
- Notification messages provide specific error details

### Common File Transfer Issues
- **Partial Transfer**: Disconnect interrupted transfer, reconnect to retry
- **Verification Failed**: Original files preserved on recorder for safety
- **Disk Full**: Clear space in inbox folder and reconnect device

### Support Resources
- Check System Console for detailed error messages
- Use Activity Monitor to verify app is running
- Test with minimal setup (single small file)

## Uninstallation

### Complete Removal
1. **Quit** Sony Recorder Helper (right-click → Quit)
2. **Remove** from Applications folder
3. **Clean up** login items in System Settings
4. **Optionally** remove Full Disk Access permission
5. **Settings** are automatically cleaned up

### Partial Removal (Keep Settings)
1. **Move** app to Trash
2. **Keep** login item and permissions for future reinstallation

---

**Version**: 1.0  
**Compatibility**: macOS 15.0+  
**Last Updated**: 2025