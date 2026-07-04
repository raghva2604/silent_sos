import 'package:flutter/material.dart';
import '../../widgets/disguise_wrapper.dart';
import '../../screens/game_home_screen.dart';

/// Game UI disguise.
class GameUI extends StatelessWidget {
  const GameUI({super.key});

  @override
  Widget build(BuildContext context) {
    return const DisguiseWrapper(
      child: GameHomeScreen(),
    );
  }
}
