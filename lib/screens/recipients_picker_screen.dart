import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../src/app_state.dart';
import '../services/email_validator.dart';

/// Recipient model for email recipients
class Recipient {
  final String name;
  final String? email;
  final String? phone;
  Recipient({required this.name, this.email, this.phone});
  Map<String, dynamic> toJson() => {'name': name, 'email': email, 'phone': phone};
  static Recipient fromJson(Map<String,dynamic> j) => Recipient(
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

class _RecipientsPickerScreenState extends State<RecipientsPickerScreen> with SingleTickerProviderStateMixin {
  List<Contact> _allContacts = [];
  final List<String> _selectedContactIds = [];
  bool _loading = true;
  List<Recipient> _emailRecipients = [];
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _emailValid = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      var ok = await FlutterContacts.requestPermission();
      debugPrint('🔵 [Contact Picker] Permission result: $ok');
      if (!ok) {
        debugPrint('❗ [Contact Picker] Initial permission denied, requesting via permission_handler...');
        final status = await Permission.contacts.request();
        ok = status.isGranted;
        debugPrint('🔵 [Contact Picker] permission_handler result: $status');
        if (!ok) {
          debugPrint('❌ [Contact Picker] Contacts permission denied (final)');
          if (!mounted) return;
          setState(() { _loading = false; });
          // Prompt user to open settings
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Contacts permission is required to pick device contacts.'),
                action: SnackBarAction(label: 'Open Settings', onPressed: () => openAppSettings()),
              ),
            );
          });
          return;
        }
      }
      debugPrint('✓ [Contact Picker] Permission granted, fetching contacts...');
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      debugPrint('✓ [Contact Picker] Raw contacts loaded: ${contacts.length} total');
      if (contacts.isNotEmpty) {
        debugPrint('  First contact: ${contacts[0].displayName}, phones: ${contacts[0].phones.length}, emails: ${contacts[0].emails.length}');
      }
      if (!mounted) return;
      setState(() {
        _allContacts = contacts.where((c) => c.phones.isNotEmpty || c.emails.isNotEmpty).toList();
        _loading = false;
      });
      debugPrint('✓ [Contact Picker] Filtered to ${_allContacts.length} contacts with phone/email');
      await _loadSelectedContactIds();
    } catch (e) {
      debugPrint('❌ [Contact Picker] Error loading contacts: $e');
      debugPrint('❌ [Contact Picker] Stack: ${StackTrace.current}');
      if (!mounted) return;
      setState(() { _loading = false; });
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
        _emailRecipients = arr.map((e) => Recipient.fromJson(Map<String,dynamic>.from(e))).toList();
      });
      debugPrint('Loaded ${_emailRecipients.length} email recipients');
    } catch (e) {
      debugPrint('Error loading email recipients: $e');
    }
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

  Future<void> _saveSelectedContacts() async {
    final prefs = await SharedPreferences.getInstance();
    // Persist the device contact IDs (for later editing)
    await prefs.setString('selected_device_contacts', jsonEncode(_selectedContactIds));

    // Build list of selected contact display strings for AppState and older persistence
    final contactsList = _allContacts
        .where((c) => _selectedContactIds.contains(c.id))
        .map((c) => c.displayName)
        .toList();

    // Also add manual email recipients (display name or email)
    contactsList.addAll(_emailRecipients.map((r) => r.name.isNotEmpty ? r.name : (r.email ?? '')));

    // Save to the AppState-compatible key 'selected_contacts' (pipe-separated)
    try {
      await prefs.setString('selected_contacts', contactsList.map((c) => c.toString()).join('|'));
    } catch (_) {}

    if (mounted) {
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.setSelectedContacts(contactsList);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved ${_selectedContactIds.length} device contacts + ${_emailRecipients.length} email recipients'),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  Future<void> _addEmailRecipient() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim().isEmpty ? email : _nameController.text.trim();
    
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter email')));
      return;
    }
    
    if (!EmailValidator.isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid email')));
      return;
    }
    
    if (_emailRecipients.any((r) => r.email == email)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email already added')));
      return;
    }
    
    final newRecipient = Recipient(name: name, email: email, phone: null);
    final prefs = await SharedPreferences.getInstance();
    _emailRecipients.add(newRecipient);
    await prefs.setString('sos_recipients', jsonEncode(_emailRecipients.map((e) => e.toJson()).toList()));
    
    if (mounted) {
      setState(() {});
      _emailController.clear();
      _nameController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email recipient added')));
    }
  }

  Future<void> _removeEmailRecipient(Recipient recipient) async {
    final prefs = await SharedPreferences.getInstance();
    _emailRecipients.removeWhere((r) => r.email == recipient.email);
    await prefs.setString('sos_recipients', jsonEncode(_emailRecipients.map((e) => e.toJson()).toList()));
    
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email recipient removed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage SOS Recipients'),
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
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Selected: ${_selectedContactIds.length} contacts',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    Expanded(
                      child: _allContacts.isEmpty
                          ? const Center(child: Text('No contacts found'))
                          : ListView.builder(
                              itemCount: _allContacts.length,
                              itemBuilder: (ctx, i) {
                                final contact = _allContacts[i];
                                final isSelected = _selectedContactIds.contains(contact.id);
                                return CheckboxListTile(
                                  title: Text(contact.displayName),
                                  subtitle: Text(
                                    contact.phones.isNotEmpty
                                        ? contact.phones.first.number
                                        : (contact.emails.isNotEmpty
                                            ? contact.emails.first.address
                                            : 'No contact info'),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  value: isSelected,
                                  onChanged: (_) => _toggleContactSelection(contact.id),
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
                              const Text('Add Email Recipient', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  hintText: 'Name (optional)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        isDense: true,
                                        suffixIcon: _emailValid ? const Icon(Icons.check, color: Colors.green) : null,
                                      ),
                                      onChanged: (v) => setState(() => _emailValid = EmailValidator.isValidEmail(v.trim())),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _addEmailRecipient,
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                                    child: const Text('Add', style: TextStyle(color: Colors.white)),
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
                            const Text('Saved Email Recipients', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 8),
                            if (_emailRecipients.isEmpty)
                              const Text('None saved', style: TextStyle(color: Colors.grey))
                            else
                              ..._emailRecipients.map((r) => Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  title: Text(r.name),
                                  subtitle: Text(r.email ?? ''),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _removeEmailRecipient(r),
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
