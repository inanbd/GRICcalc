import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/fluid_input.dart';
import '../models/patient.dart';

/// Holds every patient record and keeps the device copy in step.
///
/// Nothing in the app asks to be saved: each edit updates the list and
/// schedules a write, so a record survives closing the app without anyone
/// having to remember a save button.
class PatientStore extends ChangeNotifier {
  PatientStore({@visibleForTesting Duration? writeDelay})
    : _writeDelay = writeDelay ?? const Duration(milliseconds: 400);

  static const String _patientsKey = 'patients.v1';
  static const String _selectedKey = 'patients.selected.v1';

  /// How long to coalesce edits before writing. Typing a weight fires an edit
  /// per keystroke, and each write is a full re-encode of the list.
  final Duration _writeDelay;

  SharedPreferences? _prefs;
  Timer? _pendingWrite;
  int _nextId = 0;

  List<Patient> _patients = <Patient>[];
  String? _selectedId;
  bool _isLoaded = false;

  List<Patient> get patients => List<Patient>.unmodifiable(_patients);

  /// False until the stored records have been read, so the UI can hold off
  /// rather than flashing an empty state over saved work.
  bool get isLoaded => _isLoaded;

  Patient? get selected {
    if (_patients.isEmpty) return null;
    return _patients.firstWhere(
      (Patient p) => p.id == _selectedId,
      orElse: () => _patients.first,
    );
  }

  int get selectedIndex {
    final Patient? current = selected;
    if (current == null) return -1;
    return _patients.indexWhere((Patient p) => p.id == current.id);
  }

  /// Reads stored records, falling back to a single empty patient so the app
  /// always opens ready to type into.
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final String? raw = _prefs!.getString(_patientsKey);

