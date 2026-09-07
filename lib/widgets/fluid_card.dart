import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/formatting.dart';
import '../logic/gir_calculator.dart';
import '../models/fluid_input.dart';
import '../theme.dart';

/// Content padding for the card's fields, tighter than Material's dense
/// default so that a list of lines takes less of the screen.
const EdgeInsets _fieldPadding = EdgeInsets.symmetric(
  horizontal: 10,
  vertical: 10,
);

/// One infusion line: name, dextrose concentration, rate, and what it delivers.
///
/// The card owns its text controllers so that editing one line never disturbs
/// the cursor in another, and every edit is reported upwards through
/// [onChanged].
class FluidCard extends StatefulWidget {
  const FluidCard({
    super.key,
    required this.fluid,
    required this.result,
    required this.index,
    required this.weightKg,
    required this.onChanged,
    required this.onRemove,
    required this.canRemove,
    this.autofocusRate = false,
  });

  final FluidInput fluid;

  /// Derived figures for this line, or null while the weight is missing.
  final FluidResult? result;

  /// Position in the list, used for the line's colour.
  final int index;

  /// Current weight, used to convert the rate when the unit is switched.
  final double weightKg;

  final ValueChanged<FluidInput> onChanged;
  final VoidCallback onRemove;
  final bool canRemove;

  /// Put the cursor in this line's rate or volume field as soon as it appears,
  /// so a just-added line can be typed into without another tap.
  final bool autofocusRate;

  @override
  State<FluidCard> createState() => _FluidCardState();
}

class _FluidCardState extends State<FluidCard> {
  late final TextEditingController _name = TextEditingController(
    text: widget.fluid.name,
  );
  late final TextEditingController _dextrose = TextEditingController(
    text: trimmed(widget.fluid.dextrosePercent, 2),
  );
  late final TextEditingController _rate = TextEditingController(
    text: trimmed(widget.fluid.rateValue, 2),
  );
  final FocusNode _rateFocus = FocusNode();

