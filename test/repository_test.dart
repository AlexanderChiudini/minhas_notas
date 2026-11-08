import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:minhas_notas/core/database/app_database.dart';
import 'package:minhas_notas/models/color_size.dart';
import 'package:minhas_notas/models/note.dart';
import 'package:minhas_notas/models/note_color.dart';
import 'package:minhas_notas/repositories/note_repository.dart';
import 'package:minhas_notas/services/note_calculation_service.dart';
import 'package:minhas_notas/services/note_validation_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fixtures.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  late AppDatabase storage;
  late NoteRepository repository;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('minhas_notas_test_');
    path = '${directory.path}/notes.db';
    storage = AppDatabase(factory: databaseFactoryFfi, path: path);
    repository = NoteRepository(storage);
  });
  tearDown(() async {
    repository.dispose();
    await storage.close();
    await directory.delete(recursive: true);
  });

  test(
    'Instalação vazia, inserção completa, referência textual e relações',
    () async {
      expect(await repository.list(), isEmpty);
      final id = await repository.save(scenarioA());
      final note = await repository.get(id);
      expect(note.reference, '15787');
      expect(note.colors.map((c) => c.name), ['Cinza', 'Bege']);
      expect(note.colors.first.sizes.map((s) => s.label), [
        '1',
        '2',
        '3',
        '4',
        '6',
        '8',
        '10',
        '12',
      ]);
      expect(NoteCalculationService.noteValue(note), 24310);
      expect(note.createdAt, isNotNull);
      expect(note.updatedAt, isNotNull);
      expect(
        note.colors.every(
          (c) => c.id != null && c.sizes.every((s) => s.id != null),
        ),
        isTrue,
      );
      final second = await repository.save(simpleNote(reference: ' 001-A '));
      expect((await repository.get(second)).reference, '001-A');
      await repository.save(simpleNote(reference: '001-A'));
      expect(await repository.list(), hasLength(3));
      final db = await storage.database;
      expect(
        (await db.rawQuery('PRAGMA foreign_keys')).single.values.single,
        1,
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test(
    'Cenários C e D: edição de P/M/G/GG, recálculo, IDs e data de criação',
    () async {
      final id = await repository.save(
        Note(
          reference: '001',
          unitPriceCents: 130,
          colors: [
            NoteColor(
              name: 'Cinza',
              sizes: [
                for (final label in ['P', 'M', 'G', 'GG'])
                  ColorSize(label: label, quantity: 10),
              ],
            ),
          ],
        ),
      );
      final before = await repository.get(id);
      final color = before.colors.single;
      await repository.save(
        Note(
          id: id,
          reference: '001-X',
          unitPriceCents: 140,
          colors: [
            NoteColor(
              id: color.id,
              name: 'Pérola',
              sizes: [
                ColorSize(id: color.sizes[0].id, label: ' PP ', quantity: 20),
                ...color.sizes.skip(1),
                const ColorSize(label: 'XG', quantity: 5),
              ],
            ),
            NoteColor(
              name: 'Azul',
              sizes: [const ColorSize(label: '42', quantity: 2)],
            ),
          ],
        ),
      );
      final after = await repository.get(id);
      expect(after.createdAt, before.createdAt);
      expect(after.id, before.id);
      expect(after.colors.first.id, color.id);
      expect(after.colors.first.sizes.first.id, color.sizes.first.id);
      expect(after.colors.first.sizes.map((s) => s.label), [
        'PP',
        'M',
        'G',
        'GG',
        'XG',
      ]);
      expect(NoteCalculationService.colorPieces(after.colors.first), 55);
      expect(NoteCalculationService.colorValue(after.colors.first, 140), 7700);
      expect(NoteCalculationService.notePieces(after), 57);
      expect(NoteCalculationService.noteValue(after), 7980);
    },
  );

  test(
    'Remover cores/tamanhos e trocar nomes preserva IDs sem conflito UNIQUE',
    () async {
      final id = await repository.save(scenarioA());
      final note = await repository.get(id);
      await repository.save(
        Note(
          id: id,
          reference: note.reference,
          unitPriceCents: 130,
          colors: [
            NoteColor(
              id: note.colors[0].id,
              name: 'Bege',
              sizes: note.colors[0].sizes.take(1).toList(),
            ),
            NoteColor(
              id: note.colors[1].id,
              name: 'Cinza',
              sizes: note.colors[1].sizes,
            ),
          ],
        ),
      );
      var saved = await repository.get(id);
      expect(saved.colors.map((c) => c.name), ['Bege', 'Cinza']);
      await repository.save(
        Note(
          id: id,
          reference: saved.reference,
          unitPriceCents: 130,
          colors: [saved.colors[0]],
        ),
      );
      saved = await repository.get(id);
      expect(saved.colors, hasLength(1));
      final db = await storage.database;
      expect(await db.query('note_colors'), hasLength(1));
      expect(await db.query('color_sizes'), hasLength(1));
    },
  );

  test(
    'Cenário G: reabertura, ordem por criação e desempate pelo ID',
    () async {
      final first = await repository.save(simpleNote(reference: 'primeira'));
      final second = await repository.save(simpleNote(reference: 'segunda'));
      final db = await storage.database;
      await db.update('notes', {'created_at': '2026-11-08T12:00:00.000Z'});
      expect((await repository.list()).map((n) => n.id), [second, first]);
      final older = await repository.get(first);
      await repository.save(
        Note(
          id: first,
          reference: 'editada',
          unitPriceCents: 140,
          colors: older.colors,
        ),
      );
      expect((await repository.list()).map((n) => n.id), [second, first]);
      await storage.close();
      storage = AppDatabase(factory: databaseFactoryFfi, path: path);
      repository.dispose();
      repository = NoteRepository(storage);
      expect((await repository.list()).map((n) => n.reference), [
        'segunda',
        'editada',
      ]);
      expect(
        (await repository.get(first)).colors.single.sizes.single.label,
        'P',
      );
    },
  );

  test(
    'Cenário E: exclusão individual e em lote é física e em cascata',
    () async {
      final first = await repository.save(scenarioA());
      final second = await repository.save(scenarioB());
      final third = await repository.save(simpleNote());
      await repository.deleteMany([third]);
      await repository.deleteMany([first, second]);
      final db = await storage.database;
      for (final table in ['notes', 'note_colors', 'color_sizes']) {
        expect(await db.query(table), isEmpty, reason: table);
      }
      await expectLater(
        repository.get(first),
        throwsA(isA<NoteNotFoundException>()),
      );
    },
  );

  test(
    'Falha real de SQLite faz rollback da inserção e da edição inteiras',
    () async {
      final originalId = await repository.save(simpleNote());
      final original = await repository.get(originalId);
      final db = await storage.database;
      await db.execute(
        "CREATE TRIGGER force_failure BEFORE INSERT ON color_sizes WHEN NEW.size_label = 'FALHAR' BEGIN SELECT RAISE(ABORT, 'falha de teste'); END",
      );
      final failingColor = NoteColor(
        name: 'Teste',
        sizes: [const ColorSize(label: 'FALHAR', quantity: 1)],
      );
      await expectLater(
        repository.save(
          Note(reference: 'nova', unitPriceCents: 130, colors: [failingColor]),
        ),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        repository.save(
          Note(
            id: originalId,
            reference: 'alterada',
            unitPriceCents: 999,
            colors: [failingColor],
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect(await repository.list(), hasLength(1));
      final restored = await repository.get(originalId);
      expect(restored.reference, original.reference);
      expect(restored.unitPriceCents, original.unitPriceCents);
      expect(restored.colors.single.id, original.colors.single.id);
      expect(
        restored.colors.single.sizes.single.id,
        original.colors.single.sizes.single.id,
      );
    },
  );

  test('Lote com ID removido faz rollback de todas as exclusões', () async {
    final id = await repository.save(scenarioA());
    await expectLater(
      repository.deleteMany([id, 999999]),
      throwsA(isA<NoteNotFoundException>()),
    );
    expect((await repository.get(id)).colors, hasLength(2));
  });

  test(
    'Duplicidade e IDs de outra nota nunca alteram dados persistidos',
    () async {
      final id = await repository.save(scenarioA());
      final other = await repository.save(simpleNote());
      final foreign = await repository.get(other);
      await expectLater(
        repository.save(
          Note(
            id: id,
            reference: 'errada',
            unitPriceCents: 130,
            colors: foreign.colors,
          ),
        ),
        throwsA(isA<NoteValidationException>()),
      );
      expect((await repository.get(id)).reference, '15787');
      expect((await repository.get(id)).colors, hasLength(2));
      final note = await repository.get(id);
      await expectLater(
        repository.save(
          Note(
            id: id,
            reference: 'errada',
            unitPriceCents: 130,
            colors: [note.colors.first, note.colors.first],
          ),
        ),
        throwsA(isA<NoteValidationException>()),
      );
      expect((await repository.get(id)).colors, hasLength(2));
    },
  );
}
