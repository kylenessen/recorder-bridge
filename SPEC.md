# Sony Recorder Helper - Complete Specification

## Overview
A macOS menu bar utility that automatically transfers audio files from a Sony IC Recorder to a designated inbox folder when the device is connected.

## Core Functionality

### Device Monitoring
- Monitor for USB volumes named "IC Recorder" (configurable)
- Detect device connection automatically
- Send notification when device is detected

### File Transfer
- **File Types**: MP3 and LPCM (.wav) files
- **Operation**: Move files (copy to inbox, then delete from recorder)
- **Structure**: Flatten all files into inbox folder (ignore source folder hierarchy)
- **Verification**: Verify each file transfer before deleting original
- **Transfer Method**: Sequential/queued transfers for maximum reliability

### Error Handling
- **Transfer Failure**: Show notification, preserve original files on recorder
- **Insufficient Disk Space**: Show error notification, abort transfer
- **Device Disconnection**: Show notification, user will manually retry
- **No Automatic Retries**

### User Interface
- **Menu Bar Icon**: Always visible
- **Right-Click Menu**:
  - Configure inbox folder location
  - Configure device name(s) to monitor
  - Quit application
- **Notifications**:
  - Device detected
  - Transfer complete (with file count)
  - Any errors

### Configuration
- **Persistent Settings**: All settings saved between sessions
- **Configurable Options**:
  - Inbox folder location
  - Device name(s) to monitor

## Technical Requirements

### Platform
- **OS**: macOS 15.0 or later
- **Language**: Swift
- **Architecture**: Menu bar application
- **Permissions**: Full Disk Access (no sandboxing)

### Launch Behavior
- Start automatically at login
- Run continuously in background
- Cannot be permanently quit (relaunch if terminated)

### File Operations
1. Scan entire recorder volume for MP3 and LPCM files
2. Copy each file to inbox folder
3. Verify successful copy (checksum or byte comparison)
4. Delete original only after verification
5. Eject device after all transfers complete

### Implementation Notes
- Single device support only (no concurrent device handling)
- No file size limits
- No progress indicators
- No transfer history or logs
- No pause/cancel functionality
- Manual updates only

## Excluded Features
- Multiple device support
- Folder structure preservation
- Duplicate file handling (recorder handles this)
- File exclusion options
- Dry run mode
- Progress bars
- Transfer logs
- Automatic retries
- Advanced security features