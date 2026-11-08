# Projeto: minhas notas — Aplicativo Flutter + Dart + SQLite

## 0. Exemplos

Em anexo, tenho as imagens de exemplo de como deve ficar o PDF e do que eu espero que o app seja capaz de fazer [imagnes](example)

## 1. Objetivo

Desenvolva um aplicativo mobile chamado **minhas notas**, utilizando **Flutter e Dart**, com persistência local em **SQLite**.

O aplicativo será utilizado para controlar notas de lotes de peças, com referência, preço unitário, cores, tamanhos e quantidades.

Tenho duas imagens de anotações manuais que representam a lógica de funcionamento do aplicativo. Utilize-as como referência visual, especialmente a **primeira imagem para a geração dos PDFs**.

**IMPORTANTE:** Este é um projeto novo, independente de qualquer sistema anterior de romaneio. Não implementar funcionalidades de romaneio, estoque, vendas, clientes ou controle financeiro que não estejam especificadas aqui.

O objetivo é entregar um aplicativo simples, rápido, organizado e realmente funcional.

## 2. Tecnologias e requisitos técnicos

Utilizar:

- Flutter com Dart e Material Design 3.
- SQLite local utilizando `sqflite`.
- `path` e `path_provider` quando necessários.
- `intl` para formatação monetária brasileira.
- `pdf` para geração de documentos.
- `printing` para visualização, impressão e compartilhamento de PDFs.
- `flutter_launcher_icons` para configuração do ícone.
- Testes com `flutter_test` e ferramentas adequadas para testar SQLite.

O aplicativo deve funcionar prioritariamente em Android, mantendo compatibilidade com iOS.

Não utilizar Firebase, APIs externas, serviços de nuvem ou autenticação. Todos os registros devem funcionar sem internet.

Utilizar versões estáveis dos pacotes compatíveis com a versão do Flutter instalada no ambiente.

## 3. Identidade visual

Nome exibido do aplicativo: **minhas notas**

Criar um ícone próprio, minimalista, representando uma folha de papel com linhas de anotação, uma marca de conferência e um lápis.

O ícone não deve utilizar letras ou iniciais.

Utilizar uma identidade visual discreta, com cores como azul-escuro, branco e cinza-claro, priorizando legibilidade.

A interface deve ser moderna, limpa e adaptável a diferentes tamanhos de tela. Priorizar campos grandes e fáceis de utilizar no celular.

Não adicionar funcionalidades decorativas desnecessárias.

## 4. Estrutura de navegação

O aplicativo deverá possuir as seguintes telas:

1. Menu principal.
2. Listagem de notas.
3. Cadastro de nota — Etapa 1.
4. Cadastro de nota — Etapa 2 (cores).
5. Visualização dos detalhes de uma nota.
6. Edição de nota.
7. Visualização de PDF.

O menu principal deve conter somente uma opção de navegação: **Notas**.

Na listagem de notas deve existir um botão destacado para cadastrar uma nova nota.

## 5. Modelo de dados SQLite

Utilizar três tabelas relacionadas.

### 5.1. Tabela `notes`

Campos:

- `id`: INTEGER PRIMARY KEY AUTOINCREMENT
- `reference`: TEXT NOT NULL
- `unit_price_cents`: INTEGER NOT NULL
- `created_at`: TEXT NOT NULL
- `updated_at`: TEXT NOT NULL

A referência é um identificador informado pelo usuário e deve ser tratada como texto, permitindo números, letras e zeros à esquerda.

O preço unitário pertence à nota, não às cores individuais.

Não exigir unicidade global da referência entre diferentes notas. Cada nota possui seu próprio ID interno.

### 5.2. Tabela `note_colors`

Campos:

- `id`: INTEGER PRIMARY KEY AUTOINCREMENT
- `note_id`: INTEGER NOT NULL
- `name`: TEXT NOT NULL
- `sort_order`: INTEGER NOT NULL

Relacionamento:

`note_colors.note_id` referencia `notes.id`.

Cada nota pode possuir uma ou várias cores.

Não permitir duas cores com o mesmo nome dentro da mesma nota, desconsiderando diferenças entre letras maiúsculas e minúsculas.

