import 'package:flutter/foundation.dart';

/// The unit an infusion was ordered in.
///
/// NICU orders are written both ways: pumps are programmed in mL/hr, while
/// daily fluid goals are prescribed in mL/kg/day. Either can be entered here
/// and the other is derived from the baby's weight.
enum RateUnit {
  mlPerHour('mL/hr'),
  mlPerKgPerDay('mL/kg/day');

  const RateUnit(this.label);

  final String label;
}

/// A single infusion line: what is running, how concentrated it is, how fast.
@immutable
class FluidInput {
  const FluidInput({
    required this.id,
    required this.name,
    required this.dextrosePercent,
    required this.rateUnit,
    required this.rateValue,
  });

  /// Stable identity, so removing a line does not shuffle the other text fields.
  final String id;

  final String name;

  /// Grams of dextrose per 100 mL (e.g. 10 for D10W).
  final double dextrosePercent;

  final RateUnit rateUnit;

  /// The rate as entered, expressed in [rateUnit].
  final double rateValue;

  /// Serialises to the shape stored on the device.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'dextrosePercent': dextrosePercent,
    'rateUnit': rateUnit.name,
    'rateValue': rateValue,
  };

  /// Rebuilds a line from stored JSON, tolerating anything missing or of the
  /// wrong type so one bad record cannot wipe out a whole patient list.
  static FluidInput? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final Object? id = json['id'];
    if (id is! String || id.isEmpty) return null;
    return FluidInput(
      id: id,
      name: json['name'] is String ? json['name'] as String : '',
      dextrosePercent: _toDouble(json['dextrosePercent']) ?? 0,
      rateUnit: RateUnit.values.firstWhere(
        (RateUnit unit) => unit.name == json['rateUnit'],
        orElse: () => RateUnit.mlPerHour,
      ),
      rateValue: _toDouble(json['rateValue']) ?? 0,
    );
  }

  FluidInput copyWith({
    String? name,
    double? dextrosePercent,
    RateUnit? rateUnit,
    double? rateValue,
  }) {
    return FluidInput(
      id: id,
      name: name ?? this.name,
      dextrosePercent: dextrosePercent ?? this.dextrosePercent,
      rateUnit: rateUnit ?? this.rateUnit,
      rateValue: rateValue ?? this.rateValue,
    );
  }
}

/// Reads a number that may have been stored as an int, a double, or a string.
double? _toDouble(Object? value) {
  final double? parsed = switch (value) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s),
    _ => null,
  };
  return parsed != null && parsed.isFinite ? parsed : null;
}

/// Common NICU fluids, so a line can be set up with one tap.
@immutable
class FluidPreset {
  const FluidPreset(this.name, this.dextrosePercent);

  final String name;
  final double dextrosePercent;

  static const List<FluidPreset> all = <FluidPreset>[
    FluidPreset('D5W', 5),
    FluidPreset('D7.5W', 7.5),
    FluidPreset('D10W', 10),
    FluidPreset('D12.5W', 12.5),
    FluidPreset('D15W', 15),
    FluidPreset('D20W', 20),
    FluidPreset('D25W', 25),
    FluidPreset('TPN', 12.5),
    FluidPreset('Lipid 20%', 0),
    FluidPreset('NS', 0),
    FluidPreset('Breast milk', 7),
  ];
}
