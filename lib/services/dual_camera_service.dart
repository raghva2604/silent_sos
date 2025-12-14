import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
// dart:io not required here

/// Dual camera (front & back) recording service for SOS alerts
class DualCameraService {
  CameraController? _frontController;
  CameraController? _backController;
  
  bool _isFrontRecording = false;
  bool _isBackRecording = false;

  /// Get list of available cameras
  static Future<List<CameraDescription>> getCameras() async {
    return await availableCameras();
  }

  /// Initialize both front and back cameras
  Future<bool> initializeCameras() async {
    try {
      final cameras = await getCameras();
      
      // Find front and back cameras
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.last,
      );

      _frontController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      _backController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await Future.wait([
        _frontController!.initialize(),
        _backController!.initialize(),
      ]);

      debugPrint('Dual camera initialized successfully');
      return true;
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      return false;
    }
  }

  /// Start recording both cameras
  Future<Map<String, String>> startDualRecording() async {
    try {
      if (_frontController == null || _backController == null) {
        throw Exception('Cameras not initialized');
      }

      final appDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final frontVideoPath = '${appDir.path}/sos_front_$timestamp.mp4';
      final backVideoPath = '${appDir.path}/sos_back_$timestamp.mp4';

      await _frontController!.startVideoRecording();
      await _backController!.startVideoRecording();

      _isFrontRecording = true;
      _isBackRecording = true;

      debugPrint('Started dual camera recording');
      return {
        'front': frontVideoPath,
        'back': backVideoPath,
      };
    } catch (e) {
      debugPrint('Start recording error: $e');
      return {};
    }
  }

  /// Stop recording both cameras and return video files
  Future<Map<String, String>> stopDualRecording() async {
    try {
      if (_frontController == null || _backController == null) {
        return {};
      }

      final frontVideo = await _frontController!.stopVideoRecording();
      final backVideo = await _backController!.stopVideoRecording();

      _isFrontRecording = false;
      _isBackRecording = false;

      debugPrint('Stopped dual camera recording');
      return {
        'front': frontVideo.path,
        'back': backVideo.path,
      };
    } catch (e) {
      debugPrint('Stop recording error: $e');
      return {};
    }
  }

  /// Check recording status
  bool get isFrontRecording => _isFrontRecording;
  bool get isBackRecording => _isBackRecording;
  bool get isDualRecording => _isFrontRecording && _isBackRecording;

  /// Get camera preview widget for front camera
  Widget? getFrontCameraPreview() {
    if (_frontController == null || !_frontController!.value.isInitialized) {
      return null;
    }
    return CameraPreview(_frontController!);
  }

  /// Get camera preview widget for back camera
  Widget? getBackCameraPreview() {
    if (_backController == null || !_backController!.value.isInitialized) {
      return null;
    }
    return CameraPreview(_backController!);
  }

  /// Take a snapshot from front camera
  Future<String?> takeFrontSnapshot() async {
    try {
      if (_frontController == null) return null;
      final image = await _frontController!.takePicture();
      return image.path;
    } catch (e) {
      debugPrint('Front snapshot error: $e');
      return null;
    }
  }

  /// Take a snapshot from back camera
  Future<String?> takeBackSnapshot() async {
    try {
      if (_backController == null) return null;
      final image = await _backController!.takePicture();
      return image.path;
    } catch (e) {
      debugPrint('Back snapshot error: $e');
      return null;
    }
  }

  /// Release camera resources
  Future<void> dispose() async {
    try {
      if (_isFrontRecording) await _frontController!.stopVideoRecording();
      if (_isBackRecording) await _backController!.stopVideoRecording();
      
      await _frontController?.dispose();
      await _backController?.dispose();
      
      _frontController = null;
      _backController = null;
      debugPrint('Camera resources released');
    } catch (e) {
      debugPrint('Dispose error: $e');
    }
  }
}
