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
    required this.countsTowardGir,
    required this.feedsPerDay,
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

  /// Whether [gir] was added to [GirSummary.totalGir]. A feed only counts when
  /// the clinician opts it in.
  final bool countsTowardGir;

  /// Feeds in 24 hours, for a line ordered as a volume every few hours.
  final double? feedsPerDay;

  bool get isFeed => fluid.isFeed;
}

/// Every total the calculator reports, for one weight and set of fluids.
@immutable
class GirSummary {
  const GirSummary({
    required this.weightKg,
    required this.isValid,
    required this.fluids,
    required this.totalGir,
    required this.ivGir,
    required this.enteralGir,
    required this.countedEnteralGir,
    required this.totalMlPerHour,
    required this.totalMlPerKgPerDay,
    required this.ivMlPerKgPerDay,
    required this.enteralMlPerKgPerDay,
    required this.totalGlucoseGramsPerDay,
    required this.meanDextrosePercent,
  });

  /// A summary for a weight that has not been entered yet, or is not usable.
  const GirSummary.empty()
    : weightKg = 0,
      isValid = false,
      fluids = const <FluidResult>[],
      totalGir = 0,
      ivGir = 0,
      enteralGir = 0,
      countedEnteralGir = 0,
      totalMlPerHour = 0,
      totalMlPerKgPerDay = 0,
      ivMlPerKgPerDay = 0,
      enteralMlPerKgPerDay = 0,
      totalGlucoseGramsPerDay = 0,
      meanDextrosePercent = null;

  final double weightKg;

  /// False when the weight is missing or non-positive, so nothing is derivable.
  final bool isValid;

  final List<FluidResult> fluids;

  /// The headline figure, in mg/kg/min: [ivGir] plus [countedEnteralGir].
  final double totalGir;

  /// Glucose from intravenous lines alone, in mg/kg/min. This is what "GIR"
  /// means without further qualification.
  final double ivGir;

  /// Carbohydrate delivered by every feed, in mg/kg/min, whether or not it is
  /// being counted. An estimate: feed composition varies.
  final double enteralGir;

  /// The part of [enteralGir] opted in to the total.
  final double countedEnteralGir;

  /// Combined rate of everything, in mL/hr. A feed contributes its average -
  /// 20 mL every 3 hours is 6.67 mL/hr.
  final double totalMlPerHour;

  /// Every route's volume, in mL/kg/day.
  final double totalMlPerKgPerDay;

  /// Intravenous volume alone, in mL/kg/day.
  final double ivMlPerKgPerDay;

  /// Fed volume alone, in mL/kg/day.
  final double enteralMlPerKgPerDay;

  /// Combined dextrose delivered over 24 hours, in grams.
  final double totalGlucoseGramsPerDay;

  /// Volume-weighted dextrose concentration of the intravenous lines, as a
  /// percentage. Null when nothing is infusing. Feeds are left out: the figure
  /// exists to be checked against what a peripheral line will take.
  final double? meanDextrosePercent;

  /// Whether any feed is on the list.
  bool get hasFeeds => fluids.any((FluidResult r) => r.isFeed);

