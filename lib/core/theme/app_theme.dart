import 'package:flutter/material.dart';

class AppTheme {
  static final lightTheme = ThemeData(
    fontFamily: 'Inter',
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF44627F),
      primaryContainer: Color(0xFFB9D7FA),
      tertiary: Color(0xFFC7B1E6),
      tertiaryContainer: Color(0xFFE1D0F8),
      surface: Color(0xFFF8F9FA),
      onSurface: Color(0xFF2D3335),
      onSurfaceVariant: Color(0xFF5A6062),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF1F4F5),
      surfaceContainerHighest: Color(0xFFDEE3E6),
      outlineVariant: Color(0xFFADB3B5),
    ),
    scaffoldBackgroundColor: const Color(0xFFF8F9FA),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Color(0xFF2D3335)),
      titleTextStyle: TextStyle(color: Color(0xFF2D3335), fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.02),
    ),
    dividerTheme: const DividerThemeData(color: Colors.transparent, space: 0, thickness: 0),
    useMaterial3: true,
  );

  static final darkTheme = ThemeData(
    fontFamily: 'Inter',
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF7193B5),
      primaryContainer: Color(0xFF2A3A4C),
      tertiary: Color(0xFFC7B1E6),
      tertiaryContainer: Color(0xFF44345F),
      surface: Color(0xFF0F1214), // Dark base
      onSurface: Color(0xFFE2E8EA),
      onSurfaceVariant: Color(0xFF8F9B9F),
      surfaceContainerLowest: Color(0xFF272F33), // Focus card
      surfaceContainerLow: Color(0xFF15191C), // Deep card background
      surfaceContainerHighest: Color(0xFF1F2529),
      outlineVariant: Color(0xFF4A5255),
    ),
    scaffoldBackgroundColor: const Color(0xFF0F1214),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Color(0xFFE2E8EA)),
      titleTextStyle: TextStyle(color: Color(0xFFE2E8EA), fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.02),
    ),
    dividerTheme: const DividerThemeData(color: Colors.transparent, space: 0, thickness: 0),
    useMaterial3: true,
  );
}
