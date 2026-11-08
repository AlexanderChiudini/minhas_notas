import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minhas_notas/app.dart';
import 'package:minhas_notas/core/database/app_database.dart';
import 'package:minhas_notas/models/note.dart';
import 'package:minhas_notas/repositories/note_repository.dart';
import 'package:minhas_notas/screens/note_details_screen.dart';
import 'package:minhas_notas/screens/note_form_screen.dart';
import 'package:minhas_notas/services/note_validation_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fixtures.dart';

// SQLite is exercised against real files in repository_test and on Android in
// integration_test. This fake keeps widget animations independent of FFI timers.
class _WidgetRepository extends NoteRepository {
  _WidgetRepository() : super(AppDatabase(factory: databaseFactoryFfi));
  final _items = <int, Note>{};
  var _nextId = 1;
  bool failNextSave = false;
  @override
  Future<List<Note>> list() async => _items.values.toList().reversed.toList();
  @override
  Future<Note> get(int id) async => _items[id]!;
  @override
  Future<int> save(Note note) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('Falha de gravação simulada somente neste teste.');
    }
    NoteValidationService.validate(note);
    final id = note.id ?? _nextId++;
    _items[id] = Note(
      id: id,
      reference: note.reference,
      unitPriceCents: note.unitPriceCents,
      createdAt: note.createdAt ?? DateTime(2026, 11, 8),
      colors: note.colors,
    );
    notifyListeners();
    return id;
  }

  @override
  Future<void> deleteMany(Iterable<int> ids) async {
    for (final id in ids) {
      _items.remove(id);
    }
    notifyListeners();
  }
}

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> press(WidgetTester tester, String text) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  if (find.text(text).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(text),
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  if (find.byType(AlertDialog).evaluate().isEmpty) await tester.pumpAndSettle();
}

