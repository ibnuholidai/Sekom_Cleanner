# Sekom Cleaner - Recent Files Enhancement - COMPLETED ✅

## Task Summary
Enhanced the Recent files cleaning functionality to address issues where recent items still appeared in Windows Start/Search after cleaning, and added automatic Photos app unpinning.

## Completed Improvements ✅

### 1. Enhanced Search/Explorer MRU Cleaning
- ✅ Added SearchApp.exe and SearchUI.exe to processes killed before cleaning
- ✅ Enhanced Windows Search cache clearing:
  - Clear `%LOCALAPPDATA%\Packages\Microsoft.Windows.Search_cw5n1h2txyewy\LocalState`
  - Clear Windows Search database completely
- ✅ Added comprehensive Explorer MRU registry cleaning:
  - `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSaveMRU`
  - `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU`
  - `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRU`
  - `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ACMru` (AutoComplete MRU)

### 2. Enhanced Office MRU Cleaning
- ✅ Added additional Office registry paths:
  - `Recent Files` and `Recent Documents` for each Office app
  - `Common\Open Find` and `Common\Roaming\Open Find` paths
- ✅ Covers Office versions 15.0, 16.0, 17.0, 18.0
- ✅ Covers all major Office apps: Word, Excel, PowerPoint, Access, Publisher, Visio, Project

### 3. Photos App Unpinning Feature
- ✅ Created `unpinPhotosFromStart()` function with multiple methods:
  - **Method 1**: COM Shell.Application approach to find and unpin Photos from Start Menu
  - **Method 2**: Unpin Photos from taskbar if present
  - **Method 3**: Clear Start menu cache files (DefaultLayouts.xml)
  - **Method 4**: Clear Start layout registry cache
- ✅ Integrated automatic Photos unpinning into `clearRecentFiles()` function
- ✅ All methods are best-effort with proper error handling

### 4. Technical Implementation Details
- ✅ All new functionality uses try-catch blocks for robust error handling
- ✅ PowerShell scripts are properly escaped and formatted
- ✅ File and directory operations include existence checks
- ✅ Registry operations are wrapped in individual try-catch blocks
- ✅ Service restart logic for Windows Search is maintained

## Expected Results After Implementation

### Before Enhancement:
- ❌ Recent files still appeared in Start/Search suggestions
- ❌ Excel/Office jump lists showed recent documents in Start Menu
- ❌ Search history and autocomplete suggestions persisted
- ❌ Photos app tile remained pinned to Start Menu

### After Enhancement:
- ✅ Start/Search suggestions should be completely clean
- ✅ Office apps (Excel, Word, etc.) should show no recent items in Start Menu
- ✅ Search autocomplete and history should be cleared
- ✅ Photos app should be unpinned from Start Menu automatically
- ✅ All MRU (Most Recently Used) lists should be cleared comprehensively

## Files Modified
- `lib/services/system_service.dart` - Enhanced `clearRecentFiles()` method and added `unpinPhotosFromStart()` function

## Testing Recommendations
1. Run the Recent files cleaning feature
2. Check Start Menu search - type "ex" and verify no Excel recent files appear
3. Check that Photos app tile is no longer pinned to Start Menu
4. Verify File Explorer Quick Access is clean
5. Test Office apps to ensure no recent documents in jump lists

## Notes
- All enhancements are backward compatible
- Error handling ensures partial failures don't break the entire cleaning process
- Photos unpinning is best-effort and won't cause failures if unsuccessful
- Registry operations target user-specific keys (HKCU) for safety

---

## Installer Build Instructions (Inno Setup)

This project now includes an Inno Setup script to generate a Windows installer for the Flutter app.

Script:
- scripts/installer/sekom_clenner.iss

Output:
- dist/installer/sekom_clenner-1.0.0-setup.exe

Prerequisites:
- Flutter SDK with Windows desktop support
- Visual Studio with Desktop development with C++ workload (for Flutter desktop build)
- Inno Setup installed (ISCC.exe in PATH or compile via GUI)

Steps:
1) Build the Windows release:
   flutter build windows --release

2) Compile the installer:
   - Option A: Open scripts/installer/sekom_clenner.iss in Inno Setup Compiler (GUI) and click Compile
   - Option B: Using command line (if ISCC is in PATH):
     ISCC.exe "scripts\installer\sekom_clenner.iss"

3) The installer executable will be generated at:
   dist\installer\sekom_clenner-1.0.0-setup.exe

What gets packaged:
- Entire build\windows\x64\runner\Release\* (including subfolders like data, flutter_assets, etc.)
- native\publish\SekomHelper.exe placed next to the app executable

Shortcuts:
- Start Menu shortcut: sekom_clenner
- Desktop shortcut: optional (enabled by default)

Uninstall:
- Available via Control Panel / Settings; removes files under {pf}\Sekom\sekom_clenner and shortcuts

Notes:
- WebView2 Runtime: app uses webview_windows; most Windows 10/11 machines already have it. The first version of installer does not auto-install WebView2.
- .NET 7 Runtime: SekomHelper.exe in native/publish is expected to be self-contained. If not, user may need to install .NET 7 Runtime.
- If you change app version, update the constants in sekom_clenner.iss:
  - #define MyAppVersion "1.0.0"
  - OutputBaseFilename accordingly (e.g., sekom_clenner-1.0.1-setup)
