import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/text_classifier.dart';
import '../config.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _textCtrl = TextEditingController();
  String _result = '';
  bool _loading = false;
  String _serverStatus = '';
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    // slower, subtle breathing animation (reverse) for a more stable orb
    _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      // Default to empty string to force user to configure it
      final rawServer = prefs.getString('server_url') ?? '';
      if (rawServer.isEmpty) {
        setState(() {
          _result = 'Server URL not configured. Please set it in the Ping Server field first (e.g., http://YOUR_PC_IP:3000)';
        });
        setState(() => _loading = false);
        return;
      }
      final server = _normalizeAndPersistServer(prefs, rawServer);
      final uri = Uri.parse('$server/ai/chat');
      final model = prefs.getString('ai_model') ?? 'claude-haiku-4.5';

      // Retry logic with exponential backoff
      const maxAttempts = 3;
      int attempt = 0;
      while (true) {
        attempt++;
        try {
          final resp = await http
              .post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'input': text, 'model': model}))
              .timeout(const Duration(seconds: 12));

          if (resp.statusCode == 200) {
            final body = jsonDecode(resp.body);
            setState(() {
              _result = body['reply']?.toString() ?? body.toString();
            });
            break;
          } else {
            throw Exception('HTTP ${resp.statusCode}');
          }
        } catch (e) {
          if (attempt >= maxAttempts) {
            setState(() {
              _result = 'AI request failed after $attempt attempts: $e\n(Check server URL in settings or press Ping)';
            });
            break;
          }
          // backoff
          await Future.delayed(Duration(milliseconds: 500 * math.pow(2, attempt).toInt()));
        }
      }
    } catch (e) {
      setState(() => _result = 'Unexpected error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // Ensure server URL is web-friendly and persist corrected value when needed.
  // Converts hosts like 127.0.0.1 to 'localhost' when running on web and
  // ensures a scheme is present (defaults to http://).
  String _normalizeServerString(String raw) {
    if (raw.trim().isEmpty) return raw;
    var s = raw.trim();
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'http://$s';
    }
    try {
      final u = Uri.parse(s);
      if (kIsWeb && u.host == '127.0.0.1') {
        return u.replace(host: 'localhost').toString();
      }
      return s;
    } catch (e) {
      return s; // fallback to original-with-scheme
    }
  }

  String _normalizeAndPersistServer(SharedPreferences prefs, String raw) {
    final fixed = _normalizeServerString(raw);
    if (fixed != raw) {
      prefs.setString('server_url', fixed);
    }
    return fixed;
  }

  Future<void> _pingServer() async {
    setState(() {
      _serverStatus = 'Checking...';
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawServer = prefs.getString('server_url') ?? '';
      if (rawServer.isEmpty) {
        setState(() {
          _serverStatus = 'No URL set. Enter your PC IP (e.g., 192.168.x.x:3000)';
        });
        return;
      }
      final server = _normalizeAndPersistServer(prefs, rawServer);
      final uri = Uri.parse(server);
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      setState(() {
        _serverStatus = 'Server responded: ${resp.statusCode}';
      });
    } catch (e) {
      setState(() {
        _serverStatus = 'Ping failed: $e';
      });
    }
  }

  Future<void> _classify() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawServer = prefs.getString('server_url');
      final backendBase = (rawServer != null && rawServer.isNotEmpty) ? rawServer : Config.inferenceBaseEmulator;

      final classifier = TextClassifier(backendBase: backendBase);
      final out = await classifier.classify(text);
      setState(() {
        _result = 'Label: ${out["label"] ?? out}\nScore: ${out["score"] ?? "n/a"}';
      });
    } catch (e) {
      setState(() => _result = 'Classification failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(title: const Text('AI Assistant'), backgroundColor: Colors.transparent, elevation: 0),
      body: Stack(
        children: [
          // subtle particle background if available in the project
          // use a neutral container if not
          Positioned.fill(child: Container(color: Colors.transparent)),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                    // AI orb visual (subtle breathing)
                  AnimatedBuilder(
                    animation: _ctl,
                    builder: (context, child) {
                      final t = _ctl.value;
                      // smaller amplitude to keep orb stable on screen
                      final size = 160.0 + math.sin(t * 2 * math.pi) * 4;
                      return Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [Colors.cyanAccent.withValues(alpha: 0.9), Colors.transparent],
                          ),
                          boxShadow: [BoxShadow(color: Colors.cyanAccent.withValues(alpha: 0.12), blurRadius: 36, spreadRadius: 8)],
                        ),
                        child: Center(child: Icon(_loading ? Icons.mic : Icons.smart_toy, size: 48, color: Colors.white)),
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  const Text('Hi, I\'m Aira', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text('I can help you. Ask for help, check maps or share an SOS.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 18),
                  // Server URL input
                  TextField(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Server URL (e.g., http://10.184.49.158:3000)',
                      labelText: 'Server Address',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (value) async {
                      final prefs = await SharedPreferences.getInstance();
                      if (value.isNotEmpty) {
                        await prefs.setString('server_url', value);
                      }
                    },
                    onSubmitted: (_) => _pingServer(),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(onPressed: _pingServer, child: const Text('Ping Server')),
                        const SizedBox(width: 12),
                        Text(_serverStatus, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(width: 12),
                        ElevatedButton(onPressed: _loading ? null : _classify, child: const Text('Classify Text')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _textCtrl,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Describe the emergency...'),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _send,
                      icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
                      label: const Text('Send to Silent SOS'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(_result.isEmpty ? 'Result will appear here...' : _result, style: const TextStyle(color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
