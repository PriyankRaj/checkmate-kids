import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'board_theme.dart';

/// Calm, restrained palette for the main game, puzzles, and analysis board.
ThemeData buildClassicTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2E3A46),
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFFF4F1EC),
    textTheme: GoogleFonts.sourceSerif4TextTheme().copyWith(
      titleLarge: GoogleFonts.sourceSerif4(
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Color(0xFF2E3A46),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    extensions: [BoardTheme.classic],
  );
}