### 5.3. Tabela `color_sizes`

Campos:

- `id`: INTEGER PRIMARY KEY AUTOINCREMENT
- `color_id`: INTEGER NOT NULL
- `size_label`: TEXT NOT NULL
- `quantity`: INTEGER NOT NULL
- `sort_order`: INTEGER NOT NULL

Relacionamento:

`color_sizes.color_id` referencia `note_colors.id`.

O campo `size_label` deve aceitar tamanhos numéricos ou alfanuméricos.

Exemplos: `1`, `2`, `4`, `12`, `P`, `M`, `G`, `GG`, `XG`, `42`, `44`.

Não limitar os tamanhos a uma enumeração fixa.

Não permitir tamanhos duplicados dentro da mesma cor, considerando a normalização de espaços e diferenças de maiúsculas/minúsculas.

### 5.4. Regras do banco

- Ativar `PRAGMA foreign_keys = ON`.
- Utilizar integridade referencial.
- Implementar exclusão física com `ON DELETE CASCADE` ou exclusão transacional equivalente.
- Nunca utilizar soft delete.
- Utilizar transações para salvar, editar e excluir estruturas relacionadas.
- Preservar a ordem de cadastro das cores e tamanhos por meio de `sort_order`.
- Não persistir valores totais calculáveis; derivá-los dos dados e do preço unitário.

## 6. Cadastro de notas

O cadastro deve funcionar em duas etapas.

### ETAPA 1 — Dados gerais do lote

Exibir somente os campos:

**Referência do lote**

- Campo de texto obrigatório.
- Aceitar números e letras.
- Preservar o valor informado, removendo espaços desnecessários nas extremidades.

**Valor unitário da peça**

- Campo monetário obrigatório.
- Utilizar formato brasileiro, como R$ 1,30.
- Aceitar valores com até duas casas decimais.
- Não permitir valores menores ou iguais a zero.

Exemplo:

Referência: `15787`

Valor por peça: `R$ 1,30`

Botão principal: **Próximo**

Ao clicar, validar os campos e avançar para o cadastro de cores.

Não criar uma nota incompleta no SQLite simplesmente porque o usuário avançou para a segunda etapa. Manter os dados temporariamente em memória até a finalização.

### ETAPA 2 — Cadastro das cores

Esta etapa deve permitir cadastrar uma quantidade ilimitada de cores.

Cada cor representa um bloco de cadastro independente, pertencente à mesma nota.

Campos editáveis:

**Cor**

- Campo de texto obrigatório.
- Exemplos: Cinza, Bege, Azul, Preto, Branco.

**Tamanhos e quantidades**

Exibir linhas com dois campos:

| Tamanho | Quantidade |
|---|---|
| 1 | 12 |
| 2 | 12 |
| 3 | 16 |
| 4 | 16 |

O usuário poderá adicionar quantas linhas desejar.

Cada linha deve conter:

- Campo editável para tamanho.
- Campo numérico editável para quantidade.
- Botão para remover a linha.

Adicionar botão **+ Adicionar tamanho**.

Não utilizar um conjunto de tamanhos obrigatório ou fixo.

A quantidade deve ser um número inteiro positivo.

Não permitir salvar linhas sem tamanho ou com quantidades inválidas.

### 6.1. Campos calculados da cor

Abaixo da listagem de tamanhos, exibir os campos somente para leitura:

**Total de peças da cor**

Soma das quantidades de todos os tamanhos daquela cor.

**Valor total da cor**

Total de peças da cor multiplicado pelo valor unitário informado na Etapa 1.

Exemplo:

- Cor: Cinza
- Total de peças: 106
- Valor unitário: R$ 1,30
- Total da cor: R$ 137,80

Esses campos devem ser recalculados imediatamente sempre que uma quantidade for adicionada, editada ou removida.

### 6.2. Botões da segunda etapa

Disponibilizar:

**Voltar**

Retorna à primeira etapa, mantendo todos os dados preenchidos.

**Próxima cor**

