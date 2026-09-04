import 'package:flutter/material.dart';

import 'logic/patient_store.dart';
import 'screens/calculator_screen.dart';
import 'theme.dart';

void main() => runApp(const GirCalculatorApp());

class GirCalculatorApp extends StatelessWidget {
  const GirCalculatorApp({super.key, this.store});

  /// Injected by tests so they can drive storage; the screen builds its own.
  final PatientStore? store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NICU GIR Calculator',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: CalculatorScreen(store: store),
    );
  }
}
