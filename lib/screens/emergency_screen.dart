import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../services/tflite_service.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> with TickerProviderStateMixin {
  final ApiService api = ApiService();
  final TextEditingController textCtrl = TextEditingController();
  final TFLiteService tflite = TFLiteService();
  File? imageFile;
  File? audioFile;
  String resultText = "";
  bool loading = false;
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    textCtrl.dispose();
    super.dispose();
  }

  Future<void> pickImageFromCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked == null) return;

    // On web, ImagePicker returns an XFile with readAsBytes(); on mobile it's a File path.
    if (kIsWeb) {
      setState(() {
        resultText = "Uploading image to server for analysis (web)";
      });

      try {
        final resp = await api.analyze(imageFile: picked, text: textCtrl.text);
        setState(() {
          resultText = "Server: ${resp['instruction'] ?? resp['diagnostics'] ?? resp}";
        });
        if (resp['call_emergency'] == true) _showEmergencyDialog();
      } catch (e) {
        setState(() => resultText = "Server error: $e");
      }

      return;
    }

    // -- non-web path (mobile/desktop) --
    final file = File(picked.path);
    setState(() => imageFile = file);

    // run local TFLite
    try {
      final local = await tflite.runOnImage(file);
      final confidence = local['confidence'] != null ? (local['confidence'] as double) : 0.0;
      final label = local['label'] as String? ?? 'unknown';
      setState(() {
        resultText = "Local: $label (conf ${confidence.toStringAsFixed(2)})";
      });
      if (label == 'severe_bleeding' && confidence > 0.7) {
        _showEmergencyDialog();
      }
    } catch (e) {
      setState(() => resultText = "Local model error: $e");
    }
  }

  Future<void> pickImageFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    // On web, ImagePicker returns an XFile with readAsBytes(); on mobile it's a File path.
    if (kIsWeb) {
      // show image preview if you want - convert bytes to memory image else skip
      setState(() {
        resultText = "Uploading image to server for analysis (web)";
      });

      try {
        // api.analyze expects an object with readAsBytes() on web
        final resp = await api.analyze(imageFile: picked, text: textCtrl.text);
        setState(() {
          resultText = "Server: ${resp['instruction'] ?? resp['diagnostics'] ?? resp}";
        });
        if (resp['call_emergency'] == true) _showEmergencyDialog();
      } catch (e) {
        setState(() => resultText = "Server error: $e");
      }

      return;
    }

    // -- non-web path (mobile/desktop) --
    final file = File(picked.path);
    setState(() => imageFile = file);

    // run local TFLite
    try {
      final local = await tflite.runOnImage(file);
      final confidence = local['confidence'] != null ? (local['confidence'] as double) : 0.0;
      final label = local['label'] as String? ?? 'unknown';
      setState(() {
        resultText = "Local: $label (conf ${confidence.toStringAsFixed(2)})";
      });
      if (label == 'severe_bleeding' && confidence > 0.7) {
        _showEmergencyDialog();
      }
    } catch (e) {
      setState(() => resultText = "Local model error: $e");
    }
  }

  Future<void> pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      setState(() => audioFile = File(result.files.single.path!));
    }
  }

  Future<void> sendToServer() async {
    setState(() {
      loading = true;
      resultText = "";
    });

    try {
      final response = (audioFile != null)
          ? await api.transcribeAndAnalyze(
              text: textCtrl.text, imageFile: imageFile, audioFile: audioFile)
          : await api.analyze(
              text: textCtrl.text, imageFile: imageFile, audioFile: audioFile);

      String output = "Severity: ${response["severity"]}\n\n";

      if (response["instruction"] is List) {
        for (int i = 0; i < response["instruction"].length; i++) {
          output += "${i + 1}. ${response["instruction"][i]}\n";
        }
      } else {
        output += "${response["instruction"]}";
      }

      // Add model diagnostics if available
      if (response["diagnostics"] != null) {
        final diag = response["diagnostics"];
        output += "\n\nModel Analysis:\n";
        output += "Label: ${diag["image_label"]}\n";
        output += "Confidence: ${(diag["image_confidence"] as double).toStringAsFixed(4)}\n";
      }

      setState(() => resultText = output);

      if (response["call_emergency"] == true) {
        _showEmergencyDialog();
      }
    } catch (e) {
      setState(() => resultText = "Error: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Emergency Detected"),
        content:
            const Text("This situation is critical.\nCall emergency services now?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Call 108"),
            onPressed: () {
              Navigator.pop(context);
              _callNumber();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _callNumber() async {
    final uri = Uri.parse("tel:108");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF03030A),
                  const Color(0xFF0D1B2A).withOpacity(0.8),
                  const Color(0xFF1A0033).withOpacity(0.6),
                ],
              ),
            ),
          ),

          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // Animated Header
                ScaleTransition(
                  scale: Tween(begin: 0.8, end: 1.0).animate(
                    CurvedAnimation(parent: _pulseController, curve: Curves.elasticOut),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00FFD5).withOpacity(0.3),
                          const Color(0xFF7C4DFF).withOpacity(0.2),
                        ],
                      ),
                    ),
                    child: const Icon(Icons.warning, size: 40, color: Color(0xFF00FFD5)),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'EMERGENCY SOS',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF00FFD5),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                Text(
                  'Describe your emergency situation',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[400],
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 30),

                // Description input field with glassmorphism
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1A1A2E).withOpacity(0.8),
                        const Color(0xFF16213E).withOpacity(0.8),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFF00FFD5).withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FFD5).withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: textCtrl,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Describe your emergency: injury type, severity, symptoms...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      contentPadding: const EdgeInsets.all(16),
                      border: InputBorder.none,
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Icon(Icons.edit, color: const Color(0xFF00FFD5).withOpacity(0.6)),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Action buttons grid
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _buildActionButton(Icons.camera_alt, 'Camera', pickImageFromCamera),
                    _buildActionButton(Icons.image, 'Gallery', pickImageFromGallery),
                    _buildActionButton(Icons.mic, 'Audio', pickAudio),
                  ],
                ),

                const SizedBox(height: 24),

                // AI Assistant Button (NEW!)
                _buildAIAssistantButton(),

                const SizedBox(height: 20),

                // Send button with gradient
                ScaleTransition(
                  scale: Tween(begin: 0.95, end: 1.0).animate(
                    CurvedAnimation(parent: _pulseController, curve: Curves.elasticInOut),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF00FFD5),
                          const Color(0xFF00B8A9).withOpacity(0.9),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00FFD5).withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 0,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: loading ? null : sendToServer,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: loading
                              ? const CircularProgressIndicator(color: Colors.black, strokeWidth: 2)
                              : Text(
                            'SEND TO SILENT SOS',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Result card with glassmorphism
                if (resultText.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1A1A2E).withOpacity(0.9),
                          const Color(0xFF16213E).withOpacity(0.9),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFF00FFD5).withOpacity(0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00FFD5).withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: Color(0xFF00FFD5)),
                            const SizedBox(width: 12),
                            Text(
                              'RESULT',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF00FFD5),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          resultText,
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: 1.05).animate(
          CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF00FFD5).withOpacity(0.15),
                const Color(0xFF7C4DFF).withOpacity(0.1),
              ],
            ),
            border: Border.all(
              color: const Color(0xFF00FFD5).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF00FFD5), size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAIAssistantButton() {
    return ScaleTransition(
      scale: Tween(begin: 0.95, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.elasticInOut),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF7C4DFF),
              const Color(0xFF00FFD5).withOpacity(0.8),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C4DFF).withOpacity(0.5),
              blurRadius: 25,
              spreadRadius: 0,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🤖 AI Assistant activated - analyzing your emergency...'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.smart_toy, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'AI ASSISTANT',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
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
