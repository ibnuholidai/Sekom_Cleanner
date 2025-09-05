# Sekom Cleaner - Flutter Version

A Flutter application that replicates the functionality of the Python tkinter-based browser cleaner tool. This app provides a modern, cross-platform interface for cleaning browsers, system folders, and managing Windows system settings.

## Features

### 🌐 Browser Cleaning
- **Supported Browsers**: Google Chrome, Microsoft Edge, Mozilla Firefox
- **Reset Functionality**: Complete browser reset to default settings
- **Selective Cleaning**: Choose specific browsers to clean
- **Bulk Selection**: Select all browsers at once

### 📁 System Folders Cleaning
- **Folder Support**: 3D Objects, Documents, Downloads, Music, Pictures, Videos
- **Size Calculation**: Real-time folder size display
- **Warning System**: Clear warnings about permanent file deletion
- **Bulk Operations**: Select all folders option

### 🛡️ Windows System Management
- **Windows Defender**: Status checking and definition updates
- **Windows Update**: Check for and install system updates
- **Driver Management**: Scan and update device drivers
- **Activation Status**: Check and activate Windows and Office
- **Recent Files**: Clear recent items from Quick Access and Office

## Architecture

### Project Structure
```
lib/
├── main.dart                    # App entry point
├── models/
│   └── system_status.dart       # Data models
├── services/
│   └── system_service.dart      # System operations
├── screens/
│   └── main_screen.dart         # Main application screen
└── widgets/
    ├── browser_section.dart     # Browser cleaning UI
    ├── system_folders_section.dart # Folder cleaning UI
    └── windows_system_section.dart # System management UI
```

### Key Components

#### Models
- **SystemStatus**: Represents system component status (active, needs update, etc.)
- **FolderInfo**: Contains folder information (name, path, size, existence)
- **CleaningResult**: Stores cleaning operation results

#### Services
- **SystemService**: Handles all system operations including:
  - Browser cleaning and reset
  - System folder management
  - Windows system checks and updates
  - File size calculations
  - Registry operations

#### Widgets
- **BrowserSection**: UI for browser selection and cleaning options
- **SystemFoldersSection**: Interface for folder selection with size display
- **WindowsSystemSection**: System status display and action buttons

## Dependencies

```yaml
dependencies:
  flutter: sdk
  process_run: ^0.12.5      # Shell command execution
  path_provider: ^2.1.1     # System path access
  url_launcher: ^6.2.1      # URL and system app launching
  cupertino_icons: ^1.0.8   # iOS-style icons
```

## Platform Considerations

### Windows-Specific Features
- Registry access for Office activation checking
- PowerShell command execution
- Windows-specific folder paths
- System service management

### Cross-Platform Limitations
- Some system operations are Windows-only
- Registry operations not available on other platforms
- File system permissions vary by platform

## Installation & Setup

1. **Prerequisites**
   ```bash
   flutter --version  # Ensure Flutter is installed
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the Application**
   ```bash
   flutter run -d windows  # For Windows desktop
   flutter run -d chrome   # For web version
   ```

## Usage

### Basic Operations
1. **Check System Status**: Click "🔍 Check All" to scan all system components
2. **Select Items**: Choose browsers, folders, or system options to clean
3. **Bulk Selection**: Use "✅ Pilih Semua" to select all options
4. **Clean**: Click "🧹 Bersihkan" to start the cleaning process

### Advanced Features
- **Individual Updates**: Use update buttons for specific system components
- **Activation**: Activate Windows or Office using built-in scripts
- **Recent Files**: Clear recent items from Windows and Office applications

## Security & Permissions

### Required Permissions
- **File System Access**: Read/write access to user folders
- **Registry Access**: Windows registry modification (Windows only)
- **Process Management**: Ability to terminate browser processes
- **Network Access**: For activation scripts and updates

### Safety Features
- **Confirmation Dialogs**: All destructive operations require confirmation
- **Warning Messages**: Clear warnings for permanent file deletion
- **Error Handling**: Comprehensive error handling and user feedback

## Development Notes

### System Integration
The Flutter app uses platform channels and shell commands to interact with the Windows system, similar to the original Python implementation.

### Error Handling
- Try-catch blocks around all system operations
- User-friendly error messages
- Graceful degradation when operations fail

### Performance
- Asynchronous operations for system checks
- Parallel execution of independent tasks
- Progress indicators for long-running operations

## Comparison with Python Version

### Advantages
- **Modern UI**: Material Design 3 interface
- **Cross-Platform**: Runs on Windows, Web, and potentially mobile
- **Better Performance**: Compiled Dart code
- **Responsive Design**: Adaptive layout for different screen sizes

### Maintained Features
- All original functionality preserved
- Same system operation logic
- Identical user workflow
- Compatible activation scripts

## Building for Production

### Windows Desktop
```bash
flutter build windows --release
```

### Web Version
```bash
flutter build web --release
```

## Troubleshooting

### Common Issues
1. **Permission Errors**: Run as administrator for system operations
2. **PowerShell Execution**: Ensure PowerShell execution policy allows scripts
3. **Antivirus Interference**: Whitelist the application if needed

### Debug Mode
```bash
flutter run --debug  # For development and debugging
```

## Contributing

When contributing to this Flutter version:
1. Maintain compatibility with the original Python functionality
2. Follow Flutter/Dart coding standards
3. Test on Windows platform thoroughly
4. Update documentation for any new features

## License

This Flutter version maintains the same license as the original Python application.
