import 'dart:io';
import 'package:flutter/material.dart';
import '../services/video_storage_service.dart';
import '../services/retry_upload_service.dart';
// DISABLED Phase 1: import '../services/sos_service.dart';
import 'video_player_screen.dart';

class SavedVideosScreen extends StatefulWidget {
  const SavedVideosScreen({super.key});

  @override
  State<SavedVideosScreen> createState() => _SavedVideosScreenState();
}

class _SavedVideosScreenState extends State<SavedVideosScreen> {
  List<File> _videos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() => _loading = true);
    final vids = await VideoStorageService.getAllSosVideos();
    setState(() {
      _videos = vids;
      _loading = false;
    });
  }

  Future<void> _play(File f) async {
    try {
      if (!await f.exists()) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('File not found: ${f.path}')));
        return;
      }

      // Open in-app video player for reliable playback across devices
      Navigator.of(context).push(
          MaterialPageRoute(builder: (ctx) => VideoPlayerScreen(path: f.path)));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error opening video: $e')));
    }
  }

  Future<void> _delete(File f) async {
    await VideoStorageService.deleteVideo(f);
    await RetryUploadService.removeFromQueue(f.path);
    await _loadVideos();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Deleted video')));
  }

  Future<void> _upload(File f) async {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Attempting upload...')));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Videos saved locally and ready to attach to SOS')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Videos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _videos.isEmpty
              ? const Center(child: Text('No saved videos'))
              : ListView.builder(
                  itemCount: _videos.length,
                  itemBuilder: (ctx, i) {
                    final f = _videos[i];
                    return ListTile(
                      title: Text(f.path.split('/').last),
                      subtitle: Text('${(f.lengthSync() / 1024).round()} KB'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              icon: const Icon(Icons.play_arrow),
                              onPressed: () => _play(f)),
                          IconButton(
                              icon: const Icon(Icons.cloud_upload),
                              onPressed: () => _upload(f)),
                          IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _delete(f)),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
