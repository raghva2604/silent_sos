import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Example that demonstrates loading a tflite model from assets and running
/// a simple inference with a random input. Add `tflite_flutter` to
/// your `pubspec.yaml` before using this example.
class TFLiteExample {
  Interpreter? _interpreter;

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('assets/models/model.tflite');
  }

  /// Run inference with a dummy input shaped [1,10]
  List<double> runDummy() {
    if (_interpreter == null) throw Exception('Interpreter not loaded');
    final input = List<double>.filled(10, 0.5);
    final inputBuffer = Float32List.fromList(input).buffer;
    final output = Float32List(1);

    _interpreter!.run(inputBuffer.asFloat32List(), output);
    return output.toList();
  }
}
