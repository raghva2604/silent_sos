import 'dart:async';
import 'package:flutter/material.dart';

class OverlayTimer extends StatefulWidget {
  final int seconds;
  final VoidCallback? onComplete;
  const OverlayTimer({super.key, required this.seconds, this.onComplete});

  static Future<void> show(BuildContext context,
      {required int seconds, VoidCallback? onComplete}) async {
    try {
      await Navigator.of(context).push(PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) =>
            OverlayTimer(seconds: seconds, onComplete: onComplete),
      ));
    } catch (_) {}
  }

  @override
  State<OverlayTimer> createState() => _OverlayTimerState();
}

class _OverlayTimerState extends State<OverlayTimer> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        _remaining -= 1;
        if (_remaining <= 0) {
          _timer?.cancel();
          widget.onComplete?.call();
          Navigator.of(context).pop();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('SOS Countdown',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Text('$_remaining',
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 120,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // cancel
                  _timer?.cancel();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('I Am Safe',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
