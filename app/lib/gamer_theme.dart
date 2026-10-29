import 'package:flutter/material.dart';

const ink = Color(0xFF080D19),
    panel = Color(0xFF111B2C),
    cyan = Color(0xFF56E5EC),
    lime = Color(0xFFD1FA68);
ThemeData gamerTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: ink,
  colorScheme: const ColorScheme.dark(
    primary: cyan,
    secondary: lime,
    surface: panel,
  ),
  fontFamily: 'Arial',
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: panel,
    contentPadding: const EdgeInsets.all(16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF27344B)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF27344B)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: lime,
      foregroundColor: ink,
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
);

class GridBackdrop extends StatelessWidget {
  const GridBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext c) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF14233A), ink, Color(0xFF0E252B)],
      ),
    ),
    child: child,
  );
}
