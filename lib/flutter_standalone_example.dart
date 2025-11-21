// Single-file Flutter example: recorder + image picker + send to backend
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'services/api.dart';
import 'package:silent_sos/config.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext c) => const MaterialApp(home: HomePage());
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final recorder = Record();
  String status = '';
  File? lastAudio;
  File? lastImage;

  final Api api = Api(Config.baseUrlEmulator);

  Future<String> _getFilePath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/recorded.wav';
  }

  Future<void> start() async {
    if (await recorder.hasPermission()) {
      final p = await _getFilePath();
      await recorder.start(path: p, encoder: AudioEncoder.wav, bitRate: 128000, samplingRate: 16000);
      setState(() => status = 'Recording...');
    } else {
      setState(() => status = 'No mic permission');
    }
  }

  Future<void> stop() async {
    final p = await recorder.stop();
    if (p != null) {
      setState(() {
        lastAudio = File(p);
        status = 'Stopped. File: ${lastAudio!.path}';
      });
    }
  }

  Future<void> pickImage() async {
    final XFile? photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
    if (photo == null) return;
    setState(() {
      lastImage = File(photo.path);
      status = 'Picked image: ${lastImage!.path}';
    });
  }

  Future<void> send() async {
    if (lastAudio == null) {
      setState(() => status = 'No audio');
      return;
    }
    setState(() => status = 'Uploading...');
    try {
      final res = await api.transcribeAndAnalyzeMultipart(audioFile: lastAudio!, imageFile: lastImage);
      setState(() => status = 'Transcript: ${res['transcript'] ?? res}');
    } catch (e) {
      setState(() => status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: const Text('Silent SOS — Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text(status),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            ElevatedButton(onPressed: start, child: const Text('Record')),
            ElevatedButton(onPressed: stop, child: const Text('Stop')),
            ElevatedButton(onPressed: pickImage, child: const Text('Pick Image')),
            ElevatedButton(onPressed: send, child: const Text('Send')),
          ])
        ]),
      ),
    );
  }
}
