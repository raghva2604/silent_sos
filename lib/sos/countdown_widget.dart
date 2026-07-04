import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:silent_sos/settings/user_settings.dart';
import 'package:silent_sos/core/sos_controller.dart';
// DISABLED Phase 1: import 'package:silent_sos/core/fall_learning.dart';
import 'package:silent_sos/services/sos_integration.dart';

class CountdownWidget extends StatefulWidget {
  final String trigger; // 'manual', 'fall', or 'voice'
  final VoidCallback onCountdownComplete;
  final VoidCallback? onCancel;
  final UserSettings settings;

  const CountdownWidget({
    super.key,
    required this.trigger,
    required this.onCountdownComplete,
    this.onCancel,
    required this.settings,
  });

  @override
  State<CountdownWidget> createState() => _CountdownWidgetState();
}

class _CountdownWidgetState extends State<CountdownWidget>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late int _remainingSeconds;
  bool _isCancelled = false;
  late Ticker _ticker;
  int _lastSecond = -1;
  double _pulseScale = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _remainingSeconds = widget.settings.sosCountdownSeconds;
    _startCountdown();
  }

  void _startCountdown() {
    // Ticker-based countdown: UI-bound, OEM-safe, guaranteed vibration
    _ticker = createTicker((elapsed) {
      final secondsPassed = elapsed.inSeconds;
      final newRemaining = widget.settings.sosCountdownSeconds - secondsPassed;

      // Trigger haptic + pulse only when second changes
      if (newRemaining != _lastSecond && newRemaining >= 0 && !_isCancelled) {
        _lastSecond = newRemaining;

        // 🔥 GUARANTEED haptic on every second boundary
        try {
          HapticFeedback.heavyImpact();
        } catch (_) {}

        // 💓 Pulse OUT
        setState(() {
          _pulseScale = 1.15;
          _remainingSeconds = newRemaining;
        });

        // 💓 Pulse contract (same frame, micro-task)
        Future.microtask(() {
          if (mounted && !_isCancelled) {
            setState(() => _pulseScale = 1.0);
          }
        });

        // Countdown complete
        if (newRemaining == 0) {
          _ticker.stop();
          if (mounted) {
            widget.onCountdownComplete();
          }
        }
      }
    });

    _ticker.start();
  }

  void _cancel() {
    _isCancelled = true;
    _ticker.stop();

    // Stop any native recording in progress
    try {
      SosIntegration.stopNativeRecording();
      debugPrint('✓ Stopped native recording on cancel');
    } catch (e) {
      debugPrint('⚠️ Failed to stop native recording: $e');
    }

    debugPrint('User cancelled alert');

    // Stop SOS countdown via controller
    try {
      SosController.instance.stop();
      debugPrint('✓ SOS Countdown stopped');
    } catch (e) {
      debugPrint('⚠️ Failed to stop SOS Countdown: $e');
    }

    widget.onCancel?.call();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // WillPopScope is deprecated in newer Flutter versions but still widely
    // supported; keep using it with an explicit ignore to maintain behavior.
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color.fromRGBO(139, 0, 0, 0.95),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // 🔴 Pulsing SOS circle (synced with vibration)
              AnimatedScale(
                scale: _pulseScale,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.shade700,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.7),
                        blurRadius: 30,
                        spreadRadius: 8,
                      )
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.sos_rounded,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Countdown number
              Text(
                _remainingSeconds.toString().padLeft(2, '0'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 96,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'seconds',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'Triggered by: ${widget.trigger.toUpperCase()}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: _isCancelled ? null : _cancel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 15,
                  ),
                ),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
