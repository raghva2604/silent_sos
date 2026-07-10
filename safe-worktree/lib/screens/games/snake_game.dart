import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

class SnakeGame extends StatefulWidget {
  const SnakeGame({super.key});

  @override
  State<SnakeGame> createState() => _SnakeGameState();
}

class _SnakeGameState extends State<SnakeGame> {
  final int gridSize = 10;
  late List<Offset> snake;
  late Offset food;
  late Offset direction;
  late Offset nextDirection;
  bool gameOver = false;
  int score = 0;
  late Timer gameTimer;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  void _initializeGame() {
    snake = [const Offset(5, 5), const Offset(4, 5), const Offset(3, 5)];
    direction = const Offset(1, 0);
    nextDirection = const Offset(1, 0);
    food = _generateFood();
    gameOver = false;
    score = 0;
    gameTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _update();
    });
  }

  Offset _generateFood() {
    final random = Random();
    Offset newFood;
    do {
      newFood = Offset(
        random.nextInt(gridSize).toDouble(),
        random.nextInt(gridSize).toDouble(),
      );
    } while (snake.contains(newFood));
    return newFood;
  }

  void _update() {
    if (gameOver) return;

    direction = nextDirection;
    final newHead = Offset(
      (snake.first.dx + direction.dx) % gridSize,
      (snake.first.dy + direction.dy) % gridSize,
    );

    if (snake.contains(newHead)) {
      setState(() {
        gameOver = true;
      });
      gameTimer.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('💀 Game Over! Score: $score'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      snake.insert(0, newHead);
      if (newHead == food) {
        score += 10;
        food = _generateFood();
      } else {
        snake.removeLast();
      }
    });
  }

  void _changeDirection(Offset newDir) {
    if ((direction.dx + newDir.dx != 0) || (direction.dy + newDir.dy != 0)) {
      nextDirection = newDir;
    }
  }

  @override
  void dispose() {
    gameTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🐍 Snake Game'),
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
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey, width: 2),
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                // Grid
                GridView.builder(
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridSize,
                  ),
                  itemCount: gridSize * gridSize,
                  itemBuilder: (context, index) {
                    return Container(
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: Colors.grey[800]!, width: 0.5),
                      ),
                    );
                  },
                ),
                // Snake
                ...snake.map((segment) {
                  return Positioned(
                    left: segment.dx * 30,
                    top: segment.dy * 30,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: segment == snake.first
                            ? Colors.green
                            : Colors.lightGreen,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
                // Food
                Positioned(
                  left: food.dx * 30,
                  top: food.dy * 30,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            gameOver ? '💀 Game Over!' : 'Use arrow buttons to move',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: gameOver ? Colors.red : Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          // Direction controls
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 32),
                onPressed: () => _changeDirection(const Offset(0, -1)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 32),
                    onPressed: () => _changeDirection(const Offset(-1, 0)),
                  ),
                  const SizedBox(width: 40),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward, size: 32),
                    onPressed: () => _changeDirection(const Offset(1, 0)),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward, size: 32),
                onPressed: () => _changeDirection(const Offset(0, 1)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              gameTimer.cancel();
              setState(() {
                _initializeGame();
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('New Game'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}
