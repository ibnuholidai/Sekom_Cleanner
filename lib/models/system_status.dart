class SystemStatus {
  final String status;
  final bool isActive;
  final bool needsUpdate;
  final String? detail; // Optional detailed summary (e.g., permanent vs time-based with expiry)
  final Map<String, String>? info; // Optional metadata (edition, channel, partial key, expiryDate, remainingDays, etc.)

  SystemStatus({
    required this.status,
    this.isActive = false,
    this.needsUpdate = false,
    this.detail,
    this.info,
  });
}

class FolderInfo {
  final String name;
  final String path;
  final String size;
  final bool exists;
  final int sizeBytes;

  FolderInfo({
    required this.name,
    required this.path,
    this.size = "0 B",
    this.exists = false,
    this.sizeBytes = 0,
  });
}

class CleaningResult {
  final List<String> cleanedBrowsers;
  final List<String> cleanedFolders;
  final bool recentFilesCleared;
  final String message;

  CleaningResult({
    this.cleanedBrowsers = const [],
    this.cleanedFolders = const [],
    this.recentFilesCleared = false,
    this.message = "",
  });
}

class BatteryStatus {
  final int chargeLevel;
  final String healthStatus;
  final bool isCharging;
  final String chargingState;
  final int designCapacity;
  final int fullChargeCapacity;
  final double batteryHealth;
  final String powerPlan;
  final String estimatedRuntime;
  final String batteryType;
  final String manufacturer;
  final bool isPresent;

  BatteryStatus({
    this.chargeLevel = 0,
    this.healthStatus = "Unknown",
    this.isCharging = false,
    this.chargingState = "Unknown",
    this.designCapacity = 0,
    this.fullChargeCapacity = 0,
    this.batteryHealth = 0.0,
    this.powerPlan = "Unknown",
    this.estimatedRuntime = "Unknown",
    this.batteryType = "Unknown",
    this.manufacturer = "Unknown",
    this.isPresent = false,
  });

  String get healthStatusIcon {
    if (batteryHealth >= 80) return "🟢";
    if (batteryHealth >= 60) return "🟡";
    if (batteryHealth >= 40) return "🟠";
    return "🔴";
  }

  String get chargingIcon {
    if (isCharging) return "🔌";
    return "🔋";
  }

  String get batteryIcon {
    if (chargeLevel >= 80) return "🔋";
    if (chargeLevel >= 60) return "🔋";
    if (chargeLevel >= 40) return "🔋";
    if (chargeLevel >= 20) return "🪫";
    return "🪫";
  }
}
