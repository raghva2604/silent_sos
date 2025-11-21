// TFLite inference helpers for both classifier and SSD-style detector
// Adapt the input/output shapes and preprocessing to your exact model.

import 'dart:io';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

class TFLiteClassifier {
  late Interpreter _interpreter;
  late TensorImage _inputImage;
  late TensorBuffer _outputBuffer;
  final int inputSize;

  TFLiteClassifier({required this.inputSize});

  Future<void> loadModel(String assetPath, {int numThreads = 1}) async {
    final options = InterpreterOptions()..threads = numThreads;
    _interpreter = await Interpreter.fromAsset(assetPath, options: options);

    final inputShape = _interpreter.getInputTensor(0).shape; // e.g. [1,224,224,3]
    final outputShape = _interpreter.getOutputTensor(0).shape; // e.g. [1,1000]

    _inputImage = TensorImage.fromType(TensorImageType.float32);
    _outputBuffer = TensorBuffer.createFixedSize(outputShape, TfLiteType.float32);
  }

  /// Preprocess: resize + normalize. Adjust normalization to model's expectation.
  TensorImage preprocess(ImageProcessor imageProcessor, TensorImage inputImage) {
    return imageProcessor.process(inputImage);
  }

  List<double> predict(TensorImage inputImage) {
    _interpreter.run(inputImage.buffer, _outputBuffer.buffer);
    return _outputBuffer.getDoubleList();
  }
}

class TFLiteDetector {
  late Interpreter _interpreter;
  late TensorImage _inputImage;
  final int inputSize;

  TFLiteDetector({required this.inputSize});

  Future<void> loadModel(String assetPath, {int numThreads = 1}) async {
    final options = InterpreterOptions()..threads = numThreads;
    _interpreter = await Interpreter.fromAsset(assetPath, options: options);

    _inputImage = TensorImage.fromType(TensorImageType.uint8);
  }

  /// Run detector and return raw outputs. Postprocessing (NMS, decode boxes) required.
  Map<String, Object> detect(TensorImage inputImage) {
    // Example output names vary by model. Typical SSD outputs:
    // locations: [1,num_boxes,4]
    // classes: [1,num_boxes]
    // scores: [1,num_boxes]
    // num_detections: [1]

    final outputs = <int, Object>{};

    // Prepare buffers based on interpreter output tensors
    for (int i = 0; i < _interpreter.getOutputTensors().length; i++) {
      final t = _interpreter.getOutputTensor(i);
      final shape = t.shape;
      final dtype = t.type;
      outputs[i] = TensorBuffer.createFixedSize(shape, dtype);
    }

    _interpreter.runForMultipleInputs([inputImage.buffer], outputs);

    return outputs;
  }
}

/*
Notes:
- For classification: use TensorImage + ImageProcessor from tflite_flutter_helper to resize/normalize.
  Example preprocess:
    final processor = ImageProcessorBuilder()
        .add(ResizeOp(inputSize, inputSize, ResizeMethod.BILINEAR))
        .add(NormalizeOp(127.5, 127.5)) // if model expects [-1,1]
        .build();
    var ti = TensorImage.fromFile(File(path));
    ti = processor.process(ti);

- For detection: model outputs differ. Inspect `_interpreter.getOutputTensors()` to determine shapes and types, then decode boxes and apply NMS.
- Provide exact model input size and output layout if you want a tailored `runDetection` helper that returns parsed boxes/labels.
*/
