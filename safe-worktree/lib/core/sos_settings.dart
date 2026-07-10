class SosSettings {
  /// Toggle: record video or not
  static bool recordVideo = true;

  /// Recording duration PER CAMERA (seconds)
  /// Example: 20 = 20s front + 20s back
  static int recordDurationSeconds = 20;

  /// Minimum recording duration (seconds)
  static const int recordDurationMin = 5;

  /// Maximum recording duration (seconds)
  static const int recordDurationMax = 60;

  /// Upload speed: 'slow' | 'medium' | 'fast'
  /// slow: record 60s per camera, medium: 30s, fast: 20s
  static String uploadSpeed = 'medium';

  /// Video file size estimate (MB) per second at medium quality
  static const double mbPerSecondAtMediumQuality = 0.8;

  /// Calculate recommended recording duration based on upload speed
  static int getRecommendedDurationPerCamera({int maxMbPerVideo = 10}) {
    int speedDuration = 30; // medium default
    if (uploadSpeed == 'slow') {
      speedDuration = 60;
    } else if (uploadSpeed == 'fast') {
      speedDuration = 20;
    }
    final recommended =
        speedDuration.clamp(recordDurationMin, recordDurationMax);
    final maxBySize = (maxMbPerVideo / mbPerSecondAtMediumQuality).toInt();
    return recommended.clamp(5, maxBySize);
  }
}
