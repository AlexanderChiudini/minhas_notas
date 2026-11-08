import '../core/utils/amount_limit_exception.dart';
import '../models/note.dart';
import '../models/note_color.dart';

class NoteCalculationService {
  static int _checked(BigInt value) {
    if (value.abs() > BigInt.from(9007199254740991)) {
      throw const AmountLimitException();
    }
    return value.toInt();
  }

  static int colorPieces(NoteColor color) => _checked(
    color.sizes.fold(
      BigInt.zero,
      (total, size) => total + BigInt.from(size.quantity),
    ),
  );

  static int colorValue(NoteColor color, int unitPriceCents) =>
      _checked(BigInt.from(colorPieces(color)) * BigInt.from(unitPriceCents));

  static int notePieces(Note note) => _checked(
    note.colors.fold(
      BigInt.zero,
      (total, color) => total + BigInt.from(colorPieces(color)),
    ),
  );

  static int noteValue(Note note) => _checked(
    note.colors.fold(
      BigInt.zero,
      (total, color) =>
          total + BigInt.from(colorValue(color, note.unitPriceCents)),
    ),
  );
}
