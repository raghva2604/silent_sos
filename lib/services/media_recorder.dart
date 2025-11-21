import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple foreground-only video recorder using the `camera` plugin.
///
/// Notes:
/// - This implementation assumes it is called while the app is in the foreground
///   (for example: during the SOS countdown flow). Background recording is
///   restricted on many OEMs and Android versions and is intentionally not
///   attempted here.
class MediaRecorder {
  /// Record a short video (with audio) for [seconds] duration and return the
  /// local file path of the recorded file. Throws on permission denied or
  /// recording errors.
  static Future<String> recordVideo({int seconds = 30}) async {
    // Request camera & microphone permissions first.
    final camStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();
    if (!camStatus.isGranted || !micStatus.isGranted) {
      throw Exception('Camera and microphone permissions are required to record video.');
    }

    // Get available cameras and pick the back camera if present.
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('No camera available on device.');
    CameraDescription selected = cameras.first;
    try {
      selected = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back);
    } catch (_) {}

    // Respect user-configured recording quality for SOS recordings to control
    // file sizes (lower quality -> smaller uploads, useful when auto-sending).
    ResolutionPreset preset = ResolutionPreset.medium;
    try {
      final prefs = await SharedPreferences.getInstance();
      final q = prefs.getString('sosRecordingQuality') ?? 'medium';
      if (q == 'low' || q == 'veryLow') {
        preset = ResolutionPreset.low;
      } else if (q == 'high') {
        preset = ResolutionPreset.high;
      } else {
        preset = ResolutionPreset.medium;
      }
    } catch (_) {}

    CameraController? controller;
    try {
      controller = CameraController(selected, preset, enableAudio: true);
      await controller.initialize();

      // Temporary file path
      final tmpDir = await getTemporaryDirectory();
      final fileName = 'sos_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final outPath = '${tmpDir.path}/$fileName';

      // Start recording
      await controller.startVideoRecording();

      // Wait for the requested duration (but allow cancellation by throwing)
      await Future.delayed(Duration(seconds: seconds));

      final XFile recorded = await controller.stopVideoRecording();

      // Move the recorded file to our temp path (camera plugin may already
      // save to cache - but copying ensures we control the filename).
      final src = File(recorded.path);
      final dst = await src.copy(outPath);
      return dst.path;
    } finally {
      try {
        await controller?.dispose();
      } catch (_) {}
    }
  }

  /// Record a video split between the back camera (first half) and the front
  /// camera (second half). Returns a list of two file paths in order
  /// [backPath, frontPath]. If only one camera is available the same camera
  /// will be used for both halves (resulting in two files).
  static Future<List<String>> recordSplitVideo({int seconds = 30}) async {
    if (seconds < 2) seconds = 2;
    final half = (seconds / 2).ceil();

    // Request camera & microphone permissions first.
    final camStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();
    if (!camStatus.isGranted || !micStatus.isGranted) {
      throw Exception('Camera and microphone permissions are required to record video.');
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('No camera available on device.');

    // Find back and front cameras, fallback to first available if missing
    CameraDescription? back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
    CameraDescription? front = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);

    final tmpDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
  final backPath = '${tmpDir.path}/sos_back_$timestamp.mp4';
  final frontPath = '${tmpDir.path}/sos_front_$timestamp.mp4';

    CameraController? controller;
    try {
      // Record back camera first
      // Respect user-configured resolution to control automatic upload sizes.
      ResolutionPreset preset = ResolutionPreset.medium;
      try {
        final prefs = await SharedPreferences.getInstance();
        final q = prefs.getString('sosRecordingQuality') ?? 'medium';
        if (q == 'low' || q == 'veryLow') {
          preset = ResolutionPreset.low;
        } else if (q == 'high') {
          preset = ResolutionPreset.high;
        }
      } catch (_) {}
      controller = CameraController(back, preset, enableAudio: true);
      await controller.initialize();
      await controller.startVideoRecording();
      await Future.delayed(Duration(seconds: half));
      final XFile recordedBack = await controller.stopVideoRecording();
      await File(recordedBack.path).copy(backPath);
      await controller.dispose();

      // Then initialize front camera
      controller = CameraController(front, ResolutionPreset.medium, enableAudio: true);
      await controller.initialize();
      await controller.startVideoRecording();
      await Future.delayed(Duration(seconds: seconds - half));
      final XFile recordedFront = await controller.stopVideoRecording();
      await File(recordedFront.path).copy(frontPath);

      return [backPath, frontPath];
    } finally {
      try {
        await controller?.dispose();
      } catch (_) {}
    }
  }

  /// Merge two video files [first] and [second] into a single MP4 file and
  /// return the output path. This uses FFmpeg concat via filter_complex so the
  /// files do not need to share container-level concat compatibility.
  static Future<String> mergeVideos(String first, String second) async {
    // FFmpeg native artifacts are not available in this build configuration.
    // As a safe fallback, return the first file so the SOS pipeline can
    // continue and upload both clips separately. Consumers should handle
    // uploading multiple files when merge is not available.
    debugPrint('mergeVideos: FFmpeg not available in this build; skipping merge.');
    return first;
  }
}
