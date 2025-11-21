TFLite image inference (Flutter)

Recommended model:
- Use a MobileNetV2/SSD-lite style detector converted to TFLite for mobile inference.
- If you need bounding boxes and object detection, use a small SSD-MobileNetV2 converted via TensorFlow's `export_tflite`/`tflite_convert`.

Flutter packages:
- `tflite_flutter`: TFLite interpreter for Flutter (supports Android & iOS)
- `tflite_flutter_helper`: helper for image preprocessing/postprocessing

Example usage (high-level):
1. Add to `pubspec.yaml`:

dependencies:
  tflite_flutter: ^0.10.0
  tflite_flutter_helper: ^0.3.0

2. Put model in `assets/models/injury_detector.tflite` and register in `pubspec.yaml`:

flutter:
  assets:
    - assets/models/injury_detector.tflite

3. Use `TFLiteHelper` (see `lib/services/tflite_helper.dart`) to load model and run inference.

Notes:
- Match the input size & datatype to your model (e.g., 320x320 RGB uint8/float32).
- For object detection models, you'll also need label mapping `assets/models/labels.txt` and NMS postprocessing.
- If you want, I can provide a full SSD-MobileNet conversion checklist and a small example inference pipeline with preprocessing code.