    List<Patient> restored = <Patient>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(raw);
        if (decoded is List) {
          restored = <Patient>[
            for (final Object? entry in decoded) ?Patient.fromJson(entry),
          ];
        }
      } on FormatException {
        // Unreadable storage is treated as no storage: better to start clean
        // than to fail to open at all.
        restored = <Patient>[];
      }
    }

    _patients = restored;
    _seedIdCounter();
    if (_patients.isEmpty) {
      _patients = <Patient>[_blankPatient()];
    }

    final String? storedSelection = _prefs!.getString(_selectedKey);
    _selectedId = _patients.any((Patient p) => p.id == storedSelection)
        ? storedSelection
        : _patients.first.id;

    _isLoaded = true;
    notifyListeners();
  }

  /// Restarts id generation past anything already stored, so a restored record
  /// can never collide with a newly created one.
  void _seedIdCounter() {
    for (final Patient patient in _patients) {
      _nextId = _maxIdSuffix(patient.id, _nextId);
      for (final FluidInput fluid in patient.fluids) {
        _nextId = _maxIdSuffix(fluid.id, _nextId);
      }
    }
  }

  static int _maxIdSuffix(String id, int current) {
    final int dash = id.lastIndexOf('-');
    final int? suffix = dash == -1
        ? null
        : int.tryParse(id.substring(dash + 1));
    return suffix != null && suffix >= current ? suffix + 1 : current;
  }

  String _newId(String prefix) => '$prefix-${_nextId++}';

  Patient _blankPatient() => Patient(
    id: _newId('patient'),
    name: '',
    weightGrams: null,
    // Start with the commonest maintenance fluid already on the list, so a new
    // patient needs a weight and a rate and nothing else.
    fluids: <FluidInput>[newFluid(name: 'D10W', dextrosePercent: 10)],
  );

  FluidInput newFluid({
    String name = '',
    double dextrosePercent = 10,
    FluidRoute route = FluidRoute.intravenous,
  }) {
    final bool isFeed = route == FluidRoute.enteral;
    return FluidInput(
      id: _newId('fluid'),
      name: name,
      dextrosePercent: dextrosePercent,
      // Feeds are ordered as a volume every few hours; drips are ordered by rate.
      rateUnit: isFeed ? RateUnit.mlPerFeed : RateUnit.mlPerHour,
      rateValue: 0,
      route: route,
      // A feed's carbohydrate is an estimate, so it stays out of the GIR until
      // it is deliberately switched on.
      countsTowardGir: !isFeed,
    );
  }

  void select(String id) {
    if (_selectedId == id || !_patients.any((Patient p) => p.id == id)) return;
    _selectedId = id;
    _scheduleWrite();
    notifyListeners();
  }

  /// Adds an empty record and switches to it, so "new patient" is a single tap.
  Patient addPatient() {
    final Patient patient = _blankPatient();
    _patients = <Patient>[..._patients, patient];
    _selectedId = patient.id;
    _scheduleWrite();
    notifyListeners();
    return patient;
  }

  /// Copies a record's fluids onto a fresh patient - siblings and unit
  /// protocols mean the next baby is often on the same lines.
  Patient duplicatePatient(String id) {
    final Patient source = _patients.firstWhere((Patient p) => p.id == id);
    final Patient copy = Patient(
      id: _newId('patient'),
      name: source.name.trim().isEmpty ? '' : '${source.name.trim()} (copy)',
      weightGrams: source.weightGrams,
      fluids: <FluidInput>[
        for (final FluidInput fluid in source.fluids)
          FluidInput(
            id: _newId('fluid'),
            name: fluid.name,
            dextrosePercent: fluid.dextrosePercent,
            rateUnit: fluid.rateUnit,
            rateValue: fluid.rateValue,
            route: fluid.route,
            feedIntervalHours: fluid.feedIntervalHours,
            countsTowardGir: fluid.countsTowardGir,
          ),
      ],
    );
    _patients = <Patient>[..._patients, copy];
    _selectedId = copy.id;
    _scheduleWrite();
    notifyListeners();
    return copy;
  }

  /// Removes a record. The list is never left empty - the last removal leaves a
  /// fresh blank patient behind rather than an empty screen.
  void removePatient(String id) {
    final int index = _patients.indexWhere((Patient p) => p.id == id);
    if (index == -1) return;

    _patients = <Patient>[
      for (final Patient p in _patients)
        if (p.id != id) p,
    ];

    if (_patients.isEmpty) {
      _patients = <Patient>[_blankPatient()];
      _selectedId = _patients.first.id;
    } else if (_selectedId == id) {
      _selectedId = _patients[index.clamp(0, _patients.length - 1)].id;
    }

    _scheduleWrite();
    notifyListeners();
  }

  void updateSelected(Patient Function(Patient) change) {
    final Patient? current = selected;
    if (current == null) return;
    final Patient updated = change(current);
    _patients = <Patient>[
      for (final Patient p in _patients)
        if (p.id == updated.id) updated else p,
    ];
    _scheduleWrite();
    notifyListeners();
  }

  void setWeight(double? weightGrams) {
    updateSelected(
      (Patient p) => weightGrams == null
          ? p.copyWith(clearWeight: true)
          : p.copyWith(weightGrams: weightGrams),
    );
  }

  void setName(String name) =>
      updateSelected((Patient p) => p.copyWith(name: name));

  void addFluid({
    String name = '',
    double dextrosePercent = 10,
    FluidRoute route = FluidRoute.intravenous,
  }) {
    updateSelected(
      (Patient p) => p.copyWith(
        fluids: <FluidInput>[
          ...p.fluids,
          newFluid(name: name, dextrosePercent: dextrosePercent, route: route),
        ],
      ),
    );
  }

  void updateFluid(FluidInput updated) {
    updateSelected(
      (Patient p) => p.copyWith(
        fluids: <FluidInput>[
          for (final FluidInput f in p.fluids)
            if (f.id == updated.id) updated else f,
        ],
      ),
    );
  }

  void removeFluid(String fluidId) {
    updateSelected(
      (Patient p) => p.copyWith(
        fluids: <FluidInput>[
          for (final FluidInput f in p.fluids)
            if (f.id != fluidId) f,
        ],
      ),
    );
  }

  /// Clears the current record back to empty without disturbing the others.
  void resetSelected() {
    updateSelected(
      (Patient p) => Patient(
        id: p.id,
        name: '',
        weightGrams: null,
        fluids: <FluidInput>[newFluid(name: 'D10W', dextrosePercent: 10)],
      ),
    );
  }

  void _scheduleWrite() {
    _pendingWrite?.cancel();
    _pendingWrite = Timer(_writeDelay, flush);
  }

  /// Writes immediately, rather than waiting out the debounce.
  Future<void> flush() async {
    _pendingWrite?.cancel();
    _pendingWrite = null;
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(
      _patientsKey,
      jsonEncode(_patients.map((Patient p) => p.toJson()).toList()),
    );
    final String? selectedId = _selectedId;
    if (selectedId != null) {
      await prefs.setString(_selectedKey, selectedId);
    }
  }

  @override
  void dispose() {
    _pendingWrite?.cancel();
    super.dispose();
  }
}
