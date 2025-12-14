import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../services/tflite_service.dart';

class EmergencyScreenFixed extends StatefulWidget {
  const EmergencyScreenFixed({super.key});

  @override
  State<EmergencyScreenFixed> createState() => _EmergencyScreenFixedState();
}

class _EmergencyScreenFixedState extends State<EmergencyScreenFixed> {
  final ApiService api = ApiService();
  final TextEditingController textCtrl = TextEditingController();
  final TFLiteService tflite = TFLiteService();
  File? imageFile;
  File? audioFile;
  String resultText = "";
  bool loading = false;

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
        String msg = e.toString();
        if (kIsWeb && msg.contains('Failed to fetch')) {
          msg = 'Failed to contact backend at http://127.0.0.1:8000. Start the backend and enable CORS.\nOriginal error: $msg';
        }
        setState(() => resultText = "Server error: $msg");
      }

      return;
    }

    // -- non-web path (mobile/desktop) --
    final file = File(picked.path);
    setState(() => imageFile = file);

    // run local TFLite
    try {
      final local = await tflite.runOnImage(file);
      // Be defensive: model may return nulls or non-double types
      final label = local['label'] != null ? local['label'].toString() : 'unknown';
      final confNum = local['confidence'] is num ? (local['confidence'] as num).toDouble() : 0.0;
      setState(() {
        resultText = "Local: $label (conf ${confNum.toStringAsFixed(2)})";
      });
      if (label == 'severe_bleeding' && confNum > 0.7) {
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
        String msg = e.toString();
        if (kIsWeb && msg.contains('Failed to fetch')) {
          msg = 'Failed to contact backend at http://127.0.0.1:8000. Start the backend and enable CORS.\nOriginal error: $msg';
        }
        setState(() => resultText = "Server error: $msg");
      }

      return;
    }

    // -- non-web path (mobile/desktop) --
    final file = File(picked.path);
    setState(() => imageFile = file);

    // run local TFLite
    try {
      final local = await tflite.runOnImage(file);
      final label = local['label'] != null ? local['label'].toString() : 'unknown';
      final confNum = local['confidence'] is num ? (local['confidence'] as num).toDouble() : 0.0;
      setState(() {
        resultText = "Local: $label (conf ${confNum.toStringAsFixed(2)})";
      });
      if (label == 'severe_bleeding' && confNum > 0.7) {
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
        final imageLabel = diag["image_label"]?.toString() ?? 'unknown';
        final imageConf = (diag["image_confidence"] is num) ? (diag["image_confidence"] as num).toDouble() : 0.0;
        output += "\n\nModel Analysis:\n";
        output += "Label: $imageLabel\n";
        output += "Confidence: ${imageConf.toStringAsFixed(4)}\n";
      }

      setState(() => resultText = output);

      if (response["call_emergency"] == true) {
        _showEmergencyDialog();
      }
    } catch (e) {
      String err = e.toString();
      if (kIsWeb && err.contains('Failed to fetch')) {
        err = 'Failed to contact backend at http://127.0.0.1:8000.\nIf you are running the app in the browser, start the backend and enable CORS.\nOriginal error: $err';
      }
      setState(() => resultText = "Error: $err");
    } finally {
      setState(() => loading = false);
    }
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Emergency Detected"),
        content: const Text("This situation is critical.\nCall emergency services now?"),
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
      appBar: AppBar(title: const Text("Silent SOS")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Describe Emergency:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            TextField(
              controller: textCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "e.g., Person is bleeding heavily",
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: pickImageFromCamera,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Camera"),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: pickImageFromGallery,
                  icon: const Icon(Icons.photo),
                  label: const Text("Gallery"),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: pickAudio,
                  icon: const Icon(Icons.mic),
                  label: const Text("Audio"),
                ),
              ],
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: loading ? null : sendToServer,
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Send to Silent SOS"),
            ),

            const SizedBox(height: 20),
            const Text("RESULT:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SelectableText(resultText),
          ],
        ),
      ),
    );
  }
}
 
