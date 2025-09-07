import 'package:flutter/material.dart';
import '../models/system_status.dart';
import '../services/system_service.dart';
import '../widgets/browser_section.dart';
import '../widgets/system_folders_section.dart';
import '../widgets/windows_system_section.dart';
import 'application_screen.dart';
import 'uninstaller_screen.dart';
import 'battery_screen.dart';
import 'testing_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Browser selection states
  bool _chromeSelected = true;
  bool _edgeSelected = true;
  bool _firefoxSelected = true;
  bool _resetBrowserSelected = true;
  bool _selectAllBrowsers = true;

  // System folders selection states
  bool _objects3dSelected = false;
  bool _documentsSelected = false;
  bool _downloadsSelected = false;
  bool _musicSelected = false;
  bool _picturesSelected = false;
  bool _videosSelected = false;
  bool _selectAllFolders = false;

  // Windows system states
  bool _clearRecentSelected = false;
  bool _clearRecycleBinSelected = false;
  bool _isChecking = false;
  bool _isCleaning = false;
  bool _skipActivationOnCheckAll = false;

  // System status
  SystemStatus _defenderStatus = SystemStatus(status: "Checking...");
  SystemStatus _updateStatus = SystemStatus(status: "Checking...");
  SystemStatus _driverStatus = SystemStatus(status: "Checking...");
  SystemStatus _windowsActivationStatus = SystemStatus(status: "Checking...");
  SystemStatus _officeActivationStatus = SystemStatus(status: "Checking...");

  // Folder information
  List<FolderInfo> _folderInfos = [];

  // Status message
  String _statusMessage = "Siap untuk membersihkan browser dan folder sistem";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    // Preload System Folders size on startup so UI tidak menampilkan 0 B.
    // Gunakan metode cepat terlebih dahulu, lalu fallback ke metode akurat jika hasil nol.
    Future.microtask(() async {
      try {
        await _checkFolderSizesFast();
        // Jika masih kosong/0 B untuk semua folder yang ada, lakukan perhitungan akurat.
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        final existsList = _folderInfos.where((f) => f.exists).toList();
        final allZero = existsList.isNotEmpty && existsList.every((f) => f.sizeBytes == 0);
        if (_folderInfos.isEmpty || allZero) {
          final accurate = await SystemService.getFolderSizes();
          if (!mounted) return;
          setState(() {
            _folderInfos = accurate;
          });
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Browser selection methods
  void _onChromeChanged(bool value) {
    setState(() {
      _chromeSelected = value;
      _updateSelectAllBrowsers();
    });
  }

  void _onEdgeChanged(bool value) {
    setState(() {
      _edgeSelected = value;
      _updateSelectAllBrowsers();
    });
  }

  void _onFirefoxChanged(bool value) {
    setState(() {
      _firefoxSelected = value;
      _updateSelectAllBrowsers();
    });
  }

  void _onResetBrowserChanged(bool value) {
    setState(() {
      _resetBrowserSelected = value;
    });
  }

  void _onSelectAllBrowsersChanged(bool value) {
    setState(() {
      _selectAllBrowsers = value;
      _chromeSelected = value;
      _edgeSelected = value;
      _firefoxSelected = value;
    });
  }

  void _updateSelectAllBrowsers() {
    _selectAllBrowsers = _chromeSelected && _edgeSelected && _firefoxSelected;
  }

  // System folders selection methods
  void _onObjects3dChanged(bool value) {
    setState(() {
      _objects3dSelected = value;
      _updateSelectAllFolders();
    });
  }

  void _onDocumentsChanged(bool value) {
    setState(() {
      _documentsSelected = value;
      _updateSelectAllFolders();
    });
  }

  void _onDownloadsChanged(bool value) {
    setState(() {
      _downloadsSelected = value;
      _updateSelectAllFolders();
    });
  }

  void _onMusicChanged(bool value) {
    setState(() {
      _musicSelected = value;
      _updateSelectAllFolders();
    });
  }

  void _onPicturesChanged(bool value) {
    setState(() {
      _picturesSelected = value;
      _updateSelectAllFolders();
    });
  }

  void _onVideosChanged(bool value) {
    setState(() {
      _videosSelected = value;
      _updateSelectAllFolders();
    });
  }

  void _onSelectAllFoldersChanged(bool value) {
    setState(() {
      _selectAllFolders = value;
      _objects3dSelected = value;
      _documentsSelected = value;
      _downloadsSelected = value;
      _musicSelected = value;
      _picturesSelected = value;
      _videosSelected = value;
    });
  }

  void _updateSelectAllFolders() {
    _selectAllFolders = _objects3dSelected &&
        _documentsSelected &&
        _downloadsSelected &&
        _musicSelected &&
        _picturesSelected &&
        _videosSelected;
  }

  void _onClearRecentChanged(bool value) {
    setState(() {
      _clearRecentSelected = value;
    });
  }

  void _onClearRecycleBinChanged(bool value) {
    setState(() {
      _clearRecycleBinSelected = value;
    });
  }

  // System checking methods
  Future<void> _checkAllStatus() async {
    setState(() {
      _isChecking = true;
      _statusMessage = "Menjalankan semua pemeriksaan...";
    });

    try {
      // Jalankan pengecekan ukuran folder dan status sistem secara paralel
      final defenderF = SystemService
          .checkWindowsDefender()
          .timeout(const Duration(seconds: 3), onTimeout: () => SystemStatus(status: "Timeout", isActive: false));

      final updateF = SystemService
          .checkWindowsUpdate()
          .timeout(const Duration(seconds: 3), onTimeout: () => SystemStatus(status: "Timeout", isActive: false));

      final driverF = SystemService
          .checkDrivers()
          .timeout(const Duration(seconds: 3), onTimeout: () => SystemStatus(status: "Timeout", isActive: false));

      final windowsActF = _skipActivationOnCheckAll
          ? Future.value(SystemStatus(status: "⏭️ Dilewati (tekan Cek Ulang)", isActive: false))
          : SystemService
              .checkWindowsActivation()
              .timeout(const Duration(seconds: 15), onTimeout: () => SystemStatus(status: "⏳ Ditunda (akan diperbarui)", isActive: false));

      // Office check bisa lambat (cscript), beri timeout agar UI tidak terhambat
      final officeActF = _skipActivationOnCheckAll
          ? Future.value(SystemStatus(status: "⏭️ Dilewati (tekan Cek Ulang)", isActive: false))
          : SystemService
              .checkOfficeActivation()
              .timeout(const Duration(seconds: 15), onTimeout: () => SystemStatus(status: "⏳ Ditunda (akan diperbarui)", isActive: false));

      // Gunakan metode cepat untuk ukuran folder (berbasis robocopy) dengan timeout
      _checkFolderSizesFast();

      final results = await Future.wait<SystemStatus>([
        defenderF,
        updateF,
        driverF,
        windowsActF,
        officeActF,
      ]);

      // Perhitungan ukuran folder berjalan di background (tidak diblok menunggu di sini)

      setState(() {
        _defenderStatus = results[0];
        _updateStatus = results[1];
        _driverStatus = results[2];
        _windowsActivationStatus = results[3];
        _officeActivationStatus = results[4];
        _statusMessage = "Semua pemeriksaan selesai";
      });

      // If activation checks were deferred (timeout/policy), retry in background with longer window
      final wStat = _windowsActivationStatus.status.toLowerCase();
      if (wStat.contains("ditunda") || wStat.contains("timeout")) {
        _refreshWindowsActivationInBackground();
      }
      final oStat = _officeActivationStatus.status.toLowerCase();
      if (oStat.contains("ditunda") || oStat.contains("timeout")) {
        _refreshOfficeActivationInBackground();
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Error: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isChecking = false;
      });
    }
  }

  // ignore: unused_element
  Future<void> _checkFolderSizes() async {
    try {
      final folderInfos = await SystemService.getFolderSizes();
      if (!mounted) return;
      if (_folderInfos.isEmpty) {
        setState(() {
          _folderInfos = folderInfos;
        });
      } else {
        _applyStableFolderInfos(folderInfos);
      }
    } catch (e) {
      debugPrint('Error checking folder sizes: $e');
    }
  }

  // Stabilkan update ukuran agar tidak kembali ke 0 B bila hasil sementara gagal.
  void _applyStableFolderInfos(List<FolderInfo> next) {
    final prevByName = {for (final f in _folderInfos) f.name: f};
    final merged = <FolderInfo>[];
    for (final n in next) {
      final p = prevByName[n.name];
      if (p != null) {
        // Jika hasil baru 0 B tapi sebelumnya ada nilai > 0, pertahankan yang lama.
        // Ini menghindari "kedip" kembali ke 0 saat robocopy/PS sementara gagal.
        final keepPrev = n.exists && n.sizeBytes == 0 && p.sizeBytes > 0;
        if (keepPrev) {
          merged.add(FolderInfo(
            name: p.name,
            path: n.path.isNotEmpty ? n.path : p.path,
            size: p.size,
            exists: p.exists || n.exists,
            sizeBytes: p.sizeBytes,
          ));
          continue;
        }
      }
      merged.add(n);
    }
    setState(() {
      _folderInfos = merged;
    });
  }

  // Versi cepat untuk ukuran folder (batas waktu agar UI tidak menunggu lama)
  Future<void> _checkFolderSizesFast() async {
    try {
      final folderInfos = await SystemService.getFolderSizesUltraFast(timeout: const Duration(seconds: 6));
      if (!mounted) return;
      if (_folderInfos.isEmpty) {
        setState(() {
          _folderInfos = folderInfos;
        });
      } else {
        _applyStableFolderInfos(folderInfos);
      }
    } catch (e) {
      // Jika gagal, biarkan diam-diam agar tidak menghambat UI
      debugPrint('Error checking folder sizes (fast): $e');
    }
  }

  // System action methods
  Future<void> _updateDefender() async {
    setState(() {
      _statusMessage = "Updating Windows Defender...";
    });

    bool success = await SystemService.updateWindowsDefender();
    if (success) {
      setState(() {
        _defenderStatus = SystemStatus(status: "✅ Updated", isActive: true);
        _statusMessage = "Windows Defender updated successfully";
      });
    } else {
      setState(() {
        _statusMessage = "Failed to update Windows Defender";
      });
    }
  }

  Future<void> _runWindowsUpdate() async {
    setState(() {
      _statusMessage = "Running Windows Update...";
    });

    bool success = await SystemService.runWindowsUpdate();
    if (success) {
      setState(() {
        _updateStatus = SystemStatus(status: "✅ Updates installed", isActive: true);
        _statusMessage = "Windows Update completed successfully";
      });
    } else {
      setState(() {
        _statusMessage = "Failed to run Windows Update";
      });
    }
  }

  Future<void> _updateDrivers() async {
    setState(() {
      _statusMessage = "Updating drivers...";
    });

    bool success = await SystemService.updateDrivers();
    if (success) {
      setState(() {
        _driverStatus = SystemStatus(status: "✅ Scan completed", isActive: true);
        _statusMessage = "Driver scan completed successfully";
      });
    } else {
      setState(() {
        _statusMessage = "Failed to update drivers";
      });
    }
  }

  Future<void> _activateWindows() async {
    bool? confirm = await _showConfirmationDialog(
      'Konfirmasi Aktivasi Windows',
      'Apakah Anda yakin ingin mengaktifkan Windows?\n\n'
      'Script akan dijalankan melalui PowerShell dengan perintah:\n'
      'irm https://get.activated.win | iex\n\n'
      '⚠️ Pastikan Anda memiliki koneksi internet yang stabil.',
    );

    if (confirm == true) {
      setState(() {
        _statusMessage = "Activating Windows...";
      });

      bool success = await SystemService.activateWindows();
      if (success) {
        setState(() {
          _statusMessage = "Verifying Windows activation status...";
        });
        final st = await SystemService.checkWindowsActivation();
        setState(() {
          _windowsActivationStatus = st;
          _statusMessage = "Windows activation completed: ${st.status}";
        });
      } else {
        setState(() {
          _statusMessage = "Failed to activate Windows";
        });
      }
    }
  }

  Future<void> _activateOffice() async {
    bool? confirm = await _showConfirmationDialog(
      'Konfirmasi Aktivasi Office',
      'Apakah Anda yakin ingin mengaktifkan Microsoft Office?\n\n'
      'Script akan dijalankan melalui PowerShell dengan perintah:\n'
      'irm https://get.activated.win | iex\n\n'
      '⚠️ Pastikan Anda memiliki koneksi internet yang stabil.',
    );
  
    if (confirm == true) {
      setState(() {
        _statusMessage = "Activating Office...";
      });
  
      bool success = await SystemService.activateOffice();
      if (success) {
        setState(() {
          _statusMessage = "Verifying Office activation status...";
        });
        final st = await SystemService.checkOfficeActivation();
        setState(() {
          _officeActivationStatus = st;
          _statusMessage = "Office activation completed: ${st.status}";
        });
      } else {
        setState(() {
          _statusMessage = "Failed to activate Office";
        });
      }
    }
  }

  Future<void> _openActivationShell() async {
    bool? confirm = await _showConfirmationDialog(
      'Buka PowerShell Aktivasi',
      'Ini akan membuka jendela PowerShell dan menjalankan:\n'
      'irm https://get.activated.win | iex\n\n'
      'Lanjutkan?',
    );

    if (confirm == true) {
      setState(() {
        _statusMessage = "Membuka PowerShell Aktivasi...";
      });
      bool ok = await SystemService.openActivationPowerShell();
      setState(() {
        _statusMessage = ok
            ? "PowerShell dibuka. Ikuti instruksi untuk aktivasi Windows/Office."
            : "Gagal membuka PowerShell Aktivasi.";
      });
    }
  }
  
  Future<void> _openWindowsUpdateSettings() async {
    setState(() {
      _statusMessage = "Membuka Windows Update settings...";
    });
    await SystemService.openWindowsUpdateSettings();
  }

  Future<void> _openWindowsSecurity() async {
    setState(() {
      _statusMessage = "Membuka Windows Security...";
    });
    await SystemService.openWindowsSecurity();
  }

  Future<void> _openDeviceManager() async {
    setState(() {
      _statusMessage = "Membuka Device Manager...";
    });
    await SystemService.openDeviceManager();
  }
  
  // Activation re-check (background) helpers
  Future<void> _refreshWindowsActivationInBackground() async {
    try {
      final st = await SystemService.checkWindowsActivation();
      if (!mounted) return;
      if (st.status.isNotEmpty && st.status != _windowsActivationStatus.status) {
        setState(() {
          _windowsActivationStatus = st;
        });
      }
    } catch (_) {}
  }

  Future<void> _refreshOfficeActivationInBackground() async {
    try {
      final st = await SystemService.checkOfficeActivation();
      if (!mounted) return;
      if (st.status.isNotEmpty && st.status != _officeActivationStatus.status) {
        setState(() {
          _officeActivationStatus = st;
        });
      }
    } catch (_) {}
  }

  // Selection methods
  void _selectAllEverything() {
    setState(() {
      _selectAllBrowsers = true;
      _selectAllFolders = true;
      _resetBrowserSelected = true;
      _clearRecentSelected = true;
      _clearRecycleBinSelected = true;
      _onSelectAllBrowsersChanged(true);
      _onSelectAllFoldersChanged(true);
    });
  }

  void _deselectAllEverything() {
    setState(() {
      _selectAllBrowsers = false;
      _selectAllFolders = false;
      _resetBrowserSelected = false;
      _clearRecentSelected = false;
      _clearRecycleBinSelected = false;
      _onSelectAllBrowsersChanged(false);
      _onSelectAllFoldersChanged(false);
    });
  }

  // Cleaning method
  Future<void> _startCleaning() async {
    bool browserSelected = _chromeSelected || _edgeSelected || _firefoxSelected;
    bool folderSelected = _objects3dSelected ||
        _documentsSelected ||
        _downloadsSelected ||
        _musicSelected ||
        _picturesSelected ||
        _videosSelected;
    bool recentSelected = _clearRecentSelected;
    bool recycleSelected = _clearRecycleBinSelected;

    if (!browserSelected && !folderSelected && !recentSelected && !recycleSelected) {
      _showWarningDialog(
        'Peringatan',
        'Silakan pilih minimal satu opsi untuk dijalankan!',
      );
      return;
    }

    String confirmMessage = 'Apakah Anda yakin ingin melakukan operasi berikut?\n\n';
    if (browserSelected) confirmMessage += '✓ Data browser akan dihapus\n';
    if (folderSelected) confirmMessage += '✓ File di folder sistem akan dihapus PERMANEN\n';
    if (recentSelected) confirmMessage += '✓ Jejak recent (Start/Search, Quick Access, Office) akan dihapus & Photos akan di-unpin\n';
    if (recycleSelected) confirmMessage += '✓ Recycle Bin akan dikosongkan\n';

    bool? confirm = await _showConfirmationDialog('Konfirmasi', confirmMessage);
    if (confirm != true) return;

    setState(() {
      _isCleaning = true;
      _statusMessage = "Memulai proses pembersihan...";
    });

    try {
      List<String> cleanedBrowsers = [];
      List<String> cleanedFolders = [];
      bool recentCleared = false;
      bool recycleCleared = false;

      // Clean browsers
      if (browserSelected && _resetBrowserSelected) {
        setState(() {
          _statusMessage = "Menutup browser dan mereset ke setelan awal...";
        });

        cleanedBrowsers = await SystemService.cleanBrowsers(
          chrome: _chromeSelected,
          edge: _edgeSelected,
          firefox: _firefoxSelected,
          resetBrowser: _resetBrowserSelected,
        );
      }

      // Clean system folders
      if (folderSelected) {
        setState(() {
          _statusMessage = "Membersihkan folder sistem...";
        });

        cleanedFolders = await SystemService.cleanSystemFolders(
          documents: _documentsSelected,
          downloads: _downloadsSelected,
          music: _musicSelected,
          pictures: _picturesSelected,
          videos: _videosSelected,
          objects3d: _objects3dSelected,
        );
      }

      // Clear recent files
      if (recentSelected) {
        setState(() {
          _statusMessage = "Menghapus Recent Files...";
        });

        recentCleared = await SystemService.clearRecentFiles();
      }

      // Clear recycle bin
      if (recycleSelected) {
        setState(() {
          _statusMessage = "Mengosongkan Recycle Bin...";
        });

        recycleCleared = await SystemService.clearRecycleBin();
      }

      // Show results
      String resultMessage = '';
      if (cleanedBrowsers.isNotEmpty) {
        resultMessage += '✅ Browser berhasil di-reset:\n${cleanedBrowsers.join('\n')}\n\n';
      }
      if (cleanedFolders.isNotEmpty) {
        resultMessage += '✅ Folder sistem berhasil dibersihkan:\n${cleanedFolders.join('\n')}\n\n';
      }
      if (recentCleared) {
        resultMessage += '✅ Recent files berhasil dihapus (termasuk unpin Photos).\n\n';
      }
      if (recycleCleared) {
        resultMessage += '✅ Recycle Bin berhasil dikosongkan.\n\n';
      }

      if (resultMessage.isNotEmpty) {
        _showInfoDialog('Selesai', resultMessage.trim());
        setState(() {
          _statusMessage = "Pembersihan selesai.";
        });
      } else {
        setState(() {
          _statusMessage = "Tidak ada aksi yang dilakukan.";
        });
        _showInfoDialog('Info', 'Tidak ada browser atau folder yang dipilih untuk dibersihkan.');
      }
    } catch (e) {
      setState(() {
        _statusMessage = "❌ Gagal melakukan pembersihan: ${e.toString()}";
      });
      _showErrorDialog('Error', 'Terjadi kesalahan saat proses pembersihan:\n${e.toString()}');
    } finally {
      setState(() {
        _isCleaning = false;
      });
    }
  }

  // Dialog methods
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
              child: Text('Ya'),
            ),
          ],
        );
      },
    );
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SEKOM Group',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Icon(Icons.cleaning_services),
              text: 'System Cleaner',
            ),
            Tab(
              icon: Icon(Icons.apps),
              text: 'Application Manager',
            ),
            Tab(
              icon: Icon(Icons.delete_outline),
              text: 'Shortcut',
            ),
            Tab(
              icon: Icon(Icons.battery_charging_full),
              text: 'Battery Health',
            ),
            Tab(
              icon: Icon(Icons.science),
              text: 'Testing',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // System Cleaner Tab
          _buildSystemCleanerTab(),
          // Application Manager Tab
          ApplicationScreen(),
          // Uninstaller Tab
          UninstallerScreen(),
          // Battery Health Tab
          BatteryScreen(),
          // Testing Tab
          TestingScreen(),
        ],
      ),
    );
  }

  Widget _buildSystemCleanerTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Three column layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Browser section
              Expanded(
                child: BrowserSection(
                  chromeSelected: _chromeSelected,
                  edgeSelected: _edgeSelected,
                  firefoxSelected: _firefoxSelected,
                  resetBrowserSelected: _resetBrowserSelected,
                  selectAllBrowsers: _selectAllBrowsers,
                  onChromeChanged: _onChromeChanged,
                  onEdgeChanged: _onEdgeChanged,
                  onFirefoxChanged: _onFirefoxChanged,
                  onResetBrowserChanged: _onResetBrowserChanged,
                  onSelectAllBrowsersChanged: _onSelectAllBrowsersChanged,
                ),
              ),
              SizedBox(width: 16),
              // System folders section
              Expanded(
                child: SystemFoldersSection(
                  objects3dSelected: _objects3dSelected,
                  documentsSelected: _documentsSelected,
                  downloadsSelected: _downloadsSelected,
                  musicSelected: _musicSelected,
                  picturesSelected: _picturesSelected,
                  videosSelected: _videosSelected,
                  selectAllFolders: _selectAllFolders,
                  folderInfos: _folderInfos,
                  onObjects3dChanged: _onObjects3dChanged,
                  onDocumentsChanged: _onDocumentsChanged,
                  onDownloadsChanged: _onDownloadsChanged,
                  onMusicChanged: _onMusicChanged,
                  onPicturesChanged: _onPicturesChanged,
                  onVideosChanged: _onVideosChanged,
                  onSelectAllFoldersChanged: _onSelectAllFoldersChanged,
                ),
              ),
              SizedBox(width: 16),
              // Windows system section
              Expanded(
                child: WindowsSystemSection(
                  defenderStatus: _defenderStatus,
                  updateStatus: _updateStatus,
                  driverStatus: _driverStatus,
                  windowsActivationStatus: _windowsActivationStatus,
                  officeActivationStatus: _officeActivationStatus,
                  clearRecentSelected: _clearRecentSelected,
                  isChecking: _isChecking,
                  onUpdateDefender: _updateDefender,
                  onRunWindowsUpdate: _runWindowsUpdate,
                  onUpdateDrivers: _updateDrivers,
                  onActivateWindows: _activateWindows,
                  onActivateOffice: _activateOffice,
                  onOpenActivationShell: _openActivationShell,
                  onOpenWindowsUpdateSettings: _openWindowsUpdateSettings,
                  onOpenWindowsSecurity: _openWindowsSecurity,
                  onOpenDeviceManager: _openDeviceManager,
                  clearRecycleBinSelected: _clearRecycleBinSelected,
                  onClearRecycleBinChanged: _onClearRecycleBinChanged,
                  onClearRecentChanged: _onClearRecentChanged,
                  onRecheckActivation: () {
                    _refreshWindowsActivationInBackground();
                    _refreshOfficeActivationInBackground();
                  },
                  skipActivationOnCheckAll: _skipActivationOnCheckAll,
                  onSkipActivationChanged: (v) { setState(() { _skipActivationOnCheckAll = v; }); },
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          // Action buttons
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _isChecking ? null : _checkAllStatus,
                icon: Icon(Icons.search),
                label: Text('🔍 Check All'),
              ),
              ElevatedButton.icon(
                onPressed: _selectAllEverything,
                icon: Icon(Icons.check_box),
                label: Text('✅ Pilih Semua'),
              ),
              ElevatedButton.icon(
                onPressed: _deselectAllEverything,
                icon: Icon(Icons.check_box_outline_blank),
                label: Text('❌ Batal Pilih Semua'),
              ),
              ElevatedButton.icon(
                onPressed: _isCleaning ? null : _startCleaning,
                icon: Icon(Icons.cleaning_services),
                label: Text('🧹 Bersihkan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.exit_to_app),
                label: Text('❌ Keluar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          // Progress indicator
          if (_isChecking || _isCleaning)
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
    );
  }
}
