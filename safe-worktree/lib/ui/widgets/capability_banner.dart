import 'package:flutter/material.dart';
import '../../core/platform_capabilities.dart';

class CapabilityBanner extends StatelessWidget {
  const CapabilityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    String message;
    IconData icon;
    Color bgColor;

    if (PlatformCapabilities.isAndroid) {
      message = "✅ Full automatic protection enabled (Fall + Voice)";
      icon = Icons.security;
      bgColor = Colors.green[900] ?? Colors.green;
    } else if (PlatformCapabilities.isIOS) {
      message = "⚠️ Limited background protection (iOS restrictions)";
      icon = Icons.info_outline;
      bgColor = Colors.orange[900] ?? Colors.orange;
    } else {
      // For other platforms, hide the banner to avoid showing "Manual SOS"
      message = '';
      icon = Icons.info_outline;
      bgColor = Colors.transparent;
    }

    if (message.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
