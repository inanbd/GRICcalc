import 'package:flutter_test/flutter_test.dart';
import 'package:griccalc/logic/gir_calculator.dart';
import 'package:griccalc/logic/report.dart';
import 'package:griccalc/models/fluid_input.dart';

GirSummary buildSummary({bool countFeed = false}) => summarise(
  weightGrams: 1500,
  fluids: <FluidInput>[
    const FluidInput(
      id: 'iv',
      name: 'D10W',
      dextrosePercent: 10,
      rateUnit: RateUnit.mlPerHour,
      rateValue: 4,
    ),
    FluidInput(
      id: 'feed',
      name: 'Breast milk',
      dextrosePercent: 7,
      rateUnit: RateUnit.mlPerFeed,
      rateValue: 20,
      route: FluidRoute.enteral,
      countsTowardGir: countFeed,
    ),
  ],
);

void main() {
  group('copy text', () {
    test('is the three figures, one per line, in the asked-for shape', () {
      expect(
        girSummaryText(buildSummary()),
        'IV GIR: 4.44 mg/kg/min\n'
        'Enteral GIR: 5.19 mg/kg/min\n'
        'Total GIR: 4.44 mg/kg/min',
      );
    });

    test('the total moves when the feed is counted, the parts do not', () {
      expect(
        girSummaryText(buildSummary(countFeed: true)),
        'IV GIR: 4.44 mg/kg/min\n'
        'Enteral GIR: 5.19 mg/kg/min\n'
        'Total GIR: 9.63 mg/kg/min',
      );
    });

    test('reads as zeros rather than blanks before a weight is entered', () {
      const GirSummary empty = GirSummary.empty();
      expect(girSummaryText(empty), contains('IV GIR: 0.00 mg/kg/min'));
      expect(girSummaryText(empty), contains('Total GIR: 0.00 mg/kg/min'));
    });
  });

  group('line working', () {
    test('shows an infusion\'s inputs and its result', () {
      final GirSummary summary = buildSummary();
      final String line = lineWorking(summary.fluids.first);
      expect(
        line,
        'D10W: 4 mL/hr (64 mL/kg/day), 10% dextrose -> 4.44 mg/kg/min',
      );
    });

    test('shows a feed\'s interval, feeds per day and daily volume', () {
      final GirSummary summary = buildSummary();
      final String line = lineWorking(summary.fluids.last);
      expect(
        line,
        'Breast milk: 20 mL q3h = 8 feeds/day = 160 mL/day (6.67 mL/hr), '
        '7% carbohydrate -> 5.19 mg/kg/min (not counted)',
      );
    });

    test('drops the "not counted" note once the feed is switched on', () {
      final GirSummary summary = buildSummary(countFeed: true);
      expect(lineWorking(summary.fluids.last), isNot(contains('not counted')));
    });

    test('names an unnamed line rather than leaving a gap', () {
      final GirSummary summary = summarise(
        weightGrams: 1000,
        fluids: <FluidInput>[
          const FluidInput(
            id: 'x',
            name: '   ',
            dextrosePercent: 10,
            rateUnit: RateUnit.mlPerHour,
            rateValue: 2,
          ),
        ],
      );
      expect(lineWorking(summary.fluids.single), startsWith('Unnamed:'));
    });
  });

  group('pdf report', () {
    test('renders a non-empty PDF document', () async {
      final List<int> bytes = await buildReportPdf(
        summary: buildSummary(),
        patientName: 'Baby A',
        generatedAt: DateTime(2026, 9, 4, 1, 42),
      );

      expect(bytes.length, greaterThan(1000));
      // A PDF always starts with the %PDF- header.
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('renders when there is nothing to report', () async {
      final List<int> bytes = await buildReportPdf(
        summary: const GirSummary.empty(),
        patientName: 'Patient 1',
      );
      expect(bytes.length, greaterThan(500));
    });

    test('renders a feeds-only patient', () async {
      final GirSummary summary = summarise(
        weightGrams: 3000,
        fluids: <FluidInput>[
          const FluidInput(
            id: 'f',
            name: 'Formula',
            dextrosePercent: 7.5,
            rateUnit: RateUnit.mlPerFeed,
            rateValue: 45,
            route: FluidRoute.enteral,
            countsTowardGir: false,
          ),
        ],
      );
      final List<int> bytes = await buildReportPdf(
        summary: summary,
        patientName: 'Baby B',
      );
      expect(bytes.length, greaterThan(1000));
    });
  });
}
