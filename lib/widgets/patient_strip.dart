import 'package:flutter/material.dart';

import '../logic/formatting.dart';
import '../models/patient.dart';

/// The row of babies across the top. Switching is one tap, and adding another
/// patient is one more - no menus, no separate screen.
class PatientStrip extends StatelessWidget {
  const PatientStrip({
    super.key,
    required this.patients,
    required this.selectedId,
    required this.onSelect,
    required this.onAdd,
  });

  final List<Patient> patients;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: patients.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          if (index == patients.length) {
            return Center(
              child: ActionChip(
                avatar: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Add patient'),
                onPressed: onAdd,
              ),
            );
          }

          final Patient patient = patients[index];
          final bool isSelected = patient.id == selectedId;
          final double? weight = patient.weightGrams;

          return Center(
            child: ChoiceChip(
              selected: isSelected,
              onSelected: (_) => onSelect(patient.id),
              showCheckmark: false,
              avatar: CircleAvatar(
                backgroundColor: isSelected
                    ? theme.colorScheme.onSecondaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                child: Text(
                  '${index + 1}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isSelected
                        ? theme.colorScheme.secondaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              label: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    patient.displayName(index + 1),
                    style: theme.textTheme.labelLarge,
                  ),
                  Text(
                    weight == null ? 'no weight' : '${trimmed(weight, 0)} g',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
