import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HotwordSettings extends StatefulWidget {
  const HotwordSettings({super.key});

  @override
  State<HotwordSettings> createState() => _HotwordSettingsState();
}

class _HotwordSettingsState extends State<HotwordSettings> {
  final _modelController = TextEditingController();
  final _phraseController = TextEditingController();
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _modelController.text = p.getString('vosk_model_path') ??
          '/sdcard/vosk-model-small-en-us-0.15';
      _phraseController.text = p.getString('custom_hotword') ?? '';
      _enabled = p.getBool('hotword_enabled') ?? false;
    });
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final p = await SharedPreferences.getInstance();
    await p.setString('vosk_model_path', _modelController.text);
    await p.setString('custom_hotword', _phraseController.text);
    await p.setBool('hotword_enabled', _enabled);
    messenger
        .showSnackBar(const SnackBar(content: Text('Hotword settings saved')));
  }

  @override
  void dispose() {
    _modelController.dispose();
    _phraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hotword Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Enable hotword listener'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            TextField(
              controller: _modelController,
              decoration:
                  const InputDecoration(labelText: 'Vosk model path on device'),
            ),
            TextField(
              controller: _phraseController,
              decoration:
                  const InputDecoration(labelText: 'Custom hotword phrase'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
