import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers how the app should look, so the choice survives a restart.
class SettingsStore extends ChangeNotifier {
  static const String _themeKey = 'settings.themeMode.v1';

  SharedPreferences? _prefs;
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoaded = false;

  ThemeMode get themeMode => _themeMode;
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final String? stored = _prefs!.getString(_themeKey);
    _themeMode = ThemeMode.values.firstWhere(
      (ThemeMode mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _prefs?.setString(_themeKey, mode.name);
  }
}

/// The label and icon shown for each mode in the picker.
extension ThemeModeDisplay on ThemeMode {
  String get label => switch (this) {
    ThemeMode.system => 'Match device',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  /// The next mode when cycling from the app bar: device, then light, then
  /// dark, then back. Enough for a one-tap switch on a night shift.
  ThemeMode get next => switch (this) {
    ThemeMode.system => ThemeMode.light,
    ThemeMode.light => ThemeMode.dark,
    ThemeMode.dark => ThemeMode.system,
  };

  IconData get icon => switch (this) {
    ThemeMode.system => Icons.brightness_auto_outlined,
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
  };
}
