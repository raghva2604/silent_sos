import 'package:flutter/material.dart';
import '../../widgets/disguise_wrapper.dart';

class InstagramUI extends StatelessWidget {
  const InstagramUI({super.key});

  @override
  Widget build(BuildContext context) {
    return DisguiseWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Instagram"),
          actions: [
            IconButton(
              icon: const Icon(Icons.favorite_border),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () {},
            ),
          ],
        ),
        body: Column(
          children: [
            // Stories
            Container(
              height: 100,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _storyItem("Your story", true),
                  _storyItem("Alice", false),
                  _storyItem("Bob", false),
                  _storyItem("Charlie", false),
                  _storyItem("Diana", false),
                ],
              ),
            ),
            const Divider(),
            // Posts
            Expanded(
              child: ListView(
                children: [
                  _postItem("Alice", "Beautiful sunset! 🌅", "2 hours ago"),
                  _postItem("Bob", "New recipe try! 🍝", "4 hours ago"),
                  _postItem("Charlie", "Weekend vibes 🎉", "6 hours ago"),
                  _postItem("Diana", "Travel goals ✈️", "1 day ago"),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
            BottomNavigationBarItem(icon: Icon(Icons.add_box), label: 'Add'),
            BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Likes'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
          currentIndex: 0,
          onTap: (index) {},
        ),
      ),
    );
  }

  Widget _storyItem(String name, bool isMe) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: isMe ? Colors.grey[300] : Colors.blue,
            child: isMe
                ? const Icon(Icons.add, color: Colors.black)
                : Text(name[0], style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _postItem(String username, String caption, String time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue,
            child: Text(username[0]),
          ),
          title: Text(username),
          trailing: const Icon(Icons.more_vert),
        ),
        // Image placeholder
        Container(
          height: 300,
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.image, size: 64, color: Colors.grey),
          ),
        ),
        // Actions
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              IconButton(
                  icon: const Icon(Icons.favorite_border), onPressed: () {}),
              IconButton(icon: const Icon(Icons.comment), onPressed: () {}),
              IconButton(icon: const Icon(Icons.send), onPressed: () {}),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.bookmark_border), onPressed: () {}),
            ],
          ),
        ),
        // Caption
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(caption,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(time,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
