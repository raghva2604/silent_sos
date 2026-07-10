import 'package:flutter/material.dart';
import '../../widgets/disguise_wrapper.dart';

class ShoppingUI extends StatelessWidget {
  const ShoppingUI({super.key});

  @override
  Widget build(BuildContext context) {
    return DisguiseWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("ShopHub"),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.shopping_cart),
              onPressed: () {},
            ),
          ],
        ),
        body: GridView.count(
          crossAxisCount: 2,
          padding: const EdgeInsets.all(16),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _productCard("Wireless Headphones", Icons.headphones),
            _productCard("Smart Watch", Icons.watch),
            _productCard("Gaming Mouse", Icons.mouse),
            _productCard("Bluetooth Speaker", Icons.speaker),
            _productCard("Phone Case", Icons.phone_android),
            _productCard("Laptop Stand", Icons.laptop),
          ],
        ),
      ),
    );
  }

  Widget _productCard(String name, IconData icon) {
    return Card(
      elevation: 4,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.blue),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            "\$99.99",
            style: TextStyle(
                color: Colors.green[700], fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
