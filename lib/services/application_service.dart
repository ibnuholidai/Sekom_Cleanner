import 'dart:io';
import 'dart:convert';
import 'package:process_run/shell.dart';
import 'package:path_provider/path_provider.dart';
import '../models/application_models.dart';

class ApplicationService {
  static final Shell _shell = Shell();

  // Default applications to check
  static List<Map<String, String>> get defaultApplications => [
    {
      'name': 'Microsoft Office',
      'registryPath': 'HKLM\\SOFTWARE\\Microsoft\\Office',
      'alternativePath': 'HKLM\\SOFTWARE\\WOW6432Node\\Microsoft\\Office',
    },
    {
      'name': 'Firefox',
      'registryPath': 'HKLM\\SOFTWARE\\Mozilla\\Mozilla Firefox',
      'alternativePath': 'HKLM\\SOFTWARE\\WOW6432Node\\Mozilla\\Mozilla Firefox',
    },
    {
      'name': 'Microsoft Edge',
      'registryPath': 'HKLM\\SOFTWARE\\Microsoft\\EdgeUpdate\\Clients',
      'alternativePath': 'HKLM\\SOFTWARE\\WOW6432Node\\Microsoft\\EdgeUpdate\\Clients',
    },
    {
      'name': 'Google Chrome',
      'registryPath': 'HKLM\\SOFTWARE\\Google\\Chrome',
      'alternativePath': 'HKLM\\SOFTWARE\\WOW6432Node\\Google\\Chrome',
    },
    {
      'name': 'WinRAR',
      'registryPath': 'HKLM\\SOFTWARE\\WinRAR',
      'alternativePath': 'HKLM\\SOFTWARE\\WOW6432Node\\WinRAR',
    },
    {
      'name': 'RustDesk',
      'registryPath': 'HKLM\\SOFTWARE\\RustDesk',
      'alternativePath': 'HKLM\\SOFTWARE\\WOW6432Node\\RustDesk',
    },
    {
      'name': 'DirectX',
      'registryPath': 'HKLM\\SOFTWARE\\Microsoft\\DirectX',
      'alternativePath': 'HKLM\\SOFTWARE\\WOW6432Node\\Microsoft\\DirectX',
    },
  ];

  // Predefined installable applications
  static List<InstallableApplication> get predefinedApplications => [
    InstallableApplication(
      id: 'office365',
      name: 'Microsoft Office 365',
      description: 'Suite aplikasi produktivitas Microsoft',
      downloadUrl: 'https://www.office.com/',
      installerName: 'OfficeSetup.exe',
    ),
    InstallableApplication(
      id: 'firefox',
      name: 'Mozilla Firefox',
      description: 'Browser web yang cepat dan aman',
      downloadUrl: 'https://www.mozilla.org/firefox/',
      installerName: 'Firefox Installer.exe',
    ),
    InstallableApplication(
      id: 'chrome',
      name: 'Google Chrome',
      description: 'Browser web dari Google',
      downloadUrl: 'https://www.google.com/chrome/',
      installerName: 'ChromeSetup.exe',
    ),
    InstallableApplication(
      id: 'winrar',
      name: 'WinRAR',
      description: 'Aplikasi kompresi dan ekstraksi file',
      downloadUrl: 'https://www.win-rar.com/',
      installerName: 'winrar-x64.exe',
    ),
    InstallableApplication(
      id: 'rustdesk',
      name: 'RustDesk',
      description: 'Aplikasi remote desktop open source',
      downloadUrl: 'https://rustdesk.com/',
      installerName: 'rustdesk.exe',
    ),
    InstallableApplication(
      id: 'directx',
      name: 'DirectX Runtime',
      description: 'Runtime library untuk gaming dan multimedia',
      downloadUrl: 'https://www.microsoft.com/en-us/download/details.aspx?id=35',
      installerName: 'directx_Jun2010_redist.exe',
    ),
    InstallableApplication(
      id: 'vlc',
      name: 'VLC Media Player',
      description: 'Pemutar media yang mendukung berbagai format',
      downloadUrl: 'https://www.videolan.org/vlc/',
      installerName: 'vlc-installer.exe',
    ),
    InstallableApplication(
      id: '7zip',
      name: '7-Zip',
      description: 'Aplikasi kompresi file gratis',
      downloadUrl: 'https://www.7-zip.org/',
      installerName: '7z-installer.exe',
    ),
    InstallableApplication(
      id: 'notepadpp',
      name: 'Notepad++',
      description: 'Editor teks dan kode yang powerful',
      downloadUrl: 'https://notepad-plus-plus.org/',
      installerName: 'npp-installer.exe',
    ),
    InstallableApplication(
      id: 'teamviewer',
      name: 'TeamViewer',
      description: 'Aplikasi remote access dan support',
      downloadUrl: 'https://www.teamviewer.com/',
      installerName: 'TeamViewer_Setup.exe',
    ),
  ];

