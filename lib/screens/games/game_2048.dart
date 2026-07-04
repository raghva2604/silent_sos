import 'package:flutter/material.dart';
import 'dart:math';

class Game2048 extends StatefulWidget {
  const Game2048({super.key});

  @override
  State<Game2048> createState() => _Game2048State();
}

class _Game2048State extends State<Game2048> {
  late List<List<int>> board;
  int score = 0;
  bool gameOver = false;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  void _initializeGame() {
    board = List.generate(4, (_) => List.filled(4, 0));
    _addNewTile();
    _addNewTile();
    score = 0;
    gameOver = false;
  }

  void _addNewTile() {
    final emptyTiles = <Offset>[];
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        if (board[i][j] == 0) {
          emptyTiles.add(Offset(i.toDouble(), j.toDouble()));
        }
      }
    }

    if (emptyTiles.isNotEmpty) {
      final randomTile = emptyTiles[Random().nextInt(emptyTiles.length)];
      board[randomTile.dx.toInt()][randomTile.dy.toInt()] =
          Random().nextBool() ? 2 : 4;
    }
  }

  void _moveLeft() {
    bool changed = false;
    for (int i = 0; i < 4; i++) {
      // Compress
      for (int j = 0; j < 4; j++) {
        for (int k = j + 1; k < 4; k++) {
          if (board[i][j] == 0 && board[i][k] != 0) {
            board[i][j] = board[i][k];
            board[i][k] = 0;
            changed = true;
          }
        }
      }

      // Merge
      for (int j = 0; j < 3; j++) {
        if (board[i][j] != 0 && board[i][j] == board[i][j + 1]) {
          board[i][j] *= 2;
          score += board[i][j];
          board[i][j + 1] = 0;
          changed = true;
        }
      }

      // Compress again
      for (int j = 0; j < 4; j++) {
        for (int k = j + 1; k < 4; k++) {
          if (board[i][j] == 0 && board[i][k] != 0) {
            board[i][j] = board[i][k];
            board[i][k] = 0;
          }
        }
      }
    }
    if (changed) {
      setState(() {
        _addNewTile();
        _checkGameOver();
      });
    }
  }

  void _moveRight() {
    bool changed = false;
    for (int i = 0; i < 4; i++) {
      // Compress
      for (int j = 3; j >= 0; j--) {
        for (int k = j - 1; k >= 0; k--) {
          if (board[i][j] == 0 && board[i][k] != 0) {
            board[i][j] = board[i][k];
            board[i][k] = 0;
            changed = true;
          }
        }
      }

      // Merge
      for (int j = 3; j > 0; j--) {
        if (board[i][j] != 0 && board[i][j] == board[i][j - 1]) {
          board[i][j] *= 2;
          score += board[i][j];
          board[i][j - 1] = 0;
          changed = true;
        }
      }

      // Compress again
      for (int j = 3; j >= 0; j--) {
        for (int k = j - 1; k >= 0; k--) {
          if (board[i][j] == 0 && board[i][k] != 0) {
            board[i][j] = board[i][k];
            board[i][k] = 0;
          }
        }
      }
    }
    if (changed) {
      setState(() {
        _addNewTile();
        _checkGameOver();
      });
    }
  }

  void _moveUp() {
    bool changed = false;
    for (int j = 0; j < 4; j++) {
      // Compress
      for (int i = 0; i < 4; i++) {
        for (int k = i + 1; k < 4; k++) {
          if (board[i][j] == 0 && board[k][j] != 0) {
            board[i][j] = board[k][j];
            board[k][j] = 0;
            changed = true;
          }
        }
      }

      // Merge
      for (int i = 0; i < 3; i++) {
        if (board[i][j] != 0 && board[i][j] == board[i + 1][j]) {
          board[i][j] *= 2;
          score += board[i][j];
          board[i + 1][j] = 0;
          changed = true;
        }
      }

      // Compress again
      for (int i = 0; i < 4; i++) {
        for (int k = i + 1; k < 4; k++) {
          if (board[i][j] == 0 && board[k][j] != 0) {
            board[i][j] = board[k][j];
            board[k][j] = 0;
          }
        }
      }
    }
    if (changed) {
      setState(() {
        _addNewTile();
        _checkGameOver();
      });
    }
  }

  void _moveDown() {
    bool changed = false;
    for (int j = 0; j < 4; j++) {
      // Compress
      for (int i = 3; i >= 0; i--) {
        for (int k = i - 1; k >= 0; k--) {
          if (board[i][j] == 0 && board[k][j] != 0) {
            board[i][j] = board[k][j];
            board[k][j] = 0;
            changed = true;
          }
        }
      }

      // Merge
      for (int i = 3; i > 0; i--) {
        if (board[i][j] != 0 && board[i][j] == board[i - 1][j]) {
          board[i][j] *= 2;
          score += board[i][j];
          board[i - 1][j] = 0;
          changed = true;
        }
      }

      // Compress again
      for (int i = 3; i >= 0; i--) {
        for (int k = i - 1; k >= 0; k--) {
          if (board[i][j] == 0 && board[k][j] != 0) {
            board[i][j] = board[k][j];
            board[k][j] = 0;
          }
        }
      }
    }
    if (changed) {
      setState(() {
        _addNewTile();
        _checkGameOver();
      });
    }
  }

  void _checkGameOver() {
    // Check if any moves are possible
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        if (board[i][j] == 0) return; // Empty space available

        // Check right
        if (j < 3 && board[i][j] == board[i][j + 1]) return;
        // Check down
        if (i < 3 && board[i][j] == board[i + 1][j]) return;
      }
    }
    gameOver = true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('💀 Game Over! Score: $score'),
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.red,
      ),
    );
  }

  Color _getTileColor(int value) {
    if (value == 0) return Colors.grey[300]!;
    if (value == 2) return Colors.orange[100]!;
    if (value == 4) return Colors.orange[200]!;
    if (value == 8) return Colors.orange[300]!;
    if (value == 16) return Colors.orange[400]!;
    if (value == 32) return Colors.orange[500]!;
    if (value == 64) return Colors.orange[600]!;
    if (value == 128) return Colors.yellow[600]!;
    if (value == 256) return Colors.yellow[700]!;
    if (value == 512) return Colors.yellow[800]!;
    if (value == 1024) return Colors.green[600]!;
    if (value == 2048) return Colors.green[700]!;
    return Colors.green[800]!;
  }

  Color _getTextColor(int value) {
    return value <= 4 ? Colors.black : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('2️⃣0️⃣4️⃣8️⃣ Game'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                'Score: $score',
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
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 16,
              itemBuilder: (context, index) {
                final row = index ~/ 4;
                final col = index % 4;
                final value = board[row][col];

                return Container(
                  decoration: BoxDecoration(
                    color: _getTileColor(value),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: value == 0
                        ? const SizedBox.shrink()
                        : Text(
                            '$value',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _getTextColor(value),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            gameOver ? '💀 Game Over!' : 'Swipe to move tiles',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: gameOver ? Colors.red : Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 32),
                onPressed: gameOver ? null : _moveUp,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 32),
                    onPressed: gameOver ? null : _moveLeft,
                  ),
                  const SizedBox(width: 40),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward, size: 32),
                    onPressed: gameOver ? null : _moveRight,
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward, size: 32),
                onPressed: gameOver ? null : _moveDown,
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _initializeGame();
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('New Game'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}
