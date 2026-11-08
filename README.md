# minhas notas

Aplicativo Flutter para anotar lotes de peças por referência, preço unitário,
cores, tamanhos livres e quantidades. Funciona sem internet, com SQLite local.
Não há autenticação, API, cadastro de clientes, estoque ou dados de demonstração
inseridos no aplicativo.

## Configuração e execução

Ambiente validado: Flutter **3.47.9 stable**, Dart **3.13.7**, Android SDK e Java 17
ou superior compatível com o Gradle do projeto. As versões resolvidas estão no
`pubspec.lock`; mantenha esse arquivo no controle de versão.

```sh
flutter pub get
flutter devices
flutter run -d <id-do-aparelho>
```

Use um aparelho Android com depuração USB ou um emulador. Android é o alvo
principal; o projeto mantém a configuração iOS. Para iOS, execute em macOS com
Xcode e as ferramentas de assinatura configuradas:

```sh
flutter run -d <id-do-iphone-ou-simulador>
flutter build ios --release
```

A primeira resolução de dependências e a compilação podem precisar de internet.
O aplicativo instalado, incluindo criação e renderização de PDFs, funciona
offline e não baixa fontes ou outros recursos. Web e desktop não fazem parte
da entrega; executar no Chrome não oferece a persistência SQLite mobile.

No Windows, se o Flutter informar que plugins precisam de links simbólicos,
habilite o **Modo de Desenvolvedor** nas configurações do Windows e execute
`flutter pub get` novamente.

## Uso

1. Abra **Notas** no menu principal e toque em **Nova nota**.
2. Informe a referência e o valor unitário em reais. Zeros iniciais da referência
   são preservados. O preço aceita, por exemplo, `1,30`, `1.30` e `1.234,56`.
3. Em **Cores e tamanhos**, informe uma cor e linhas de tamanho/quantidade.
   **Adicionar tamanho** cria linhas livres; o botão de remoção exclui a linha.
4. **Próxima cor** valida a cor atual e abre outra. Os cards das cores permitem
   voltar a uma cor para editar ou removê-la. Rascunhos ficam em memória e todos
   os totais acompanham as alterações. **Voltar** permite mudar referência/preço.
5. **Salvar** valida todas as cores e grava a nota completa em uma transação.
   Uma cor vazia aberta com **Próxima cor** deve ser preenchida ou removida.
6. Toque no card para conferir os detalhes. O menu de três pontos oferece
   visualização, edição, exclusão e PDF.
7. **Selecionar**, ou um toque longo, ativa a seleção múltipla. Há seleção de
   todas, desmarcação e cancelamento. Excluir sempre exige confirmação.
8. O PDF é apresentado antes de **Compartilhar** ou **Imprimir**. A impressão
   usa o serviço do sistema; o compartilhamento usa os aplicativos instalados.

Cancelar um formulário alterado exige confirmação. Alterações não salvas não
modificam o banco. Mensagens de erro permitem repetir operações sem perder o
rascunho. As notas ficam ordenadas pela criação, mesmo depois de editadas.

## Arquitetura e arquivos

| Local | Responsabilidade |
|---|---|
| `lib/main.dart`, `lib/app.dart` | Inicialização, tema e localização pt_BR |
| `lib/core/database/app_database.dart` | Abertura do SQLite, esquema versão 1, chaves estrangeiras, índices e cascatas |
| `lib/core/theme/app_theme.dart` | Material 3, azul-escuro, branco e cinza |
| `lib/core/utils/` | Conversão monetária e proteção de limites numéricos |
| `lib/models/` | Modelos imutáveis de nota, cor e tamanho |
| `lib/repositories/note_repository.dart` | Leitura e CRUD transacional; notificação da interface |
| `lib/services/note_calculation_service.dart` | Única implementação dos cálculos em centavos |
| `lib/services/note_validation_service.dart` | Obrigatoriedade, quantidades, duplicidade e normalização |
| `lib/services/pdf_service.dart` | PDF A4, duas cores lado a lado, paginação e nomes seguros |
| `lib/screens/` | Menu, listagem, formulário em duas etapas, detalhes e prévia do PDF |
| `lib/widgets/` | Cards, resumo, confirmação, mensagens de erro e largura adaptável |
| `assets/icon/` | Ícone original em SVG e PNG, sem letras |
| `tool/generate_icon.ps1` | Renderização reproduzível do SVG para PNG no Windows |
| `test/` | Cálculos, moeda, validação, SQLite, PDF e interface |
| `integration_test/app_test.dart` | Fluxo completo e renderização nativa no Android |
| `docs/VALIDATION.md` | Resultados e limites da validação realizada |

