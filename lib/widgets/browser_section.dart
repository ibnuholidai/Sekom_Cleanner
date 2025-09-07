import 'package:flutter/material.dart';
import '../services/system_service.dart';

class BrowserSection extends StatefulWidget {
  final bool chromeSelected;
  final bool edgeSelected;
  final bool firefoxSelected;
  final bool resetBrowserSelected;
  final bool selectAllBrowsers;
  final Function(bool) onChromeChanged;
  final Function(bool) onEdgeChanged;
  final Function(bool) onFirefoxChanged;
  final Function(bool) onResetBrowserChanged;
  final Function(bool) onSelectAllBrowsersChanged;

  const BrowserSection({
    super.key,
    required this.chromeSelected,
    required this.edgeSelected,
    required this.firefoxSelected,
    required this.resetBrowserSelected,
    required this.selectAllBrowsers,
    required this.onChromeChanged,
    required this.onEdgeChanged,
    required this.onFirefoxChanged,
    required this.onResetBrowserChanged,
    required this.onSelectAllBrowsersChanged,
  });

  @override
  State<BrowserSection> createState() => _BrowserSectionState();
}

class _BrowserSectionState extends State<BrowserSection> {
  List<Map<String, dynamic>> _disks = [];
  bool _loadingDisks = false;
  String? _diskError;

  @override
  void initState() {
    super.initState();
    _loadDisks();
  }

  Future<void> _loadDisks() async {
    setState(() {
      _loadingDisks = true;
      _diskError = null;
    });
    try {
      final disks = await SystemService.getDiskInfo();
      setState(() {
        _disks = disks;
      });
    } catch (e) {
      setState(() {
        _diskError = e.toString();
      });
    } finally {
      setState(() {
        _loadingDisks = false;
      });
    }
  }

  Future<void> _visitDrive(String drive) async {
    await SystemService.openDrive(drive);
  }

  Widget _buildDiskList() {
    if (_diskError != null) {
      return Text(
        'Gagal memuat info disk: $_diskError',
        style: TextStyle(color: Colors.red),
      );
    }
    if (_loadingDisks) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_disks.isEmpty) {
      return Text(
        'Tidak ada disk yang terdeteksi.',
        style: TextStyle(color: Colors.grey.shade700),
      );
    }

    return Column(
      children: _disks.map((d) {
        final drive = (d['drive'] ?? '').toString();
        final totalText = (d['totalText'] ?? '').toString();
        final freeText = (d['freeText'] ?? '').toString();
        final usedText = (d['usedText'] ?? '').toString();
        final usedPercent = (d['usedPercent'] is num) ? (d['usedPercent'] as num).toDouble() : 0.0;

        return Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade50,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    drive,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Total $totalText • Used $usedText • Free $freeText',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _visitDrive(drive),
                    child: Text('Visit'),
                  ),
                ],
              ),
              SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: usedPercent.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

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
                Icon(Icons.web, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Browser Cleaning',
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
              'Pilih browser:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            CheckboxListTile(
              title: Text('✅ Pilih Semua Browser'),
              value: widget.selectAllBrowsers,
              onChanged: (value) {
                widget.onSelectAllBrowsersChanged(value ?? false);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: Text('Google Chrome'),
              value: widget.chromeSelected,
              onChanged: (value) {
                widget.onChromeChanged(value ?? false);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: Text('Microsoft Edge'),
              value: widget.edgeSelected,
              onChanged: (value) {
                widget.onEdgeChanged(value ?? false);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: Text('Mozilla Firefox'),
              value: widget.firefoxSelected,
              onChanged: (value) {
                widget.onFirefoxChanged(value ?? false);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            SizedBox(height: 16),
            Text(
              'Aksi:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            CheckboxListTile(
              title: Text('🔄 Reset browser ke setelan awal'),
              value: widget.resetBrowserSelected,
              onChanged: (value) {
                widget.onResetBrowserChanged(value ?? false);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),

            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 8),

            // Disk Usage section
            Row(
              children: [
                Icon(Icons.storage, color: Colors.blueGrey),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Disk Usage',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh Disk',
                  onPressed: _loadingDisks ? null : _loadDisks,
                  icon: _loadingDisks
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.refresh),
                ),
              ],
            ),
            SizedBox(height: 8),
            _buildDiskList(),
          ],
        ),
      ),
    );
  }
}
