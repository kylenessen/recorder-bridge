# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Sony Recorder Helper** is a macOS menu bar utility that automatically transfers audio files from Sony IC Recorders to a designated inbox folder. This is currently a specification-only project with no implementation code yet.

## Development Setup

This project will be implemented in Swift for macOS 15.0+. When implementation begins:

1. Create Xcode project or Swift Package Manager setup
2. Target: macOS app bundle with menu bar interface
3. Required permissions: Full Disk Access (non-sandboxed)

## Architecture

The application follows a simple menu bar utility pattern:

- **Device Monitoring**: USB volume detection for "IC Recorder" devices using DiskArbitration framework
- **File Transfer Engine**: Sequential file operations (MP3/LPCM files) with verification
- **Menu Bar UI**: NSStatusBar with right-click configuration menu
- **Configuration**: UserDefaults for persistent settings (inbox folder, device names)
- **Notifications**: UserNotifications framework for status updates

## Key Implementation Requirements

- **File Transfer**: Move operation (copy + verify + delete) with no progress indicators
- **Error Handling**: Show notifications, no automatic retries
- **Launch Behavior**: Auto-start at login, continuous background operation
- **Single Device**: No concurrent device handling
- **Flatten Structure**: Ignore source folder hierarchy when transferring to inbox

## Technical Constraints

- macOS 15.0+ only
- No sandboxing (requires Full Disk Access)
- No external dependencies planned
- Sequential transfers for reliability
- Manual updates only

## Current Status

Project is in planning phase with complete specification in SPEC.md. No build system, dependencies, or source code exists yet. Next step is creating the Swift project structure and implementing the core modules.