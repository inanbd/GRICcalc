import 'package:flutter_test/flutter_test.dart';
import 'package:griccalc/logic/patient_store.dart';
import 'package:griccalc/models/fluid_input.dart';
import 'package:griccalc/models/patient.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds a store over the given stored state and waits for it to load.
Future<PatientStore> loadStore([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  final PatientStore store = PatientStore(writeDelay: Duration.zero);
  await store.load();
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('loading', () {
    test(
      'starts with one ready-to-use patient when nothing is stored',
      () async {
        final PatientStore store = await loadStore();

        expect(store.isLoaded, isTrue);
        expect(store.patients, hasLength(1));
        expect(store.selected, isNotNull);
        expect(store.selected!.weightGrams, isNull);
        // A new record arrives with the commonest maintenance fluid on it.
        expect(store.selected!.fluids.single.name, 'D10W');
        expect(store.selected!.fluids.single.dextrosePercent, 10);
      },
    );

    test('restores stored patients and the previous selection', () async {
      final PatientStore first = await loadStore();
      first.setName('Baby A');
      first.setWeight(1250);
      final Patient second = first.addPatient();
      first.setName('Baby B');
      await first.flush();

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final PatientStore restored = PatientStore(writeDelay: Duration.zero);
      await restored.load();

      expect(restored.patients.map((Patient p) => p.name), <String>[
        'Baby A',
        'Baby B',
      ]);
      expect(restored.patients.first.weightGrams, 1250);
      expect(restored.selected!.id, second.id);
      expect(prefs.getString('patients.v1'), isNotNull);
    });

    test('a new patient never reuses a restored id', () async {
      final PatientStore first = await loadStore();
      final Patient a = first.addPatient();
      final Patient b = first.addPatient();
      await first.flush();

      final PatientStore restored = PatientStore(writeDelay: Duration.zero);
      await restored.load();
      final Patient fresh = restored.addPatient();

      expect(<String>{a.id, b.id}, isNot(contains(fresh.id)));
      expect(
        restored.patients.map((Patient p) => p.id).toSet(),
        hasLength(restored.patients.length),
      );
    });

    test('unreadable storage falls back to a blank patient', () async {
      final PatientStore store = await loadStore(<String, Object>{
        'flutter.patients.v1': 'not json at all',
      });

      expect(store.patients, hasLength(1));
      expect(store.selected!.name, isEmpty);
    });

    test('drops unreadable records but keeps the readable ones', () async {
      final PatientStore store = await loadStore(<String, Object>{
        'flutter.patients.v1':
            '[{"id":"patient-0","name":"Kept","weightGrams":900,"fluids":[]},'
            '{"name":"No id"},'
            '"nonsense"]',
      });

      expect(store.patients.map((Patient p) => p.name), <String>['Kept']);
      expect(store.patients.single.weightGrams, 900);
    });
  });

  group('editing', () {
    test('edits apply to the selected patient only', () async {
      final PatientStore store = await loadStore();
      store.setName('Baby A');
      store.setWeight(1000);

      store.addPatient();
      store.setName('Baby B');
      store.setWeight(2000);

      expect(store.patients[0].name, 'Baby A');
      expect(store.patients[0].weightGrams, 1000);
      expect(store.patients[1].name, 'Baby B');
      expect(store.patients[1].weightGrams, 2000);
    });

    test('adding a preset fluid fills in its name and concentration', () async {
      final PatientStore store = await loadStore();
      store.addFluid(name: 'D12.5W', dextrosePercent: 12.5);

      final FluidInput added = store.selected!.fluids.last;
      expect(added.name, 'D12.5W');
      expect(added.dextrosePercent, 12.5);
      expect(added.rateValue, 0);
    });

    test('duplicating copies the fluids onto a new record', () async {
      final PatientStore store = await loadStore();
      store.setName('Twin 1');
      store.setWeight(1400);
      store.addFluid(name: 'TPN', dextrosePercent: 12.5);

      final Patient copy = store.duplicatePatient(store.selected!.id);

      expect(store.patients, hasLength(2));
      expect(copy.name, 'Twin 1 (copy)');
      expect(copy.weightGrams, 1400);
      expect(copy.fluids.map((FluidInput f) => f.name), <String>[
        'D10W',
        'TPN',
      ]);
      // The copy owns its lines, so editing one does not change the original.
      final Set<String> originalIds = store.patients.first.fluids
          .map((FluidInput f) => f.id)
          .toSet();
      expect(
        copy.fluids.map((FluidInput f) => f.id).any(originalIds.contains),
        isFalse,
      );
      expect(store.selected!.id, copy.id);
    });

    test('deleting the last patient leaves a blank one behind', () async {
      final PatientStore store = await loadStore();
      store.removePatient(store.selected!.id);

      expect(store.patients, hasLength(1));
      expect(store.selected!.name, isEmpty);
      expect(store.selected!.weightGrams, isNull);
    });

    test('deleting moves the selection to a neighbouring patient', () async {
      final PatientStore store = await loadStore();
      store.setName('A');
      store.addPatient();
      store.setName('B');
      store.addPatient();
      store.setName('C');

      store.select(store.patients[1].id);
      store.removePatient(store.patients[1].id);

      expect(store.patients.map((Patient p) => p.name), <String>['A', 'C']);
      expect(store.selected!.name, 'C');
    });

    test('clearing resets one record without touching the others', () async {
      final PatientStore store = await loadStore();
      store.setName('Keep me');
      store.setWeight(1100);
      store.addPatient();
      store.setName('Clear me');
      store.setWeight(2200);

      store.resetSelected();

      expect(store.patients.first.name, 'Keep me');
      expect(store.patients.first.weightGrams, 1100);
      expect(store.selected!.name, isEmpty);
      expect(store.selected!.weightGrams, isNull);
      expect(store.selected!.fluids.single.name, 'D10W');
    });

    test('removing a fluid leaves the rest in order', () async {
      final PatientStore store = await loadStore();
      store.addFluid(name: 'TPN', dextrosePercent: 12.5);
      store.addFluid(name: 'Lipid 20%', dextrosePercent: 0);

      store.removeFluid(store.selected!.fluids[1].id);

      expect(store.selected!.fluids.map((FluidInput f) => f.name), <String>[
        'D10W',
        'Lipid 20%',
      ]);
    });
  });

  group('persistence', () {
    test('every edit is written without an explicit save', () async {
      final PatientStore store = await loadStore();
      store.setName('Autosaved');
      store.setWeight(1750);
      // Zero debounce still defers to a timer, so let it fire.
      await Future<void>.delayed(Duration.zero);

      final PatientStore restored = PatientStore(writeDelay: Duration.zero);
      await restored.load();
      expect(restored.selected!.name, 'Autosaved');
      expect(restored.selected!.weightGrams, 1750);
    });

    test('a patient survives a round trip through JSON intact', () {
      const Patient patient = Patient(
        id: 'patient-7',
        name: 'Baby C',
        weightGrams: 1325.5,
        fluids: <FluidInput>[
          FluidInput(
            id: 'fluid-1',
            name: 'D12.5W',
            dextrosePercent: 12.5,
            rateUnit: RateUnit.mlPerKgPerDay,
            rateValue: 120,
          ),
        ],
      );

      final Patient? restored = Patient.fromJson(patient.toJson());

      expect(restored, isNotNull);
      expect(restored!.id, 'patient-7');
      expect(restored.name, 'Baby C');
      expect(restored.weightGrams, 1325.5);
      expect(restored.fluids.single.rateUnit, RateUnit.mlPerKgPerDay);
      expect(restored.fluids.single.rateValue, 120);
      expect(restored.fluids.single.dextrosePercent, 12.5);
    });

    test('a non-positive stored weight reads back as no weight', () {
      final Patient? restored = Patient.fromJson(<String, dynamic>{
        'id': 'patient-1',
        'name': 'X',
        'weightGrams': 0,
        'fluids': <Object?>[],
      });

      expect(restored!.weightGrams, isNull);
    });
  });
}
