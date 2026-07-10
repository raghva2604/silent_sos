import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

/// Local video storage service
/// Saves recorded videos to device storage regardless of network status
class VideoStorageService {
  static const String _sosVideoDirName = 'sos_videos';

  /// Get the SOS videos directory, creating it if needed
  static Future<Directory> getSosVideoDir() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final sosDir = Directory('${dir.path}/$_sosVideoDirName');

      if (!await sosDir.exists()) {
        await sosDir.create(recursive: true);
        debugPrint('✅ Created SOS videos directory: ${sosDir.path}');
      }

      return sosDir;
    } catch (e) {
      debugPrint('❌ Error getting SOS video directory: $e');
      rethrow;
    }
  }

  /// Save a temporary video file to permanent storage
  /// Returns the saved file path
  static Future<File> saveVideo(File tempVideoFile) async {
    try {
      if (!await tempVideoFile.exists()) {
        throw Exception(
            'Temp video file does not exist: ${tempVideoFile.path}');
      }

      final sosDir = await getSosVideoDir();
      final fileName = 'sos_${const Uuid().v4()}.mp4';
      final savedFilePath = '${sosDir.path}/$fileName';

      final savedFile = await tempVideoFile.copy(savedFilePath);

      debugPrint(
          '✅ Video saved locally: $savedFilePath (${await savedFile.length()} bytes)');

      return savedFile;
    } catch (e) {
      debugPrint('❌ Error saving video locally: $e');
      rethrow;
    }
  }

  /// Add a video from native background recording (called from MethodChannel)
  static Future<void> addFromNative(String nativeVideoPath) async {
    try {
      final src = File(nativeVideoPath);
      if (!await src.exists()) {
        debugPrint('⚠️ Native video not found: $nativeVideoPath');
        return;
      }

      // Copy native file into our managed sos_videos directory so Flutter
      // consistently owns and can list it. Use RecordingManager-style storage
      // semantics to avoid accidental deletions by native processes.
      final sosDir = await getSosVideoDir();
      final dest = File('${sosDir.path}/${src.uri.pathSegments.last}');
      try {
        final copied = await src.copy(dest.path);
        debugPrint(
            '✅ Native video copied into app storage: ${copied.path} (${await copied.length()} bytes)');

        // Persist last paths for SOSservice to pick up
        try {
          final prefs = await SharedPreferences.getInstance();
          final existing = prefs.getString('last_sos_video_path');
          if (existing == null || existing.isEmpty) {
            await prefs.setString('last_sos_video_path', copied.path);
          } else {
            await prefs.setString('last_sos_video_path_secondary', copied.path);
          }
        } catch (e) {
          debugPrint('⚠️ Failed to persist native video path: $e');
        }
      } catch (e) {
        debugPrint('⚠️ Failed to copy native video into app storage: $e');
      }
    } catch (e) {
      debugPrint('❌ Error registering native video: $e');
    }
  }

  /// Get all locally saved SOS videos
  static Future<List<File>> getAllSosVideos() async {
    try {
      final sosDir = await getSosVideoDir();

      // Also include archive directory used by RecordingManager/media_recorder
      final appDoc = await getApplicationDocumentsDirectory();
      final archiveDir = Directory('${appDoc.path}/sos_videos');

      final List<File> videos = [];

      if (await sosDir.exists()) {
        videos.addAll(sosDir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.mp4'))
            .toList());
      }

      if (await archiveDir.exists()) {
        videos.addAll(archiveDir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.mp4'))
            .toList());
      }

      // Deduplicate by path
      final unique = {for (var v in videos) v.path: v}.values.toList();
      debugPrint(
          '📁 Found ${unique.length} SOS videos in storage (sos_videos)');
      return unique;
    } catch (e) {
      debugPrint('❌ Error getting SOS videos: $e');
      return [];
    }
  }

  /// Delete a specific SOS video (call after successful upload)
  static Future<void> deleteVideo(File videoFile) async {
    try {
      if (await videoFile.exists()) {
        await videoFile.delete();
        debugPrint('🗑️ Deleted video: ${videoFile.path}');
      }
    } catch (e) {
      debugPrint('⚠️ Error deleting video: $e');
    }
  }

  /// Get total size of all SOS videos
  static Future<int> getTotalVideoSize() async {
    try {
      final videos = await getAllSosVideos();
      int totalSize = 0;

      for (final video in videos) {
        if (await video.exists()) {
          totalSize += await video.length();
        }
      }

      debugPrint('📊 Total SOS video size: ${totalSize ~/ 1024} KB');
      return totalSize;
    } catch (e) {
      debugPrint('⚠️ Error calculating video size: $e');
      return 0;
    }
  }

  /// Clear all SOS videos (manual cleanup)
  static Future<void> clearAllVideos() async {
    try {
      final videos = await getAllSosVideos();

      for (final video in videos) {
        await deleteVideo(video);
      }

      debugPrint('✅ Cleared all SOS videos');
    } catch (e) {
      debugPrint('❌ Error clearing videos: $e');
    }
  }
}
