import 'package:flutter/material.dart';
import '../models/application_models.dart';

class InstalledAppsSection extends StatelessWidget {
  final List<InstalledApplication> defaultApps;
  final bool isLoading;
  final VoidCallback onRefresh;
  final VoidCallback onAddDefault;
  final Set<String> customNames;
  final void Function(String name) onRemoveDefault;

  const InstalledAppsSection({
    super.key,
    required this.defaultApps,
    required this.isLoading,
    required this.onRefresh,
    required this.onAddDefault,
    required this.customNames,
    required this.onRemoveDefault,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.apps, color: Colors.green),
                    SizedBox(width: 8),
                Text(
                  'Aplikasi Default',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: isLoading ? null : onAddDefault,
                      icon: Icon(Icons.add),
                      tooltip: 'Tambah Aplikasi Default',
                    ),
                    IconButton(
                      onPressed: isLoading ? null : onRefresh,
                      icon: isLoading 
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.refresh),
                      tooltip: 'Refresh Status',
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),
            if (isLoading && defaultApps.isEmpty)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Memeriksa aplikasi default...'),
                  ],
                ),
              )
            else
              SizedBox(
                height: 400,
                child: ListView.builder(
                  itemCount: defaultApps.length,
                  itemBuilder: (context, index) {
                    final app = defaultApps[index];
                    return _buildDefaultAppItem(app);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAppItem(InstalledApplication app) {
    Color statusColor = app.isInstalled ? Colors.green : Colors.orange;
    IconData statusIcon = app.isInstalled ? Icons.check_circle : Icons.download;
    String statusText = app.isInstalled ? 'Terinstal' : 'Belum Terinstal';

    final bool isCustom = customNames.any((n) => n.toLowerCase() == app.name.toLowerCase());
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: app.isInstalled ? Colors.green.shade50 : Colors.orange.shade50,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                statusIcon,
                color: statusColor,
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            app.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      app.status,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCustom) ...[
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade600),
                  tooltip: 'Hapus dari Aplikasi Default',
                  onPressed: () => onRemoveDefault(app.name),
                ),
              ],
            ],
          ),
          if (!app.isInstalled) ...[
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Perlu diinstal',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