  // Check installed applications using Control Panel method (faster)
  static Future<List<InstalledApplication>> checkInstalledApplications() async {
    List<InstalledApplication> installedApps = [];

    // Get installed programs from Control Panel
    Map<String, Map<String, String>> installedPrograms = await _getInstalledProgramsFromControlPanel();

    for (Map<String, String> app in defaultApplications) {
      try {
        InstalledApplication installedApp = await _checkApplicationFromControlPanel(
          app['name']!,
          installedPrograms,
        );
        installedApps.add(installedApp);
      } catch (e) {
        installedApps.add(InstalledApplication(
          name: app['name']!,
          version: 'Error checking',
          isInstalled: false,
          status: 'Error: ${e.toString()}',
          registryPath: '',
        ));
      }
    }

    // Merge custom default apps added by user (persisted)
    try {
      List<String> customNames = await loadDefaultAppChecks();
      final lowerExisting = installedApps.map((e) => e.name.toLowerCase()).toSet();
      for (final cname in customNames) {
        if (cname.trim().isEmpty) continue;
        if (lowerExisting.contains(cname.toLowerCase())) continue;
        try {
          final customApp = await _checkApplicationFromControlPanel(cname, installedPrograms);
          installedApps.add(customApp);
        } catch (e) {
          installedApps.add(InstalledApplication(
            name: cname,
            version: 'Tidak terdeteksi',
            isInstalled: false,
            status: 'Tidak terinstal atau tidak terdeteksi',
            registryPath: 'Control Panel',
          ));
        }
      }
    } catch (_) {}

    return installedApps;
  }

  // Get installed programs via Registry (fast and safe; avoids Win32_Product)
  static Future<Map<String, Map<String, String>>> _getInstalledProgramsFromControlPanel() async {
    Map<String, Map<String, String>> programs = {};

    try {
      // Query uninstall keys from HKLM (x64 + WOW6432Node) and HKCU using a temporary PowerShell script to avoid quoting issues.
      final String psScript = r'''
$paths = @(
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
);
$apps = foreach ($p in $paths) {
  try { Get-ItemProperty -Path $p -ErrorAction SilentlyContinue | Select-Object DisplayName, DisplayVersion } catch {}
};
$apps | Where-Object { $_ -and $_.DisplayName -and $_.DisplayName.Trim() -ne '' } |
  Select-Object @{Name='Name';Expression={$_.DisplayName}}, @{Name='Version';Expression={$_.DisplayVersion}} |
  ConvertTo-Json -Compress
''';
      final String scriptPath = '${Directory.systemTemp.path}\\sekom_proglist.ps1';
      final String outPath = '${Directory.systemTemp.path}\\sekom_proglist.json';
      await File(scriptPath).writeAsString(psScript);
      try { await File(outPath).delete(); } catch (_) {}
      await _shell.run('cmd /c powershell -NoProfile -ExecutionPolicy Bypass -File "$scriptPath" > "$outPath"').timeout(Duration(seconds: 15));
      String output = '';
      try {
        output = await File(outPath).readAsString();
      } catch (_) {}

      if (output.isNotEmpty && !output.toLowerCase().contains('error')) {
        try {
          final decoded = jsonDecode(output);
          if (decoded is List) {
            for (final item in decoded) {
              final name = (item['Name'] ?? '').toString();
              final version = (item['Version'] ?? '').toString();
              if (name.isNotEmpty) {
                programs[name.toLowerCase()] = {
                  'name': name,
                  'version': version.isNotEmpty ? version : 'Terdeteksi',
                };
              }
            }
          } else if (decoded is Map) {
            final name = (decoded['Name'] ?? '').toString();
            final version = (decoded['Version'] ?? '').toString();
            if (name.isNotEmpty) {
              programs[name.toLowerCase()] = {
                'name': name,
                'version': version.isNotEmpty ? version : 'Terdeteksi',
              };
            }
          }
        } catch (e) {
          print('Failed to parse registry JSON: $e');
        }
      }
    } catch (e) {
      print('Error getting programs from registry: $e');
    }

    // Fallback: Check common installation paths (very fast)
    await _checkCommonPaths(programs);

    return programs;
  }

