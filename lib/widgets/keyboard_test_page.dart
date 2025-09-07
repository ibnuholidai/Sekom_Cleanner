import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'keyboard_test_web_offline.dart';

class KeyboardTestPage extends StatelessWidget {
  const KeyboardTestPage({super.key});

  static const String _onlineUrl = 'https://en.key-test.ru/';

  Future<void> _openOnline() async {
    final uri = Uri.parse(_onlineUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keyboard Test'),
        actions: [
          IconButton(
            tooltip: 'Buka versi online',
            onPressed: _openOnline,
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: Column(
        children: [
          // Info bar: helps users give focus to WebView2
          Container(
            width: double.infinity,
            color: const Color(0xFFEEF3FF),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tip: Klik sekali pada area keyboard, lalu tekan tombol fisik untuk mulai mengetes. '
                    'Gunakan layout English untuk hasil akurat.',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // The offline WebView content (full screen)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: const KeyboardTestWebOffline(),
            ),
          ),
        ],
      ),
    );
  }
}
