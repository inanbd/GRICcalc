import 'package:flutter/foundation.dart';

import '../models/fluid_input.dart';

/// Where a glucose infusion rate sits against usual neonatal practice.
enum GirBand {
  none('No glucose', 'No dextrose-containing fluid is running.'),
  low(
    'Below maintenance',
    'Lower than the usual neonatal maintenance range of 4-8 mg/kg/min.',
  ),
  maintenance(
    'Maintenance range',
    'Within the usual neonatal maintenance range of 4-8 mg/kg/min.',
  ),
  elevated(
    'Elevated',
    'Above maintenance. Commonly used when treating hypoglycaemia.',
  ),
  high(
    'High',
    'At or above 12 mg/kg/min. Persistent need at this level warrants a work-up '
        'for hyperinsulinism and review of access and concentration.',
  );

  const GirBand(this.label, this.description);

  final String label;
  final String description;
}

/// One infusion line with everything derived from it.
@immutable
class FluidResult {
  const FluidResult({
    required this.fluid,
    required this.mlPerHour,
    required this.mlPerKgPerDay,
    required this.gir,
    required this.glucoseGramsPerDay,
    required this.girShare,
  });

  final FluidInput fluid;

  /// Pump rate in mL/hr.
  final double mlPerHour;

  /// Daily volume in mL/kg/day.
  final double mlPerKgPerDay;

  /// Glucose infusion rate contributed by this line, in mg/kg/min.
  final double gir;

  /// Grams of dextrose this line delivers over 24 hours.
  final double glucoseGramsPerDay;

  /// This line's share of the total GIR, 0.0-1.0.
  final double girShare;
}

/// Every total the calculator reports, for one weight and set of fluids.
@immutable
class GirSummary {
  const GirSummary({
    required this.weightKg,
    required this.isValid,
    required this.fluids,
    required this.totalGir,
    required this.totalMlPerHour,
    required this.totalMlPerKgPerDay,
    required this.totalGlucoseGramsPerDay,
    required this.meanDextrosePercent,
  });

  /// A summary for a weight that has not been entered yet, or is not usable.
  const GirSummary.empty()
    : weightKg = 0,
      isValid = false,
      fluids = const <FluidResult>[],
      totalGir = 0,
      totalMlPerHour = 0,
      totalMlPerKgPerDay = 0,
      totalGlucoseGramsPerDay = 0,
      meanDextrosePercent = null;

  final double weightKg;

  /// False when the weight is missing or non-positive, so nothing is derivable.
  final bool isValid;

  final List<FluidResult> fluids;

  /// Combined glucose infusion rate, in mg/kg/min.
  final double totalGir;

  /// Combined pump rate, in mL/hr.
  final double totalMlPerHour;

  /// Combined daily volume, in mL/kg/day.
  final double totalMlPerKgPerDay;

  /// Combined dextrose delivered over 24 hours, in grams.
  final double totalGlucoseGramsPerDay;

  /// Volume-weighted dextrose concentration of everything running, as a
  /// percentage. Null when no volume is running.
  final double? meanDextrosePercent;

  GirBand get band => girBandFor(totalGir);

  /// Lines running a dextrose concentration above [peripheralDextroseLimit].
  List<FluidResult> get linesAbovePeripheralLimit => fluids
      .where(
        (FluidResult r) =>
            r.fluid.dextrosePercent > peripheralDextroseLimit &&
            r.mlPerHour > 0,
      )
      .toList(growable: false);
}

/// Dextrose concentrations above this are generally given centrally rather
/// than through a peripheral line.
const double peripheralDextroseLimit = 12.5;

/// Classifies a glucose infusion rate against usual neonatal practice.
GirBand girBandFor(double gir) {
  if (!gir.isFinite || gir <= 0) return GirBand.none;
  if (gir < 4) return GirBand.low;
  if (gir < 8) return GirBand.maintenance;
  if (gir < 12) return GirBand.elevated;
  return GirBand.high;
}

/// Converts a rate expressed in [unit] into mL/hr for a baby of [weightKg].
double toMlPerHour(double value, RateUnit unit, double weightKg) {
  return switch (unit) {
    RateUnit.mlPerHour => value,
    RateUnit.mlPerKgPerDay => value * weightKg / 24,
  };
}

