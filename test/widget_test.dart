import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:griccalc/main.dart';
import 'package:griccalc/models/fluid_input.dart';

/// Types [text] into the field whose label is [label].
Future<void> enterInto(WidgetTester tester, String label, String text) async {
  await tester.enterText(
    find.ancestor(of: find.text(label), matching: find.byType(TextField)).first,
    text,
  );
  await tester.pumpAndSettle();
}

void main() {
  // A phone-sized surface, so the app renders its narrow layout.
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  testWidgets('prompts for a weight before showing totals', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GirCalculatorApp());

    expect(find.text('NICU GIR Calculator'), findsOneWidget);
    expect(find.text('Enter a weight to see totals'), findsOneWidget);
  });

  testWidgets('computes a total GIR from weight and one fluid', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GirCalculatorApp());

    await enterInto(tester, 'Weight', '1500');
    await enterInto(tester, 'Dextrose', '10');
    await enterInto(tester, 'Rate', '5');

    // 5 mL/hr of D10 over 1.5 kg = 5.56 mg/kg/min, at 80 mL/kg/day.
    expect(find.text('5.56'), findsWidgets);
    expect(find.text('80'), findsWidgets);
    expect(find.text('= 1.5 kg'), findsOneWidget);
  });

  testWidgets('adds fluids and sums their contributions', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GirCalculatorApp());

    await enterInto(tester, 'Weight', '1000');

    final Finder dextroseFields = find.ancestor(
      of: find.text('Dextrose'),
      matching: find.byType(TextField),
    );
    final Finder rateFields = find.ancestor(
      of: find.text('Rate'),
      matching: find.byType(TextField),
    );

    await tester.enterText(dextroseFields.at(0), '10');
    await tester.enterText(rateFields.at(0), '3');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add fluid'));
    await tester.pumpAndSettle();

    await tester.enterText(dextroseFields.at(1), '12.5');
    await tester.enterText(rateFields.at(1), '1');
    await tester.pumpAndSettle();

    // 5.00 + 2.08 = 7.08 mg/kg/min across two lines, 4 mL/hr in total.
    expect(find.text('7.08'), findsWidgets);
    expect(find.text('2 lines'), findsOneWidget);
  });

  testWidgets('switching the rate unit keeps the same infusion', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GirCalculatorApp());

    await enterInto(tester, 'Weight', '2000');
    await enterInto(tester, 'Dextrose', '10');
    await enterInto(tester, 'Rate', '10'); // 10 mL/hr

    // Scope to the segmented control: the totals bar carries the same label.
    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<RateUnit>),
        matching: find.text('mL/kg/day'),
      ),
    );
    await tester.pumpAndSettle();

    // 10 mL/hr in a 2 kg baby is 120 mL/kg/day, and the GIR is unchanged.
    final TextField rateField = tester.widget<TextField>(
      find.ancestor(of: find.text('Rate'), matching: find.byType(TextField)),
    );
    expect(rateField.controller?.text, '120');
    expect(find.text('8.33'), findsWidgets);
  });

  testWidgets('draws a visible GIR contribution bar per fluid', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GirCalculatorApp());

    await enterInto(tester, 'Weight', '1000');

    final Finder dextroseFields = find.ancestor(
      of: find.text('Dextrose'),
      matching: find.byType(TextField),
    );
    final Finder rateFields = find.ancestor(
      of: find.text('Rate'),
      matching: find.byType(TextField),
    );

    await tester.enterText(dextroseFields.at(0), '10');
    await tester.enterText(rateFields.at(0), '3');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add fluid'));
    await tester.pumpAndSettle();
    await tester.enterText(dextroseFields.at(1), '10');
    await tester.enterText(rateFields.at(1), '1');
    await tester.pumpAndSettle();

    expect(find.text('GIR by fluid'), findsOneWidget);

    // Each segment must actually occupy space, in both axes.
    final Iterable<Element> segments = find
        .descendant(
          of: find.byType(ClipRRect),
          matching: find.byType(ColoredBox),
        )
        .evaluate();
    expect(segments.length, 2);
    for (final Element segment in segments) {
      final Size size = segment.size!;
      expect(size.height, greaterThan(0));
      expect(size.width, greaterThan(0));
    }
    // 3:1 rates share the same concentration, so 75% / 25% of the width.
    final List<double> widths = segments
        .map((Element e) => e.size!.width)
        .toList();
    expect(widths[0] / (widths[0] + widths[1]), closeTo(0.75, 0.02));
  });

  testWidgets('warns when a fluid needs central access', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GirCalculatorApp());

    await enterInto(tester, 'Weight', '3000');
    await enterInto(tester, 'Dextrose', '20');
    await enterInto(tester, 'Rate', '6');

    expect(find.textContaining('usually needs central access'), findsOneWidget);
  });

  testWidgets('start over clears the weight and extra fluids', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GirCalculatorApp());

    await enterInto(tester, 'Weight', '1500');
    await tester.tap(find.text('Add fluid'));
    await tester.pumpAndSettle();
    expect(find.text('2 lines'), findsOneWidget);

    await tester.tap(find.byTooltip('Start over'));
    await tester.pumpAndSettle();

    expect(find.text('1 line'), findsOneWidget);
    expect(find.text('Enter a weight to see totals'), findsOneWidget);
  });
}