  // Check common installation paths for faster detection
  static Future<void> _checkCommonPaths(Map<String, Map<String, String>> programs) async {
    Map<String, List<String>> commonPaths = {
      'Microsoft Office': [
        'C:\\Program Files\\Microsoft Office',
        'C:\\Program Files (x86)\\Microsoft Office',
      ],
      'Google Chrome': [
        'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
        'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
      ],
      'Mozilla Firefox': [
        'C:\\Program Files\\Mozilla Firefox\\firefox.exe',
        'C:\\Program Files (x86)\\Mozilla Firefox\\firefox.exe',
      ],
      'Microsoft Edge': [
        'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
        'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
      ],
      'WinRAR': [
        'C:\\Program Files\\WinRAR\\WinRAR.exe',
        'C:\\Program Files (x86)\\WinRAR\\WinRAR.exe',
      ],
      'RustDesk': [
        'C:\\Program Files\\RustDesk\\rustdesk.exe',
        'C:\\Program Files (x86)\\RustDesk\\rustdesk.exe',
      ],
    };

    for (String appName in commonPaths.keys) {
      String lowerName = appName.toLowerCase();
      if (!programs.containsKey(lowerName)) {
        for (String path in commonPaths[appName]!) {
          if (await File(path).exists()) {
            try {
              // Try to get version from file
              var result = await _shell.run('powershell "(Get-ItemProperty \'$path\').VersionInfo.FileVersion"').timeout(Duration(seconds: 2));
              String version = result.first.stdout.toString().trim();
              
              programs[lowerName] = {
                'name': appName,
                'version': version.isNotEmpty ? version : 'Terdeteksi',
              };
              break;
            } catch (e) {
              programs[lowerName] = {
                'name': appName,
                'version': 'Terdeteksi',
              };
              break;
            }
          }
        }
      }
    }

    // DirectX is always present on modern Windows
    programs['directx'] = {
      'name': 'DirectX',
      'version': '9.0c atau lebih tinggi',
    };
  }

  // Check single application from Control Panel data
  static Future<InstalledApplication> _checkApplicationFromControlPanel(
    String appName,
    Map<String, Map<String, String>> installedPrograms,
  ) async {
    // Search for the application in installed programs
    String searchKey = appName.toLowerCase();
    
    // Try exact match first
    if (installedPrograms.containsKey(searchKey)) {
      Map<String, String> appInfo = installedPrograms[searchKey]!;
      return InstalledApplication(
        name: appName,
        version: appInfo['version'] ?? 'Terdeteksi',
        isInstalled: true,
        status: 'Terinstal (Versi: ${appInfo['version'] ?? 'Terdeteksi'})',
        registryPath: 'Control Panel',
      );
    }

    // Try partial match
    for (String key in installedPrograms.keys) {
      if (key.contains(searchKey.split(' ')[0]) || searchKey.contains(key.split(' ')[0])) {
        Map<String, String> appInfo = installedPrograms[key]!;
        return InstalledApplication(
          name: appName,
          version: appInfo['version'] ?? 'Terdeteksi',
          isInstalled: true,
          status: 'Terinstal (Versi: ${appInfo['version'] ?? 'Terdeteksi'})',
          registryPath: 'Control Panel',
        );
      }
    }

    // Special cases
    if (appName == 'Microsoft Edge') {
      // Edge is built into Windows 10/11
      return InstalledApplication(
        name: appName,
        version: 'Built-in',
        isInstalled: true,
        status: 'Terinstal (Built-in Windows)',
        registryPath: 'System',
      );
    }

    return InstalledApplication(
      name: appName,
      version: 'Tidak terdeteksi',
      isInstalled: false,
      status: 'Tidak terinstal atau tidak terdeteksi',
      registryPath: '',
    );
  }

