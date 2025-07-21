# Sony Recorder Helper - Implementation Roadmap

## Phase 1: Project Foundation
**Goal**: Establish Swift project structure and core application skeleton

### Tasks:
1. **Create Xcode Project**
   - New macOS app project targeting macOS 15.0+
   - Configure app bundle identifier and basic info.plist
   - Set up non-sandboxed entitlements for Full Disk Access

2. **Basic Menu Bar Setup**
   - Implement NSStatusBar integration
   - Create basic menu with placeholder items
   - Set up app to run as background-only (LSUIElement)

3. **Project Structure**
   - Define core module architecture
   - Create placeholder classes for major components
   - Set up basic logging framework

**Deliverable**: Working menu bar app that launches and shows basic menu

## Phase 2: Configuration System
**Goal**: Implement persistent settings and configuration UI

### Tasks:
1. **UserDefaults Integration**
   - Create Settings class to manage UserDefaults
   - Define keys for inbox folder and device names
   - Implement getters/setters with sensible defaults

2. **Configuration Menu Items**
   - "Set Inbox Folder" with NSOpenPanel integration
   - "Configure Device Names" with simple text input
   - Display current settings in menu

3. **Settings Validation**
   - Verify inbox folder exists and is writable
   - Validate device name format
   - Show error alerts for invalid configurations

**Deliverable**: Functional configuration system with persistent settings

## Phase 3: Device Monitoring
**Goal**: Detect Sony IC Recorder USB connections

### Tasks:
1. **DiskArbitration Framework Integration**
   - Set up DASession for volume monitoring
   - Create callbacks for mount/unmount events
   - Filter for volumes matching configured device names

2. **Device Detection Logic**
   - Implement volume name matching
   - Verify device is readable
   - Send system notifications when device detected

3. **Device State Management**
   - Track currently connected devices
   - Handle device disconnection gracefully
   - Prevent multiple simultaneous operations

**Deliverable**: Reliable detection of Sony IC Recorder connections

## Phase 4: File Discovery & Scanning
**Goal**: Locate and catalog audio files on connected devices

### Tasks:
1. **File System Traversal**
   - Recursive directory scanning
   - Filter for MP3 and LPCM (.wav) extensions
   - Build list of files to transfer

2. **File Validation**
   - Verify files are readable
   - Check available disk space in inbox
   - Calculate total transfer size

3. **Error Handling**
   - Handle permission errors gracefully
   - Show notifications for scanning issues
   - Skip corrupted or inaccessible files

**Deliverable**: Complete file discovery system for connected devices

## Phase 5: File Transfer Engine
**Goal**: Implement reliable file move operations with verification

### Tasks:
1. **Core Transfer Logic**
   - Sequential file copying to inbox folder
   - Flatten directory structure (ignore source paths)
   - Handle filename conflicts appropriately

2. **Transfer Verification**
   - Implement file integrity checking (size/checksum comparison)
   - Verify successful copy before deletion
   - Roll back on verification failure

3. **Original File Cleanup**
   - Delete source files only after verification
   - Handle deletion errors gracefully
   - Maintain original files if any step fails

**Deliverable**: Robust file transfer system with verification

## Phase 6: Notification System
**Goal**: Keep users informed of transfer progress and issues

### Tasks:
1. **UserNotifications Integration**
   - Request notification permissions at launch
   - Create notification templates for different events
   - Handle user interaction with notifications

2. **Event Notifications**
   - Device detected/disconnected
   - Transfer started/completed with file counts
   - Error conditions with clear descriptions

3. **Notification Management**
   - Prevent notification spam
   - Clear old notifications appropriately
   - Respect system Do Not Disturb settings

**Deliverable**: Complete notification system for all user-facing events

## Phase 7: Launch & Persistence
**Goal**: Ensure app starts with system and runs continuously

### Tasks:
1. **Login Item Registration**
   - Add app to user's login items
   - Handle login item permissions
   - Provide toggle in configuration menu

2. **Background Operation**
   - Ensure app continues running when hidden
   - Handle system sleep/wake cycles
   - Prevent accidental termination

3. **Auto-restart Logic**
   - Monitor for app termination
   - Implement restart mechanism if needed
   - Handle multiple instance prevention

**Deliverable**: Self-maintaining background utility

## Phase 8: Device Ejection & Cleanup
**Goal**: Safely eject devices after successful transfers

### Tasks:
1. **Safe Ejection**
   - Implement proper volume unmounting
   - Verify all file operations complete before ejection
   - Handle ejection failures gracefully

2. **Transfer Completion**
   - Final verification of all transferred files
   - Send completion notification with summary
   - Clean up temporary resources

3. **Error Recovery**
   - Handle partial transfers appropriately
   - Maintain device connection for manual retry
   - Clear messaging about transfer state

**Deliverable**: Complete transfer workflow with safe device ejection

## Phase 9: Testing & Polish
**Goal**: Ensure reliability and user experience quality

### Tasks:
1. **Comprehensive Testing**
   - Test with various Sony IC Recorder models
   - Verify behavior with different file types and sizes
   - Test error conditions and edge cases

2. **Performance Optimization**
   - Optimize file scanning for large devices
   - Minimize CPU usage during monitoring
   - Reduce memory footprint

3. **User Experience Polish**
   - Refine notification timing and content
   - Improve menu organization and clarity
   - Add helpful tooltips and descriptions

**Deliverable**: Production-ready application

## Phase 10: Distribution Preparation
**Goal**: Prepare application for distribution and deployment

### Tasks:
1. **Code Signing & Notarization**
   - Set up Apple Developer account requirements
   - Configure code signing certificates
   - Implement notarization workflow

2. **Installation Package**
   - Create simple installer or app bundle
   - Include setup instructions for Full Disk Access
   - Prepare user documentation

3. **Version Management**
   - Implement version checking
   - Prepare for future manual updates
   - Document release process

**Deliverable**: Distributable application package

## Implementation Notes

### Dependencies
- No external dependencies planned
- Use only system frameworks (DiskArbitration, UserNotifications, AppKit)
- Swift standard library only

### Testing Strategy
- Manual testing with physical Sony IC Recorder devices
- Unit tests for core logic components
- Integration testing for complete workflows

### Risk Mitigation
- Implement comprehensive error handling early
- Test with multiple device types if available
- Plan for edge cases in file system operations

### Success Criteria
- Reliable automatic detection of Sony IC Recorders
- 100% successful file transfers with verification
- Stable background operation without user intervention
- Clear user feedback for all operations and errors