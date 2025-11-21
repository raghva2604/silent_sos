import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MedicalChatScreen extends StatefulWidget {
  const MedicalChatScreen({super.key});

  @override
  @override
  State<MedicalChatScreen> createState() => _MedicalChatScreenState();
}

class _MedicalChatScreenState extends State<MedicalChatScreen> {
  String connectionStatus = 'connected';
  bool isConnecting = false;
  final TextEditingController _inputController = TextEditingController();
  final List<Map<String, String>> _messages = [];

  Future<String> _getServerBase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Use server_url only; WhatsApp backend preference removed
      return prefs.getString('server_url') ?? 'http://10.0.2.2:3000';
    } catch (_) {
      return 'http://10.0.2.2:3000';
    }
  }

  Future<Map<String, dynamic>> sendMessageWithRetry(String sessionId, String message,
      {int maxRetries = 3}) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        setState(() {
          isConnecting = true;
          connectionStatus = attempt > 0 ? 'reconnecting' : 'connected';
        });

        final serverBase = await _getServerBase();
        final apiUrl = '$serverBase/ai/chat';

        final response = await http
            .post(Uri.parse(apiUrl),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'sessionId': sessionId, 'chatInput': message}))
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          setState(() {
            connectionStatus = 'connected';
            isConnecting = false;
          });
          return jsonDecode(response.body) as Map<String, dynamic>;
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } catch (error) {
        debugPrint('Attempt ${attempt + 1} failed: $error');

        if (attempt < maxRetries - 1) {
          setState(() => connectionStatus = 'reconnecting');
          final delay = Duration(seconds: 2 * (1 << attempt));
          await Future.delayed(delay);
        } else {
          setState(() {
            connectionStatus = 'disconnected';
            isConnecting = false;
          });
          throw Exception('Unable to connect. Please check your internet connection.');
        }
      }
    }
    throw Exception('Failed after all retries');
  }

  Color getStatusColor() {
    switch (connectionStatus) {
      case 'connected':
        return Colors.green;
      case 'reconnecting':
        return Colors.orange;
      case 'disconnected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String getStatusText() {
    switch (connectionStatus) {
      case 'connected':
        return '● Connected';
      case 'reconnecting':
        return '⟳ Reconnecting...';
      case 'disconnected':
        return '✕ Connection Lost';
      default:
        return '';
    }
  }

  Future<void> handleSendMessage(String message) async {
    if (message.trim().isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'text': message});
      _inputController.clear();
    });

    try {
      final response = await sendMessageWithRetry('user-1', message);
      setState(() {
        _messages.add({'role': 'assistant', 'text': response.toString()});
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
        setState(() {
          _messages.add({'role': 'assistant', 'text': 'Error: ${error.toString()}'});
        });
      }
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Assistant'),
        actions: [
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(Icons.circle, color: getStatusColor(), size: 12),
                const SizedBox(width: 5),
                Text(getStatusText(), style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, idx) {
                final m = _messages[idx];
                final isUser = m['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blueGrey : Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(m['text'] ?? '', style: const TextStyle(fontSize: 14)),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(hintText: 'Describe symptoms or ask a question...'),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: isConnecting ? null : () => handleSendMessage(_inputController.text),
                    child: const Text('Send'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
