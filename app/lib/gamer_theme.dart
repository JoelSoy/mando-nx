// Shared console-inspired surfaces. Cyan and coral identify the two sides; branding is Mando NX's own.
import 'package:flutter/material.dart';

import 'classic_theme.dart' as classic;
import 'visual_style.dart';
export 'visual_style.dart';

ThemeData themeFor(VisualStyle style) =>
    style == VisualStyle.gamer ? classic.gamerTheme() : gamerTheme();
Widget backdropFor(VisualStyle style) => style == VisualStyle.gamer
    ? const classic.GridBackdrop(child: SizedBox.expand())
    : const GridBackdrop(child: SizedBox.expand());

const ink = Color(0xFF171A20),
    panel = Color(0xFF252A33),
    cyan = Color(0xFF34D5E5),
    coral = Color(0xFFFF736C),
    lime = Color(0xFFCEEFA0),
    muted = Color(0xFF98A2B1);
ThemeData gamerTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: ink,
  colorScheme: const ColorScheme.dark(
    primary: cyan,
    secondary: coral,
    surface: panel,
  ),
  fontFamily: 'Arial',
  textTheme: const TextTheme(
    bodyMedium: TextStyle(height: 1.3),
    labelLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: .2),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF1C2028),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    labelStyle: const TextStyle(color: muted, fontSize: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF3A414E)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF3A414E)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: cyan, width: 1.5),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: cyan,
      foregroundColor: ink,
      minimumSize: const Size(0, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFF515A69)),
      minimumSize: const Size(0, 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: panel,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
  ),
  chipTheme: const ChipThemeData(
    backgroundColor: ink,
    selectedColor: Color(0xFF22525A),
    side: BorderSide(color: Color(0xFF49515E)),
  ),
  dividerTheme: const DividerThemeData(color: Color(0xFF3A414E)),
);

class GridBackdrop extends StatelessWidget {
  const GridBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF303640), ink, Color(0xFF202A31)],
      ),
    ),
    child: child,
  );
}
