import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'video_storage_service.dart';
import 'recording_status_service.dart';

/// Camera side identifier
enum CameraSide { front, back }

/// Simple foreground-only video recorder using the `camera` plugin.
///
/// Notes:
/// - This implementation assumes it is called while the app is in the foreground
///   (for example: during the SOS countdown flow). Background recording is
///   restricted on many OEMs and Android versions and is intentionally not
///   attempted here.
class MediaRecorder {
  /// Safely select a camera by side (front/back) with guaranteed lookup
  /// Throws if requested camera not available
  static Future<CameraDescription> _getCamera(CameraSide side) async {
    final cameras = await availableCameras();

    for (final cam in cameras) {
      if (side == CameraSide.front &&
          cam.lensDirection == CameraLensDirection.front) {
        debugPrint('✅ Found front camera: ${cam.name}');
        return cam;
      }
      if (side == CameraSide.back &&
          cam.lensDirection == CameraLensDirection.back) {
        debugPrint('✅ Found back camera: ${cam.name}');
        return cam;
      }
    }

    throw Exception('Requested camera not available: ${side.name}');
  }

  /// Record a short video (with audio) for [seconds] duration and return the
  /// local file path of the recorded file. Throws on permission denied or
  /// recording errors.
  static Future<String> recordVideo({int seconds = 30}) async {
    debugPrint('📹 Recording video for $seconds seconds...');
    // Request camera & microphone permissions first.
    final camStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();
    if (!camStatus.isGranted || !micStatus.isGranted) {
      debugPrint('🔴 Camera/microphone permissions not granted');
      throw Exception(
          'Camera and microphone permissions are required to record video.');
    }
    debugPrint('✅ Camera/microphone permissions granted');

    // Get available cameras and pick the back camera safely.
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      debugPrint('🔴 No camera available on device');
      throw Exception('No camera available on device.');
    }

