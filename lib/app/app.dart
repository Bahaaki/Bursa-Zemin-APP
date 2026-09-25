import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../features/splash/splash_screen.dart';
import 'theme.dart';

/// Root application widget for Bursa Zemin.
class BursaZeminApp extends StatelessWidget {
  const BursaZeminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