  static Future<InstalledApplication> _checkSingleApplication(
    String name,
    String registryPath,
    String alternativePath,
  ) async {
    try {
      // Try main registry path first
      var result = await _checkRegistryPath(registryPath);
      if (result['found']) {
        return InstalledApplication(
          name: name,
          version: result['version'],
          isInstalled: true,
          status: 'Terinstal (Versi: ${result['version']})',
          registryPath: registryPath,
        );
      }

      // Try alternative path (WOW6432Node for 32-bit apps on 64-bit system)
      result = await _checkRegistryPath(alternativePath);
      if (result['found']) {
        return InstalledApplication(
          name: name,
          version: result['version'],
          isInstalled: true,
          status: 'Terinstal (Versi: ${result['version']})',
          registryPath: alternativePath,
        );
      }

      // Special checks for specific applications
      if (name == 'Microsoft Edge') {
        return await _checkEdgeSpecial();
      } else if (name == 'DirectX') {
        return await _checkDirectXSpecial();
      }

      return InstalledApplication(
        name: name,
        version: 'Tidak terdeteksi',
        isInstalled: false,
        status: 'Tidak terinstal atau tidak terdeteksi',
        registryPath: registryPath,
      );
    } catch (e) {
      return InstalledApplication(
        name: name,
        version: 'Error',
        isInstalled: false,
        status: 'Error: ${e.toString()}',
        registryPath: registryPath,
      );
    }
  }

  static Future<Map<String, dynamic>> _checkRegistryPath(String path) async {
    try {
      // Set timeout untuk mempercepat pencarian
      var result = await _shell.run('reg query "$path" /s').timeout(Duration(seconds: 3));
      String output = result.first.stdout.toString();
      
      if (output.isNotEmpty && !output.contains('ERROR')) {
        // Try to extract version information quickly
        String version = await _extractVersionFromRegistry(path);
        return {
          'found': true,
          'version': version.isNotEmpty ? version : 'Terdeteksi',
        };
      }
    } catch (e) {
      // Registry path not found, access denied, or timeout
    }
    
    return {'found': false, 'version': ''};
  }

  static Future<String> _extractVersionFromRegistry(String path) async {
    try {
      // Query specific value names with proper quoting
      List<String> valueNames = [
        'DisplayVersion',
        'Version',
        'CurrentVersion',
      ];

      for (String value in valueNames) {
        try {
          var result = await _shell.run('reg query "$path" /v "$value"').timeout(Duration(seconds: 2));
          String output = result.first.stdout.toString();

          // Extract version number from registry output
          RegExp versionRegex = RegExp(r'(\d+\.[\d\.]+)');
          Match? match = versionRegex.firstMatch(output);
          if (match != null) {
            return match.group(1) ?? '';
          }
        } catch (e) {
          // Try next value name
          continue;
        }
      }
    } catch (e) {
      // Could not extract version
    }

    return '';
  }

  static Future<InstalledApplication> _checkEdgeSpecial() async {
    try {
      // Check both Program Files locations
      List<String> candidates = [
        'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
        'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
      ];
      for (final edgePath in candidates) {
        try {
          if (await File(edgePath).exists()) {
            try {
              var result = await _shell.run('powershell -NoProfile -Command "(Get-ItemProperty \'$edgePath\').VersionInfo.FileVersion"')
                  .timeout(Duration(seconds: 3));
              String version = result.first.stdout.toString().trim();
              return InstalledApplication(
                name: 'Microsoft Edge',
                version: version.isNotEmpty ? version : 'Terdeteksi',
                isInstalled: true,
                status: 'Terinstal (Versi: ${version.isNotEmpty ? version : 'Terdeteksi'})',
                registryPath: 'File System',
              );
            } catch (e) {
              return InstalledApplication(
                name: 'Microsoft Edge',
                version: 'Terdeteksi',
                isInstalled: true,
                status: 'Terinstal (Versi: Terdeteksi)',
                registryPath: 'File System',
              );
            }
          }
        } catch (_) {
          // continue checking next path
        }
      }
    } catch (e) {
      // Edge not found
    }

    return InstalledApplication(
      name: 'Microsoft Edge',
      version: 'Tidak terdeteksi',
      isInstalled: false,
      status: 'Tidak terinstal atau tidak terdeteksi',
      registryPath: '',
    );
  }

