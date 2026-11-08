import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:minhas_notas/core/database/app_database.dart';
import 'package:minhas_notas/models/color_size.dart';
import 'package:minhas_notas/models/note.dart';
import 'package:minhas_notas/models/note_color.dart';
import 'package:minhas_notas/repositories/note_repository.dart';
import 'package:minhas_notas/services/note_validation_service.dart';
import 'package:minhas_notas/services/pdf_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fixtures.dart';

/// Reads generated PDF content streams (Helvetica/Latin-1), including escaped
/// literals. Checks the saved bytes, rather than an intermediate layout model.
List<String> pageText(Uint8List bytes) {
  final source = latin1.decode(bytes);
  final pages = <String>[];
  for (final match in RegExp(
    r'stream\r?\n(.*?)\r?\nendstream',
    dotAll: true,
  ).allMatches(source)) {
    List<int> data = latin1.encode(match[1]!);
    try {
      data = ZLibDecoder().convert(data);
    } catch (_) {
      /* Uncompressed stream. */
    }
    final stream = latin1.decode(data);
    if (!stream.contains('BT')) continue;
    final texts = RegExp(r'\(((?:\\.|[^\\)])*)\)', dotAll: true)
        .allMatches(stream)
        .map((m) {
          return m[1]!.replaceAllMapped(RegExp(r'\\([0-7]{1,3}|.)'), (escape) {
            final escaped = escape[1]!;
            final octal = int.tryParse(escaped, radix: 8);
            return octal == null ? escaped : String.fromCharCode(octal);
          });
        });
    pages.add(texts.join(' ').replaceAll('\u00a0', ' '));
  }
  return pages;
}

void main() {
  final service = PdfService();
  test('Cenário A: PDF A4 com duas cores, subtotais e totais reais', () async {
    final bytes = await service.generate([scenarioA()]);
    expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
    final text = pageText(bytes);
    expect(text, hasLength(1));
    for (final value in [
      '15787',
      '1,30',
      'Cinza',
      'Bege',
      '106',
      '81',
      '137,80',
      '105,30',
      '187',
      '243,10',
    ]) {
      expect(text.single, contains(value), reason: value);
    }
    final directory = Directory('build/test_artifacts')
      ..createSync(recursive: true);
    File('${directory.path}/nota_15787.pdf').writeAsBytesSync(bytes);
  });

  test('Cenário F: arquivo único, cada nota começa em página distinta e sem somar notas', () async {
    final bytes = await service.generate([scenarioA(), scenarioB()]);
    final text = pageText(bytes);
    expect(text, hasLength(2));
    expect(text[0], contains('15787'));
    expect(text[0], contains('243,10'));
    expect(text[0], isNot(contains('50353')));
    expect(text[0], isNot(contains('190,40')));
    expect(text[1], contains('50353'));
    expect(text[1], contains('190,40'));
    expect(text[1], isNot(contains('15787')));
    expect(text[1], isNot(contains('243,10')));
    File('build/test_artifacts/notas_em_lote.pdf').writeAsBytesSync(bytes);
  });

  test('Cenário C: tamanhos alfanuméricos no PDF', () async {
    final note = Note(
      reference: '001-ABC',
      unitPriceCents: 130,
      colors: [
        NoteColor(
          name: 'Pérola',
          sizes: [
            for (final label in ['P', 'M', 'G', 'GG'])
              ColorSize(label: label, quantity: 2),
          ],
        ),
      ],
    );
    final text = pageText(await service.generate([note])).join(' ');
    for (final label in ['P', 'M', 'G', 'GG', 'Pérola']) {
      expect(text, contains(label));
    }
    expect(text, contains('10,40'));
  });

  test(
    'Muitas cores, tamanhos, nomes longos e continuação não perdem dados',
    () async {
      final note = Note(
        reference: 'REFERÊNCIA LONGA ' * 12,
        unitPriceCents: 130,
        colors: [
          for (var c = 0; c < 5; c++)
            NoteColor(
              name: 'Cor $c',
              sizes: [
                for (var s = 0; s < (c == 0 ? 140 : 7); s++)
                  ColorSize(label: 'Tamanho $s', quantity: 1),
              ],
            ),
        ],
      );
      final bytes = await service.generate([note]);
      final pages = pageText(bytes);
      expect(pages.length, greaterThan(5));
      final all = pages.join(' ');
      for (var s = 0; s < 140; s++) {
        expect(all, contains('Tamanho $s'));
      }
      for (var c = 0; c < 5; c++) {
        expect(all, contains('Cor $c'));
      }
      expect(all, contains('168'));
      expect(all, contains('218,40'));
      File('build/test_artifacts/nota_multipagina.pdf').writeAsBytesSync(bytes);
    },
  );

  test('PDF usa snapshot atualizado do SQLite na ordem solicitada', () async {
    sqfliteFfiInit();
    final storage = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final repository = NoteRepository(storage);
    try {
      final a = await repository.save(scenarioA());
      final b = await repository.save(scenarioB());
      final original = await repository.get(a);
      await repository.save(
        Note(
          id: a,
          reference: 'ATUALIZADA',
          unitPriceCents: 200,
          colors: original.colors,
        ),
      );
      final document = await service.fromRepository(repository, [b, a]);
      final pages = pageText(document.bytes);
      expect(pages[0], contains('50353'));
      expect(pages[1], contains('ATUALIZADA'));
      expect(pages[1], contains('374,00'));
      expect(pages[1], isNot(contains('243,10')));
    } finally {
      repository.dispose();
      await storage.close();
    }
  });

  test('Nomes previsíveis e seguros; seleção vazia rejeitada', () async {
    expect(
      service.filename([simpleNote(reference: '001/A:B?*')]),
      'nota_001_A_B__.pdf',
    );
    expect(service.filename([scenarioA()]), 'nota_15787.pdf');
    expect(
      service.filename([
        scenarioA(),
        scenarioB(),
      ], now: DateTime(2026, 11, 8, 14, 30)),
      'minhas_notas_20261108_143000.pdf',
    );
    await expectLater(
      service.generate([]),
      throwsA(isA<NoteValidationException>()),
    );
  });
}
