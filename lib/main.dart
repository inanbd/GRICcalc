import 'package:flutter/material.dart';

import 'logic/settings_store.dart';
import 'screens/calculator_screen.dart';
import 'logic/patient_store.dart';
import 'theme.dart';

void main() => runApp(const GirCalculatorApp());

class GirCalculatorApp extends StatefulWidget {
  const GirCalculatorApp({super.key, this.store, this.settings});

  /// Injected by tests so they can drive storage; the app builds its own.
  final PatientStore? store;
  final SettingsStore? settings;

  @override
  State<GirCalculatorApp> createState() => _GirCalculatorAppState();
}

class _GirCalculatorAppState extends State<GirCalculatorApp> {
  late final SettingsStore _settings = widget.settings ?? SettingsStore();
  late final bool _ownsSettings = widget.settings == null;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
    if (!_settings.isLoaded) _settings.load();
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    if (_ownsSettings) _settings.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NICU GIR Calculator',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: _settings.themeMode,
      home: CalculatorScreen(store: widget.store, settings: _settings),
    );
  }
}
