import 'package:flutter_test/flutter_test.dart';
import 'package:griccalc/logic/formatting.dart';
import 'package:griccalc/logic/gir_calculator.dart';
import 'package:griccalc/models/fluid_input.dart';

FluidInput fluid({
  String id = 'a',
  String name = 'Fluid',
  double dextrosePercent = 10,
  RateUnit rateUnit = RateUnit.mlPerHour,
  double rateValue = 0,
  FluidRoute route = FluidRoute.intravenous,
  double feedIntervalHours = 3,
  bool? countsTowardGir,
}) {
  return FluidInput(
    id: id,
    name: name,
    dextrosePercent: dextrosePercent,
    rateUnit: rateUnit,
    rateValue: rateValue,
    route: route,
    feedIntervalHours: feedIntervalHours,
    countsTowardGir: countsTowardGir ?? route == FluidRoute.intravenous,
  );
}

/// A bolus feed line, e.g. 20 mL of breast milk every 3 hours.
FluidInput feed({
  String id = 'feed',
  String name = 'Breast milk',
  double carbPercent = 7,
  double volumeMl = 20,
  double everyHours = 3,
  bool countsTowardGir = false,
}) {
  return fluid(
    id: id,
    name: name,
    dextrosePercent: carbPercent,
    rateUnit: RateUnit.mlPerFeed,
    rateValue: volumeMl,
    route: FluidRoute.enteral,
    feedIntervalHours: everyHours,
    countsTowardGir: countsTowardGir,
  );
}

