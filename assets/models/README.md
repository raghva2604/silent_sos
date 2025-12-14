This folder is intended to hold TFLite models used by the Flutter app.

Place your model file at `assets/models/model.tflite` and update `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/models/model.tflite
```

If you exported a TFLite model from `src/tf/train.py`, copy `models/model.tflite` here for inclusion in the app.
