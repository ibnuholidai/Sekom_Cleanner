import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:webview_windows/webview_windows.dart';

class KeyboardTestWebOffline extends StatefulWidget {
  const KeyboardTestWebOffline({super.key});

  @override
  State<KeyboardTestWebOffline> createState() => _KeyboardTestWebOfflineState();
}

class _KeyboardTestWebOfflineState extends State<KeyboardTestWebOffline> {
  final WebviewController _controller = WebviewController();
  bool _initialized = false;
  String? _error;

  // Try to resolve a real folder to map as virtual host:
  // 1) Project lib/ (dev run)
  // 2) Packaged assets under exeDir/data/flutter_assets/ (release build) - lib/ placement
  // 3) Fallback: project root (still allowing manual relative loading)
  String _bestAssetsFolder() {
    // Dev: map to project lib directory (contains the provided html + folder)
    final libDir = Directory('lib');
    if (libDir.existsSync()) {
      return libDir.absolute.path;
    }

    // Packaged exe: assets typically under <exeDir>/data/flutter_assets/
    try {
      final exeDir = File(Platform.resolvedExecutable).parent;
      final flutterAssets = Directory(p.join(exeDir.path, 'data', 'flutter_assets', 'lib'));
      if (flutterAssets.existsSync()) {
        return flutterAssets.path;
      }
    } catch (_) {}

    // Last resort: current directory
    return Directory.current.absolute.path;
  }

  Future<void> _init() async {
    try {
      await _controller.initialize();
      await _controller.setBackgroundColor(Colors.transparent);

      // Langsung muat file:// URL ke HTML lokal (tanpa virtual host mapping)
      final folderPath = _bestAssetsFolder();
      // Load the new offline HTML you provided
      final htmlPath = p.join(folderPath, 'keyboard_test', 'index.html');
      final fileUrl = Uri.file(htmlPath).toString();

      await _controller.loadUrl(fileUrl);

      setState(() {
        _initialized = true;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat WebView offline: $e';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Only available on Windows
    if (!Platform.isWindows) {
      _error = 'WebView offline hanya didukung di Windows.';
    } else {
      _init();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _ErrorPane(message: _error!);
    }
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Webview(_controller),
              // Optional overlay if needed (e.g., to show reload)
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  tooltip: 'Reload',
                  onPressed: () {
                    _controller.reload();
                  },
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  final String message;
  const _ErrorPane({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF0F1216),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}
