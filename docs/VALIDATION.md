# Validação — 08/11/2026

Implementação baseada em `INSTRUCTIONS.md` e nas duas imagens da pasta `example/`.

## Verificações

- Flutter 3.47.9 stable / Dart 3.13.7 no Windows.
- Resolução de dependências com `flutter pub get`.
- Formatação com `dart format .` e análise com `flutter analyze`.
- Testes unitários de cálculos, moeda e validação.
- Suíte automatizada: 30 testes aprovados com `flutter test`.
- Análise estática: nenhum problema encontrado com `flutter analyze`.
- SQLite real em arquivos temporários: inserção, recuperação, atualização,
  preservação de IDs, remoção de cores/tamanhos, cascata, rollback e reabertura.
- Ordenação por `created_at DESC, id DESC`, sem alteração de posição após editar.
- Cenário A: Cinza 106 / R$ 137,80; Bege 81 / R$ 105,30; total 187 / R$ 243,10.
- Cenário B: Cinza 64; Azul 72; total 136 / R$ 190,40.
- Tamanhos P/M/G/GG, cores acentuadas, duplicidade e zeros iniciais.
- Conteúdo dos arquivos PDF individuais, em lote e de múltiplas páginas.
- Interface: cadastro, estado entre etapas, recálculo, erros, descarte,
  edição cancelada, seleção e exclusão, inclusive em tela de 320 × 640.
- APK Android debug compilado.
- Teste completo no emulador Android 17 / API 37: criação em duas etapas,
  edição, reabertura do SQLite e exclusão física de três notas e relações.
- PDF individual renderizado nativamente pelo Android; PDF em lote com duas páginas.
- Tela de prévia Android validada, com botões de impressão e compartilhamento.
- APK final recompilado a partir de `lib/main.dart` para Android ARM, ARM64 e x64.

## Artefatos

Gerados em `build/test_artifacts/` pelos testes, sem inserção no banco normal:

- `nota_15787.pdf`: cenário A.
- `notas_em_lote.pdf`: cenários A e B.
- `nota_multipagina.pdf`: cinco cores, incluindo uma com 140 tamanhos.
- `android/detalhes.png`: captura da interface nativa.
- `android/nota_15787.png`: renderização nativa do PDF.
- `android/nota_15787.pdf` e `android/notas_em_lote.pdf`: documentos gerados no Android.
- `android/preview.png`: tela nativa de prévia com as ações de impressão e compartilhamento.

O APK entregue em `build/app/outputs/flutter-apk/app-debug.apk` é compilado a
partir de `lib/main.dart`; o APK transitório dos testes de integração deve ser
substituído por esse build normal antes da entrega.

## Arquivos de implementação

Arquivos criados:

```text
lib/app.dart
lib/core/database/app_database.dart
lib/core/theme/app_theme.dart
lib/core/utils/amount_limit_exception.dart
lib/core/utils/currency_utils.dart
lib/models/color_size.dart
lib/models/note.dart
lib/models/note_color.dart
lib/repositories/note_repository.dart
lib/services/note_calculation_service.dart
lib/services/note_validation_service.dart
lib/services/pdf_service.dart
lib/screens/home_screen.dart
lib/screens/notes_list_screen.dart
lib/screens/note_form_screen.dart
lib/screens/note_details_screen.dart
lib/screens/pdf_preview_screen.dart
lib/widgets/common.dart
lib/widgets/note_card.dart
lib/widgets/note_summary.dart
assets/icon/app_icon.svg
assets/icon/app_icon.png
tool/generate_icon.ps1
test/domain_test.dart
test/fixtures.dart
test/repository_test.dart
test/pdf_test.dart
integration_test/app_test.dart
docs/VALIDATION.md
```

Arquivos existentes substituídos/atualizados: `lib/main.dart`,
`test/widget_test.dart`, `pubspec.yaml`, `pubspec.lock`, `README.md`,
`android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml` e
`ios/Runner/Info.plist`. O gerador atualizou os PNGs nas pastas Android
`mipmap-*` e iOS `Runner/Assets.xcassets/AppIcon.appiconset`, e criou os recursos
adaptativos Android em `mipmap-anydpi-v26` e `values/colors.xml`.

`INSTRUCTIONS.md` e as imagens originais em `example/` foram preservados.

## Limitações da validação

Não houve build iOS, teste em iPhone, impressão física ou compartilhamento para
um aplicativo externo. Publicação em loja requer identificador e assinatura
definitivos. O PDF utiliza fontes padrão latinas, adequadas aos exemplos e ao
português; outros alfabetos e emojis não foram validados.
