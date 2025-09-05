import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/application_models.dart';
import '../services/application_service.dart';
import '../widgets/installed_apps_section.dart';
import '../widgets/installable_apps_section.dart';

class ApplicationScreen extends StatefulWidget {
  const ApplicationScreen({super.key});

  @override
  State<ApplicationScreen> createState() => _ApplicationScreenState();
}

class _ApplicationScreenState extends State<ApplicationScreen> {
  // State variables
  List<InstalledApplication> _defaultApps = [];
  List<InstallableApplication> _shortcutApps = [];
  ApplicationList? _currentAppList;
  bool _isLoadingDefault = false;
  bool _isInstalling = false;
  String _statusMessage = "Siap untuk mengelola aplikasi";
  Set<String> _customDefaultNames = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _refreshDefaultApps();
    await _loadShortcutList();
  }

  Future<void> _refreshDefaultApps() async {
    setState(() {
      _isLoadingDefault = true;
      _statusMessage = "Memeriksa aplikasi default...";
    });

    try {
      List<InstalledApplication> defaultApps = await ApplicationService.checkInstalledApplications();
      List<String> custom = await ApplicationService.loadDefaultAppChecks();
      setState(() {
        _defaultApps = defaultApps;
        _customDefaultNames = custom.toSet();
        _statusMessage = "Pemeriksaan aplikasi selesai";
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Error: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isLoadingDefault = false;
      });
    }
  }

  Future<void> _loadShortcutList() async {
    try {
      // Load saved shortcuts from storage
      List<ApplicationList> savedLists = await ApplicationService.loadApplicationLists();
      if (savedLists.isNotEmpty) {
        setState(() {
          _currentAppList = savedLists.first;
          _shortcutApps = List.from(savedLists.first.applications);
        });
      } else {
        // Initialize empty list with proper ApplicationList structure
        ApplicationList emptyList = ApplicationList(
          applications: [],
          name: 'Shortcut Applications',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        setState(() {
          _currentAppList = emptyList;
          _shortcutApps = [];
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Error loading shortcuts: ${e.toString()}";
        _shortcutApps = [];
        // Create fallback ApplicationList
        _currentAppList = ApplicationList(
          applications: [],
          name: 'Shortcut Applications',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      });
    }
  }

  void _onAppSelectionChanged(String appId, bool isSelected) {
    setState(() {
      int index = _shortcutApps.indexWhere((app) => app.id == appId);
      if (index != -1) {
        _shortcutApps[index] = _shortcutApps[index].copyWith(isSelected: isSelected);
      }
    });
  }

  void _onEditApp(String appId) {
    InstallableApplication? app = _shortcutApps.firstWhere(
      (app) => app.id == appId,
      orElse: () => InstallableApplication(id: '', name: '', description: ''),
    );
    
    if (app.id.isNotEmpty) {
      _showEditAppDialog(app);
    }
  }

  void _onDeleteApp(String appId) {
    _showDeleteConfirmationDialog(appId);
  }

  void _onInstallApp(String appId) {
    InstallableApplication? app = _shortcutApps.firstWhere(
      (app) => app.id == appId,
      orElse: () => InstallableApplication(id: '', name: '', description: ''),
    );
    
    if (app.id.isNotEmpty) {
      _showInstallConfirmationDialog([app]);
    }
  }

  void _showEditAppDialog(InstallableApplication app) {
    TextEditingController nameController = TextEditingController(text: app.name);
    TextEditingController descriptionController = TextEditingController(text: app.description);
    TextEditingController urlController = TextEditingController(text: app.downloadUrl);
    TextEditingController installerController = TextEditingController(text: app.installerName);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Aplikasi'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Aplikasi',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Deskripsi',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  decoration: InputDecoration(
                    labelText: 'Path File .exe',
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.folder_open),
                      onPressed: () async {
                        await _pickFile(urlController);
                      },
                    ),
                  ),
                  readOnly: true,
                ),
                SizedBox(height: 12),
                TextField(
                  controller: installerController,
                  decoration: InputDecoration(
                    labelText: 'Nama File Installer',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validate path (if provided)
                final path = urlController.text;
                if (path.isNotEmpty) {
                  final resolved = ApplicationService.resolvePortablePath(path);
                  if (!resolved.toLowerCase().endsWith('.exe')) {
                    _showErrorDialog('Error', 'Path harus file .exe yang valid.');
                    return;
                  }
                  if (!await File(resolved).exists()) {
                    _showErrorDialog('Error', 'File tidak ditemukan di: $resolved');
                    return;
                  }
                }

                _updateApp(
                  app.id,
                  nameController.text,
                  descriptionController.text,
                  urlController.text,
                  installerController.text,
                );
                Navigator.of(context).pop();
              },
              child: Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _updateApp(String appId, String name, String description, String filePath, String installer) {
    setState(() {
      int index = _shortcutApps.indexWhere((app) => app.id == appId);
      if (index != -1) {
        _shortcutApps[index] = _shortcutApps[index].copyWith(
          name: name,
          description: description,
          downloadUrl: filePath, // Using downloadUrl field to store file path
          installerName: installer,
        );
      }
    });
  }

  void _showDeleteConfirmationDialog(String appId) {
    InstallableApplication? app = _shortcutApps.firstWhere(
      (app) => app.id == appId,
      orElse: () => InstallableApplication(id: '', name: '', description: ''),
    );

    if (app.id.isEmpty) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Konfirmasi Hapus'),
          content: Text('Apakah Anda yakin ingin menghapus shortcut "${app.name}" dari daftar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteApp(appId);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  void _deleteApp(String appId) {
    setState(() {
      _shortcutApps.removeWhere((app) => app.id == appId);
    });
  }

  void _showAddAppDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();
    TextEditingController pathController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Tambah Shortcut Baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Aplikasi *',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Deskripsi *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                SizedBox(height: 12),
                TextField(
                  controller: pathController,
                  decoration: InputDecoration(
                    labelText: 'Pilih File .exe *',
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.folder_open),
                      onPressed: () async {
                        await _pickFile(pathController);
                      },
                    ),
                  ),
                  readOnly: true,
                ),
                SizedBox(height: 8),
                Text(
                  'Klik ikon folder untuk memilih file .exe',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty && 
                    descriptionController.text.isNotEmpty && 
                    pathController.text.isNotEmpty) {
                  // Validate selected path
                  final resolvedPath = ApplicationService.resolvePortablePath(pathController.text);
                  if (!resolvedPath.toLowerCase().endsWith('.exe')) {
                    _showErrorDialog('Error', 'Path harus file .exe yang valid.');
                    return;
                  }
                  if (!await File(resolvedPath).exists()) {
                    _showErrorDialog('Error', 'File tidak ditemukan di: $resolvedPath');
                    return;
                  }

                  _addNewApp(
                    nameController.text,
                    descriptionController.text,
                    pathController.text,
                    '',
                  );
                  Navigator.of(context).pop();
                } else {
                  _showWarningDialog('Peringatan', 'Harap isi semua field yang wajib diisi!');
                }
              },
              child: Text('Tambah'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickFile(TextEditingController controller) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['exe'],
        dialogTitle: 'Pilih File Aplikasi (.exe)',
      );

      if (result != null && result.files.single.path != null) {
        String selectedPath = result.files.single.path!;
        
        // Convert to portable path for USB compatibility
        String portablePath = ApplicationService.makePathPortable(selectedPath);
        
        setState(() {
          controller.text = portablePath;
        });
      }
    } catch (e) {
      _showErrorDialog('Error', 'Gagal memilih file: ${e.toString()}');
    }
  }

  void _addNewApp(String name, String description, String filePath, String installer) {
    String newId = 'shortcut_${DateTime.now().millisecondsSinceEpoch}';
    
    // Make sure path is portable for USB compatibility
    String portablePath = ApplicationService.makePathPortable(filePath);
    
    InstallableApplication newApp = InstallableApplication(
      id: newId,
      name: name,
      description: description,
      downloadUrl: portablePath, // Using downloadUrl field to store portable file path
      installerName: installer,
    );

    setState(() {
      _shortcutApps.add(newApp);
    });
    
    // Auto save after adding
    _saveApplicationList();
  }

  Future<void> _saveApplicationList() async {
    try {
      // Ensure we have a current app list structure
      _currentAppList ??= ApplicationList(
          applications: [],
          name: 'Shortcut Applications',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

      ApplicationList updatedList = ApplicationList(
        applications: _shortcutApps,
        name: 'Shortcut Applications',
        createdAt: _currentAppList!.createdAt,
        updatedAt: DateTime.now(),
      );

      await ApplicationService.saveApplicationList(updatedList);
      
      setState(() {
        _statusMessage = "Daftar shortcut berhasil disimpan (${_shortcutApps.length} shortcut)";
        _currentAppList = updatedList;
      });

      _showInfoDialog('Berhasil', 'Daftar shortcut berhasil disimpan dengan ${_shortcutApps.length} shortcut.');
    } catch (e) {
      setState(() {
        _statusMessage = "Error: ${e.toString()}";
      });
      _showErrorDialog('Error', 'Gagal menyimpan daftar aplikasi: ${e.toString()}');
    }
  }

  Future<void> _startInstallation() async {
    List<InstallableApplication> selectedApps = _shortcutApps.where((app) => app.isSelected).toList();
    
    if (selectedApps.isEmpty) {
      _showWarningDialog('Peringatan', 'Silakan pilih minimal satu shortcut untuk dijalankan!');
      return;
    }

    _showInstallConfirmationDialog(selectedApps);
  }

  void _showInstallConfirmationDialog(List<InstallableApplication> selectedApps) {
    String appList = selectedApps.map((app) => '• ${app.name}').join('\n');
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Konfirmasi Jalankan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Shortcut yang akan dijalankan:'),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(appList),
              ),
              SizedBox(height: 12),
              Text(
                'Catatan: Aplikasi akan dijalankan dari file .exe yang sudah Anda tentukan.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performInstallation(selectedApps);
              },
              child: Text('Jalankan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performInstallation(List<InstallableApplication> selectedApps) async {
    setState(() {
      _isInstalling = true;
      _statusMessage = "Menjalankan aplikasi...";
    });

    try {
      // Resolve portable paths before execution
      List<InstallableApplication> resolvedApps = selectedApps.map((app) {
        String resolvedPath = ApplicationService.resolvePortablePath(app.downloadUrl);
        return app.copyWith(downloadUrl: resolvedPath);
      }).toList();
      
      Map<String, dynamic> result = await ApplicationService.simulateInstallation(resolvedApps);
      
      setState(() {
        _statusMessage = "Selesai menjalankan aplikasi";
      });

      _showInstallationResultDialog(result);
    } catch (e) {
      setState(() {
        _statusMessage = "Error: ${e.toString()}";
      });
      _showErrorDialog('Error', 'Terjadi kesalahan saat menjalankan aplikasi: ${e.toString()}');
    } finally {
      setState(() {
        _isInstalling = false;
      });
    }
  }

  void _showInstallationResultDialog(Map<String, dynamic> result) {
    List<String> successful = result['successful'] ?? [];
    List<String> failed = result['failed'] ?? [];
    int total = result['total'] ?? 0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Hasil Eksekusi'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total shortcut: $total'),
                SizedBox(height: 12),
                if (successful.isNotEmpty) ...[
                  Text(
                    'Berhasil dijalankan (${successful.length}):',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  ...successful.map((app) => Text('✅ $app')),
                  SizedBox(height: 12),
                ],
                if (failed.isNotEmpty) ...[
                  Text(
                    'Gagal dijalankan (${failed.length}):',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  ...failed.map((app) => Text('❌ $app')),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Dialog helper methods
  void _showWarningDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Remove a previously added custom default application, update persistence and refresh
  Future<void> _onRemoveDefaultApp(String name) async {
    try {
      final existing = await ApplicationService.loadDefaultAppChecks();
      final before = existing.length;
      existing.removeWhere((e) => e.toLowerCase() == name.toLowerCase());
      if (existing.length != before) {
        await ApplicationService.saveDefaultAppChecks(existing);
        await _refreshDefaultApps();
        setState(() {
          _statusMessage = 'Aplikasi default "$name" berhasil dihapus.';
        });
      } else {
        _showInfoDialog('Info', 'Entri "$name" tidak ditemukan di daftar custom.');
      }
    } catch (e) {
      _showErrorDialog('Error', 'Gagal menghapus aplikasi default: ${e.toString()}');
    }
  }

  // Add a default application entry only if it exists on this Windows installation,
  // then persist so it appears on other machines (USB portable).
  Future<void> _onAddDefaultApp() async {
    try {
      setState(() {
        _statusMessage = 'Memuat daftar program terinstal...';
      });

      // List installed program names using control panel registry sources
      final installedNames = await ApplicationService.listInstalledProgramNames();

      // Compose existing default names (built-in + user-added)
      final builtIn = ApplicationService.defaultApplications
          .map((e) => (e['name'] ?? '').toString())
          .where((e) => e.isNotEmpty)
          .toSet();
      final custom = (await ApplicationService.loadDefaultAppChecks()).toSet();

      final existingLower = <String>{}
        ..addAll(builtIn.map((e) => e.toLowerCase()))
        ..addAll(custom.map((e) => e.toLowerCase()));

      // Available to add = installed on this machine AND not already in defaults
      final available = installedNames
          .where((n) => !existingLower.contains(n.toLowerCase()))
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (available.isEmpty) {
        _showInfoDialog('Info', 'Tidak ada aplikasi terinstal yang bisa ditambahkan.\nSemua yang tersedia sudah ada di daftar default.');
        return;
      }

      String search = '';
      String? selected;
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          List<String> filtered = available;
          return StatefulBuilder(
            builder: (ctx, setStateSB) {
              filtered = available
                  .where((n) => n.toLowerCase().contains(search.toLowerCase()))
                  .toList();
              return AlertDialog(
                title: Text('Tambah Aplikasi Default'),
                content: SizedBox(
                  width: 450,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Cari aplikasi terinstal',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setStateSB(() => search = v),
                      ),
                      SizedBox(height: 12),
                      Container(
                        height: 300,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (c, i) {
                            final name = filtered[i];
                            return RadioListTile<String>(
                              dense: true,
                              title: Text(name),
                              value: name,
                              groupValue: selected,
                              onChanged: (val) => setStateSB(() => selected = val),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('Batal'),
                  ),
                  ElevatedButton(
                    onPressed: selected == null
                        ? null
                        : () async {
                            // Persist selection
                            final existing = await ApplicationService.loadDefaultAppChecks();
                            if (!existing.map((e) => e.toLowerCase()).contains(selected!.toLowerCase())) {
                              existing.add(selected!);
                              await ApplicationService.saveDefaultAppChecks(existing);
                            }
                            Navigator.of(ctx).pop();
                          },
                    child: Text('Tambah'),
                  ),
                ],
              );
            },
          );
        },
      );

      // Refresh default apps to include the new entry
      await _refreshDefaultApps();
      setState(() {
        _statusMessage = 'Aplikasi default berhasil ditambahkan.';
      });
    } catch (e) {
      _showErrorDialog('Error', 'Gagal menambahkan aplikasi default: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Two column layout
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Default applications section
                Expanded(
                  child: InstalledAppsSection(
                    defaultApps: _defaultApps,
                    isLoading: _isLoadingDefault,
                    onRefresh: _refreshDefaultApps,
                    onAddDefault: _onAddDefaultApp,
                    customNames: _customDefaultNames,
                    onRemoveDefault: _onRemoveDefaultApp,
                  ),
                ),
                SizedBox(width: 16),
                // Shortcut applications section
                Expanded(
                  child: InstallableAppsSection(
                    installableApps: _shortcutApps,
                    onAppSelectionChanged: _onAppSelectionChanged,
                    onEditApp: _onEditApp,
                    onDeleteApp: _onDeleteApp,
                    onInstallApp: _onInstallApp,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            // Bottom action buttons
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _showAddAppDialog,
                  icon: Icon(Icons.add),
                  label: Text('Tambah Shortcut'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _saveApplicationList,
                  icon: Icon(Icons.save),
                  label: Text('Simpan Daftar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isInstalling ? null : _startInstallation,
                  icon: _isInstalling 
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.play_arrow),
                  label: Text(_isInstalling ? 'Running...' : 'Jalankan Shortcut'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            // Progress indicator
            if (_isLoadingDefault || _isInstalling)
              Column(
                children: [
                  LinearProgressIndicator(),
                  SizedBox(height: 8),
                ],
              ),
            // Status message
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
