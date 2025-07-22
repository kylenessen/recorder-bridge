# Release Checklist

## Pre-Release Preparation
- [ ] All code changes committed and tested
- [ ] Version numbers updated in:
  - [ ] Xcode project (Marketing Version + Current Project Version)
  - [ ] INSTALLATION_GUIDE.md
  - [ ] README.txt
  - [ ] Any other documentation
- [ ] Release notes prepared
- [ ] Testing completed on target hardware

## Certificate and Signing Setup
- [ ] Developer ID Application certificate installed
- [ ] Developer ID Installer certificate installed (if using PKG)
- [ ] App-specific password generated
- [ ] Scripts updated with correct:
  - [ ] DEVELOPER_ID_APPLICATION
  - [ ] APPLE_ID
  - [ ] TEAM_ID
  - [ ] APP_PASSWORD

## Build Process
- [ ] Clean build environment (`rm -rf ~/Library/Developer/Xcode/DerivedData/*`)
- [ ] Run build script: `./Scripts/notarize.sh`
- [ ] Build completed without errors
- [ ] Notarization submitted successfully
- [ ] Notarization approved by Apple
- [ ] DMG created and signed

## Optional Package Creation
- [ ] Run installer script: `./Scripts/create-installer.sh`
- [ ] PKG created successfully
- [ ] PKG signed (if certificates configured)

## Validation Testing
- [ ] Run validation: `./Scripts/validate-distribution.sh SonyRecorderHelper.dmg`
- [ ] All validation checks pass
- [ ] Test Gatekeeper: `spctl -a -vvv -t install SonyRecorderHelper.dmg`
- [ ] Clean system installation test
- [ ] Functional testing:
  - [ ] App launches correctly
  - [ ] Menu bar icon appears
  - [ ] Configuration works
  - [ ] Device detection works (with test device)
  - [ ] File transfer works (with test files)
  - [ ] Notifications appear

## Distribution
- [ ] Files uploaded to distribution platform
- [ ] Download links tested
- [ ] Installation guide accessible
- [ ] README file included
- [ ] Release announcement prepared

## Post-Release
- [ ] Version tagged in source control
- [ ] Release notes published
- [ ] Monitor for initial user feedback
- [ ] Document any issues discovered
- [ ] Update internal documentation if needed

---

**Version**: ___________  
**Release Date**: ___________  
**Released By**: ___________  
**Notes**: 
_____________________
_____________________
_____________________