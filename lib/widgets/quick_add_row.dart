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
  final VoidCallback onAddCustom;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Add a fluid',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final FluidPreset preset in FluidPreset.all)
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: Text(preset.name),
                onPressed: () => onAddPreset(preset),
              ),
            ActionChip(
              avatar: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Custom'),
              onPressed: onAddCustom,
            ),
          ],
        ),
      ],
    );
  }
}