void main() {
  late NoteRepository repository;
  setUp(() {
    repository = _WidgetRepository();
  });
  tearDown(() {
    repository.dispose();
  });

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(NotesApp(repository: repository));
    await tester.pumpAndSettle();
    await press(tester, 'Notas');
  }

  Future<void> general(WidgetTester tester) async {
    await press(tester, 'Nova nota');
    await tester.enterText(field('Referência do lote'), '001-A');
    await tester.enterText(field('Valor unitário da peça'), '1,30');
    await press(tester, 'Próximo');
  }

  testWidgets('Cadastro em duas etapas com duas cores e recálculo imediato', (
    tester,
  ) async {
    await start(tester);
    expect(find.text('Suas notas começam aqui'), findsOneWidget);
    await general(tester);
    expect(await repository.list(), isEmpty);
    await tester.enterText(field('Cor'), 'Cinza');
    await tester.enterText(field('Tamanho'), 'P');
    await tester.enterText(field('Quantidade'), '10');
    await tester.pump();
    expect(find.text('Total de peças da cor: 10'), findsOneWidget);
    await press(tester, 'Adicionar tamanho');
    await tester.enterText(field('Tamanho').last, 'M');
    await tester.enterText(field('Quantidade').last, '5');
    await press(tester, 'Próxima cor');
    await tester.enterText(field('Cor'), 'Bege');
    await tester.enterText(field('Tamanho'), 'GG');
    await tester.enterText(field('Quantidade'), '2');
    await press(tester, 'Voltar');
    expect(find.text('001-A'), findsOneWidget);
    await tester.enterText(field('Valor unitário da peça'), '1,40');
    await press(tester, 'Próximo');
    expect(find.text('Bege'), findsWidgets);
    expect(find.textContaining('23,80'), findsOneWidget);
    await press(tester, 'Salvar');
    expect(find.byType(NoteFormScreen), findsNothing);
    expect(find.text('Nota salva com sucesso.'), findsOneWidget);
    final notes = await repository.list();
    expect(notes, hasLength(1));
    expect(notes.single.unitPriceCents, 140);
    expect(notes.single.colors.map((c) => c.name), ['Cinza', 'Bege']);
    await press(tester, 'Referência: 001-A');
    expect(find.byType(NoteDetailsScreen), findsOneWidget);
    expect(find.text('Total de peças: 15'), findsOneWidget);
    expect(find.textContaining('23,80'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Validação, duplicidade e descarte sem persistir rascunhos', (
    tester,
  ) async {
    await start(tester);
    await press(tester, 'Nova nota');
    await press(tester, 'Próximo');
    expect(find.text('Informe a referência do lote.'), findsOneWidget);
    await tester.enterText(field('Referência do lote'), '007');
    await tester.enterText(field('Valor unitário da peça'), '0');
    await press(tester, 'Próximo');
    expect(field('Cor'), findsNothing);
    await tester.enterText(field('Valor unitário da peça'), '1,30');
    await press(tester, 'Próximo');
    await press(tester, 'Salvar');
    expect(find.text('Informe o nome da cor.'), findsOneWidget);
    await tester.enterText(field('Cor'), 'Azul');
    await tester.enterText(field('Tamanho'), 'P');
    await tester.enterText(field('Quantidade'), '1');
    await press(tester, 'Próxima cor');
    await tester.enterText(field('Cor'), ' AZUL ');
    await tester.enterText(field('Tamanho'), 'P');
    await tester.enterText(field('Quantidade'), '1');
    await press(tester, 'Salvar');
    expect(
      find.text('Esta cor já foi adicionada. Edite a cor existente.'),
      findsOneWidget,
    );
    expect(await repository.list(), isEmpty);
    await tester.tap(find.byTooltip('Cancelar cadastro'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar alterações?'), findsOneWidget);
    await press(tester, 'Cancelar');
    expect(field('Cor'), findsOneWidget);
    await tester.tap(find.byTooltip('Cancelar cadastro'));
    await tester.pumpAndSettle();
    await press(tester, 'Descartar');
    expect(find.byType(NoteFormScreen), findsNothing);
    expect(await repository.list(), isEmpty);
  });

  testWidgets('Seleção múltipla, confirmação, desmarcar e exclusão física', (
    tester,
  ) async {
    await repository.save(scenarioA());
    await repository.save(scenarioB());
    await start(tester);
    await press(tester, 'Selecionar');
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Gerar PDF das selecionadas'),
          )
          .onPressed,
      isNull,
    );
    await press(tester, 'Selecionar todas');
    expect(find.text('2 selecionadas'), findsOneWidget);
    await press(tester, 'Desmarcar todas');
    expect(find.text('0 selecionadas'), findsOneWidget);
    await press(tester, 'Selecionar todas');
    await press(tester, 'Excluir selecionadas');
    expect(
      find.textContaining('Excluir 2 notas selecionadas?'),
      findsOneWidget,
    );
    await press(tester, 'Cancelar');
    expect(await repository.list(), hasLength(2));
    await press(tester, 'Excluir selecionadas');
    await press(tester, 'Excluir');
    expect(await repository.list(), isEmpty);
    expect(find.text('Suas notas começam aqui'), findsOneWidget);
  });

  testWidgets('Cancelar edição mantém o registro original', (tester) async {
    await repository.save(simpleNote());
    await start(tester);
    await press(tester, 'Referência: 001ABC');
    await press(tester, 'Editar');
    await tester.enterText(field('Referência do lote'), 'ALTERADA');
    await tester.tap(find.byTooltip('Cancelar cadastro'));
    await tester.pumpAndSettle();
    await press(tester, 'Descartar');
    final Note persisted = (await repository.list()).single;
    expect(persisted.reference, '001ABC');
    expect(find.text('Referência: 001ABC'), findsOneWidget);
  });

  testWidgets('Tela estreita mantém campos e ações acessíveis', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(NotesApp(repository: repository));
    await tester.pumpAndSettle();
    await press(tester, 'Notas');
    await general(tester);
    await tester.enterText(field('Cor'), 'Branco');
    await tester.enterText(field('Tamanho'), 'XG');
    await tester.enterText(field('Quantidade'), '3');
    await press(tester, 'Salvar');
    expect(await repository.list(), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Cores anteriores podem ser editadas e removidas sem perder o rascunho atual',
    (tester) async {
      await start(tester);
      await general(tester);
      await tester.enterText(field('Cor'), 'Cinza');
      await tester.enterText(field('Tamanho'), 'P');
      await tester.enterText(field('Quantidade'), '10');
      await press(tester, 'Próxima cor');
      await tester.enterText(field('Cor'), 'Bege');
      await tester.enterText(field('Tamanho'), 'GG');
      await tester.enterText(field('Quantidade'), '3');
      await tester.tap(find.widgetWithText(ListTile, 'Cinza'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('Quantidade')).controller!.text,
        '10',
      );
      await tester.enterText(field('Quantidade'), '20');
      await tester.tap(find.widgetWithText(ListTile, 'Bege'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('Quantidade')).controller!.text,
        '3',
      );
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Cinza'),
          matching: find.byTooltip('Remover cor'),
        ),
      );
      await tester.pumpAndSettle();
      await press(tester, 'Salvar');
      final note = (await repository.list()).single;
      expect(note.colors.single.name, 'Bege');
      expect(note.colors.single.sizes.single.label, 'GG');
      expect(note.colors.single.sizes.single.quantity, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Falha ao salvar mantém os dados e permite tentar novamente', (
    tester,
  ) async {
    (repository as _WidgetRepository).failNextSave = true;
    await start(tester);
    await general(tester);
    await tester.enterText(field('Cor'), 'Azul');
    await tester.enterText(field('Tamanho'), 'P');
    await tester.enterText(field('Quantidade'), '10');
    await press(tester, 'Salvar');
    expect(find.byType(NoteFormScreen), findsOneWidget);
    expect(
      find.textContaining('Seus dados continuam no formulário'),
      findsOneWidget,
    );
    expect(await repository.list(), isEmpty);
    await press(tester, 'Salvar');
    expect(await repository.list(), hasLength(1));
    expect(find.byType(NoteFormScreen), findsNothing);
  });
}
