import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/ui_modes.dart';
import '../sos/sos_controller.dart';
import '../services/ui_mode_service.dart';
import '../screens/theme_store_screen.dart';
import '../services/recording_status_service.dart';
import '../services/sos_service.dart';
import 'recording_indicator.dart';

/// Wraps any disguise UI and provides a reliable hidden SOS trigger.
///
/// The gestures are intentionally broad (translucent hit testing) so that
/// the trigger can fire even when the UI contains many interactive elements.
///
/// A small overlay hint is shown so users can discover how to switch UI skins.
class DisguiseWrapper extends StatefulWidget {
  final Widget child;

  const DisguiseWrapper({required this.child, super.key});

  @override
  State<DisguiseWrapper> createState() => _DisguiseWrapperState();
}

class _DisguiseWrapperState extends State<DisguiseWrapper> {
  static const _hintKey = 'disguise_mode_hint_dismissed';
  bool _hintVisible = false;

  @override
  void initState() {
    super.initState();
    _loadHintState();
  }

  Future<void> _loadHintState() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_hintKey) ?? false;
    if (mounted) {
      setState(() {
        _hintVisible = !dismissed;
      });
    }
  }

  Future<void> _dismissHint() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hintKey, true);
    if (mounted) {
      setState(() {
        _hintVisible = false;
      });
    }
  }

  void _openModeStore() {
    _dismissHint();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ThemeStoreScreen()),
    );
  }

  String _modeName(AppUIMode mode) {
    switch (mode) {
      case AppUIMode.safety:
        return 'Safety';
      case AppUIMode.game:
        return 'Game';
      case AppUIMode.calculator:
        return 'Calculator';
      case AppUIMode.chat:
        return 'Chat';
      case AppUIMode.notes:
        return 'Notes';
      case AppUIMode.instagram:
        return 'Instagram';
      case AppUIMode.bank:
        return 'Bank';
      case AppUIMode.shopping:
        return 'Shopping';
      case AppUIMode.army:
        return 'Army';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          try {
            final uiService = Provider.of<UIModeService>(context, listen: false);
            if (uiService.mode != AppUIMode.safety) {
              uiService.changeMode(AppUIMode.safety);
            } else {
              Navigator.of(context).pop();
            }
          } catch (_) {
            // Fail-safe: let system handle back navigation if mode cannot be resolved.
            Navigator.of(context).pop();
          }
        }
      },
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPress: () {
              final ctx = SOSservice.navigatorKey.currentState?.context;
              if (ctx != null) {
                SosController.triggerSOS(context: ctx, source: 'Gesture');
              }
            },
            onDoubleTap: () {
              final ctx = SOSservice.navigatorKey.currentState?.context;
              if (ctx != null) {
                SosController.triggerSOS(context: ctx, source: 'Gesture');
              }
            },
            child: widget.child,
          ),
          // Mode indicator only in debug mode
          if (kDebugMode)
            Positioned(
              top: 14,
              right: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Consumer<UIModeService>(
                    builder: (ctx, uiModeService, _) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.visibility,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Mode: ${_modeName(uiModeService.mode)}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: _hintVisible ? 1 : 0,
                    child: GestureDetector(
                      onTap: _openModeStore,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.layers, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Tap to switch disguise',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _openModeStore,
                    child: Container(
                      height: 28,
                      width: 28,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.layers,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          // Recording indicator
          Consumer<RecordingStatusService>(
            builder: (ctx, recordingService, _) {
              if (recordingService.isRecording) {
                return const RecordingIndicator();
              }
              return const SizedBox.shrink();
            },
          ),

          // Small return-to-safety button (easily accessible in disguise UIs)
          Positioned(
            top: 12,
            left: 12,
            child: GestureDetector(
              onTap: () {
                try {
                  final uiService =
                      Provider.of<UIModeService>(context, listen: false);
                  uiService.changeMode(AppUIMode.safety);
                } catch (_) {}
              },
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.security, size: 18, color: Colors.white),
              ),
            ),
          ),

          // Back/Next mode button (cycle through modes) for quick evaluation nav
          Positioned(
            bottom: 12,
            right: 12,
            child: GestureDetector(
              onTap: () {
                final uiService =
                    Provider.of<UIModeService>(context, listen: false);
                final modes = AppUIMode.values
                    .where((m) => m != AppUIMode.safety)
                    .toList();
                final current = uiService.mode;
                final index = modes.indexWhere((m) => m == current);
                final nextMode = index < 0 || index + 1 >= modes.length
                    ? modes.first
                    : modes[index + 1];
                uiService.changeMode(nextMode);
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward,
                    size: 20, color: Colors.white),
              ),
            ),
          ),

          // Small cancel button for silent countdowns (disguised mode)
          ValueListenableBuilder<bool>(
            valueListenable: SosController.silentCountdownActive,
            builder: (context, active, child) {
              return Positioned(
                bottom: 80,
                right: 16,
                child: IgnorePointer(
                  ignoring: !active,
                  child: Opacity(
                    opacity: active ? 1.0 : 0.35,
                    child: GestureDetector(
                      onTap: () {
                        if (!active) return;
                        SosController.cancelSilentCountdown();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('SOS cancelled.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
