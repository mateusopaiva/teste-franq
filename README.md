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

* Resolver duplicidade na origem (modelo intermediate)
* Definir regra clara de negócio (ex: settlement mais recente, settlement pago, etc.)
* Garantir grain consistente antes do mart

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

## Priorização

Os três problemas escolhidos para refatoração foram:

1. Join com `IN UNNEST` (impacto direto em custo e duplicidade)
2. Uso de `ROW_NUMBER` mascarando inconsistência
3. Ausência de testes e documentação

Esses pontos foram priorizados por afetarem diretamente:

* Confiabilidade dos dados
* Custo de infraestrutura
* Capacidade de uso analítico e por IA
