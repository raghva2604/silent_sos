import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:math' as math;

/// Internal debug widget for testing ML model inference.
///
/// **NOT FOR PUBLIC USE** — Debug only.
/// This widget is used internally to validate model loading and inference.
class DebugModelInference extends StatefulWidget {
  const DebugModelInference({super.key});

  @override
  State<DebugModelInference> createState() => _DebugModelInferenceState();
}

class _DebugModelInferenceState extends State<DebugModelInference> {
  Interpreter? _imageInterp;
  Interpreter? _fallInterp;
  String _result = '';

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  /// Load TFLite models from assets.
  Future<void> _loadModels() async {
    try {
      _imageInterp = await Interpreter.fromAsset('assets/models/danger_image_model.tflite');
      _fallInterp = await Interpreter.fromAsset('assets/models/fall_detector_model.tflite');
      setState(() => _result = 'Models loaded');
    } catch (e) {
      setState(() => _result = 'Load error: $e');
    }
  }

  /// Test image inference with resized 224x224 RGB input.
  Future<void> _runImageTest() async {
    try {
      final data = await rootBundle.load('assets/debug_test.jpg');
      final bytes = data.buffer.asUint8List();
      final image = img.decodeImage(bytes)!;
      final resized = img.copyResize(image, width: 224, height: 224);

      final input = Float32List(1 * 224 * 224 * 3);
      int idx = 0;
      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          final pixel = resized.getPixel(x, y);
          final r = pixel.r;
          final g = pixel.g;
          final b = pixel.b;
          input[idx++] = (r / 255.0);
          input[idx++] = (g / 255.0);
          input[idx++] = (b / 255.0);
        }
      }

      var output = List.filled(6, 0.0).reshape([1, 6]);
      _imageInterp!.run(input.reshape([1, 224, 224, 3]), output);
      setState(() => _result = 'Image preds: ${output[0]}');
    } catch (e) {
      setState(() => _result = 'Image test error: $e');
    }
  }

  /// Test fall detection inference from accelerometer sequence.
  Future<void> _runFallTest() async {
    try {
      final csv = await rootBundle.loadString('assets/debug_fall.csv');
      final rows = csv.split('\n').map((r) => r.trim()).where((r) => r.isNotEmpty).toList();
      final seq = rows.map((r) {
        final parts = r.split(',');
        if (parts.length >= 3) {
          final x = double.parse(parts[0]);
          final y = double.parse(parts[1]);
          final z = double.parse(parts[2]);
          return math.sqrt(x * x + y * y + z * z);
        } else {
          return double.parse(parts[0]);
        }
      }).toList();

      final seqLen = _fallInterp!.getInputTensor(0).shape[1];
      while (seq.length < seqLen) {
        seq.add(0.0);
      }

      final input = Float32List.fromList(seq.sublist(0, seqLen));
      final inShape = [1, seqLen, 1];
      final outShape = [1, 1];
      var output = List.filled(1, 0.0).reshape(outShape);
      _fallInterp!.run(input.reshape(inShape), output);
      setState(() => _result = 'Fall pred: ${output[0][0]}');
    } catch (e) {
      setState(() => _result = 'Fall test error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug Models')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(_result),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _runImageTest,
              child: const Text('Run Image Test'),
            ),
            ElevatedButton(
              onPressed: _runFallTest,
              child: const Text('Run Fall Test'),
            ),
          ],
        ),
      ),
    );
  }
}
