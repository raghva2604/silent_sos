import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/ui_modes.dart';

class UIModeService extends ChangeNotifier {
  static const _key = 'ui_mode';

  AppUIMode currentMode = AppUIMode.safety;

  /// Compatibility alias for legacy code.
  AppUIMode get mode => currentMode;

  /// Compatibility alias for legacy code.
  Future<void> setMode(AppUIMode mode) => changeMode(mode);

  /// Provides a default theme for the app.
  ///
  /// This is kept for backwards compatibility with the previous theme system.
  ThemeData getThemeData() {
    return ThemeData(useMaterial3: true);
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getInt(_key);
      debugPrint(
          '🔧 UIModeService.load(): stored index=$index, available modes=${AppUIMode.values.length}');
      if (index != null && index >= 0 && index < AppUIMode.values.length) {
        currentMode = AppUIMode.values[index];
        debugPrint('✅ UIModeService.load(): loaded mode=${currentMode}');
      } else {
        debugPrint(
            '⚠️ UIModeService.load(): no valid stored mode, using default=${currentMode}');
      }
    } catch (e) {
      debugPrint('❌ UIModeService.load(): error loading mode: $e');
    }
    notifyListeners();
  }

  Future<void> changeMode(AppUIMode mode) async {
    debugPrint(
        '🔄 UIModeService.changeMode(): changing from ${currentMode} to ${mode}');
    currentMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, mode.index);
    debugPrint('💾 UIModeService.changeMode(): saved mode index=${mode.index}');
    notifyListeners();
  }
}
