import 'dart:io';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' as ap;

class SoundTestLR extends StatefulWidget {
  const SoundTestLR({super.key});

  @override
  State<SoundTestLR> createState() => _SoundTestLRState();
}

class _SoundTestLRState extends State<SoundTestLR> with TickerProviderStateMixin {
  final ap.AudioPlayer _player = ap.AudioPlayer();
  bool _initialized = false;
  String? _error;


  bool _isPlayingLeft = false;
  bool _isPlayingRight = false;
  bool _isAlternating = false;
  double _volume = 0.9;

  late final AnimationController _pulseLeft;
  late final AnimationController _pulseRight;

  @override
  void initState() {
    super.initState();
    _pulseLeft = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _pulseRight = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _pulseLeft.value = 0.0;
    _pulseRight.value = 0.0;
    _init();
  }

  @override
  void dispose() {
    _pulseLeft.dispose();
    _pulseRight.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      if (!Platform.isWindows) {
        setState(() {
          _error = 'Sound L/R test saat ini hanya didukung pada Windows.';
        });
        return;
      }

      // Menggunakan asset audio untuk test; tidak perlu file sementara.

      await _player.setVolume(_volume);

      setState(() {
        _initialized = true;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal inisialisasi Sound Test: $e';
      });
    }
  }

  Future<void> _playLeft() async {
    if (!_initialized) return;
    _stopAnimations();
    _isAlternating = false;
    setState(() {
      _isPlayingLeft = true;
      _isPlayingRight = false;
    });
    _pulseLeft.repeat(reverse: true);
    await _player.stop();
    await _player.setVolume(_volume);
    await _player.setBalance(-1.0); // full left
    unawaited(_player.play(ap.AssetSource('ringtone-193209.mp3')));
    _player.onPlayerComplete.first.then((_) {
      if (!_isAlternating) {
        _stopAnimations();
      }
    });
  }

  Future<void> _playRight() async {
    if (!_initialized) return;
    _stopAnimations();
    _isAlternating = false;
    setState(() {
      _isPlayingLeft = false;
      _isPlayingRight = true;
    });
    _pulseRight.repeat(reverse: true);
    await _player.stop();
    await _player.setVolume(_volume);
    await _player.setBalance(1.0); // full right
    unawaited(_player.play(ap.AssetSource('ringtone-193209.mp3')));
    _player.onPlayerComplete.first.then((_) {
      if (!_isAlternating) {
        _stopAnimations();
      }
    });
  }

  Future<void> _playAlternate() async {
    if (!_initialized) return;
    _isAlternating = true;

    // Aktifkan kedua kanal bersamaan (balance center)
    _stopAnimations();
    setState(() {
      _isPlayingLeft = true;
      _isPlayingRight = true;
    });
    _pulseLeft.repeat(reverse: true);
    _pulseRight.repeat(reverse: true);

    await _player.stop();
    await _player.setVolume(_volume);
    await _player.setBalance(0.0); // center: L+R bersamaan
    unawaited(_player.play(ap.AssetSource('ringtone-193209.mp3')));
    _player.onPlayerComplete.first.then((_) {
      _isAlternating = false;
      _stopAnimations();
    });
  }

  Future<void> _stopAll() async {
    _isAlternating = false;
    await _player.stop();
    _stopAnimations();
  }

  void _stopAnimations() {
    _pulseLeft.stop();
    _pulseRight.stop();
    _pulseLeft.value = 0.0;
    _pulseRight.value = 0.0;
    setState(() {
      _isPlayingLeft = false;
      _isPlayingRight = false;
    });
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _errorPane(_error!);
    }
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Row(
          children: [
            const Icon(Icons.volume_up, size: 18, color: Colors.white70),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Sound Test - Left / Right',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Tooltip(
              message: 'Uji speaker kiri/kanan dengan suara notifikasi pendek. Gunakan headphone/speaker stereo.',
              child: const Icon(Icons.info_outline, size: 16),
            )
          ],
        ),
        const SizedBox(height: 12),
        // Visualizer circles
        Row(
          children: [
            Expanded(child: _channelCircle('LEFT', Colors.tealAccent, _pulseLeft, _isPlayingLeft)),
            const SizedBox(width: 12),
            Expanded(child: _channelCircle('RIGHT', Colors.pinkAccent, _pulseRight, _isPlayingRight)),
          ],
        ),
        const SizedBox(height: 16),
        // Controls
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: _playLeft,
              icon: const Icon(Icons.arrow_left),
              label: const Text('Play Left'),
            ),
            FilledButton.icon(
              onPressed: _playRight,
              icon: const Icon(Icons.arrow_right),
              label: const Text('Play Right'),
            ),
            OutlinedButton.icon(
              onPressed: _isAlternating ? null : () { _playAlternate(); },
              icon: const Icon(Icons.surround_sound),
              label: const Text('Both (L+R)'),
            ),
            OutlinedButton.icon(
              onPressed: _stopAll,
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Volume
        Row(
          children: [
            const Icon(Icons.volume_mute, size: 16),
            Expanded(
              child: Slider(
                value: _volume,
                min: 0.0,
                max: 1.0,
                onChanged: (v) async {
                  setState(() {
                    _volume = v;
                  });
                  await _player.setVolume(_volume);
                },
              ),
            ),
            const Icon(Icons.volume_up, size: 16),
          ],
        ),
      ],
    );
  }

  Widget _channelCircle(String label, Color color, AnimationController pulse, bool isActive) {
    final anim = CurvedAnimation(parent: pulse, curve: Curves.easeInOut);
    final scale = Tween(begin: 0.96, end: 1.06).animate(anim);
    final glow = (isActive ? 0.6 : 0.15);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(isActive ? 0.35 : 0.15),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(glow),
                  blurRadius: isActive ? 28 : 6,
                  spreadRadius: isActive ? 6 : 1,
                ),
              ],
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: Colors.white.withOpacity(0.92),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorPane(String message) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1216),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}


// Avoid analyzer warning for unawaited futures
void unawaited(Future<void> f) {}
