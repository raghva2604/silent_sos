import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';

/// Banner showing that videos were recorded and need manual attachment
class AttachVideoBanner extends StatelessWidget {
  final List<String> videoPaths;
  final VoidCallback? onDismiss;

  const AttachVideoBanner({
    super.key,
    required this.videoPaths,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (videoPaths.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        border: Border.all(color: Colors.amber.shade700, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.videocam, color: Colors.amber),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '🎥 Safety videos recorded',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onDismiss,
                  iconSize: 20,
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Please attach the recorded video(s) in WhatsApp or SMS before sending:',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          const Text(
            '📁 Videos saved on device:',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87),
          ),
          const SizedBox(height: 6),
          ...videoPaths.asMap().entries.map((e) {
            final index = e.key;
            final path = e.value;
            final cameraLabel =
                index == 0 ? '📱 Front Camera' : '🔙 Back Camera';
            final fileName = File(path).uri.pathSegments.last;
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.videocam, size: 18, color: Colors.amber),
                title: Text(cameraLabel, style: const TextStyle(fontSize: 12)),
                subtitle: Text(fileName, style: const TextStyle(fontSize: 10)),
                onTap: () => OpenFile.open(path),
              ),
            );
          }),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('Open Videos Folder'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () {
              try {
                final videoDir = File(videoPaths.first).parent.path;
                OpenFile.open(videoDir);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not open folder: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
