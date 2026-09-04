import 'package:flutter/material.dart';

import '../logic/gir_calculator.dart';
import '../logic/formatting.dart';

/// What this app is, what it is not, and the limits worth knowing before
/// acting on a number it produces.
class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Disclaimer & safety')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.warning_amber_rounded,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This app is a calculation aid. It is not a prescription, '
                      'not a medical device, and not medical advice. The final '
                      'decision rests with the treating physician and the '
                      'clinical team.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _Section(
            title: 'Check every figure',
            body:
                'Confirm each result against the order, the product label and '
                'your unit\'s protocol, and against an independent '
                'calculation, before anything is changed at the cot side. '
                'Treat a number here as a second opinion, never as the first.',
          ),
          const _Section(
            title: 'What goes in decides what comes out',
            body:
                'Everything is calculated from the weight, concentrations and '
                'rates you type in. A mistyped weight or a stale rate produces '
                'a confident, wrong answer. Check that the dosing weight is '
                'the one your unit is currently using, and that each line '
                'matches what is actually running.',
          ),
          _Section(
            title: 'Enteral GIR is an estimate',
            body:
                'Carbohydrate content varies with fortification, recipe and '
                'batch, and what a baby absorbs is not the same as what goes '
                'down the tube. The preset percentages are typical values, not '
                'product data. GIR conventionally means intravenous glucose, '
                'which is why feeds stay out of the total unless you switch '
                'them in.',
          ),
          _Section(
            title: 'Reference ranges are a guide',
            body:
                'The maintenance band of 4-8 mg/kg/min, and the flag at '
                '${trimmed(peripheralDextroseLimit, 1)}% dextrose for '
                'peripheral access, are common conventions rather than rules. '
                'Your unit\'s protocol and the baby in front of you take '
                'precedence over both.',
          ),
          const _Section(
            title: 'Your data stays on the device',
            body:
                'Patient records are stored on this device only. Nothing is '
                'uploaded, and there is no account and no analytics. That also '
                'means there is no backup: uninstalling the app, or clearing '
                'its data, removes the records. Avoid entering identifiers you '
                'would not want on an unlocked phone - a cot number or initials '
                'is usually enough.',
          ),
          const _Section(
            title: 'No warranty',
            body:
                'This software is provided as is, without warranty of any '
                'kind. The authors accept no liability for any loss or harm '
                'arising from its use.',
          ),
          const SizedBox(height: 8),
          Text(
            'If a result here disagrees with your own calculation, trust your '
            'own and report the discrepancy.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
        ],
      ),
    );
  }
}
