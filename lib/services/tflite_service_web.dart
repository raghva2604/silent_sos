// Web stub for TFLite service. Web can't use FFI-based tflite packages.
class TFLiteService {
  Future<void> loadModel() async {
    throw UnsupportedError('TFLite is not supported on web');
  }

  /// On web this will always throw — use server-side inference instead.
  Future<Map<String, dynamic>> runOnImage(dynamic file) async {
    throw UnsupportedError('Local TFLite inference is not available on web');
  }
}