  static Future<InstalledApplication> _checkDirectXSpecial() async {
    // Langsung return DirectX sebagai terinstal untuk mempercepat
    // karena hampir semua Windows modern sudah punya DirectX
    return InstalledApplication(
      name: 'DirectX',
      version: '9.0c atau lebih tinggi',
      isInstalled: true,
      status: 'Terinstal (Versi: 9.0c atau lebih tinggi)',
      registryPath: 'System',
    );
  }

  // Application list management
  static Future<void> saveApplicationList(ApplicationList appList) async {
    try {
      final directory = await _getApplicationDocumentsDirectory();
      final file = File('${directory.path}/application_lists.json');
      
      // Ensure directory exists
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      List<ApplicationList> existingLists = await loadApplicationLists();
      
      // Update existing list or add new one
      int existingIndex = existingLists.indexWhere((list) => list.name == appList.name);
      if (existingIndex != -1) {
        existingLists[existingIndex] = appList.copyWith(updatedAt: DateTime.now());
      } else {
        existingLists.add(appList);
      }
      
      String jsonString = jsonEncode(existingLists.map((list) => list.toMap()).toList());
      await file.writeAsString(jsonString);
      
      print('Successfully saved application list to: ${file.path}');
      print('Data saved: ${existingLists.length} lists, current list has ${appList.applications.length} apps');
    } catch (e) {
      print('Error saving application list: $e');
      throw Exception('Failed to save application list: $e');
    }
  }

  static Future<List<ApplicationList>> loadApplicationLists() async {
    try {
      final directory = await _getApplicationDocumentsDirectory();
      final file = File('${directory.path}/application_lists.json');
      
      print('Loading application lists from: ${file.path}');
      
      if (await file.exists()) {
        String jsonString = await file.readAsString();
        print('File content length: ${jsonString.length}');
        
        if (jsonString.isNotEmpty) {
          List<dynamic> jsonList = jsonDecode(jsonString);
          List<ApplicationList> result = jsonList.map((json) => ApplicationList.fromMap(json)).toList();
          print('Successfully loaded ${result.length} application lists');
          return result;
        }
      } else {
        print('Application lists file does not exist yet');
      }
    } catch (e) {
      print('Error loading application lists: $e');
    }
    
    return [];
  }

  // Helper method to get application documents directory with USB portability support
  static Future<Directory> _getApplicationDocumentsDirectory() async {
    try {
      // Try to get documents directory first
      final directory = await getApplicationDocumentsDirectory();
      final appDir = Directory('${directory.path}/SekomCleaner');
      return appDir;
    } catch (e) {
      print('Failed to get application documents directory: $e');
      
      try {
        // Fallback to application support directory
        final directory = await getApplicationSupportDirectory();
        final appDir = Directory('${directory.path}/SekomCleaner');
        return appDir;
      } catch (e2) {
        print('Failed to get application support directory: $e2');
        
        try {
          // Fallback to temporary directory
          final directory = await getTemporaryDirectory();
          final appDir = Directory('${directory.path}/SekomCleaner');
          return appDir;
        } catch (e3) {
          print('Failed to get temporary directory: $e3');
          
          // Final fallback: use current directory (good for USB portability)
          final appDir = Directory('${Directory.current.path}/data');
          print('Using current directory fallback: ${appDir.path}');
          return appDir;
        }
      }
    }
  }