/// Converts a rate expressed in [unit] into mL/kg/day for a baby of [weightKg].
double toMlPerKgPerDay(double value, RateUnit unit, double weightKg) {
  if (weightKg <= 0) return 0;
  return switch (unit) {
    RateUnit.mlPerHour => value * 24 / weightKg,
    RateUnit.mlPerKgPerDay => value,
  };
}

/// Glucose infusion rate in mg/kg/min for one line.
///
/// A `%` dextrose solution carries that many grams per 100 mL, so:
///
///   mg/kg/min = mL/hr x (% / 100 g/mL) x 1000 mg/g / 60 min/hr / kg
///             = mL/hr x % / (6 x kg)
double girFor({
  required double mlPerHour,
  required double dextrosePercent,
  required double weightKg,
}) {
  if (weightKg <= 0) return 0;
  return (mlPerHour * dextrosePercent) / (6 * weightKg);
}

/// Runs the full calculation for [weightGrams] and every line in [fluids].
///
/// Returns [GirSummary.empty] when the weight is missing or non-positive -
/// without a weight none of the per-kilogram figures mean anything.
GirSummary summarise({
  required double? weightGrams,
  required List<FluidInput> fluids,
}) {
  if (weightGrams == null || !weightGrams.isFinite || weightGrams <= 0) {
    return const GirSummary.empty();
  }

  final double weightKg = weightGrams / 1000;

  double totalGir = 0;
  double totalMlPerHour = 0;
  double totalGlucoseGramsPerDay = 0;

  final List<_Partial> partials = <_Partial>[];
  for (final FluidInput fluid in fluids) {
    final double mlPerHour = _sanitise(
      toMlPerHour(fluid.rateValue, fluid.rateUnit, weightKg),
    );
    final double mlPerKgPerDay = _sanitise(
      toMlPerKgPerDay(fluid.rateValue, fluid.rateUnit, weightKg),
    );
    final double gir = _sanitise(
      girFor(
        mlPerHour: mlPerHour,
        dextrosePercent: fluid.dextrosePercent,
        weightKg: weightKg,
      ),
    );
    final double glucoseGramsPerDay = _sanitise(
      mlPerHour * 24 * fluid.dextrosePercent / 100,
    );

    totalGir += gir;
    totalMlPerHour += mlPerHour;
    totalGlucoseGramsPerDay += glucoseGramsPerDay;

    partials.add(
      _Partial(fluid, mlPerHour, mlPerKgPerDay, gir, glucoseGramsPerDay),
    );
  }

  final List<FluidResult> results = partials
      .map(
        (_Partial p) => FluidResult(
          fluid: p.fluid,
          mlPerHour: p.mlPerHour,
          mlPerKgPerDay: p.mlPerKgPerDay,
          gir: p.gir,
          glucoseGramsPerDay: p.glucoseGramsPerDay,
          girShare: totalGir > 0 ? p.gir / totalGir : 0,
        ),
      )
      .toList(growable: false);

  final double totalMlPerDay = totalMlPerHour * 24;

  return GirSummary(
    weightKg: weightKg,
    isValid: true,
    fluids: results,
    totalGir: totalGir,
    totalMlPerHour: totalMlPerHour,
    totalMlPerKgPerDay: _sanitise(totalMlPerDay / weightKg),
    totalGlucoseGramsPerDay: totalGlucoseGramsPerDay,
    meanDextrosePercent: totalMlPerDay > 0
        ? _sanitise(totalGlucoseGramsPerDay / totalMlPerDay * 100)
        : null,
  );
}

/// Keeps a stray NaN or infinity from a malformed entry out of the totals.
double _sanitise(double value) => value.isFinite ? value : 0;

class _Partial {
  _Partial(
    this.fluid,
    this.mlPerHour,
    this.mlPerKgPerDay,
    this.gir,
    this.glucoseGramsPerDay,
  );

  final FluidInput fluid;
  final double mlPerHour;
  final double mlPerKgPerDay;
  final double gir;
  final double glucoseGramsPerDay;
}
