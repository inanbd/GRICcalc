import 'package:flutter_test/flutter_test.dart';
import 'package:griccalc/logic/gir_calculator.dart';
import 'package:griccalc/models/fluid_input.dart';

/// The same calculation built up from units rather than from the app's
/// simplified form, so agreement between the two is a real check:
///
///   g/mL     = percent / 100
///   mg/hr    = mL/hr x g/mL x 1000
///   mg/min   = mg/hr / 60
///   mg/kg/min = mg/min / kg
///
/// which collapses to (percent x mL/hr x 1000) / (kg x 60 x 100). Checked
/// against a figure that can be recalled rather than derived: D10W at 6 mL/hr
/// in a 1 kg baby is 10 mg/kg/min.
double referenceGirFromRate(double percent, double mlPerHour, double kg) =>
    (percent * mlPerHour * 1000) / (kg * 60 * 100);

/// A second, separately derived route to the same number, starting from a
/// daily volume instead of an hourly rate:
///
///   mL/hr = mL/kg/day x kg / 24, so GIR = mL/kg/day x % / 144
double referenceGirFromDailyVolume(double percent, double mlPerKgPerDay) =>
    mlPerKgPerDay * percent / 144;

FluidInput iv(double percent, double mlPerHour, {String id = 'iv'}) =>
    FluidInput(
      id: id,
      name: 'IV',
      dextrosePercent: percent,
      rateUnit: RateUnit.mlPerHour,
      rateValue: mlPerHour,
    );

FluidInput bolusFeed(
  double percent,
  double volumeMl,
  double everyHours, {
  String id = 'feed',
  bool counts = false,
}) => FluidInput(
  id: id,
  name: 'Feed',
  dextrosePercent: percent,
  rateUnit: RateUnit.mlPerFeed,
  rateValue: volumeMl,
  route: FluidRoute.enteral,
  feedIntervalHours: everyHours,
  countsTowardGir: counts,
);

/// Weights spanning a micropreemie to a large term baby.
const List<double> weightsGrams = <double>[
  400,
  600,
  850,
  1000,
  1250,
  1500,
  2000,
  2500,
  3200,
  4100,
  5000,
];

const List<double> concentrations = <double>[
  2.5,
  5,
  7.5,
  10,
  12.5,
  15,
  20,
  25,
  50,
];

const List<double> hourlyRates = <double>[0.1, 0.5, 1, 2.4, 4, 7.5, 12, 20];

