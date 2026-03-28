import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const seedColor = Color(0xFFD97706);

final lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.light,
  ),
  textTheme: GoogleFonts.beVietnamProTextTheme(),
  scaffoldBackgroundColor: const Color(0xFFF7F9F8),
);

final darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
  ),
  textTheme: GoogleFonts.beVietnamProTextTheme(),
  scaffoldBackgroundColor: const Color(0xFF0B1220),
);
