import 'package:flutter/material.dart';

class UploadResultScreen extends StatefulWidget {
  const UploadResultScreen({super.key});

  @override
  State<UploadResultScreen> createState() => _UploadResultScreenState();
}

class _UploadResultScreenState extends State<UploadResultScreen> {
  String _result = 'No result yet';
  bool _loading = false;

  Future<void> _sendDummy() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _result = 'Severity: critical\n1. Apply direct pressure\n2. Call emergency services';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload & Result')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(height: 140, color: Colors.grey.shade900, child: const Center(child: Text('Upload / Result Mockup'))),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.camera_alt), label: const Text('Camera')),
                const SizedBox(width: 8),
                ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.photo), label: const Text('Gallery')),
                const SizedBox(width: 8),
                ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.mic), label: const Text('Audio')),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loading ? null : _sendDummy, child: _loading ? const CircularProgressIndicator() : const Text('Send to Silent SOS')),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_result),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
