import 'package:flutter/material.dart';

import '../models/fluid_input.dart';

/// Adds a fluid line in one tap.
///
/// Tapping a preset creates the line already named and at the right dextrose
/// concentration, so only the rate is left to type. Picking a fluid used to
/// take three taps: add, then open the presets, then choose.
class QuickAddRow extends StatelessWidget {
  const QuickAddRow({
    super.key,
    required this.onAddPreset,
    required this.onAddCustom,
  });

  final void Function(FluidPreset preset) onAddPreset;

  /// Starts an empty line on the given route, for anything not on the lists.
  final void Function(FluidRoute route) onAddCustom;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Group(
          title: 'Add a fluid',
          presets: FluidPreset.infusions,
          onAddPreset: onAddPreset,
          trailing: _CustomChip(
            onPressed: () => onAddCustom(FluidRoute.intravenous),
          ),
        ),
        const SizedBox(height: 14),
        _Group(
          title: 'Add a feed',
          subtitle:
              'Counts towards the day\'s fluid. Carbohydrate is left out of '
              'the GIR unless you switch it on.',
          presets: FluidPreset.feeds,
          onAddPreset: onAddPreset,
          trailing: _CustomChip(
            onPressed: () => onAddCustom(FluidRoute.enteral),
          ),
        ),
      ],
    );
  }
}

/// Starts a line with nothing filled in, for a fluid or feed off the lists.
class _CustomChip extends StatelessWidget {
  const _CustomChip({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.edit_outlined, size: 18),
      label: const Text('Custom'),
      onPressed: onPressed,
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.presets,
    required this.onAddPreset,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final List<FluidPreset> presets;
  final void Function(FluidPreset preset) onAddPreset;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: <Widget>[
            for (final FluidPreset preset in presets)
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: Text(preset.name),
                onPressed: () => onAddPreset(preset),
              ),
            ?trailing,
          ],
        ),
      ],
    );
  }
}
