// TFLite helper snippet for Flutter using tflite_flutter
import 'package:tflite_flutter/tflite_flutter.dart';

class TFLiteHelper {
  late Interpreter _interpreter;

  Future<void> loadModel(String assetPath) async {
    _interpreter = await Interpreter.fromAsset(assetPath);
  }

  /// Run inference where `inputTensor` is a nested List matching the model input shape
  /// (for example: [[[...], ...], ...]) and `outputShape` is the expected output shape.
  List<double> runInference(Object inputTensor, List<int> outputShape) {
    final outputLen = outputShape.reduce((a, b) => a * b);
    final output = List<double>.filled(outputLen, 0.0);
    _interpreter.run(inputTensor, output);
    return output.map((e) => e.toDouble()).toList();
  }
}
