import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;
import 'package:win32_registry/win32_registry.dart' as reg;

/// Minimal native helpers implemented in pure Dart using Win32/FFI,
/// avoiding PowerShell/cscript so UI never hangs.
class WindowsNative {
  WindowsNative._();

  /// Returns true if a Windows service is currently running.
  /// Example: WinDefend (Windows Defender), wuauserv (Windows Update).
  static bool isServiceRunning(String serviceName) {
    try {
      final scm = win32.OpenSCManager(
        nullptr,
        nullptr,
        win32.SC_MANAGER_CONNECT,
      );
      if (scm == 0) {
        return false;
      }

      final svcNamePtr = serviceName.toNativeUtf16();
      final service = win32.OpenService(
        scm,
        svcNamePtr,
        win32.SERVICE_QUERY_STATUS,
      );
      calloc.free(svcNamePtr);

      if (service == 0) {
        win32.CloseServiceHandle(scm);
        return false;
      }

      final svcStatus = calloc<win32.SERVICE_STATUS_PROCESS>();
      final bytesNeeded = calloc<Uint32>();

      final ok = win32.QueryServiceStatusEx(
        service,
        win32.SC_STATUS_PROCESS_INFO,
        svcStatus.cast(),
        sizeOf<win32.SERVICE_STATUS_PROCESS>(),
        bytesNeeded,
      );

      final running =
          ok != 0 && svcStatus.ref.dwCurrentState == win32.SERVICE_RUNNING;

      calloc.free(svcStatus);
      calloc.free(bytesNeeded);
      win32.CloseServiceHandle(service);
      win32.CloseServiceHandle(scm);

      return running;
    } catch (_) {
      return false;
    }
  }

  /// Try to read a DWORD (int) from HKLM.
  static int? _regReadIntHKLM(String path, String value) {
    try {
      final key = reg.Registry.openPath(
        reg.RegistryHive.localMachine,
        path: path,
      );
      final v = key.getValueAsInt(value);
      key.close();
      return v;
    } catch (_) {
      return null;
    }
  }

  /// Try to read a string value from HKLM using both registry views (system/user).
  static String? _regReadStringHKLM(String path, String value) {
    try {
      final key = reg.Registry.openPath(
        reg.RegistryHive.localMachine,
        path: path,
      );
      final v = key.getValueAsString(value);
      key.close();
      if (v != null && v.trim().isNotEmpty) {
        return v;
      }
    } catch (_) {}

    // Try again using a fresh open (best-effort across registry views depending on process bitness)
    try {
      final key = reg.Registry.openPath(
        reg.RegistryHive.localMachine,
        path: path,
      );
      final v = key.getValueAsString(value);
      key.close();
      if (v != null && v.trim().isNotEmpty) {
        return v;
      }
    } catch (_) {}
    return null;
  }

  /// Parse a variety of datetime string formats used by Windows into DateTime (local).
  static DateTime? _parseWindowsDateTime(String s) {
    try {
      final t = s.trim();
      // common: 2024-02-18 06:34:04 or 2024-02-18T06:34:04
      final iso = t.replaceFirst(' ', 'T');
      final dt = DateTime.tryParse(iso);
      if (dt != null) return dt.toLocal();

      // legacy: 02/18/2024 06:34:04 (en-US) or 18/02/2024 06:34:04 (id-ID)
      final re = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?$');
      final m = re.firstMatch(t);
      if (m != null) {
        int a = int.parse(m.group(1)!);
        int b = int.parse(m.group(2)!);
        int y = int.parse(m.group(3)!);
        int h = int.parse(m.group(4)!);
        int min = int.parse(m.group(5)!);
        int sec = int.tryParse(m.group(6) ?? '0') ?? 0;

        // Heuristic: if a > 12 then assume a = day, b = month; else assume en-US month/day
        int month, day;
        if (a > 12) {
          day = a;
          month = b;
        } else {
          month = a;
          day = b;
        }
        if (y < 100) y += 2000;
        return DateTime(y, month, day, h, min, sec);
      }
    } catch (_) {}
    return null;
  }

  /// Get last successful Windows Update time from registry.
  static DateTime? getWindowsUpdateLastSuccessTime() {
    try {
      // Try Detect result first (often present), then Install.
      const detectPath =
          r'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\Results\Detect';
      const installPath =
          r'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\Results\Install';

      String? s = _regReadStringHKLM(detectPath, 'LastSuccessTime');
      s ??= _regReadStringHKLM(installPath, 'LastSuccessTime');
      if (s == null) return null;

      final dt = _parseWindowsDateTime(s);
      return dt;
    } catch (_) {
      return null;
    }
  }

  /// Get Defender signature version text (if available) from registry.
  static String? getDefenderSignatureVersion() {
    try {
      const path =
          r'SOFTWARE\Microsoft\Windows Defender\Signature Updates';
      final v = _regReadStringHKLM(path, 'AVSignatureVersion') ??
          _regReadStringHKLM(path, 'SignatureUpdateVersion');
      return (v != null && v.trim().isNotEmpty) ? v.trim() : null;
    } catch (_) {
      return null;
    }
  }
  
  static int? getWindowsGenuineState() {
    try {
      const path = r'SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform';
      return _regReadIntHKLM(path, 'GenuineState');
    } catch (_) {
      return null;
    }
  }
}
