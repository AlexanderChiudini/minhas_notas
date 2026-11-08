import 'package:flutter/material.dart';

import '../repositories/note_repository.dart';
import '../widgets/common.dart';
import 'notes_list_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.repository});
  final NoteRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('minhas notas')),
    body: ContentWidth(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: 80,
              height: 80,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Suas anotações,\nsempre à mão.',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Referências, cores e quantidades em um só lugar. Tudo salvo neste aparelho.',
          ),
          const SizedBox(height: 32),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              leading: const Icon(Icons.description_outlined, size: 32),
              title: const Text('Notas'),
              subtitle: const Text('Cadastre, confira e gere seus PDFs'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => NotesListScreen(repository: repository),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
