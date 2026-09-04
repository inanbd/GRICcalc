import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/formatting.dart';
import '../logic/gir_calculator.dart';
import '../models/fluid_input.dart';
import '../theme.dart';

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
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
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
                    decoration: const InputDecoration(
                      labelText: 'Fluid',
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
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
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
                    child: _NumberField(
                      controller: _rate,
                      focusNode: _rateFocus,
                      label: widget.fluid.rateUnit == RateUnit.mlPerFeed
                          ? 'Volume'
                          : 'Rate',
                      suffix: widget.fluid.rateUnit == RateUnit.mlPerFeed
                          ? 'mL'
                          : widget.fluid.rateUnit.label,
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
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: SegmentedButton<RateUnit>(
                    segments: <ButtonSegment<RateUnit>>[
                      if (widget.fluid.isFeed)
                        const ButtonSegment<RateUnit>(
                          value: RateUnit.mlPerFeed,
                          label: Text('Per feed'),
                        ),
                      const ButtonSegment<RateUnit>(
                        value: RateUnit.mlPerHour,
                        label: Text('mL/hr'),
                      ),
                      const ButtonSegment<RateUnit>(
                        value: RateUnit.mlPerKgPerDay,
                        label: Text('mL/kg/d'),
                      ),
                    ],
                    selected: <RateUnit>{widget.fluid.rateUnit},
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onSelectionChanged: (Set<RateUnit> selection) =>
                        _changeUnit(selection.first),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            if (widget.fluid.isFeed) ...<Widget>[
              const SizedBox(height: 8),
              _CountInGirSwitch(
                value: widget.fluid.countsTowardGir,
                onChanged: (bool value) => widget.onChanged(
                  widget.fluid.copyWith(countsTowardGir: value),
                ),
              ),
            ],
            if (widget.result != null) ...<Widget>[
              const SizedBox(height: 12),
              _LineReadout(result: widget.result!, accent: accent),
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
      width: 132,
      child: DropdownButtonFormField<double>(
        initialValue: options.contains(hours) ? hours : null,
        isDense: true,
        // Let the value shrink to the box rather than overflow it.
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Every'),
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
        padding: const EdgeInsets.symmetric(vertical: 4),
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
class _LineReadout extends StatelessWidget {
  const _LineReadout({required this.result, required this.accent});

  final FluidResult result;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final RateUnit unit = result.fluid.rateUnit;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        children: <Widget>[
          _Stat(
            label: result.countsTowardGir ? 'GIR' : 'GIR (not counted)',
            value: '${fixed(result.gir, 2)} mg/kg/min',
            emphasise: true,
            muted: !result.countsTowardGir,
          ),
          if (result.feedsPerDay != null)
            _Stat(
              label: 'Feeds',
              value: '${trimmed(result.feedsPerDay!, 1)}/day',
            ),
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
              label: 'Volume',
              value: '${trimmed(result.mlPerHour * 24, 1)} mL/day',
            ),
          _Stat(
            label: 'Glucose',
            value: '${trimmed(result.glucoseGramsPerDay, 2)} g/day',
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.emphasise = false,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool emphasise;

  /// Dims a figure that is displayed but excluded from the totals.
  final bool muted;

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
            fontWeight: emphasise ? FontWeight.w700 : FontWeight.w500,
            color: muted ? theme.colorScheme.onSurfaceVariant : null,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// A decimal field that reports parsed values, tolerating comma separators.
class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.onChanged,
    this.focusNode,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final ValueChanged<double?> onChanged;
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
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      onChanged: (String value) => onChanged(parseNumber(value)),
    );
  }
}
