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
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Emergency Contacts', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all, color: Colors.teal),
            tooltip: 'Select All',
            onPressed: () {
              setState(() {
                final all = _contacts.map((c) => c.phones.isNotEmpty ? _normalizeNumber(c.phones.first.number) : '').where((n) => n.isNotEmpty).toList();
                if (all.length <= _maxSelections) {
                  _selectedNumbers = all;
                } else {
                  _selectedNumbers = all.sublist(0, _maxSelections);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Selected first $_maxSelections contacts')));
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.teal),
            tooltip: 'Refresh',
            onPressed: _loadContacts,
          ),
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green),
            onPressed: () async {
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select up to $_maxSelections contacts.',
                    style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                Builder(builder: (ctx) {
                  final remaining = (_maxSelections - _selectedNumbers.length).clamp(0, _maxSelections);
                  final reached = remaining == 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: reached ? Colors.red.withAlpha(30) : Colors.teal.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: reached ? Colors.red.withAlpha(100) : Colors.teal.withAlpha(100)),
                    ),
                    child: Text(
                      reached ? 'Max Reached' : '$remaining remaining',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: reached ? Colors.red : Colors.teal,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                hintText: 'Search contacts...',
                hintStyle: const TextStyle(color: Colors.black54),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.teal.withAlpha(80)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.teal.withAlpha(60)),
                ),
              ),
              style: const TextStyle(color: Colors.black87),
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            ),
          ),
          Expanded(child: _buildBody()),
          if (_selectedNumbers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.sms),
                label: const Text('Test SMS to First Contact'),
                onPressed: () async {
                  final to = _selectedNumbers.first;
                  final uri = Uri(scheme: 'sms', path: to, queryParameters: {'body': 'Test message from SilentSOS'});
                  try {
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  } catch (e) {
                    debugPrint('Could not launch SMS: $e');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
          ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_permissionStatus == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_permissionStatus!.isDenied || _permissionStatus!.isPermanentlyDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, size: 64, color: Colors.red),
              const SizedBox(height: 20),
              const Text("Permission Required", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                "This app needs contact access to select emergency contacts. Please grant permission in your device settings.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => openAppSettings(),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text('Open Settings', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_contacts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.contacts_outlined, size: 64, color: Colors.teal),
              const SizedBox(height: 20),
              const Text(
                'No contacts with phone numbers found on this device.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  final test = ['+15551234567', '+15557654321'];
                  Navigator.pop(context, test);
                },
                icon: const Icon(Icons.add),
                label: const Text('Use Test Contacts'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _loadContacts,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Contacts'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800),
              ),
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

        if (_search.isNotEmpty) {
          final lower = contact.displayName.toLowerCase();
          if (!lower.contains(_search) && !number.contains(_search)) {
            return const SizedBox.shrink();
          }
        }

        final canToggle = isSelected || _selectedNumbers.length < _maxSelections;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: CheckboxListTile(
              title: Text(
                contact.displayName,
                style: TextStyle(
                  color: (!canToggle && !isSelected) ? Colors.black26 : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              subtitle: Text(
                number.isNotEmpty ? number : 'No number',
                style: TextStyle(color: (!canToggle && !isSelected) ? Colors.black26 : Colors.black54, fontSize: 12),
              ),
              value: isSelected,
              activeColor: Colors.teal,
              checkColor: Colors.white,
              onChanged: canToggle
                  ? (val) {
                        setState(() {
                          if (val == true && number.isNotEmpty) {
                            if (!_selectedNumbers.contains(number)) {
                              if (_selectedNumbers.length >= _maxSelections) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('You can select up to $_maxSelections contacts only')),
                                );
                                return;
                              }
                              _selectedNumbers.add(number);
                            }
                          } else {
                            _selectedNumbers.remove(number);
                          }
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
            ),
          ),
        );
      },
    );
  }
}
