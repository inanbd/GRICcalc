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
}) {
  return FluidInput(
    id: id,
    name: name,
    dextrosePercent: dextrosePercent,
    rateUnit: rateUnit,
    rateValue: rateValue,
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
}
