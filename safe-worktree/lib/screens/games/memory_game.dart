import 'package:flutter/material.dart';
import 'dart:math';

class MemoryGame extends StatefulWidget {
  const MemoryGame({super.key});

  @override
  State<MemoryGame> createState() => _MemoryGameState();
}

class _MemoryGameState extends State<MemoryGame> {
  late List<int> cards;
  late List<bool> revealed;
  late List<bool> matched;
  int? firstCard;
  int? secondCard;
  int moves = 0;
  int matchedCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  void _initializeGame() {
    cards = List.generate(16, (i) => i ~/ 2);
    cards.shuffle(Random());
    revealed = List.filled(16, false);
    matched = List.filled(16, false);
    firstCard = null;
    secondCard = null;
    moves = 0;
    matchedCount = 0;
  }

  void _cardPressed(int index) {
    // Allow first card to be chosen; only prevent interaction when two cards are already open
    if (revealed[index] || matched[index]) return;
    if (firstCard != null && secondCard != null) return;

    setState(() {
      revealed[index] = true;

      if (firstCard == null) {
        firstCard = index;
      } else if (secondCard == null) {
        secondCard = index;
        moves++;

        if (cards[firstCard!] == cards[secondCard!]) {
          matched[firstCard!] = true;
          matched[secondCard!] = true;
          matchedCount += 2;
          firstCard = null;
          secondCard = null;

          if (matchedCount == 16) {
            Future.delayed(const Duration(milliseconds: 500), () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🎉 You won in $moves moves!'),
                  duration: const Duration(seconds: 3),
                  backgroundColor: Colors.green,
                ),
              );
            });
          }
        } else {
          Future.delayed(const Duration(milliseconds: 800), () {
            setState(() {
              revealed[firstCard!] = false;
              revealed[secondCard!] = false;
              firstCard = null;
              secondCard = null;
            });
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧠 Memory Game'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                'Moves: $moves',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 16,
                  itemBuilder: (context, index) {
                    final isMatched = matched[index];
                    final isRevealed = revealed[index];

                    return GestureDetector(
                      onTap: () => _cardPressed(index),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isMatched
                              ? Colors.green[300]
                              : isRevealed
                                  ? Colors.blue
                                  : Colors.purple[300],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: Center(
                          child: isMatched || isRevealed
                              ? Text(
                                  _getEmoji(cards[index]),
                                  style: const TextStyle(fontSize: 32),
                                )
                              : const Text(
                                  '?',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  matchedCount == 16 ? '🎉 You Won!' : 'Match all pairs',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: matchedCount == 16 ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _initializeGame();
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('New Game'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getEmoji(int value) {
    const emojis = ['🌟', '🎈', '🎮', '🍎', '🎄', '🏆', '🎯', '🚀'];
    return emojis[value % emojis.length];
  }
}
