import 'dart:async';
import 'dart:io';
import 'dart:math';
// kIsWeb not used in this file
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Futuristic Emergency Screen (new)
/// - Animated RGB gradient background
/// - Pulsing result card
/// - AI Assistant quick access
/// - Permission gate and camera reference capture

class EmergencyScreenFuturisticNew extends StatefulWidget {
  const EmergencyScreenFuturisticNew({super.key});

  @override
  State<EmergencyScreenFuturisticNew> createState() => _EmergencyScreenFuturisticNewState();
}

class _EmergencyScreenFuturisticNewState extends State<EmergencyScreenFuturisticNew> with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _pulseController;
  final List<XFile> _referenceImages = [];
  bool _permissionsGranted = false;
  bool _checkingPermissions = true;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() => _checkingPermissions = true);
    try {
      // Camera and microphone are the primary permissions for capture
      final camera = await Permission.camera.request();
      final microphone = await Permission.microphone.request();
      final location = await Permission.location.request();

      final ok = camera.isGranted && microphone.isGranted && location.isGranted;
      setState(() {
        _permissionsGranted = ok;
      });
    } catch (_) {
      setState(() {
        _permissionsGranted = false;
      });
    } finally {
      setState(() => _checkingPermissions = false);
    }
  }

  Future<void> _captureReference() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      if (picked != null) {
        setState(() => _referenceImages.insert(0, picked));
      }
    } catch (e) {
      debugPrint('Capture failed: $e');
    }
  }

  Color _colorForIndex(int i) {
    if (_referenceImages.isEmpty) {
      // cycle through preset neon palette
      const palette = [Color(0xFF00E5FF), Color(0xFF9C27B0), Color(0xFFFF3D00), Color(0xFF00C853)];
      return palette[i % palette.length];
    }
    // derive a color from the file path hash as a lightweight heuristic
    final file = _referenceImages[min(i, _referenceImages.length - 1)];
    final h = file.path.hashCode;
    final r = (h & 0xFF0000) >> 16;
    final g = (h & 0x00FF00) >> 8;
    final b = (h & 0x0000FF);
    return Color.fromARGB(255, (r.abs() % 200) + 30, (g.abs() % 200) + 30, (b.abs() % 200) + 30);
  }

  @override
  void dispose() {
    _bgController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _openAiChat() {
    Navigator.pushNamed(context, '/ai');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Silent SOS — Futuristic'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _checkPermissions),
        ],
      ),
      body: _checkingPermissions
          ? const Center(child: CircularProgressIndicator())
          : _permissionsGranted
              ? Stack(children: [
                  // Animated RGB gradient background
                  AnimatedBuilder(
                    animation: _bgController,
                    builder: (context, child) {
                      final t = _bgController.value;
                      final c1 = _colorForIndex((t * 4).floor());
                      final c2 = _colorForIndex(((t * 4).floor() + 1));
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [c1.withAlpha((0.55 * 255).round()), c2.withAlpha((0.35 * 255).round())],
                            begin: Alignment(-1 + sin(2 * pi * t), -1),
                            end: Alignment(1, 1 - cos(2 * pi * t)),
                          ),
                        ),
                      );
                    },
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Reference images row
                          SizedBox(
                            height: 96,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: max(1, _referenceImages.length),
                              itemBuilder: (ctx, i) {
                                if (_referenceImages.isEmpty) {
                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 8),
                                    width: 120,
                                    decoration: BoxDecoration(
                                      color: Colors.white12,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(child: Text('No reference\nimages')),
                                  );
                                }
                                final file = _referenceImages[i];
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 8),
                                  width: 96,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    image: DecorationImage(image: Image.file(File(file.path)).image, fit: BoxFit.cover),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Center futuristic SOS area
                          Expanded(
                            child: Center(
                              child: ScaleTransition(
                                scale: Tween<double>(begin: 0.98, end: 1.03).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
                                child: Container(
                                  width: 320,
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    color: Colors.black.withAlpha((0.35 * 255).round()),
                                    border: Border.all(color: Colors.white10),
                                    boxShadow: [
                                      BoxShadow(color: _colorForIndex(0).withAlpha((0.28 * 255).round()), blurRadius: 30, spreadRadius: 4),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('S I L E N T  S O S', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, letterSpacing: 6)),
                                      const SizedBox(height: 12),
                                      const Text('Tap to send an SOS or open AI assistant', style: TextStyle(color: Colors.white70)),
                                      const SizedBox(height: 16),
                                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(backgroundColor: _colorForIndex(2)),
                                          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS sent (stub)'))),
                                          icon: const Icon(Icons.sos, color: Colors.white),
                                          label: const Text('Send SOS'),
                                        ),
                                        const SizedBox(width: 12),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white24),
                                          onPressed: _openAiChat,
                                          icon: const Icon(Icons.smart_toy, color: Colors.white),
                                          label: const Text('AI Assistant'),
                                        ),
                                      ]),
                                      const SizedBox(height: 12),
                                      ElevatedButton.icon(
                                        onPressed: _captureReference,
                                        icon: const Icon(Icons.camera_alt),
                                        label: const Text('Capture Reference Image'),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
                                      ),
                                      const SizedBox(height: 12),
                                      ElevatedButton.icon(
                                        onPressed: () => Navigator.pushNamed(context, '/tflite_test'),
                                        icon: const Icon(Icons.psychology),
                                        label: const Text('Test TFLite Model'),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Footer
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            TextButton(onPressed: () async { await openAppSettings(); }, child: const Text('Open App Settings', style: TextStyle(color: Colors.white70))),
                            TextButton(onPressed: () => setState(() => _referenceImages.clear()), child: const Text('Clear References', style: TextStyle(color: Colors.white70))),
                          ])
                        ],
                      ),
                    ),
                  ),
                ])
              : Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('Permissions required to continue', style: TextStyle(color: Colors.white)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _checkPermissions, child: const Text('Grant Permissions')),
                  ]),
                ),
    );
  }
}
