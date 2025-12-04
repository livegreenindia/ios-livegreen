import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF019863),
      brightness: Brightness.light,
    ),
    textTheme: GoogleFonts.manropeTextTheme(),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF019863),
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF0F231C), // matches background-dark
    textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme),
  );
}
