import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/utils/amount_limit_exception.dart';
import '../core/utils/currency_utils.dart';
import '../models/color_size.dart';
import '../models/note.dart';
import '../models/note_color.dart';
import '../repositories/note_repository.dart';
import '../services/note_calculation_service.dart';
import '../services/note_validation_service.dart';
import '../widgets/common.dart';
import '../widgets/note_summary.dart';

class _SizeDraft {
  _SizeDraft([ColorSize? value])
    : id = value?.id,
      label = TextEditingController(text: value?.label),
      quantity = TextEditingController(text: value?.quantity.toString());
  final int? id;
  final TextEditingController label;
  final TextEditingController quantity;
  ColorSize get value => ColorSize(
    id: id,
    label: NoteValidationService.cleanLabel(label.text),
    quantity: int.tryParse(quantity.text) ?? 0,
  );
  void dispose() {
    label.dispose();
    quantity.dispose();
  }
}

class _ColorDraft {
  _ColorDraft([NoteColor? value])
    : id = value?.id,
      name = TextEditingController(text: value?.name),
      sizes = value == null
          ? [_SizeDraft()]
          : value.sizes.map(_SizeDraft.new).toList();
  final int? id;
  final TextEditingController name;
  final List<_SizeDraft> sizes;
  NoteColor get value => NoteColor(
    id: id,
    name: NoteValidationService.cleanLabel(name.text),
    sizes: sizes.map((s) => s.value).toList(),
  );
  bool get hasData =>
      name.text.isNotEmpty ||
      sizes.any((s) => s.label.text.isNotEmpty || s.quantity.text.isNotEmpty);
  void dispose() {
    name.dispose();
    for (final s in sizes) {
      s.dispose();
    }
  }
}

class NoteFormScreen extends StatefulWidget {
  const NoteFormScreen({super.key, required this.repository, this.note});
  final NoteRepository repository;
  final Note? note;
  @override
  State<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends State<NoteFormScreen> {
  final _generalKey = GlobalKey<FormState>();
  final _scroll = ScrollController();
  late final TextEditingController _reference;
  late final TextEditingController _price;
  late final List<_ColorDraft> _colors;
  int _step = 1;
  int _active = 0;
  bool _dirty = false;
  bool _busy = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _reference = TextEditingController(text: widget.note?.reference)
      ..addListener(_touch);
    _price = TextEditingController(
      text: widget.note == null
          ? ''
          : CurrencyUtils.editable(widget.note!.unitPriceCents),
    )..addListener(_touch);
    _colors =
        widget.note?.colors.map(_ColorDraft.new).toList() ?? [_ColorDraft()];
    for (final color in _colors) {
      _listen(color);
    }
  }

  void _touch() {
    if (mounted) setState(() => _dirty = true);
  }

  void _listen(_ColorDraft color) {
    color.name.addListener(_touch);
    for (final size in color.sizes) {
      _listenSize(size);
    }
  }

  void _listenSize(_SizeDraft size) {
    size.label.addListener(_touch);
    size.quantity.addListener(_touch);
  }

  @override
  void dispose() {
    _reference.dispose();
    _price.dispose();
    _scroll.dispose();
    for (final color in _colors) {
      color.dispose();
    }
    super.dispose();
  }

  int get _unitPrice => CurrencyUtils.parse(_price.text) ?? 0;
  String _piecesText(NoteColor color) {
    try {
      return '${NoteCalculationService.colorPieces(color)}';
    } on AmountLimitException {
      return 'Acima do limite';
    }
  }

  String _valueText(NoteColor color) {
    try {
      return CurrencyUtils.format(
        NoteCalculationService.colorValue(color, _unitPrice),
      );
    } on AmountLimitException {
      return 'Acima do limite';
    }
  }

  Note _note({bool summary = false}) => Note(
    id: widget.note?.id,
    reference: _reference.text.trim(),
    unitPriceCents: _unitPrice,
    colors: _colors
        .where((c) => !summary || c.hasData)
        .map((c) => c.value)
        .toList(),
  );

