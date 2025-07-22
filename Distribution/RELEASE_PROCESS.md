# Sony Recorder Helper - Release Process

This document outlines the complete process for building, signing, notarizing, and distributing Sony Recorder Helper.

## Prerequisites

### Apple Developer Account Setup
1. **Developer ID Application Certificate**
   - Download from Apple Developer portal
   - Install in Keychain Access
   - Update `DEVELOPER_ID_APPLICATION` in scripts

2. **Developer ID Installer Certificate** (Optional)
   - For signing installer packages
   - Update `DEVELOPER_ID_INSTALLER` in scripts

3. **App-Specific Password**
   - Generate at appleid.apple.com
   - Required for notarization
   - Update `APP_PASSWORD` in scripts

4. **Team ID**
   - Found in Apple Developer account
   - Update `TEAM_ID` in scripts and project settings

### Development Environment
- **Xcode 16.0+** with Command Line Tools
- **macOS 15.0+** for building and testing
- **Code signing certificates** properly installed

## Version Management

### Update Version Numbers
1. **In Xcode Project**:
   - Marketing Version (e.g., "1.1.0")
   - Current Project Version (e.g., "2")

2. **Update Documentation**:
   - INSTALLATION_GUIDE.md version references
   - README.txt version number
   - This document if process changes

### Version Numbering Scheme
- **Marketing Version**: Semantic versioning (1.0.0, 1.1.0, 1.1.1)
- **Build Number**: Increment for each build (1, 2, 3...)
- **Pre-release**: Add suffix (-beta1, -rc1) to marketing version

## Build and Distribution Process

### Step 1: Pre-Build Checklist
- [ ] All code changes committed and pushed
- [ ] Version numbers updated in project
- [ ] Documentation updated with new version
- [ ] Testing completed on target devices
- [ ] Known issues documented

### Step 2: Build Configuration
1. **Update build scripts** with current certificates:
   ```bash
   # Edit Scripts/notarize.sh
   DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAM_ID)"
   APPLE_ID="your-apple-id@example.com"
   TEAM_ID="YOUR_TEAM_ID"
   APP_PASSWORD="your-app-specific-password"
   ```

2. **Configure Xcode project**:
   - Ensure CODE_SIGN_IDENTITY is set to "Developer ID Application"
   - Verify DEVELOPMENT_TEAM is set correctly
   - Check entitlements are properly configured

### Step 3: Build and Sign
```bash
# Navigate to project root
cd /path/to/recorder-bridge

# Run the notarization script (builds, signs, and notarizes)
./Scripts/notarize.sh
```

This script will:
- Clean and build the project
- Create an archive
- Export the signed app
- Create a DMG file
- Sign the DMG
- Submit for notarization
- Staple the notarization ticket

### Step 4: Create Additional Packages
```bash
# Create installer package (optional)
./Scripts/create-installer.sh

# This creates SonyRecorderHelper-Installer.pkg
```

### Step 5: Validation
```bash
# Validate the distribution package
./Scripts/validate-distribution.sh SonyRecorderHelper.dmg

# Also validate the app bundle directly
./Scripts/validate-distribution.sh build/export/SonyRecorderHelper.app
```

### Step 6: Testing
1. **Clean System Test**:
   - Test on a clean macOS system (VM recommended)
   - Verify installation process
   - Test Full Disk Access setup
   - Verify app functionality

2. **Gatekeeper Test**:
   ```bash
   # Test that macOS will allow execution
   spctl -a -vvv -t install SonyRecorderHelper.dmg
   spctl -a -vvv -t exec /Applications/SonyRecorderHelper.app
   ```

3. **Functional Testing**:
   - Connect Sony IC Recorder
   - Verify file transfer
   - Test error handling
   - Check notifications

## Distribution Methods

### Option 1: Direct Distribution
- Upload DMG to your preferred file hosting
- Provide INSTALLATION_GUIDE.md alongside
- Include README.txt with quick start info

### Option 2: GitHub Releases
1. Create a new release tag
2. Upload both DMG and PKG files
3. Include release notes
4. Attach installation guide

### Option 3: Developer Portal
- For wider distribution through Apple channels
- Requires additional App Store Connect setup

## Troubleshooting Common Issues

### Code Signing Failures
- **Certificate not found**: Check Keychain Access, re-download if needed
- **Team ID mismatch**: Verify DEVELOPMENT_TEAM in project settings
- **Expired certificate**: Renew through Apple Developer portal

### Notarization Failures
- **Invalid binary**: Check for unsigned dependencies
- **Wrong certificate type**: Must use Developer ID Application
- **Hardened runtime issues**: Review entitlements configuration

### Gatekeeper Issues
- **App won't open**: Check if properly notarized and stapled
- **"Damaged" error**: Usually indicates signature problems
- **Permission denied**: Verify Full Disk Access instructions

## Release Checklist

### Pre-Release
- [ ] Code freeze - no changes during release process
- [ ] Version numbers updated everywhere
- [ ] Build scripts configured with valid certificates
- [ ] Clean build environment (delete derived data)

### Build Process
- [ ] Build completed successfully
- [ ] Code signing verified
- [ ] Notarization submitted and approved
- [ ] DMG created and signed
- [ ] Installer package created (if needed)

### Validation
- [ ] Distribution validation script passes
- [ ] Gatekeeper assessment passes
- [ ] Clean system installation test
- [ ] Functional testing completed
- [ ] No security warnings or errors

### Distribution
- [ ] Files uploaded to distribution platform
- [ ] Release notes prepared
- [ ] Installation guide updated
- [ ] Download links tested
- [ ] Support documentation accessible

### Post-Release
- [ ] Monitor for user issues
- [ ] Track adoption metrics (if applicable)
- [ ] Document any issues discovered
- [ ] Plan next release cycle

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-01-XX | Initial release with core functionality |
| | | Future versions will be documented here |

## Support Resources

### Apple Documentation
- [Code Signing Guide](https://developer.apple.com/documentation/security/code_signing_services)
- [Notarization Documentation](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Distribution Guide](https://developer.apple.com/documentation/security/distributing_software_securely)

### Debugging Tools
- `codesign --verify --verbose=4 [path]` - Verify signatures
- `spctl -a -vvv -t exec [app]` - Test Gatekeeper
- `stapler validate [dmg]` - Check notarization stapling
- Console.app - View system logs for errors

---

**Last Updated**: 2025  
**Process Version**: 1.0  
**Compatible with**: Xcode 16.0+, macOS 15.0+