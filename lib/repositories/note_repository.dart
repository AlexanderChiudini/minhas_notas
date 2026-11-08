import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database/app_database.dart';
import '../models/color_size.dart';
import '../models/note.dart';
import '../models/note_color.dart';
import '../services/note_validation_service.dart';

class NoteNotFoundException implements Exception {
  const NoteNotFoundException();
  @override
  String toString() => 'Esta nota já foi removida. Atualize a listagem.';
}

class NoteRepository extends ChangeNotifier {
  NoteRepository(this.database);
  final AppDatabase database;

  Future<List<Note>> list() async {
    final db = await database.database;
    return db.transaction((tx) async {
      final rows = await tx.query('notes', orderBy: 'created_at DESC, id DESC');
      return [for (final row in rows) await _read(tx, row)];
    });
  }

  Future<Note> get(int id) async {
    final db = await database.database;
    return db.transaction((tx) => _get(tx, id));
  }

  Future<Note> _get(DatabaseExecutor tx, int id) async {
    final rows = await tx.query('notes', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw const NoteNotFoundException();
    return _read(tx, rows.single);
  }

  Future<Note> _read(DatabaseExecutor tx, Map<String, Object?> row) async {
    final colorRows = await tx.query(
      'note_colors',
      where: 'note_id = ?',
      whereArgs: [row['id']],
      orderBy: 'sort_order, id',
    );
    final colors = <NoteColor>[];
    for (final color in colorRows) {
      final sizeRows = await tx.query(
        'color_sizes',
        where: 'color_id = ?',
        whereArgs: [color['id']],
        orderBy: 'sort_order, id',
      );
      colors.add(
        NoteColor(
          id: color['id'] as int,
          name: color['name'] as String,
          sizes: sizeRows
              .map(
                (size) => ColorSize(
                  id: size['id'] as int,
                  label: size['size_label'] as String,
                  quantity: size['quantity'] as int,
                ),
              )
              .toList(),
        ),
      );
    }
    return Note(
      id: row['id'] as int,
      reference: row['reference'] as String,
      unitPriceCents: row['unit_price_cents'] as int,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
      colors: colors,
    );
  }

  /// Reads one consistent snapshot, keeping the exact list order for batch PDFs.
  Future<List<Note>> getMany(List<int> ids) async {
    final db = await database.database;
    return db.transaction(
      (tx) async => [for (final id in ids) await _get(tx, id)],
    );
  }

  Future<int> save(Note note) async {
    NoteValidationService.validate(note);
    final db = await database.database;
    final id = await db.transaction((tx) async {
      final now = DateTime.now().toUtc().toIso8601String();
      final values = <String, Object?>{
        'reference': note.reference.trim(),
        'unit_price_cents': note.unitPriceCents,
        'updated_at': now,
      };
      final int noteId;
      if (note.id == null) {
        noteId = await tx.insert('notes', {...values, 'created_at': now});
      } else {
        noteId = note.id!;
        final changed = await tx.update(
          'notes',
          values,
          where: 'id = ?',
          whereArgs: [noteId],
        );
        if (changed == 0) throw const NoteNotFoundException();
      }
      // Transactional reinsertion preserves surviving IDs and permits name swaps.
      final oldColors = await tx.query(
        'note_colors',
        where: 'note_id = ?',
        whereArgs: [noteId],
      );
      final ownedColorIds = oldColors.map((row) => row['id'] as int).toSet();
      final ownedSizeIds = <int, Set<int>>{};
      for (final colorId in ownedColorIds) {
        final sizes = await tx.query(
          'color_sizes',
          columns: ['id'],
          where: 'color_id = ?',
          whereArgs: [colorId],
        );
        ownedSizeIds[colorId] = sizes.map((row) => row['id'] as int).toSet();
      }
      await tx.delete('note_colors', where: 'note_id = ?', whereArgs: [noteId]);
      final usedColors = <int>{};
      final usedSizes = <int>{};
      for (var c = 0; c < note.colors.length; c++) {
        final color = note.colors[c];
        if (color.id != null &&
            (!ownedColorIds.contains(color.id) || !usedColors.add(color.id!))) {
          throw const NoteValidationException(
            'Identificador de cor inválido. Reabra a nota.',
          );
        }
        final colorId = await tx.insert('note_colors', {
          if (color.id != null) 'id': color.id,
          'note_id': noteId,
          'name': NoteValidationService.cleanLabel(color.name),
          'sort_order': c,
        });
        for (var s = 0; s < color.sizes.length; s++) {
          final size = color.sizes[s];
          if (size.id != null &&
              (!(ownedSizeIds[color.id]?.contains(size.id) ?? false) ||
                  !usedSizes.add(size.id!))) {
            throw const NoteValidationException(
              'Identificador de tamanho inválido. Reabra a nota.',
            );
          }
          await tx.insert('color_sizes', {
            if (size.id != null) 'id': size.id,
            'color_id': colorId,
            'size_label': NoteValidationService.cleanLabel(size.label),
            'quantity': size.quantity,
            'sort_order': s,
          });
        }
      }
      return noteId;
    });
    notifyListeners();
    return id;
  }

  Future<void> deleteMany(Iterable<int> ids) async {
    final uniqueIds = ids.toSet();
    if (uniqueIds.isEmpty) return;
    final db = await database.database;
    await db.transaction((tx) async {
      for (final id in uniqueIds) {
        final count = await tx.delete(
          'notes',
          where: 'id = ?',
          whereArgs: [id],
        );
        if (count == 0) throw const NoteNotFoundException();
      }
    });
    notifyListeners();
  }
}
