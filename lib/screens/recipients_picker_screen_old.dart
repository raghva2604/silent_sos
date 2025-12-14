import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../src/app_state.dart';
import '../widgets/contact_validation_widget.dart';
import '../services/email_validator.dart';

/// Recipient model
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

class _RecipientsPickerScreenState extends State<RecipientsPickerScreen> {
  List<Contact> _allContacts = [];
  final List<String> _selectedIds = []; // contact ids
  bool _loading = true;
  List<Recipient> _persisted = [];
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _emailValid = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final ok = await FlutterContacts.requestPermission();
      if (!ok) {
        debugPrint('Contacts permission denied');
        if (!mounted) return;
        setState(() { _loading = false; });
        return;
      }
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      debugPrint('Loaded ${contacts.length} contacts');
      // Filter contacts with at least phone or email
      if (!mounted) return;
      setState(() {
        _allContacts = contacts.where((c) => c.phones.isNotEmpty || c.emails.isNotEmpty).toList();
        _loading = false;
      });
      debugPrint('Filtered to ${_allContacts.length} contacts with phone/email');
      // After contacts are loaded, also load any persisted recipients and map them to selected ids
      await _loadPersistedRecipients();
    } catch (e) {
      debugPrint('Error loading contacts: $e');
      if (!mounted) return;
      setState(() { _loading = false; });
    }
  }

  Future<void> _loadPersistedRecipients() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('sos_recipients') ?? '[]';
    final arr = jsonDecode(raw) as List<dynamic>;
    if (!mounted) return;
    setState(() {
      _persisted = arr.map((e) => Recipient.fromJson(Map<String,dynamic>.from(e))).toList();
      // Map persisted recipients to contact ids so they appear selected in the list
      _selectedIds.clear();
      for (final r in _persisted) {
        // Try match by email
        if (r.email != null && r.email!.isNotEmpty) {
          Contact? match;
          for (final c in _allContacts) {
            final found = c.emails.any((e) => (e.address).toLowerCase().trim() == r.email!.toLowerCase().trim());
            if (found) {
              match = c;
              break;
            }
          }
          if (match != null && match.id.isNotEmpty) _selectedIds.add(match.id);
        }
        // Try match by phone if not matched
        if (r.phone != null && r.phone!.isNotEmpty) {
          Contact? match;
          for (final c in _allContacts) {
            final found = c.phones.any((p) => (p.number).replaceAll(RegExp(r'\D'), '') == r.phone!.replaceAll(RegExp(r'\D'), ''));
            if (found) {
              match = c;
              break;
            }
          }
          if (match != null && !_selectedIds.contains(match.id)) _selectedIds.add(match.id);
        }
      }
    });
  }

  Future<void> _savePersistedRecipients(List<Recipient> recipients) async {
    final messenger = ScaffoldMessenger.of(context);
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(recipients.map((r) => r.toJson()).toList());
    await prefs.setString('sos_recipients', raw);
    if (!mounted) return;
    setState(() => _persisted = recipients);
    // Update AppState selected contacts so Home shows persisted recipients
    final appState = Provider.of<AppState>(context, listen: false);
    final combined = <String>[];
    // add device-selected contacts (names)
    combined.addAll(_allContacts.where((c) => _selectedIds.contains(c.id)).map((c) => c.displayName));
    // add persisted recipients (name or email)
    combined.addAll(_persisted.map((r) => r.name.isNotEmpty ? r.name : (r.email ?? '')));
    await appState.setSelectedContacts(combined);
    messenger.showSnackBar(SnackBar(content: Text('Saved ${recipients.length} recipients')));
  }

  void _onToggle(String contactId) {
    setState(() {
      if (_selectedIds.contains(contactId)) {
        _selectedIds.remove(contactId);
      } else {
        _selectedIds.add(contactId);
      }
    });
  }

  Future<void> _saveSelected() async {
    // Transform selected contacts -> Recipient (take first email/phone available)
    final list = _allContacts.where((c) => _selectedIds.contains(c.id)).map((c){
      final email = c.emails.isNotEmpty ? c.emails.first.address : null;
      final phone = c.phones.isNotEmpty ? c.phones.first.number : null;
      return Recipient(name: c.displayName, email: email, phone: phone);
    }).toList();
    await _savePersistedRecipients(list);
    
    // Also update AppState
    if (mounted) {
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.setSelectedContacts(list.map((r) => r.name).toList());
    }
  }

  Widget _buildContactTile(Contact c) {
    final selected = _selectedIds.contains(c.id);
    return ContactValidationTile(
      name: c.displayName,
      email: c.emails.isNotEmpty ? c.emails.first.address : null,
      phone: c.phones.isNotEmpty ? c.phones.first.number : null,
      isSelected: selected,
      onToggle: () => _onToggle(c.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage SOS Recipients'),
        actions: [
          TextButton(
            onPressed: _selectedIds.isEmpty ? null : _saveSelected,
            child: Text('Save', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: _loading ? Center(child: CircularProgressIndicator()) : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Selected: ${_selectedIds.length} device contacts • Saved: ${_persisted.length} total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _allContacts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) => _buildContactTile(_allContacts[i]),
            ),
          ),
          const Divider(),
          // Email Input Section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add Email Recipient', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                const SizedBox(height: 8),
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
                      onPressed: () async {
                        final email = _emailController.text.trim();
                        final name = _nameController.text.trim().isEmpty ? email : _nameController.text.trim();
                        
                        if (email.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter email')));
                          return;
                        }
                        
                        // Validate email using existing validator
                        if (!EmailValidator.isValidEmail(email)) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid email')));
                          return;
                        }
                        
                        // Check if already exists
                        if (_persisted.any((r) => r.email == email)) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Already added')));
                          return;
                        }
                        
                        // Add to persisted
                        final newRecipient = Recipient(name: name, email: email, phone: null);
                        _persisted.add(newRecipient);

                        // Save to SharedPreferences
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('sos_recipients', jsonEncode(_persisted.map((e) => e.toJson()).toList()));

                        // Update AppState so Home shows this recipient immediately
                        final appState = Provider.of<AppState>(context, listen: false);
                        final current = List<String>.from(appState.selectedContacts);
                        final display = newRecipient.name.isNotEmpty ? newRecipient.name : newRecipient.email ?? '';
                        if (display.isNotEmpty && !current.contains(display)) {
                          current.add(display);
                          await appState.setSelectedContacts(current);
                        }

                        // Clear inputs and update UI
                        _emailController.clear();
                        _nameController.clear();
                        setState(() {});

                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email recipient added')));
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                      child: const Text('Add', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Saved Recipients
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0,2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saved Recipients', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_persisted.isEmpty)
                  const Text('None saved', style: TextStyle(color: Colors.black54)),
                if (_persisted.isNotEmpty)
                  ..._persisted.map((r) {
                    // Check if recipient is from manual email (not found in device contacts)
                    final isManualEmail = r.email != null && r.email!.isNotEmpty && !_allContacts.any((c) => c.emails.any((e) => (e.address).toLowerCase().trim() == r.email!.toLowerCase().trim()));
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Stack(
                        children: [
                          ContactValidationTile(
                            name: r.name,
                            email: r.email,
                            phone: r.phone,
                            isSelected: false,
                            onToggle: () {},
                            onRemove: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final prefs = await SharedPreferences.getInstance();
                              final newList = _persisted.where((p) => p.name != r.name || p.email != r.email).toList();
                              await prefs.setString('sos_recipients', jsonEncode(newList.map((e) => e.toJson()).toList()));
                              if (!mounted) return;
                              setState(() { _persisted = newList; });
                              messenger.showSnackBar(const SnackBar(content: Text('Removed recipient')));
                            },
                          ),
                          // Visual indicator badge
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isManualEmail ? Colors.orange.shade100 : Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isManualEmail ? Colors.orange.shade300 : Colors.blue.shade300,
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                isManualEmail ? Icons.mail_outline : Icons.person_outline,
                                size: 16,
                                color: isManualEmail ? Colors.orange.shade700 : Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  })
              ],
            ),
          )
        ],
      ),
    );
  }
}
