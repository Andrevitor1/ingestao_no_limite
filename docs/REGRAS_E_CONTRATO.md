# 📄 Regras de Negócio e Contrato de Dados

Para sua submissão ser **classificada**, a tabela final no PostgreSQL deve cumprir rigorosamente o schema abaixo e **zerar todas as métricas de erro** do Juiz Automático.

As queries executadas pelo juiz estão em [`evaluator/judge/sql/gates/`](../evaluator/judge/sql/gates/) e [`evaluator/judge/sql/metrics/`](../evaluator/judge/sql/metrics/).

---

## 1. Origem dos Dados

* Diretório de dados brutos no container: `/data/`
* Múltiplos arquivos compactados (`.zip`)
* Extensão interna: arquivos do tipo `.EMPRECSV` (ex: `K3241.K03200Y0.D60613.EMPRECSV`)
* Codificação original: `ISO-8859-1` (Latin-1) ➔ deve ser convertido para `UTF-8`
* Separador: `;` (ponto e vírgula) com aspas duplas `"`. Sem cabeçalho

---

## 2. Destino Final (Obrigatório)

| Item | Valor |
| :--- | :--- |
| Banco | `db_empresas` |
| Schema | `public` |
| Tabela | `{participante}_empresas` |
| Exemplo | participante `renan_python` → `public.renan_python_empresas` |
| Hífen no ID | Permitido (ex.: `dataforma-hub`). Ao criar a tabela no SQL/client, use identificador entre aspas: `public."dataforma-hub_empresas"` — senão o Postgres interpreta `-` como minus. |

A tabela deve existir e estar populada ao final da execução do container.

### Uso opcional de object storage S3-compatível

Você pode usar storage S3-compatível (na avaliação: MinIO dockerizado como alvo de laboratório) livremente para staging ou formatos intermediários (Parquet, Delta Lake, Iceberg), desde que:

* Use apenas o prefixo `s3://marketing-leads/{participante}/`
* A tabela final em Postgres permaneça a **fonte de verdade** para validação e BI
* Projete o código contra a **API S3 genérica** — não acople à marca MinIO; em produção, escolha o backend S3 que fizer sentido para o seu contexto (ver [licença e alternativas](./STACK_E_LIMITES.md#-object-storage-s3-compatível-opcional))

---

## 3. Schema da Tabela Final

| Coluna | Tipo Postgres | Regra de Transformação |
| :--- | :--- | :--- |
| `cnpj_basico` | `VARCHAR(8)` | Exatamente 8 dígitos numéricos com zeros à esquerda |
| `razao_social` | `VARCHAR` | Uppercase, sem espaços nas extremidades |
| `natureza_juridica` | `VARCHAR(4)` | Código numérico de 4 dígitos |
| `qualificacao_responsavel` | `VARCHAR` | Código de qualificação (NOT NULL) |
| `capital_social` | `DOUBLE PRECISION` | Vírgula BR → ponto (`5000.00`) |
| `porte_codigo` | `VARCHAR(2)` | `"00"`, `"01"`, `"03"` ou `"05"` |
| `porte_descricao` | `VARCHAR` | Mapeamento: `00`→`NÃO INFORMADO`, `01`→`MICRO EMPRESA`, `03`→`EMPRESA DE PEQUENO PORTE`, `05`→`DEMAIS` |
| `ente_federativo` | `VARCHAR` | Strings vazias `""` → `NULL` |

---

## 4. Data Quality (Gates)

Todas as regras abaixo devem ter **0 erros**. Qualquer valor acima de zero reprova a submissão.

| Gate | Regra | Tolerância |
| :--- | :--- | :--- |
| DQ-01 | `cnpj_basico` com exatamente 8 dígitos numéricos | **0** |
| DQ-02 | `razao_social` em UPPER e sem espaços nas extremidades | **0** |
| DQ-03 | `natureza_juridica` com 4 dígitos | **0** |
| DQ-04 | `qualificacao_responsavel` preenchido (NOT NULL) | **0** |
| DQ-05 | `capital_social` maior que `1000.00` e não nulo | **0** |
| DQ-06 | `porte_codigo` em `00`, `01`, `03` ou `05` | **0** |
| DQ-07 | `porte_descricao` com valor do mapeamento oficial | **0** |
| DQ-08 | `razao_social` não termina com 11 dígitos (CPF de MEI) | **0** |

Arquivos SQL por gate: `evaluator/judge/sql/gates/dq-01_*.sql` … `dq-08_*.sql`  
Validação manual de todos: `evaluator/judge/sql/gates/run_all_dq_manual.sql`

---

## 5. Filtros de Negócio B2B

1. **Capital Social Mínimo:** apenas empresas com `capital_social > 1000.00`
2. **Filtro de MEI com CPF:** remover registros onde `razao_social` termina com 11 dígitos numéricos (CPF do titular)

---

## 6. Sanidade de Volume

A tabela final não pode estar vazia nem fora da faixa esperada para o dataset oficial.

| Situação | Status |
| :--- | :--- |
| Zero registros | `ERRO_TABELA_VAZIA` |
| Abaixo do mínimo | `ERRO_POUCOS_REGISTROS` |
| Acima do máximo | `ERRO_REGISTROS_DEMAIS` |
| Dentro da faixa | aprovado |

Os limites exatos (`limite_min`, `limite_max`) são configurados no servidor em `evaluator/judge/config.env` e no script `evaluator/judge/sql/metrics/volume_sanity.sql`.
