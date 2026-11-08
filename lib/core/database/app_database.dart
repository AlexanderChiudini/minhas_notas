import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase({DatabaseFactory? factory, this.path})
    : _factory = factory ?? databaseFactory;

  final DatabaseFactory _factory;
  final String? path;
  Future<Database>? _opening;

  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    try {
      final location =
          path ?? p.join(await _factory.getDatabasesPath(), 'minhas_notas.db');
      return await _factory.openDatabase(
        location,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE notes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                reference TEXT NOT NULL CHECK(length(trim(reference)) > 0),
                unit_price_cents INTEGER NOT NULL CHECK(unit_price_cents > 0),
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE note_colors (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                note_id INTEGER NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
                name TEXT NOT NULL CHECK(length(trim(name)) > 0),
                sort_order INTEGER NOT NULL,
                UNIQUE(note_id, name COLLATE NOCASE)
              )
            ''');
            await db.execute('''
              CREATE TABLE color_sizes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                color_id INTEGER NOT NULL REFERENCES note_colors(id) ON DELETE CASCADE,
                size_label TEXT NOT NULL CHECK(length(trim(size_label)) > 0),
                quantity INTEGER NOT NULL CHECK(quantity > 0 AND typeof(quantity) = 'integer'),
                sort_order INTEGER NOT NULL,
                UNIQUE(color_id, size_label COLLATE NOCASE)
              )
            ''');
            await db.execute(
              'CREATE INDEX notes_created ON notes(created_at DESC, id DESC)',
            );
            await db.execute(
              'CREATE INDEX colors_note ON note_colors(note_id, sort_order)',
            );
            await db.execute(
              'CREATE INDEX sizes_color ON color_sizes(color_id, sort_order)',
            );
          },
        ),
      );
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<void> close() async {
    final opening = _opening;
    _opening = null;
    if (opening != null) await (await opening).close();
  }
}
