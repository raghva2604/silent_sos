/// Call sequencing and retry configuration
class CallSettings {
  final int retryCount;      // number of retry attempts per contact

  CallSettings({
    this.retryCount = 1,
  });

  @override
  String toString() =>
      'CallSettings(retries: $retryCount)';
}