void main() {
  group('agrees with the published formula', () {
    test('across every weight, concentration and rate in the grid', () {
      for (final double grams in weightsGrams) {
        final double kg = grams / 1000;
        for (final double percent in concentrations) {
          for (final double rate in hourlyRates) {
            final double actual = girFor(
              mlPerHour: rate,
              dextrosePercent: percent,
              weightKg: kg,
            );
            final double expected = referenceGirFromRate(percent, rate, kg);
            expect(
              actual,
              closeTo(expected, 1e-9),
              reason: '$percent% at $rate mL/hr in $grams g',
            );
          }
        }
      }
    });

    test('agrees with the daily-volume derivation too', () {
      const List<double> dailyVolumes = <double>[
        40,
        60,
        80,
        100,
        120,
        150,
        180,
      ];
      for (final double grams in weightsGrams) {
        for (final double percent in concentrations) {
          for (final double perKgPerDay in dailyVolumes) {
            final GirSummary summary = summarise(
              weightGrams: grams,
              fluids: <FluidInput>[
                FluidInput(
                  id: 'a',
                  name: 'IV',
                  dextrosePercent: percent,
                  rateUnit: RateUnit.mlPerKgPerDay,
                  rateValue: perKgPerDay,
                ),
              ],
            );
            expect(
              summary.totalGir,
              closeTo(referenceGirFromDailyVolume(percent, perKgPerDay), 1e-9),
              reason: '$percent% at $perKgPerDay mL/kg/day in $grams g',
            );
          }
        }
      }
    });
  });

  group('known reference points', () {
    test('D10W at 100 mL/kg/day is 6.94 mg/kg/min at any weight', () {
      for (final double grams in weightsGrams) {
        final GirSummary summary = summarise(
          weightGrams: grams,
          fluids: <FluidInput>[
            FluidInput(
              id: 'a',
              name: 'D10W',
              dextrosePercent: 10,
              rateUnit: RateUnit.mlPerKgPerDay,
              rateValue: 100,
            ),
          ],
        );
        expect(summary.totalGir, closeTo(6.944, 0.001), reason: '$grams g');
      }
    });

    test('matches the worked figures published by infantfeeds.com', () {
      // Their example: 2000 g, D5W at 1 mL/hr, plus a continuous feed at
      // 1 mL/hr of a 7.2% formula with a 1% carbohydrate modular (8.2%).
      // Reported there as IV 0.42, enteral 0.68, total 1.1.
      final GirSummary summary = summarise(
        weightGrams: 2000,
        fluids: <FluidInput>[
          iv(5, 1),
          FluidInput(
            id: 'feed',
            name: 'Similac Pro-Total Comfort RTF 20 kcal + 1% D',
            dextrosePercent: 8.2,
            rateUnit: RateUnit.mlPerHour,
            rateValue: 1,
            route: FluidRoute.enteral,
            countsTowardGir: true,
          ),
        ],
      );

      expect(summary.ivGir, closeTo(0.4167, 0.0001));
      expect(summary.enteralGir, closeTo(0.6833, 0.0001));
      expect(summary.totalGir, closeTo(1.1, 0.0001));
      // Rounded the way the app displays them.
      expect(summary.ivGir.toStringAsFixed(2), '0.42');
      expect(summary.enteralGir.toStringAsFixed(2), '0.68');
      expect(summary.totalGir.toStringAsFixed(1), '1.1');
    });

    test('a 1 kg baby on D10W at 6 mL/hr sits at 10 mg/kg/min', () {
      // Chosen because the arithmetic is checkable by hand: 6 x 10 / 6 = 10.
      expect(
        girFor(mlPerHour: 6, dextrosePercent: 10, weightKg: 1),
        closeTo(10, 1e-12),
      );
    });
  });

  group('totals never drift from their parts', () {
    test('total GIR equals the sum of the counted lines', () {
      final GirSummary summary = summarise(
        weightGrams: 1750,
        fluids: <FluidInput>[
          iv(10, 3.2, id: 'a'),
          iv(12.5, 1.1, id: 'b'),
          iv(0, 2, id: 'c'),
          bolusFeed(7, 18, 3, id: 'd', counts: true),
          bolusFeed(8.3, 12, 4, id: 'e'),
        ],
      );

      final double summed = summary.fluids
          .where((FluidResult r) => r.countsTowardGir)
          .fold(0.0, (double acc, FluidResult r) => acc + r.gir);
      expect(summary.totalGir, closeTo(summed, 1e-12));
      expect(
        summary.totalGir,
        closeTo(summary.ivGir + summary.countedEnteralGir, 1e-12),
      );
    });

    test('total volume equals the sum of every line, feeds included', () {
      final GirSummary summary = summarise(
        weightGrams: 1750,
        fluids: <FluidInput>[
          iv(10, 3.2, id: 'a'),
          bolusFeed(7, 18, 3, id: 'd'),
          bolusFeed(8.3, 12, 4, id: 'e'),
        ],
      );

      final double summed = summary.fluids.fold(
        0.0,
        (double acc, FluidResult r) => acc + r.mlPerHour,
      );
      expect(summary.totalMlPerHour, closeTo(summed, 1e-12));
      expect(
        summary.totalMlPerKgPerDay,
        closeTo(summary.ivMlPerKgPerDay + summary.enteralMlPerKgPerDay, 1e-9),
      );
    });

    test('an uncounted feed changes the GIR total not at all', () {
      final List<FluidInput> withoutFeed = <FluidInput>[iv(10, 4)];
      final List<FluidInput> withFeed = <FluidInput>[
        iv(10, 4),
        bolusFeed(7, 20, 3),
      ];

      final GirSummary a = summarise(weightGrams: 1500, fluids: withoutFeed);
      final GirSummary b = summarise(weightGrams: 1500, fluids: withFeed);

      expect(b.totalGir, closeTo(a.totalGir, 1e-12));
      // But it certainly changes the fluid.
      expect(b.totalMlPerKgPerDay, greaterThan(a.totalMlPerKgPerDay));
    });
  });

  group('unit changes do not change the infusion', () {
    test('a rate converted away and back returns to itself', () {
      for (final double grams in weightsGrams) {
        final double kg = grams / 1000;
        for (final double rate in hourlyRates) {
          final FluidInput line = iv(10, rate);
          final double asDaily = convertRate(line, RateUnit.mlPerKgPerDay, kg);
          final FluidInput daily = line.copyWith(
            rateUnit: RateUnit.mlPerKgPerDay,
            rateValue: asDaily,
          );
          expect(
            convertRate(daily, RateUnit.mlPerHour, kg),
            closeTo(rate, 1e-9),
            reason: '$rate mL/hr at $grams g',
          );
        }
      }
    });

    test('a feed converted to mL/hr keeps the same GIR', () {
      for (final double interval in <double>[1, 2, 3, 4, 6, 8, 12, 24]) {
        const double kg = 1.6;
        final FluidInput perFeed = bolusFeed(7, 24, interval, counts: true);
        final double hourly = convertRate(perFeed, RateUnit.mlPerHour, kg);

        final GirSummary a = summarise(
          weightGrams: kg * 1000,
          fluids: <FluidInput>[perFeed],
        );
        final GirSummary b = summarise(
          weightGrams: kg * 1000,
          fluids: <FluidInput>[
            perFeed.copyWith(rateUnit: RateUnit.mlPerHour, rateValue: hourly),
          ],
        );

        expect(b.totalGir, closeTo(a.totalGir, 1e-9), reason: 'q${interval}h');
        expect(
          b.totalMlPerKgPerDay,
          closeTo(a.totalMlPerKgPerDay, 1e-9),
          reason: 'q${interval}h',
        );
      }
    });
  });

  group('feed volumes', () {
    test('match volume x 24 / interval across the common intervals', () {
      const double kg = 1.4;
      for (final double interval in <double>[1, 2, 3, 4, 6, 8, 12, 24]) {
        for (final double volume in <double>[1, 5, 12.5, 20, 45, 80]) {
          final GirSummary summary = summarise(
            weightGrams: kg * 1000,
            fluids: <FluidInput>[bolusFeed(7, volume, interval)],
          );
          final double expectedPerDay = volume * (24 / interval);
          expect(
            summary.totalMlPerHour * 24,
            closeTo(expectedPerDay, 1e-9),
            reason: '$volume mL q${interval}h',
          );
          expect(
            summary.enteralMlPerKgPerDay,
            closeTo(expectedPerDay / kg, 1e-9),
            reason: '$volume mL q${interval}h',
          );
          expect(
            summary.fluids.single.feedsPerDay,
            closeTo(24 / interval, 1e-9),
          );
        }
      }
    });
  });

  group('refuses to produce a dangerous number', () {
    test('a nonsense concentration contributes no glucose', () {
      // The volume is real and still counts; the concentration is not usable,
      // so it must add nothing to the GIR rather than subtract from it.
      final GirSummary summary = summarise(
        weightGrams: 1200,
        fluids: <FluidInput>[iv(-10, 5)],
      );

      expect(summary.totalGir, 0);
      expect(summary.totalGlucoseGramsPerDay, 0);
      expect(summary.totalMlPerHour, 5);
    });

    test('a negative rate delivers nothing at all', () {
      final GirSummary summary = summarise(
        weightGrams: 1200,
        fluids: <FluidInput>[
          iv(10, -5, id: 'b'),
          bolusFeed(-7, -20, 3, id: 'c', counts: true),
        ],
      );

      expect(summary.totalGir, 0);
      expect(summary.ivGir, 0);
      expect(summary.enteralGir, 0);
      expect(summary.totalMlPerHour, 0);
      expect(summary.totalMlPerKgPerDay, 0);
      for (final FluidResult line in summary.fluids) {
        expect(line.gir, greaterThanOrEqualTo(0));
        expect(line.mlPerHour, greaterThanOrEqualTo(0));
        expect(line.glucoseGramsPerDay, greaterThanOrEqualTo(0));
      }
    });

    test('survives non-finite inputs without producing NaN', () {
      final GirSummary summary = summarise(
        weightGrams: 1000,
        fluids: <FluidInput>[
          iv(double.nan, 4, id: 'a'),
          iv(10, double.infinity, id: 'b'),
          bolusFeed(7, double.nan, 3, id: 'c', counts: true),
          bolusFeed(7, 20, 0, id: 'd', counts: true),
        ],
      );

      expect(summary.totalGir.isFinite, isTrue);
      expect(summary.totalMlPerHour.isFinite, isTrue);
      expect(summary.totalMlPerKgPerDay.isFinite, isTrue);
      for (final FluidResult line in summary.fluids) {
        expect(line.gir.isFinite, isTrue);
        expect(line.girShare.isFinite, isTrue);
      }
    });

    test('a missing or impossible weight reports nothing at all', () {
      for (final double? grams in <double?>[
        null,
        0,
        -1,
        -2500,
        double.nan,
        double.infinity,
      ]) {
        final GirSummary summary = summarise(
          weightGrams: grams,
          fluids: <FluidInput>[iv(10, 4), bolusFeed(7, 20, 3)],
        );
        expect(summary.isValid, isFalse, reason: 'weight $grams');
        expect(summary.totalGir, 0, reason: 'weight $grams');
        expect(summary.fluids, isEmpty, reason: 'weight $grams');
      }
    });

    test('shares stay within 0 and 1 and add up', () {
      final GirSummary summary = summarise(
        weightGrams: 1500,
        fluids: <FluidInput>[
          iv(10, 4, id: 'a'),
          iv(12.5, 2, id: 'b'),
          bolusFeed(7, 20, 3, id: 'c', counts: true),
          bolusFeed(7, 10, 6, id: 'd'),
        ],
      );

      double total = 0;
      for (final FluidResult line in summary.fluids) {
        expect(line.girShare, inInclusiveRange(0, 1));
        total += line.girShare;
      }
      expect(total, closeTo(1, 1e-9));
    });
  });

  group('banding', () {
    test('classifies exactly at the boundaries', () {
      expect(girBandFor(3.9999), GirBand.low);
      expect(girBandFor(4), GirBand.maintenance);
      expect(girBandFor(7.9999), GirBand.maintenance);
      expect(girBandFor(8), GirBand.elevated);
      expect(girBandFor(11.9999), GirBand.elevated);
      expect(girBandFor(12), GirBand.high);
      expect(girBandFor(0), GirBand.none);
      expect(girBandFor(-5), GirBand.none);
      expect(girBandFor(double.nan), GirBand.none);
    });

    test('the band follows the total, not any single line', () {
      // Two modest lines that together clear the elevated threshold.
      final GirSummary summary = summarise(
        weightGrams: 1000,
        fluids: <FluidInput>[
          iv(10, 3, id: 'a'),
          iv(10, 2.5, id: 'b'),
        ],
      );
      expect(summary.totalGir, closeTo(9.1667, 0.0001));
      expect(summary.band, GirBand.elevated);
    });
  });

  group('peripheral access flag', () {
    test('flags only running lines above the limit', () {
      final GirSummary summary = summarise(
        weightGrams: 1000,
        fluids: <FluidInput>[
          iv(12.5, 2, id: 'at-limit'),
          iv(12.6, 2, id: 'over'),
          iv(25, 0, id: 'not-running'),
        ],
      );
      expect(
        summary.linesAbovePeripheralLimit
            .map((FluidResult r) => r.fluid.id)
            .toList(),
        <String>['over'],
      );
    });

    test('a concentrated feed is not a peripheral access concern', () {
      // Feeds do not go through a cannula, so they must not raise the flag.
      final GirSummary summary = summarise(
        weightGrams: 1000,
        fluids: <FluidInput>[bolusFeed(20, 20, 3)],
      );
      expect(summary.linesAbovePeripheralLimit, isEmpty);
    });
  });
}
