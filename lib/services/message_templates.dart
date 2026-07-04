/// SOS message templates for user selection
class SosTemplates {
  static const List<String> templates = [
    '🚨 I need immediate help. Please reach me.',
    '🚨 Emergency! I may be in danger.',
    '🚨 SOS! Please check my location immediately.',
    '🚨 I am not safe. Contact me urgently.',
  ];

  /// Get default template
  static String getDefault() => templates.first;

  /// Get template by index
  static String? byIndex(int index) {
    if (index >= 0 && index < templates.length) {
      return templates[index];
    }
    return null;
  }
}
