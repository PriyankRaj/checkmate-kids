import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'board_theme.dart';

/// Bright, high-contrast, big-touch-target palette for tutorials and
/// challenges.
ThemeData buildKidsTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFFF8A65),
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFFFFF8EE),
    textTheme: GoogleFonts.baloo2TextTheme().copyWith(
      titleLarge: GoogleFonts.baloo2(fontSize: 26, fontWeight: FontWeight.w700),
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Color(0xFFB5490C),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        textStyle: GoogleFonts.baloo2(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    extensions: [BoardTheme.kids],
  );
}
