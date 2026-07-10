import 'package:flutter/material.dart';

final ThemeData futuristicTheme = ThemeData.dark().copyWith(
  primaryColor: const Color(0xFF00FFD5),
  scaffoldBackgroundColor: const Color(0xFF03030A),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.6,
      color: Colors.white,
    ),
  ),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF00FFD5),
    secondary: Color(0xFF7C4DFF),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF00FFD5).withAlpha((0.14 * 255).round()),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: const Color(0xFF00FFD5)),
  ),
  cardColor: const Color(0xFF071029),
);
