import 'package:flutter/material.dart';
import '../../widgets/disguise_wrapper.dart';

class NotesUI extends StatelessWidget {
  const NotesUI({super.key});

  @override
  Widget build(BuildContext context) {
    return DisguiseWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("QuickNotes"),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {},
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _noteCard("Shopping List", "Milk, Bread, Eggs, Cheese", "Today"),
            _noteCard("Meeting Notes",
                "Discuss project timeline and deliverables", "Yesterday"),
            _noteCard("Ideas", "New app features: dark mode, notifications",
                "2 days ago"),
            _noteCard("Reminders", "Call dentist, Pay bills, Book flight",
                "3 days ago"),
            _noteCard("Recipe", "Ingredients: pasta, tomato sauce, cheese",
                "1 week ago"),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _noteCard(String title, String content, String date) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              date,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
