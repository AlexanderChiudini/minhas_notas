import 'package:flutter/material.dart';

import '../models/note.dart';
import '../repositories/note_repository.dart';
import '../services/pdf_service.dart';
import '../widgets/common.dart';
import '../widgets/note_card.dart';
import 'note_details_screen.dart';
import 'note_form_screen.dart';
import 'pdf_preview_screen.dart';

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key, required this.repository});
  final NoteRepository repository;
  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  late Future<List<Note>> _notes;
  final _selected = <int>{};
  bool _selecting = false;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _notes = widget.repository.list();
    widget.repository.addListener(_reload);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted) {
      setState(() {
        _notes = widget.repository.list();
      });
    }
  }

  void _cancelSelection() => setState(() {
    _selecting = false;
    _selected.clear();
  });
  void _toggle(int id) => setState(() {
    _selecting = true;
    if (!_selected.add(id)) _selected.remove(id);
  });

  Future<void> _edit([int? id]) async {
    if (_busy) return;
    Note? note;
    if (id != null) {
      setState(() => _busy = true);
      try {
        note = await widget.repository.get(id);
      } catch (error) {
        if (mounted) {
          showMessage(
            context,
            errorMessage(
              error,
              'Não foi possível abrir a nota para edição. Tente novamente.',
            ),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    if (!mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NoteFormScreen(repository: widget.repository, note: note),
      ),
    );
    if (saved == true && mounted) {
      showMessage(context, 'Nota salva com sucesso.');
    }
  }

  Future<void> _delete(List<int> ids, {String? reference}) async {
    if (_busy || ids.isEmpty) return;
    setState(() => _busy = true);
    try {
      final confirmed = await confirmAction(
        context,
        title: ids.length == 1 ? 'Excluir nota?' : 'Excluir notas?',
        message: reference != null
            ? 'Excluir a nota de referência $reference? Esta ação é permanente e não poderá ser desfeita.'
            : 'Excluir ${ids.length} notas selecionadas? Esta ação é permanente e removerá todas as cores e tamanhos relacionados.',
        action: 'Excluir',
      );
      if (!confirmed) return;
      await widget.repository.deleteMany(ids);
      if (mounted) {
        _cancelSelection();
        showMessage(
          context,
          ids.length == 1 ? 'Nota excluída.' : '${ids.length} notas excluídas.',
        );
      }
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          errorMessage(
            error,
            'Não foi possível excluir. Nenhuma nota foi alterada. Tente novamente.',
          ),
        );
        _reload();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pdf(List<int> ids) async {
    if (_busy || ids.isEmpty) return;
    setState(() => _busy = true);
    try {
      final document = await PdfService().fromRepository(
        widget.repository,
        ids,
      );
      if (mounted) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(document: document),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          errorMessage(error, 'Não foi possível gerar o PDF. Tente novamente.'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _action(Note note, NoteAction action) {
    switch (action) {
      case NoteAction.view:
        Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                NoteDetailsScreen(repository: widget.repository, id: note.id!),
          ),
        );
      case NoteAction.edit:
        _edit(note.id!);
      case NoteAction.delete:
        _delete([note.id!], reference: note.reference);
      case NoteAction.pdf:
        _pdf([note.id!]);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && !_selecting,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_busy && _selecting) _cancelSelection();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(_selecting ? '${_selected.length} selecionadas' : 'Notas'),
        actions: [
          if (!_selecting)
            TextButton(
              onPressed: _busy ? null : () => setState(() => _selecting = true),
              child: const Text('Selecionar'),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: FutureBuilder<List<Note>>(
              future: _notes,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return LoadError(
                    message: errorMessage(
                      snapshot.error!,
                      'Não foi possível acessar as notas salvas neste aparelho.',
                    ),
                    onRetry: _reload,
                  );
                }
                final notes = snapshot.data!;
                final orderedIds = notes
                    .where((n) => _selected.contains(n.id))
                    .map((n) => n.id!)
                    .toList();
                return Column(
                  children: [
                    if (_selecting)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Wrap(
                          spacing: 4,
                          alignment: WrapAlignment.center,
                          children: [
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(
                                      () => _selected.addAll(
                                        notes.map((n) => n.id!),
                                      ),
                                    ),
                              child: const Text('Selecionar todas'),
                            ),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(_selected.clear),
                              child: const Text('Desmarcar todas'),
                            ),
                            TextButton(
                              onPressed: _busy ? null : _cancelSelection,
                              child: const Text('Cancelar seleção'),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: notes.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.description_outlined,
                                      size: 64,
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'Suas notas começam aqui',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Cadastre a primeira nota para organizar seus lotes.',
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 24),
                                    FilledButton.icon(
                                      onPressed: _busy ? null : () => _edit(),
                                      icon: const Icon(Icons.add),
                                      label: const Text(
                                        'Cadastrar primeira nota',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ContentWidth(
                              child: RefreshIndicator(
                                onRefresh: () async {
                                  _reload();
                                  await _notes;
                                },
                                child: ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    16,
                                    20,
                                    100,
                                  ),
                                  itemCount: notes.length,
                                  separatorBuilder: (_, index) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (_, index) {
                                    final note = notes[index];
                                    return NoteCard(
                                      note: note,
                                      selecting: _selecting,
                                      selected: _selected.contains(note.id),
                                      enabled: !_busy,
                                      onTap: () => _selecting
                                          ? _toggle(note.id!)
                                          : _action(note, NoteAction.view),
                                      onLongPress: () => _toggle(note.id!),
                                      onAction: (action) =>
                                          _action(note, action),
                                    );
                                  },
                                ),
                              ),
                            ),
                    ),
                    if (_selecting)
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _busy || orderedIds.isEmpty
                                    ? null
                                    : () => _delete(orderedIds),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Excluir selecionadas'),
                              ),
                              FilledButton.icon(
                                onPressed: _busy || orderedIds.isEmpty
                                    ? null
                                    : () => _pdf(orderedIds),
                                icon: const Icon(Icons.picture_as_pdf_outlined),
                                label: const Text('Gerar PDF das selecionadas'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selecting
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Nova nota'),
            ),
    ),
  );
}
