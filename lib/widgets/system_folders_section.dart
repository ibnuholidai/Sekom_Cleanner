import 'package:flutter/material.dart';
import '../models/system_status.dart';

class SystemFoldersSection extends StatefulWidget {
  final bool objects3dSelected;
  final bool documentsSelected;
  final bool downloadsSelected;
  final bool musicSelected;
  final bool picturesSelected;
  final bool videosSelected;
  final bool selectAllFolders;
  final List<FolderInfo> folderInfos;
  final Function(bool) onObjects3dChanged;
  final Function(bool) onDocumentsChanged;
  final Function(bool) onDownloadsChanged;
  final Function(bool) onMusicChanged;
  final Function(bool) onPicturesChanged;
  final Function(bool) onVideosChanged;
  final Function(bool) onSelectAllFoldersChanged;

  const SystemFoldersSection({
    super.key,
    required this.objects3dSelected,
    required this.documentsSelected,
    required this.downloadsSelected,
    required this.musicSelected,
    required this.picturesSelected,
    required this.videosSelected,
    required this.selectAllFolders,
    required this.folderInfos,
    required this.onObjects3dChanged,
    required this.onDocumentsChanged,
    required this.onDownloadsChanged,
    required this.onMusicChanged,
    required this.onPicturesChanged,
    required this.onVideosChanged,
    required this.onSelectAllFoldersChanged,
  });

  @override
  State<SystemFoldersSection> createState() => _SystemFoldersSectionState();
}

class _SystemFoldersSectionState extends State<SystemFoldersSection> {
  String _getFolderSize(String folderName) {
    try {
      FolderInfo? info = widget.folderInfos.firstWhere(
        (folder) => folder.name == folderName,
        orElse: () => FolderInfo(name: folderName, path: '', size: ''),
      );
      return info.size.isNotEmpty ? '(${info.size})' : '';
    } catch (e) {
      return '';
    }
  }

  String _getTotalSize() {
    if (widget.folderInfos.isEmpty) return '';
    try {
      int total = 0;
      for (final info in widget.folderInfos) {
        if (info.exists) {
          total += info.sizeBytes;
        }
      }
      return 'Total: ${_formatSize(total)}';
    } catch (e) {
      return 'Total: -';
    }
  }

  String _formatSize(int sizeBytes) {
    if (sizeBytes <= 0) return "0 B";
    const units = ["B", "KB", "MB", "GB", "TB"];
    int i = 0;
    double size = sizeBytes.toDouble();
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return "${size.toStringAsFixed(2)} ${units[i]}";
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
                Icon(Icons.folder, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'System Folders',
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
              'Pilih folder untuk dibersihkan:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PERINGATAN: File akan dihapus permanen!',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            CheckboxListTile(
              title: Text('✅ Pilih Semua Folder'),
              value: widget.selectAllFolders,
              onChanged: (value) {
                widget.onSelectAllFoldersChanged(value ?? false);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            _buildFolderCheckbox(
              '📦 3D Objects',
              widget.objects3dSelected,
              widget.onObjects3dChanged,
              '3D Objects',
            ),
            _buildFolderCheckbox(
              '📄 Documents',
              widget.documentsSelected,
              widget.onDocumentsChanged,
              'Documents',
            ),
            _buildFolderCheckbox(
              '📥 Downloads',
              widget.downloadsSelected,
              widget.onDownloadsChanged,
              'Downloads',
            ),
            _buildFolderCheckbox(
              '🎵 Music',
              widget.musicSelected,
              widget.onMusicChanged,
              'Music',
            ),
            _buildFolderCheckbox(
              '🖼️ Pictures',
              widget.picturesSelected,
              widget.onPicturesChanged,
              'Pictures',
            ),
            _buildFolderCheckbox(
              '🎬 Videos',
              widget.videosSelected,
              widget.onVideosChanged,
              'Videos',
            ),
            if (widget.folderInfos.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                _getTotalSize(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFolderCheckbox(
    String title,
    bool value,
    Function(bool) onChanged,
    String folderName,
  ) {
    String sizeInfo = _getFolderSize(folderName);
    
    return Row(
      children: [
        Expanded(
          child: CheckboxListTile(
            title: Text(title),
            value: value,
            onChanged: (newValue) {
              onChanged(newValue ?? false);
            },
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (sizeInfo.isNotEmpty)
          Text(
            sizeInfo,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue,
            ),
          ),
      ],
    );
  }
}
