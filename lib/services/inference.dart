// Simplified TFLite inference helpers that avoid tflite_flutter_helper types.
// Uses raw buffers with tflite_flutter Interpreter. Adapt preprocessing to your model.

import 'package:tflite_flutter/tflite_flutter.dart';

class SimpleTFLiteModel {
  late Interpreter _interpreter;

  Future<void> loadModel(String assetPath, {int numThreads = 1}) async {
    final options = InterpreterOptions()..threads = numThreads;
    _interpreter = await Interpreter.fromAsset(assetPath, options: options);
  }

  /// Run a model that takes a float32 input tensor of shape [1,h,w,3] and
  /// returns a float32 output vector. `input` should contain normalized floats.
  List<double> runForVector(List<double> input, List<int> inputShape, List<int> outputShape) {
    // Build nested list for interpreter input
    final inputTensor = _wrapInput(input, inputShape);

    // Prepare output buffer
    final outputLength = outputShape.reduce((a, b) => a * b);
    final outputBuffer = List.filled(outputLength, 0.0);

    _interpreter.run(inputTensor, outputBuffer);

    return outputBuffer.map((e) => e.toDouble()).toList();
  }

  /// Run a model with multiple outputs. Provide prepared input and a map of
  /// output index -> preallocated buffer (List or TypedData) to fill.
  void runForMultipleInputs(List<Object> inputs, Map<int, Object> outputs) {
    _interpreter.runForMultipleInputs(inputs, outputs);
  }

  dynamic _wrapInput(List<double> flat, List<int> shape) {
    // convert flat list into nested lists matching shape e.g. [1,h,w,3]
    if (shape.length == 1) return flat;
    // recursive builder
    int idx = 0;
    Object build(int dim) {
      final len = shape[dim];
      if (dim == shape.length - 1) {
        final out = List<double>.filled(len, 0.0);
        for (int i = 0; i < len; i++) {
          out[i] = flat[idx++];
        }
        return out;
      } else {
        final out = <dynamic>[];
        for (int i = 0; i < len; i++) {
          out.add(build(dim + 1));
        }
        return out;
      }
    }

    return build(0);
  }
}
