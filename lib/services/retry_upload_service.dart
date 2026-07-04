import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Retry upload service for failed uploads
/// Automatically retries when connectivity is restored
class RetryUploadService {
  static const String _uploadQueueKey = 'sos_upload_queue';
  static int maxRetries = 5;

  /// Add a failed upload to retry queue
  static Future<void> queueFailedUpload({
    required String videoPath,
    required String recipientEmail,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_uploadQueueKey) ?? '[]';
      final queue =
          List<Map<String, dynamic>>.from(jsonDecode(queueJson) as List);

      queue.add({
        'videoPath': videoPath,
        'recipientEmail': recipientEmail,
        'metadata': metadata,
        'retries': 0,
        'queuedAt': DateTime.now().toIso8601String(),
      });

      await prefs.setString(_uploadQueueKey, jsonEncode(queue));
      debugPrint('📤 Queued failed upload: $videoPath → $recipientEmail');
    } catch (e) {
      debugPrint('❌ Error queueing upload: $e');
    }
  }

  /// Check connectivity and retry pending uploads
  static Future<void> retryPendingUploads({
    required Future<bool> Function(File, String, Map<String, dynamic>)
        uploadFunction,
  }) async {
    try {
      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      // connectivity_plus returns List<ConnectivityResult> in newer versions
      final hasConnection = connectivity.isNotEmpty &&
          !connectivity.contains(ConnectivityResult.none);

      if (!hasConnection) {
        debugPrint('⚠️ No internet connectivity; retries paused');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_uploadQueueKey) ?? '[]';
      var queue =
          List<Map<String, dynamic>>.from(jsonDecode(queueJson) as List);

      if (queue.isEmpty) {
        debugPrint('✅ No pending uploads');
        return;
      }

      debugPrint('🔄 Retrying ${queue.length} pending upload(s)...');

      final updatedQueue = <Map<String, dynamic>>[];

      for (final item in queue) {
        final videoPath = item['videoPath'] as String;
        final recipientEmail = item['recipientEmail'] as String;
        final metadata = item['metadata'] as Map<String, dynamic>;
        final retries = (item['retries'] as int?) ?? 0;

        // Check if video still exists
        if (!await File(videoPath).exists()) {
          debugPrint(
              '⚠️ Video no longer exists: $videoPath; removing from queue');
          continue; // Skip this item
        }

        // Check max retries
        if (retries >= maxRetries) {
          debugPrint('❌ Max retries reached for: $videoPath');
          continue; // Skip this item
        }

        try {
          // Attempt upload
          final success = await uploadFunction(
            File(videoPath),
            recipientEmail,
            metadata,
          );

          if (success) {
            debugPrint('✅ Retry successful: $videoPath → $recipientEmail');
            // Don't add back to queue; it succeeded
            continue;
          } else {
            // Retry failed; increment counter and re-queue
            item['retries'] = retries + 1;
            item['lastRetryAt'] = DateTime.now().toIso8601String();
            updatedQueue.add(item);
            debugPrint(
                '⚠️ Retry attempt ${retries + 1}/$maxRetries for: $videoPath');
          }
        } catch (e) {
          // Exception during upload; re-queue
          item['retries'] = retries + 1;
          item['lastRetryAt'] = DateTime.now().toIso8601String();
          item['lastError'] = e.toString();
          updatedQueue.add(item);
          debugPrint(
              '⚠️ Retry exception (attempt ${retries + 1}/$maxRetries): $e');
        }
      }

      // Save updated queue
      await prefs.setString(_uploadQueueKey, jsonEncode(updatedQueue));
      debugPrint(
          '📊 Upload queue updated: ${updatedQueue.length} items pending');
    } catch (e) {
      debugPrint('❌ Error retrying uploads: $e');
    }
  }

  /// Get current upload queue status
  static Future<Map<String, dynamic>> getQueueStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_uploadQueueKey) ?? '[]';
      final queue =
          List<Map<String, dynamic>>.from(jsonDecode(queueJson) as List);

      return {
        'totalPending': queue.length,
        'queue': queue,
      };
    } catch (e) {
      debugPrint('❌ Error getting queue status: $e');
      return {'totalPending': 0, 'queue': []};
    }
  }

  /// Clear upload queue (after successful batch upload)
  static Future<void> clearQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_uploadQueueKey);
      debugPrint('✅ Upload queue cleared');
    } catch (e) {
      debugPrint('❌ Error clearing queue: $e');
    }
  }

  /// Remove a specific item from queue (if manually confirmed uploaded)
  static Future<void> removeFromQueue(String videoPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_uploadQueueKey) ?? '[]';
      var queue =
          List<Map<String, dynamic>>.from(jsonDecode(queueJson) as List);

      queue.removeWhere((item) => (item['videoPath'] as String) == videoPath);

      await prefs.setString(_uploadQueueKey, jsonEncode(queue));
      debugPrint('✅ Removed from queue: $videoPath');
    } catch (e) {
      debugPrint('❌ Error removing from queue: $e');
    }
  }
}
