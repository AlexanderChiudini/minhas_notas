import 'package:flutter_test/flutter_test.dart';
import 'package:minhas_notas/core/utils/currency_utils.dart';
import 'package:minhas_notas/models/color_size.dart';
import 'package:minhas_notas/models/note.dart';
import 'package:minhas_notas/models/note_color.dart';
import 'package:minhas_notas/services/note_calculation_service.dart';
import 'package:minhas_notas/services/note_validation_service.dart';

import 'fixtures.dart';

void main() {
  test('Cenário A: subtotais e soma geral exatos em centavos', () {
    final note = scenarioA();
    expect(NoteCalculationService.colorPieces(note.colors[0]), 106);
    expect(NoteCalculationService.colorValue(note.colors[0], 130), 13780);
    expect(NoteCalculationService.colorPieces(note.colors[1]), 81);
    expect(NoteCalculationService.colorValue(note.colors[1], 130), 10530);
    expect(NoteCalculationService.notePieces(note), 187);
    expect(NoteCalculationService.noteValue(note), 24310);
  });
  test('Cenário B: 136 peças e R\$ 190,40', () {
    final note = scenarioB();
    expect(NoteCalculationService.colorPieces(note.colors[0]), 64);
    expect(NoteCalculationService.colorPieces(note.colors[1]), 72);
    expect(NoteCalculationService.notePieces(note), 136);
    expect(NoteCalculationService.noteValue(note), 19040);
  });
  test('Conversão monetária sem arredondar ou usar ponto flutuante', () {
    for (final input in ['1,30', 'R\$ 1,30', '1.30', ' 1,3 ']) {
      expect(CurrencyUtils.parse(input), 130, reason: input);
    }
    expect(CurrencyUtils.parse('1.234,56'), 123456);
    expect(CurrencyUtils.parse('12'), 1200);
    expect(CurrencyUtils.parse('0,01'), 1);
    expect(CurrencyUtils.parse('0'), 0);
    for (final input in [
      '1,301',
      '1.2345',
      'abc',
      '-1,30',
      '',
      '1,',
      '1,2,3',
      '12.34,56',
    ]) {
      expect(CurrencyUtils.parse(input), isNull, reason: input);
    }
    expect(CurrencyUtils.format(24310).replaceAll('\u00a0', ' '), 'R\$ 243,10');
    expect(CurrencyUtils.editable(130), '1,30');
    expect(CurrencyUtils.parse('90071992547409,91'), 9007199254740991);
    expect(
      CurrencyUtils.format(9007199254740991).replaceAll('\u00a0', ' '),
      'R\$ 90.071.992.547.409,91',
    );
  });

  group('Validações', () {
    final invalid = throwsA(isA<NoteValidationException>());
    Note colorNote(List<NoteColor> colors) =>
        Note(reference: '001', unitPriceCents: 130, colors: colors);
    NoteColor color(String name, List<ColorSize> sizes) =>
        NoteColor(name: name, sizes: sizes);
    const validSize = ColorSize(label: 'P', quantity: 1);

    test('Referência e preço obrigatórios e positivos', () {
      expect(
        () => NoteValidationService.validate(simpleNote(reference: '  ')),
        invalid,
      );
      expect(
        () => NoteValidationService.validate(simpleNote(price: 0)),
        invalid,
      );
      expect(
        () => NoteValidationService.validate(simpleNote(price: -1)),
        invalid,
      );
      expect(
        () => NoteValidationService.validate(simpleNote(reference: ' 001-A ')),
        returnsNormally,
      );
    });
    test('Cor e tamanhos obrigatórios', () {
      expect(() => NoteValidationService.validate(colorNote([])), invalid);
      expect(
        () => NoteValidationService.validate(
          colorNote([
            color('', [validSize]),
          ]),
        ),
        invalid,
      );
      expect(
        () => NoteValidationService.validate(colorNote([color('Azul', [])])),
        invalid,
      );
      expect(
        () => NoteValidationService.validate(
          colorNote([
            color('Azul', [const ColorSize(label: ' ', quantity: 1)]),
          ]),
        ),
        invalid,
      );
    });
    test('Quantidade estritamente positiva', () {
      for (final qty in [-1, 0]) {
        expect(
          () => NoteValidationService.validate(simpleNote(quantity: qty)),
          invalid,
        );
      }
    });
    test('Cores e tamanhos duplicados com normalização e acentuação', () {
      expect(
        () => NoteValidationService.validate(
          colorNote([
            color(' AZUL  CLARO ', [validSize]),
            color('azul claro', [validSize]),
          ]),
        ),
        invalid,
      );
      expect(
        () => NoteValidationService.validate(
          colorNote([
            color('PÉROLA', [validSize]),
            color('pérola', [validSize]),
          ]),
        ),
        invalid,
      );
      expect(
        () => NoteValidationService.validate(
          colorNote([
            color('Azul', [
              const ColorSize(label: ' X  G ', quantity: 1),
              const ColorSize(label: 'x g', quantity: 2),
            ]),
          ]),
        ),
        invalid,
      );
    });
    test('Tamanhos livres e mesmos tamanhos entre cores diferentes', () {
      final labels = ['P', 'M', 'G', 'GG', 'XG', '42', '004', 'Especial A'];
      final row = labels.map((l) => ColorSize(label: l, quantity: 1)).toList();
      expect(
        () => NoteValidationService.validate(
          colorNote([color('Cinza', row), color('Azul', row)]),
        ),
        returnsNormally,
      );
    });
    test('Totais excessivos são rejeitados antes de persistir', () {
      expect(
        () => NoteValidationService.validate(
          simpleNote(price: 9007199254740991, quantity: 10),
        ),
        invalid,
      );
    });
  });
}
