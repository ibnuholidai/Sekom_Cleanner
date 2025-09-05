import 'package:flutter/material.dart';
import '../models/application_models.dart';

class InstallableAppsSection extends StatelessWidget {
  final List<InstallableApplication> installableApps;
  final Function(String, bool) onAppSelectionChanged;
  final Function(String) onEditApp;
  final Function(String) onDeleteApp;
  final Function(String) onInstallApp;

  const InstallableAppsSection({
    super.key,
    required this.installableApps,
    required this.onAppSelectionChanged,
    required this.onEditApp,
    required this.onDeleteApp,
    required this.onInstallApp,
  });

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
                Icon(Icons.download, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Shortcut Aplikasi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 400,
              child: installableApps.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Belum ada shortcut dalam daftar',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Klik "Tambah Shortcut" untuk menambah file .exe',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: installableApps.length,
                      itemBuilder: (context, index) {
                        final app = installableApps[index];
                        return _buildInstallableAppItem(context, app);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstallableAppItem(BuildContext context, InstallableApplication app) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: app.isSelected ? Colors.blue.shade300 : Colors.grey.shade300,
          width: app.isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: app.isSelected ? Colors.blue.shade50 : Colors.white,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Checkbox
              Checkbox(
                value: app.isSelected,
                onChanged: (value) {
                  onAppSelectionChanged(app.id, value ?? false);
                },
              ),
              SizedBox(width: 12),
              // App icon placeholder
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Icon(
                  _getAppIcon(app.name),
                  size: 24,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(width: 16),
              // App info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      app.description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (app.downloadUrl.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        'Path: ${app.downloadUrl}',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Run button
              ElevatedButton.icon(
                onPressed: () => onInstallApp(app.id),
                icon: Icon(Icons.play_arrow, size: 16),
                label: Text('Jalankan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size(0, 32),
                ),
              ),
              SizedBox(width: 8),
              // Edit button
              OutlinedButton.icon(
                onPressed: () => onEditApp(app.id),
                icon: Icon(Icons.edit, size: 16),
                label: Text('Edit'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size(0, 32),
                ),
              ),
              SizedBox(width: 8),
              // Delete button
              OutlinedButton.icon(
                onPressed: () => onDeleteApp(app.id),
                icon: Icon(Icons.delete, size: 16),
                label: Text('Hapus'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size(0, 32),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getAppIcon(String appName) {
    String lowerName = appName.toLowerCase();
    
    if (lowerName.contains('office')) return Icons.work;
    if (lowerName.contains('firefox')) return Icons.web;
    if (lowerName.contains('chrome')) return Icons.web;
    if (lowerName.contains('edge')) return Icons.web;
    if (lowerName.contains('winrar') || lowerName.contains('7-zip')) return Icons.archive;
    if (lowerName.contains('rustdesk') || lowerName.contains('teamviewer')) return Icons.desktop_windows;
    if (lowerName.contains('directx')) return Icons.games;
    if (lowerName.contains('vlc')) return Icons.play_circle;
    if (lowerName.contains('notepad')) return Icons.edit_note;
    
    return Icons.apps;
  }
}
