import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img_pkg;

class TFLiteService {
  Interpreter? _interpreter;
  List<String>? _labels;

  Future<void> loadModel() async {
    if (_interpreter != null) return;

    // load interpreter from asset
    _interpreter = await Interpreter.fromAsset('assets/models/injury_detector.tflite');

    // load labels
    final raw = await rootBundle.loadString('assets/models/labels.txt');
    _labels = raw.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  /// Run inference on a File image. Returns {'label':..., 'confidence':...}
  Future<Map<String, dynamic>> runOnImage(File file) async {
    await loadModel();

    // get input tensor shape [1, h, w, 3]
    final inputTensor = _interpreter!.getInputTensor(0);
    final inputShape = inputTensor.shape;
    final height = inputShape[1];
    final width = inputShape[2];

    // Load & resize image using 'image' package
    final bytes = await file.readAsBytes();
    img_pkg.Image? image = img_pkg.decodeImage(bytes);
    if (image == null) throw Exception("Could not decode image");

    img_pkg.Image resized = img_pkg.copyResize(image, width: width, height: height);

    // Convert to normalized float32 list [1, height, width, 3] with values 0..1
    final Float32List input = Float32List(width * height * 3);
    int idx = 0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final rawBytes = resized.getBytes();
        final base = (y * width + x) * 4;
        final r = rawBytes[base] / 255.0;
        final g = rawBytes[base + 1] / 255.0;
        final b = rawBytes[base + 2] / 255.0;
        input[idx++] = r;
        input[idx++] = g;
        input[idx++] = b;
      }
    }

    // Build nested input list [1, h, w, 3]
    int pos = 0;
    final input4d = List.generate(1, (_) {
      return List.generate(height, (_) {
        return List.generate(width, (_) {
          final r = input[pos++].toDouble();
          final g = input[pos++].toDouble();
          final b = input[pos++].toDouble();
          return <double>[r, g, b];
        });
      });
    });

    // Prepare output buffer
    final outputTensor = _interpreter!.getOutputTensor(0);
    final outputShape = outputTensor.shape; // e.g. [1,1000]
    final outputSize = outputShape.reduce((a, b) => a * b);
    final output = List<double>.filled(outputSize, 0.0);

    // Run
    _interpreter!.run(input4d, output);

    // find top index
    int topIndex = 0;
    double topVal = output.isNotEmpty ? output[0] : 0.0;
    for (int i = 1; i < output.length; i++) {
      final v = output[i];
      if (v > topVal) {
        topVal = v;
        topIndex = i;
      }
    }

    final label = (_labels != null && topIndex < _labels!.length) ? _labels![topIndex] : 'class_$topIndex';
    return {'label': label, 'confidence': topVal};
  }
}