1. Valida a cor atual.
2. Adiciona a cor ao cadastro temporário da nota.
3. Abre um novo formulário vazio para cadastrar outra cor.
4. Mantém a referência e o preço unitário informados na primeira etapa.
5. Preserva todas as cores já cadastradas.

**Salvar**

1. Valida a cor atual.
2. Adiciona a última cor ao conjunto de dados.
3. Valida a nota completa.
4. Persiste a nota, as cores e todos os tamanhos no SQLite, em uma transação.
5. Exibe uma confirmação de sucesso.
6. Retorna à listagem de notas.

Se a transação falhar, não deixar registros parciais no banco.

### 6.3. Visualização das cores durante o cadastro

Na segunda etapa, mostrar também as cores já adicionadas, preferencialmente em pequenos cards.

Exemplo:

- Cinza — 106 peças — R$ 137,80
- Bege — 81 peças — R$ 105,30

Permitir editar ou remover uma cor já adicionada antes de finalizar a nota.

Exibir no rodapé um resumo atualizado:

- Total de cores.
- Total geral de peças.
- Valor total da nota.

Evitar perder o estado do formulário ao navegar entre cores ou etapas.

Se o usuário tentar cancelar um cadastro com dados preenchidos, solicitar confirmação para descartar as alterações.

## 7. Regras de cálculo

O preço unitário deve ser único para todos os itens de uma mesma nota.

### Total de peças de uma cor

`totalPecasCor = soma(quantidadesDosTamanhos)`

### Valor total da cor

`valorTotalCor = totalPecasCor * valorUnitario`

### Quantidade total da nota

`totalPecasNota = soma(totalPecasCor de todas as cores)`

### Valor total da nota

`valorTotalNota = soma(valorTotalCor de todas as cores)`

O cálculo do total geral deve ser realizado pela soma dos valores de cada cor.

Para evitar erros de precisão monetária, armazenar o valor unitário em centavos, como número inteiro.

Por exemplo:

R$ 1,30 deve ser armazenado como `130`.

Formatar os valores para apresentação usando o padrão `pt_BR`, com símbolo R$, vírgula decimal e duas casas.

Todas as operações de cálculo devem ser centralizadas em uma camada de domínio ou serviço reutilizável. Não duplicar a lógica entre telas, banco e PDF.

## 8. Listagem de notas

Ao acessar o item **Notas** do menu principal, exibir todos os registros salvos.

Ordenação obrigatória:

`ORDER BY created_at DESC, id DESC`

Ou seja, as notas mais recentes devem aparecer primeiro.

Cada registro deve aparecer em um card, contendo:

**Referência: 15787**

- Total de cores: 2
- Total de peças: 187
- Valor total: R$ 243,10
- Data de criação: 08/11/2026

A referência deve ser o principal identificador visual da nota.

Cada card deve permitir:

- Visualizar.
- Editar.
- Excluir.
- Gerar PDF.

Pode utilizar um menu de três pontos para concentrar essas ações.

A listagem precisa atualizar automaticamente após cadastro, edição ou exclusão.

Quando não houver notas, mostrar um estado vazio amigável e uma ação para cadastrar a primeira nota.

## 9. Visualização de detalhes

Ao abrir uma nota, mostrar:

- Referência.
- Valor unitário.
- Data de criação.
- Todas as cores cadastradas.
- Tamanhos e quantidades de cada cor.
- Total de peças por cor.
- Valor total por cor.
- Quantidade total de peças da nota.
- Valor total da nota.

As cores devem aparecer separadas em cards ou seções expansíveis.

Os totais devem estar visualmente destacados, mas não editáveis.

Disponibilizar ações para editar e gerar PDF.

## 10. Edição de notas

Permitir editar uma nota salva anteriormente.

A edição deve possibilitar:

- Alterar a referência.
- Alterar o preço unitário.
- Alterar o nome de uma cor.
- Adicionar novas cores.
- Excluir cores existentes.
- Adicionar tamanhos a uma cor.
- Alterar tamanhos.
- Alterar quantidades.
- Remover tamanhos.

Ao alterar o valor unitário da nota, todos os subtotais e o valor geral devem ser recalculados.

