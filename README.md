# Teste Técnico — Analytics Engineer


## Diagnóstico

A análise do projeto foi feita considerando três dimensões principais: confiabilidade dos dados, custo de processamento e capacidade de uso analítico (incluindo uso por IA). Abaixo estão os principais problemas identificados, ordenados por criticidade.

---

### 🔴 1. Join com `IN UNNEST` gerando alto custo e duplicidade

**O que está errado**

O modelo `revenue_report` realiza o join entre transações e settlements utilizando:

```sql
t.transaction_id IN UNNEST(s.transaction_ids)
```

Esse padrão é problemático porque:

* Realiza leitura de arrays linha a linha
* Pode gerar múltiplas correspondências para a mesma transação
* Não garante controle sobre o número de registros gerados

**Por que é um problema real**

Esse tipo de join é conhecido por ser custoso no BigQuery, principalmente em grandes volumes. Além disso, pode multiplicar linhas silenciosamente, o que impacta diretamente métricas agregadas.

**Impacto**

* Aumento significativo de custo de processamento (explicando o aumento da conta do BigQuery)
* Duplicidade de registros
* Métricas inconsistentes (ex: receita inflada ou distorcida)

**Como corrigir**

* Normalizar a tabela de settlements em um modelo intermediário (`UNNEST` separado)
* Garantir uma linha por `transaction_id`
* Substituir o join por igualdade simples (`=`)

---

### 🔴 2. Uso de `ROW_NUMBER` para mascarar problema de duplicidade

**O que está errado**

Após o join com settlements, o modelo utiliza:

```sql
ROW_NUMBER() OVER (
  PARTITION BY transaction_id
  ORDER BY settlement_date DESC
) as rn
QUALIFY rn = 1
```

Isso não resolve o problema de duplicidade, apenas seleciona arbitrariamente uma linha.

**Por que é um problema real**

Se uma transação tiver múltiplos settlements válidos, o modelo descarta informações sem critério de negócio claro.

**Impacto**

* Perda de dados relevantes
* Inconsistência nas métricas
* Falta de rastreabilidade (difícil explicar divergências)

**Como corrigir**

* Remover o `ROW_NUMBER` do mart final (`revenue_report`) e resolver a duplicidade antes, na camada intermediate
* Definir regra clara de negócio para a deduplicação (ex: escolher o settlement mais recente/pago)
* Garantir grain consistente antes do mart (ex: 1 linha por `transaction_id`)

---

### 🔴 3. Ausência de testes e validações de dados

**O que está errado**

O projeto não possui testes no `schema.yml`, como:

* `not_null`
* `unique`
* `relationships`

**Por que é um problema real**

Sem testes, erros como duplicidade, nulos ou joins incorretos passam despercebidos.

**Impacto**

* Baixa confiabilidade dos dados
* Risco direto para decisões de negócio
* Dificuldade de escalar o uso dos dados

**Como corrigir**

* Implementar testes básicos em todas as chaves e métricas
* Garantir integridade referencial entre tabelas
* Adicionar testes de regra de negócio (ex: valores negativos indevidos)

---

### 🟠 4. Staging não cumpre seu papel de padronização

**O que está errado**

O modelo `stg_transactions`:

* Não faz cast de tipos
* Não padroniza nomenclatura
* Apenas replica a source com pequena transformação

**Por que é um problema real**

Problemas da camada bruta são propagados para toda a modelagem.

**Impacto**

* Inconsistência entre ambientes
* Dificuldade de manutenção
* Aumento de erros em modelos downstream

**Como corrigir**

* Aplicar casts explícitos
* Padronizar nomes de colunas
* Documentar regras de limpeza (ex: exclusão de status `test`)

---

### 🟠 5. Uso de `CURRENT_TIMESTAMP()` no staging

**O que está errado**

O campo `loaded_at` é gerado com `CURRENT_TIMESTAMP()` a cada execução.

**Por que é um problema real**

Mesmo sem alteração nos dados, a tabela muda a cada execução.

**Impacto**

* Quebra de reprodutibilidade
* Dificulta uso de incremental
* Pode gerar reprocessamento desnecessário

**Como corrigir**

* Remover ou substituir por campo confiável da origem
* Utilizar controle de carga consistente

---

### 🟠 6. Materialização como tabela sem estratégia incremental

**O que está errado**

Os modelos são materializados como `table`, sem controle incremental.

**Por que é um problema real**

Tabelas grandes serão reprocessadas completamente a cada execução.

**Impacto**

* Alto custo no BigQuery
* Tempo elevado de execução
* Baixa escalabilidade

**Como corrigir**

* Implementar materialização incremental nos fatos
* Utilizar filtros por `updated_at` ou partições

---

### 🟡 7. Falta de definição clara de grain

**O que está errado**

O modelo `revenue_report` não documenta seu nível de granularidade e depende de `ROW_NUMBER` para garantir unicidade.

**Por que é um problema real**

Analistas e sistemas (como IA) podem agregar dados incorretamente.

**Impacto**

* Erros em análises
* Métricas inconsistentes
* Ambiguidade no uso dos dados

**Como corrigir**

* Definir explicitamente o grain (ex: 1 linha por transaction_id)
* Garantir isso na modelagem, não via workaround

---

### 🟡 8. Métricas com semântica ambígua

**O que está errado**

A métrica `revenue_impact` mistura conceitos de:

