class ApiConfig {
    // Primary backend endpoint. Set to production host for deployed apps.
    // Updated from local development hosts to production as requested.
    static const String baseUrl = "http://niradevelopers.duckdns.org:3001";

    // Fallback endpoint for emulators/devices if needed. Keep same host/port
    // or change to an internal reachable address for testing.
    static const String fallbackBaseUrl =
      "http://niradevelopers.duckdns.org:3001";

  static const String sendSos = "$baseUrl/sos-send-sos";
  static const String sendSosFallback = "$fallbackBaseUrl/sos-send-sos";

  static const String updateLiveLocation = "$baseUrl/update-live-location";
  static const String updateLiveLocationFallback =
      "$fallbackBaseUrl/update-live-location";

  static const String getLiveLocation = "$baseUrl/get-live-location";
  static const String generateUploadUrl = "$baseUrl/generate-upload-url";
  static const String generateUploadUrlFallback =
      "$fallbackBaseUrl/generate-upload-url";

  // URL prefix for manual video key resolution when backend download endpoint is unavailable.
  // Set this to your own bucket/edge endpoint (region must match your bucket):
  //   ap-south-1: https://your-bucket.s3.ap-south-1.amazonaws.com/
  //   ap-southeast-2: https://your-bucket.s3-ap-southeast-2.amazonaws.com/
  // or CloudFront: https://dxxxxx.cloudfront.net/
  // If you can configure signed URLs on backend, leave this as fallback only.
  // Use your actual bucket path for direct GET fallbacks when signed endpoint is unavailable.
  // This should match the bucket host in signed upload URLs (for example from logs):
  // https://sos-emergency-videos-ap-south-1-raghav.s3-accelerate.amazonaws.com
  static const String videoDownloadBaseUrl =
      "https://sos-emergency-videos-ap-south-1-raghav.s3-accelerate.amazonaws.com";

  // Application secret header used by server endpoints
  static const String appSecret = 'Niha@2604';

  /// Common headers for API requests. Callers can add/override entries.
  static Map<String, String> defaultHeaders({Map<String, String>? extra}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'x-app-secret': appSecret,
    };
    if (extra != null) headers.addAll(extra);
    return headers;
  }
}