void main() {
  group('girFor', () {
    test('D10W at 3 mL/hr in a 1.5 kg baby is 3.33 mg/kg/min', () {
      // 3 mL/hr x 10 g/100mL = 0.3 g/hr = 300 mg/hr = 5 mg/min over 1.5 kg.
      expect(
        girFor(mlPerHour: 3, dextrosePercent: 10, weightKg: 1.5),
        closeTo(3.333, 0.001),
      );
    });

    test('D10W at 100 mL/kg/day equals 6.94 mg/kg/min at any weight', () {
      // 100 mL/kg/day of D10 is a weight-independent GIR.
      for (final double kg in <double>[0.5, 1.5, 3.4]) {
        final double mlPerHour = toMlPerHour(100, RateUnit.mlPerKgPerDay, kg);
        expect(
          girFor(mlPerHour: mlPerHour, dextrosePercent: 10, weightKg: kg),
          closeTo(6.944, 0.001),
        );
      }
    });

    test('a dextrose-free fluid contributes no glucose', () {
      expect(girFor(mlPerHour: 20, dextrosePercent: 0, weightKg: 2), 0);
    });

    test('a non-positive weight yields zero rather than infinity', () {
      expect(girFor(mlPerHour: 5, dextrosePercent: 10, weightKg: 0), 0);
    });
  });

  group('rate conversion', () {
    test('mL/kg/day to mL/hr uses weight over 24 hours', () {
      expect(toMlPerHour(150, RateUnit.mlPerKgPerDay, 2), closeTo(12.5, 1e-9));
    });

    test('mL/hr to mL/kg/day is the inverse', () {
      expect(toMlPerKgPerDay(12.5, RateUnit.mlPerHour, 2), closeTo(150, 1e-9));
    });

    test('a rate already in its own unit passes through untouched', () {
      expect(toMlPerHour(4.2, RateUnit.mlPerHour, 3), 4.2);
      expect(toMlPerKgPerDay(120, RateUnit.mlPerKgPerDay, 3), 120);
    });

    test('mL/kg/day is zero when the weight is unusable', () {
      expect(toMlPerKgPerDay(10, RateUnit.mlPerHour, 0), 0);
    });
  });

  group('summarise', () {
    test('returns an empty summary until a usable weight is entered', () {
      for (final double? weight in <double?>[null, 0, -500, double.nan]) {
        final GirSummary summary = summarise(
          weightGrams: weight,
          fluids: <FluidInput>[fluid(rateValue: 5)],
        );
        expect(summary.isValid, isFalse, reason: 'weight $weight');
        expect(summary.totalGir, 0);
        expect(summary.fluids, isEmpty);
      }
    });

    test('adds the GIR of every line', () {
      // 1000 g baby: D10 at 3 mL/hr (5.0) plus D12.5 at 1 mL/hr (2.083).
      final GirSummary summary = summarise(
        weightGrams: 1000,
        fluids: <FluidInput>[
          fluid(id: 'a', dextrosePercent: 10, rateValue: 3),
          fluid(id: 'b', dextrosePercent: 12.5, rateValue: 1),
        ],
      );

      expect(summary.weightKg, 1.0);
      expect(summary.fluids[0].gir, closeTo(5.0, 0.001));
      expect(summary.fluids[1].gir, closeTo(2.083, 0.001));
      expect(summary.totalGir, closeTo(7.083, 0.001));
      expect(summary.band, GirBand.maintenance);
    });

    test('totals volume in mL/hr and mL/kg/day', () {
      final GirSummary summary = summarise(
        weightGrams: 2000,
        fluids: <FluidInput>[
          fluid(id: 'a', rateValue: 6),
          fluid(
            id: 'b',
            rateUnit: RateUnit.mlPerKgPerDay,
            rateValue: 24, // 24 mL/kg/day at 2 kg = 2 mL/hr
          ),
        ],
      );

      expect(summary.totalMlPerHour, closeTo(8, 1e-9));
      // 8 mL/hr x 24 h = 192 mL/day over 2 kg.
      expect(summary.totalMlPerKgPerDay, closeTo(96, 1e-9));
      expect(summary.fluids[1].mlPerHour, closeTo(2, 1e-9));
      expect(summary.fluids[0].mlPerKgPerDay, closeTo(72, 1e-9));
    });

    test('reports glucose grams per day and mean concentration', () {
      // Equal volumes of D20 and D0 average out to D10.
      final GirSummary summary = summarise(
        weightGrams: 3000,
        fluids: <FluidInput>[
          fluid(id: 'a', dextrosePercent: 20, rateValue: 5),
          fluid(id: 'b', dextrosePercent: 0, rateValue: 5),
        ],
      );

      expect(summary.totalGlucoseGramsPerDay, closeTo(24, 1e-9));
      expect(summary.meanDextrosePercent, closeTo(10, 1e-9));
    });

    test('mean concentration is null when nothing is running', () {
      final GirSummary summary = summarise(
        weightGrams: 1500,
        fluids: <FluidInput>[fluid(rateValue: 0)],
      );
      expect(summary.meanDextrosePercent, isNull);
      expect(summary.band, GirBand.none);
    });

    test('each line reports its share of the total GIR', () {
      final GirSummary summary = summarise(
        weightGrams: 1000,
        fluids: <FluidInput>[
          fluid(id: 'a', dextrosePercent: 10, rateValue: 3),
          fluid(id: 'b', dextrosePercent: 10, rateValue: 1),
        ],
      );

      expect(summary.fluids[0].girShare, closeTo(0.75, 1e-9));
      expect(summary.fluids[1].girShare, closeTo(0.25, 1e-9));
    });

    test('shares are zero rather than NaN when no glucose is running', () {
      final GirSummary summary = summarise(
        weightGrams: 1000,
        fluids: <FluidInput>[fluid(dextrosePercent: 0, rateValue: 10)],
      );
      expect(summary.fluids.single.girShare, 0);
    });

    test('flags lines above the peripheral dextrose limit', () {
      final GirSummary summary = summarise(
        weightGrams: 1000,
        fluids: <FluidInput>[
          fluid(id: 'a', name: 'D10W', dextrosePercent: 10, rateValue: 2),
          fluid(id: 'b', name: 'D20W', dextrosePercent: 20, rateValue: 2),
          // Ordered but not running, so not a live concern.
          fluid(id: 'c', name: 'D25W', dextrosePercent: 25, rateValue: 0),
        ],
      );

      expect(
        summary.linesAbovePeripheralLimit
            .map((FluidResult r) => r.fluid.name)
            .toList(),
        <String>['D20W'],
      );
    });
  });

  group('girBandFor', () {
    test('classifies against usual neonatal practice', () {
      expect(girBandFor(0), GirBand.none);
      expect(girBandFor(3.9), GirBand.low);
      expect(girBandFor(4), GirBand.maintenance);
      expect(girBandFor(7.9), GirBand.maintenance);
      expect(girBandFor(8), GirBand.elevated);
      expect(girBandFor(11.9), GirBand.elevated);
      expect(girBandFor(12), GirBand.high);
      expect(girBandFor(double.nan), GirBand.none);
    });
  });

  group('formatting', () {
    test('fixed keeps a steady number of decimals', () {
      expect(fixed(8.666, 2), '8.67');
      expect(fixed(9, 1), '9.0');
      expect(fixed(double.infinity), '--');
    });

    test('trimmed drops trailing zeros', () {
      expect(trimmed(12.50, 2), '12.5');
      expect(trimmed(10, 2), '10');
      expect(trimmed(0.125, 3), '0.125');
    });

    test('parseNumber accepts comma decimals and rejects junk', () {
      expect(parseNumber('1,5'), 1.5);
      expect(parseNumber(' 2.25 '), 2.25);
      expect(parseNumber(''), isNull);
      expect(parseNumber('abc'), isNull);
      expect(parseNumber(null), isNull);
    });
  });

  group('feeds', () {
    test('20 mL every 3 hours is 8 feeds, 160 mL, 6.67 mL/hr', () {
      expect(
        toMlPerHour(20, RateUnit.mlPerFeed, 1.5, intervalHours: 3),
        closeTo(6.667, 0.001),
      );
      // 8 feeds x 20 mL = 160 mL/day over 1.5 kg.
      expect(
        toMlPerKgPerDay(20, RateUnit.mlPerFeed, 1.5, intervalHours: 3),
        closeTo(106.667, 0.001),
      );
      expect(feed(volumeMl: 20, everyHours: 3).feedsPerDay, 8);
    });

    test('a zero interval yields zero rather than infinity', () {
      expect(toMlPerHour(20, RateUnit.mlPerFeed, 1.5, intervalHours: 0), 0);
      expect(toMlPerKgPerDay(20, RateUnit.mlPerFeed, 1.5, intervalHours: 0), 0);
      expect(feed(everyHours: 0).feedsPerDay, isNull);
    });

    test('feeds add to the day\'s fluid but not to the GIR by default', () {
      // 1.5 kg baby: D10 at 4 mL/hr, plus 20 mL of breast milk q3h.
      final GirSummary summary = summarise(
        weightGrams: 1500,
        fluids: <FluidInput>[
          fluid(id: 'iv', dextrosePercent: 10, rateValue: 4),
          feed(),
        ],
      );

      // The GIR is the drip alone: 4 x 10 / (6 x 1.5).
      expect(summary.ivGir, closeTo(4.444, 0.001));
      expect(summary.totalGir, closeTo(4.444, 0.001));
      // The feed's contribution is still reported, just not added in.
      expect(summary.enteralGir, closeTo(5.185, 0.001));
      expect(summary.countedEnteralGir, 0);
      expect(summary.countsFeedsInGir, isFalse);

      // Both routes count towards the day's fluid: 4 + 6.667 mL/hr.
      expect(summary.totalMlPerHour, closeTo(10.667, 0.001));
      expect(summary.totalMlPerKgPerDay, closeTo(170.667, 0.001));
      expect(summary.ivMlPerKgPerDay, closeTo(64, 0.001));
      expect(summary.enteralMlPerKgPerDay, closeTo(106.667, 0.001));
    });

    test('switching a feed on adds it to the total GIR', () {
      final GirSummary summary = summarise(
        weightGrams: 1500,
        fluids: <FluidInput>[
          fluid(id: 'iv', dextrosePercent: 10, rateValue: 4),
          feed(countsTowardGir: true),
        ],
      );

      expect(summary.ivGir, closeTo(4.444, 0.001));
      expect(summary.enteralGir, closeTo(5.185, 0.001));
      expect(summary.countedEnteralGir, closeTo(5.185, 0.001));
      expect(summary.totalGir, closeTo(9.630, 0.001));
      expect(summary.countsFeedsInGir, isTrue);
      // Counting it does not change the fluid totals.
      expect(summary.totalMlPerKgPerDay, closeTo(170.667, 0.001));
    });

    test('an uncounted feed takes no slice of the contribution bar', () {
      final GirSummary summary = summarise(
        weightGrams: 1500,
        fluids: <FluidInput>[
          fluid(id: 'iv', dextrosePercent: 10, rateValue: 4),
          feed(),
        ],
      );

      expect(summary.fluids[0].girShare, closeTo(1.0, 1e-9));
      expect(summary.fluids[1].girShare, 0);
      expect(summary.fluids[1].countsTowardGir, isFalse);
      expect(summary.fluids[1].feedsPerDay, 8);
    });

    test('mean dextrose describes the IV fluids, not the feeds', () {
      final GirSummary summary = summarise(
        weightGrams: 1500,
        fluids: <FluidInput>[
          fluid(id: 'iv', dextrosePercent: 10, rateValue: 4),
          feed(carbPercent: 7),
        ],
      );

      // Diluting by the feed would understate what the drip line carries.
      expect(summary.meanDextrosePercent, closeTo(10, 1e-9));
      expect(summary.hasFeeds, isTrue);
    });

    test('a continuous feed can be entered in mL/hr and still be a feed', () {
      final GirSummary summary = summarise(
        weightGrams: 2000,
        fluids: <FluidInput>[
          fluid(
            id: 'ng',
            dextrosePercent: 7,
            rateValue: 5,
            route: FluidRoute.enteral,
            countsTowardGir: false,
          ),
        ],
      );

      expect(summary.totalGir, 0);
      expect(summary.enteralGir, closeTo(2.917, 0.001));
      expect(summary.enteralMlPerKgPerDay, closeTo(60, 0.001));
      expect(summary.ivMlPerKgPerDay, 0);
    });

    test('feeds-only totals report fluid with no GIR', () {
      final GirSummary summary = summarise(
        weightGrams: 3000,
        fluids: <FluidInput>[feed(volumeMl: 45, everyHours: 3)],
      );

      expect(summary.totalGir, 0);
      expect(summary.band, GirBand.none);
      // 8 x 45 = 360 mL/day over 3 kg.
      expect(summary.totalMlPerKgPerDay, closeTo(120, 0.001));
      expect(summary.meanDextrosePercent, isNull);
    });
  });

  group('convertRate', () {
    test('a feed converted to mL/hr keeps the same daily volume', () {
      final FluidInput f = feed(volumeMl: 20, everyHours: 3);
      expect(convertRate(f, RateUnit.mlPerHour, 1.5), closeTo(6.667, 0.001));
      expect(
        convertRate(f, RateUnit.mlPerKgPerDay, 1.5),
        closeTo(106.667, 0.001),
      );
    });

    test('mL/hr converted to per-feed uses the line\'s interval', () {
      final FluidInput f = fluid(
        rateUnit: RateUnit.mlPerHour,
        rateValue: 6.6667,
        route: FluidRoute.enteral,
        feedIntervalHours: 3,
      );
      expect(convertRate(f, RateUnit.mlPerFeed, 1.5), closeTo(20, 0.01));
    });

    test('converting to the unit already in use changes nothing', () {
      final FluidInput f = feed(volumeMl: 20);
      expect(convertRate(f, RateUnit.mlPerFeed, 1.5), 20);
    });
  });

  group('feed interval labels', () {
    test('reads the way it is prescribed', () {
      expect(feedIntervalLabel(3), 'q3h');
      expect(feedIntervalLabel(1), 'q1h');
      expect(feedIntervalLabel(1.5), 'q1.5h');
      expect(feedIntervalLabel(0), 'q?h');
    });
  });
}
