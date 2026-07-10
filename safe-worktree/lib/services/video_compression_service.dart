import 'dart:io';
import 'package:video_compress/video_compress.dart';

/// Video Compression Service
/// Compresses video files before upload for faster transmission
class VideoCompressionService {
  /// Compress video file
  static Future<File?> compress(String videoPath) async {
    try {
      final info = await VideoCompress.compressVideo(
        videoPath,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
      );
      return info?.file;
    } catch (e) {
      print('⚠️ VideoCompressionService: Compression failed: $e');
      return null;
    }
  }
}
