import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:griccalc/logic/patient_store.dart';
import 'package:griccalc/logic/settings_store.dart';
import 'package:griccalc/main.dart';
import 'package:griccalc/models/fluid_input.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps the app over empty storage on a tall phone-sized surface.
Future<PatientStore> pumpApp(
  WidgetTester tester, {
  Size size = const Size(500, 2200),
  SettingsStore? settings,
}) async {
  // A caller that brings its own settings store has already reset storage and
  // loaded it; resetting again here would hand that store a stale backing map.
  if (settings == null) {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  }
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final PatientStore store = PatientStore(writeDelay: Duration.zero);
  final SettingsStore appSettings = settings ?? SettingsStore();
  await tester.pumpWidget(
    GirCalculatorApp(store: store, settings: appSettings),
  );
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

    // Scope to the segmented control: other widgets carry similar labels.
    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<RateUnit>),
        matching: find.text('mL/kg/d'),
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

  testWidgets('a feed adds to the day\'s fluid but not to the GIR', (
    WidgetTester tester,
  ) async {
    // Wide, so the results panel is on screen rather than behind the sheet.
    final PatientStore store = await pumpApp(
      tester,
      size: const Size(1500, 1600),
    );

    await enterInto(tester, 'Weight', '1500');
    await enterInto(tester, 'Rate', '4'); // D10W at 4 mL/hr

    await tester.tap(find.widgetWithText(ActionChip, 'Breast milk'));
    await tester.pumpAndSettle();

    // A feed line arrives ordered per feed, at q3h, and out of the GIR.
    final FluidInput fed = store.selected!.fluids.last;
    expect(fed.route, FluidRoute.enteral);
    expect(fed.rateUnit, RateUnit.mlPerFeed);
    expect(fed.feedIntervalHours, 3);
    expect(fed.countsTowardGir, isFalse);
    expect(fed.dextrosePercent, 7);

    // 20 mL every 3 hours.
    final Finder volume = find.ancestor(
      of: find.text('Volume'),
      matching: find.byType(TextField),
    );
    await tester.enterText(volume, '20');
    await tester.pumpAndSettle();

    // GIR stays the drip alone; the day's fluid takes in both routes.
    expect(find.text('4.44'), findsWidgets);
    expect(find.text('170.7'), findsWidgets);
    expect(
      find.textContaining('Feeds are shown but not added in'),
      findsOneWidget,
    );
  });

  testWidgets('switching a feed on adds it to the GIR', (
    WidgetTester tester,
  ) async {
    // Wide, so the results panel is on screen rather than behind the sheet.
    final PatientStore store = await pumpApp(
      tester,
      size: const Size(1500, 1600),
    );

    await enterInto(tester, 'Weight', '1500');
    await enterInto(tester, 'Rate', '4');
    await tester.tap(find.widgetWithText(ActionChip, 'Breast milk'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.ancestor(of: find.text('Volume'), matching: find.byType(TextField)),
      '20',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Count towards GIR'));
    await tester.pumpAndSettle();

    expect(store.selected!.fluids.last.countsTowardGir, isTrue);
    // 4.44 from the drip plus 5.19 from the feed.
    expect(find.text('9.63'), findsWidgets);
    expect(
      find.textContaining('Enteral glucose is an estimate'),
      findsOneWidget,
    );
  });

  testWidgets('a feed keeps its volume when switched to mL/hr', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await enterInto(tester, 'Weight', '1500');
    await tester.tap(find.widgetWithText(ActionChip, 'Breast milk'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.ancestor(of: find.text('Volume'), matching: find.byType(TextField)),
      '20',
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find
          .descendant(
            of: find.byType(SegmentedButton<RateUnit>),
            matching: find.text('mL/hr'),
          )
          .last,
    );
    await tester.pumpAndSettle();

    // 20 mL q3h is 6.67 mL/hr, so the daily volume is unchanged.
    final TextField rate = tester.widget<TextField>(
      find
          .ancestor(of: find.text('Rate'), matching: find.byType(TextField))
          .last,
    );
    expect(rate.controller?.text, '6.67');
  });

  testWidgets('feeds are stored and restored with the patient', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await enterInto(tester, 'Weight', '1500');
    await tester.tap(find.widgetWithText(ActionChip, 'BM + Similac HMF 24'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.ancestor(of: find.text('Volume'), matching: find.byType(TextField)),
      '25',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Count towards GIR'));
    await tester.pumpAndSettle();

    final PatientStore reopened = PatientStore(writeDelay: Duration.zero);
    await reopened.load();
    final FluidInput restored = reopened.selected!.fluids.last;
    expect(restored.name, 'BM + Similac HMF 24');
    expect(restored.route, FluidRoute.enteral);
    expect(restored.dextrosePercent, 8.3);
    expect(restored.rateValue, 25);
    expect(restored.feedIntervalHours, 3);
    expect(restored.countsTowardGir, isTrue);
  });

  group('appearance', () {
    testWidgets('follows the device until a mode is chosen', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SettingsStore settings = SettingsStore();
      await settings.load();
      await pumpApp(tester, settings: settings);

      expect(settings.themeMode, ThemeMode.system);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.system,
      );
    });

    testWidgets('picking dark switches the app over and sticks', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SettingsStore settings = SettingsStore();
      await settings.load();
      await pumpApp(tester, settings: settings);

      // The dedicated button cycles: device -> light -> dark.
      await tester.tap(find.byTooltip('Appearance: Match device'));
      await tester.pumpAndSettle();
      expect(settings.themeMode, ThemeMode.light);

      await tester.tap(find.byTooltip('Appearance: Light'));
      await tester.pumpAndSettle();

      expect(settings.themeMode, ThemeMode.dark);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.dark,
      );

      // A store built over the same storage sees the choice already.
      final SettingsStore reopened = SettingsStore();
      await reopened.load();
      expect(reopened.themeMode, ThemeMode.dark);
    });

    testWidgets('offers all three modes', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SettingsStore settings = SettingsStore();
      await settings.load();
      await pumpApp(tester, settings: settings);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();

      expect(find.text('Match device'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });
  });

  group('adding a line puts the cursor in it', () {
    testWidgets('a new fluid takes focus on its rate field', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await enterInto(tester, 'Weight', '1500');

      await tester.tap(find.widgetWithText(ActionChip, 'D12.5W'));
      await tester.pumpAndSettle();

      // The last rate field is the one just added, and it holds the cursor.
      final Finder rates = find.ancestor(
        of: find.text('Rate'),
        matching: find.byType(TextField),
      );
      final TextField added = tester.widget<TextField>(rates.last);
      expect(added.focusNode?.hasFocus, isTrue);
      // Its placeholder is selected, so the first keystroke replaces it.
      expect(added.controller?.selection.start, 0);
      expect(added.controller?.selection.end, added.controller?.text.length);
    });

    testWidgets('a new feed takes focus on its volume field', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await enterInto(tester, 'Weight', '1500');

      await tester.tap(find.widgetWithText(ActionChip, 'Breast milk'));
      await tester.pumpAndSettle();

      final TextField volume = tester.widget<TextField>(
        find.ancestor(
          of: find.text('Volume'),
          matching: find.byType(TextField),
        ),
      );
      expect(volume.focusNode?.hasFocus, isTrue);
    });

    testWidgets('typing straight away replaces the placeholder', (
      WidgetTester tester,
    ) async {
      final PatientStore store = await pumpApp(tester);
      await enterInto(tester, 'Weight', '1500');

      await tester.tap(find.widgetWithText(ActionChip, 'Breast milk'));
      await tester.pumpAndSettle();
      tester.testTextInput.enterText('20');
      await tester.pumpAndSettle();

      expect(store.selected!.fluids.last.rateValue, 20);
    });

    testWidgets('switching patients does not re-open the keyboard', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await enterInto(tester, 'Weight', '1500');
      await tester.tap(find.widgetWithText(ActionChip, 'D12.5W'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ActionChip, 'Add patient'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Patient 1'));
      await tester.pumpAndSettle();

      final Finder rates = find.ancestor(
        of: find.text('Rate'),
        matching: find.byType(TextField),
      );
      for (final Element element in rates.evaluate()) {
        final TextField field = element.widget as TextField;
        expect(field.focusNode?.hasFocus ?? false, isFalse);
      }
    });
  });

  group('reference material', () {
    testWidgets('the formula sheet covers feeds as well as infusions', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, size: const Size(500, 2400));

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('How this is calculated'));
      await tester.pumpAndSettle();

      expect(find.text('How this is calculated'), findsWidgets);
      expect(find.text('Feeds - volume'), findsOneWidget);
      expect(find.text('Feeds - glucose'), findsOneWidget);
      expect(find.textContaining('feeds per day = 24'), findsOneWidget);
      expect(find.textContaining('20 mL q3h'), findsOneWidget);
      expect(find.textContaining('5.19 mg/kg/min'), findsOneWidget);
    });

    testWidgets('the disclaimer names who decides', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, size: const Size(500, 2400));

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disclaimer & safety'));
      await tester.pumpAndSettle();

      expect(find.text('Disclaimer & safety'), findsWidgets);
      expect(
        find.textContaining('final decision rests with the treating physician'),
        findsOneWidget,
      );
      expect(find.textContaining('not a medical device'), findsOneWidget);
      expect(find.text('Enteral GIR is an estimate'), findsOneWidget);
      expect(find.text('Your data stays on the device'), findsOneWidget);
    });
  });

  group('copying', () {
    testWidgets('puts the three figures on the clipboard', (
      WidgetTester tester,
    ) async {
      final List<MethodCall> calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pumpApp(tester);
      await enterInto(tester, 'Weight', '1500');
      await enterInto(tester, 'Rate', '4');

      await tester.tap(find.byTooltip('Copy GIR values'));
      await tester.pumpAndSettle();

      final MethodCall copy = calls.firstWhere(
        (MethodCall c) => c.method == 'Clipboard.setData',
      );
      expect(
        (copy.arguments as Map<Object?, Object?>)['text'],
        'IV GIR: 4.44 mg/kg/min\n'
        'Enteral GIR: 0.00 mg/kg/min\n'
        'Total GIR: 4.44 mg/kg/min',
      );
      expect(find.text('GIR values copied.'), findsOneWidget);
    });

    testWidgets('asks for a weight before copying anything', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(find.byTooltip('Copy GIR values'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a weight first.'), findsOneWidget);
    });
  });
}
