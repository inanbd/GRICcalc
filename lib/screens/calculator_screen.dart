import 'package:flutter/material.dart';

import '../logic/formatting.dart';
import '../logic/gir_calculator.dart';
import '../logic/patient_store.dart';
import '../models/fluid_input.dart';
import '../models/patient.dart';
import '../widgets/fluid_card.dart';
import '../widgets/patient_card.dart';
import '../widgets/patient_strip.dart';
import '../widgets/quick_add_row.dart';
import '../widgets/results_panel.dart';
import '../widgets/totals_bar.dart';

/// Width at which the results move into their own column beside the inputs.
const double _wideLayoutBreakpoint = 900;

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key, this.store});

  /// Injected by tests; the app builds its own.
  final PatientStore? store;

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  late final PatientStore _store = widget.store ?? PatientStore();
  late final bool _ownsStore = widget.store == null;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  /// The record the text fields currently hold, so they are only rewritten
  /// when the patient actually changes and never while it is being typed into.
  String? _boundPatientId;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    if (!_store.isLoaded) {
      _store.load();
    } else {
      _bindControllers();
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _nameController.dispose();
    _weightController.dispose();
    if (_ownsStore) {
      // Persist whatever is still sitting in the debounce window.
      _store.flush();
      _store.dispose();
    }
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) return;
    setState(_bindControllers);
  }

  /// Loads the selected record into the text fields when the selection moves.
  void _bindControllers() {
    final Patient? patient = _store.selected;
    if (patient == null || patient.id == _boundPatientId) return;
    _boundPatientId = patient.id;
    _nameController.text = patient.name;
    _weightController.text = patient.weightGrams == null
        ? ''
        : trimmed(patient.weightGrams!, 1);
  }

  /// Rebinds even if the record is the same one, for edits made to the current
  /// patient from outside the fields (clearing it, for instance).
  void _rebindCurrent() {
    _boundPatientId = null;
    _bindControllers();
  }

  Future<void> _confirmDelete(Patient patient, int position) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text('Delete ${patient.displayName(position)}?'),
            content: const Text(
              'This removes the record and its fluids from this device.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;
    _store.removePatient(patient.id);
    _rebindCurrent();
  }

  void _showResultsSheet(GirSummary summary) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (BuildContext context, ScrollController controller) =>
            SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: ResultsPanel(summary: summary, scrollable: false),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_store.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final Patient patient = _store.selected!;
    final int position = _store.selectedIndex + 1;
    final GirSummary summary = summarise(
      weightGrams: patient.weightGrams,
      fluids: patient.fluids,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth >= _wideLayoutBreakpoint;

        return Scaffold(
          appBar: AppBar(
            title: const Text('NICU GIR Calculator'),
            actions: <Widget>[
              IconButton(
                tooltip: 'How this is calculated',
                onPressed: () => _showFormulaDialog(context),
                icon: const Icon(Icons.help_outline),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: PatientStrip(
                patients: _store.patients,
                selectedId: patient.id,
                onSelect: _store.select,
                onAdd: () {
                  _store.addPatient();
                  _rebindCurrent();
                },
              ),
            ),
          ),
          body: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(child: _inputs(patient, position, summary)),
                    const VerticalDivider(width: 1),
                    SizedBox(width: 400, child: ResultsPanel(summary: summary)),
                  ],
                )
              : _inputs(patient, position, summary),
          bottomNavigationBar: isWide
              ? null
              : TotalsBar(
                  summary: summary,
                  onTap: () => _showResultsSheet(summary),
                ),
        );
      },
    );
  }

  Widget _inputs(Patient patient, int position, GirSummary summary) {
    final Map<String, FluidResult> resultsById = <String, FluidResult>{
      for (final FluidResult r in summary.fluids) r.fluid.id: r,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        PatientCard(
          nameController: _nameController,
          weightController: _weightController,
          weightGrams: patient.weightGrams,
          patientLabel: 'Patient $position',
          onNameChanged: _store.setName,
          onWeightChanged: (String value) =>
              _store.setWeight(parseNumber(value)),
          onDuplicate: () {
            _store.duplicatePatient(patient.id);
            _rebindCurrent();
          },
          onClear: () {
            _store.resetSelected();
            _rebindCurrent();
          },
          onDelete: () => _confirmDelete(patient, position),
        ),
        const SizedBox(height: 24),
        Row(
          children: <Widget>[
            Text('Fluids', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text(
              '${patient.fluids.length} '
              '${patient.fluids.length == 1 ? 'line' : 'lines'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < patient.fluids.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FluidCard(
              key: ValueKey<String>(patient.fluids[i].id),
              fluid: patient.fluids[i],
              result: resultsById[patient.fluids[i].id],
              index: i,
              weightKg: summary.weightKg,
              canRemove: true,
              onChanged: _store.updateFluid,
              onRemove: () => _store.removeFluid(patient.fluids[i].id),
            ),
          ),
        if (patient.fluids.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No fluids yet - tap one below to add it.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 8),
        QuickAddRow(
          onAddPreset: (FluidPreset preset) => _store.addFluid(
            name: preset.name,
            dextrosePercent: preset.dextrosePercent,
          ),
          onAddCustom: () => _store.addFluid(),
        ),
      ],
    );
  }
}

void _showFormulaDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('How this is calculated'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const <Widget>[
            _FormulaEntry(
              title: 'Glucose infusion rate',
              formula: 'GIR = (rate mL/hr × dextrose %) ÷ (6 × weight kg)',
              note:
                  'A dextrose solution labelled "%" carries that many grams per '
                  '100 mL. Converting grams to milligrams and hours to minutes '
                  'is where the 6 comes from.',
            ),
            SizedBox(height: 16),
            _FormulaEntry(
              title: 'Worked example',
              formula:
                  'D10W at 4 mL/hr, 1250 g baby\n'
                  '(4 × 10) ÷ (6 × 1.25) = 5.33 mg/kg/min',
              note:
                  'The same line delivers 76.8 mL/kg/day and 9.6 g of dextrose '
                  'a day.',
            ),
            SizedBox(height: 16),
            _FormulaEntry(
              title: 'Daily fluid',
              formula: 'mL/kg/day = (rate mL/hr × 24) ÷ weight kg',
              note:
                  'A rate entered as mL/kg/day is converted the other way: '
                  'mL/hr = (mL/kg/day × weight kg) ÷ 24.',
            ),
            SizedBox(height: 16),
            _FormulaEntry(
              title: 'Totals',
              formula:
                  'Total GIR = sum of every line\'s GIR\n'
                  'Total rate = sum of every line\'s mL/hr',
              note:
                  'Mean dextrose is the volume-weighted concentration of '
                  'everything running.',
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _FormulaEntry extends StatelessWidget {
  const _FormulaEntry({
    required this.title,
    required this.formula,
    required this.note,
  });

  final String title;
  final String formula;
  final String note;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              formula,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          note,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
