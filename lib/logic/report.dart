import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/fluid_input.dart';
import 'formatting.dart';
import 'gir_calculator.dart';

/// The three figures, in the shape asked for when pasting into a note.
String girSummaryText(GirSummary summary) {
  return 'IV GIR: ${fixed(summary.ivGir, 2)} mg/kg/min\n'
      'Enteral GIR: ${fixed(summary.enteralGir, 2)} mg/kg/min\n'
      'Total GIR: ${fixed(summary.totalGir, 2)} mg/kg/min';
}

/// How one line's figure was arrived at, written out so a reader can check it.
///
/// Deliberately shows the inputs and not just the answer: a number nobody can
/// re-derive is a number nobody should act on.
String lineWorking(FluidResult result) {
  final FluidInput fluid = result.fluid;
  final String name = fluid.name.trim().isEmpty ? 'Unnamed' : fluid.name.trim();
  final StringBuffer buffer = StringBuffer(name);

  buffer.write(': ');
  if (fluid.rateUnit == RateUnit.mlPerFeed) {
    buffer.write(
      '${trimmed(fluid.rateValue, 2)} mL '
      '${feedIntervalLabel(fluid.feedIntervalHours)} '
      '= ${trimmed(result.feedsPerDay ?? 0, 2)} feeds/day '
      '= ${trimmed(result.mlPerHour * 24, 1)} mL/day '
      '(${trimmed(result.mlPerHour, 2)} mL/hr)',
    );
  } else {
    buffer.write(
      '${trimmed(result.mlPerHour, 2)} mL/hr '
      '(${trimmed(result.mlPerKgPerDay, 1)} mL/kg/day)',
    );
  }

  buffer.write(', ${trimmed(fluid.dextrosePercent, 2)}% ');
  buffer.write(fluid.isFeed ? 'carbohydrate' : 'dextrose');
  buffer.write(' -> ${fixed(result.gir, 2)} mg/kg/min');
  if (!result.countsTowardGir) buffer.write(' (not counted)');
  return buffer.toString();
}

/// Renders the detailed working as a one-page PDF for printing or sharing.
Future<Uint8List> buildReportPdf({
  required GirSummary summary,
  required String patientName,
  DateTime? generatedAt,
}) async {
  final DateTime now = generatedAt ?? DateTime.now();
  final pw.Document doc = pw.Document();

  final List<FluidResult> ivLines = summary.fluids
      .where((FluidResult r) => !r.isFeed)
      .toList();
  final List<FluidResult> feedLines = summary.fluids
      .where((FluidResult r) => r.isFeed)
      .toList();

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            'Glucose Infusion Rate (GIR)',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated ${_formatDateTime(now)}  -  NICU GIR Calculator',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: <pw.Widget>[
              _statCard('IV GIR', fixed(summary.ivGir, 2)),
              pw.SizedBox(width: 10),
              _statCard('ENTERAL GIR', fixed(summary.enteralGir, 2)),
              pw.SizedBox(width: 10),
              _statCard(
                'TOTAL GIR',
                fixed(summary.totalGir, 2),
                highlight: true,
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            summary.countsFeedsInGir
                ? 'Total GIR includes feeds. Enteral GIR is an estimate only.'
                : 'Total GIR is intravenous only. Enteral GIR is shown for '
                      'reference and is an estimate only.',
            // Plain rather than italic: the built-in oblique face has no
            // Unicode coverage and warns on anything outside its encoding.
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 18),
          _field('Patient', patientName),
          _field(
            'Dosing weight',
            '${trimmed(summary.weightKg * 1000, 1)} g '
                '(${trimmed(summary.weightKg, 3)} kg)',
          ),
          pw.SizedBox(height: 12),
          if (ivLines.isNotEmpty) ...<pw.Widget>[
            _sectionTitle('IV lines'),
            for (final FluidResult line in ivLines) _workingLine(line),
            pw.SizedBox(height: 10),
          ],
          if (feedLines.isNotEmpty) ...<pw.Widget>[
            _sectionTitle('Feeds'),
            for (final FluidResult line in feedLines) _workingLine(line),
            pw.SizedBox(height: 10),
          ],
          _sectionTitle('Totals'),
          _field('Total rate', '${trimmed(summary.totalMlPerHour, 2)} mL/hr'),
          _field(
            'Total fluid',
            '${trimmed(summary.totalMlPerKgPerDay, 1)} mL/kg/day '
                '(${trimmed(summary.totalMlPerHour * 24, 1)} mL/day)',
          ),
          if (summary.hasFeeds) ...<pw.Widget>[
            _field(
              '  of which IV',
              '${trimmed(summary.ivMlPerKgPerDay, 1)} mL/kg/day',
            ),
            _field(
              '  of which feeds',
              '${trimmed(summary.enteralMlPerKgPerDay, 1)} mL/kg/day',
            ),
          ],
          _field(
            'Carbohydrate delivered',
            '${trimmed(summary.totalGlucoseGramsPerDay, 2)} g/day',
          ),
          if (summary.meanDextrosePercent != null)
            _field(
              'Mean IV dextrose',
              '${trimmed(summary.meanDextrosePercent!, 1)}%',
            ),
          pw.SizedBox(height: 14),
          _sectionTitle('Formula'),
          pw.Text(
            'GIR (mg/kg/min) = (rate mL/hr x carbohydrate %) / (6 x weight kg)',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'A feed is averaged over the day: volume per feed / interval hours.',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey400),
          pw.Text(
            'This report is a calculation aid only. It is not a prescription '
            'and not medical advice. Every figure must be checked against the '
            'order, the product label and your unit\'s protocol, and confirmed '
            'by an independent calculation. Responsibility for the decision '
            'rests with the treating clinician.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    ),
  );

  return doc.save();
}

pw.Widget _statCard(String label, String value, {bool highlight = false}) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: highlight ? PdfColors.teal700 : PdfColors.grey400,
        ),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: <pw.Widget>[
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: highlight ? PdfColors.teal700 : PdfColors.black,
            ),
          ),
          pw.Text(
            'mg/kg/min',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    ),
  );
}

pw.Widget _sectionTitle(String text) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 4),
  child: pw.Text(
    text,
    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
  ),
);

pw.Widget _field(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 3),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      pw.SizedBox(
        width: 130,
        child: pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
      ),
      pw.Expanded(
        child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
      ),
    ],
  ),
);

pw.Widget _workingLine(FluidResult line) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 3, left: 6),
  child: pw.Text(
    '- ${lineWorking(line)}',
    style: const pw.TextStyle(fontSize: 10),
  ),
);

String _formatDateTime(DateTime at) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${at.year}-${two(at.month)}-${two(at.day)} '
      '${two(at.hour)}:${two(at.minute)}';
}
