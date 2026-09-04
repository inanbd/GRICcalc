import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:griccalc/logic/patient_store.dart';
import 'package:griccalc/main.dart';
import 'package:griccalc/models/fluid_input.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps the app over empty storage on a tall phone-sized surface.
Future<PatientStore> pumpApp(
  WidgetTester tester, {
  Size size = const Size(500, 2200),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final PatientStore store = PatientStore(writeDelay: Duration.zero);
  await tester.pumpWidget(GirCalculatorApp(store: store));
  await tester.pumpAndSettle();
  return store;
}

/// Types [text] into the field whose label or hint is [label].
Future<void> enterInto(WidgetTester tester, String label, String text) async {
  await tester.enterText(
    find.ancestor(of: find.text(label), matching: find.byType(TextField)).first,
    text,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on a patient with D10W already listed', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('NICU GIR Calculator'), findsOneWidget);
    expect(find.text('Enter a weight to see totals'), findsOneWidget);
    // The default line means a new patient only needs a weight and a rate.
    expect(find.text('1 line'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'D10W'), findsOneWidget);
  });

  testWidgets('one tap adds a preset fluid, already filled in', (
    WidgetTester tester,
  ) async {
    final PatientStore store = await pumpApp(tester);

    await tester.tap(find.widgetWithText(ActionChip, 'D12.5W'));
    await tester.pumpAndSettle();

    expect(find.text('2 lines'), findsOneWidget);
    final FluidInput added = store.selected!.fluids.last;
    expect(added.name, 'D12.5W');
    expect(added.dextrosePercent, 12.5);
  });

  testWidgets('computes a total GIR from weight and rate', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await enterInto(tester, 'Weight', '1500');
    await enterInto(tester, 'Rate', '5');

    // 5 mL/hr of D10 over 1.5 kg = 5.56 mg/kg/min, at 80 mL/kg/day.
    expect(find.text('5.56'), findsWidgets);
    expect(find.text('80'), findsWidgets);
    expect(find.text('= 1.5 kg'), findsOneWidget);
  });

  testWidgets('keeps a separate record per patient and switches in one tap', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await enterInto(tester, 'Patient 1', 'Baby A');
    await enterInto(tester, 'Weight', '1000');

    await tester.tap(find.widgetWithText(ActionChip, 'Add patient'));
    await tester.pumpAndSettle();

    // The new record starts empty rather than inheriting the first one.
    expect(find.text('Enter a weight to see totals'), findsOneWidget);
    await enterInto(tester, 'Patient 2', 'Baby B');
    await enterInto(tester, 'Weight', '2000');
    expect(find.text('= 2 kg'), findsOneWidget);

    // One tap back to the first baby restores their weight.
    await tester.tap(find.text('Baby A'));
    await tester.pumpAndSettle();
    expect(find.text('= 1 kg'), findsOneWidget);
  });

  testWidgets('fluids belong to the patient that was on screen', (
    WidgetTester tester,
  ) async {
    final PatientStore store = await pumpApp(tester);

    await enterInto(tester, 'Weight', '1000');
    await tester.tap(find.widgetWithText(ActionChip, 'TPN'));
    await tester.pumpAndSettle();
    expect(find.text('2 lines'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'Add patient'));
    await tester.pumpAndSettle();
    expect(find.text('1 line'), findsOneWidget);

    await tester.tap(find.text('Patient 1'));
    await tester.pumpAndSettle();
    expect(find.text('2 lines'), findsOneWidget);
    expect(store.patients.first.fluids, hasLength(2));
  });

  testWidgets('records are written without an explicit save', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await enterInto(tester, 'Patient 1', 'Baby A');
    await enterInto(tester, 'Weight', '1250');
    await tester.pumpAndSettle();

    // A store built over the same storage sees the edits already.
    final PatientStore reopened = PatientStore(writeDelay: Duration.zero);
    await reopened.load();
    expect(reopened.selected!.name, 'Baby A');
    expect(reopened.selected!.weightGrams, 1250);
  });

  testWidgets('duplicating carries the fluids to a new patient', (
    WidgetTester tester,
  ) async {
    final PatientStore store = await pumpApp(tester);

    await enterInto(tester, 'Patient 1', 'Twin 1');
    await enterInto(tester, 'Weight', '1400');
    await tester.tap(find.widgetWithText(ActionChip, 'Lipid 20%'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Patient actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate patient'));
    await tester.pumpAndSettle();

    expect(store.patients, hasLength(2));
    expect(find.text('2 lines'), findsOneWidget);
    expect(find.text('= 1.4 kg'), findsOneWidget);
    expect(store.selected!.name, 'Twin 1 (copy)');
  });

  testWidgets('deleting a patient asks first', (WidgetTester tester) async {
    final PatientStore store = await pumpApp(tester);

    await enterInto(tester, 'Patient 1', 'Baby A');
    await tester.tap(find.widgetWithText(ActionChip, 'Add patient'));
    await tester.pumpAndSettle();
    await enterInto(tester, 'Patient 2', 'Baby B');

    await tester.tap(find.byTooltip('Patient actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete patient'));
    await tester.pumpAndSettle();

    // Backing out leaves the record alone.
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(store.patients, hasLength(2));

    await tester.tap(find.byTooltip('Patient actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete patient'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(store.patients, hasLength(1));
    expect(store.selected!.name, 'Baby A');
  });

  testWidgets('switching the rate unit keeps the same infusion', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await enterInto(tester, 'Weight', '2000');
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
    await pumpApp(tester, size: const Size(1400, 1400));

    await enterInto(tester, 'Weight', '1000');
    await tester.tap(find.widgetWithText(ActionChip, 'D10W'));
    await tester.pumpAndSettle();

    final Finder rateFields = find.ancestor(
      of: find.text('Rate'),
      matching: find.byType(TextField),
    );
    await tester.enterText(rateFields.at(0), '3');
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
      expect(segment.size!.height, greaterThan(0));
      expect(segment.size!.width, greaterThan(0));
    }
    final List<double> widths = segments
        .map((Element e) => e.size!.width)
        .toList();
    expect(widths[0] / (widths[0] + widths[1]), closeTo(0.75, 0.02));
  });

  testWidgets('warns when a fluid needs central access', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: const Size(1400, 1400));

    await enterInto(tester, 'Weight', '3000');
    await enterInto(tester, 'Dextrose', '20');
    await enterInto(tester, 'Rate', '6');

    expect(find.textContaining('usually needs central access'), findsOneWidget);
  });

  testWidgets('clearing a patient keeps the other records', (
    WidgetTester tester,
  ) async {
    final PatientStore store = await pumpApp(tester);

    await enterInto(tester, 'Patient 1', 'Baby A');
    await enterInto(tester, 'Weight', '1500');
    await tester.tap(find.widgetWithText(ActionChip, 'Add patient'));
    await tester.pumpAndSettle();
    await enterInto(tester, 'Weight', '900');

    await tester.tap(find.byTooltip('Patient actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear this patient'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a weight to see totals'), findsOneWidget);
    expect(store.patients.first.name, 'Baby A');
    expect(store.patients.first.weightGrams, 1500);
  });
}
