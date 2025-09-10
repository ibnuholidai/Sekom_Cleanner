import 'package:flutter/material.dart';
import '../models/system_status.dart';

class WindowsSystemSection extends StatefulWidget {
  final SystemStatus defenderStatus;
  final SystemStatus updateStatus;
  final SystemStatus driverStatus;
  final SystemStatus windowsActivationStatus;
  final SystemStatus officeActivationStatus;
  final bool clearRecentSelected;
  final bool isChecking;
  final Function() onUpdateDefender;
  final Function() onRunWindowsUpdate;
  final Function() onUpdateDrivers;
  final Function() onActivateWindows;
  final Function() onActivateOffice;
  final Function() onOpenActivationShell;
  final Function() onOpenWindowsUpdateSettings;
  final Function() onOpenWindowsSecurity;
  final Function() onOpenDeviceManager;
  final bool clearRecycleBinSelected;
  final Function(bool) onClearRecycleBinChanged;
  final Function(bool) onClearRecentChanged;
  final Function() onRecheckActivation;
  final bool skipActivationOnCheckAll;
  final Function(bool) onSkipActivationChanged;
  final Function() onDisableWindowsUpdate; // NEW: disable Windows Update via Services

  const WindowsSystemSection({
    super.key,
    required this.defenderStatus,
    required this.updateStatus,
    required this.driverStatus,
    required this.windowsActivationStatus,
    required this.officeActivationStatus,
    required this.clearRecentSelected,
    required this.isChecking,
    required this.onUpdateDefender,
    required this.onRunWindowsUpdate,
    required this.onUpdateDrivers,
    required this.onActivateWindows,
    required this.onActivateOffice,
    required this.onOpenActivationShell,
    required this.onOpenWindowsUpdateSettings,
    required this.onOpenWindowsSecurity,
    required this.onOpenDeviceManager,
    required this.clearRecycleBinSelected,
    required this.onClearRecycleBinChanged,
    required this.onClearRecentChanged,
    required this.onRecheckActivation,
    required this.skipActivationOnCheckAll,
    required this.onSkipActivationChanged,
    required this.onDisableWindowsUpdate,
  });

  @override
  State<WindowsSystemSection> createState() => _WindowsSystemSectionState();
}

class _WindowsSystemSectionState extends State<WindowsSystemSection> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: Colors.green),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Windows System',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Sistem Windows:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            _buildSystemStatusRow(
              'Windows Defender',
              widget.defenderStatus,
              widget.onUpdateDefender,
              'Update',
              onOpen: widget.onOpenWindowsSecurity,
              openText: 'Lihat',
            ),
            _buildSystemStatusRow(
              'Windows Update',
              widget.updateStatus,
              widget.onRunWindowsUpdate,
              'Update',
              onOpen: widget.onOpenWindowsUpdateSettings,
              openText: 'Lihat',
            ),
            SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.isChecking ? null : widget.onDisableWindowsUpdate,
                icon: Icon(Icons.block),
                label: Text('Disable Windows Update (Stop + Disable Service)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            _buildSystemStatusRow(
              'Drivers',
              widget.driverStatus,
              widget.onUpdateDrivers,
              'Update',
              onOpen: widget.onOpenDeviceManager,
              openText: 'Lihat',
            ),
            SizedBox(height: 16),
            Text(
              'Activation Status:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            _buildSystemStatusRow(
              'Windows Activation',
              widget.windowsActivationStatus,
              widget.onActivateWindows,
              'Activate',
              onOpen: () => _showStatusDetail('Windows Activation', widget.windowsActivationStatus),
              openText: 'Detail',
            ),
            _buildSystemStatusRow(
              'Office Activation',
              widget.officeActivationStatus,
              widget.onActivateOffice,
              'Activate',
              onOpen: () => _showStatusDetail('Office Activation', widget.officeActivationStatus),
              openText: 'Detail',
            ),
            SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.isChecking ? null : widget.onOpenActivationShell,
                icon: Icon(Icons.terminal),
                label: Text('Buka PowerShell Aktivasi'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.isChecking ? null : widget.onRecheckActivation,
                icon: Icon(Icons.refresh),
                label: Text('Cek Ulang Aktivasi'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            CheckboxListTile(
              title: Text('Lewati cek Aktivasi saat "Check All"'),
              value: widget.skipActivationOnCheckAll,
              onChanged: widget.isChecking ? null : (v) => widget.onSkipActivationChanged(v ?? false),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            SizedBox(height: 16),
            CheckboxListTile(
              title: Text('🗑️ Hapus Recent Items (Start/Search + Quick Access + Office) & Unpin Photos'),
              value: widget.clearRecentSelected,
              onChanged: (value) {
                widget.onClearRecentChanged(value ?? false);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: Text('🗑️ Kosongkan Recycle Bin'),
              value: widget.clearRecycleBinSelected,
              onChanged: (value) {
                widget.onClearRecycleBinChanged(value ?? false);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusDetail(String title, SystemStatus status) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('$title - Detail'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status.status, style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                if (status.detail != null && status.detail!.trim().isNotEmpty) ...[
                  Text(status.detail!),
                  SizedBox(height: 8),
                ],
                if (status.info != null && status.info!.isNotEmpty) ...[
                  ...status.info!.entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 120,
                              child: Text(e.key, style: TextStyle(color: Colors.grey.shade700)),
                            ),
                            Expanded(child: Text(e.value)),
                          ],
                        ),
                      )),
                ] else
                  Text('Tidak ada informasi tambahan.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSystemStatusRow(
    String title,
    SystemStatus status,
    VoidCallback onAction,
    String actionText, {
    VoidCallback? onOpen,
    String openText = 'Lihat',
  }) {
    bool showButton = status.needsUpdate && !widget.isChecking;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$title: ${status.status}',
              style: TextStyle(fontSize: 12),
            ),
          ),
          if (onOpen != null) ...[
            SizedBox(width: 8),
            SizedBox(
              height: 28,
              child: OutlinedButton(
                onPressed: onOpen,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size(0, 0),
                ),
                child: Text(
                  openText,
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ),
          ],
          if (showButton)
            SizedBox(
              height: 28,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size(0, 0),
                ),
                child: Text(
                  actionText,
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
