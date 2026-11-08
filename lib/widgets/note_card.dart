import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/utils/currency_utils.dart';
import '../models/note.dart';
import '../services/note_calculation_service.dart';

enum NoteAction { view, edit, delete, pdf }

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onAction,
    this.enabled = true,
  });
  final Note note;
  final bool selecting;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<NoteAction> onAction;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selecting)
              Checkbox(
                value: selected,
                onChanged: enabled ? (_) => onTap() : null,
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Referência: ${note.reference}',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Total de cores: ${note.colors.length} • Total de peças: ${NoteCalculationService.notePieces(note)}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    CurrencyUtils.format(
                      NoteCalculationService.noteValue(note),
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Criada em ${DateFormat('dd/MM/yyyy').format(note.createdAt!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (!selecting)
              PopupMenuButton<NoteAction>(
                enabled: enabled,
                tooltip: 'Ações da nota ${note.reference}',
                onSelected: onAction,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: NoteAction.view,
                    child: Text('Visualizar'),
                  ),
                  PopupMenuItem(value: NoteAction.edit, child: Text('Editar')),
                  PopupMenuItem(
                    value: NoteAction.pdf,
                    child: Text('Gerar PDF'),
                  ),
                  PopupMenuItem(
                    value: NoteAction.delete,
                    child: Text('Excluir'),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}
