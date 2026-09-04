import 'package:flutter/material.dart';

import '../logic/formatting.dart';
import '../logic/gir_calculator.dart';
import '../theme.dart';

/// The always-visible summary pinned to the bottom on narrow screens, so the
/// totals stay in view while fluids are being edited. Tapping opens the full
/// results panel.
class TotalsBar extends StatelessWidget {
  const TotalsBar({super.key, required this.summary, required this.onTap});

  final GirSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: InkWell(
        onTap: onTap,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: summary.isValid
                ? Row(
                    children: <Widget>[
                      Expanded(
                        flex: 4,
                        child: _Metric(
                          label: 'Total GIR',
                          value: fixed(summary.totalGir, 2),
                          unit: 'mg/kg/min',
                          color: colorForBand(summary.band, theme.brightness),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: _Metric(
                          label: 'Rate',
                          value: trimmed(summary.totalMlPerHour, 2),
                          unit: 'mL/hr',
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: _Metric(
                          label: 'Fluid',
                          value: trimmed(summary.totalMlPerKgPerDay, 1),
                          unit: 'mL/kg/day',
                        ),
                      ),
                      Icon(
                        Icons.expand_less,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  )
                : Row(
                    children: <Widget>[
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Enter a weight to see totals',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.unit,
    this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color? color;

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
            letterSpacing: 0.6,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        Text(
          unit,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
