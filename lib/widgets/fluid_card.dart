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

  @override
  void dispose() {
    _name.dispose();
    _dextrose.dispose();
    _rate.dispose();
    super.dispose();
  }

  /// Switches the rate unit, carrying the equivalent rate across so the line
  /// keeps running at the same speed.
  void _changeUnit(RateUnit unit) {
    if (unit == widget.fluid.rateUnit) return;

    double converted = widget.fluid.rateValue;
    if (widget.weightKg > 0) {
      converted = switch (unit) {
        RateUnit.mlPerHour => toMlPerHour(
          widget.fluid.rateValue,
          widget.fluid.rateUnit,
          widget.weightKg,
        ),
        RateUnit.mlPerKgPerDay => toMlPerKgPerDay(
          widget.fluid.rateValue,
          widget.fluid.rateUnit,
          widget.weightKg,
        ),
      };
    }

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
                      label: 'Dextrose',
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
                      label: 'Rate',
                      suffix: widget.fluid.rateUnit.label,
                      onChanged: (double? value) => widget.onChanged(
                        widget.fluid.copyWith(rateValue: value ?? 0),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<RateUnit>(
                segments: const <ButtonSegment<RateUnit>>[
                  ButtonSegment<RateUnit>(
                    value: RateUnit.mlPerHour,
                    label: Text('mL/hr'),
                  ),
                  ButtonSegment<RateUnit>(
                    value: RateUnit.mlPerKgPerDay,
                    label: Text('mL/kg/day'),
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
            label: 'GIR',
            value: '${fixed(result.gir, 2)} mg/kg/min',
            emphasise: true,
          ),
          // Show the equivalent in the unit that was not typed in.
          if (unit == RateUnit.mlPerKgPerDay)
            _Stat(label: 'Rate', value: '${trimmed(result.mlPerHour, 2)} mL/hr')
          else
            _Stat(
              label: 'Daily',
              value: '${trimmed(result.mlPerKgPerDay, 1)} mL/kg/day',
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
  });

  final String label;
  final String value;
  final bool emphasise;

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
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      onChanged: (String value) => onChanged(parseNumber(value)),
    );
  }
}
