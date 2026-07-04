import 'package:flutter/material.dart';
import 'dart:math';

class PuzzleGame extends StatefulWidget {
  const PuzzleGame({super.key});

  @override
  State<PuzzleGame> createState() => _PuzzleGameState();
}

class _PuzzleGameState extends State<PuzzleGame> {
  late List<int> tiles;
  int moves = 0;
  bool won = false;

  @override
  void initState() {
    super.initState();
    _initializePuzzle();
  }

  void _initializePuzzle() {
    tiles = List.generate(9, (i) => i);
    _shufflePuzzle();
    moves = 0;
    won = false;
  }

  void _shufflePuzzle() {
    final random = Random();
    for (int i = 0; i < 100; i++) {
      final emptyIndex = tiles.indexOf(0);
      final neighbors = _getValidNeighbors(emptyIndex);
      final neighbor = neighbors[random.nextInt(neighbors.length)];
      _swapTiles(emptyIndex, neighbor);
    }
  }

  List<int> _getValidNeighbors(int index) {
    final neighbors = <int>[];
    // Up
    if (index >= 3) neighbors.add(index - 3);
    // Down
    if (index < 6) neighbors.add(index + 3);
    // Left
    if (index % 3 != 0) neighbors.add(index - 1);
    // Right
    if (index % 3 != 2) neighbors.add(index + 1);
    return neighbors;
  }

  void _swapTiles(int a, int b) {
    final temp = tiles[a];
    tiles[a] = tiles[b];
    tiles[b] = temp;
  }

  void _tilePressed(int index) {
    if (won) return;

    final emptyIndex = tiles.indexOf(0);
    if (_getValidNeighbors(emptyIndex).contains(index)) {
      setState(() {
        _swapTiles(index, emptyIndex);
        moves++;
        _checkWin();
      });
    }
  }

  void _checkWin() {
    won = true;
    for (int i = 0; i < 9; i++) {
      if (tiles[i] != i) {
        won = false;
        break;
      }
    }
    if (won) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Puzzle solved in $moves moves!'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧩 Puzzle Game'),
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
      body: MaxWidthConstraint(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                buildPuzzleGrid(),
                const SizedBox(height: 24),
                Text(
                  won ? '🎉 You Won!' : 'Arrange tiles in order',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: won ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _initializePuzzle();
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('New Game'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildPuzzleGrid() {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        padding: const EdgeInsets.all(4),
        itemCount: 9,
        itemBuilder: (context, index) {
          final tile = tiles[index];
          return GestureDetector(
            onTap: () => _tilePressed(index),
            child: Container(
              decoration: BoxDecoration(
                color: tile == 0 ? Colors.transparent : Colors.blue,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: tile == 0
                    ? const SizedBox.shrink()
                    : Text(
                        '$tile',
                        style: const TextStyle(
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
    );
  }
}

class MaxWidthConstraint extends StatelessWidget {
  final Widget child;

  const MaxWidthConstraint({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
