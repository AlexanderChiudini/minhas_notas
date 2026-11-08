import 'dart:math' as math;
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/utils/currency_utils.dart';
import '../models/note.dart';
import '../models/note_color.dart';
import '../repositories/note_repository.dart';
import 'note_calculation_service.dart';
import 'note_validation_service.dart';

class GeneratedPdf {
  const GeneratedPdf({required this.bytes, required this.filename});
  final Uint8List bytes;
  final String filename;
}

class PdfService {
  static const rowsPerBlock = 20;
  static const _navy = PdfColor.fromInt(0xFF19364E);
  static const _pale = PdfColor.fromInt(0xFFEEF2F6);

  /// Reloads persisted records, never using stale list cards or draft data.
  Future<GeneratedPdf> fromRepository(
    NoteRepository repository,
    List<int> ids,
  ) async {
    final notes = await repository.getMany(ids);
    return GeneratedPdf(
      bytes: await generate(notes),
      filename: filename(notes),
    );
  }

  String filename(List<Note> notes, {DateTime? now}) {
    if (notes.length == 1) {
      var reference = notes.single.reference
          .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
          .trim();
      reference = reference.replaceAll(RegExp(r'[. ]+$'), '');
      if (reference.length > 80) reference = reference.substring(0, 80);
      return 'nota_${reference.isEmpty ? 'sem_referencia' : reference}.pdf';
    }
    return 'minhas_notas_${DateFormat('yyyyMMdd_HHmmss').format(now ?? DateTime.now())}.pdf';
  }

  Future<Uint8List> generate(List<Note> notes) async {
    if (notes.isEmpty) {
      throw const NoteValidationException(
        'Selecione pelo menos uma nota para gerar o PDF.',
      );
    }
    final doc = pw.Document(title: 'minhas notas', author: 'minhas notas');
    for (final note in notes) {
      NoteValidationService.validate(note);
      final blocks = <pw.Widget>[];
      for (var c = 0; c < note.colors.length; c += 2) {
        final left = note.colors[c];
        final right = c + 1 < note.colors.length ? note.colors[c + 1] : null;
        final count = math.max(left.sizes.length, right?.sizes.length ?? 0);
        for (var offset = 0; offset < count; offset += rowsPerBlock) {
          final end = math.min(offset + rowsPerBlock, count);
          final last = c + 2 >= note.colors.length && end == count;
          blocks.add(
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _pair(note, left, right, offset, end),
                if (last) ...[pw.SizedBox(height: 18), _summary(note)],
                pw.SizedBox(height: 18),
              ],
            ),
          );
        }
      }
      // Each MultiPage starts a separate section/page for its note. A bounded
      // block keeps rows and their subtotals together; the number of blocks is unlimited.
      doc.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            theme: pw.ThemeData.withFont(
              base: pw.Font.helvetica(),
              bold: pw.Font.helveticaBold(),
            ),
            buildBackground: (_) => pw.FullPage(
              ignoreMargins: true,
              child: pw.Container(color: PdfColors.white),
            ),
          ),
          maxPages: blocks.length + 2,
          header: (_) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  'minhas notas',
                  style: const pw.TextStyle(color: _navy, fontSize: 11),
                ),
                pw.SizedBox(height: 10),
                pw.SizedBox(
                  height: 26,
                  child: pw.FittedBox(
                    alignment: pw.Alignment.centerLeft,
                    fit: pw.BoxFit.scaleDown,
                    child: pw.Text(
                      'Referência: ${note.reference}',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: _navy,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Valor por peça: ${CurrencyUtils.format(note.unitPriceCents)}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Divider(color: _navy),
              ],
            ),
          ),
          footer: (context) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'minhas notas',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.Text(
                  'Página ${context.pageNumber}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),
          build: (_) => blocks,
        ),
      );
    }
    return doc.save();
  }

  pw.Widget _cell(String text, {bool bold = false, PdfColor? color}) =>
      pw.Container(
        height: 23,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        alignment: pw.Alignment.centerLeft,
        child: text.isEmpty
            ? pw.SizedBox()
            : pw.FittedBox(
                fit: pw.BoxFit.scaleDown,
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  text,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: bold
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                    color: color,
                  ),
                ),
              ),
      );

  pw.Widget _pair(
    Note note,
    NoteColor left,
    NoteColor? right,
    int offset,
    int end,
  ) {
    List<pw.Widget> cells(NoteColor? color, int index) {
      if (color == null || index >= color.sizes.length) {
        return [_cell(''), _cell(''), _cell('')];
      }
      final size = color.sizes[index];
      return [
        _cell(index == offset ? color.name : '', bold: true),
        _cell(size.label),
        _cell('${size.quantity}'),
      ];
    }

    List<pw.Widget> total(NoteColor? color) {
      if (color == null ||
          offset >= color.sizes.length ||
          end < color.sizes.length) {
        return [_cell(''), _cell(''), _cell('')];
      }
      return [
        _cell('Total', bold: true),
        _cell(''),
        _cell('${NoteCalculationService.colorPieces(color)}', bold: true),
      ];
    }

    pw.Widget subtotal(NoteColor? color) {
      if (color == null ||
          offset >= color.sizes.length ||
          end < color.sizes.length) {
        return pw.SizedBox();
      }
      return pw.SizedBox(
        height: 22,
        child: pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            '${color.name}: ${CurrencyUtils.format(NoteCalculationService.colorValue(color, note.unitPriceCents))}',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (offset > 0)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Text(
              'Continuação dos tamanhos',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ),
        pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.SizedBox(
            width: right == null ? (PdfPageFormat.a4.width - 64) / 2 : null,
            child: pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.4),
                1: const pw.FlexColumnWidth(),
                2: const pw.FlexColumnWidth(),
                if (right != null) ...{
                  3: const pw.FlexColumnWidth(1.4),
                  4: const pw.FlexColumnWidth(),
                  5: const pw.FlexColumnWidth(),
                },
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _pale),
                  children: [
                    for (
                      var side = 0;
                      side < (right == null ? 1 : 2);
                      side++
                    ) ...[
                      _cell('Cor', bold: true),
                      _cell('Tamanho', bold: true),
                      _cell('Peças', bold: true),
                    ],
                  ],
                ),
                for (var row = offset; row < end; row++)
                  pw.TableRow(
                    children: [
                      ...cells(left, row),
                      if (right != null) ...cells(right, row),
                    ],
                  ),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _pale),
                  children: [
                    ...total(left),
                    if (right != null) ...total(right),
                  ],
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Expanded(child: subtotal(left)),
            pw.SizedBox(width: 12),
            pw.Expanded(child: subtotal(right)),
          ],
        ),
      ],
    );
  }

  pw.Widget _summary(Note note) => pw.Container(
    padding: const pw.EdgeInsets.all(14),
    decoration: const pw.BoxDecoration(color: _pale),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Total de peças: ${NoteCalculationService.notePieces(note)}',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Valor total da nota: ${CurrencyUtils.format(NoteCalculationService.noteValue(note))}',
          style: pw.TextStyle(
            fontSize: 15,
            fontWeight: pw.FontWeight.bold,
            color: _navy,
          ),
        ),
      ],
    ),
  );
}
