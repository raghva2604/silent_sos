import 'package:flutter/material.dart';
import '../../widgets/disguise_wrapper.dart';

/// A simple "Army" disguise interface.
///
/// This is intentionally minimal: it looks like an informational military-style
/// dashboard while the safety engine runs silently in the background.
class ArmyUI extends StatelessWidget {
  const ArmyUI({super.key});

  @override
  Widget build(BuildContext context) {
    return DisguiseWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Field Ops'),
          backgroundColor: Colors.brown.shade800,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh status',
              onPressed: () {},
            ),
          ],
        ),
        backgroundColor: Colors.brown.shade50,
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Operational Status',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'All systems nominal. Keep this screen open to maintain the disguise.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    _buildCard(context, Icons.map, 'Objectives',
                        'View mission objectives'),
                    _buildCard(context, Icons.chat, 'Comms',
                        'Check incoming messages'),
                    _buildCard(
                        context, Icons.location_on, 'Map', 'View nearby areas'),
                    _buildCard(context, Icons.medical_services, 'First Aid',
                        'Safety protocols'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(
      BuildContext context, IconData icon, String title, String subtitle) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Opening "$title"...'),
                duration: const Duration(seconds: 1)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: Colors.brown.shade700),
              const SizedBox(height: 14),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
