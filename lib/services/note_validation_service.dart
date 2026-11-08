import '../core/utils/amount_limit_exception.dart';
import '../models/note.dart';
import '../models/note_color.dart';
import 'note_calculation_service.dart';

class NoteValidationException implements Exception {
  const NoteValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class NoteValidationService {
  static String cleanLabel(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String key(String value) => cleanLabel(value).toLowerCase();

  static void validateColor(NoteColor color) {
    if (cleanLabel(color.name).isEmpty) {
      throw const NoteValidationException('Informe o nome da cor.');
    }
    if (color.sizes.isEmpty) {
      throw const NoteValidationException(
        'Adicione pelo menos um tamanho à cor.',
      );
    }
    final labels = <String>{};
    for (final size in color.sizes) {
      if (cleanLabel(size.label).isEmpty) {
        throw const NoteValidationException(
          'Preencha o tamanho de todas as linhas.',
        );
      }
      if (size.quantity <= 0) {
        throw const NoteValidationException(
          'A quantidade deve ser um inteiro maior que zero.',
        );
      }
      if (!labels.add(key(size.label))) {
        throw NoteValidationException(
          'O tamanho "${cleanLabel(size.label)}" está repetido nesta cor.',
        );
      }
    }
  }

  static void validate(Note note) {
    if (note.reference.trim().isEmpty) {
      throw const NoteValidationException('Informe a referência do lote.');
    }
    if (note.unitPriceCents <= 0) {
      throw const NoteValidationException(
        'Informe um valor unitário maior que zero.',
      );
    }
    if (note.colors.isEmpty) {
      throw const NoteValidationException('Adicione pelo menos uma cor.');
    }
    final names = <String>{};
    for (final color in note.colors) {
      validateColor(color);
      if (!names.add(key(color.name))) {
        throw NoteValidationException(
          'A cor "${cleanLabel(color.name)}" já foi adicionada.',
        );
      }
    }
    try {
      NoteCalculationService.notePieces(note);
      NoteCalculationService.noteValue(note);
    } on AmountLimitException {
      throw const NoteValidationException(AmountLimitException.message);
    }
  }
}