  /// Whether this line's figures are showing. Collapsed to begin with, so a
  /// list of lines stays short; the choice is per card and is not persisted.
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    if (widget.autofocusRate) {
      // After the first frame, so the field exists to receive focus. Selecting
      // the placeholder zero means the first keystroke replaces it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _rate.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _rate.text.length,
        );
        _rateFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _dextrose.dispose();
    _rate.dispose();
    _rateFocus.dispose();
    super.dispose();
  }

  /// Switches the rate unit, carrying the equivalent rate across so the line
  /// keeps delivering the same amount.
  void _changeUnit(RateUnit unit) {
    if (unit == widget.fluid.rateUnit) return;
    final double converted = widget.weightKg > 0
        ? convertRate(widget.fluid, unit, widget.weightKg)
        : widget.fluid.rateValue;
    final double rounded = double.parse(converted.toStringAsFixed(2));
    _rate.text = trimmed(rounded, 2);
    widget.onChanged(widget.fluid.copyWith(rateUnit: unit, rateValue: rounded));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = fluidColor(widget.index);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                if (widget.fluid.isFeed) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.local_drink_outlined,
                      size: 18,
                      color: accent,
                    ),
                  ),
                ],
                Expanded(
                  child: TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      // A hint, not a label: an unnamed line still says what to
                      // type, without a caption sitting over every title.
                      hintText: widget.fluid.isFeed ? 'Feed' : 'Fluid',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: theme.textTheme.titleMedium,
                    onChanged: (String value) =>
                        widget.onChanged(widget.fluid.copyWith(name: value)),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove this fluid',
                  onPressed: widget.canRemove ? widget.onRemove : null,
                  icon: const Icon(Icons.close),
                  // Trimmed from the default 48px target, which alone set the
                  // height of the title row.
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: _NumberField(
                      controller: _dextrose,
                      label: widget.fluid.isFeed ? 'Carb' : 'Dextrose',
                      suffix: '%',
                      onChanged: (double? value) => widget.onChanged(
                        widget.fluid.copyWith(dextrosePercent: value ?? 0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: _NumberField(
                      controller: _rate,
                      focusNode: _rateFocus,
                      label: widget.fluid.rateUnit == RateUnit.mlPerFeed
                          ? 'Volume'
                          : 'Rate',
                      // The unit sits in the field beside the number it
                      // qualifies, and switching it converts the rate.
                      unit: _UnitPicker(
                        unit: widget.fluid.rateUnit,
                        isFeed: widget.fluid.isFeed,
                        onChanged: _changeUnit,
                      ),
                      onChanged: (double? value) => widget.onChanged(
                        widget.fluid.copyWith(rateValue: value ?? 0),
                      ),
                    ),
                  ),
                  if (widget.fluid.rateUnit == RateUnit.mlPerFeed) ...<Widget>[
                    const SizedBox(width: 12),
                    _IntervalPicker(
                      hours: widget.fluid.feedIntervalHours,
                      onChanged: (double hours) => widget.onChanged(
                        widget.fluid.copyWith(feedIntervalHours: hours),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.fluid.isFeed) ...<Widget>[
              const SizedBox(height: 4),
              _CountInGirSwitch(
                value: widget.fluid.countsTowardGir,
                onChanged: (bool value) => widget.onChanged(
                  widget.fluid.copyWith(countsTowardGir: value),
                ),
              ),
            ],
            if (widget.result != null) ...<Widget>[
              const SizedBox(height: 8),
              _LineReadout(
                result: widget.result!,
                accent: accent,
                expanded: _showDetails,
                onToggle: () => setState(() => _showDetails = !_showDetails),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// How often a bolus feed is given. One tap opens the list, one more picks it.
class _IntervalPicker extends StatelessWidget {
  const _IntervalPicker({required this.hours, required this.onChanged});

  final double hours;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    // A stored interval that is not on the list still has to be selectable.
    final List<double> options = <double>{
      ...feedIntervals,
      if (hours > 0) hours,
    }.toList()..sort();

    return SizedBox(
      width: 96,
      child: DropdownButtonFormField<double>(
        initialValue: options.contains(hours) ? hours : null,
        isDense: true,
        // Let the value shrink to the box rather than overflow it.
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Every',
          contentPadding: _fieldPadding,
        ),
        items: <DropdownMenuItem<double>>[
          for (final double option in options)
            DropdownMenuItem<double>(
              value: option,
              child: Text(feedIntervalLabel(option)),
            ),
        ],
        onChanged: (double? value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

/// Opts a feed's carbohydrate into the GIR total. Off by default: GIR normally
/// means intravenous glucose, and a feed's contribution is an estimate.
class _CountInGirSwitch extends StatelessWidget {
  const _CountInGirSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: <Widget>[
            Switch(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Count towards GIR',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What this one line contributes, updated as you type.
///
/// Collapsed to its headline by default: the GIR stays in view, and the rest of
/// the working stays out of the way until it is asked for.
class _LineReadout extends StatelessWidget {
  const _LineReadout({
    required this.result,
    required this.accent,
    required this.expanded,
    required this.onToggle,
  });

  final FluidResult result;
  final Color accent;

  /// Whether the figures under the headline are showing.
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final RateUnit unit = result.fluid.rateUnit;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 5, 5, 5),
              child: Row(
                children: <Widget>[
                  Expanded(
                    // Wraps rather than overflows when the type is scaled up.
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          'GIR',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            letterSpacing: 0.6,
                          ),
                        ),
                        Text(
                          '${fixed(result.gir, 2)} mg/kg/min',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: result.countsTowardGir
                                ? null
                                : theme.colorScheme.onSurfaceVariant,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        if (!result.countsTowardGir)
                          Text(
                            '(not counted)',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Wrap(
                spacing: 16,
                runSpacing: 6,
                children: <Widget>[
                  // Show the equivalent in a unit that was not typed in.
                  if (unit == RateUnit.mlPerHour)
                    _Stat(
                      label: 'Daily',
                      value: '${trimmed(result.mlPerKgPerDay, 1)} mL/kg/day',
                    )
                  else
                    _Stat(
                      label: 'Rate',
                      value: '${trimmed(result.mlPerHour, 2)} mL/hr',
                    ),
                  if (unit == RateUnit.mlPerFeed)
                    _Stat(
                      label: 'Total fluid',
                      value: '${trimmed(result.mlPerKgPerDay, 1)} mL/kg/day',
                    ),
                  _Stat(
                    label: 'Glucose',
                    value: '${trimmed(result.glucoseGramsPerDay, 2)} g/day',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.6,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// A decimal field that reports parsed values, tolerating comma separators.
///
/// The unit goes in the field itself - as [suffix] text, or as [unit] when it
/// is something the reader can change.
class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.suffix,
    this.unit,
    this.focusNode,
  }) : assert(suffix == null || unit == null, 'one unit, not two');

  final TextEditingController controller;
  final String label;
  final ValueChanged<double?> onChanged;

  /// A fixed unit, written after the value.
  final String? suffix;

  /// A unit the reader can change, sitting where [suffix] would.
  final Widget? unit;

  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        suffixIcon: unit,
        // Without this the suffix would be padded out to a 48px icon slot,
        // leaving the number almost no room.
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        // Tighter than the dense default of (12, 16, 12, 8): four pixels off
        // every field, and the interval picker beside it matches.
        contentPadding: _fieldPadding,
      ),
      onChanged: (String value) => onChanged(parseNumber(value)),
    );
  }
}

/// The unit a rate is written in, sitting in the rate field beside the number.
///
/// Closed it is abbreviated so the number keeps the room; the menu spells each
/// unit out. Feeds can also be ordered as a volume per feed.
class _UnitPicker extends StatelessWidget {
  const _UnitPicker({
    required this.unit,
    required this.isFeed,
    required this.onChanged,
  });

  final RateUnit unit;
  final bool isFeed;
  final ValueChanged<RateUnit> onChanged;

  /// What the closed picker reads. A per-feed volume says only "mL": the
  /// interval picker beside it supplies the rest.
  static String _closed(RateUnit unit) => switch (unit) {
    RateUnit.mlPerHour => 'mL/hr',
    RateUnit.mlPerKgPerDay => 'mL/kg/d',
    RateUnit.mlPerFeed => 'mL',
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<RateUnit> options = <RateUnit>[
      if (isFeed) RateUnit.mlPerFeed,
      RateUnit.mlPerHour,
      RateUnit.mlPerKgPerDay,
    ];
    final TextStyle? style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    // A DropdownButton would reserve the width of its longest unit and crowd
    // the number out of a narrow field; this is only as wide as what it shows.
    return PopupMenuButton<RateUnit>(
      tooltip: 'Rate unit',
      initialValue: unit,
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      onSelected: onChanged,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<RateUnit>>[
        for (final RateUnit option in options)
          CheckedPopupMenuItem<RateUnit>(
            value: option,
            checked: option == unit,
            child: Text(option.label),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(left: 2, right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(_closed(unit), style: style),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
