import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/utils/currency_utils.dart';
import '../models/note.dart';
import '../repositories/note_repository.dart';
import '../services/note_calculation_service.dart';
import '../services/pdf_service.dart';
import '../widgets/common.dart';
import '../widgets/note_summary.dart';
import 'note_form_screen.dart';
import 'pdf_preview_screen.dart';

class NoteDetailsScreen extends StatefulWidget {
  const NoteDetailsScreen({
    super.key,
    required this.repository,
    required this.id,
  });
  final NoteRepository repository;
  final int id;
  @override
  State<NoteDetailsScreen> createState() => _NoteDetailsScreenState();
}

class _NoteDetailsScreenState extends State<NoteDetailsScreen> {
  late Future<Note> _note;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _note = widget.repository.get(widget.id);
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
        _note = widget.repository.get(widget.id);
      });
    }
  }

  Future<void> _edit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final note = await widget.repository.get(widget.id);
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
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          errorMessage(error, 'Não foi possível abrir a edição da nota.'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pdf() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final document = await PdfService().fromRepository(widget.repository, [
        widget.id,
      ]);
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalhes da nota')),
    body: Column(
      children: [
        if (_busy) const LinearProgressIndicator(),
        Expanded(
          child: FutureBuilder<Note>(
            future: _note,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return LoadError(
                  message: errorMessage(
                    snapshot.error!,
                    'Não foi possível carregar esta nota.',
                  ),
                  onRetry: _reload,
                );
              }
              final note = snapshot.data!;
              return ContentWidth(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Referência: ${note.reference}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Valor unitário: ${CurrencyUtils.format(note.unitPriceCents)}',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Criada em ${DateFormat('dd/MM/yyyy').format(note.createdAt!)}',
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _edit,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar'),
                        ),
                        FilledButton.icon(
                          onPressed: _busy ? null : _pdf,
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Gerar PDF'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    for (final color in note.colors)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  color.name,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 12),
                                const Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Tamanho',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Quantidade',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(),
                                for (final size in color.sizes)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 7,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(size.label)),
                                        Text('${size.quantity}'),
                                      ],
                                    ),
                                  ),
                                const Divider(),
                                Text(
                                  'Total de peças: ${NoteCalculationService.colorPieces(color)}',
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Valor total da cor: ${CurrencyUtils.format(NoteCalculationService.colorValue(color, note.unitPriceCents))}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    NoteSummary(note: note),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