Ao alterar uma quantidade, atualizar automaticamente todos os totais relacionados.

A edição deve carregar os dados existentes e preservar seus IDs internos quando aplicável.

Ao salvar, realizar a atualização em transação.

Se o usuário cancelar, nenhuma alteração não salva deverá modificar a nota persistida.

Não permitir salvar uma nota sem pelo menos uma cor válida contendo um tamanho válido.

## 11. Exclusão de notas

Implementar exclusão física.

Ao excluir uma nota, eliminar definitivamente:

- A nota.
- Suas cores.
- Todos os tamanhos e quantidades relacionados.

Nunca utilizar campos `deleted_at`, `is_deleted` ou lógica de soft delete.

Antes da exclusão, mostrar um diálogo de confirmação.

Exemplo:

"Excluir a nota de referência 15787? Esta ação é permanente e não poderá ser desfeita."

Após confirmar, executar a exclusão e atualizar a interface.

## 12. Seleção em massa

Na tela de listagem, implementar um modo de seleção múltipla.

O usuário poderá ativá-lo por um botão **Selecionar** ou por um toque longo sobre uma nota.

Quando o modo estiver ativo:

- Exibir checkbox em cada card.
- Permitir selecionar ou desmarcar notas individualmente.
- Mostrar a quantidade de notas selecionadas.
- Disponibilizar **Selecionar todas**.
- Disponibilizar **Desmarcar todas**.
- Disponibilizar **Cancelar seleção**.

Com notas selecionadas, disponibilizar duas ações principais:

**Excluir selecionadas**

Mostrar confirmação contendo a quantidade de notas que serão excluídas.

Executar a exclusão física das notas selecionadas e seus relacionamentos de forma transacional.

**Gerar PDF das selecionadas**

Gerar um único arquivo PDF contendo todas as notas selecionadas.

Cada nota deve começar em uma nova página.

Se uma nota ocupar mais de uma página, permitir a continuação nas páginas seguintes.

Preservar a ordem apresentada na listagem.

Não misturar valores, cores ou totais de notas diferentes.

Não realizar uma soma geral entre notas diferentes.

Desabilitar as ações de lote quando nenhuma nota estiver selecionada.

## 13. Geração de PDF

A geração de PDF é uma funcionalidade essencial.

Utilizar a primeira imagem fornecida como referência de organização visual.

O documento não precisa reproduzir o aspecto manuscrito da folha. Ele deve reproduzir a mesma **estrutura de informações**, com um visual limpo e profissional.

### 13.1. Cabeçalho

No início do PDF:

**Referência: 15787**

**Valor por peça: R$ 1,30**

Exibir esses dois dados em destaque.

Usar formato A4, preferencialmente retrato.

### 13.2. Organização por cores

Reproduzir a organização de colunas da primeira imagem.

Sempre que couberem duas cores lado a lado, apresentar dois conjuntos de colunas.

Exemplo:

| Cor | Tamanho | Peças | Cor | Tamanho | Peças |
|---|---|---|---|---|---|
| Cinza | 1 | 12 | Bege | 1 | 12 |
| | 2 | 12 | | 2 | 12 |
| | 3 | 16 | | 3 | 12 |
| | 4 | 16 | | 4 | 4 |
| | 6 | 15 | | 6 | 6 |
| | 8 | 16 | | 8 | 16 |
| | 10 | 11 | | 10 | 12 |
| | 12 | 8 | | 12 | 7 |
| **Total** | | **106** | **Total** | | **81** |

Abaixo de cada cor, apresentar também seu subtotal financeiro:

- Cinza: R$ 137,80.
- Bege: R$ 105,30.

Se houver mais de duas cores, continuar com novos conjuntos de duas cores abaixo dos anteriores ou nas páginas seguintes.

Se houver uma quantidade ímpar de cores, a última deve ocupar apenas seu espaço, sem criar uma cor fictícia.

Não limitar a quantidade de tamanhos ou cores.

Os tamanhos devem aparecer na ordem em que foram cadastrados.

Evitar cortar tabelas ou totais nas mudanças de página.

### 13.3. Rodapé da nota

Ao final de todas as cores, exibir:

