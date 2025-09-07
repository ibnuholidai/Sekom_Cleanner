import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:process_run/shell.dart';
import '../models/system_status.dart';
import '../models/application_models.dart';

class SystemService {
  static final Shell _shell = Shell();
  static Map<String, dynamic> lastReport = {};
  // Test mode flag to avoid heavy OS calls during widget tests
  static bool testMode = false;

  // ===== Helpers (keep before usages to avoid "referenced before declaration") =====

  static Future<int> _calculateFolderSize(Directory folder) async {
    int totalSize = 0;
    try {
      await for (FileSystemEntity entity in folder.list(recursive: true)) {
        if (entity is File) {
          try {
            totalSize += await entity.length();
          } catch (_) {
            // Ignore inaccessible files
          }
        }
      }
    } catch (_) {
      // Ignore
    }
    return totalSize;
  }

  static String _formatSize(int sizeBytes) {
    if (sizeBytes <= 0) return "0 B";
    List<String> sizeNames = ["B", "KB", "MB", "GB", "TB"];
    int i = (log(sizeBytes) / log(1024)).floor();
    double size = sizeBytes / pow(1024, i);
    return "${size.toStringAsFixed(2)} ${sizeNames[i]}";
  }

  static Map<String, dynamic> _parseBatteryReport(String content) {
    Map<String, dynamic> data = {};
    try {
      RegExp designCapMatch = RegExp(r'>DESIGN CAPACITY<.*?>([\d,]+)', caseSensitive: false);
      var designMatch = designCapMatch.firstMatch(content);
      if (designMatch != null) {
        String designStr = designMatch.group(1)?.replaceAll(',', '') ?? '0';
        data['design'] = int.tryParse(designStr) ?? 0;
      }

      RegExp fullChargeMatch = RegExp(r'>FULL CHARGE CAPACITY<.*?>([\d,]+)', caseSensitive: false);
      var fullMatch = fullChargeMatch.firstMatch(content);
      if (fullMatch != null) {
        String fullStr = fullMatch.group(1)?.replaceAll(',', '') ?? '0';
        data['full_charge'] = int.tryParse(fullStr) ?? 0;
      }

      RegExp cycleCountMatch = RegExp(r'>CYCLE COUNT<.*?>([\d,]+)', caseSensitive: false);
      var cycleMatch = cycleCountMatch.firstMatch(content);
      if (cycleMatch != null) {
        String cycleStr = cycleMatch.group(1)?.replaceAll(',', '') ?? '0';
        data['cycle_count'] = int.tryParse(cycleStr) ?? 0;
      }

      return data;
    } catch (_) {
      return {};
    }
  }

  // Fast directory deletion helper (tries rmdir, then PowerShell Remove-Item, then Dart fallback)
  static Future<bool> _fastDeleteDirectoryPath(String path) async {
    try {
      if (path.trim().isEmpty) return false;

      try {
        await _shell.run('cmd /c rmdir /s /q "$path"');
      } catch (_) {}

      if (await Directory(path).exists()) {
        try {
          await _shell.run('powershell -NoProfile -Command "Remove-Item -LiteralPath \\"$path\\" -Recurse -Force -ErrorAction SilentlyContinue"');
        } catch (_) {}
      }

      if (await Directory(path).exists()) {
        try {
          await Directory(path).delete(recursive: true);
        } catch (_) {}
      }

      return !(await Directory(path).exists());
    } catch (_) {
      return false;
    }
  }

  // Robocopy-based fast folder size helper
  static Future<int> _getFolderSizeViaRobocopy(String folderPath) async {
    try {
      if (folderPath.trim().isEmpty) return 0;
      final folderEsc = folderPath.replaceAll('"', r'`"');
      final ps = '''
\$folder = "$folderEsc"
try {
  # Quote the Robocopy source path to handle spaces (e.g. "3D Objects", "My Documents")
  \$out = robocopy "\$folder" "NUL" /E /L /BYTES | Out-String
  \$bytes = 0
  \$line = (\$out -split "`n") | Where-Object { \$_ -match 'Bytes\\s*:' } | Select-Object -Last 1
  if (\$line -and (\$line -match 'Bytes\\s*:\\s*([0-9,]+)')) {
    \$bytes = [int64](\$Matches[1].Value.Replace(',', ''))
  }
  Write-Output \$bytes
} catch {
  Write-Output 0
}
''';
      final scriptPath = '${Directory.systemTemp.path}\\sekom_size_robocopy.ps1';
      await File(scriptPath).writeAsString(ps);
      final result = await _shell.run('powershell -NoProfile -ExecutionPolicy Bypass -File "$scriptPath"');
      final out = result.first.stdout.toString().trim();
      final val = int.tryParse(out) ?? 0;
      return val;
    } catch (_) {
      return 0;
    }
  }

