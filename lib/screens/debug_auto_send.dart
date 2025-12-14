import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/server_upload.dart' as server_upload;
import '../services/foreground_service.dart' as fg;
import 'package:flutter/services.dart';
import '../services/native_callbacks.dart' as native_callbacks;
import 'medical_chat.dart';

class DebugAutoSendScreen extends StatefulWidget {
  const DebugAutoSendScreen({super.key});

  @override
  State<DebugAutoSendScreen> createState() => _DebugAutoSendScreenState();
}

class _DebugAutoSendScreenState extends State<DebugAutoSendScreen> {
  static const MethodChannel _channel = MethodChannel('silent_sos/foreground');
  StreamSubscription<Map<String, dynamic>>? _sub;
  String _log = '';
  final List<String> _lastUploadedUrls = [];
  Map<String, dynamic>? _lastDebugResult;
  final TextEditingController _symptomsController = TextEditingController();
  final TextEditingController _spo2Controller = TextEditingController();
  final TextEditingController _pulseController = TextEditingController();
  final TextEditingController _respRateController = TextEditingController();
  Map<String, dynamic>? _triageResult;

  @override
  void initState() {
    super.initState();
    _sub = native_callbacks.debugAutoSendStream.listen((map) {
      setState(() {
        _log = 'Received debugAutoSendResult:\n${map.toString()}';
      });
    });
    _loadPrefs();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  final TextEditingController _shortUrlController = TextEditingController();
  final TextEditingController _serverBaseController = TextEditingController(text: 'http://10.0.2.2:3000');
  bool _autoSendOnStart = false;
  bool _autoSendOptIn = false;
  String _smsPermissionStatus = '';

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('last_tracking_shorturl') ?? '';
      final a = prefs.getBool('auto_send_on_start') ?? false;
      final opt = prefs.getBool('auto_send_opt_in') ?? false;
      setState(() {
        _shortUrlController.text = s;
        _autoSendOnStart = a;
        _autoSendOptIn = opt;
      });
    } catch (_) {}
  }

  Future<void> _saveShortUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_tracking_shorturl', _shortUrlController.text.trim());
      setState(() {
        _log = 'Saved short URL.';
      });
    } catch (e) {
      setState(() { _log = 'Failed to save short url: $e'; });
    }
  }

  Future<void> _setAutoSendPref(bool v) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_send_on_start', v);
      setState(() { _autoSendOnStart = v; _log = 'auto_send_on_start=$v'; });
    } catch (e) {
      setState(() { _log = 'Failed to set auto_send_on_start: $e'; });
    }
  }

  Future<void> _setAutoSendOptIn(bool v) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_send_opt_in', v);
      setState(() { _autoSendOptIn = v; _log = 'auto_send_opt_in=$v'; });
    } catch (e) {
      setState(() { _log = 'Failed to set auto_send_opt_in: $e'; });
    }
  }

  Future<void> _requestSmsPermission() async {
    try {
      final status = await Permission.sms.request();
      setState(() { _log = 'SEND_SMS permission: ${status.toString()}'; _smsPermissionStatus = status.toString(); });
    } catch (e) {
      setState(() { _log = 'Permission request failed: $e'; });
    }
  }

  Future<void> _sendTestMms() async {
    setState(() { _log = 'Starting test sendMms (scaffold)...'; });
    try {
      final prefs = await SharedPreferences.getInstance();
  final list = prefs.getStringList('selected_contacts') ?? <String>[];
  final to = list.isNotEmpty ? list.first : null;
      if (to == null) {
        setState(() { _log = 'No selected_contacts set; cannot send test MMS'; });
        return;
      }
  final args = {"to": to, "body": "Test MMS scaffold message", "mediaPaths": ["https://example.com/test.jpg"]};
  final res = await _channel.invokeMethod('sendMms', args);
  setState(() { _log = 'sendMms result: ${res.toString()}'; });
    } catch (e) {
      setState(() { _log = 'sendMms invocation failed: $e'; });
    }
  }

  Future<void> _runDebug() async {
    setState(() {
      _log = 'Starting debugAutoSend...';
    });
    try {
      await _channel.invokeMethod('debugAutoSend', {});
      setState(() {
        _log += '\nInvoked native debugAutoSend, awaiting result...';
      });
    } catch (e) {
      setState(() {
        _log = 'Failed to invoke debugAutoSend: $e';
      });
    }
  }

  Future<void> _pickFilesAndSend() async {
    setState(() { _log = 'Picking files...'; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('selected_contacts') ?? <String>[];
      final to = list.isNotEmpty ? list.first : null;
      if (to == null) {
        setState(() { _log = 'No selected_contacts set; cannot send test MMS'; });
        return;
      }

      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null || result.files.isEmpty) {
        setState(() { _log = 'No files selected'; });
        return;
      }

      // Convert picked files to File objects
      final files = <File>[];
      for (final pf in result.files) {
        if (pf.path != null) files.add(File(pf.path!));
      }
      setState(() { _log = 'Attempting native sendMms for ${files.length} files...'; });

      // Try native MMS first by passing local file paths as mediaPaths
      final mediaPaths = files.map((f) => f.path).toList();
      final args = {"to": to, "body": "SOS with attachments", "mediaPaths": mediaPaths};
      try {
        final res = await _channel.invokeMethod('sendMms', args);
        setState(() { _log = 'Native sendMms result: ${res.toString()}'; });
        // If native indicates success, we're done. If not, fall through to upload fallback.
        if (res is Map && (res['success'] == true || (res['method'] != null && res['method'] == 'sendMultimediaMessage'))) {
          return;
        }
      } catch (e) {
        setState(() { _log += '\nNative sendMms threw: $e'; });
      }

      // Fallback: upload files to server and send SMS with returned short URLs
      setState(() { _log += '\nNative MMS failed or not available — uploading files to server...'; });
      final serverBase = _serverBaseController.text.trim();
      final urls = await server_upload.uploadFilesToServer(files, serverBase: serverBase);
      setState(() { _log += '\nUploaded ${urls.length} files — sending SMS with links...'; });

      // Ask server-side triage for a brief triage shortUrl to include in the SMS (optional)
      Map<String, dynamic>? triage;
        try {
          final triageUri = Uri.parse('$serverBase/ai/triage');
          final payload = {
            'context': {
              'symptoms': _symptomsController.text.trim(),
              'vitals': {
                'pulse': int.tryParse(_pulseController.text),
                'spo2': double.tryParse(_spo2Controller.text),
                'respRate': int.tryParse(_respRateController.text),
              }
            },
            'attachments': urls,
            'consent': true
          };
          final tr = await http.post(triageUri, headers: { 'Content-Type': 'application/json' }, body: json.encode(payload)).timeout(Duration(seconds: 20));
          if (tr.statusCode == 200) triage = json.decode(tr.body) as Map<String, dynamic>?;
          setState(() { _log += '\nServer triage status: ${tr.statusCode}'; });
        } catch (e) {
          setState(() { _log += '\nServer triage call failed: $e'; });
        }

      final body = StringBuffer();
      body.writeln('🆘 SILENTSOS: Media attached');
      for (final u in urls) {
        body.writeln(u);
      }
      if (triage != null && triage['shortUrl'] != null) {
        body.writeln('\nTriage: ${triage['shortUrl']}');
      }

      final smsRes = await fg.ForegroundService.sendSmsDetailed(to, body.toString());
      setState(() { _log += '\nSMS send result: ${smsRes.toString()}'; });
      // Persist uploaded media links so native debug flow can include them later
      try {
        await _channel.invokeMethod('persistLastUploadedMedia', urls);
      } catch (_) {}
    } catch (e) {
      setState(() { _log = 'File pick/send failed: $e'; });
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        setState(() { _log += '\nFailed to open $url'; });
      }
    } catch (e) {
      setState(() { _log += '\nopenUrl error: $e'; });
    }
  }

  Future<void> _copyToClipboard(String s) async {
    try {
      await Clipboard.setData(ClipboardData(text: s));
      setState(() { _log += '\nCopied to clipboard: $s'; });
    } catch (e) {
      setState(() { _log += '\nClipboard error: $e'; });
    }
  }

  Future<void> _resendUrlSms(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('selected_contacts') ?? <String>[];
      final to = list.isNotEmpty ? list.first : null;
      if (to == null) {
        setState(() { _log += '\nNo selected_contacts set; cannot resend SMS'; });
        return;
      }
      final body = 'Shared media: $url';
      final res = await fg.ForegroundService.sendSmsDetailed(to, body);
      setState(() { _log += '\nResend SMS result for $url: ${res.toString()}'; });
    } catch (e) {
      setState(() { _log += '\nResend error: $e'; });
    }
  }

  // On-device red-flag checks removed from UI; server triage remains available via the 'Call server triage' button.
  
  // Call server-side triage proxy (POST /ai/triage)
  Future<void> _callServerTriage() async {
    try {
      final serverBase = _serverBaseController.text.trim();
      final uri = Uri.parse('$serverBase/ai/triage');
      final symptoms = _symptomsController.text.trim();
      final vitals = <String, dynamic>{};
      if (_spo2Controller.text.isNotEmpty) vitals['spo2'] = double.tryParse(_spo2Controller.text);
      if (_pulseController.text.isNotEmpty) vitals['pulse'] = int.tryParse(_pulseController.text);
      if (_respRateController.text.isNotEmpty) vitals['respRate'] = int.tryParse(_respRateController.text);
      final payload = { 'context': { 'symptoms': symptoms, 'vitals': vitals }, 'consent': true };
      setState(() { _log += '\nCalling server triage...'; });
      final r = await http.post(uri, headers: { 'Content-Type': 'application/json' }, body: json.encode(payload)).timeout(Duration(seconds: 20));
      if (r.statusCode == 200) {
        final j = json.decode(r.body);
        setState(() { _triageResult = j; _log += '\nServer triage: ${j['severity'] ?? 'unknown'}'; });
      } else {
        setState(() { _log += '\nServer triage failed: ${r.statusCode}'; });
      }
    } catch (e) {
      setState(() { _log += '\nServer triage error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug: Auto-send')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This screen triggers the native debug auto-send flow and shows the native result map.\n\nNote: Enabling "Opt-in to auto-send at boot" gives explicit consent so the app will automatically attempt sending at boot (no additional native_auto_send flag required). Always ensure SEND_SMS permission is granted before enabling auto-send on a real device.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _shortUrlController,
              decoration: const InputDecoration(labelText: 'Short tracking URL'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              ElevatedButton(onPressed: _saveShortUrl, child: const Text('Save URL')),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _requestSmsPermission, child: const Text('Request SEND_SMS')),
            ]),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('Auto-send on start')),
                Switch(value: _autoSendOnStart, onChanged: (v) => _setAutoSendPref(v)),
              ],
            ),
            Row(
              children: [
                const Expanded(child: Text('Opt-in to auto-send at boot (consent)')),
                Switch(value: _autoSendOptIn, onChanged: (v) => _setAutoSendOptIn(v)),
              ],
            ),
            Row(children: [Text('SEND_SMS status: $_smsPermissionStatus')]),
            const SizedBox(height: 8),
            TextField(
              controller: _serverBaseController,
              decoration: const InputDecoration(labelText: 'Server base (for uploads)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _pickFilesAndSend, child: const Text('Pick files and send (native MMS then fallback)')),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _runDebug,
              child: const Text('Run debugAutoSend'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _sendTestMms, child: const Text('Send test MMS (scaffold)')),
            const SizedBox(height: 12),

            // Uploaded short URLs (interactive)
            if (_lastUploadedUrls.isNotEmpty) ...[
              const Text('Uploaded short URLs:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._lastUploadedUrls.map((u) => Card(
                    child: ListTile(
                      title: Text(u, style: const TextStyle(fontSize: 12)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.copy), onPressed: () => _copyToClipboard(u)),
                        IconButton(icon: const Icon(Icons.open_in_new), onPressed: () => _openUrl(u)),
                        IconButton(icon: const Icon(Icons.send), onPressed: () => _resendUrlSms(u)),
                      ]),
                    ),
                  )),
              const SizedBox(height: 12),
            ],

            // Native debug diagnostics
            if (_lastDebugResult != null) ...[
              const Text('Native debug diagnostics:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_lastDebugResult!['results'] is List) ...[
                ...((_lastDebugResult!['results'] as List).map((r) {
                  final rec = r is Map ? Map<String, dynamic>.from(r.cast<String, dynamic>()) : null;
                  final recipient = rec != null ? (rec['recipient'] ?? 'unknown') : 'unknown';
                  final overall = rec != null ? (rec['overallSuccess'] ?? false) : false;
                  final attempts = rec != null ? (rec['attempts'] as List? ?? []) : [];
                  return Card(
                    child: ExpansionTile(
                      title: Text('$recipient — ${overall ? 'OK' : 'FAIL'}'),
                      children: attempts.map<Widget>((a) {
                        final am = a is Map ? Map<String, dynamic>.from(a.cast<String, dynamic>()) : {};
                        return ListTile(
                          title: Text('Attempt ${am['attempt'] ?? '?'} — success: ${am['success'] ?? false}'),
                          subtitle: Text('timedOut: ${am['timedOut'] ?? false} error: ${am['error'] ?? ''}'),
                        );
                      }).toList(),
                    ),
                  );
                }).toList()),
              ] else ...[
                SelectableText(_lastDebugResult.toString()),
              ],
              const SizedBox(height: 12),
            ],

            // Quick access: server triage and AI Assistant
            Row(children: [
              ElevatedButton(onPressed: _callServerTriage, child: const Text('Call server triage')),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicalChatScreen())), child: const Text('Open AI Assistant')),
              const SizedBox(width: 8),
              if (_triageResult != null) ElevatedButton(onPressed: () async {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final list = prefs.getStringList('selected_contacts') ?? <String>[];
                  final to = list.isNotEmpty ? list.first : null;
                  if (to == null) { setState(() { _log += '\nNo selected_contacts set; cannot send triage SMS'; }); return; }
                  var body = _triageResult!['brief_message_for_contacts'] ?? 'Triage info';
                  if (_triageResult!['shortUrl'] != null) body = '$body\n${_triageResult!['shortUrl'] as String}';
                  final res = await fg.ForegroundService.sendSmsDetailed(to, body);
                  setState(() { _log += '\nTriage SMS result: ${res.toString()}'; });
                } catch (e) { setState(() { _log += '\nTriage send error: $e'; }); }
              }, child: const Text('Send triage SMS')),
            ]),
            if (_triageResult != null) ...[
              const SizedBox(height: 8),
              Text('Severity: ${_triageResult!['severity']}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              if ((_triageResult!['reasons'] as List?)?.isNotEmpty ?? false) ...[
                const Text('Reasons:'),
                ...((_triageResult!['reasons'] as List).map((r) => Text('- $r'))),
              ],
              const SizedBox(height: 4),
              const Text('Actions:'),
              ...((_triageResult!['immediate_actions'] as List).map((a) => Text('- $a'))),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(_log),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
