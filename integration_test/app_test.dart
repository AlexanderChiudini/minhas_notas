import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:minhas_notas/app.dart';
import 'package:minhas_notas/core/database/app_database.dart';
import 'package:minhas_notas/repositories/note_repository.dart';
import 'package:minhas_notas/services/pdf_service.dart';
import 'package:printing/printing.dart';
import 'package:sqflite/sqflite.dart';

import '../test/fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android: cadastro, persistência, edição, seleção e renderização nativa de PDF',
    (tester) async {
      final base = await getDatabasesPath();
      final path = '$base/integration_notes.db';
      await deleteDatabase(path);
      var storage = AppDatabase(path: path);
      var repository = NoteRepository(storage);
      final artifacts = Directory('$base/test_artifacts')
        ..createSync(recursive: true);
      Finder field(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      Future<void> press(String text) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        if (find.text(text).evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            find.text(text),
            200,
            scrollable: find.byType(Scrollable).first,
          );
        }
        final target = find.text(text).last;
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        if (find.byType(AlertDialog).evaluate().isEmpty) {
          await tester.pumpAndSettle();
        }
      }

      try {
        await tester.pumpWidget(NotesApp(repository: repository));
        await tester.pumpAndSettle();
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await press('Notas');
        expect(find.text('Suas notas começam aqui'), findsOneWidget);
        await press('Nova nota');
        await tester.enterText(field('Referência do lote'), '001-ANDROID');
        await tester.enterText(field('Valor unitário da peça'), '1,30');
        await press('Próximo');
        expect(await repository.list(), isEmpty);
        await tester.enterText(field('Cor'), 'Pérola');
        await tester.enterText(field('Tamanho'), 'GG');
        await tester.enterText(field('Quantidade'), '12');
        await press('Próxima cor');
        await tester.enterText(field('Cor'), 'Azul');
        await tester.enterText(field('Tamanho'), 'P');
        await tester.enterText(field('Quantidade'), '8');
        await press('Salvar');
        expect(await repository.list(), hasLength(1));
        await press('Referência: 001-ANDROID');
        await press('Editar');
        await tester.enterText(field('Valor unitário da peça'), '1,40');
        await press('Próximo');
        await tester.enterText(field('Quantidade'), '13');
        await press('Salvar');
        expect(find.textContaining('29,40'), findsOneWidget);
        File('${artifacts.path}/detalhes.png')
            .writeAsBytesSync(await binding.takeScreenshot('detalhes'));
        await press('Gerar PDF');
        expect(find.byType(PdfPreview), findsOneWidget);
        expect(find.text('Compartilhar'), findsOneWidget);
        expect(find.text('Imprimir'), findsOneWidget);
        await tester.pumpAndSettle();
        File('${artifacts.path}/preview.png')
            .writeAsBytesSync(await binding.takeScreenshot('preview'));
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await storage.close();
        repository.dispose();
        storage = AppDatabase(path: path);
        repository = NoteRepository(storage);
        expect(
          (await repository.list()).single.colors.first.sizes.single.quantity,
          13,
        );
        final a = await repository.save(scenarioA());
        final b = await repository.save(scenarioB());
        final single = await PdfService().fromRepository(repository, [a]);
        File('${artifacts.path}/nota_15787.pdf').writeAsBytesSync(single.bytes);
        final images = await Printing.raster(single.bytes, dpi: 110).toList();
        expect(images, hasLength(1));
        expect(images.single.width, greaterThan(800));
        File('${artifacts.path}/nota_15787.png')
            .writeAsBytesSync(await images.single.toPng());
        final batch = await PdfService().fromRepository(repository, [b, a]);
        File('${artifacts.path}/notas_em_lote.pdf')
            .writeAsBytesSync(batch.bytes);
        expect(await Printing.raster(batch.bytes, dpi: 36).length, 2);

        await tester.pumpWidget(NotesApp(repository: repository));
        await tester.pumpAndSettle();
        await press('Notas');
        await press('Selecionar');
        await press('Selecionar todas');
        expect(find.text('3 selecionadas'), findsOneWidget);
        await press('Excluir selecionadas');
        await press('Excluir');
        expect(await repository.list(), isEmpty);
        final db = await storage.database;
        expect(await db.query('note_colors'), isEmpty);
        expect(await db.query('color_sizes'), isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        repository.dispose();
        await storage.close();
        await deleteDatabase(path);
      }
    },
  );
}
