import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' hide PermissionStatus;
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
  bool _reorderMode = false;
  String _primaryContactNumber = '';

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
      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.phone},
      );
      final contactsWithPhones = contacts.where((c) => c.phones.isNotEmpty).toList();
      debugPrint(
          'ContactPicker: total=${contacts.length}, withPhones=${contactsWithPhones.length}');

      // Restore previously selected numbers and metadata from preferences
      List<String> saved = [];
      try {
        final prefs = await SharedPreferences.getInstance();
        saved = prefs.getStringList('selected_contacts') ?? [];
        final primaryNumber = prefs.getString('primary_contact_number');
        if (primaryNumber != null && primaryNumber.isNotEmpty) {
          _primaryContactNumber = primaryNumber;
        }
      } catch (e) {
        debugPrint('Could not restore contact metadata: $e');
      }

      if (mounted) {
        // Sort: Primary first, then selected, then others
        contactsWithPhones.sort((a, b) {
          final aNum = a.phones.isNotEmpty
              ? _normalizeNumber(a.phones.first.number)
              : '';
          final bNum = b.phones.isNotEmpty
              ? _normalizeNumber(b.phones.first.number)
              : '';

          // Primary contact always first
          if (aNum == _primaryContactNumber && bNum != _primaryContactNumber) {
            return -1;
          }
          if (aNum != _primaryContactNumber && bNum == _primaryContactNumber) {
            return 1;
          }

          // Then selected contacts
          final aSelected = saved.contains(aNum) ? 0 : 1;
          final bSelected = saved.contains(bNum) ? 0 : 1;
          if (aSelected != bSelected) return aSelected - bSelected;

          // Then alphabetically
          return (a.displayName ?? '')
              .toLowerCase()
              .compareTo((b.displayName ?? '').toLowerCase());
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

  /// Validate phone number format (basic check)
  bool _validatePhoneNumber(String number) {
    if (number.isEmpty) return false;
    // Valid if has at least 8 digits
    final digitsOnly = number.replaceAll(RegExp(r'\D'), '');
    return digitsOnly.length >= 8;
  }

  /// Set/unset a contact as primary
  void _setPrimaryContact(String phoneNumber) {
    _primaryContactNumber = phoneNumber;
  }

  /// Save selected contacts and metadata to preferences
  Future<void> _saveContactsAndMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('selected_contacts', _selectedNumbers);
      if (_primaryContactNumber.isNotEmpty) {
        await prefs.setString('primary_contact_number', _primaryContactNumber);
      }
      debugPrint(
          '✓ Saved ${_selectedNumbers.length} contacts + primary: $_primaryContactNumber');
    } catch (e) {
      debugPrint('Failed to save contacts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Emergency Contacts',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
        actions: [
          // Reorder mode toggle (only show if selections exist)
          if (_selectedNumbers.isNotEmpty)
            IconButton(
              icon: Icon(
                _reorderMode ? Icons.check_circle : Icons.unfold_more,
                color: _reorderMode ? Colors.amber : Colors.teal,
              ),
              tooltip: _reorderMode ? 'Done Reordering' : 'Reorder Contacts',
              onPressed: () {
                setState(() {
                  _reorderMode = !_reorderMode;
                  if (_reorderMode) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Drag contacts to reorder (selected section only)'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.select_all, color: Colors.teal),
            tooltip: 'Select All',
            onPressed: () {
              setState(() {
                final all = _contacts
                    .map((c) => c.phones.isNotEmpty
                        ? _normalizeNumber(c.phones.first.number)
                        : '')
                    .where((n) => n.isNotEmpty)
                    .toList();
                if (all.length <= _maxSelections) {
                  _selectedNumbers = all;
                } else {
                  _selectedNumbers = all.sublist(0, _maxSelections);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                          Text('Selected first $_maxSelections contacts')));
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
                await prefs.setStringList(
                    'selected_contacts', _selectedNumbers);
                await _saveContactsAndMetadata();
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
          // Selected count header (prominent display)
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade50, Colors.teal.shade100],
              ),
              border: Border(
                  bottom: BorderSide(color: Colors.teal.shade200, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected: ${_selectedNumbers.length} / $_maxSelections',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade900,
                      ),
                    ),
                    Text(
                      _selectedNumbers.isEmpty
                          ? 'No contacts selected'
                          : '${_selectedNumbers.length} contact${_selectedNumbers.length == 1 ? '' : 's'} ready',
                      style:
                          TextStyle(fontSize: 12, color: Colors.teal.shade700),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _selectedNumbers.length >= _maxSelections
                        ? Colors.red.shade100
                        : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedNumbers.length >= _maxSelections
                          ? Colors.red.shade300
                          : Colors.green.shade300,
                    ),
                  ),
                  child: Text(
                    _selectedNumbers.length >= _maxSelections
                        ? '⚠️ Max'
                        : '✓ OK',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _selectedNumbers.length >= _maxSelections
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Search bar
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
              onChanged: (v) =>
                  setState(() => _search = v.trim().toLowerCase()),
            ),
          ),
          Expanded(child: _buildBody()),
          if (_selectedNumbers.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.sms),
                label: const Text('Test SMS to First Contact'),
                onPressed: () async {
                  final to = _selectedNumbers.first;
                  final uri = Uri(
                      scheme: 'smsto',
                      path: to,
                      queryParameters: {'body': 'Test message from SilentSOS'});
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
              const Text("Permission Required",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                "This app needs contact access to select emergency contacts. Please grant permission in your device settings.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => openAppSettings(),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text('Open Settings',
                      style: TextStyle(color: Colors.white)),
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
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _loadContacts,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Contacts'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade800),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _contacts.length + (_selectedNumbers.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        // Show selected contacts header if there are selections
        if (_selectedNumbers.isNotEmpty && index == 0) {
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    border: Border(
                      left: BorderSide(color: Colors.teal.shade400, width: 3),
                    ),
                  ),
                  child: Text(
                    '✓ Selected Contacts (${_selectedNumbers.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal.shade700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        }

        final contactIndex = _selectedNumbers.isNotEmpty ? index - 1 : index;
        if (contactIndex >= _contacts.length) return const SizedBox.shrink();

        final contact = _contacts[contactIndex];
        final number = contact.phones.isNotEmpty
            ? _normalizeNumber(contact.phones.first.number)
            : '';
        final isSelected =
            _selectedNumbers.contains(number) && number.isNotEmpty;

        if (_search.isNotEmpty) {
          final lower = (contact.displayName ?? '').toLowerCase();
          if (!lower.contains(_search) && !number.contains(_search)) {
            return const SizedBox.shrink();
          }
        }

        final canToggle =
            isSelected || _selectedNumbers.length < _maxSelections;

        final isPrimary = _primaryContactNumber == number;
        final isVerified = isSelected && _validatePhoneNumber(number);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              color: isSelected ? Colors.teal.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: Colors.teal.shade300, width: 1.5)
                  : Border(
                      left: BorderSide(
                        color: canToggle
                            ? Colors.transparent
                            : Colors.red.shade200,
                        width: canToggle ? 0 : 2,
                      ),
                    ),
              boxShadow: [
                BoxShadow(
                  color:
                      isSelected ? Colors.teal.withAlpha(80) : Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              leading: isSelected
                  ? Icon(Icons.check_circle,
                      color: Colors.teal.shade600, size: 24)
                  : Icon(
                      Icons.radio_button_unchecked,
                      color: canToggle
                          ? Colors.grey.shade400
                          : Colors.red.shade300,
                      size: 24,
                    ),
              title: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                contact.displayName ?? '',
                                style: TextStyle(
                                  color: !canToggle && !isSelected
                                      ? Colors.black26
                                      : Colors.black87,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            // Show verification checkmark if validated
                            if (isSelected && isVerified)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Icon(Icons.check_circle,
                                    color: Colors.green.shade600, size: 18),
                              ),
                          ],
                        ),
                        if (isSelected)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withAlpha(38),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Ready',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Star icon for primary selection (only in selected section)
                  if (isSelected)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isPrimary) {
                              _primaryContactNumber = '';
                            } else {
                              _setPrimaryContact(number);
                            }
                          });
                        },
                        child: Icon(
                          isPrimary ? Icons.star : Icons.star_outline,
                          color: isPrimary
                              ? Colors.amber.shade600
                              : Colors.grey.shade400,
                          size: 22,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Text(
                number.isNotEmpty ? number : 'No number',
                style: TextStyle(
                  color: !canToggle && !isSelected
                      ? Colors.black26
                      : Colors.black54,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              trailing: GestureDetector(
                onTap: !canToggle && !isSelected
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Maximum 5 contacts allowed'),
                            backgroundColor: Colors.red.shade600,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    : null,
                child: Opacity(
                  opacity: canToggle ? 1.0 : 0.5,
                  child: IconButton(
                    icon: Icon(
                      isSelected
                          ? Icons.remove_circle
                          : Icons.add_circle_outline,
                      color: isSelected
                          ? Colors.red.shade600
                          : Colors.teal.shade600,
                    ),
                    onPressed: canToggle
                        ? () {
                            setState(() {
                              if (isSelected) {
                                _selectedNumbers.remove(number);
                                if (_primaryContactNumber == number) {
                                  _primaryContactNumber = '';
                                }
                              } else {
                                if (_selectedNumbers.length < _maxSelections) {
                                  _selectedNumbers.add(number);
                                }
                              }
                              // Trigger reorder after selection change
                              _contacts.sort((a, b) {
                                final aNum = a.phones.isNotEmpty
                                    ? _normalizeNumber(a.phones.first.number)
                                    : '';
                                final bNum = b.phones.isNotEmpty
                                    ? _normalizeNumber(b.phones.first.number)
                                    : '';
                                final aSelected =
                                    _selectedNumbers.contains(aNum) ? 0 : 1;
                                final bSelected =
                                    _selectedNumbers.contains(bNum) ? 0 : 1;
                                if (aSelected != bSelected) {
                                  return aSelected - bSelected;
                                }
                                return (a.displayName ?? '')
                                    .toLowerCase()
                                    .compareTo((b.displayName ?? '').toLowerCase());
                              });
                            });
                          }
                        : null,
                  ),
                ),
              ),
              onTap: canToggle
                  ? () {
                      setState(() {
                        if (isSelected) {
                          _selectedNumbers.remove(number);
                        } else {
                          if (_selectedNumbers.length < _maxSelections) {
                            _selectedNumbers.add(number);
                          }
                        }
                        // Trigger reorder after selection change
                        _contacts.sort((a, b) {
                          final aNum = a.phones.isNotEmpty
                              ? _normalizeNumber(a.phones.first.number)
                              : '';
                          final bNum = b.phones.isNotEmpty
                              ? _normalizeNumber(b.phones.first.number)
                              : '';
                          final aSelected =
                              _selectedNumbers.contains(aNum) ? 0 : 1;
                          final bSelected =
                              _selectedNumbers.contains(bNum) ? 0 : 1;
                          if (aSelected != bSelected) {
                            return aSelected - bSelected;
                          }
                          return (a.displayName ?? '')
                              .toLowerCase()
                              .compareTo((b.displayName ?? '').toLowerCase());
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
