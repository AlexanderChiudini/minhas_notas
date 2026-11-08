import 'note_color.dart';

class Note {
  Note({
    this.id,
    required this.reference,
    required this.unitPriceCents,
    this.createdAt,
    this.updatedAt,
    required List<NoteColor> colors,
  }) : colors = List.unmodifiable(colors);

  final int? id;
  final String reference;
  final int unitPriceCents;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<NoteColor> colors;
}
