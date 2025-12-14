# Flutter TFLite Integration

This document explains how to wire a TFLite model into the Flutter app using `tflite_flutter`.

Steps

1. Add dependencies in `pubspec.yaml`:

```yaml
dependencies:
  tflite_flutter: ^0.10.0
  tflite_flutter_helper: ^0.3.0
```

2. Place your TFLite model under `assets/models/model.tflite` and add it to `pubspec.yaml` assets:

```yaml
flutter:
  assets:
    - assets/models/model.tflite
```

3. Example usage (see `lib/src/tflite_example.dart` for a full snippet):

- Load the model with `Interpreter.fromAsset('assets/models/model.tflite')` or `Interpreter.fromBuffer`.
- Prepare input tensor using `TensorImage` and `ImageProcessor` from `tflite_flutter_helper` for images.
- Run inference with `interpreter.run(inputBuffer.buffer, outputBuffer.buffer)`.

I included a small example file `lib/src/tflite_example.dart` that shows how to load the interpreter and run a dummy input.
