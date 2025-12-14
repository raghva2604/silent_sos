class Config {
  // For emulator
  static const String baseUrlEmulator = "http://10.0.2.2:8000/api/v1";
  // For device (change to your PC IP if using a real phone)
  static const String baseUrlDevice = "http://10.240.2.158:8000/api/v1";
  // For web when backend runs locally
  static const String baseUrlWeb = "http://127.0.0.1:8000/api/v1";

  // Inference backend (FastAPI) may run separately on port 8000 without the
  // app-specific `/api/v1` prefix. Use emulator host `10.0.2.2` for Android
  // emulator to reach the host machine. Change these as needed for device.
  static const String inferenceBaseEmulator = "http://10.0.2.2:8000";
  static const String inferenceBaseDevice = "http://10.240.2.158:8000";
  static const String inferenceBaseWeb = "http://127.0.0.1:8000";
}