O banco `minhas_notas.db` fica no diretório privado de bancos do aplicativo.
As tabelas são `notes`, `note_colors` e `color_sizes`, com
`PRAGMA foreign_keys = ON` e `ON DELETE CASCADE`. Não há soft delete nem totais
armazenados. O preço pertence à nota e é persistido em centavos inteiros.

A atualização ocorre em uma transação: os relacionamentos são regravados
preservando os IDs sobreviventes, o que também permite trocar nomes de cores
sem conflito temporário de unicidade. IDs que pertençam a outra nota/cor são
rejeitados. A data de criação permanece inalterada.

Nomes de cores e tamanhos têm espaços consecutivos normalizados e são
comparados sem distinguir maiúsculas/minúsculas na validação de domínio,
incluindo letras acentuadas. A referência recebe somente `trim` nas extremidades.
Há também restrições SQL para obrigatoriedade, quantidade e unicidade ASCII.

Os cálculos verificam os limites antes de converter para inteiros. O limite de
totais é 9.007.199.254.740.991 centavos/peças; entradas acima dele são recusadas
com mensagem. A conversão e a apresentação monetária preservam os centavos.

PDFs usam os dados atualizados do SQLite e fontes padrão incorporadas ao formato
PDF, sem requisições de rede. Há dois grupos de Cor/Tamanho/Peças por linha;
a última cor ímpar ocupa a metade esquerda. Blocos de até 20 linhas mantêm
as tabelas e os subtotais juntos, repetindo a referência na continuação.
Não existe limite fixo de cores, tamanhos ou páginas. A geração em lote mantém
a ordem da seleção na listagem, começa cada nota em nova página e não soma
totais de notas distintas. PDFs são gerados em memória sob demanda.

## Testes e qualidade

```sh
flutter pub get
dart format .
flutter analyze
flutter test
flutter test integration_test/app_test.dart -d <id-do-android>
```

Os testes de persistência usam SQLite real via `sqflite_common_ffi`, com arquivos
temporários, reabertura do banco, cascata, IDs e falhas provocadas por trigger
para verificar rollback. Os testes de interface usam um repositório em memória
para isolar as animações dos temporizadores FFI. O teste no Android percorre
a interface usando o plugin SQLite real e renderiza os PDFs pelo `printing`.

O teste Android usa somente `integration_notes.db`, removido ao finalizar,
sem acessar o banco normal. `--no-uninstall` mantém a instalação de teste e
seus artefatos no emulador para inspeção; depois, reinstale o aplicativo normal.

Os PDFs dos cenários A/B e o exemplo de várias páginas são produzidos por
`flutter test` em `build/test_artifacts/`. A leitura dos fluxos do arquivo PDF
verifica referências, tamanhos, cores, subtotais, separação de páginas e totais.

## Ícones e build Android

O PNG original já está incluído e os ícones Android/iOS já foram gerados.
Após editar o SVG, no Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/generate_icon.ps1
flutter pub run flutter_launcher_icons
```

Para gerar um APK instalável localmente:

```sh
flutter build apk --debug
```

Saída: `build/app/outputs/flutter-apk/app-debug.apk`.

Para distribuição otimizada:

```sh
flutter build apk --release
flutter build appbundle --release
```

Antes de publicar em loja, configure o identificador definitivo e uma chave
privada de assinatura. A configuração atual usa a chave de depuração também
para builds locais em release; ela não é uma configuração de publicação.
As credenciais de assinatura não estão incluídas no projeto.

## Limites reais

O iOS não foi compilado neste ambiente Windows. Impressão em impressora física
e envio para aplicativos de terceiros dependem do aparelho e não foram
executados nos testes. As ações de sistema estão implementadas com `printing`.
As fontes padrão do PDF cobrem o português e caracteres latinos; alfabetos como
chinês e emojis não têm cobertura garantida.

Os registros permanecem neste aparelho. Não há sincronização, exportação do
banco ou restauração de backup dentro do aplicativo. Desinstalar ou limpar os
dados do aplicativo pode apagar as notas; o PDF é o documento compartilhável.
