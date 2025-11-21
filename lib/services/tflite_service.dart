// Conditional import: native implementation uses tflite_flutter (FFI),
// web implementation is a stub that throws UnsupportedError.
export 'tflite_service_io.dart' if (dart.library.html) 'tflite_service_web.dart';

