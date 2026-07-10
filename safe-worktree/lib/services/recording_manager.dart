import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart' show debugPrint;

/// Local video & audio recording manager.
/// Saves files to device storage with proper organization and cleanup.
class RecordingManager {
  static final RecordingManager _instance = RecordingManager._();

  factory RecordingManager() => _instance;

  RecordingManager._();

  /// Get the SOS recordings directory, creating it if needed
  Future<Directory> _getRecordingDir() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final recordingDir = Directory(p.join(appDocDir.path, 'sos_videos'));
      if (!await recordingDir.exists()) {
        await recordingDir.create(recursive: true);
        debugPrint('✓ Created recording directory: ${recordingDir.path}');
      }
      return recordingDir;
    } catch (e) {
      debugPrint('⚠️ Failed to get recording directory: $e');
      rethrow;
    }
  }

  /// Save video file to local storage and return the path
  Future<String> saveVideoFile(File sourceFile,
      {String? prefix = 'sos_video'}) async {
    try {
      final recordingDir = await _getRecordingDir();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${prefix}_$timestamp.mp4';
      final destFile = File(p.join(recordingDir.path, fileName));

      // Copy the file to the recording directory
      await sourceFile.copy(destFile.path);
      debugPrint(
          '✓ Video saved: ${destFile.path} (${destFile.lengthSync()} bytes)');
      return destFile.path;
    } catch (e) {
      debugPrint('✗ Failed to save video file: $e');
      rethrow;
    }
  }

  /// Save audio file to local storage and return the path
  Future<String> saveAudioFile(File sourceFile,
      {String? prefix = 'sos_audio'}) async {
    try {
      final recordingDir = await _getRecordingDir();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${prefix}_$timestamp.aac';
      final destFile = File(p.join(recordingDir.path, fileName));

      await sourceFile.copy(destFile.path);
      debugPrint(
          '✓ Audio saved: ${destFile.path} (${destFile.lengthSync()} bytes)');
      return destFile.path;
    } catch (e) {
      debugPrint('✗ Failed to save audio file: $e');
      rethrow;
    }
  }

  /// List all saved SOS recordings
  Future<List<File>> listRecordings() async {
    try {
      final recordingDir = await _getRecordingDir();
      return recordingDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.mp4') || f.path.endsWith('.aac'))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Failed to list recordings: $e');
      return [];
    }
  }

  /// Delete a recording file
  Future<void> deleteRecording(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('✓ Deleted recording: $filePath');
      }
    } catch (e) {
      debugPrint('✗ Failed to delete recording: $e');
    }
  }

  /// Clean up old recordings older than daysOld
  Future<int> cleanupOldRecordings({int daysOld = 7}) async {
    try {
      final recordingDir = await _getRecordingDir();
      final cutoffTime = DateTime.now().subtract(Duration(days: daysOld));
      int deletedCount = 0;

      for (final file in recordingDir.listSync().whereType<File>()) {
        final stat = file.statSync();
        if (stat.modified.isBefore(cutoffTime)) {
          await file.delete();
          deletedCount++;
          debugPrint('✓ Cleaned up old recording: ${file.path}');
        }
      }

      if (deletedCount > 0) {
        debugPrint('✓ Cleanup completed: deleted $deletedCount old recordings');
      }
      return deletedCount;
    } catch (e) {
      debugPrint('⚠️ Cleanup failed: $e');
      return 0;
    }
  }

  /// Get total size of all recordings in bytes
  Future<int> getTotalRecordingSize() async {
    try {
      final recordingDir = await _getRecordingDir();
      int totalSize = 0;
      for (final file in recordingDir.listSync().whereType<File>()) {
        totalSize += file.lengthSync();
      }
      return totalSize;
    } catch (e) {
      debugPrint('⚠️ Failed to calculate recording size: $e');
      return 0;
    }
  }
}