  /// Whether a feed's carbohydrate is being counted in [totalGir], which makes
  /// the headline figure an estimate rather than a calculation.
  bool get countsFeedsInGir =>
      fluids.any((FluidResult r) => r.isFeed && r.countsTowardGir && r.gir > 0);

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

/// Converts a rate into mL/hr for a baby of [weightKg].
///
/// A bolus feed is averaged over the day: 20 mL every 3 hours is 8 feeds,
/// 160 mL, and so 6.67 mL/hr.
double toMlPerHour(
  double value,
  RateUnit unit,
  double weightKg, {
  double intervalHours = 3,
}) {
  return switch (unit) {
    RateUnit.mlPerHour => value,
    RateUnit.mlPerKgPerDay => value * weightKg / 24,
    RateUnit.mlPerFeed => intervalHours > 0 ? value / intervalHours : 0,
  };
}

/// Converts a rate into mL/kg/day for a baby of [weightKg].
double toMlPerKgPerDay(
  double value,
  RateUnit unit,
  double weightKg, {
  double intervalHours = 3,
}) {
  if (weightKg <= 0) return 0;
  return switch (unit) {
    RateUnit.mlPerHour => value * 24 / weightKg,
    RateUnit.mlPerKgPerDay => value,
    RateUnit.mlPerFeed =>
      intervalHours > 0 ? value * (24 / intervalHours) / weightKg : 0,
  };
}

/// Restates [fluid]'s rate in [unit], so switching units on a line leaves it
/// running at the same speed.
double convertRate(FluidInput fluid, RateUnit unit, double weightKg) {
  if (unit == fluid.rateUnit) return fluid.rateValue;
  final double mlPerHour = toMlPerHour(
    fluid.rateValue,
    fluid.rateUnit,
    weightKg,
    intervalHours: fluid.feedIntervalHours,
  );
  return switch (unit) {
    RateUnit.mlPerHour => mlPerHour,
    RateUnit.mlPerKgPerDay => weightKg > 0 ? mlPerHour * 24 / weightKg : 0,
    RateUnit.mlPerFeed => mlPerHour * fluid.feedIntervalHours,
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

  double ivGir = 0;
  double enteralGir = 0;
  double countedEnteralGir = 0;
  double totalMlPerHour = 0;
  double ivMlPerHour = 0;
  double enteralMlPerHour = 0;
  double totalGlucoseGramsPerDay = 0;
  double ivVolumePerDay = 0;
  double ivGlucoseGramsPerDay = 0;

  final List<_Partial> partials = <_Partial>[];
  for (final FluidInput fluid in fluids) {
    final double mlPerHour = _sanitise(
      toMlPerHour(
        fluid.rateValue,
        fluid.rateUnit,
        weightKg,
        intervalHours: fluid.feedIntervalHours,
      ),
    );
    final double mlPerKgPerDay = _sanitise(
      toMlPerKgPerDay(
        fluid.rateValue,
        fluid.rateUnit,
        weightKg,
        intervalHours: fluid.feedIntervalHours,
      ),
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

    // Every route adds to the day's fluid; only opted-in carbohydrate adds to
    // the GIR, which is the whole point of separating the two.
    totalMlPerHour += mlPerHour;
    totalGlucoseGramsPerDay += glucoseGramsPerDay;
    if (fluid.isFeed) {
      enteralGir += gir;
      enteralMlPerHour += mlPerHour;
      if (fluid.countsTowardGir) countedEnteralGir += gir;
    } else {
      ivGir += gir;
      ivMlPerHour += mlPerHour;
      ivVolumePerDay += mlPerHour * 24;
      ivGlucoseGramsPerDay += glucoseGramsPerDay;
    }

    partials.add(
      _Partial(fluid, mlPerHour, mlPerKgPerDay, gir, glucoseGramsPerDay),
    );
  }

  final double totalGir = ivGir + countedEnteralGir;

  /// A line's share of the bar is measured against what is actually counted,
  /// so an uncounted feed shows no slice rather than a misleading one.
  double shareOf(_Partial p) {
    if (totalGir <= 0) return 0;
    final bool counted = !p.fluid.isFeed || p.fluid.countsTowardGir;
    return counted ? p.gir / totalGir : 0;
  }

  final List<FluidResult> results = partials
      .map(
        (_Partial p) => FluidResult(
          fluid: p.fluid,
          mlPerHour: p.mlPerHour,
          mlPerKgPerDay: p.mlPerKgPerDay,
          gir: p.gir,
          glucoseGramsPerDay: p.glucoseGramsPerDay,
          girShare: shareOf(p),
          countsTowardGir: !p.fluid.isFeed || p.fluid.countsTowardGir,
          feedsPerDay: p.fluid.feedsPerDay,
        ),
      )
      .toList(growable: false);

  return GirSummary(
    weightKg: weightKg,
    isValid: true,
    fluids: results,
    totalGir: totalGir,
    ivGir: ivGir,
    enteralGir: enteralGir,
    countedEnteralGir: countedEnteralGir,
    totalMlPerHour: totalMlPerHour,
    totalMlPerKgPerDay: _sanitise(totalMlPerHour * 24 / weightKg),
    ivMlPerKgPerDay: _sanitise(ivMlPerHour * 24 / weightKg),
    enteralMlPerKgPerDay: _sanitise(enteralMlPerHour * 24 / weightKg),
    totalGlucoseGramsPerDay: totalGlucoseGramsPerDay,
    meanDextrosePercent: ivVolumePerDay > 0
        ? _sanitise(ivGlucoseGramsPerDay / ivVolumePerDay * 100)
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