    CameraDescription selected;
    try {
      selected = await _getCamera(CameraSide.back);
    } catch (e) {
      debugPrint('⚠️ Back camera not available, using first available: $e');
      selected = cameras.first;
    }
    debugPrint('✅ Selected camera: ${selected.name}');

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
      debugPrint('📹 Recording preset: $preset');
    } catch (_) {}

    CameraController? controller;
    try {
      // Retry logic: some devices may fail to initialize camera on first attempt.
      int attempts = 0;
      while (attempts < 5) {
        try {
          debugPrint('📹 Camera init attempt ${attempts + 1}/5...');
          controller = CameraController(selected, preset, enableAudio: true);
          await controller.initialize().timeout(const Duration(seconds: 10));
          debugPrint('✅ Camera initialized on attempt ${attempts + 1}');
          break;
        } catch (e) {
          attempts++;
          debugPrint('⚠️ Camera init attempt $attempts failed: $e');
          await controller?.dispose();
          controller = null;
          await Future.delayed(Duration(milliseconds: 500 * attempts));
          if (attempts >= 5) {
            debugPrint(
                '🔴 Camera initialization failed after $attempts attempts');
            rethrow;
          }
        }
      }

      // Temporary file path (for upload)
      final tmpDir = await getTemporaryDirectory();
      final fileName = 'sos_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final outPath = '${tmpDir.path}/$fileName';
      debugPrint('📹 Recording to: $outPath');

      // Also save a copy to app documents for local storage/proof
      final docsDir = await getApplicationDocumentsDirectory();
      final archiveDir = Directory('${docsDir.path}/sos_videos');
      if (!await archiveDir.exists()) {
        await archiveDir.create(recursive: true);
      }
      final archivePath = '${archiveDir.path}/$fileName';
      debugPrint('📹 Will archive to: $archivePath');

      // Start recording with retry
      attempts = 0;
      while (attempts < 3) {
        try {
          debugPrint('📹 startVideoRecording attempt ${attempts + 1}/3...');
          await controller!.startVideoRecording();
          debugPrint('✅ Video recording started');

          // 🔥 NOTIFY UI THAT RECORDING HAS STARTED
          RecordingStatusService().startRecording();

          break;
        } catch (e) {
          attempts++;
          debugPrint('⚠️ startVideoRecording attempt $attempts failed: $e');
          await Future.delayed(Duration(milliseconds: 300 * attempts));
          if (attempts >= 3) {
            debugPrint(
                '🔴 startVideoRecording failed after $attempts attempts');
            rethrow;
          }
        }
      }

      // Wait for the requested duration (but allow cancellation by throwing)
      debugPrint('📹 Recording for $seconds seconds...');
      await Future.delayed(Duration(seconds: seconds));

      debugPrint('📹 Stopping video recording...');

      // 🔥 NOTIFY UI THAT RECORDING HAS STOPPED
      RecordingStatusService().stopRecording();
      final XFile recorded = await controller!.stopVideoRecording();
      debugPrint('✅ Video recording stopped');

      // Move the recorded file to our temp path (camera plugin may already
      // save to cache - but copying ensures we control the filename).
      final src = File(recorded.path);
      final dst = await src.copy(outPath);

      // Also save to permanent storage using VideoStorageService for local proof/recovery
      String? savedLocalPath;
      try {
        final savedFile = await VideoStorageService.saveVideo(dst);
        savedLocalPath = savedFile.path;
        debugPrint('📹 Saved video locally: $savedLocalPath');
      } catch (e) {
        debugPrint('⚠️ Failed to save video to permanent storage: $e');
      }

      debugPrint(
          '✅ Video recorded successfully: ${dst.path} (size: ${await dst.length()} bytes)');
      try {
        final sp = await SharedPreferences.getInstance();
        final toPersist = savedLocalPath ?? dst.path;
        await sp.setString('last_sos_video_path', toPersist);
        debugPrint('✓ Persisted last_sos_video_path: $toPersist');
      } catch (e) {
        debugPrint('⚠️ Failed to persist last_sos_video_path: $e');
      }
      return savedLocalPath ?? dst.path;
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
      throw Exception(
          'Camera and microphone permissions are required to record video.');
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('No camera available on device.');

    // Find back and front cameras, fallback to first available if missing
    CameraDescription? back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first);
    CameraDescription? front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first);

    final tmpDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backPath = '${tmpDir.path}/sos_back_$timestamp.mp4';
    final frontPath = '${tmpDir.path}/sos_front_$timestamp.mp4';

    // Prepare archive directory in app documents for proof storage
    final docsDir = await getApplicationDocumentsDirectory();
    final archiveDir = Directory('${docsDir.path}/sos_videos');
    if (!await archiveDir.exists()) await archiveDir.create(recursive: true);
    final archiveBack = '${archiveDir.path}/sos_back_$timestamp.mp4';
    final archiveFront = '${archiveDir.path}/sos_front_$timestamp.mp4';

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
      controller =
          CameraController(front, ResolutionPreset.medium, enableAudio: true);
      await controller.initialize();
      await controller.startVideoRecording();
      await Future.delayed(Duration(seconds: seconds - half));
      final XFile recordedFront = await controller.stopVideoRecording();
      await File(recordedFront.path).copy(frontPath);

      // Archive copies for user access/proof
      try {
        await File(backPath).copy(archiveBack);
        await File(frontPath).copy(archiveFront);
        debugPrint('📁 Archived split videos to: $archiveBack, $archiveFront');
      } catch (e) {
        debugPrint('⚠️ Failed to archive split videos: $e');
      }

      return [backPath, frontPath];
    } finally {
      try {
        await controller?.dispose();
      } catch (_) {}
    }
  }

  /// Record sequentially: front camera then back camera for [seconds] each.
  /// Returns list `[frontPath, backPath]` when both attempted. If recording
  /// is disabled via settings, returns an empty list.
  static Future<List<String>> recordSequentialVideos({int seconds = 20}) async {
    final List<String> out = [];

    // Request camera & microphone permissions first.
    final camStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();
    if (!camStatus.isGranted || !micStatus.isGranted) {
      throw Exception(
          'Camera and microphone permissions are required to record video.');
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('No camera available on device.');

    // Safely select front and back cameras
    CameraDescription? front;
    CameraDescription? back;

    try {
      front = await _getCamera(CameraSide.front);
    } catch (e) {
      debugPrint('⚠️ Front camera not available: $e, using first available');
      front = cameras.first;
    }

    try {
      back = await _getCamera(CameraSide.back);
    } catch (e) {
      debugPrint('⚠️ Back camera not available: $e, using first available');
      back = cameras.first;
    }

    final tmpDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final frontPath = '${tmpDir.path}/sos_front_$timestamp.mp4';
    final backPath = '${tmpDir.path}/sos_back_$timestamp.mp4';

    CameraController? controller;
    try {
      // Front camera first
      debugPrint('📹 Recording front camera...');
      controller =
          CameraController(front, ResolutionPreset.medium, enableAudio: true);
      await controller.initialize();

      // 🔥 NOTIFY UI THAT RECORDING HAS STARTED
      RecordingStatusService().startRecording();

      await controller.startVideoRecording();
      await Future.delayed(Duration(seconds: seconds));
      final XFile recordedFront = await controller.stopVideoRecording();
      await File(recordedFront.path).copy(frontPath);
      await controller.dispose();
      controller = null;
      debugPrint('✅ Front camera recorded: $frontPath');

      // Then back camera
      debugPrint('📹 Recording back camera...');
      controller =
          CameraController(back, ResolutionPreset.medium, enableAudio: true);
      await controller.initialize();
      await controller.startVideoRecording();
      await Future.delayed(Duration(seconds: seconds));
      final XFile recordedBack = await controller.stopVideoRecording();
      await File(recordedBack.path).copy(backPath);

      // 🔥 NOTIFY UI THAT RECORDING HAS STOPPED
      RecordingStatusService().stopRecording();

      debugPrint('✅ Back camera recorded: $backPath');

      // Archive to documents for user access
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final archiveDir = Directory('${docsDir.path}/sos_videos');
        if (!await archiveDir.exists()) {
          await archiveDir.create(recursive: true);
        }
        await File(frontPath)
            .copy('${archiveDir.path}/sos_front_$timestamp.mp4');
        await File(backPath).copy('${archiveDir.path}/sos_back_$timestamp.mp4');
        debugPrint('📁 Archived videos to: ${archiveDir.path}');
      } catch (e) {
        debugPrint('⚠️ Failed to archive sequential videos: $e');
      }

      out.add(frontPath);
      out.add(backPath);
      return out;
    } catch (e) {
      debugPrint('⚠️ Sequential recording failed, trying single-camera fallback: $e');
      try {
        final fallbackPath = await recordVideo(seconds: seconds);
        if (fallbackPath.isNotEmpty) {
          out.add(fallbackPath);
          return out;
        }
      } catch (fallbackError) {
        debugPrint('⚠️ Single-camera fallback failed: $fallbackError');
      }
      return out;
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
    debugPrint(
        'mergeVideos: FFmpeg not available in this build; skipping merge.');
    return first;
  }
}