**Total de peças: 187**

**Valor total da nota: R$ 243,10**

Os totais devem ser calculados a partir dos dados reais, não de valores armazenados previamente.

### 13.4. Ações com PDF

Permitir:

- Gerar PDF de uma nota individual.
- Visualizar o PDF antes de compartilhar.
- Compartilhar PDF com outros aplicativos.
- Imprimir pelo sistema operacional.
- Gerar um PDF único de múltiplas notas selecionadas.

Utilizar nomes de arquivo previsíveis, por exemplo:

`nota_15787.pdf`

`minhas_notas_20261108_143000.pdf`

Sanitizar caracteres inválidos dos nomes de arquivos.

O PDF deve ser gerado sob demanda com os dados atualizados do SQLite.

Não é necessário armazenar permanentemente cópias de todos os PDFs no banco de dados.

## 14. Arquitetura do projeto

Criar uma estrutura simples e organizada.

Sugestão:

```text
lib/
  main.dart
  app.dart

  core/
    database/
      app_database.dart
    utils/
      currency_utils.dart
    theme/
      app_theme.dart

  models/
    note.dart
    note_color.dart
    color_size.dart

  repositories/
    note_repository.dart

  services/
    note_calculation_service.dart
    pdf_service.dart

  screens/
    home_screen.dart
    notes_list_screen.dart
    note_form_screen.dart
    note_details_screen.dart
    pdf_preview_screen.dart

  widgets/
    note_card.dart
    color_form.dart
    size_quantity_row.dart
    note_summary.dart
```

Essa estrutura pode ser adaptada caso exista uma opção mais adequada, mas deve manter separação entre interface, persistência e regras de negócio.

Evitar arquiteturas excessivamente complexas e bibliotecas desnecessárias.

Utilizar componentes reutilizáveis.

## 15. Tratamento de erros e validações

Implementar validações para:

- Referência vazia.
- Preço unitário inválido.
- Quantidade negativa ou zero.
- Tamanho vazio.
- Cor vazia.
- Nome de cor duplicado na mesma nota.
- Tamanho duplicado na mesma cor.
- Nota sem cores.
- Cor sem tamanhos.
- Tentativa de salvar registros incompletos.
- Falha no acesso ao SQLite.
- Falha na geração do PDF.
- Exclusão de registros já removidos.
- Saída de formulários com alterações não salvas.

Mostrar mensagens claras em português brasileiro.

Durante operações de gravação, exclusão e geração de PDF, utilizar estados de carregamento para evitar ações duplicadas.

Garantir que a interface não fique bloqueada permanentemente após uma falha.

## 16. Casos de teste obrigatórios

### Cenário A — Primeira imagem

Criar uma nota com os seguintes dados.

Referência: `15787`

Valor unitário: R$ 1,30

**Cor Cinza:**

| Tamanho | Quantidade |
|---|---|
| 1 | 12 |
| 2 | 12 |
| 3 | 16 |
| 4 | 16 |
| 6 | 15 |
| 8 | 16 |
| 10 | 11 |
| 12 | 8 |

Resultado esperado:

- Total Cinza: 106 peças.
- Valor Cinza: R$ 137,80.

**Cor Bege:**

| Tamanho | Quantidade |
|---|---|
| 1 | 12 |
| 2 | 12 |
| 3 | 12 |
| 4 | 4 |
| 6 | 6 |
| 8 | 16 |
| 10 | 12 |
| 12 | 7 |

Resultado esperado:

- Total Bege: 81 peças.
- Valor Bege: R$ 105,30.

**Resultado esperado da nota:**

- Total de cores: 2.
- Total de peças: 187.
- Valor total: R$ 243,10.

O PDF gerado deve apresentar as duas cores lado a lado, seguindo o exemplo da primeira imagem.

### Cenário B — Segunda imagem

Referência: `50353`

Valor unitário: R$ 1,40.

Cor Cinza: 64 peças.

Cor Azul: 72 peças.

Resultado esperado:

- Total: 136 peças.
- Valor total: R$ 190,40.

### Cenário C — Tamanhos alfanuméricos

