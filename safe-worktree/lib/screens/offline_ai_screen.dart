import 'package:flutter/material.dart';

import '../services/offline_ai_service.dart';

class OfflineAiScreen extends StatefulWidget {
  const OfflineAiScreen({super.key});

  @override
  State<OfflineAiScreen> createState() => _OfflineAiScreenState();
}

class _OfflineAiScreenState extends State<OfflineAiScreen> {
  final TextEditingController _inputController = TextEditingController();
  bool _isProcessing = false;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _inputController.text =
        'Describe the situation (e.g. fall, threat, accident...)';
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _isProcessing = true;
      _result = null;
    });

    // Build a properly typed input for the offline AI rules
    final input = <String, dynamic>{
      'symptoms': text,
      'vitals': <String, dynamic>{},
    };

    final result = await OfflineAIService().analyzeHybrid(input);
    setState(() {
      _result = result;
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Safety AI'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ask for quick safety advice based on your situation.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ActionChip(
                  label: const Text('Woman safety'),
                  onPressed: () {
                    setState(() {
                      _inputController.text =
                          'I feel like someone is following me and I am worried for my safety.';
                    });
                  },
                ),
                ActionChip(
                  label: const Text('Accident / Fall'),
                  onPressed: () {
                    setState(() {
                      _inputController.text =
                          'I had a fall and I am hurt and need help immediately.';
                    });
                  },
                ),
                ActionChip(
                  label: const Text('Medical emergency'),
                  onPressed: () {
                    setState(() {
                      _inputController.text =
                          'I am experiencing severe pain or difficulty breathing.';
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _inputController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'What is happening?',
                hintText: 'I fell and can’t move, or I feel followed…',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _runAnalysis,
              icon: const Icon(Icons.smart_toy),
              label: Text(_isProcessing ? 'Analyzing...' : 'Analyze (Offline)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 18),
            if (_result != null) ...[
              Text(
                'Result: ${_result!['mode']?.toString().toUpperCase() ?? 'N/A'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_result!['brief'] != null)
                Text(_result!['brief'], style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              if (_result!['reasons'] is List)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Reasons:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    ...(_result!['reasons'] as List).map((e) => Text('- $e')),
                  ],
                ),
              if (_result!['actions'] is List) ...[
                const SizedBox(height: 12),
                const Text('Suggested actions:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ...(_result!['actions'] as List).map((e) => Text('- $e')),
              ],
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _result = null;
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Clear'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade800),
              ),
            ],
            if (_result == null && !_isProcessing) ...[
              const Spacer(),
              const Text(
                'Tip: Use this when you are unsafe or unsure. For emergencies, trigger SOS instead.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
