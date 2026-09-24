import 'package:flutter/material.dart';
import 'core/constants.dart';

void main() {
  runApp(const BursaZeminApp());
}

class BursaZeminApp extends StatelessWidget {
  const BursaZeminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text(kAppName, style: TextStyle(fontSize: 24)),
        ),
      ),
    );
  }
}