Criar uma nota com uma cor e tamanhos `P`, `M`, `G`, `GG`.

Verificar inserção, edição, persistência no SQLite e apresentação no PDF.

### Cenário D — Edição e recálculo

Editar uma nota existente, alterando o preço unitário e a quantidade de um tamanho.

Verificar se todos os subtotais e o total geral foram recalculados corretamente.

### Cenário E — Exclusão em lote

Selecionar duas ou mais notas e excluí-las.

Verificar se todos os registros correspondentes foram removidos fisicamente, inclusive nas tabelas relacionadas.

### Cenário F — PDF em lote

Selecionar duas ou mais notas e gerar PDF.

Verificar que:

- Existe um único arquivo.
- Cada nota começa em uma nova página.
- Nenhuma cor pertence à nota errada.
- Todos os totais estão corretos.

### Cenário G — Persistência e ordenação

Cadastrar duas notas, fechar o aplicativo e abri-lo novamente.

Verificar que os dados permanecem salvos e que a nota criada mais recentemente aparece primeiro.

Editar a nota mais antiga e verificar que ela mantém sua posição de criação na listagem.

## 17. Testes automatizados e qualidade

Implementar testes unitários para:

- Cálculo de peças por cor.
- Cálculo de valores por cor.
- Cálculo do total geral.
- Conversão e formatação monetária.
- Validações de tamanhos, cores e quantidades.

Implementar testes de persistência para:

- Inserção de nota e relacionamentos.
- Recuperação de nota completa.
- Atualização.
- Exclusão em cascata.
- Transações e rollback.
- Ordenação por data de criação.

Criar testes de interface para os principais fluxos, quando viável.

Validar a geração de documentos PDF com dados de exemplo.

Executar:

```bash
flutter pub get
dart format .
flutter analyze
flutter test
```

Corrigir os problemas encontrados antes de considerar o projeto concluído.

Não considerar a tarefa finalizada apenas porque o projeto compila.

## 18. Entrega esperada

Quero que você implemente o aplicativo completo, não apenas um protótipo visual.

A entrega deverá conter:

1. Código-fonte Flutter funcional.
2. Banco SQLite e operações CRUD implementadas.
3. Cadastro em duas etapas funcionando.
4. Cadastro de N cores e N tamanhos por cor.
5. Totais calculados automaticamente.
6. Listagem ordenada por criação.
7. Visualização e edição de notas.
8. Exclusão física individual e em lote.
9. Seleção múltipla.
10. Geração de PDF individual e em lote.
11. Ícone próprio do aplicativo.
12. Testes automatizados.
13. `README.md` explicando configuração, execução, build e arquitetura.

Criar a estrutura do projeto se ainda não existir.

Se já houver um projeto Flutter no diretório, verificar seu conteúdo antes de alterar qualquer arquivo.

Não utilizar dados fictícios na versão final da aplicação. Os exemplos especificados devem ser utilizados nos testes, não inseridos automaticamente nas notas do usuário.

O aplicativo deve iniciar com o banco vazio em uma instalação nova.

### Critérios finais de aceite

A implementação estará concluída quando for possível:

- Abrir o aplicativo e acessar Notas.
- Criar uma nota informando uma única referência e preço unitário.
- Cadastrar várias cores em sequência, cada uma com seus tamanhos e quantidades.
- Finalizar o cadastro e visualizar a nota na listagem.
- Fechar e reabrir o aplicativo sem perder os dados.
- Editar completamente a nota.
- Excluir uma nota definitivamente.
- Selecionar várias notas e excluí-las em lote.
- Gerar PDF individual no formato da primeira imagem.
- Selecionar várias notas e gerar um PDF consolidado.
- Obter os resultados exatos dos cenários de cálculo.

**Orientação final:** implemente de ponta a ponta, priorizando simplicidade de uso, correção dos cálculos, integridade dos dados e fidelidade do layout dos PDFs. Não deixe botões sem funcionalidade, métodos simulados ou funcionalidades essenciais marcadas como TODO.

Ao finalizar, informe quais arquivos foram criados, quais testes foram executados e quais limitações reais permaneceram, se houver.
