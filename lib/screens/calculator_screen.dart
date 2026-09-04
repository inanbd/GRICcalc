import 'package:flutter/material.dart';

import '../logic/formatting.dart';
import '../logic/gir_calculator.dart';
import '../models/fluid_input.dart';
import '../widgets/fluid_card.dart';
import '../widgets/results_panel.dart';
import '../widgets/totals_bar.dart';
import '../widgets/weight_card.dart';

/// Width at which the results move into their own column beside the inputs.
const double _wideLayoutBreakpoint = 900;

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final TextEditingController _weightController = TextEditingController();

  double? _weightGrams;
  int _nextId = 0;
  late List<FluidInput> _fluids = <FluidInput>[_newFluid()];

  FluidInput _newFluid({String name = '', double dextrosePercent = 10}) {
    return FluidInput(
      id: 'fluid-${_nextId++}',
      name: name,
      dextrosePercent: dextrosePercent,
      rateUnit: RateUnit.mlPerHour,
      rateValue: 0,
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  void _addFluid() {
    setState(() => _fluids = <FluidInput>[..._fluids, _newFluid()]);
  }

  void _removeFluid(String id) {
    setState(() {
      _fluids = _fluids
          .where((FluidInput f) => f.id != id)
          .toList(growable: false);
    });
  }

  void _updateFluid(FluidInput updated) {
    setState(() {
      _fluids = <FluidInput>[
        for (final FluidInput f in _fluids)
          if (f.id == updated.id) updated else f,
      ];
    });
  }

  void _resetAll() {
    setState(() {
      _weightController.clear();
      _weightGrams = null;
      _fluids = <FluidInput>[_newFluid()];
    });
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
    final GirSummary summary = summarise(
      weightGrams: _weightGrams,
      fluids: _fluids,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth >= _wideLayoutBreakpoint;

        return Scaffold(
          appBar: AppBar(
            title: const Text('NICU GIR Calculator'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Start over',
                onPressed: _resetAll,
                icon: const Icon(Icons.restart_alt),
              ),
              IconButton(
                tooltip: 'How this is calculated',
                onPressed: () => _showFormulaDialog(context),
                icon: const Icon(Icons.help_outline),
              ),
            ],
          ),
          body: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(child: _inputs(summary)),
                    const VerticalDivider(width: 1),
                    SizedBox(width: 400, child: ResultsPanel(summary: summary)),
                  ],
                )
              : _inputs(summary),
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

  Widget _inputs(GirSummary summary) {
    // One result per fluid while the weight is usable, otherwise null so the
    // cards hide their readouts rather than showing meaningless zeros.
    final Map<String, FluidResult> resultsById = <String, FluidResult>{
      for (final FluidResult r in summary.fluids) r.fluid.id: r,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        WeightCard(
          controller: _weightController,
          weightGrams: _weightGrams,
          onChanged: (String value) {
            setState(() => _weightGrams = parseNumber(value));
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: <Widget>[
            Text('Fluids', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text(
              '${_fluids.length} ${_fluids.length == 1 ? 'line' : 'lines'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < _fluids.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FluidCard(
              key: ValueKey<String>(_fluids[i].id),
              fluid: _fluids[i],
              result: resultsById[_fluids[i].id],
              index: i,
              weightKg: summary.weightKg,
              canRemove: _fluids.length > 1,
              onChanged: _updateFluid,
              onRemove: () => _removeFluid(_fluids[i].id),
            ),
          ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: _addFluid,
          icon: const Icon(Icons.add),
          label: const Text('Add fluid'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
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
              formula: 'GIR = (rate mL/hr \u00d7 dextrose %) \u00f7 (6 \u00d7 weight kg)',
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
                  '(4 \u00d7 10) \u00f7 (6 \u00d7 1.25) = 5.33 mg/kg/min',
              note:
                  'The same line delivers 76.8 mL/kg/day and 9.6 g of dextrose '
                  'a day.',
            ),
            SizedBox(height: 16),
            _FormulaEntry(
              title: 'Daily fluid',
              formula: 'mL/kg/day = (rate mL/hr \u00d7 24) \u00f7 weight kg',
              note:
                  'A rate entered as mL/kg/day is converted the other way: '
                  'mL/hr = (mL/kg/day \u00d7 weight kg) \u00f7 24.',
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
