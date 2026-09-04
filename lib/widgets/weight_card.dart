import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/formatting.dart';

/// The baby's weight in grams - the figure every per-kilogram result hangs on.
class WeightCard extends StatelessWidget {
  const WeightCard({
    super.key,
    required this.controller,
    required this.weightGrams,
    required this.onChanged,
  });

  final TextEditingController controller;
  final double? weightGrams;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasWeight = weightGrams != null && weightGrams! > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.monitor_weight_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text('Baby\'s weight', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              onChanged: onChanged,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Weight',
                hintText: 'e.g. 1250',
                suffixText: 'g',
                helperText: hasWeight
                    ? '= ${trimmed(weightGrams! / 1000, 3)} kg'
                    : 'Enter the dosing weight in grams',
                errorText: controller.text.trim().isNotEmpty && !hasWeight
                    ? 'Enter a weight greater than 0'
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
