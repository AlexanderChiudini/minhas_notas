import 'color_size.dart';

class NoteColor {
  NoteColor({this.id, required this.name, required List<ColorSize> sizes})
    : sizes = List.unmodifiable(sizes);

  final int? id;
  final String name;
  final List<ColorSize> sizes;
}
