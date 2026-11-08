import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'repositories/note_repository.dart';
import 'screens/home_screen.dart';

class NotesApp extends StatelessWidget {
  const NotesApp({super.key, required this.repository});
  final NoteRepository repository;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'minhas notas',
    debugShowCheckedModeBanner: false,
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: AppTheme.light,
    home: HomeScreen(repository: repository),
  );
}
