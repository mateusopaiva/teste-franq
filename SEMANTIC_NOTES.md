# SEMANTIC_NOTES

## Objetivo

Esta documentação descreve como os modelos refatorados podem ser usados por um agente de IA para responder perguntas de negócio com menor risco de ambiguidade semântica.

A principal preocupação desta camada é deixar explícitos:

* o grain de cada modelo
* a diferença entre métricas parecidas
* a dimensão temporal correta para cada tipo de pergunta
* quais modelos são adequados para consulta final e quais são apenas modelos técnicos

---

## Princípios desta camada semântica

* O modelo `revenue_report` deve ser utilizado como padrão para perguntas transacionais
* O campo `transaction_date` é a dimensão principal de tempo
* Métricas de volume, taxa e impacto de receita possuem significados distintos e não devem ser confundidas
* Modelos agregados, como `merchant_summary`, devem ser usados apenas para análises já consolidadas

---

## Modelos principais para consumo por IA

### 1. `revenue_report`

**Grain:** uma linha por `transaction_id`

Esse é o principal modelo factual para perguntas transacionais e análises com filtro por tempo, merchant e método de pagamento.

**Perguntas que esse modelo consegue responder bem**

* Qual o volume de transações Pix do merchant X no último mês?
* Quanto foi transacionado por merchant em determinado período?
* Quanto a empresa faturou em taxas na última semana?
* Quantas transações possuem status chargeback em determinado intervalo?
* Qual o impacto de refunds e chargebacks na receita?

**Métricas importantes**

* `amount_brl`: volume bruto transacionado
* `fee_amount_brl`: faturamento em taxas
* `revenue_impact_brl`: impacto líquido da transação considerando refund e chargeback como negativos

**Dimensão temporal preferencial**

* `transaction_date`

**Cuidados**

* `amount_brl` não deve ser usado para responder perguntas sobre faturamento em taxas
* `fee_amount_brl` não deve ser interpretado como volume transacionado
* `settlement_date` só deve ser usado quando a pergunta for explicitamente sobre liquidação
* `updated_at` é técnico e não deve ser a dimensão principal de negócio

---

### 2. `merchant_summary`

**Grain:** uma linha por `merchant_id`

Esse modelo é mais adequado para rankings e comparações entre merchants, pois já está agregado.

**Perguntas que esse modelo consegue responder bem**

* Quais merchants tiveram taxa de chargeback acima de 2% neste trimestre?
* Quais merchants mais faturaram em taxas?
* Quais merchants tiveram maior volume de receita impactada?
* Quais merchants possuem maior número de chargebacks?

**Métricas importantes**

* `total_transactions`
* `total_revenue_brl`
* `total_fees_brl`
* `chargeback_rate`

**Cuidados**

* Como o modelo já está agregado por merchant, ele não é adequado para análises temporais detalhadas por dia
* `chargeback_rate` já é uma taxa calculada e não deve ser agregada novamente
* Para perguntas com filtro transacional detalhado, o modelo correto é `revenue_report`

---

## Armadilhas que um agente de IA cometeria sem orientação

### 1. Confundir volume transacionado com faturamento em taxas

Um agente pode usar `amount_brl` para responder "quanto a empresa faturou em taxas na última semana".

**Problema**

* `amount_brl` representa valor bruto da transação
* `fee_amount_brl` representa a taxa

**Como prevenir**

* Diferenciação clara entre métricas no schema
* Uso de sinônimos alinhando "taxas" com `fee_amount_brl`
* Documentação explícita indicando o uso correto de cada métrica

---

### 2. Usar o modelo agregado para perguntas transacionais

Um agente pode consultar `merchant_summary` para responder perguntas como:

* "Qual o volume Pix do merchant X no último mês?"

**Problema**

* `merchant_summary` não tem granularidade transacional nem método de pagamento por linha

**Como prevenir**

* O grain dos modelos deixa explícito o nível de agregação
* As descrições indicam que `revenue_report` é o modelo principal para análises transacionais

---

### 3. Usar a dimensão temporal errada

Um agente pode filtrar por `settlement_date` quando a pergunta do usuário estiver claramente falando de transações.

**Problema**

* Isso altera o significado da análise

**Como prevenir**

* Definição clara de `transaction_date` como dimensão principal de negócio
* Documentação indicando uso específico de `settlement_date`

---

### 4. Agregar indevidamente uma métrica que já é taxa

Um agente pode somar `chargeback_rate` em vez de filtrar ou comparar o valor.

**Problema**

* Taxas agregadas por soma perdem significado analítico

**Como prevenir**

* Documentação deixando claro que a métrica já é calculada
* Indicação de que deve ser usada para filtro ou comparação

---

### 5. Usar modelos técnicos como se fossem modelos finais

Um agente pode consultar `stg_settlements` diretamente sem considerar que ali ainda pode existir mais de um settlement por transação.

**Problema**

* Risco de duplicidade e métricas incorretas

**Como prevenir**

* Diferenciação clara entre camadas (staging, intermediate e mart)
* Indicação de que modelos factuais devem ser priorizados

---

## Mapeamento de linguagem natural para métricas

* "volume", "valor transacionado", "tpv" → `amount_brl`
* "taxas", "faturamento em taxas", "fee revenue" → `fee_amount_brl`
* "impacto na receita", "receita líquida" → `revenue_impact_brl`

---

## O que ainda falta para uma camada semântica completa

Apesar da melhoria desta entrega, ainda faltariam alguns elementos para considerar a camada realmente pronta para consumo robusto por IA:

### 1. Catálogo formal de métricas

* Definição oficial
* Fórmula
* Responsável pela métrica
* Exemplos de uso

### 2. Dicionário mais completo de linguagem de negócio

* Sinônimos mais amplos
* Termos usados por diferentes áreas

### 3. Regras temporais padronizadas

* Definição de "última semana", "último mês", etc.
* Timezone padrão
* Definição de calendário

### 4. Camada semântica dedicada

* Modelos semânticos formais
* Métricas governadas
* Contratos de dados

### 5. Testes de negócio mais robustos

* Validação de métricas
* Regras de consistência
* Monitoramento contínuo

### 6. Exemplos de SQL canônico

* Queries aprovadas para perguntas frequentes
* Redução de ambiguidade na geração de SQL

---

## Conclusão

A refatoração e o enriquecimento semântico realizados tornam os modelos mais confiáveis e utilizáveis por um agente de IA, principalmente por:

* explicitar o grain
* diferenciar métricas com significados próximos
* indicar o modelo correto para cada tipo de pergunta
* reduzir ambiguidades de tempo, agregação e interpretação

Essa abordagem cria uma base sólida para evolução futura rumo a uma camada semântica mais governada e escalável.
