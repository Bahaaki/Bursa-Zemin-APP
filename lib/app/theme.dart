import 'package:flutter/material.dart';

/// App theme configuration for Bursa Zemin.
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      colorSchemeSeed: Colors.teal,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: const CardTheme(
        elevation: 1,
        margin: EdgeInsets.all(8),
      ),
    );
  }
}
