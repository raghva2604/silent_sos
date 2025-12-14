import 'package:flutter/material.dart';

class ContactsMapScreen extends StatelessWidget {
  const ContactsMapScreen({super.key});

  final List<Map<String, String>> contacts = const [
    {'name': 'Mom', 'phone': '+91 9xxxxxxxx'},
    {'name': 'Dad', 'phone': '+91 9xxxxxxxx'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts & Map')),
      body: Column(
        children: [
          Container(height: 160, color: Colors.grey.shade900, child: const Center(child: Text('Contacts/Map Mockup'))),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (ctx, i) {
                final c = contacts[i];
                return ListTile(
                  leading: CircleAvatar(child: Text(c['name']![0])),
                  title: Text(c['name']!),
                  subtitle: Text(c['phone']!),
                  trailing: IconButton(icon: const Icon(Icons.call), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Call ${c['phone']}')))),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