  static Future<ApplicationList> loadDefaultApplicationList() async {
    return ApplicationList(
      applications: predefinedApplications,
      name: 'Default Applications',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Future<void> deleteApplicationList(String listName) async {
    try {
      List<ApplicationList> existingLists = await loadApplicationLists();
      existingLists.removeWhere((list) => list.name == listName);
      
      final directory = await _getApplicationDocumentsDirectory();
      final file = File('${directory.path}/application_lists.json');
      
      String jsonString = jsonEncode(existingLists.map((list) => list.toMap()).toList());
      await file.writeAsString(jsonString);
    } catch (e) {
      print('Error deleting application list: $e');
      throw Exception('Failed to delete application list: $e');
    }
  }

  // Execute shortcut applications
  static Future<Map<String, dynamic>> simulateInstallation(List<InstallableApplication> selectedApps) async {
    List<String> successfulRuns = [];
    List<String> failedRuns = [];
    
    for (InstallableApplication app in selectedApps) {
      if (app.isSelected) {
        try {
          String filePath = app.downloadUrl; // Path to .exe file
          
          if (filePath.isNotEmpty && await File(filePath).exists()) {
            // Try to run the executable
            try {
              await _shell.run('cmd /c start "" "$filePath"');
              successfulRuns.add(app.name);
            } catch (e) {
              failedRuns.add('${app.name} (Error: ${e.toString()})');
            }
          } else {
            failedRuns.add('${app.name} (File tidak ditemukan: $filePath)');
          }
        } catch (e) {
          failedRuns.add('${app.name} (Error: ${e.toString()})');
        }
      }
    }
    
    return {
      'successful': successfulRuns,
      'failed': failedRuns,
      'total': selectedApps.where((app) => app.isSelected).length,
    };
  }

  // Helper method to convert absolute path to relative path for USB portability
  static String makePathPortable(String absolutePath) {
    try {
      // Get current executable directory (where the app is running from)
      String currentDir = Directory.current.path;
      
      // If path is on the same drive, make it relative
      if (absolutePath.startsWith(currentDir.substring(0, 2))) {
        // Try to make relative path
        String relativePath = absolutePath.replaceFirst(currentDir, '.');
        return relativePath;
      }
      
      // If it's on different drive, keep absolute but note it
      return absolutePath;
    } catch (e) {
      return absolutePath;
    }
  }

  // Helper method to resolve portable path back to absolute
  static String resolvePortablePath(String portablePath) {
    try {
      if (portablePath.startsWith('.')) {
        // Relative path, resolve to current directory
        String currentDir = Directory.current.path;
        return portablePath.replaceFirst('.', currentDir);
      }
      
      // Already absolute path
      return portablePath;
    } catch (e) {
      return portablePath;
    }
  }

  // ===== Shortcut favorites persistence =====
  static Future<void> saveShortcutFavorites(Set<String> favorites) async {
    try {
      final directory = await _getApplicationDocumentsDirectory();
      final file = File('${directory.path}/shortcut_favorites.json');

      // Ensure directory exists
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final List<String> list = favorites.toList()..sort();
      final String jsonString = jsonEncode(list);
      await file.writeAsString(jsonString);
      print('Saved ${list.length} shortcut favorites to: ${file.path}');
    } catch (e) {
      print('Error saving shortcut favorites: $e');
    }
  }

  static Future<Set<String>> loadShortcutFavorites() async {
    try {
      final directory = await _getApplicationDocumentsDirectory();
      final file = File('${directory.path}/shortcut_favorites.json');

      if (await file.exists()) {
        final String jsonString = await file.readAsString();
        if (jsonString.isNotEmpty) {
          final decoded = jsonDecode(jsonString);
          if (decoded is List) {
            final set = decoded.map((e) => e.toString()).toSet();
            print('Loaded ${set.length} shortcut favorites from: ${file.path}');
            return set;
          }
        }
      } else {
        print('Shortcut favorites file does not exist yet');
      }
    } catch (e) {
      print('Error loading shortcut favorites: $e');
    }
    return <String>{};
  }

  // ===== Default app checks persistence =====
  static Future<void> saveDefaultAppChecks(List<String> names) async {
    try {
      final directory = await _getApplicationDocumentsDirectory();
      final file = File('${directory.path}/default_app_checks.json');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final uniq = names.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      await file.writeAsString(jsonEncode(uniq));
      print('Saved ${uniq.length} default app checks to: ${file.path}');
    } catch (e) {
      print('Error saving default app checks: $e');
    }
  }

  static Future<List<String>> loadDefaultAppChecks() async {
    try {
      final directory = await _getApplicationDocumentsDirectory();
      final file = File('${directory.path}/default_app_checks.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is List) {
            return decoded.map((e) => e.toString()).toList();
          }
        }
      }
    } catch (e) {
      print('Error loading default app checks: $e');
    }
    return <String>[];
  }

  // ===== Installed programs listing (names only) =====
  static Future<List<String>> listInstalledProgramNames() async {
    final map = await _getInstalledProgramsFromControlPanel();
    final names = map.values
        .map((m) => (m['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }
}
