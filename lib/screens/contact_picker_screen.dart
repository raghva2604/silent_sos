import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactPickerScreen extends StatefulWidget {
  final List<String> initialContacts;
  const ContactPickerScreen({super.key, required this.initialContacts});

  @override
  State<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends State<ContactPickerScreen> {
  static const int _maxSelections = 5;
  List<Contact> _contacts = [];
  List<String> _selectedNumbers = [];
  PermissionStatus? _permissionStatus;
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selectedNumbers = List.from(widget.initialContacts);
    _checkPermissionAndLoadContacts();
  }

  String _normalizeNumber(String? raw) {
    if (raw == null) return '';
    return raw.replaceAll(RegExp(r"[^+0-9]"), '');
  }

  Future<void> _checkPermissionAndLoadContacts() async {
    final status = await Permission.contacts.status;
    setState(() => _permissionStatus = status);

    if (status.isGranted) {
      await _loadContacts();
    } else {
      final newStatus = await Permission.contacts.request();
      setState(() => _permissionStatus = newStatus);
      if (newStatus.isGranted) await _loadContacts();
    }
  }

  Future<void> _loadContacts() async {
    setState(() {
      _loading = true;
    });
    try {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      final contactsWithPhones = contacts.where((c) => c.phones.isNotEmpty).toList();
      debugPrint('ContactPicker: total=${contacts.length}, withPhones=${contactsWithPhones.length}');

      // Restore any previously selected numbers from preferences
      List<String> saved = [];
      try {
        final prefs = await SharedPreferences.getInstance();
        saved = prefs.getStringList('selected_contacts') ?? [];
      } catch (e) {
        debugPrint('Could not restore selected contacts: $e');
      }

      if (mounted) {
        // Place selected contacts at the top of the list
        contactsWithPhones.sort((a, b) {
          final aNum = a.phones.isNotEmpty ? _normalizeNumber(a.phones.first.number) : '';
          final bNum = b.phones.isNotEmpty ? _normalizeNumber(b.phones.first.number) : '';
          final aSelected = saved.contains(aNum) ? 0 : 1;
          final bSelected = saved.contains(bNum) ? 0 : 1;
          if (aSelected != bSelected) return aSelected - bSelected;
          return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
        });

        setState(() {
          _contacts = contactsWithPhones;
          _permissionStatus = PermissionStatus.granted;
          _selectedNumbers = List.from(saved);
        });
      }
    } catch (e, st) {
      debugPrint('Error loading contacts: $e\n$st');
      if (mounted) {
        setState(() {
          _permissionStatus = PermissionStatus.denied;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: 'Select All',
            onPressed: () {
              setState(() {
                final all = _contacts.map((c) => c.phones.isNotEmpty ? _normalizeNumber(c.phones.first.number) : '').where((n) => n.isNotEmpty).toList();
                if (all.length <= _maxSelections) {
                  _selectedNumbers = all;
                } else {
                  _selectedNumbers = all.sublist(0, _maxSelections);
                  // notify user that only first N were selected
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Selected first $_maxSelections contacts')));
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadContacts,
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () async {
              // Persist selection
              final nav = Navigator.of(context);
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setStringList('selected_contacts', _selectedNumbers);
              } catch (e) {
                debugPrint('Failed to save selection: $e');
              }
              if (!mounted) return;
              nav.pop(_selectedNumbers);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Helper text and remaining counter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'You can select up to $_maxSelections contacts.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ),
                const SizedBox(width: 8),
                Builder(builder: (ctx) {
                  final remaining = (_maxSelections - _selectedNumbers.length).clamp(0, _maxSelections);
                  final reached = remaining == 0;
                  return Tooltip(
                    message: reached ? 'Selection limit reached' : '$remaining selections remaining',
                    child: AnimatedScale(
                      scale: reached ? 1.08 : 1.0,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeInOut,
                      child: Chip(
                        backgroundColor: reached ? Colors.red.shade100 : Colors.green.shade50,
                        avatar: CircleAvatar(
                          backgroundColor: reached ? Colors.red : Colors.green,
                          child: Text(remaining.toString(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                        label: Text(reached ? 'Max' : 'Remaining', style: TextStyle(color: reached ? Colors.red.shade700 : Colors.green.shade800)),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search contacts...'),
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            ),
          ),
          Expanded(child: _buildBody()),
          if (_selectedNumbers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.sms),
                      label: const Text('Test SMS'),
                      onPressed: () async {
                        final to = _selectedNumbers.first;
                        final uri = Uri(scheme: 'sms', path: to, queryParameters: {'body': 'Test message from SilentSOS'});
                        try {
                          if (await canLaunchUrl(uri)) await launchUrl(uri);
                        } catch (e) {
                          debugPrint('Could not launch SMS: $e');
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
  if (_loading) return const Center(child: CircularProgressIndicator());

  if (_permissionStatus == null) return const Center(child: CircularProgressIndicator());

    if (_permissionStatus!.isDenied || _permissionStatus!.isPermanentlyDenied) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 60, color: Colors.red),
              SizedBox(height: 20),
              Text("Permission Required", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text("This app needs contact access to select emergency contacts. Please grant permission in your device settings.", textAlign: TextAlign.center),
              SizedBox(height: 20),
              // ElevatedButton cannot be const because callback is non-const
            ],
          ),
        ),
      );
    }

    if (_contacts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No contacts with phone numbers found on this device.', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  // Provide test contacts for emulators or devices without contacts
                  final test = ['+15551234567', '+15557654321'];
                  Navigator.pop(context, test);
                },
                child: const Text('Use Test Contacts'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loadContacts,
                child: const Text('Refresh Contacts'),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _loadContacts, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        final number = contact.phones.isNotEmpty ? _normalizeNumber(contact.phones.first.number) : '';
        final isSelected = _selectedNumbers.contains(number) && number.isNotEmpty;

        // If a search filter is active, skip items that don't match
        if (_search.isNotEmpty) {
          final lower = contact.displayName.toLowerCase();
          if (!lower.contains(_search) && !number.contains(_search)) {
            return const SizedBox.shrink();
          }
        }

        final canToggle = isSelected || _selectedNumbers.length < _maxSelections;
        return CheckboxListTile(
          title: Text(
            contact.displayName,
            style: TextStyle(color: (!canToggle && !isSelected) ? Colors.grey : null),
          ),
          subtitle: Text(number.isNotEmpty ? number : 'No number', style: TextStyle(color: (!canToggle && !isSelected) ? Colors.grey : null)),
          value: isSelected,
          onChanged: canToggle
              ? (val) {
                  setState(() {
                    if (val == true && number.isNotEmpty) {
                      if (!_selectedNumbers.contains(number)) {
                        if (_selectedNumbers.length >= _maxSelections) {
                          // enforce max selection
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You can select up to $_maxSelections contacts only')));
                          return;
                        }
                        _selectedNumbers.add(number);
                      }
                    } else {
                      _selectedNumbers.remove(number);
                    }
                    // Keep selected contacts at top visually by re-sorting
                    _contacts.sort((a, b) {
                      final aNum = a.phones.isNotEmpty ? _normalizeNumber(a.phones.first.number) : '';
                      final bNum = b.phones.isNotEmpty ? _normalizeNumber(b.phones.first.number) : '';
                      final aSelected = _selectedNumbers.contains(aNum) ? 0 : 1;
                      final bSelected = _selectedNumbers.contains(bNum) ? 0 : 1;
                      if (aSelected != bSelected) return aSelected - bSelected;
                      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
                    });
                  });
                }
              : null,
        );
      },
    );
  }
}
