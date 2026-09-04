import 'package:flutter/material.dart';

import 'logic/gir_calculator.dart';

/// A calm clinical palette: teal for the app, and a fixed set of status colours
/// that keep the same meaning in light and dark mode.
ThemeData buildTheme(Brightness brightness) {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF00696E),
    brightness: brightness,
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      margin: EdgeInsets.zero,
    ),
  );
}

/// Colours used to flag a glucose infusion rate. Deliberately not the seed
/// colour, so a warning never blends into the app's own chrome, and lightened
/// on dark backgrounds where the deep shades lose their contrast.
class StatusColors {
  const StatusColors._();

  static const Color _neutralLight = Color(0xFF5F6368);
  static const Color _neutralDark = Color(0xFFA8B0B8);
  static const Color _cautionLight = Color(0xFF9A5B00);
  static const Color _cautionDark = Color(0xFFF0AE4E);
  static const Color _goodLight = Color(0xFF1B7F4B);
  static const Color _goodDark = Color(0xFF5FD597);
  static const Color _alertLight = Color(0xFFB3261E);
  static const Color _alertDark = Color(0xFFFF8A80);

  static Color neutral(Brightness b) => _pick(b, _neutralLight, _neutralDark);
  static Color caution(Brightness b) => _pick(b, _cautionLight, _cautionDark);
  static Color good(Brightness b) => _pick(b, _goodLight, _goodDark);
  static Color alert(Brightness b) => _pick(b, _alertLight, _alertDark);

  static Color _pick(Brightness b, Color light, Color dark) =>
      b == Brightness.dark ? dark : light;
}

/// The colour used to flag a total GIR, matching [GirBand]'s meaning.
Color colorForBand(GirBand band, Brightness brightness) {
  return switch (band) {
    GirBand.none => StatusColors.neutral(brightness),
    GirBand.low => StatusColors.caution(brightness),
    GirBand.maintenance => StatusColors.good(brightness),
    GirBand.elevated => StatusColors.caution(brightness),
    GirBand.high => StatusColors.alert(brightness),
  };
}

/// Distinct colours for the per-line contribution bar, reused cyclically.
const List<Color> fluidPalette = <Color>[
  Color(0xFF00696E),
  Color(0xFF7B5BA6),
  Color(0xFFB26A00),
  Color(0xFF1B7F4B),
  Color(0xFF9E4A6B),
  Color(0xFF3F6BB0),
];

Color fluidColor(int index) => fluidPalette[index % fluidPalette.length];
