import 'package:flutter/material.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'repositories/note_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(NotesApp(repository: NoteRepository(AppDatabase())));
}
