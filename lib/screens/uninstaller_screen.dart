import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../models/application_models.dart';
import '../services/system_service.dart';
import '../services/application_service.dart';
import '../data/keyboard_shortcuts.dart';

class _ShortcutItem {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Future<bool> Function() action;
  _ShortcutItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.action,
  });
}

class UninstallerScreen extends StatefulWidget {
  const UninstallerScreen({super.key});

  @override
  State<UninstallerScreen> createState() => _UninstallerScreenState();
}

class _UninstallerScreenState extends State<UninstallerScreen> {
  List<InstalledApplication> _installedApps = [];
  List<InstalledApplication> _filteredApps = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _statusMessage = 'Klik "Refresh" untuk memuat daftar aplikasi terinstal';
  
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _sortBy = 'name'; // name | size | date
  bool _onlyUninstallable = false;

  // Shortcuts dashboard data
  List<_ShortcutItem> _shortcuts = [];
  List<_ShortcutItem> _filteredShortcuts = [];
  Set<String> _favorites = {};

  // Keyboard shortcuts data (static list from data/keyboard_shortcuts.dart)
  List<KeyboardShortcut> _kbShortcuts = keyboardShortcuts;
  List<KeyboardShortcut> _filteredKbShortcuts = keyboardShortcuts;
  String _kbSearchQuery = '';
  final TextEditingController _kbSearchController = TextEditingController();
  Timer? _kbDebounce;

  @override
  void initState() {
    super.initState();
    _initShortcuts();
    _loadFavorites();

    // Initialize keyboard shortcuts list
    _kbShortcuts = List.of(keyboardShortcuts);
    _filteredKbShortcuts = List.of(keyboardShortcuts);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _kbDebounce?.cancel();
    _searchController.dispose();
    _kbSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    try {
      final favs = await ApplicationService.loadShortcutFavorites();
      setState(() {
        _favorites = favs;
      });
      _sortFilteredForFavorites();
    } catch (_) {
      // ignore errors
    }
  }