  // Try to resolve native helper path from multiple possible locations
  static Future<String?> _findSekomHelperExe() async {
    try {
      // Candidates relative to probable working directories
      final exeDir = File(Platform.resolvedExecutable).parent.path; // runner dir
      final candidates = <String>[
        'native\\publish\\SekomHelper.exe',                                 // project root run
        '$exeDir\\SekomHelper.exe',                                         // same dir as runner
        '$exeDir\\..\\..\\..\\..\\native\\publish\\SekomHelper.exe',        // from runner to project root
        '${Directory.current.path}\\native\\publish\\SekomHelper.exe',      // current dir -> native
      ];

      for (final p in candidates) {
        try {
          final path = p.replaceAll('/', '\\');
          if (await File(path).exists()) return path;
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }
 
  // Resolve Python executable path
  static Future<String?> _resolvePython() async {
    final candidates = <String>[
      'python',
      'python3',
      'py -3',
      'py',
    ];
    for (final c in candidates) {
      try {
        // Use cmd /c to allow candidates with arguments like "py -3"
        await _shell.run('cmd /c $c --version');
        return c;
      } catch (_) {}
    }
    return null;
  }
 
  // ===== Browser cleaning methods =====
  static Future<List<String>> cleanBrowsers({
    bool chrome = false,
    bool edge = false,
    bool firefox = false,
    bool resetBrowser = false,
  }) async {
    List<String> cleaned = [];
    try {
      // Close browsers first
      List<String> browsers = [];
      if (chrome) browsers.add("chrome.exe");
      if (edge) browsers.add("msedge.exe");
      if (firefox) browsers.add("firefox.exe");

      for (String browser in browsers) {
        try {
          await _shell.run('taskkill /f /im $browser');
        } catch (_) {
          // ignore if not running
        }
      }

      // Wait a bit
      await Future.delayed(Duration(seconds: 2));

      // Get user profile
      String userProfile = Platform.environment['USERPROFILE'] ?? '';

      if (chrome && resetBrowser) {
        String chromePath = '$userProfile\\AppData\\Local\\Google\\Chrome\\User Data';
        if (await Directory(chromePath).exists()) {
          final ok = await _fastDeleteDirectoryPath(chromePath);
          if (ok || !await Directory(chromePath).exists()) {
            cleaned.add("Google Chrome");
          }
        }
      }

      if (edge && resetBrowser) {
        String edgePath = '$userProfile\\AppData\\Local\\Microsoft\\Edge\\User Data';
        if (await Directory(edgePath).exists()) {
          final ok = await _fastDeleteDirectoryPath(edgePath);
          if (ok || !await Directory(edgePath).exists()) {
            cleaned.add("Microsoft Edge");
          }
        }
      }

      if (firefox && resetBrowser) {
        String firefoxPath = '$userProfile\\AppData\\Roaming\\Mozilla\\Firefox';
        if (await Directory(firefoxPath).exists()) {
          final ok = await _fastDeleteDirectoryPath(firefoxPath);
          if (ok || !await Directory(firefoxPath).exists()) {
            cleaned.add("Mozilla Firefox");
          }
        }
      }
    } catch (_) {
      // swallow
    }

    lastReport['cleanBrowsers'] = {
      'cleaned': cleaned,
    };
    return cleaned;
  }

  // ===== System folder cleaning methods =====
  static Future<List<String>> cleanSystemFolders({
    bool documents = false,
    bool downloads = false,
    bool music = false,
    bool pictures = false,
    bool videos = false,
    bool objects3d = false,
  }) async {
    List<String> cleaned = [];

    try {
      String userProfile = Platform.environment['USERPROFILE'] ?? '';
      Map<String, bool> folders = {
        'Documents': documents,
        'Downloads': downloads,
        'Music': music,
        'Pictures': pictures,
        'Videos': videos,
        '3D Objects': objects3d,
      };

      for (String folderName in folders.keys) {
        if (folders[folderName] == true) {
          String folderPath = '$userProfile\\$folderName';
          Directory folder = Directory(folderPath);

          if (await folder.exists()) {
            bool ok = false;
            try {
              // Fast path: Remove-Item for all contents inside the folder
              await _shell.run('powershell -NoProfile -Command "Remove-Item -Path \\"$folderPath\\*\\" -Recurse -Force -ErrorAction SilentlyContinue"');
              ok = true;
            } catch (_) {
              ok = false;
            }

            if (!ok) {
              // Fallback to Dart deletion item-by-item
              try {
                await for (FileSystemEntity entity in folder.list()) {
                  try {
                    if (entity is File) {
                      await entity.delete();
                    } else if (entity is Directory) {
                      await entity.delete(recursive: true);
                    }
                  } catch (_) {}
                }
                ok = true;
              } catch (_) {}
            }

            if (ok) {
              cleaned.add(folderName);
            }
          }
        }
      }
    } catch (_) {
      // swallow
    }

    lastReport['cleanSystemFolders'] = {
      'cleaned': cleaned,
    };
    return cleaned;
  }

  // ===== Enhanced Recent files cleaning =====
  static Future<bool> clearRecentFiles() async {
    try {
      String userProfile = Platform.environment['USERPROFILE'] ?? '';
      String appData = Platform.environment['APPDATA'] ?? '';
      String localAppData = Platform.environment['LOCALAPPDATA'] ?? '';

      // Close common apps using recent files
      List<String> appsToClose = [
        "winword.exe", "excel.exe", "powerpnt.exe", "outlook.exe",
        "msaccess.exe", "mspub.exe", "visio.exe", "project.exe",
        "notepad.exe", "wordpad.exe"
      ];
      for (String app in appsToClose) {
        try {
          await _shell.run('taskkill /f /im $app');
        } catch (_) {}
      }

      await Future.delayed(Duration(seconds: 3));

      // 1. Clear Windows Recent folder
      String recentPath = '$appData\\Microsoft\\Windows\\Recent';
      Directory recentDir = Directory(recentPath);
      if (await recentDir.exists()) {
        await for (FileSystemEntity entity in recentDir.list()) {
          try {
            if (entity is File || entity is Link) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
          } catch (_) {}
        }
      }

      // 2. Clear Quick Access destinations
      List<String> quickAccessPaths = [
        '$appData\\Microsoft\\Windows\\Recent\\AutomaticDestinations',
        '$appData\\Microsoft\\Windows\\Recent\\CustomDestinations'
      ];
      for (String path in quickAccessPaths) {
        Directory dir = Directory(path);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          await dir.create(recursive: true);
        }
      }

      // 3. Clear Office MRU registry entries (multiple versions)
      List<String> officeVersions = ['15.0', '16.0', '17.0', '18.0'];
      List<String> officeApps = ['Word', 'Excel', 'PowerPoint', 'Access', 'Publisher', 'Visio', 'Project'];
      for (String version in officeVersions) {
        // Clear common Open/Find histories
        try { await _shell.run('reg delete "HKCU\\Software\\Microsoft\\Office\\$version\\Common\\Open Find" /f'); } catch (_) {}
        try { await _shell.run('reg delete "HKCU\\Software\\Microsoft\\Office\\$version\\Common\\Roaming\\Open Find" /f'); } catch (_) {}
        // Additional common MRU paths
        try { await _shell.run('reg delete "HKCU\\Software\\Microsoft\\Office\\$version\\Common\\Place MRU" /f'); } catch (_) {}
        try { await _shell.run('reg delete "HKCU\\Software\\Microsoft\\Office\\$version\\Common\\Recent Files" /f'); } catch (_) {}
        try { await _shell.run('reg delete "HKCU\\Software\\Microsoft\\Office\\$version\\Common\\Recent Documents" /f'); } catch (_) {}
        for (String app in officeApps) {
          try { await _shell.run('reg delete "HKCU\\Software\\Microsoft\\Office\\$version\\$app\\File MRU" /f'); } catch (_) {}
          try { await _shell.run('reg delete "HKCU\\Software\\Microsoft\\Office\\$version\\$app\\Place MRU" /f'); } catch (_) {}
          try { await _shell.run('reg delete "HKCU\\Software\\Microsoft\\Office\\$version\\$app\\User MRU" /f'); } catch (_) {}
          try { await _shell.run('reg delete "HKCU\\Software\\Microsoft\\Office\\$version\\$app\\Recent Files" /f'); } catch (_) {}
          try { await _shell.run('reg delete "HKCU\\Software\\Microsoft\\Office\\$version\\$app\\Recent Documents" /f'); } catch (_) {}
        }
      }

      // 3b. Clear Office roaming recent folder and OfficeHub caches (best-effort)
      try {
        // %APPDATA%\Microsoft\Office\Recent (contains .lnk recent files for Office apps)
        String officeRecentRoaming = '$appData\\Microsoft\\Office\\Recent';
        Directory officeRecentDir = Directory(officeRecentRoaming);
        if (await officeRecentDir.exists()) {
          try { await officeRecentDir.delete(recursive: true); } catch (_) {}
          try { await officeRecentDir.create(recursive: true); } catch (_) {}
        }
      } catch (_) {}

      try {
        // Clear OfficeHub cache (affects Office recommendations in Start/Search)
        String officeHub = '$localAppData\\Packages\\Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe';
        Directory hubLocal = Directory('$officeHub\\LocalState');
        if (await hubLocal.exists()) {
          try { await hubLocal.delete(recursive: true); } catch (_) {}
        }
        Directory hubTemp = Directory('$officeHub\\TempState');
        if (await hubTemp.exists()) {
          try { await hubTemp.delete(recursive: true); } catch (_) {}
        }
      } catch (_) {}

      // 4. Clear Windows Search index and search history
      try {
        // Stop search UI processes and service
        try { await _shell.run('taskkill /f /im SearchApp.exe'); } catch (_) {}
        try { await _shell.run('taskkill /f /im SearchUI.exe'); } catch (_) {}
        try { await _shell.run('taskkill /f /im SearchHost.exe'); } catch (_) {}
        await _shell.run('net stop "Windows Search"');
        await Future.delayed(Duration(seconds: 2));

        // Delete Windows Search database
        String searchDbPath = '$localAppData\\Microsoft\\Windows\\Search';
        Directory searchDbDir = Directory(searchDbPath);
        if (await searchDbDir.exists()) {
          await searchDbDir.delete(recursive: true);
        }

        // Delete Search app cache (per-user)
        String searchPkgLocalState = '$localAppData\\Packages\\Microsoft.Windows.Search_cw5n1h2txyewy\\LocalState';
        Directory searchLocalStateDir = Directory(searchPkgLocalState);
        if (await searchLocalStateDir.exists()) {
          await searchLocalStateDir.delete(recursive: true);
        }

        // Clear Explorer search/history MRU
        try { await _shell.run('reg delete "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\WordWheelQuery" /f'); } catch (_) {}
        try { await _shell.run('reg delete "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\TypedPaths" /f'); } catch (_) {}
        try { await _shell.run('reg delete "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\RunMRU" /f'); } catch (_) {}
        try { await _shell.run('reg delete "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\ComDlg32\\OpenSaveMRU" /f'); } catch (_) {}
        try { await _shell.run('reg delete "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\ComDlg32\\OpenSavePidlMRU" /f'); } catch (_) {}
        try { await _shell.run('reg delete "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\ComDlg32\\LastVisitedPidlMRU" /f'); } catch (_) {}
        try { await _shell.run('reg delete "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\ACMru" /f'); } catch (_) {}

        await _shell.run('net start "Windows Search"');
      } catch (_) {}

      // 5. Clear Jump Lists
      String jumpListPath = '$appData\\Microsoft\\Windows\\Recent\\CustomDestinations';
      Directory jumpListDir = Directory(jumpListPath);
      if (await jumpListDir.exists()) {
        await jumpListDir.delete(recursive: true);
        await jumpListDir.create(recursive: true);
      }
      // Also clear AutomaticDestinations (per-app Jump Lists used by Start/Search)
      String jumpAutoPath = '$appData\\Microsoft\\Windows\\Recent\\AutomaticDestinations';
      Directory jumpAutoDir = Directory(jumpAutoPath);
      if (await jumpAutoDir.exists()) {
        await jumpAutoDir.delete(recursive: true);
        await jumpAutoDir.create(recursive: true);
      }

      // 6. Clear Explorer RecentDocs
      try {
        await _shell.run('reg delete "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\RecentDocs" /f');
      } catch (_) {}

      // 7. Notepad recent
      try {
        await _shell.run('reg delete "HKCU\\Software\\Microsoft\\Notepad" /v "Recent File List" /f');
      } catch (_) {}

      // 8. WordPad recent
      try {
        await _shell.run('reg delete "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Applets\\Wordpad\\Recent File List" /f');
      } catch (_) {}

      // 9. Paint recent
      try {
        await _shell.run('reg delete "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Applets\\Paint\\Recent File List" /f');
      } catch (_) {}

      // 10. Media Player recent
      try {
        await _shell.run('reg delete "HKCU\\Software\\Microsoft\\MediaPlayer\\Player\\RecentFileList" /f');
        await _shell.run('reg delete "HKCU\\Software\\Microsoft\\MediaPlayer\\Player\\RecentURLList" /f');
      } catch (_) {}

      // 11. Photo Viewer recents
      try {
        await _shell.run('reg delete "HKCU\\Software\\Microsoft\\Windows Photo Viewer\\Capabilities\\FileAssociations" /f');
      } catch (_) {}

      // 12. Start Menu search history
      String startMenuSearchPath = '$localAppData\\Microsoft\\Windows\\History\\History.IE5';
      Directory startMenuSearchDir = Directory(startMenuSearchPath);
      if (await startMenuSearchDir.exists()) {
        await startMenuSearchDir.delete(recursive: true);
      }

      // 13. Explorer address bar history
      try {
        await _shell.run('reg delete "HKCU\\Software\\Microsoft\\Internet Explorer\\TypedURLs" /f');
      } catch (_) {}

      // 14. Thumbnail cache
      String thumbCachePath = '$localAppData\\Microsoft\\Windows\\Explorer';
      Directory thumbCacheDir = Directory(thumbCachePath);
      if (await thumbCacheDir.exists()) {
        await for (FileSystemEntity entity in thumbCacheDir.list()) {
          if (entity is File && entity.path.contains('thumbcache') && entity.path.endsWith('.db')) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }

      // 15. Clear old prefetch (>30 days)
      try {
        await _shell.run('forfiles /p C:\\Windows\\Prefetch /c "cmd /c del @path" /d -30');
      } catch (_) {}

      // 16. Temp files
      List<String> tempPaths = [
        '$userProfile\\AppData\\Local\\Temp',
        'C:\\Windows\\Temp'
      ];
      for (String tempPath in tempPaths) {
        Directory tempDir = Directory(tempPath);
        if (await tempDir.exists()) {
          await for (FileSystemEntity entity in tempDir.list()) {
            try {
              if (entity is File) {
                await entity.delete();
              } else if (entity is Directory) {
                await entity.delete(recursive: true);
              }
            } catch (_) {}
          }
        }
      }

      // 17. Refresh shell icons
      try {
        await _shell.run('ie4uinit.exe -show');
      } catch (_) {}

      // 18. Try to unpin Photos tile from Start (best-effort)
      try {
        await unpinPhotosFromStart();
      } catch (_) {}

      lastReport['clearRecentFiles'] = { 'completed': true };
      return true;
    } catch (e) {
      lastReport['clearRecentFiles'] = { 'completed': false, 'error': e.toString() };
      return false;
    }
  }

  // ===== System status checking methods =====
  static Future<SystemStatus> checkWindowsDefender() async {
    try {
      final cmd = r'''powershell -NoProfile -Command "$enabled=$false; $days=-1; $hours=-1; try { $s=Get-MpComputerStatus; if ($s) { $enabled = [bool]$s.AntivirusEnabled -and [bool]$s.RealTimeProtectionEnabled; $last=$s.AntivirusSignatureLastUpdated; if ($last) { $ts=(Get-Date)-$last; $days=$ts.Days; $hours=[int]$ts.TotalHours } } } catch {}; if (-not $enabled) { try { $svc=(Get-Service -Name WinDefend -ErrorAction SilentlyContinue); if ($svc -and $svc.Status -eq 'Running') { $enabled=$true } } catch {} } ; Write-Output ($enabled.ToString() + '|' + $days + '|' + $hours)"''';
      var result = await _shell.run(cmd);
      String out = result.first.stdout.toString().trim();
      bool enabled = false;
      int days = -1;
      int hours = -1;
      if (out.contains("|")) {
        var parts = out.split("|");
        enabled = parts[0].toLowerCase().contains("true");
        days = int.tryParse(parts[1].trim()) ?? -1;
        hours = int.tryParse(parts[2].trim()) ?? -1;
      }

      if (!enabled) {
        return SystemStatus(status: "Defender disabled", isActive: false, needsUpdate: true);
      }

      String ageText = "unknown";
      if (days >= 0) {
        if (days > 0) {
          ageText = "$days day(s)";
        } else if (hours >= 0) {
          ageText = "$hours hour(s)";
        }
      }
      bool needs = (days > 7 || hours > (24 * 7));
      return SystemStatus(
        status: "Active - Signature updated $ageText ago",
        isActive: true,
        needsUpdate: needs,
      );
    } catch (_) {
      return SystemStatus(status: "❓ Cannot check", isActive: false);
    }
  }

  static Future<SystemStatus> checkWindowsUpdate() async {
    try {
      final cmd = r'''powershell -NoProfile -Command "$d=-1; $h=-1; $last=$null; try { $reg=Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\Results\Install' -Name LastSuccessTime -ErrorAction SilentlyContinue; if ($reg -and $reg.LastSuccessTime) { $last=[datetime]$reg.LastSuccessTime } } catch {}; if (-not $last) { try { $last=(Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1).InstalledOn } catch {} } ; if ($last) { $ts=(Get-Date)-$last; $d=$ts.Days; $h=[int]$ts.TotalHours } ; Write-Output ($d.ToString() + '|' + $h.ToString())"''';
      var result = await _shell.run(cmd);
      String out = result.first.stdout.toString().trim();
      int days = -1;
      int hours = -1;
      if (out.contains("|")) {
        var parts = out.split("|");
        days = int.tryParse(parts[0].trim()) ?? -1;
        hours = int.tryParse(parts[1].trim()) ?? -1;
      }

      if (days == -1 && hours == -1) {
        return SystemStatus(status: "❓ Cannot determine last update", isActive: false);
      }

      String ageText = (days > 0) ? "$days day(s)" : ((hours >= 0) ? "$hours hour(s)" : "unknown");
      bool needs = (days > 7 || hours > (24 * 7));
      if (!needs) {
        return SystemStatus(status: "Up-to-date - Last update $ageText ago", isActive: true);
      } else {
        return SystemStatus(status: "Last update $ageText ago (needs update)", isActive: false, needsUpdate: true);
      }
    } catch (_) {
      return SystemStatus(status: "❓ Cannot check", isActive: false);
    }
  }

  static Future<SystemStatus> checkDrivers() async {
    try {
      try {
        var pnputil = await _shell.run('cmd /c pnputil /enum-devices /problem');
        String pout = pnputil.first.stdout.toString();
        if (pout.isNotEmpty) {
          final totalMatches = RegExp(r'Problem\s*:').allMatches(pout).length;
          final missingMatches = RegExp(r'0x0000001C', caseSensitive: false).allMatches(pout).length;
          if (totalMatches == 0) {
            return SystemStatus(status: "All drivers OK", isActive: true);
          } else {
            return SystemStatus(
              status: "Driver issues: $totalMatches - Not installed: $missingMatches",
              isActive: false,
              needsUpdate: true,
            );
          }
        }
      } catch (_) {}

      final cmd = r'''powershell -NoProfile -Command "$allCount=0; $notInstalled=0; try { $bad=Get-PnpDevice -PresentOnly -ErrorAction Stop | Where-Object { $_.Status -ne 'OK' }; $allCount=$bad.Count } catch {}; if ($allCount -eq 0) { try { $all = Get-WmiObject Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 }; $not = $all | Where-Object { $_.ConfigManagerErrorCode -eq 28 }; $allCount=$all.Count; $notInstalled=$not.Count } catch {} } ; Write-Output ($allCount.ToString() + '|' + $notInstalled.ToString())"''';
      var result = await _shell.run(cmd);
      String out = result.first.stdout.toString().trim();
      int total = 0, notInstalled = 0;
      if (out.contains("|")) {
        var parts = out.split("|");
        total = int.tryParse(parts[0].trim()) ?? 0;
        notInstalled = int.tryParse(parts[1].trim()) ?? 0;
      }
      if (total == 0) {
        return SystemStatus(status: "All drivers OK", isActive: true);
      }
      return SystemStatus(
        status: "Driver issues: $total - Not installed: $notInstalled",
        isActive: false,
        needsUpdate: true,
      );
    } catch (_) {
      return SystemStatus(status: "❓ Cannot check", isActive: false);
    }
  }

  static Future<SystemStatus> checkWindowsActivation() async {
    // Robust, locale-agnostic with fast CIM and cscript/slmgr fallbacks.
    try {
      final winDir = Platform.environment['WINDIR'] ?? 'C:\\Windows';

      // 1) Fast path: PowerShell CIM -> JSON (short timeout, locale-agnostic)
      try {
        final ps = r'''$p = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL" |
  Where-Object { $_.Name -like "*Windows*" -or $_.Description -like "*Windows*" } |
  Select-Object -First 1 Name, Description, LicenseStatus, PartialProductKey;
if ($p) { $p | ConvertTo-Json -Compress }''';
        final scriptPath = '${Directory.systemTemp.path}\\sekom_winact_cim.ps1';
        await File(scriptPath).writeAsString(ps);
        final cimRes = await _shell
            .run('powershell -NoProfile -ExecutionPolicy Bypass -File "$scriptPath"')
            .timeout(const Duration(seconds: 5));
        final out = cimRes.first.stdout.toString().trim();
        if (out.isNotEmpty && out != 'null' && out.startsWith('{')) {
          final map = jsonDecode(out) as Map<String, dynamic>;
          final licStatus = int.tryParse((map['LicenseStatus'] ?? '0').toString()) ?? 0;
          final name = (map['Name'] ?? '').toString();
          final desc = (map['Description'] ?? '').toString();
          final last5 = (map['PartialProductKey'] ?? '').toString();

          final info = <String, String>{};
          if (name.isNotEmpty) info['edition'] = name;
          if (desc.isNotEmpty) info['channel'] = desc;
          if (last5.isNotEmpty) info['partialKey'] = last5;

          final active = licStatus == 1;
          if (active) {
            return SystemStatus(
              status: "✅ Activated",
              isActive: true,
              detail: 'Aktif permanen${desc.isNotEmpty ? " ($desc)" : ""}',
              info: info.isEmpty ? null : info,
            );
          }
          // If CIM says not activated, continue to slmgr for more detail.
        }
      } catch (_) {
        // swallow and try next method
      }

      // 2) cscript + slmgr.vbs fallback with multiple architecture paths, locale-tolerant parsing
      final cscriptCandidates = <String>[
        '$winDir\\Sysnative\\cscript.exe',
        '$winDir\\System32\\cscript.exe',
        'cscript',
      ];
      final slmgrCandidates = <String>[
        '$winDir\\Sysnative\\slmgr.vbs',
        '$winDir\\System32\\slmgr.vbs',
        '$winDir\\SysWOW64\\slmgr.vbs',
      ];

      // Locale patterns (EN + ID)
      final activatedPatterns = <String>[
        'permanently activated',
        'aktif permanen',
        'diaktifkan secara permanen',
      ];
      final gracePatterns = <String>[
        'will expire',
        'activated until',
        'expire',
        'grace',
        'akan berakhir',
        'kedaluwarsa',
        'masa tenggang',
        'diaktifkan sampai',
      ];

      Future<Map<String, String>> _tryParseDlv(String cscript, String slmgr) async {
        final details = <String, String>{};
        try {
          final res = await _shell
              .run('cmd /c "$cscript" //nologo "$slmgr" /dlv')
              .timeout(const Duration(seconds: 6));
          final raw = (res.first.stdout.toString() + "\n" + res.first.stderr.toString()).trim();

          // Generic tolerant regexes
          final nameMatch = RegExp(r'(?im)^\s*Name:\s*(.+)$').firstMatch(raw);
          final descMatch = RegExp(r'(?im)^\s*Description:\s*(.+)$').firstMatch(raw);
          final last5Match = RegExp(r'(?im)^\s*Partial\s+Product\s+Key:\s*([A-Z0-9]{5})$').firstMatch(raw);

          if (nameMatch != null) details['edition'] = nameMatch.group(1)!.trim();
          if (descMatch != null) details['channel'] = descMatch.group(1)!.trim();
          if (last5Match != null) details['partialKey'] = last5Match.group(1)!.trim();
        } catch (_) {
          // ignore, best-effort
        }
        return details;
      }

      for (final cscript in cscriptCandidates) {
        for (final slmgr in slmgrCandidates) {
          try {
            final res = await _shell
                .run('cmd /c "$cscript" //nologo "$slmgr" /xpr')
                .timeout(const Duration(seconds: 6));
            final combined = (res.first.stdout.toString() + "\n" + res.first.stderr.toString()).trim();
            final lower = combined.toLowerCase();

            bool isActivated = activatedPatterns.any((p) => lower.contains(p));
            bool isGrace = gracePatterns.any((p) => lower.contains(p));

            if (isActivated || isGrace) {
              final extra = await _tryParseDlv(cscript, slmgr);
              final desc = extra['channel'] ?? '';
              final detail = isActivated
                  ? 'Aktif permanen${desc.isNotEmpty ? " ($desc)" : ""}'
                  : combined.replaceAll('\r', '').trim();

              return SystemStatus(
                status: isActivated ? "✅ Activated" : "⚠️ Grace/Not activated",
                isActive: isActivated,
                needsUpdate: !isActivated,
                detail: detail,
                info: extra.isEmpty ? null : extra,
              );
            }
          } catch (_) {
            // try next combination
          }
        }
      }

      // 3) If all methods failed or blocked, return deferred so UI can retry in background.
      return SystemStatus(status: "⏳ Ditunda (akan diperbarui)", isActive: false);
    } catch (_) {
      // As a last resort
      return SystemStatus(status: "⏳ Ditunda (akan diperbarui)", isActive: false);
    }
  }
  static Future<SystemStatus> checkOfficeActivation() async {
    try {
      List<String> osppPaths = [
        'C:\\Program Files\\Microsoft Office\\Office16\\OSPP.VBS',
        'C:\\Program Files (x86)\\Microsoft Office\\Office16\\OSPP.VBS',
        'C:\\Program Files\\Microsoft Office\\Office15\\OSPP.VBS'
      ];
      for (String path in osppPaths) {
        if (await File(path).exists()) {
          try {
            var result = await _shell.run('cscript //nologo "$path" /dstatus');
            final outputRaw = result.first.stdout.toString();
            final output = outputRaw.toLowerCase();

            final licensed = RegExp(r'license status:\s*---licensed---', caseSensitive: false).hasMatch(outputRaw);
            final last5Match = RegExp(r'Last 5 characters of installed product key:\s*([A-Z0-9]{5})', caseSensitive: false).firstMatch(outputRaw);
            final nameMatch = RegExp(r'LICENSE NAME:\s*(.+)', caseSensitive: false).firstMatch(outputRaw);
            final descMatch = RegExp(r'LICENSE DESCRIPTION:\s*(.+)', caseSensitive: false).firstMatch(outputRaw);
            final kmsMatch = RegExp(r'KMS machine name from DNS:\s*(.+)', caseSensitive: false).firstMatch(outputRaw);
            final graceMatch = RegExp(r'REMAINING GRACE:\s*([\d]+)\s*days', caseSensitive: false).firstMatch(outputRaw);

            final last5 = last5Match != null ? last5Match.group(1)!.trim() : '';
            final licName = nameMatch != null ? nameMatch.group(1)!.trim() : '';
            final licDesc = descMatch != null ? descMatch.group(1)!.trim() : '';
            final kmsHost = kmsMatch != null ? kmsMatch.group(1)!.trim() : '';
            final remainingDays = graceMatch != null ? (int.tryParse(graceMatch.group(1)!.trim()) ?? 0) : 0;

            Map<String, String> info = {};
            if (licName.isNotEmpty) info['licenseName'] = licName;
            if (licDesc.isNotEmpty) info['licenseDescription'] = licDesc;
            if (last5.isNotEmpty) info['partialKey'] = last5;
            if (kmsHost.isNotEmpty) info['kmsHost'] = kmsHost;
            if (remainingDays > 0) info['remainingDays'] = '$remainingDays';

            if (licensed) {
              bool needs = false;
              String detail;
              if (licDesc.toLowerCase().contains('kms')) {
                detail = 'Aktif berjangka (KMS). Sisa: ${remainingDays > 0 ? "$remainingDays hari" : "-"}';
                needs = remainingDays > 0 && remainingDays <= 30;
              } else {
                detail = 'Aktif permanen ($licDesc)';
              }
              return SystemStatus(
                status: "✅ Activated",
                isActive: true,
                needsUpdate: needs,
                detail: detail,
                info: info.isEmpty ? null : info,
              );
            } else {
              final inNotif = output.contains('notification') || output.contains('unlicensed') || output.contains('grace');
              final st = inNotif ? "⚠️ Grace period" : "❌ Not activated";
              final detail = 'Status: ${inNotif ? "Grace/Notification" : "Unlicensed"}${remainingDays > 0 ? ", Sisa: $remainingDays hari" : ""}';
              return SystemStatus(
                status: st,
                isActive: false,
                needsUpdate: true,
                detail: detail,
                info: info.isEmpty ? null : info,
              );
            }
          } catch (_) {
            // continue trying other paths
          }
        }
      }
      return SystemStatus(status: "❌ Office not installed", isActive: false);
    } catch (_) {
      return SystemStatus(status: "❓ Cannot check", isActive: false);
    }
  }

  // ===== Folder size calculation =====
  static Future<List<FolderInfo>> getFolderSizesFast({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      String userProfile = Platform.environment['USERPROFILE'] ?? '';
      List<String> folderNames = ['3D Objects', 'Documents', 'Downloads', 'Music', 'Pictures', 'Videos'];

      final futures = folderNames.map((folderName) async {
        final folderPath = '$userProfile\\$folderName';
        final exists = await Directory(folderPath).exists();
        int size = 0;
        if (exists) {
          try {
            size = await _getFolderSizeViaRobocopy(folderPath).timeout(timeout);
          } catch (_) {
            size = 0;
          }
        }
        return FolderInfo(
          name: folderName,
          path: folderPath,
          size: exists ? _formatSize(size) : "Not found",
          exists: exists,
          sizeBytes: size,
        );
      }).toList();

      final results = await Future.wait(futures);
      return results;
    } catch (_) {
      // Fallback to original implementation
      return getFolderSizes();
    }
  }
  static Future<List<FolderInfo>> getFolderSizesUltraFast({Duration timeout = const Duration(seconds: 8)}) async {
    // 1) Try Python helper first
    try {
      final py = await _resolvePython();
      if (py != null) {
        final result = await _shell.run('cmd /c $py "native\\python\\checks.py" --folder-sizes').timeout(timeout);
        final out = result.first.stdout.toString().trim();
        if (out.isNotEmpty && out != 'null') {
          final decoded = jsonDecode(out);
          final list = decoded is List ? decoded : [decoded];
          final folderInfos = <FolderInfo>[];
          for (final item in list) {
            final name = (item['Name'] ?? '').toString();
            final path = (item['Path'] ?? '').toString();
            final exists = (item['Exists'] == true) || (item['Exists']?.toString().toLowerCase() == 'true');
            final size = (item['SizeBytes'] is int) ? item['SizeBytes'] as int : int.tryParse((item['SizeBytes'] ?? '0').toString()) ?? 0;
            folderInfos.add(FolderInfo(
              name: name,
              path: path,
              size: exists ? _formatSize(size) : "Not found",
              exists: exists,
              sizeBytes: size,
            ));
          }
          return folderInfos;
        }
      }
    } catch (_) {}
    // 2) Try native helper (C#) for maximum speed next
    try {
      final exePath = await _findSekomHelperExe();
      if (exePath != null && await File(exePath).exists()) {
        final result = await _shell.run('"$exePath"').timeout(timeout);
        final out = result.first.stdout.toString().trim();
        if (out.isNotEmpty && out != 'null') {
          final decoded = jsonDecode(out);
          final list = decoded is List ? decoded : [decoded];
          final folderInfos = <FolderInfo>[];
          for (final item in list) {
            final name = (item['Name'] ?? '').toString();
            final path = (item['Path'] ?? '').toString();
            final exists = (item['Exists'] == true) || (item['Exists']?.toString().toLowerCase() == 'true');
            final size = (item['SizeBytes'] is int) ? item['SizeBytes'] as int : int.tryParse((item['SizeBytes'] ?? '0').toString()) ?? 0;
            folderInfos.add(FolderInfo(
              name: name,
              path: path,
              size: exists ? _formatSize(size) : "Not found",
              exists: exists,
              sizeBytes: size,
            ));
          }
          return folderInfos;
        }
      }
    } catch (_) {
      // ignore and fallback
    }

    // 2) Fallback to ultra-fast robocopy-based PowerShell
    try {
      final script = '''
\$names = @('3D Objects','Documents','Downloads','Music','Pictures','Videos')
\$user = [Environment]::GetEnvironmentVariable('USERPROFILE','Process')
\$out = foreach (\$n in \$names) {
  \$p = Join-Path \$user \$n
  \$exists = Test-Path -LiteralPath \$p
  \$bytes = 0
  if (\$exists) {
    try {
      # Quote the Robocopy path to avoid tokenization on spaces
      \$r = robocopy "\$p" "NUL" /E /L /BYTES | Out-String
      \$m = [regex]::Match(\$r, 'Bytes\\s*:\\s*([0-9,]+)')
      if (\$m.Success) { \$bytes = [int64](\$m.Groups[1].Value.Replace(',','')) }
    } catch { \$bytes = 0 }
  }
  [PSCustomObject]@{ Name = \$n; Path = \$p; Exists = \$exists; SizeBytes = [int64]\$bytes }
}
\$out | ConvertTo-Json -Compress
''';
      final scriptPath = '${Directory.systemTemp.path}\\sekom_folder_sizes_robocopy.ps1';
      await File(scriptPath).writeAsString(script);
      final result = await _shell.run('powershell -NoProfile -ExecutionPolicy Bypass -File "$scriptPath"').timeout(timeout);
      final out = result.first.stdout.toString().trim();
      if (out.isNotEmpty && out != 'null') {
        final decoded = jsonDecode(out);
        final list = decoded is List ? decoded : [decoded];
        final folderInfos = <FolderInfo>[];
        for (final item in list) {
          final name = (item['Name'] ?? '').toString();
          final path = (item['Path'] ?? '').toString();
          final exists = (item['Exists'] == true) || (item['Exists']?.toString().toLowerCase() == 'true');
          final size = (item['SizeBytes'] is int) ? item['SizeBytes'] as int : int.tryParse((item['SizeBytes'] ?? '0').toString()) ?? 0;
          folderInfos.add(FolderInfo(
            name: name,
            path: path,
            size: exists ? _formatSize(size) : "Not found",
            exists: exists,
            sizeBytes: size,
          ));
        }
        return folderInfos;
      }
    } catch (_) {
      // ignore
    }

    // 3) Fallback to fast per-folder robocopy
    return getFolderSizesFast(timeout: timeout);
  }

  static Future<List<FolderInfo>> getFolderSizes() async {
    // Fast path: Use PowerShell to measure sizes natively for all folders at once
    try {
      final script = '''
\$names = @('3D Objects','Documents','Downloads','Music','Pictures','Videos')
\$user = [Environment]::GetEnvironmentVariable('USERPROFILE','Process')
\$out = foreach (\$n in \$names) {
  \$p = Join-Path \$user \$n
  \$exists = Test-Path -LiteralPath \$p
  \$s = 0
  if (\$exists) {
    try {
      \$m = Get-ChildItem -LiteralPath \$p -Force -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
      if (\$m -and \$m.Sum) { \$s = [int64]\$m.Sum } else { \$s = 0 }
    } catch { \$s = 0 }
  }
  [PSCustomObject]@{ Name = \$n; Path = \$p; Exists = \$exists; SizeBytes = [int64]\$s }
}
\$out | ConvertTo-Json -Compress
''';
      final scriptPath = '${Directory.systemTemp.path}\\sekom_folder_sizes.ps1';
      await File(scriptPath).writeAsString(script);
      final result = await _shell.run('powershell -NoProfile -ExecutionPolicy Bypass -File "$scriptPath"');
      final out = result.first.stdout.toString().trim();

      if (out.isNotEmpty && out != 'null') {
        final decoded = jsonDecode(out);
        final list = decoded is List ? decoded : [decoded];
        final folderInfos = <FolderInfo>[];
        for (final item in list) {
          final name = (item['Name'] ?? '').toString();
          final path = (item['Path'] ?? '').toString();
          final exists = (item['Exists'] == true) || (item['Exists']?.toString().toLowerCase() == 'true');
          final size = (item['SizeBytes'] is int) ? item['SizeBytes'] as int : int.tryParse((item['SizeBytes'] ?? '0').toString()) ?? 0;
          folderInfos.add(FolderInfo(
            name: name,
            path: path,
            size: exists ? _formatSize(size) : "Not found",
            exists: exists,
            sizeBytes: size,
          ));
        }
        return folderInfos;
      }
    } catch (_) {
      // continue to fallback
    }

    // Fallback: Dart iteration (original behavior)
    List<FolderInfo> folderInfos = [];
    try {
      String userProfile = Platform.environment['USERPROFILE'] ?? '';
      List<String> folderNames = ['3D Objects', 'Documents', 'Downloads', 'Music', 'Pictures', 'Videos'];

      for (String folderName in folderNames) {
        String folderPath = '$userProfile\\$folderName';
        Directory folder = Directory(folderPath);

        if (await folder.exists()) {
          int size = await _calculateFolderSize(folder);
          folderInfos.add(FolderInfo(
            name: folderName,
            path: folderPath,
            size: _formatSize(size),
            exists: true,
            sizeBytes: size,
          ));
        } else {
          folderInfos.add(FolderInfo(
            name: folderName,
            path: folderPath,
            size: "Not found",
            exists: false,
            sizeBytes: 0,
          ));
        }
      }
    } catch (_) {}
    return folderInfos;
  }

  // ===== Update methods =====
  static Future<bool> updateWindowsDefender() async {
    try {
      await _shell.run('powershell "Update-MpSignature"');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> runWindowsUpdate() async {
    try {
      await _shell.run('UsoClient StartScan');
      await Future.delayed(Duration(seconds: 5));
      await _shell.run('UsoClient StartDownload');
      await Future.delayed(Duration(seconds: 5));
      await _shell.run('UsoClient StartInstall');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updateDrivers() async {
    try {
      await _shell.run('powershell "pnputil /scan-devices"');
      return true;
    } catch (_) {
      return false;
    }
  }

  // ===== Open system pages =====
  static Future<bool> openWindowsUpdateSettings() async {
    try {
      await _shell.run('cmd /c start "" ms-settings:windowsupdate');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openWindowsSecurity() async {
    try {
      await _shell.run('cmd /c start "" windowsdefender:');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openDeviceManager() async {
    try {
      await _shell.run('cmd /c start "" devmgmt.msc');
      return true;
    } catch (_) {
      return false;
    }
  }

  // ===== System shortcuts (Control Panel and tools) =====
  static Future<bool> openControlPanel() async {
    try {
      await _shell.run('cmd /c start "" control');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openDxdiag() async {
    try {
      await _shell.run('cmd /c start "" dxdiag');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openMsconfig() async {
    try {
      await _shell.run('cmd /c start "" msconfig');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openTaskManagerStartup() async {
    try {
      // Open Task Manager on Startup tab
      await _shell.run('cmd /c start "" taskmgr.exe /0 /startup');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openServicesConsole() async {
    try {
      await _shell.run('cmd /c start "" services.msc');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openWindowsFeatures() async {
    try {
      await _shell.run('cmd /c start "" optionalfeatures');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openSystemProperties() async {
    try {
      await _shell.run('cmd /c start "" sysdm.cpl');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openDiskManagement() async {
    try {
      await _shell.run('cmd /c start "" diskmgmt.msc');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openDiskCleanup() async {
    try {
      await _shell.run('cmd /c start "" cleanmgr');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openNetworkConnections() async {
    try {
      await _shell.run('cmd /c start "" ncpa.cpl');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openFirewall() async {
    try {
      await _shell.run('cmd /c start "" firewall.cpl');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openRegistryEditor() async {
    try {
      await _shell.run('cmd /c start "" regedit');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openEnvironmentVariables() async {
    try {
      await _shell.run('cmd /c start "" rundll32 sysdm.cpl,EditEnvironmentVariables');
      return true;
    } catch (_) {
      return false;
    }
  }

  // ===== Additional admin tools and consoles =====
  static Future<bool> openEventViewer() async {
    try {
      await _shell.run('cmd /c start "" eventvwr.msc');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openTaskScheduler() async {
    try {
      await _shell.run('cmd /c start "" taskschd.msc');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openPerformanceMonitor() async {
    try {
      await _shell.run('cmd /c start "" perfmon');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openSystemInformation() async {
    try {
      await _shell.run('cmd /c start "" msinfo32');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openComputerManagement() async {
    try {
      await _shell.run('cmd /c start "" compmgmt.msc');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openGroupPolicy() async {
    try {
      await _shell.run('cmd /c start "" gpedit.msc');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openCommandPrompt() async {
    try {
      await _shell.run('cmd /c start "" cmd');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openPowerShell() async {
    try {
      await _shell.run('cmd /c start "" powershell');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openWindowsTerminal() async {
    try {
      await _shell.run('cmd /c start "" wt');
      return true;
    } catch (_) {
      // Fallback to PowerShell if Windows Terminal is not available
      try {
        await _shell.run('cmd /c start "" powershell');
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  static Future<bool> openSettingsUri(String uri) async {
    try {
      await _shell.run('cmd /c start "" $uri');
      return true;
    } catch (_) {
      return false;
    }
  }

  // ===== Disk utilities =====
  static Future<List<Map<String, dynamic>>> getDiskInfo() async {
    try {
      // Fast path for tests: return static disk info without shelling out
      if (testMode) {
        final cTotal = 189437034496; // ~176.4 GB
        final cFree = 67005091840;   // ~62.4 GB
        final cUsed = cTotal - cFree;
        final dTotal = 158419906560; // ~147.6 GB
        final dFree = 105817272320;  // ~98.5 GB
        final dUsed = dTotal - dFree;
        return [
          {
            'drive': 'C:',
            'totalBytes': cTotal,
            'freeBytes': cFree,
            'usedBytes': cUsed,
            'usedPercent': cTotal > 0 ? (cUsed / cTotal) : 0.0,
            'totalText': _formatSize(cTotal),
            'freeText': _formatSize(cFree),
            'usedText': _formatSize(cUsed),
          },
          {
            'drive': 'D:',
            'totalBytes': dTotal,
            'freeBytes': dFree,
            'usedBytes': dUsed,
            'usedPercent': dTotal > 0 ? (dUsed / dTotal) : 0.0,
            'totalText': _formatSize(dTotal),
            'freeText': _formatSize(dFree),
            'usedText': _formatSize(dUsed),
          },
        ];
      }

      final ps = r'''
$disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID, Size, FreeSpace
$disks | ConvertTo-Json -Compress
''';
      final scriptPath = '${Directory.systemTemp.path}\\sekom_disks.ps1';
      await File(scriptPath).writeAsString(ps);
      var result = await _shell.run('powershell -NoProfile -ExecutionPolicy Bypass -File "$scriptPath"');
      final out = result.first.stdout.toString().trim();
      final list = <Map<String, dynamic>>[];
      if (out.isNotEmpty && out != 'null') {
        final decoded = jsonDecode(out);
        final items = decoded is List ? decoded : [decoded];
        for (final d in items) {
          final id = (d['DeviceID'] ?? '').toString(); // e.g. C:
          final size = (d['Size'] is int) ? d['Size'] as int : int.tryParse((d['Size'] ?? '0').toString()) ?? 0;
          final free = (d['FreeSpace'] is int) ? d['FreeSpace'] as int : int.tryParse((d['FreeSpace'] ?? '0').toString()) ?? 0;
          final used = (size > 0 && free >= 0) ? (size - free) : 0;
          final percent = (size > 0) ? (used / size) : 0.0;
          list.add({
            'drive': id,
            'totalBytes': size,
            'freeBytes': free,
            'usedBytes': used,
            'usedPercent': percent,
            'totalText': _formatSize(size),
            'freeText': _formatSize(free),
            'usedText': _formatSize(used),
          });
        }
      }
      return list;
    } catch (e) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<bool> openDrive(String drive) async {
    try {
      if (testMode) return true;
      String d = drive.trim();
      if (d.isEmpty) return false;
      if (!d.endsWith(':')) {
        // normalize to C:
        d = d.replaceAll('\\', '').replaceAll('/', '');
        if (d.length == 1) d = '$d:';
      }
      final path = '$d\\';
      await _shell.run('cmd /c start "" "$path"');
      return true;
    } catch (_) {
      return false;
    }
  }

  // ===== Activation utilities =====
  static Future<bool> activateWindows() async {
    try {
      await _shell.run('powershell -Command "irm https://get.activated.win | iex"');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> activateOffice() async {
    try {
      await _shell.run('powershell -Command "irm https://get.activated.win | iex"');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openActivationPowerShell() async {
    try {
      await _shell.run('cmd /c start "" powershell -NoExit -NoProfile -ExecutionPolicy Bypass -Command "irm https://get.activated.win | iex"');
      return true;
    } catch (_) {
      return false;
    }
  }

  // ===== Recycle Bin =====
  static Future<bool> clearRecycleBin() async {
    try {
      try {
        await _shell.run('powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue"');
        return true;
      } catch (_) {}
      try {
        final cmdCom = r'''powershell -NoProfile -Command "$sh = New-Object -ComObject Shell.Application; $rb = $sh.NameSpace(0xA); if ($rb) { $items = @($rb.Items()); foreach ($i in $items) { try { $i.InvokeVerb('delete') } catch {} } }"''';
        await _shell.run(cmdCom);
        return true;
      } catch (_) {}
      final cmdPath = r'''powershell -NoProfile -Command "Get-PSDrive -PSProvider FileSystem | ForEach-Object { $p = Join-Path $_.Root '$Recycle.Bin'; if (Test-Path $p) { try { Remove-Item -LiteralPath $p\* -Force -Recurse -ErrorAction SilentlyContinue } catch {} } }"''';
      await _shell.run(cmdPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ===== Battery =====
  static Future<BatteryStatus> getBatteryStatus() async {
    try {
      String userProfile = Platform.environment['USERPROFILE'] ?? '';
      String reportPath = '$userProfile\\AppData\\Local\\Temp\\battery-report-flutter.html';

      await _shell.run('powercfg /batteryreport /output "$reportPath" /duration 1');

      await Future.delayed(Duration(seconds: 2));

      File reportFile = File(reportPath);
      if (!await reportFile.exists()) {
        return BatteryStatus(
          healthStatus: "Gagal mendapatkan data. Pastikan ini laptop dengan baterai.",
          isPresent: false,
        );
      }

      String reportContent = await reportFile.readAsString();
      Map<String, dynamic> batteryData = _parseBatteryReport(reportContent);

      int chargeLevel = 0;
      bool isCharging = false;
      String chargingState = "Unknown";

      try {
        var chargeResult = await _shell.run('powershell "(Get-WmiObject -Class Win32_Battery).EstimatedChargeRemaining"');
        String chargeOutput = chargeResult.first.stdout.toString().trim();
        if (chargeOutput.isNotEmpty && chargeOutput != "null") {
          chargeLevel = int.tryParse(chargeOutput) ?? 0;
        }

        var statusResult = await _shell.run('powershell "(Get-WmiObject -Class Win32_Battery).BatteryStatus"');
        String statusOutput = statusResult.first.stdout.toString().trim();
        if (statusOutput.isNotEmpty && statusOutput != "null") {
          int statusCode = int.tryParse(statusOutput) ?? 0;
          switch (statusCode) {
            case 1:
              chargingState = "Discharging";
              isCharging = false;
              break;
            case 2:
              chargingState = "Charging";
              isCharging = true;
              break;
            case 3:
              chargingState = "Fully Charged";
              isCharging = false;
              break;
            case 4:
              chargingState = "Low Battery";
              isCharging = false;
              break;
            case 5:
              chargingState = "Critical Battery";
              isCharging = false;
              break;
            default:
              chargingState = "Unknown";
              break;
          }
        }
      } catch (_) {}

      int designCapacity = batteryData['design'] ?? 0;
      int fullChargeCapacity = batteryData['full_charge'] ?? 0;
      bool isPresent = designCapacity > 0 || fullChargeCapacity > 0;

      var powerPlanResult = await _shell.run('powercfg /getactivescheme');
      String powerPlanOutput = powerPlanResult.first.stdout.toString();
      String powerPlan = "Unknown";
      if (powerPlanOutput.toLowerCase().contains("high performance")) {
        powerPlan = "High Performance";
      } else if (powerPlanOutput.toLowerCase().contains("balanced")) {
        powerPlan = "Balanced";
      } else if (powerPlanOutput.toLowerCase().contains("power saver")) {
        powerPlan = "Power Saver";
      }

      double batteryHealth = 0.0;
      if (designCapacity > 0 && fullChargeCapacity > 0) {
        batteryHealth = (fullChargeCapacity / designCapacity) * 100;
      }

      String healthStatus = "Unknown";
      if (isPresent) {
        if (batteryHealth >= 80) {
          healthStatus = "Excellent";
        } else if (batteryHealth >= 60) {
          healthStatus = "Good";
        } else if (batteryHealth >= 40) {
          healthStatus = "Fair";
        } else if (batteryHealth > 0) {
          healthStatus = "Poor";
        } else {
          healthStatus = "Cannot determine";
        }
      } else {
        healthStatus = "Gagal mendapatkan data. Pastikan ini laptop dengan baterai.";
      }

      String estimatedRuntime = "Unknown";
      if (chargeLevel > 0 && !isCharging) {
        int estimatedMinutes = (chargeLevel * 4);
        int hours = estimatedMinutes ~/ 60;
        int minutes = estimatedMinutes % 60;
        estimatedRuntime = "$hours h $minutes m";
      } else if (isCharging) {
        estimatedRuntime = "Charging";
      }

      try {
        await reportFile.delete();
      } catch (_) {}

      return BatteryStatus(
        chargeLevel: chargeLevel,
        healthStatus: healthStatus,
        isCharging: isCharging,
        chargingState: chargingState,
        designCapacity: designCapacity,
        fullChargeCapacity: fullChargeCapacity,
        batteryHealth: batteryHealth,
        powerPlan: powerPlan,
        estimatedRuntime: estimatedRuntime,
        batteryType: "Lithium-ion",
        manufacturer: "Unknown",
        isPresent: isPresent,
      );
    } catch (_) {
      return BatteryStatus(
        healthStatus: "Gagal mendapatkan data. Pastikan ini laptop dengan baterai.",
        isPresent: false,
      );
    }
  }

  static Future<bool> setPowerPlan(String planType) async {
    try {
      String guid = "";
      switch (planType.toLowerCase()) {
        case "balanced":
          guid = "381b4222-f694-41f0-9685-ff5bb260df2e";
          break;
        case "high performance":
          guid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c";
          break;
        case "power saver":
          guid = "a1841308-3541-4fab-bc81-f71556f20b4a";
          break;
        default:
          return false;
      }
      await _shell.run('powercfg /setactive $guid');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> generateBatteryReport() async {
    try {
      String userProfile = Platform.environment['USERPROFILE'] ?? '';
      String reportPath = '$userProfile\\Desktop\\battery-report.html';
      await _shell.run('powercfg /batteryreport /output "$reportPath"');
      return true;
    } catch (_) {
      return false;
    }
  }

  // ===== Start menu utilities =====
  static Future<void> unpinPhotosFromStart() async {
    try {
      // Pre-step: ensure Photos app and caches are cleared to avoid stale tiles/thumbnails
      try { await _shell.run('taskkill /f /im Microsoft.Photos.exe'); } catch (_) {}
      try { await _shell.run('taskkill /f /im PhotosApp.exe'); } catch (_) {}
      try { await _shell.run('taskkill /f /im msphotos.exe'); } catch (_) {}

      try {
        String localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
        String photosPkg = '$localAppData\\Packages\\Microsoft.Windows.Photos_8wekyb3d8bbwe';
        Directory photosLocalState = Directory('$photosPkg\\LocalState');
        if (await photosLocalState.exists()) { try { await photosLocalState.delete(recursive: true); } catch (_) {} }
        Directory photosLocalCache = Directory('$photosPkg\\LocalCache');
        if (await photosLocalCache.exists()) { try { await photosLocalCache.delete(recursive: true); } catch (_) {} }
        Directory photosTemp = Directory('$photosPkg\\TempState');
        if (await photosTemp.exists()) { try { await photosTemp.delete(recursive: true); } catch (_) {} }
      } catch (_) {}

      // Remove Photos pinned shortcuts from Start menu (User Pinned)
      try {
        String startPinned = '${Platform.environment['APPDATA'] ?? ''}\\\\Microsoft\\\\Internet Explorer\\\\Quick Launch\\\\User Pinned\\\\StartMenu';
        Directory startPinnedDir = Directory(startPinned);
        if (await startPinnedDir.exists()) {
          await for (final fse in startPinnedDir.list()) {
            if (fse is File && fse.path.toLowerCase().endsWith('.lnk') && fse.path.toLowerCase().contains('photo')) {
              try { await fse.delete(); } catch (_) {}
            }
          }
        }
      } catch (_) {}

      // Method 1: Try to unpin Photos from Start Menu using COM Shell.Application
      final psUnpinStart = r'''
$shell = New-Object -ComObject Shell.Application
$appsFolder = $shell.NameSpace("shell:AppsFolder")
if ($appsFolder) {
    $photosApp = $appsFolder.Items() | Where-Object { 
        $_.Name -like "*Photos*" -or 
        $_.Path -like "*Microsoft.Windows.Photos*" -or
        $_.Path -eq "Microsoft.Windows.Photos_8wekyb3d8bbwe!App"
    }
    if ($photosApp) {
        $photosApp | ForEach-Object {
            $verbs = $_.Verbs()
            $unpinVerb = $verbs | Where-Object { 
                $_.Name -like "*Unpin*" -or 
                $_.Name -like "*Lepas*" -or
                $_.Name -match "Unpin from Start" -or
                $_.Name -match "Lepas.*Start"
            }
            if ($unpinVerb) {
                try { $unpinVerb.DoIt() } catch {}
            }
        }
    }
}
''';
      try { await _shell.run('powershell -NoProfile -Command "$psUnpinStart"'); } catch (_) {}

      // Method 2: Attempt to unpin Photos from taskbar if pinned (harmless if not present)
      final psUnpinTaskbar = r'''
$taskbarPath = Join-Path $env:APPDATA "Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
if (Test-Path $taskbarPath) {
    $sh = New-Object -ComObject Shell.Application
    Get-ChildItem $taskbarPath -Filter "*.lnk" -ErrorAction SilentlyContinue | Where-Object { 
        $_.Name -match "Photos" -or $_.Name -match "Microsoft Photos" 
    } | ForEach-Object {
        try {
            $folder = $sh.NameSpace($_.DirectoryName)
            $item = $folder.ParseName($_.Name)
            $verb = $item.Verbs() | Where-Object { 
                $_.Name -match "Unpin from taskbar" -or 
                $_.Name -match "Lepas sematan dari taskbar" 
            }
            if ($verb) { $verb.DoIt() }
        } catch {}
    }
}
''';
      try { await _shell.run('powershell -NoProfile -Command "$psUnpinTaskbar"'); } catch (_) {}

      // Method 3: Clear Start menu cache to remove stale pinned tiles
      String localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
      String startMenuCachePath = '$localAppData\\Microsoft\\Windows\\Shell';
      Directory startMenuCacheDir = Directory(startMenuCachePath);
      if (await startMenuCacheDir.exists()) {
        try {
          await for (FileSystemEntity entity in startMenuCacheDir.list()) {
            if (entity is File && entity.path.contains('DefaultLayouts.xml')) {
              try { await entity.delete(); } catch (_) {}
            }
          }
        } catch (_) {}
      }

      // Method 4: Try registry approach to clear Start layout cache
      try {
        await _shell.run('reg delete "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\CloudStore\\Store\\Cache\\DefaultAccount" /f');
      } catch (_) {}

      // Method 5: Extra cleanup for Start menu pinned cache (Windows 10/11)
      try { await _shell.run('taskkill /f /im StartMenuExperienceHost.exe'); } catch (_) {}
      try { await _shell.run('taskkill /f /im ShellExperienceHost.exe'); } catch (_) {}
      try { await _shell.run('taskkill /f /im SearchHost.exe'); } catch (_) {}

      // Remove StartMenuExperienceHost LocalState to reset stale pinned tiles (including Photos)
      try {
        String startHostPath = '$localAppData\\Packages\\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\\LocalState';
        Directory startHost = Directory(startHostPath);
        if (await startHost.exists()) {
          await startHost.delete(recursive: true);
        }
      } catch (_) {}

      // Restart Explorer to reload layout
      try { await _shell.run('taskkill /f /im explorer.exe'); } catch (_) {}
      try { await _shell.run('cmd /c start explorer.exe'); } catch (_) {}

    } catch (_) {
      // Silently ignore errors - this is best-effort functionality
    }
  }

  // ===== Application Management (Uninstaller) =====
  static Future<List<InstalledApplication>> getInstalledApplications() async {
    final List<InstalledApplication> applications = [];

    try {
      // Query installed applications from registry hives and return JSON (compressed)
      final String psScript = r'''
$paths = @(
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
);
$apps = foreach ($p in $paths) {
  try {
    Get-ItemProperty -Path $p -ErrorAction SilentlyContinue | Where-Object {
      $_.DisplayName -and $_.DisplayName.Trim() -ne '' -and
      $_.DisplayName -notmatch '^(KB|Security Update|Update for|Hotfix)' -and
      $_.SystemComponent -ne 1 -and
      -not $_.ReleaseType -and
      -not $_.ParentKeyName
    } | ForEach-Object {
      $size = ''
      if ($_.EstimatedSize) {
        $kb = [int]$_.EstimatedSize
        if ($kb -gt 1048576) {
          $size = '{0:N2} GB' -f ($kb / 1024 / 1024)
        } elseif ($kb -gt 1024) {
          $size = '{0:N2} MB' -f ($kb / 1024)
        } else {
          $size = '{0} KB' -f $kb
        }
      }

      $installDate = ''
      if ($_.InstallDate) {
        try {
          $d = [datetime]::ParseExact($_.InstallDate, 'yyyyMMdd', $null)
          $installDate = $d.ToString('dd/MM/yyyy')
        } catch {}
      }

      [PSCustomObject]@{
        Name = $_.DisplayName
        Version = $_.DisplayVersion
        Publisher = $_.Publisher
        InstallDate = $installDate
        Size = $size
        UninstallString = $_.UninstallString
        RegistryPath = $_.PSPath
      }
    }
  } catch {}
};
$apps | Sort-Object Name | ConvertTo-Json -Compress -Depth 3
''';
      final String scriptPath = '${Directory.systemTemp.path}\\sekom_list_apps.ps1';
      final String outPath = '${Directory.systemTemp.path}\\sekom_list_apps.json';
      await File(scriptPath).writeAsString(psScript);
      try { await File(outPath).delete(); } catch (_) {}
      await _shell.run('cmd /c powershell -NoProfile -ExecutionPolicy Bypass -File "$scriptPath" > "$outPath"');
      String output = '';
      try { 
        output = await File(outPath).readAsString();
      } catch (_) {}

      if (output.isNotEmpty && output != 'null') {
        try {
          final decoded = jsonDecode(output);

          if (decoded is List) {
            for (final item in decoded) {
              final name = (item['Name'] ?? '').toString();
              if (name.isEmpty) continue;

              applications.add(InstalledApplication(
                name: name,
                version: (item['Version'] ?? '').toString(),
                isInstalled: true,
                status: 'Installed',
                registryPath: (item['RegistryPath'] ?? '').toString(),
                publisher: (item['Publisher'] ?? '').toString(),
                installDate: (item['InstallDate'] ?? '').toString(),
                size: (item['Size'] ?? '').toString(),
                uninstallString: (item['UninstallString'] ?? '').toString(),
              ));
            }
          } else if (decoded is Map) {
            final name = (decoded['Name'] ?? '').toString();
            if (name.isNotEmpty) {
              applications.add(InstalledApplication(
                name: name,
                version: (decoded['Version'] ?? '').toString(),
                isInstalled: true,
                status: 'Installed',
                registryPath: (decoded['RegistryPath'] ?? '').toString(),
                publisher: (decoded['Publisher'] ?? '').toString(),
                installDate: (decoded['InstallDate'] ?? '').toString(),
                size: (decoded['Size'] ?? '').toString(),
                uninstallString: (decoded['UninstallString'] ?? '').toString(),
              ));
            }
          }
        } catch (e) {
          // Keep going to fallback
          print('Failed to parse installed applications JSON: $e');
        }
      }

      // Fallback: simple listing if JSON failed or returned empty
      if (applications.isEmpty) {
        try {
          final String psSimple = r'''
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' |
  Where-Object { $_.DisplayName -and $_.DisplayName.Trim() -ne '' } |
  Select-Object @{Name='Name';Expression={$_.DisplayName}}, @{Name='Version';Expression={$_.DisplayVersion}}, Publisher |
  ConvertTo-Json -Compress
''';
          final String simplePath = '${Directory.systemTemp.path}\\sekom_list_apps_simple.ps1';
          await File(simplePath).writeAsString(psSimple);
          var simpleResult = await _shell.run('powershell -NoProfile -ExecutionPolicy Bypass -File "$simplePath"');
          String simpleOut = simpleResult.first.stdout.toString().trim();

          if (simpleOut.isNotEmpty && simpleOut != 'null') {
            final decoded = jsonDecode(simpleOut);

            if (decoded is List) {
              for (final item in decoded) {
                final name = (item['Name'] ?? '').toString();
                if (name.isEmpty) continue;

                applications.add(InstalledApplication(
                  name: name,
                  version: (item['Version'] ?? '').toString(),
                  isInstalled: true,
                  status: 'Installed',
                  registryPath: '',
                  publisher: (item['Publisher'] ?? '').toString(),
                  installDate: '',
                  size: '',
                  uninstallString: '',
                ));
              }
            } else if (decoded is Map) {
              final name = (decoded['Name'] ?? '').toString();
              if (name.isNotEmpty) {
                applications.add(InstalledApplication(
                  name: name,
                  version: (decoded['Version'] ?? '').toString(),
                  isInstalled: true,
                  status: 'Installed',
                  registryPath: '',
                  publisher: (decoded['Publisher'] ?? '').toString(),
                  installDate: '',
                  size: '',
                  uninstallString: '',
                ));
              }
            }
          }
        } catch (e) {
          print('Error with fallback method: $e');
        }
      }
    } catch (e) {
      print('Error getting installed applications: $e');
    }

    return applications;
  }

  static Future<bool> uninstallApplication(InstalledApplication app) async {
    try {
      if (app.uninstallString.isNotEmpty) {
        // Use the uninstall string from registry
        String uninstallCmd = app.uninstallString;
        
        // Add silent flags if possible
        if (uninstallCmd.toLowerCase().contains('msiexec')) {
          uninstallCmd += ' /quiet /norestart';
        } else if (uninstallCmd.toLowerCase().contains('.exe')) {
          // Try common silent flags
          uninstallCmd += ' /S /silent /quiet';
        }
        
        await _shell.run(uninstallCmd);
        return true;
      } else {
        // Try to uninstall using Windows built-in method
        final cmd = 'powershell -NoProfile -Command "Get-Package -Name \'${app.name}\' | Uninstall-Package -Force"';
        await _shell.run(cmd);
        return true;
      }
    } catch (e) {
      print('Error uninstalling ${app.name}: $e');
      return false;
    }
  }

  static Future<bool> openApplicationInControlPanel(InstalledApplication app) async {
    try {
      // Open Programs and Features and try to highlight the application
      await _shell.run('cmd /c start "" appwiz.cpl');
      return true;
    } catch (e) {
      print('Error opening Control Panel for ${app.name}: $e');
      return false;
    }
  }

  static Future<bool> openControlPanelPrograms() async {
    try {
      await _shell.run('cmd /c start "" appwiz.cpl');
      return true;
    } catch (e) {
      print('Error opening Control Panel Programs: $e');
      return false;
    }
  }
}
