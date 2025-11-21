// TFLite helper snippet for Flutter using tflite_flutter
import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';

class TFLiteHelper {
  late Interpreter _interpreter;

  Future<void> loadModel(String assetPath) async {
    _interpreter = await Interpreter.fromAsset(assetPath);
  }

  /// Example for a simple image classifier that expects a 224x224 RGB float input
  /// Adapt preprocessing and output handling for your model.
  List<double> runInference(List<double> inputTensor, List<int> inputShape) {
    final output = List.filled(1000, 0.0).reshape([1, 1000]);
    _interpreter.run(inputTensor.reshape([1, ...inputShape]), output);
    return output.cast<double>();
  }
}
