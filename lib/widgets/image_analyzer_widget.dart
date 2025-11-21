import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import '../services/tflite_service.dart';

class ImageAnalyzerWidget extends StatefulWidget {
  final String backendBaseUrl; // e.g. http://10.0.2.2:8000/api/v1
  const ImageAnalyzerWidget({super.key, required this.backendBaseUrl});

  @override
  State<ImageAnalyzerWidget> createState() => _ImageAnalyzerWidgetState();
}

class _ImageAnalyzerWidgetState extends State<ImageAnalyzerWidget> {
  final ImagePicker _picker = ImagePicker();
  final TFLiteService _tflite = TFLiteService();
  bool _loadingModel = false;
  bool _modelAvailable = false;
  String? _resultText;
  Map<String, dynamic>? _lastResult;
  XFile? _pickedFile;

  @override
  void initState() {
    super.initState();
    _initModelIfMobile();
  }

  Future<void> _initModelIfMobile() async {
    if (kIsWeb) return;
    setState(() => _loadingModel = true);
    try {
      await _tflite.loadModel();
      setState(() {
        _modelAvailable = true;
      });
    } catch (e) {
      setState(() {
        _modelAvailable = false;
      });
    } finally {
      setState(() => _loadingModel = false);
    }
  }

  Future<void> _pickAndAnalyze(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
        source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _pickedFile = picked;
      _resultText = null;
      _lastResult = null;
    });

    if (!kIsWeb && _modelAvailable) {
      // mobile: try on-device first
      try {
        final file = File(picked.path);
        final res = await _tflite.runOnImage(file);
        setState(() {
          _lastResult = {"provider": "tflite", "result": res};
          _resultText =
              "Label: ${res['label']} (confidence ${(res['confidence'] as num).toStringAsFixed(2)})";
        });
        return;
      } catch (e) {
        // fallback to server
      }
    }

    // web or fallback: upload to server
    await _uploadToServer(picked);
  }

  Future<void> _uploadToServer(XFile picked) async {
    setState(() => _resultText = "Uploading to server...");
    try {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        final b64 = base64Encode(bytes);
        final body = jsonEncode({"image_b64": b64, "lang_hint": "auto"});
        final resp = await http.post(
            Uri.parse('${widget.backendBaseUrl}/image_analyze'),
            headers: {'Content-Type': 'application/json'},
            body: body);
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final jsonResp = jsonDecode(resp.body);
          setState(() {
            _lastResult = {"provider": "server", "result": jsonResp};
            _resultText =
                "Server label: ${jsonResp['analysis']['diagnostics']['label'] ?? 'n/a'}";
          });
        } else {
          setState(() => _resultText = "Server error: ${resp.statusCode}");
        }
      } else {
        // mobile/multi-platform: multipart/form-data
        final uri = Uri.parse('${widget.backendBaseUrl}/image_analyze');
        final request = http.MultipartRequest('POST', uri);
        request.files.add(await http.MultipartFile.fromPath('image', picked.path,
            filename: p.basename(picked.path)));
        final streamed = await request.send();
        final body = await streamed.stream.bytesToString();
        if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
          final jsonResp = jsonDecode(body);
          setState(() {
            _lastResult = {"provider": "server", "result": jsonResp};
            _resultText =
                "Server label: ${jsonResp['analysis']['diagnostics']['label'] ?? 'n/a'}";
          });
        } else {
          setState(
              () => _resultText = "Server error: ${streamed.statusCode}: $body");
        }
      }
    } catch (e) {
      setState(() => _resultText = "Upload failed: $e");
    }
  }

  Widget _previewArea() {
    if (_pickedFile == null) return const Text("No image selected");
    if (kIsWeb) {
      return Image.network(_pickedFile!.path);
    } else {
      return Image.file(File(_pickedFile!.path));
    }
  }

  Widget _resultCard() {
    if (_lastResult == null) return const SizedBox.shrink();
    final provider = _lastResult!['provider'];
    final result = _lastResult!['result'];
    if (provider == 'tflite') {
      final r = result as Map<String, dynamic>;
      return Card(
        child: ListTile(
          title: const Text("On-device result"),
          subtitle: Text(
              "Label: ${r['label']} \nConfidence: ${(r['confidence'] as num).toStringAsFixed(2)}"),
        ),
      );
    } else {
      // server
      final analysis = result['analysis'];
      final diag = analysis != null ? analysis['diagnostics'] ?? {} : {};
      final label = diag != null ? diag['label'] : null;
      return Card(
        child: ListTile(
          title: const Text("Server result"),
          subtitle: Text(
              "Label: ${label ?? 'n/a'}\nInstructions: ${analysis != null ? (analysis['localized_instructions'] ?? analysis['instruction']) : 'n/a'}"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _previewArea()),
        const SizedBox(height: 8),
        Text(_resultText ?? "No result"),
        const SizedBox(height: 8),
        // show model loading indicator when initializing on device
        if (_loadingModel)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 8),
            Text('Loading model...')
          ]),
        Wrap(
          spacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: () => _pickAndAnalyze(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text("Camera"),
            ),
            ElevatedButton.icon(
              onPressed: () => _pickAndAnalyze(ImageSource.gallery),
              icon: const Icon(Icons.photo),
              label: const Text("Gallery"),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _resultCard(),
      ],
    );
  }
}
