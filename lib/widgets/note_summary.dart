import 'package:flutter/material.dart';

import '../core/utils/amount_limit_exception.dart';
import '../core/utils/currency_utils.dart';
import '../models/note.dart';
import '../services/note_calculation_service.dart';

class NoteSummary extends StatelessWidget {
  const NoteSummary({super.key, required this.note});
  final Note note;

  @override
  Widget build(BuildContext context) {
    try {
      return _summary(context);
    } on AmountLimitException {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(AmountLimitException.message),
      );
    }
  }

  Widget _summary(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${note.colors.length} cores • Total de peças: ${NoteCalculationService.notePieces(note)}',
        ),
        const SizedBox(height: 6),
        Text(
          'Valor total da nota: ${CurrencyUtils.format(NoteCalculationService.noteValue(note))}',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}
