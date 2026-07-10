import 'package:flutter/foundation.dart';
import '../models/risk_level.dart';

/// Simple global notifier so non-UI services (SosController, voice services)
/// can notify the UI about risk level changes.
class RiskNotifier {
  static final ValueNotifier<RiskLevel> instance =
      ValueNotifier(RiskLevel.safe);

  static void set(RiskLevel level) {
    try {
      instance.value = level;
    } catch (_) {}
  }

  static RiskLevel get value => instance.value;
}