  Future<void> _loadInstalledApplications() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Memuat daftar aplikasi terinstal...';
    });

    try {
      List<InstalledApplication> apps = await SystemService.getInstalledApplications();
      setState(() {
        _installedApps = apps;
      });
      _applyFiltersSort();
      setState(() {
        _statusMessage = 'Ditemukan ${apps.length} aplikasi terinstal';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterApplications(String query) {
    _searchQuery = query;
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: 300), () {
      _applyFiltersSort();
    });
    setState(() {}); // update suffix clear icon state
  }

  Future<void> _uninstallApplication(InstalledApplication app) async {
    bool? confirm = await _showConfirmationDialog(
      'Konfirmasi Uninstall',
      'Apakah Anda yakin ingin menghapus aplikasi "${app.name}"?\n\n'
      'Versi: ${app.version}\n'
      'Publisher: ${app.publisher}\n\n'
      '⚠️ Tindakan ini tidak dapat dibatalkan!',
    );

    if (confirm == true) {
      setState(() {
        _statusMessage = 'Menghapus ${app.name}...';
      });

      try {
        bool success = await SystemService.uninstallApplication(app);
        if (success) {
          setState(() {
            _statusMessage = '✅ ${app.name} berhasil dihapus';
          });
          // Refresh the list
          await _loadInstalledApplications();
        } else {
          setState(() {
            _statusMessage = '❌ Gagal menghapus ${app.name}';
          });
        }
      } catch (e) {
        setState(() {
          _statusMessage = '❌ Error: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _openApplicationInControlPanel(InstalledApplication app) async {
    setState(() {
      _statusMessage = 'Membuka ${app.name} di Control Panel...';
    });

    try {
      bool success = await SystemService.openApplicationInControlPanel(app);
      if (success) {
        setState(() {
          _statusMessage = 'Control Panel dibuka untuk ${app.name}';
        });
      } else {
        setState(() {
          _statusMessage = 'Gagal membuka Control Panel untuk ${app.name}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
      });
    }
  }

  Future<bool?> _showConfirmationDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Ya, Hapus'),
            ),
          ],
        );
      },
    );
  }

  // ===== Helpers: sort & filter =====
  int _sizeToKB(String sizeText) {
    if (sizeText.isEmpty) return -1;
    final m = RegExp(r'([\d\.,]+)\s*(KB|MB|GB)', caseSensitive: false).firstMatch(sizeText);
    if (m == null) return -1;
    double val = double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0.0;
    final unit = (m.group(2) ?? '').toUpperCase();
    if (unit == 'GB') {
      val *= 1024 * 1024;
    } else if (unit == 'MB') val *= 1024;
    // KB remains KB
    return val.round();
  }

  DateTime? _parseInstallDate(String d) {
    try {
      if (d.isEmpty) return null;
      final parts = d.split('/');
      if (parts.length == 3) {
        // dd/MM/yyyy
        return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
    } catch (_) {}
    return null;
  }

  void _applyFiltersSort() {
    List<InstalledApplication> list = List.of(_installedApps);

    // Search
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((app) => app.name.toLowerCase().contains(q)).toList();
    }

    // Only uninstallable
    if (_onlyUninstallable) {
      list = list.where((app) => (app.uninstallString).trim().isNotEmpty).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'size':
        list.sort((a, b) => (_sizeToKB(b.size)).compareTo(_sizeToKB(a.size)));
        break;
      case 'date':
        list.sort((a, b) {
          final da = _parseInstallDate(a.installDate);
          final db = _parseInstallDate(b.installDate);
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da); // newest first
        });
        break;
      case 'name':
      default:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }

    setState(() {
      _filteredApps = list;
    });
  }

  void _onSortChanged(String? value) {
    if (value == null) return;
    setState(() {
      _sortBy = value;
    });
    _applyFiltersSort();
  }

  void _onToggleOnlyUninstallable(bool v) {
    setState(() {
      _onlyUninstallable = v;
    });
    _applyFiltersSort();
  }

  Widget _buildApplicationTile(InstalledApplication app) {
    // Kept for backward compatibility (not used in shortcuts view)
    return SizedBox.shrink();
  }

  bool _isFavorite(String id) => _favorites.contains(id);

  void _toggleFavorite(String id) {
    setState(() {
      if (_favorites.contains(id)) {
        _favorites.remove(id);
        _statusMessage = '⭐ Favorit dimatikan';
      } else {
        _favorites.add(id);
        _statusMessage = '⭐ Ditandai favorit';
      }
    });
    _sortFilteredForFavorites();
    // Persist favorites across sessions
    ApplicationService.saveShortcutFavorites(_favorites);
  }

  void _sortFilteredForFavorites() {
    setState(() {
      _filteredShortcuts.sort((a, b) {
        final fa = _favorites.contains(a.id);
        final fb = _favorites.contains(b.id);
        if (fa == fb) {
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        }
        // favorites first
        return fb ? 1 : -1;
      });
    });
  }

  // ===== System Shortcuts data and helpers =====
  void _initShortcuts() {
    final items = <_ShortcutItem>[
      _ShortcutItem(
        id: 'control',
        title: 'Control Panel',
        description: 'Buka Control Panel klasik',
        icon: Icons.settings_applications,
        action: SystemService.openControlPanel,
      ),
      _ShortcutItem(
        id: 'programs_features',
        title: 'Programs & Features',
        description: 'Uninstall program (appwiz.cpl)',
        icon: Icons.list_alt,
        action: SystemService.openControlPanelPrograms,
      ),
      _ShortcutItem(
        id: 'dxdiag',
        title: 'DxDiag',
        description: 'Diagnostik DirectX',
        icon: Icons.gamepad,
        action: SystemService.openDxdiag,
      ),
      _ShortcutItem(
        id: 'msconfig',
        title: 'System Configuration',
        description: 'Konfigurasi sistem (msconfig)',
        icon: Icons.tune,
        action: SystemService.openMsconfig,
      ),
      _ShortcutItem(
        id: 'startup',
        title: 'Task Manager - Startup',
        description: 'Kelola aplikasi startup',
        icon: Icons.playlist_add_check,
        action: SystemService.openTaskManagerStartup,
      ),
      _ShortcutItem(
        id: 'devmgmt',
        title: 'Device Manager',
        description: 'Kelola perangkat dan driver',
        icon: Icons.usb,
        action: SystemService.openDeviceManager,
      ),
      _ShortcutItem(
        id: 'services',
        title: 'Services',
        description: 'Konsol layanan (services.msc)',
        icon: Icons.miscellaneous_services,
        action: SystemService.openServicesConsole,
      ),
      _ShortcutItem(
        id: 'features',
        title: 'Windows Features',
        description: 'Aktif/Nonaktif fitur Windows',
        icon: Icons.extension,
        action: SystemService.openWindowsFeatures,
      ),
      _ShortcutItem(
        id: 'sysprops',
        title: 'System Properties',
        description: 'Properti sistem (sysdm.cpl)',
        icon: Icons.computer,
        action: SystemService.openSystemProperties,
      ),
      _ShortcutItem(
        id: 'diskmgmt',
        title: 'Disk Management',
        description: 'Kelola partisi disk',
        icon: Icons.storage,
        action: SystemService.openDiskManagement,
      ),
      _ShortcutItem(
        id: 'cleanmgr',
        title: 'Disk Cleanup',
        description: 'Bersihkan file sementara',
        icon: Icons.cleaning_services,
        action: SystemService.openDiskCleanup,
      ),
      _ShortcutItem(
        id: 'network',
        title: 'Network Connections',
        description: 'Adaptor jaringan (ncpa.cpl)',
        icon: Icons.wifi_tethering,
        action: SystemService.openNetworkConnections,
      ),
      _ShortcutItem(
        id: 'firewall',
        title: 'Windows Firewall',
        description: 'Pengaturan firewall',
        icon: Icons.security,
        action: SystemService.openFirewall,
      ),
      _ShortcutItem(
        id: 'updates',
        title: 'Windows Update',
        description: 'Pengaturan pembaruan',
        icon: Icons.system_update,
        action: SystemService.openWindowsUpdateSettings,
      ),
      _ShortcutItem(
        id: 'security',
        title: 'Windows Security',
        description: 'Keamanan Windows',
        icon: Icons.shield,
        action: SystemService.openWindowsSecurity,
      ),
      _ShortcutItem(
        id: 'regedit',
        title: 'Registry Editor',
        description: 'Editor registry (regedit)',
        icon: Icons.folder_special,
        action: SystemService.openRegistryEditor,
      ),
      _ShortcutItem(
        id: 'env',
        title: 'Environment Variables',
        description: 'Edit variabel lingkungan',
        icon: Icons.code,
        action: SystemService.openEnvironmentVariables,
      ),
      // Tambahan Settings URI yang berguna
      _ShortcutItem(
        id: 'settings_apps',
        title: 'Settings: Apps',
        description: 'Kelola aplikasi (ms-settings:appsfeatures)',
        icon: Icons.apps,
        action: () => SystemService.openSettingsUri('ms-settings:appsfeatures'),
      ),
      _ShortcutItem(
        id: 'settings_startupapps',
        title: 'Settings: Startup Apps',
        description: 'Kelola app startup (ms-settings:startupapps)',
        icon: Icons.power_settings_new,
        action: () => SystemService.openSettingsUri('ms-settings:startupapps'),
      ),
      _ShortcutItem(
        id: 'settings_storage',
        title: 'Settings: Storage',
        description: 'Storage Sense (ms-settings:storagesense)',
        icon: Icons.sd_storage,
        action: () => SystemService.openSettingsUri('ms-settings:storagesense'),
      ),
      _ShortcutItem(
        id: 'settings_network',
        title: 'Settings: Network',
        description: 'Jaringan & Internet (ms-settings:network-status)',
        icon: Icons.settings_ethernet,
        action: () => SystemService.openSettingsUri('ms-settings:network-status'),
      ),

      // ===== Tambahan Shortcut Admin & Tools =====
      _ShortcutItem(
        id: 'event_viewer',
        title: 'Event Viewer',
        description: 'Lihat log sistem (eventvwr.msc)',
        icon: Icons.event,
        action: SystemService.openEventViewer,
      ),
      _ShortcutItem(
        id: 'task_scheduler',
        title: 'Task Scheduler',
        description: 'Jadwalkan tugas (taskschd.msc)',
        icon: Icons.schedule,
        action: SystemService.openTaskScheduler,
      ),
      _ShortcutItem(
        id: 'performance_monitor',
        title: 'Performance Monitor',
        description: 'Monitor kinerja (perfmon)',
        icon: Icons.speed,
        action: SystemService.openPerformanceMonitor,
      ),
      _ShortcutItem(
        id: 'system_information',
        title: 'System Information',
        description: 'Informasi sistem (msinfo32)',
        icon: Icons.info,
        action: SystemService.openSystemInformation,
      ),
      _ShortcutItem(
        id: 'computer_management',
        title: 'Computer Management',
        description: 'Manajemen komputer (compmgmt.msc)',
        icon: Icons.settings,
        action: SystemService.openComputerManagement,
      ),
      _ShortcutItem(
        id: 'group_policy',
        title: 'Local Group Policy',
        description: 'Kebijakan lokal (gpedit.msc)',
        icon: Icons.policy,
        action: SystemService.openGroupPolicy,
      ),
      _ShortcutItem(
        id: 'command_prompt',
        title: 'Command Prompt',
        description: 'Buka CMD',
        icon: Icons.code,
        action: SystemService.openCommandPrompt,
      ),
      _ShortcutItem(
        id: 'powershell',
        title: 'Windows PowerShell',
        description: 'Buka PowerShell',
        icon: Icons.code,
        action: SystemService.openPowerShell,
      ),
      _ShortcutItem(
        id: 'windows_terminal',
        title: 'Windows Terminal',
        description: 'Buka Windows Terminal (wt)',
        icon: Icons.code,
        action: SystemService.openWindowsTerminal,
      ),

      // ===== Tambahan Shortcut Settings =====
      _ShortcutItem(
        id: 'settings_display',
        title: 'Settings: Display',
        description: 'Pengaturan tampilan (ms-settings:display)',
        icon: Icons.desktop_windows,
        action: () => SystemService.openSettingsUri('ms-settings:display'),
      ),
      _ShortcutItem(
        id: 'settings_bluetooth',
        title: 'Settings: Bluetooth',
        description: 'Bluetooth & devices (ms-settings:bluetooth)',
        icon: Icons.bluetooth,
        action: () => SystemService.openSettingsUri('ms-settings:bluetooth'),
      ),
      _ShortcutItem(
        id: 'settings_privacy',
        title: 'Settings: Privacy',
        description: 'Privasi Windows (ms-settings:privacy)',
        icon: Icons.privacy_tip,
        action: () => SystemService.openSettingsUri('ms-settings:privacy'),
      ),
      _ShortcutItem(
        id: 'settings_about',
        title: 'Settings: About',
        description: 'Tentang perangkat (ms-settings:about)',
        icon: Icons.info_outline,
        action: () => SystemService.openSettingsUri('ms-settings:about'),
      ),
    ];

    setState(() {
      _shortcuts = items;
      _filteredShortcuts = List.of(items);
      _statusMessage = 'Shortcut siap (${items.length} item)';
    });
    _sortFilteredForFavorites();
  }

  void _filterShortcuts(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filteredShortcuts = List.of(_shortcuts));
      _sortFilteredForFavorites();
      return;
    }
    setState(() {
      _filteredShortcuts = _shortcuts
          .where((s) =>
              s.title.toLowerCase().contains(q) ||
              s.description.toLowerCase().contains(q))
          .toList();
    });
    _sortFilteredForFavorites();
  }

  Future<void> _openShortcut(_ShortcutItem item) async {
    setState(() => _statusMessage = 'Membuka ${item.title} ...');
    try {
      final ok = await item.action();
      setState(() => _statusMessage = ok ? '✅ Berhasil membuka ${item.title}' : '❌ Gagal membuka ${item.title}');
    } catch (e) {
      setState(() => _statusMessage = '❌ Error membuka ${item.title}: $e');
    }
  }

  Widget _buildShortcutCard(_ShortcutItem item) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openShortcut(item),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blue.shade50,
                    child: Icon(item.icon, color: Colors.blue.shade700),
                  ),
                  Spacer(),
                  IconButton(
                    tooltip: _isFavorite(item.id) ? 'Matikan Favorit' : 'Jadikan Favorit',
                    onPressed: () => _toggleFavorite(item.id),
                    icon: Icon(
                      _isFavorite(item.id) ? Icons.star : Icons.star_border,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              SizedBox(height: 6),
              Expanded(
                child: Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
              SizedBox(height: 10),
              Align(
                alignment: Alignment.bottomRight,
                child: ElevatedButton.icon(
                  onPressed: () => _openShortcut(item),
                  icon: Icon(Icons.open_in_new, size: 18),
                  label: Text('Open'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Keyboard Shortcuts helpers =====
  void _filterKbShortcuts(String query) {
    _kbSearchQuery = query;
    _kbDebounce?.cancel();
    _kbDebounce = Timer(Duration(milliseconds: 250), () {
      final q = _kbSearchQuery.trim().toLowerCase();
      if (q.isEmpty) {
        setState(() {
          _filteredKbShortcuts = List.of(_kbShortcuts);
        });
        return;
      }
      setState(() {
        _filteredKbShortcuts = _kbShortcuts.where((s) {
          return s.keys.toLowerCase().contains(q) ||
                 s.title.toLowerCase().contains(q) ||
                 s.description.toLowerCase().contains(q) ||
                 s.category.toLowerCase().contains(q);
        }).toList();
      });
    });
    setState(() {}); // update clear icon state
  }

  Widget _buildKbShortcutCard(KeyboardShortcut s) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category badge and copy icons
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    s.category,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                  ),
                ),
                Spacer(),
                IconButton(
                  tooltip: 'Copy keys',
                  icon: Icon(Icons.copy, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: s.keys));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied: ${s.keys}'), duration: Duration(milliseconds: 900)),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Copy description',
                  icon: Icon(Icons.notes, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: '${s.title}: ${s.description}'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied description'), duration: Duration(milliseconds: 900)),
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              s.keys,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            SizedBox(height: 6),
            Text(
              s.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            SizedBox(height: 6),
            Expanded(
              child: Text(
                s.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = MediaQuery.of(context).size.width > 1000
        ? 4
        : MediaQuery.of(context).size.width > 700
            ? 3
            : 2;

    return Scaffold(
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            // Top TabBar
            Container(
              color: Colors.grey.shade50,
              child: TabBar(
                indicatorColor: Theme.of(context).colorScheme.primary,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Colors.grey.shade700,
                tabs: const [
                  Tab(icon: Icon(Icons.widgets), text: 'System Tools'),
                  Tab(icon: Icon(Icons.keyboard), text: 'Keyboard Shortcuts'),
                ],
              ),
            ),

            // Tab views
            Expanded(
              child: TabBarView(
                children: [
                  // ===== Tab 1: System Tools (existing) =====
                  Column(
                    children: [
                      // Header with search and quick actions
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Cari shortcut sistem...',
                                prefixIcon: Icon(Icons.search),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _searchQuery = '';
                                          });
                                          _filterShortcuts('');
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (q) {
                                _searchQuery = q;
                                _debounce?.cancel();
                                _debounce = Timer(Duration(milliseconds: 250), () => _filterShortcuts(q));
                              },
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Spacer(),
                                Text(
                                  'Shortcut: ${_filteredShortcuts.length}',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Loading indicator (kept for compatibility)
                      if (_isLoading)
                        Container(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              LinearProgressIndicator(),
                              SizedBox(height: 8),
                              Text('Memuat...'),
                            ],
                          ),
                        ),

                      // Shortcuts grid
                      Expanded(
                        child: _filteredShortcuts.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.widgets, size: 64, color: Colors.grey.shade400),
                                    SizedBox(height: 12),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'Tidak ada shortcut yang cocok'
                                          : 'Tidak ada shortcut tersedia',
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              )
                            : GridView.builder(
                                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 1.4,
                                ),
                                itemCount: _filteredShortcuts.length,
                                itemBuilder: (context, index) {
                                  return _buildShortcutCard(_filteredShortcuts[index]);
                                },
                              ),
                      ),
                    ],
                  ),

                  // ===== Tab 2: Keyboard Shortcuts =====
                  Column(
                    children: [
                      // Header with search and count
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _kbSearchController,
                              decoration: InputDecoration(
                                hintText: 'Cari keyboard shortcut (keys/judul/kategori)...',
                                prefixIcon: Icon(Icons.search),
                                suffixIcon: _kbSearchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear),
                                        onPressed: () {
                                          _kbSearchController.clear();
                                          setState(() {
                                            _kbSearchQuery = '';
                                          });
                                          _filterKbShortcuts('');
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (q) => _filterKbShortcuts(q),
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Spacer(),
                                Text(
                                  'Keyboard: ${_filteredKbShortcuts.length}',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Keyboard shortcuts grid
                      Expanded(
                        child: _filteredKbShortcuts.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.keyboard, size: 64, color: Colors.grey.shade400),
                                    SizedBox(height: 12),
                                    Text(
                                      _kbSearchQuery.isNotEmpty
                                          ? 'Tidak ada keyboard shortcut yang cocok'
                                          : 'Tidak ada keyboard shortcut tersedia',
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              )
                            : GridView.builder(
                                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 1.4,
                                ),
                                itemCount: _filteredKbShortcuts.length,
                                itemBuilder: (context, index) {
                                  return _buildKbShortcutCard(_filteredKbShortcuts[index]);
                                },
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Status bar (kept for System Tools)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Text(
                _statusMessage,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