  void _toTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _exit({bool saved = false}) async {
    if (_busy && !saved) return;
    if (!saved && _dirty) {
      final discard = await confirmAction(
        context,
        title: 'Descartar alterações?',
        message: 'Os dados que você alterou ainda não foram salvos.',
        action: 'Descartar',
      );
      if (!discard || !mounted) return;
    }
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context, saved);
  }

  Future<void> _back() async {
    if (_busy) return;
    if (_step == 2) {
      setState(() => _step = 1);
      _toTop();
    } else {
      await _exit();
    }
  }

  bool _validateCurrent() {
    try {
      NoteValidationService.validateColor(_colors[_active].value);
      final name = NoteValidationService.key(_colors[_active].name.text);
      if (_colors.indexed.any(
        (entry) =>
            entry.$1 != _active &&
            NoteValidationService.key(entry.$2.name.text) == name,
      )) {
        throw const NoteValidationException(
          'Esta cor já foi adicionada. Edite a cor existente.',
        );
      }
      return true;
    } on NoteValidationException catch (error) {
      showMessage(context, error.message);
      return false;
    }
  }

  void _nextColor() {
    if (!_validateCurrent()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      final next = _ColorDraft();
      _listen(next);
      _colors.add(next);
      _active = _colors.length - 1;
      _dirty = true;
    });
    _toTop();
  }

  Future<void> _save() async {
    if (_busy) return;
    if (!_validateCurrent()) return;
    final note = _note();
    try {
      NoteValidationService.validate(note);
    } on NoteValidationException catch (error) {
      showMessage(context, error.message);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await widget.repository.save(note);
      if (!mounted) return;
      await _exit(saved: true);
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(
          context,
          errorMessage(
            error,
            'Não foi possível salvar a nota. Seus dados continuam no formulário. Tente novamente.',
          ),
        );
      }
    }
  }

  void _removeColor(int index) {
    final removed = _colors[index];
    setState(() {
      _colors.removeAt(index);
      if (_colors.isEmpty) {
        final fresh = _ColorDraft();
        _listen(fresh);
        _colors.add(fresh);
      }
      if (index < _active) _active--;
      if (_active >= _colors.length) _active = _colors.length - 1;
      _dirty = true;
    });
    // Controllers remain attached until the old fields leave the widget tree.
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _back();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'Nova nota' : 'Editar nota'),
        leading: IconButton(
          onPressed: _busy ? null : _back,
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            onPressed: _busy ? null : () => _exit(),
            tooltip: 'Cancelar cadastro',
            icon: const Icon(Icons.close),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Etapa $_step de 2 • ${_step == 1 ? 'Dados do lote' : 'Cores e tamanhos'}',
            ),
          ),
        ),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ContentWidth(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(20),
            children: _step == 1 ? _generalFields() : _colorFields(),
          ),
        ),
      ),
    ),
  );

  List<Widget> _generalFields() => [
    Form(
      key: _generalKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Dados do lote',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _reference,
            decoration: const InputDecoration(
              labelText: 'Referência do lote',
              hintText: 'Ex.: 0015787',
            ),
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            validator: (value) => (value ?? '').trim().isEmpty
                ? 'Informe a referência do lote.'
                : null,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _price,
            decoration: const InputDecoration(
              labelText: 'Valor unitário da peça',
              prefixText: 'R\$ ',
              hintText: '1,30',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              final cents = CurrencyUtils.parse(value ?? '');
              return cents == null || cents <= 0
                  ? 'Informe um valor maior que zero, com até duas casas decimais.'
                  : null;
            },
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () {
              if (_generalKey.currentState!.validate()) {
                FocusScope.of(context).unfocus();
                setState(() => _step = 2);
                _toTop();
              }
            },
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Próximo'),
          ),
        ],
      ),
    ),
  ];

  List<Widget> _colorFields() {
    final color = _colors[_active];
    final value = color.value;
    return [
      Text(
        'Referência: ${_reference.text.trim()}',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 6),
      Text('Valor por peça: ${CurrencyUtils.format(_unitPrice)}'),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            key: ObjectKey(color),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cor ${_active + 1}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: color.name,
                decoration: const InputDecoration(
                  labelText: 'Cor',
                  hintText: 'Ex.: Cinza',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),
              const Text('Tamanhos e quantidades'),
              const SizedBox(height: 12),
              for (final size in color.sizes)
                Padding(
                  key: ObjectKey(size),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: size.label,
                          decoration: const InputDecoration(
                            labelText: 'Tamanho',
                          ),
                          textCapitalization: TextCapitalization.characters,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: size.quantity,
                          decoration: const InputDecoration(
                            labelText: 'Quantidade',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(12),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remover tamanho',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          setState(() {
                            color.sizes.remove(size);
                            _dirty = true;
                          });
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => size.dispose(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    final row = _SizeDraft();
                    _listenSize(row);
                    color.sizes.add(row);
                    _dirty = true;
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Adicionar tamanho'),
              ),
              const SizedBox(height: 18),
              Text('Total de peças da cor: ${_piecesText(value)}'),
              const SizedBox(height: 6),
              Text(
                'Valor total da cor: ${_valueText(value)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      if (_colors.length > 1) ...[
        Text('Cores da nota', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        for (final entry in _colors.indexed)
          Card(
            child: ListTile(
              selected: entry.$1 == _active,
              title: Text(
                entry.$2.name.text.trim().isEmpty
                    ? 'Cor em preenchimento'
                    : entry.$2.name.text.trim(),
              ),
              subtitle: Text(
                '${_piecesText(entry.$2.value)} peças • ${_valueText(entry.$2.value)}',
              ),
              leading: Icon(
                entry.$1 == _active ? Icons.edit : Icons.palette_outlined,
              ),
              onTap: () {
                FocusScope.of(context).unfocus();
                setState(() => _active = entry.$1);
                _toTop();
              },
              trailing: IconButton(
                tooltip: 'Remover cor',
                onPressed: () => _removeColor(entry.$1),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],
      NoteSummary(note: _note(summary: true)),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: _nextColor,
        icon: const Icon(Icons.add),
        label: const Text('Próxima cor'),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _busy ? null : _save,
        icon: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.check),
        label: Text(_busy ? 'Salvando…' : 'Salvar'),
      ),
      const SizedBox(height: 8),
      TextButton(onPressed: _back, child: const Text('Voltar')),
      const SizedBox(height: 24),
    ];
  }
}
