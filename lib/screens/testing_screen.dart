import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/sound_test_lr.dart';
import '../widgets/rgb_screen_test.dart';
import '../widgets/keyboard_test_dialog_page.dart';

class TestingScreen extends StatefulWidget {
  const TestingScreen({super.key});

  @override
  State<TestingScreen> createState() => _TestingScreenState();
}

class _TestingScreenState extends State<TestingScreen> {
  final String _keyboardTestUrl = 'https://en.key-test.ru/';


  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(_keyboardTestUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // Icon-only launcher (no scrolling UI). Each icon opens a popup dialog.
  Widget _buildTestIcon(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.blue.shade50,
            shape: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Icon(icon, size: 36, color: Colors.blue),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showComingSoon(String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$name - Coming Soon'),
        content: const Text('Fitur ini akan ditambahkan pada update berikutnya.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Tutup')),
        ],
      ),
    );
  }

  Future<void> _showKeyboardTestDialog() async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Keyboard Test',
      barrierColor: Colors.transparent, // tidak menggelapkan background
      pageBuilder: (ctx, anim1, anim2) {
        return const KeyboardTestDialogPage();
      },
      transitionBuilder: (ctx, anim, secAnim, child) {
        // Animasi popup halus (fade + scale)
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _showSoundTestDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Sound Test L/R'),
          content: SizedBox(
            width: 700,
            height: 380,
            child: const SoundTestLR(),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRgbTestDialog() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const RgbScreenTest(),
      ),
    );
  }

  Widget _buildSoundTestPlaceholder() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.volume_up, color: Colors.deepPurple),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Sound Test (Kiri/Kanan) - Coming Soon',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fitur test suara akan ditambahkan selanjutnya')),
                );
              },
              child: const Text('Info'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRgbTestPlaceholder() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.palette, color: Colors.teal),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'RGB Screen Test - Coming Soon',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fitur test warna layar akan ditambahkan selanjutnya')),
                );
              },
              child: const Text('Info'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 24,
          runSpacing: 24,
          children: [
            _buildTestIcon(Icons.keyboard, 'Keyboard Test', _showKeyboardTestDialog),
            _buildTestIcon(Icons.volume_up, 'Sound L/R', _showSoundTestDialog),
            _buildTestIcon(Icons.palette, 'RGB Screen', _showRgbTestDialog),
          ],
        ),
      ),
    );
  }
}
