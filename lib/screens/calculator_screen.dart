import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../logic/formatting.dart';
import '../logic/gir_calculator.dart';
import '../logic/patient_store.dart';
import '../logic/report.dart';
import '../logic/settings_store.dart';
import '../models/fluid_input.dart';
import '../models/patient.dart';
import '../widgets/fluid_card.dart';
import '../widgets/patient_card.dart';
import '../widgets/patient_strip.dart';
import '../widgets/quick_add_row.dart';
import '../widgets/results_panel.dart';
import '../widgets/totals_bar.dart';
import 'disclaimer_screen.dart';
import 'formula_sheet.dart';

/// Width at which the results move into their own column beside the inputs.
const double _wideLayoutBreakpoint = 900;

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key, this.store, this.settings});

  /// Injected by tests; the app builds its own.
  final PatientStore? store;
  final SettingsStore? settings;

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

  /// The line whose rate or volume field should take the cursor. Set when a
  /// line is added and cleared once the field has it, so the keyboard opens on
  /// the new line and nowhere else.
  String? _focusFluidId;

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

  void _addFluid({
    String name = '',
    double dextrosePercent = 10,
    FluidRoute route = FluidRoute.intravenous,
  }) {
    _store.addFluid(name: name, dextrosePercent: dextrosePercent, route: route);
    final List<FluidInput> fluids = _store.selected?.fluids ?? <FluidInput>[];
    if (fluids.isNotEmpty) {
      setState(() => _focusFluidId = fluids.last.id);
    }
  }

  Future<void> _copyGirValues(GirSummary summary) async {
    if (!summary.isValid) {
      _notify('Enter a weight first.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: girSummaryText(summary)));
    _notify('GIR values copied.');
  }

  Future<void> _printReport(GirSummary summary, Patient patient) async {
    if (!summary.isValid) {
      _notify('Enter a weight first.');
      return;
    }
    final String label = patient.displayName(_store.selectedIndex + 1);
    await Printing.layoutPdf(
      name: 'GIR report - $label',
      onLayout: (_) => buildReportPdf(summary: summary, patientName: label),
    );
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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

  void _showResultsSheet(GirSummary summary, Patient patient) {
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
              child: ResultsPanel(
                summary: summary,
                scrollable: false,
                onCopy: () => _copyGirValues(summary),
                onPrint: () => _printReport(summary, patient),
              ),
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

    // The card has taken the cursor by now; drop the request so returning to
    // this patient later does not pop the keyboard open again.
    if (_focusFluidId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusFluidId = null);
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth >= _wideLayoutBreakpoint;

        return Scaffold(
          appBar: AppBar(
            title: const Text('NICU GIR Calculator'),
            actions: <Widget>[
              if (widget.settings case final SettingsStore settings)
                IconButton(
                  tooltip: 'Appearance: ${settings.themeMode.label}',
                  onPressed: () {
                    final ThemeMode next = settings.themeMode.next;
                    settings.setThemeMode(next);
                    _notify('Appearance: ${next.label}');
                  },
                  icon: Icon(settings.themeMode.icon),
                ),
              IconButton(
                tooltip: 'Copy GIR values',
                onPressed: () => _copyGirValues(summary),
                icon: const Icon(Icons.copy_outlined),
              ),
              IconButton(
                tooltip: 'Print report',
                onPressed: () => _printReport(summary, patient),
                icon: const Icon(Icons.print_outlined),
              ),
              _OverflowMenu(
                settings: widget.settings,
                onFormulas: () => showFormulaSheet(context),
                onDisclaimer: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DisclaimerScreen(),
                  ),
                ),
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
                    SizedBox(
                      width: 400,
                      child: ResultsPanel(
                        summary: summary,
                        onCopy: () => _copyGirValues(summary),
                        onPrint: () => _printReport(summary, patient),
                      ),
                    ),
                  ],
                )
              : _inputs(patient, position, summary),
          bottomNavigationBar: isWide
              ? null
              : TotalsBar(
                  summary: summary,
                  onTap: () => _showResultsSheet(summary, patient),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
        const SizedBox(height: 16),
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
            padding: const EdgeInsets.only(bottom: 8),
            child: FluidCard(
              key: ValueKey<String>(patient.fluids[i].id),
              fluid: patient.fluids[i],
              result: resultsById[patient.fluids[i].id],
              index: i,
              weightKg: summary.weightKg,
              canRemove: true,
              autofocusRate: patient.fluids[i].id == _focusFluidId,
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
          onAddPreset: (FluidPreset preset) => _addFluid(
            name: preset.name,
            dextrosePercent: preset.dextrosePercent,
            route: preset.route,
          ),
          onAddCustom: (FluidRoute route) => _addFluid(
            // A custom feed starts at breast milk's carbohydrate, the way a
            // custom drip starts at D10W's dextrose.
            dextrosePercent: route == FluidRoute.enteral ? 7 : 10,
            route: route,
          ),
        ),
      ],
    );
  }
}

/// The less-used actions, kept out of the way of the numbers.
class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({
    required this.settings,
    required this.onFormulas,
    required this.onDisclaimer,
  });

  final SettingsStore? settings;
  final VoidCallback onFormulas;
  final VoidCallback onDisclaimer;

  @override
  Widget build(BuildContext context) {
    final SettingsStore? store = settings;

    return PopupMenuButton<Object>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<Object>>[
        const PopupMenuItem<Object>(
          value: _MenuAction.formulas,
          child: ListTile(
            leading: Icon(Icons.help_outline),
            title: Text('How this is calculated'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem<Object>(
          value: _MenuAction.disclaimer,
          child: ListTile(
            leading: Icon(Icons.gavel_outlined),
            title: Text('Disclaimer & safety'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (store != null) ...<PopupMenuEntry<Object>>[
          const PopupMenuDivider(),
          const PopupMenuItem<Object>(
            enabled: false,
            child: Text('Appearance'),
          ),
          for (final ThemeMode mode in ThemeMode.values)
            CheckedPopupMenuItem<Object>(
              value: mode,
              checked: store.themeMode == mode,
              child: Row(
                children: <Widget>[
                  Icon(mode.icon, size: 20),
                  const SizedBox(width: 12),
                  Text(mode.label),
                ],
              ),
            ),
        ],
      ],
      onSelected: (Object value) {
        switch (value) {
          case _MenuAction.formulas:
            onFormulas();
          case _MenuAction.disclaimer:
            onDisclaimer();
          case final ThemeMode mode:
            store?.setThemeMode(mode);
        }
      },
    );
  }
}

enum _MenuAction { formulas, disclaimer }
