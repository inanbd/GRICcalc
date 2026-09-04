import 'package:flutter/material.dart';

import '../logic/formatting.dart';
import '../logic/gir_calculator.dart';
import '../theme.dart';

/// The full set of totals: GIR, volumes, glucose load, and safety flags.
class ResultsPanel extends StatelessWidget {
  const ResultsPanel({
    super.key,
    required this.summary,
    this.scrollable = true,
  });

  final GirSummary summary;

  /// Whether the panel provides its own scrolling (side column, bottom sheet)
  /// or is embedded in a scroll view owned by the caller.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!summary.isValid)
          const _AwaitingWeight()
        else ...<Widget>[
          _TotalGir(summary: summary),
          const SizedBox(height: 16),
          if (summary.totalGir > 0 && summary.fluids.length > 1) ...<Widget>[
            _ContributionBar(summary: summary),
            const SizedBox(height: 16),
          ],
          _TotalsTable(summary: summary),
          const SizedBox(height: 16),
          _Flags(summary: summary),
        ],
        const SizedBox(height: 16),
        const _Disclaimer(),
      ],
    );

    if (!scrollable) return content;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: content,
    );
  }
}

class _AwaitingWeight extends StatelessWidget {
  const _AwaitingWeight();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.scale_outlined,
            size: 40,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            'Enter the baby\'s weight to see totals',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The headline figure, with where it sits against usual practice.
class _TotalGir extends StatelessWidget {
  const _TotalGir({required this.summary});

  final GirSummary summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final GirBand band = summary.band;
    final Color color = colorForBand(band, theme.brightness);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'TOTAL GIR',
              style: theme.textTheme.labelMedium?.copyWith(
                letterSpacing: 1.2,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(
                  fixed(summary.totalGir, 2),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'mg/kg/min',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    band.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              band.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A stacked bar showing which line is providing the glucose.
class _ContributionBar extends StatelessWidget {
  const _ContributionBar({required this.summary});

  final GirSummary summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<int> indices = <int>[
      for (int i = 0; i < summary.fluids.length; i++)
        if (summary.fluids[i].gir > 0) i,
    ];
    if (indices.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('GIR by fluid', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(
                  // Stretch, or an empty ColoredBox collapses to zero height.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final int i in indices)
                      Expanded(
                        // Guarantee at least a sliver for a tiny contribution.
                        flex: (summary.fluids[i].girShare * 1000).round().clamp(
                          1,
                          1000,
                        ),
                        child: ColoredBox(color: fluidColor(i)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final int i in indices)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: fluidColor(i),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        summary.fluids[i].fluid.name.trim().isEmpty
                            ? 'Fluid ${i + 1}'
                            : summary.fluids[i].fluid.name,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${fixed(summary.fluids[i].gir, 2)} '
                      '(${(summary.fluids[i].girShare * 100).round()}%)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TotalsTable extends StatelessWidget {
  const _TotalsTable({required this.summary});

  final GirSummary summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double? meanDextrose = summary.meanDextrosePercent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Fluids', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _TotalRow(
              label: 'Total rate',
              value: trimmed(summary.totalMlPerHour, 2),
              unit: 'mL/hr',
              emphasise: true,
            ),
            _TotalRow(
              label: 'Total fluid',
              value: trimmed(summary.totalMlPerKgPerDay, 1),
              unit: 'mL/kg/day',
              emphasise: true,
            ),
            _TotalRow(
              label: 'Total volume',
              value: trimmed(summary.totalMlPerHour * 24, 1),
              unit: 'mL/day',
            ),
            _TotalRow(
              label: 'Glucose delivered',
              value: trimmed(summary.totalGlucoseGramsPerDay, 2),
              unit: 'g/day',
            ),
            _TotalRow(
              label: 'Mean dextrose',
              value: meanDextrose == null ? '--' : trimmed(meanDextrose, 1),
              unit: '%',
            ),
            const Divider(height: 24),
            _TotalRow(
              label: 'Dosing weight',
              value: trimmed(summary.weightKg, 3),
              unit: 'kg',
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    required this.unit,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final String unit;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style:
                (emphasise
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.bodyLarge)
                    ?.copyWith(
                      fontWeight: emphasise ? FontWeight.w700 : FontWeight.w500,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 76,
            child: Text(
              unit,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Practice notes worth surfacing next to the numbers.
class _Flags extends StatelessWidget {
  const _Flags({required this.summary});

  final GirSummary summary;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final List<FluidResult> central = summary.linesAbovePeripheralLimit;
    final List<Widget> flags = <Widget>[
      if (central.isNotEmpty)
        _FlagTile(
          color: StatusColors.caution(brightness),
          icon: Icons.warning_amber_rounded,
          text:
              '${central.map((FluidResult r) => r.fluid.name.trim().isEmpty ? 'a fluid' : r.fluid.name).join(', ')} '
              'runs above ${trimmed(peripheralDextroseLimit, 1)}% dextrose, '
              'which usually needs central access.',
        ),
      if (summary.band == GirBand.high)
        _FlagTile(
          color: StatusColors.alert(brightness),
          icon: Icons.priority_high_rounded,
          text:
              'A sustained GIR at or above 12 mg/kg/min suggests reviewing for '
              'hyperinsulinism and confirming the concentration and access.',
        ),
    ];

    if (flags.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final Widget flag in flags)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: flag),
      ],
    );
  }
}

class _FlagTile extends StatelessWidget {
  const _FlagTile({
    required this.color,
    required this.icon,
    required this.text,
  });

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      'For use by clinicians as a calculation aid only. Check every figure '
      'against your unit\'s protocol and an independent calculation before '
      'acting on it.',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
