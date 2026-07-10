import 'package:flutter/material.dart';

/// Risk level enumeration for global danger assessment system
/// Used across the app to indicate current security status
enum RiskLevel {
  safe, // ✅ Normal operation - green
  suspicious, // ⚠️ Potential threat detected - orange
  emergency, // 🔴 Critical emergency - red
}

extension RiskLevelDisplay on RiskLevel {
  /// Emoji for UI display
  String get emoji {
    switch (this) {
      case RiskLevel.safe:
        return '🟢';
      case RiskLevel.suspicious:
        return '🟡';
      case RiskLevel.emergency:
        return '🔴';
    }
  }

  /// Human-readable label
  String get label {
    switch (this) {
      case RiskLevel.safe:
        return 'SAFE';
      case RiskLevel.suspicious:
        return 'SUSPICIOUS ACTIVITY';
      case RiskLevel.emergency:
        return 'EMERGENCY ACTIVE';
    }
  }

  /// UI color based on risk level
  Color get displayColor {
    switch (this) {
      case RiskLevel.safe:
        return const Color(0xFF4CAF50); // Green
      case RiskLevel.suspicious:
        return const Color(0xFFFFC107); // Orange
      case RiskLevel.emergency:
        return const Color(0xFFF44336); // Red
    }
  }
}
