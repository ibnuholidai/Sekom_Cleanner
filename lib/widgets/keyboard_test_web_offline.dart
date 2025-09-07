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

  void _tryNativeFocus() {
    try {
      // Best-effort: some versions of webview_windows expose setFocus().
      ( _controller as dynamic ).setFocus();
    } catch (_) {}
  }

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
      // Push native focus right after init
      _tryNativeFocus();

      // Paksa fokus ke dokumen di dalam WebView2 (supaya event keyboard masuk)
      try {
        await _controller.addScriptToExecuteOnDocumentCreated(r"""
          (function() {
            function ensureFocus() {
              try {
                window.focus();
                if (document && document.body) {
                  document.body.setAttribute('tabindex', '0');
                  document.body.focus();
                }
              } catch (e) {}
            }
            document.addEventListener('DOMContentLoaded', ensureFocus);
            window.addEventListener('load', ensureFocus);
            window.addEventListener('click', ensureFocus);
            // jalankan segera juga
            ensureFocus();
          })();
        """);

        // Fallback handler: jika script asli halaman gagal mengikat event,
        // injeksikan listener key/mouse agar tombol tetap terbaca.
        await _controller.addScriptToExecuteOnDocumentCreated(r"""
          (function() {
            if (window.__kbInject) return;
            window.__kbInject = true;

            function setKeyState(code, state) {
              try {
                var nodes = document.querySelectorAll('.k' + code);
                nodes.forEach(function(n) {
                  if (state === 'press') {
                    n.classList.remove('active');
                    n.classList.add('press');
                  } else {
                    n.classList.remove('press');
                    n.classList.add('active');
                  }
                });
              } catch (e) {}
            }

            function handleKeyDown(e) { try { e.preventDefault(); setKeyState(e.keyCode, 'press'); } catch(_){} }
            function handleKeyUp(e)   { try { e.preventDefault(); setKeyState(e.keyCode, 'active'); } catch(_){} }
            function handleMouseDown(e){ try { e.preventDefault(); setKeyState(e.button, 'press'); } catch(_){} }
            function handleMouseUp(e)  { try { e.preventDefault(); setKeyState(e.button, 'active'); } catch(_){} }

            document.addEventListener('keydown', handleKeyDown, true);
            document.addEventListener('keyup', handleKeyUp, true);
            document.addEventListener('mousedown', handleMouseDown, true);
            document.addEventListener('mouseup', handleMouseUp, true);

            // Pastikan dokumen fokus.
            try {
              window.focus();
              if (document && document.body) {
                document.body.setAttribute('tabindex', '0');
                document.body.focus();
              }
            } catch (e) {}
          })();
        """);
      } catch (_) {}

      // Tentukan folder aset:
      // - Dev: lib/
      // - Release: <exe>/data/flutter_assets (root aset), sehingga URL menjadi /lib/keyboard_test/index.html
      final folderPath = _bestAssetsFolder();
      // Muat langsung halaman utama di folder keyboard-test.space agar tidak tergantung meta refresh
      final htmlPath = p.join(folderPath, 'keyboard_test', 'keyboard-test.space', 'index.html');
      final fileUrl = Uri.file(htmlPath).toString();

      // Hitung root aset saat release (<exe>/data/flutter_assets)
      String? assetsRoot;
      try {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        final root = p.join(exeDir, 'data', 'flutter_assets');
        if (Directory(root).existsSync()) {
          assetsRoot = root;
        }
      } catch (_) {}

      try {
        // Gunakan mapping virtual host agar semua resource relatif bekerja di WebView2
        final mappingFolder = assetsRoot ?? folderPath; // release: root aset, dev: lib/
        await _controller.addVirtualHostNameMapping(
          'appassets.example',
          mappingFolder,
          WebviewHostResourceAccessKind.allow,
        );

        // Saat mapping ke root aset, HTML berada di /lib/keyboard_test/index.html
        final virtualUrl = assetsRoot != null
            ? 'https://appassets.example/lib/keyboard_test/keyboard-test.space/index.html'
            : 'https://appassets.example/keyboard_test/keyboard-test.space/index.html';

        await _controller.loadUrl(virtualUrl);
      } catch (_) {
        // Fallback ke file:// jika mapping gagal
        await _controller.loadUrl(fileUrl);
      }

      // Give WebView a moment then push focus (native + JS)
      try {
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (_) {}
      _tryNativeFocus();
      try {
        await _controller.executeScript('window.focus(); if (document && document.body) { document.body.setAttribute("tabindex","0"); document.body.focus(); }');
      } catch (_) {}

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
    // Bersihkan mapping virtual host bila sempat
    try {
      _controller.removeVirtualHostNameMapping('appassets.example');
    } catch (_) {}
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
              Positioned(
                right: 8,
                bottom: 8,
                child: FilledButton.icon(
                  onPressed: () {
                    _tryNativeFocus();
                    _controller.executeScript('window.focus(); if (document && document.body) { document.body.setAttribute("tabindex","0"); document.body.focus(); }');
                  },
                  icon: const Icon(Icons.keyboard),
                  label: const Text('Fokus'),
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
