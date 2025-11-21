import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/foreground_service.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final _phoneController = TextEditingController();
  final _bodyController = TextEditingController(text: 'Test silent send from SilentSOS');
  String _status = '';
  Map<String, dynamic>? _lastResult;

  @override
  void dispose() {
    _phoneController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.sms.status;
    setState(() {
      _status = 'SMS permission: ${status.toString()}';
    });
  }

  Future<void> _requestPermission() async {
    final result = await Permission.sms.request();
    setState(() {
      _status = 'Requested SMS permission: ${result.toString()}';
    });
  }

  Future<void> _testSend() async {
    setState(() {
      _status = 'Attempting silent send...';
      _lastResult = null;
    });
    final to = _phoneController.text.trim();
    final body = _bodyController.text;
    if (to.isEmpty) {
      setState(() {
        _status = 'Please provide a phone number to test.';
      });
      return;
    }
    final res = await ForegroundService.sendSmsDetailed(to, body);
    setState(() {
      _lastResult = res;
      _status = 'Done. Success=${res?['success'] ?? false}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('SMS Silent Send Diagnostics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number (E.164 recommended)') ,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bodyController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Message body') ,
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _checkPermission, child: const Text('Check SMS permission')),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _requestPermission, child: const Text('Request SMS permission')),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _testSend, child: const Text('Attempt silent send (diagnostic)')),
            const SizedBox(height: 12),
            Text(_status),
            const SizedBox(height: 12),
            const Text('Last result (raw):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(_lastResult != null ? _lastResult.toString() : 'No result yet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
