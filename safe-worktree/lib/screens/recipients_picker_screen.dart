import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' hide PermissionStatus;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/email_validator.dart';

/// Recipient model for email recipients
class Recipient {
  final String name;
  final String? email;
  final String? phone;
  Recipient({required this.name, this.email, this.phone});
  Map<String, dynamic> toJson() =>
      {'name': name, 'email': email, 'phone': phone};
  static Recipient fromJson(Map<String, dynamic> j) => Recipient(
        name: j['name'] ?? '',
        email: j['email'],
        phone: j['phone'],
      );
}

class RecipientsPickerScreen extends StatefulWidget {
  const RecipientsPickerScreen({super.key});

  @override
  State<RecipientsPickerScreen> createState() => _RecipientsPickerScreenState();
}

class _RecipientsPickerScreenState extends State<RecipientsPickerScreen>
    with SingleTickerProviderStateMixin {
  List<Contact> _allContacts = [];
  final List<String> _selectedContactIds = [];
  List<String> _originalSelectedContactIds = []; // Track original state
  bool _loading = true;
  List<Recipient> _emailRecipients = [];
  List<Recipient> _originalEmailRecipients = []; // Track original state
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _emailValid = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 2, vsync: this, initialIndex: 0); // Start on contacts tab
    _loadContacts();
    _loadEmailRecipients();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      debugPrint('🔵 [Contact Picker] Starting contact load...');
      final status = await Permission.contacts.request();
      final ok = status.isGranted;
      debugPrint('🔵 [Contact Picker] Permission result: $status');
      if (!ok) {
        debugPrint(
            '❗ [Contact Picker] Contacts permission denied, asking user to open settings');
        if (!mounted) return;
        setState(() {
          _loading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Contacts permission is required to pick device contacts.'),
              action: SnackBarAction(
                  label: 'Open Settings', onPressed: () => openAppSettings()),
            ),
          );
        });
        return;
      }
      debugPrint('✓ [Contact Picker] Permission granted, fetching contacts...');
      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.phone, ContactProperty.email},
      );
      debugPrint(
          '✓ [Contact Picker] Raw contacts loaded: ${contacts.length} total');
      if (contacts.isNotEmpty) {
        debugPrint(
            '  First contact: ${contacts[0].displayName}, phones: ${contacts[0].phones.length}, emails: ${contacts[0].emails.length}');
      }
      if (!mounted) return;
      setState(() {
        _allContacts = contacts
            .where((c) => c.phones.isNotEmpty || c.emails.isNotEmpty)
            .toList();
        _loading = false;
      });
      debugPrint(
          '✓ [Contact Picker] Filtered to ${_allContacts.length} contacts with phone/email');
      await _loadSelectedContactIds();
    } catch (e) {
      debugPrint('❌ [Contact Picker] Error loading contacts: $e');
      debugPrint('❌ [Contact Picker] Stack: ${StackTrace.current}');
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadSelectedContactIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('selected_device_contacts') ?? '[]';
    try {
      final List<dynamic> ids = jsonDecode(raw);
      if (!mounted) return;
      setState(() {
        _selectedContactIds.clear();
        _selectedContactIds.addAll(ids.cast<String>());
        _originalSelectedContactIds =
            List.from(_selectedContactIds); // Save original state
      });
      debugPrint('Loaded ${_selectedContactIds.length} selected contact IDs');
    } catch (e) {
      debugPrint('Error loading selected contact IDs: $e');
    }
  }

  Future<void> _loadEmailRecipients() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('sos_recipients') ?? '[]';
    try {
      final List<dynamic> arr = jsonDecode(raw);
      if (!mounted) return;
      setState(() {
        _emailRecipients = arr
            .map((e) => Recipient.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _originalEmailRecipients =
            List.from(_emailRecipients); // Save original state
      });
      debugPrint('Loaded ${_emailRecipients.length} email recipients');
    } catch (e) {
      debugPrint('Error loading email recipients: $e');
    }
  }

  bool get _hasUnsavedChanges {
    return !_listEquals(_selectedContactIds, _originalSelectedContactIds) ||
        !_listEquals(_emailRecipients.map((e) => e.toJson()).toList(),
            _originalEmailRecipients.map((e) => e.toJson()).toList());
  }

  bool _listEquals(List a, List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _toggleContactSelection(String contactId) {
    setState(() {
      if (_selectedContactIds.contains(contactId)) {
        _selectedContactIds.remove(contactId);
      } else {
        _selectedContactIds.add(contactId);
      }
    });
  }

  /// Extract phone numbers from a contact (handles most devices)
  List<String> _extractPhoneNumbers(Contact contact) {
    final Set<String> numbers = {};

    // Extract from phones list
    for (final phone in contact.phones) {
      final value = phone.number.trim();
      if (value.isNotEmpty && value.length >= 8) {
        numbers.add(_sanitizePhoneNumber(value));
      }
    }

    // Extract from emails if no phone found (fallback)
    if (numbers.isEmpty) {
      for (final email in contact.emails) {
        final value = email.address.trim();
        if (value.isNotEmpty) {
          numbers.add(value);
        }
      }
    }

    return numbers.toList();
  }

  String _sanitizePhoneNumber(String input) {
    return input.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  Future<void> _saveSelectedContacts() async {
    final prefs = await SharedPreferences.getInstance();

    // Extract phone numbers from selected device contacts
    final phoneNumbers = <String>[];
    for (final contact
        in _allContacts.where((c) => _selectedContactIds.contains(c.id))) {
      phoneNumbers.addAll(_extractPhoneNumbers(contact));
    }

    debugPrint(
        '✓ Extracted ${phoneNumbers.length} phone numbers from contacts');
    for (final num in phoneNumbers) {
      debugPrint('  📱 $num');
    }

    // Save phone numbers to prefs
    await prefs.setStringList('sos_phone_numbers', phoneNumbers);

    // STEP 4b: Save to 'sos_contacts' key for SosController to use
    await prefs.setStringList('sos_contacts', phoneNumbers);

    // Save email recipients
    final emailList = _emailRecipients
        .map((r) => r.email ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    await prefs.setStringList('sos_email_recipients', emailList);

    // Keep contact IDs for reference
    await prefs.setString(
        'selected_device_contacts', jsonEncode(_selectedContactIds));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '✓ Saved: ${phoneNumbers.length} phones + ${emailList.length} emails'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );

    // Update original state to reflect saved changes
    setState(() {
      _originalSelectedContactIds = List.from(_selectedContactIds);
      _originalEmailRecipients = List.from(_emailRecipients);
    });
  }

  Future<void> _addEmailRecipient() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim().isEmpty
        ? email
        : _nameController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter email')));
      return;
    }

    if (!EmailValidator.isValidEmail(email)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invalid email')));
      return;
    }

    if (_emailRecipients.any((r) => r.email == email)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Email already added')));
      return;
    }

    final newRecipient = Recipient(name: name, email: email, phone: null);
    final prefs = await SharedPreferences.getInstance();
    _emailRecipients.add(newRecipient);
    await prefs.setString('sos_recipients',
        jsonEncode(_emailRecipients.map((e) => e.toJson()).toList()));

    if (mounted) {
      setState(() {
        _originalEmailRecipients =
            List.from(_emailRecipients); // Update original state
      });
      _emailController.clear();
      _nameController.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Email recipient added')));
    }
  }

  Future<void> _removeEmailRecipient(Recipient recipient) async {
    final prefs = await SharedPreferences.getInstance();
    _emailRecipients.removeWhere((r) => r.email == recipient.email);
    await prefs.setString('sos_recipients',
        jsonEncode(_emailRecipients.map((e) => e.toJson()).toList()));

    if (mounted) {
      setState(() {
        _originalEmailRecipients =
            List.from(_emailRecipients); // Update original state
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email recipient removed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Manage SOS Recipients'),
            if (_hasUnsavedChanges) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('UNSAVED',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Device Contacts'),
            Tab(text: 'Email Recipients'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Device Contacts Tab
                Column(
                  children: [
                    // Selection header (prominent display)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.teal.shade50, Colors.teal.shade100],
                        ),
                        border: Border(
                            bottom: BorderSide(
                                color: Colors.teal.shade200, width: 1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected: ${_selectedContactIds.length} / 5',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade900,
                                ),
                              ),
                              Text(
                                _selectedContactIds.isEmpty
                                    ? 'No contacts selected'
                                    : 'Ready to save',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.teal.shade700),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _selectedContactIds.length >= 5
                                  ? Colors.red.shade100
                                  : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _selectedContactIds.length >= 5
                                    ? Colors.red.shade300
                                    : Colors.green.shade300,
                              ),
                            ),
                            child: Text(
                              _selectedContactIds.length >= 5
                                  ? '⚠️ Max'
                                  : '✓ OK',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _selectedContactIds.length >= 5
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _allContacts.isEmpty
                          ? const Center(child: Text('No contacts found'))
                          : ListView.builder(
                              itemCount: _allContacts.length,
                              itemBuilder: (ctx, i) {
                                final contact = _allContacts[i];
                                final contactId = contact.id ?? '';
                                final isSelected =
                                    contactId.isNotEmpty &&
                                        _selectedContactIds.contains(contactId);
                                return CheckboxListTile(
                                  title: Text(contact.displayName ?? ''),
                                  subtitle: Text(
                                    contact.phones.isNotEmpty
                                        ? contact.phones.first.number
                                        : (contact.emails.isNotEmpty
                                            ? contact.emails.first.address
                                            : 'No contact info'),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  value: isSelected,
                                  onChanged: (_) {
                                    if (contactId.isNotEmpty) {
                                      _toggleContactSelection(contactId);
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),

                // Email Recipients Tab
                SingleChildScrollView(
                  child: Column(
                    children: [
                      // Email count header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.shade50,
                              Colors.amber.shade100
                            ],
                          ),
                          border: Border(
                              bottom: BorderSide(
                                  color: Colors.amber.shade200, width: 1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Email Recipients: ${_emailRecipients.length}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                                Text(
                                  _emailRecipients.isEmpty
                                      ? 'Add email recipients'
                                      : 'Ready to notify',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.amber.shade700),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.green.shade300),
                              ),
                              child: Text(
                                '✓ ${_emailRecipients.length}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Email input section
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.teal.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Add Email Recipient',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal)),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  hintText: 'Name (optional)',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _emailController,
                                      decoration: InputDecoration(
                                        hintText: 'Email address',
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        isDense: true,
                                        suffixIcon: _emailValid
                                            ? const Icon(Icons.check,
                                                color: Colors.green)
                                            : null,
                                      ),
                                      onChanged: (v) => setState(() =>
                                          _emailValid =
                                              EmailValidator.isValidEmail(
                                                  v.trim())),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _addEmailRecipient,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal),
                                    child: const Text('Add',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Saved email recipients section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Saved Email Recipients',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 8),
                            if (_emailRecipients.isEmpty)
                              const Text('None saved',
                                  style: TextStyle(color: Colors.grey))
                            else
                              ..._emailRecipients.map((r) => Card(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    child: ListTile(
                                      title: Text(r.name),
                                      subtitle: Text(r.email ?? ''),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () =>
                                            _removeEmailRecipient(r),
                                      ),
                                    ),
                                  )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveSelectedContacts,
        label: const Text('Save All'),
        icon: const Icon(Icons.save),
        backgroundColor: Colors.teal,
      ),
    );
  }
}
