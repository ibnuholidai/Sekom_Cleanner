import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

class RgbScreenTest extends StatefulWidget {
  const RgbScreenTest({super.key});

  @override
  State<RgbScreenTest> createState() => _RgbScreenTestState();
}

class _RgbScreenTestState extends State<RgbScreenTest> {
  // 0 = Red, 1 = Green, 2 = Blue
  int _index = 0;

  static const List<Color> _colors = <Color>[
    Colors.red,
    Colors.green,
    Colors.blue,
  ];

  @override
  void initState() {
    super.initState();
    // Masuk mode fullscreen native agar taskbar/title bar tersembunyi
    Future.microtask(() async {
      try {
        await windowManager.setFullScreen(true);
        await windowManager.setAlwaysOnTop(true);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    // Kembalikan ke mode normal saat keluar
    Future.microtask(() async {
      try {
        await windowManager.setAlwaysOnTop(false);
        await windowManager.setFullScreen(false);
      } catch (_) {}
    });
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _index = (_index + 1) % _colors.length;
    });
  }

  KeyEventResult _onKey(FocusNode node, RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return KeyEventResult.ignored;

    // ESC to exit full screen test
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }

    // Any other key toggles the color
    _toggle();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final Color bg = _colors[_index];

    return Scaffold(
      backgroundColor: bg,
      body: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          // Still map ESC to a DoNothingIntent to ensure onKey handles it
          LogicalKeySet(LogicalKeyboardKey.escape): DoNothingIntent(),
        },
        child: Actions(
          actions: const <Type, Action<Intent>>{},
          child: Focus(
            autofocus: true,
            onKey: _onKey,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              onSecondaryTap: _toggle,
              onDoubleTap: _toggle,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Fullscreen colored background handled by Scaffold.backgroundColor

                  // Close button and minimal hint overlay
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.mouse, size: 14, color: Colors.white70),
                              const SizedBox(width: 6),
                              Text(
                                'Klik untuk ganti warna (R → G → B). ESC untuk keluar.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(0.25),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close),
                          label: const Text('Tutup'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
