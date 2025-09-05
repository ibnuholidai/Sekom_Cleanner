class InstalledApplication {
  final String name;
  final String version;
  final bool isInstalled;
  final String status;
  final String registryPath;
  final String publisher;
  final String installDate;
  final String size;
  final String uninstallString;

  InstalledApplication({
    required this.name,
    required this.version,
    required this.isInstalled,
    required this.status,
    this.registryPath = '',
    this.publisher = '',
    this.installDate = '',
    this.size = '',
    this.uninstallString = '',
  });

  factory InstalledApplication.fromMap(Map<String, dynamic> map) {
    return InstalledApplication(
      name: map['name'] ?? '',
      version: map['version'] ?? '',
      isInstalled: map['isInstalled'] ?? false,
      status: map['status'] ?? '',
      registryPath: map['registryPath'] ?? '',
      publisher: map['publisher'] ?? '',
      installDate: map['installDate'] ?? '',
      size: map['size'] ?? '',
      uninstallString: map['uninstallString'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'version': version,
      'isInstalled': isInstalled,
      'status': status,
      'registryPath': registryPath,
      'publisher': publisher,
      'installDate': installDate,
      'size': size,
      'uninstallString': uninstallString,
    };
  }
}

class InstallableApplication {
  final String id;
  final String name;
  final String description;
  final String downloadUrl;
  final String installerName;
  final String iconPath;
  final bool isSelected;

  InstallableApplication({
    required this.id,
    required this.name,
    required this.description,
    this.downloadUrl = '',
    this.installerName = '',
    this.iconPath = '',
    this.isSelected = false,
  });

  factory InstallableApplication.fromMap(Map<String, dynamic> map) {
    return InstallableApplication(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      downloadUrl: map['downloadUrl'] ?? '',
      installerName: map['installerName'] ?? '',
      iconPath: map['iconPath'] ?? '',
      isSelected: map['isSelected'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'downloadUrl': downloadUrl,
      'installerName': installerName,
      'iconPath': iconPath,
      'isSelected': isSelected,
    };
  }

  InstallableApplication copyWith({
    String? id,
    String? name,
    String? description,
    String? downloadUrl,
    String? installerName,
    String? iconPath,
    bool? isSelected,
  }) {
    return InstallableApplication(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      installerName: installerName ?? this.installerName,
      iconPath: iconPath ?? this.iconPath,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

class ApplicationList {
  final List<InstallableApplication> applications;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  ApplicationList({
    required this.applications,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ApplicationList.fromMap(Map<String, dynamic> map) {
    return ApplicationList(
      applications: (map['applications'] as List<dynamic>?)
          ?.map((app) => InstallableApplication.fromMap(app))
          .toList() ?? [],
      name: map['name'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'applications': applications.map((app) => app.toMap()).toList(),
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  ApplicationList copyWith({
    List<InstallableApplication>? applications,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ApplicationList(
      applications: applications ?? this.applications,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
