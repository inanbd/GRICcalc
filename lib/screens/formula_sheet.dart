import 'package:flutter/material.dart';

/// Shows every formula the app uses, including the feed ones, so a reader can
/// re-derive any figure it reports.
void showFormulaSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: <Widget>[
          Text(
            'How this is calculated',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          const _Entry(
            title: 'Glucose infusion rate',
            formula: 'GIR = (rate mL/hr × carbohydrate %) ÷ (6 × weight kg)',
            note:
                'A solution labelled "%" carries that many grams per '
                '100 mL. Converting grams to milligrams and hours to '
                'minutes is where the 6 comes from.',
          ),
          _Entry(
            title: 'Worked example - IV',
            formula:
                'D10W at 4 mL/hr, 1250 g baby\n'
                '(4 × 10) ÷ (6 × 1.25) = 5.33 mg/kg/min',
            note:
                'The same line delivers 76.8 mL/kg/day and 9.6 g of '
                'dextrose a day.',
          ),
          const _Divider(),
          const _Entry(
            title: 'Feeds - volume',
            formula:
                'feeds per day = 24 ÷ interval hours\n'
                'mL/day        = volume per feed × feeds per day\n'
                'mL/hr         = volume per feed ÷ interval hours',
            note:
                'A bolus feed is averaged across the day so it can be '
                'added to continuous infusions.',
          ),
          const _Entry(
            title: 'Worked example - feed',
            formula:
                '20 mL q3h, 1500 g baby, 7% carbohydrate\n'
                '24 ÷ 3 = 8 feeds/day\n'
                '20 × 8 = 160 mL/day = 6.67 mL/hr\n'
                '(6.67 × 7) ÷ (6 × 1.5) = 5.19 mg/kg/min',
            note:
                'That 160 mL always counts towards the day\'s fluid: '
                '160 ÷ 1.5 = 106.7 mL/kg/day.',
          ),
          const _Entry(
            title: 'Feeds - glucose',
            formula:
                'Total GIR = IV GIR + feeds switched on\n'
                'Enteral GIR is shown either way',
            note:
                'GIR conventionally means intravenous glucose, so a feed '
                'stays out of the total until you switch it on for that '
                'line. Enteral GIR is an estimate: carbohydrate content '
                'varies with fortification and batch, and what is absorbed '
                'is not what goes down the tube.',
          ),
          const _Divider(),
          const _Entry(
            title: 'Daily fluid',
            formula:
                'mL/kg/day = (rate mL/hr × 24) ÷ weight kg\n'
                'mL/hr     = (mL/kg/day × weight kg) ÷ 24',
            note:
                'Every route counts towards the day\'s fluid, feeds '
                'included.',
          ),
          const _Entry(
            title: 'Totals',
            formula:
                'Total rate      = sum of every line\'s mL/hr\n'
                'Carbohydrate    = sum of every line\'s g/day\n'
                'Mean IV dextrose = IV grams ÷ IV volume × 100',
            note:
                'Mean dextrose covers the infusions only. Its purpose is '
                'to be checked against what a peripheral line will take, '
                'and a feed would only dilute it.',
          ),
        ],
      ),
    ),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.only(bottom: 20), child: Divider());
}

class _Entry extends StatelessWidget {
  const _Entry({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                formula,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            note,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
