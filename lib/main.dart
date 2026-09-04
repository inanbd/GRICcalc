import 'package:flutter/material.dart';

import 'screens/calculator_screen.dart';
import 'theme.dart';

void main() => runApp(const GirCalculatorApp());

class GirCalculatorApp extends StatelessWidget {
  const GirCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NICU GIR Calculator',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const CalculatorScreen(),
    );
  }
}
