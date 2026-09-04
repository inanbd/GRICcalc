import 'package:flutter/foundation.dart';

/// How a line reaches the baby.
///
/// The distinction matters because "GIR" conventionally means intravenous
/// glucose. Feeds always count towards the day's fluid, but whether their
/// carbohydrate counts towards the GIR is the clinician's call.
enum FluidRoute {
  intravenous('IV'),
  enteral('Feed');

  const FluidRoute(this.label);

  final String label;
}

/// The unit an order was written in.
///
/// Orders are written all three ways: pumps are programmed in mL/hr, daily
/// goals in mL/kg/day, and feeds as a volume every few hours.
enum RateUnit {
  mlPerHour('mL/hr', 'mL/hr'),
  mlPerKgPerDay('mL/kg/day', 'mL/kg/day'),
  mlPerFeed('mL/feed', 'Per feed');

  const RateUnit(this.label, this.shortLabel);

  /// Unit suffix shown beside the value.
  final String label;

  /// Compact label for the unit selector.
  final String shortLabel;
}

/// Feed intervals that get written on a chart, plus the hours they mean.
const List<double> feedIntervals = <double>[1, 2, 3, 4, 6, 8, 12, 24];

/// Formats an interval the way it is prescribed: 3 -> "q3h".
String feedIntervalLabel(double hours) {
  if (hours <= 0) return 'q?h';
  final String value = hours == hours.roundToDouble()
      ? hours.round().toString()
      : hours.toString();
  return 'q${value}h';
}

/// A single line: what is running or being fed, how concentrated it is, and
/// how fast.
@immutable
class FluidInput {
  const FluidInput({
    required this.id,
    required this.name,
    required this.dextrosePercent,
    required this.rateUnit,
    required this.rateValue,
    this.route = FluidRoute.intravenous,
    this.feedIntervalHours = 3,
    this.countsTowardGir = true,
  });

  /// Stable identity, so removing a line does not shuffle the other text fields.
  final String id;

  final String name;

  /// Grams of carbohydrate per 100 mL: dextrose for an infusion, and the
  /// carbohydrate content for a feed.
  final double dextrosePercent;

  final RateUnit rateUnit;

  /// The rate as entered, in [rateUnit]. For [RateUnit.mlPerFeed] this is the
  /// volume of one feed.
  final double rateValue;

  final FluidRoute route;

  /// Hours between feeds, used with [RateUnit.mlPerFeed]. A 20 mL feed on a
  /// 3-hour interval is 8 feeds and 160 mL a day.
  final double feedIntervalHours;

  /// Whether this line's carbohydrate is added to the total GIR. Always true
  /// for an infusion; opt-in for a feed, where the figure is an estimate.
  final bool countsTowardGir;

  bool get isFeed => route == FluidRoute.enteral;

  /// Feeds in 24 hours, or null when the line is not fed in boluses.
  double? get feedsPerDay {
    if (rateUnit != RateUnit.mlPerFeed || feedIntervalHours <= 0) return null;
    return 24 / feedIntervalHours;
  }

  FluidInput copyWith({
    String? name,
    double? dextrosePercent,
    RateUnit? rateUnit,
    double? rateValue,
    FluidRoute? route,
    double? feedIntervalHours,
    bool? countsTowardGir,
  }) {
    return FluidInput(
      id: id,
      name: name ?? this.name,
      dextrosePercent: dextrosePercent ?? this.dextrosePercent,
      rateUnit: rateUnit ?? this.rateUnit,
      rateValue: rateValue ?? this.rateValue,
      route: route ?? this.route,
      feedIntervalHours: feedIntervalHours ?? this.feedIntervalHours,
      countsTowardGir: countsTowardGir ?? this.countsTowardGir,
    );
  }

  /// Serialises to the shape stored on the device.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'dextrosePercent': dextrosePercent,
    'rateUnit': rateUnit.name,
    'rateValue': rateValue,
    'route': route.name,
    'feedIntervalHours': feedIntervalHours,
    'countsTowardGir': countsTowardGir,
  };

  /// Rebuilds a line from stored JSON, tolerating anything missing or of the
  /// wrong type so one bad record cannot wipe out a whole patient list.
  ///
  /// Records written before feeds existed have no route, and default to an
  /// infusion that counts towards the GIR - which is what they were.
  static FluidInput? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final Object? id = json['id'];
    if (id is! String || id.isEmpty) return null;

    final FluidRoute route = FluidRoute.values.firstWhere(
      (FluidRoute r) => r.name == json['route'],
      orElse: () => FluidRoute.intravenous,
    );

    return FluidInput(
      id: id,
      name: json['name'] is String ? json['name'] as String : '',
      dextrosePercent: _toDouble(json['dextrosePercent']) ?? 0,
      rateUnit: RateUnit.values.firstWhere(
        (RateUnit unit) => unit.name == json['rateUnit'],
        orElse: () => RateUnit.mlPerHour,
      ),
      rateValue: _toDouble(json['rateValue']) ?? 0,
      route: route,
      feedIntervalHours: _toDouble(json['feedIntervalHours']) ?? 3,
      countsTowardGir: json['countsTowardGir'] is bool
          ? json['countsTowardGir'] as bool
          : route == FluidRoute.intravenous,
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

/// A fluid or feed that can be added in one tap.
@immutable
class FluidPreset {
  const FluidPreset(
    this.name,
    this.dextrosePercent, {
    this.route = FluidRoute.intravenous,
  });

  final String name;

  /// Grams of carbohydrate per 100 mL.
  final double dextrosePercent;

  final FluidRoute route;

  /// Infusions, by their dextrose concentration.
  static const List<FluidPreset> infusions = <FluidPreset>[
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
  ];

  /// Feeds, by typical carbohydrate content in g per 100 mL.
  ///
  /// These are starting points, not product data: fortification, batch and
  /// recipe all move them, so the figure stays editable on every line and the
  /// results call the enteral GIR an estimate. Values follow the table
  /// published at infantfeeds.com/gir-calculator.
  static const List<FluidPreset> feeds = <FluidPreset>[
    FluidPreset('Breast milk', 7, route: FluidRoute.enteral),
    FluidPreset('BM + Prolacta', 7.6, route: FluidRoute.enteral),
    FluidPreset('BM + Similac HMF 22', 7.7, route: FluidRoute.enteral),
    FluidPreset('BM + Similac HMF 24', 8.3, route: FluidRoute.enteral),
    FluidPreset('BM + Enfamil HMF 22', 6.9, route: FluidRoute.enteral),
    FluidPreset('BM + Enfamil HMF 24', 6.8, route: FluidRoute.enteral),
    FluidPreset('Formula', 7.5, route: FluidRoute.enteral),
  ];

  static List<FluidPreset> get all => <FluidPreset>[...infusions, ...feeds];
}
