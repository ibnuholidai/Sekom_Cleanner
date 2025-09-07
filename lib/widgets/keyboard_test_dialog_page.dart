import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'keyboard_test_web_offline.dart';

class KeyboardTestDialogPage extends StatelessWidget {
  const KeyboardTestDialogPage({super.key});

  static const String _onlineUrl = 'https://en.key-test.ru/';

  Future<void> _openOnline() async {
    final uri = Uri.parse(_onlineUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    // Semi-transparent backdrop to mimic dialog overlay
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Align(
        // Sedikit naik ke atas agar terasa seperti dialog yang tidak menutupi penuh
        alignment: const Alignment(0, -0.05),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            // Ukuran lebih ringkas seperti popup, bukan fullscreen
            maxWidth: 1350,
            maxHeight: 710,
          ),
          child: Material(
            color: const Color(0xFFF5F7FA),
            elevation: 6,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Center(
                    child: Text(
                      'Keyboard Test',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: const KeyboardTestWebOffline(),
                    ),
                  ),
                ),

                // Actions (bottom-right)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      const Spacer(),
                      TextButton(
                        onPressed: _openOnline,
                        child: const Text('Buka Situs Online'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Tutup'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
