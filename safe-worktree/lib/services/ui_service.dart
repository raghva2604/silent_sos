import 'ui_mode_service.dart';

/// Legacy compatibility wrapper.
///
/// The app used to have a theme + mode service. This is now replaced by
/// [UIModeService], which only handles the active disguise mode.
///
/// Existing code can still call `UIService()` and use it as a drop-in replacement.
class UIService extends UIModeService {}
