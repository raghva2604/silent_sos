// WhatsApp backend helper removed from the app.
// The server-side WhatsApp scaffold (if present) lives separately in /server.
// Keeping a small stub here to avoid runtime import errors in case any
// client code still references the helper.

class WhatsAppBackend {
  /// Deprecated stub: always returns false. Use SMS or server-based flows instead.
  static Future<bool> sendViaBackend(String backendUrl, List<String> recipients, String message, {List<String>? mediaUrls}) async {
    return Future.value(false);
  }
}
