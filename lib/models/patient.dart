import 'package:flutter/foundation.dart';

import 'fluid_input.dart';

/// One baby's record: who they are, what they weigh, and what is running.
///
/// Records are kept on the device so the app opens on the same set of babies
/// it was left on, and switching between them costs a single tap.
@immutable
class Patient {
  const Patient({
    required this.id,
    required this.name,
    required this.weightGrams,
    required this.fluids,
  });

  final String id;

  /// Whatever the unit uses to identify a cot: a first name, a bed number, an
  /// MRN. Free text, because that varies between units.
  final String name;

  /// Dosing weight in grams. Null until it has been entered.
  final double? weightGrams;

  final List<FluidInput> fluids;

  /// The label to show when [name] has not been filled in yet.
  String displayName(int position) =>
      name.trim().isEmpty ? 'Patient $position' : name.trim();

  Patient copyWith({
    String? name,
    double? weightGrams,
    bool clearWeight = false,
    List<FluidInput>? fluids,
  }) {
    return Patient(
      id: id,
      name: name ?? this.name,
      weightGrams: clearWeight ? null : (weightGrams ?? this.weightGrams),
      fluids: fluids ?? this.fluids,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'weightGrams': weightGrams,
    'fluids': fluids.map((FluidInput f) => f.toJson()).toList(),
  };

  /// Rebuilds a patient from stored JSON, dropping anything unreadable rather
  /// than throwing, so a single corrupt record cannot lose the others.
  static Patient? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final Object? id = json['id'];
    if (id is! String || id.isEmpty) return null;

    final Object? rawWeight = json['weightGrams'];
    final double? weight = switch (rawWeight) {
      final num n when n.isFinite && n > 0 => n.toDouble(),
      final String s => double.tryParse(s),
      _ => null,
    };

    final List<FluidInput> fluids = <FluidInput>[
      if (json['fluids'] is List)
        for (final Object? entry in json['fluids'] as List<Object?>)
          ?FluidInput.fromJson(entry),
    ];

    return Patient(
      id: id,
      name: json['name'] is String ? json['name'] as String : '',
      weightGrams: weight != null && weight.isFinite && weight > 0
          ? weight
          : null,
      fluids: fluids,
    );
  }
}
