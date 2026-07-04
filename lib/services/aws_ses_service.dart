class AwsSesService {
  /// AWS SES fallback stub.
  /// Replace with real AWS Signature V4 + SES API call when ready.
  static Future<void> sendLocation(
    String toEmail,
    String location,
    String time,
    String message,
  ) async {
    throw Exception('AWS SES is not configured yet (fallback placeholder).');
  }

  static Future<void> sendVideo(
    String toEmail,
    String videoLink,
    String time,
    String message,
  ) async {
    throw Exception('AWS SES is not configured yet (fallback placeholder).');
  }
}
