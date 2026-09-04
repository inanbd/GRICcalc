import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/formatting.dart';

/// Who this is and what they weigh, in one card.
///
/// Both fields save as they are typed, so there is nothing to confirm. The
/// overflow menu carries the rarer actions - duplicate, clear, delete - to keep
/// the common path down to typing.
class PatientCard extends StatelessWidget {
  const PatientCard({
    super.key,
    required this.nameController,
    required this.weightController,
    required this.weightGrams,
    required this.patientLabel,
    required this.onNameChanged,
    required this.onWeightChanged,
    required this.onDuplicate,
    required this.onClear,
    required this.onDelete,
  });

  final TextEditingController nameController;
  final TextEditingController weightController;
  final double? weightGrams;

  /// Fallback shown in the name field's hint, e.g. "Patient 2".
  final String patientLabel;

  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onWeightChanged;
  final VoidCallback onDuplicate;
  final VoidCallback onClear;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasWeight = weightGrams != null && weightGrams! > 0;
    final bool weightLooksWrong =
        weightController.text.trim().isNotEmpty && !hasWeight;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: nameController,
                    onChanged: onNameChanged,
                    textCapitalization: TextCapitalization.words,
                    style: theme.textTheme.titleMedium,
                    decoration: InputDecoration(
                      hintText: patientLabel,
                      border: InputBorder.none,
                      isDense: true,
                      prefixIcon: Icon(
                        Icons.child_care,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 32),
                    ),
                  ),
                ),
                PopupMenuButton<_PatientAction>(
                  tooltip: 'Patient actions',
                  onSelected: (_PatientAction action) => switch (action) {
                    _PatientAction.duplicate => onDuplicate(),
                    _PatientAction.clear => onClear(),
                    _PatientAction.delete => onDelete(),
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<_PatientAction>>[
                        const PopupMenuItem<_PatientAction>(
                          value: _PatientAction.duplicate,
                          child: ListTile(
                            leading: Icon(Icons.copy_all_outlined),
                            title: Text('Duplicate patient'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem<_PatientAction>(
                          value: _PatientAction.clear,
                          child: ListTile(
                            leading: Icon(Icons.restart_alt),
                            title: Text('Clear this patient'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem<_PatientAction>(
                          value: _PatientAction.delete,
                          child: ListTile(
                            leading: Icon(Icons.delete_outline),
                            title: Text('Delete patient'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextField(
                controller: weightController,
                onChanged: onWeightChanged,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Weight',
                  hintText: 'e.g. 1250',
                  suffixText: 'g',
                  helperText: hasWeight
                      ? '= ${trimmed(weightGrams! / 1000, 3)} kg'
                      : 'Dosing weight in grams',
                  errorText: weightLooksWrong
                      ? 'Enter a weight greater than 0'
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PatientAction { duplicate, clear, delete }
