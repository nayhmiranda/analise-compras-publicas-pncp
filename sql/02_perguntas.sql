-- 02_perguntas.sql
-- As 6 perguntas de negocio da Controladoria, respondidas sobre o star schema.
-- Regras gerais: percentual = SOMA / SOMA (nunca media de percentuais).
-- A economia so conta itens comparaveis (comparavel = 1). Nos nao comparaveis, economia_valor e 0.
-- NULLIF evita divisao por zero (Credenciamento nao tem nenhum item comparavel).


-- =====================================================================================
-- PERGUNTA 1 - Economia global do Poder Publico
-- Qual o valor e o percentual economizados (estimado - homologado)?
-- =====================================================================================
SELECT
    SUM(CASE WHEN comparavel = 1 THEN valor_total_estimado   ELSE 0 END)  AS estimado_comparavel,
    SUM(CASE WHEN comparavel = 1 THEN valor_total_homologado ELSE 0 END)  AS homologado_comparavel,
    SUM(economia_valor)                                                   AS economia_reais,
    ROUND(100 * SUM(economia_valor)
          / NULLIF(SUM(CASE WHEN comparavel = 1 THEN valor_total_estimado ELSE 0 END), 0), 2) AS economia_pct,
    SUM(valor_total_homologado)                                           AS volume_homologado_total,
    COUNT(*)                                                              AS itens_na_fato,
    SUM(comparavel)                                                       AS itens_comparaveis
FROM fato_item_contratado;


-- =====================================================================================
-- PERGUNTA 2 - Concentracao e risco de fornecedores
-- Os 10 maiores fornecedores em volume e quanto do total cada um representa.
-- =====================================================================================
SELECT
    f.ni_fornecedor,
    f.nome_fornecedor,
    SUM(t.valor_total_homologado)                                                   AS volume,
    ROUND(100 * SUM(t.valor_total_homologado)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2)      AS pct_do_total
FROM fato_item_contratado t
JOIN dim_fornecedor f ON f.sk_fornecedor = t.sk_fornecedor
GROUP BY f.ni_fornecedor, f.nome_fornecedor
ORDER BY volume DESC
LIMIT 10;

-- Concentracao dos 10 maiores somados (quanto do orcamento esta nas maos deles)
WITH volume_por_fornecedor AS (
    SELECT sk_fornecedor, SUM(valor_total_homologado) AS volume
    FROM fato_item_contratado
    GROUP BY sk_fornecedor
),
top10 AS (
    SELECT volume FROM volume_por_fornecedor ORDER BY volume DESC LIMIT 10
)
SELECT
    SUM(volume)                                                                     AS volume_top10,
    ROUND(100 * SUM(volume)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2)      AS concentracao_top10_pct
FROM top10;


-- =====================================================================================
-- PERGUNTA 3 - Eficacia por modalidade
-- Qual modalidade da mais desagio (economia %) e qual concentra mais volume?
-- Em Credenciamento a economia % fica vazia (NULL): e esperado, nenhum item e comparavel.
-- =====================================================================================
SELECT
    m.nome_modalidade,
    COUNT(*)                                                                        AS itens,
    SUM(t.valor_total_homologado)                                                   AS volume,
    ROUND(100 * SUM(t.valor_total_homologado)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2)      AS pct_do_volume,
    SUM(t.economia_valor)                                                           AS economia_reais,
    ROUND(100 * SUM(t.economia_valor)
          / NULLIF(SUM(CASE WHEN t.comparavel = 1 THEN t.valor_total_estimado ELSE 0 END), 0), 2) AS economia_pct
FROM fato_item_contratado t
JOIN dim_modalidade m ON m.sk_modalidade = t.sk_modalidade
GROUP BY m.nome_modalidade
ORDER BY economia_pct DESC NULLS LAST;


-- =====================================================================================
-- PERGUNTA 4 - Tempo do ciclo de compras
-- Duracao media (dias) entre publicacao e homologacao, por orgao.
-- Agrupa pelo NOME padronizado (um orgao tem varias unidades/CNPJ).
-- COUNT(dias_ciclo) conta so itens com ciclo. HAVING mantem orgaos com 5 ou mais.
-- =====================================================================================
SELECT
    o.nome_orgao,
    COUNT(DISTINCT o.cnpj_orgao)        AS unidades_compradoras,
    COUNT(t.dias_ciclo)                 AS itens_com_ciclo,
    ROUND(AVG(t.dias_ciclo), 1)         AS ciclo_medio_dias,
    MAX(t.dias_ciclo)                   AS ciclo_maximo_dias
FROM fato_item_contratado t
JOIN dim_orgao o ON o.sk_orgao = t.sk_orgao
GROUP BY o.nome_orgao
HAVING COUNT(t.dias_ciclo) >= 5
ORDER BY ciclo_medio_dias DESC
LIMIT 20;

-- Ciclo medio geral (a media ignora itens sem ciclo, que ficam NULL)
SELECT
    ROUND(AVG(dias_ciclo), 1)              AS ciclo_medio_geral,
    MAX(dias_ciclo)                        AS ciclo_maximo,
    COUNT(*) - COUNT(dias_ciclo)           AS itens_sem_ciclo
FROM fato_item_contratado;


-- =====================================================================================
-- PERGUNTA 5 - Distribuicao regional
-- Onde se gasta mais e onde o desconto e melhor. Primeiro por UF, depois por regiao.
-- =====================================================================================
SELECT
    l.uf_sigla,
    l.regiao,
    SUM(t.valor_total_homologado)                                                   AS volume,
    ROUND(100 * SUM(t.valor_total_homologado)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2)      AS pct_do_volume,
    ROUND(100 * SUM(t.economia_valor)
          / NULLIF(SUM(CASE WHEN t.comparavel = 1 THEN t.valor_total_estimado ELSE 0 END), 0), 2) AS economia_pct
FROM fato_item_contratado t
JOIN dim_localidade l ON l.sk_localidade = t.sk_localidade
GROUP BY l.uf_sigla, l.regiao
ORDER BY volume DESC;

SELECT
    l.regiao,
    SUM(t.valor_total_homologado)                                                   AS volume,
    ROUND(100 * SUM(t.valor_total_homologado)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2)      AS pct_do_volume,
    ROUND(100 * SUM(t.economia_valor)
          / NULLIF(SUM(CASE WHEN t.comparavel = 1 THEN t.valor_total_estimado ELSE 0 END), 0), 2) AS economia_pct
FROM fato_item_contratado t
JOIN dim_localidade l ON l.sk_localidade = t.sk_localidade
GROUP BY l.regiao
ORDER BY volume DESC;


-- =====================================================================================
-- PERGUNTA 6 - Perfil dos gastos
-- Como o dinheiro se distribui entre Bens, Servicos e Obras e engenharia.
-- perfil_gasto e coluna da propria fato, entao nao precisa de JOIN.
-- Referencia da prova real: Obras 60,8 | Servicos 36,6 | Bens 2,6
-- =====================================================================================
SELECT
    perfil_gasto,
    COUNT(*)                                                                        AS itens,
    SUM(valor_total_homologado)                                                     AS volume,
    ROUND(100 * SUM(valor_total_homologado)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 1)      AS pct_do_volume,
    ROUND(SUM(valor_total_homologado) / COUNT(*), 2)                                AS ticket_medio_por_item
FROM fato_item_contratado
GROUP BY perfil_gasto
ORDER BY volume DESC;