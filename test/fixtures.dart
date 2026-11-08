import 'package:minhas_notas/models/color_size.dart';
import 'package:minhas_notas/models/note.dart';
import 'package:minhas_notas/models/note_color.dart';

Note scenarioA() => Note(
  reference: '15787',
  unitPriceCents: 130,
  colors: [
    NoteColor(name: 'Cinza', sizes: sizes([12, 12, 16, 16, 15, 16, 11, 8])),
    NoteColor(name: 'Bege', sizes: sizes([12, 12, 12, 4, 6, 16, 12, 7])),
  ],
);

Note scenarioB() => Note(
  reference: '50353',
  unitPriceCents: 140,
  colors: [
    NoteColor(name: 'Cinza', sizes: sizes([8, 8, 8, 8, 8, 8, 8, 8])),
    NoteColor(name: 'Azul', sizes: sizes([8, 8, 8, 8, 8, 12, 12, 8])),
  ],
);

List<ColorSize> sizes(List<int> quantities) {
  const labels = ['1', '2', '3', '4', '6', '8', '10', '12'];
  return [
    for (var i = 0; i < quantities.length; i++)
      ColorSize(label: labels[i], quantity: quantities[i]),
  ];
}

Note simpleNote({
  String reference = '001ABC',
  int price = 130,
  int quantity = 12,
}) => Note(
  reference: reference,
  unitPriceCents: price,
  colors: [
    NoteColor(
      name: 'Azul',
      sizes: [ColorSize(label: 'P', quantity: quantity)],
    ),
  ],
);
