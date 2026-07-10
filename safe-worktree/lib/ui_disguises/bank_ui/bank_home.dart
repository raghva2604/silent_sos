import 'package:flutter/material.dart';
import '../../widgets/disguise_wrapper.dart';

class BankUI extends StatelessWidget {
  const BankUI({super.key});

  @override
  Widget build(BuildContext context) {
    return DisguiseWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("SecureBank"),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {},
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Balance Card
              Card(
                elevation: 8,
                color: Colors.blue[700],
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Current Balance",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "\$2,450.67",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _actionButton("Transfer", Icons.send),
                          _actionButton("Pay", Icons.payment),
                          _actionButton("More", Icons.more_vert),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Recent Transactions
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Recent Transactions",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        children: [
                          _transactionItem(
                              "Grocery Store", "-\$45.20", "Today"),
                          _transactionItem(
                              "Salary Deposit", "+\$2,500.00", "Yesterday"),
                          _transactionItem(
                              "Coffee Shop", "-\$5.50", "2 days ago"),
                          _transactionItem(
                              "Online Purchase", "-\$89.99", "3 days ago"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  Widget _transactionItem(String title, String amount, String date) {
    final isPositive = amount.startsWith('+');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isPositive ? Colors.green[100] : Colors.red[100],
        child: Icon(
          isPositive ? Icons.arrow_downward : Icons.arrow_upward,
          color: isPositive ? Colors.green : Colors.red,
        ),
      ),
      title: Text(title),
      subtitle: Text(date),
      trailing: Text(
        amount,
        style: TextStyle(
          color: isPositive ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