* volume transacionado
* impacto de chargeback/refund

Sem distinção clara de métricas como:

* receita de taxa
* volume bruto
* valor líquido

**Por que é um problema real**

Usuários podem interpretar métricas incorretamente.

**Impacto**

* Decisões erradas
* Dificuldade de uso por IA (ambiguidade semântica)

**Como corrigir**

* Separar métricas por conceito
* Documentar claramente cada uma
* Padronizar nomenclatura

---

### 🟡 9. Schema.yml pouco informativo

**O que está errado**

O arquivo contém apenas descrições superficiais e não documenta colunas nem regras.

**Por que é um problema real**

Não fornece contexto suficiente para analistas ou sistemas automatizados.

**Impacto**

* Baixa usabilidade
* Dificuldade para onboarding
* Limitação para uso por IA

**Como corrigir**

* Documentar colunas
* Adicionar meta tags semânticas
* Incluir descrições orientadas a negócio

---

## Refatoração seletiva

Para a implementação em código, priorizei os três problemas com maior impacto combinado em confiabilidade, custo e capacidade de evolução do projeto:

1. Join com `IN UNNEST` no `revenue_report`
2. Duplicidade resolvida apenas com `ROW_NUMBER` no mart final
3. Ausência de testes e documentação no `schema.yml`

Escolhi esses três porque eles atacam diretamente as dores descritas no case:

- os números não batem
- o custo do BigQuery aumentou
- o time quer preparar a base para consumo por IA

Outros pontos também são relevantes, como incrementalidade e maior enriquecimento semântico, mas preferi concentrar a refatoração inicial naquilo que melhora a estrutura central do pipeline e reduz o risco de inconsistência analítica.

## Processo de abordagem

A abordagem adotada começou pela leitura completa do projeto legado, com foco em entender o fluxo de dados ponta a ponta.

Inicialmente, busquei responder três perguntas principais:

* Por que os números não batem?
* O que pode estar gerando aumento de custo?
* O que impede esse modelo de ser utilizado por IA?

A partir dessa análise, identifiquei padrões problemáticos como:

* joins com `IN UNNEST`
* uso de `ROW_NUMBER` para mascarar duplicidade
* ausência de testes e documentação

A priorização foi guiada pelo impacto direto no negócio, considerando:

1. confiabilidade dos dados
2. custo de processamento
3. clareza semântica

---

## Principais decisões de modelagem

### Refatoração do modelo `revenue_report`

Optei por refatorar o modelo existente `revenue_report` em vez de criar um novo modelo factual.

A decisão foi tomada para:

* evitar aumento desnecessário de complexidade
* manter continuidade com o modelo existente
* focar na correção dos problemas estruturais

A refatoração transformou o modelo em uma tabela fato confiável, com:

* grain definido (uma linha por `transaction_id`)
* remoção do join com `IN UNNEST`
* deduplicação tratada na camada intermediate
* separação clara entre staging, intermediate e mart

---

### Separação por camadas

A modelagem foi reorganizada em três níveis:

* staging: padronização dos dados
* intermediate: regras de relacionamento e deduplicação
* mart: camada final de consumo

Essa separação melhora a legibilidade, manutenção e confiabilidade do pipeline.

---

### Normalização de settlements

O relacionamento entre transações e settlements foi reestruturado, removendo o uso de `IN UNNEST` no modelo final.

A normalização permitiu:

* reduzir custo computacional
* tornar o join determinístico
* controlar corretamente a duplicidade

---

## Uso de IA

A IA foi utilizada como ferramenta de apoio ao longo do processo, principalmente para:

### Estruturação inicial

Auxiliou na identificação de padrões problemáticos e organização das ideias, mas todas as conclusões foram validadas manualmente.

### Refatoração

Ajudou na geração inicial de estruturas de modelos, mas foi necessário ajustar:

* definição correta de grain
* controle de duplicidade
* regras de negócio implícitas

### Camada semântica

A IA contribuiu na organização da documentação, porém foi necessário refinar manualmente:

* distinção entre métricas
* uso correto dos modelos
* identificação de armadilhas reais

### Limitações observadas

A IA mostrou limitações principalmente em:

* entender impacto real de duplicidade
* interpretar regras de negócio
* priorizar corretamente os problemas

Por isso, todas as decisões finais foram baseadas em análise crítica.

---

## O que faria com mais tempo

Se tivesse mais tempo, priorizaria os seguintes pontos:

### 1. Incrementalidade

Implementaria materialização incremental no modelo factual para reduzir custo e melhorar performance.

### 2. Testes de negócio

Adicionaria validações mais avançadas, como:

* consistência de taxas
* comportamento esperado de chargebacks
* validações temporais

### 3. Governança de métricas

Criaria uma camada formal de métricas com definições claras e centralizadas.

### 4. Evolução da camada semântica

Expandiria o mapeamento de linguagem natural e criaria um dicionário de negócio mais completo.

### 5. Observabilidade

Implementaria monitoramento de qualidade e alertas de falha.

### 6. Otimização de custo

Analisaria estratégias de particionamento, clustering e redução de leitura desnecessária.

---

## Conclusão

A refatoração priorizou a correção de problemas estruturais críticos, mantendo o projeto simples e evolutivo.

O resultado é uma base mais confiável, com menor custo operacional e preparada para consumo analítico e por IA.
