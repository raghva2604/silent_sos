import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ui_mode_service.dart';
import '../core/ui_modes.dart';
import '../widgets/disguise_wrapper.dart';

import 'games/puzzle_game.dart';
import 'games/snake_game.dart';
import 'games/memory_game.dart';
import 'games/game_2048.dart';

class GameHomeScreen extends StatelessWidget {
  const GameHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DisguiseWrapper(
      child: DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: const Text("Games"),
            leading: IconButton(
              icon: const Icon(Icons.security),
              tooltip: 'Return to safety',
              onPressed: () {
                // switch back to safety UI
                context.read<UIModeService>().changeMode(AppUIMode.safety);
              },
            ),
            bottom: const TabBar(
              tabs: [
                Tab(text: "Puzzle"),
                Tab(text: "Snake"),
                Tab(text: "Memory"),
                Tab(text: "2048"),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              PuzzleGame(),
              SnakeGame(),
              MemoryGame(),
              Game2048(),
            ],
          ),
        ),
      ),
    );
  }
}
