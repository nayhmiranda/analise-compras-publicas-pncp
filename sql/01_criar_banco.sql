-- 01_criar_banco.sql
-- Star Schema do projeto PNCP: 4 dimensoes e 1 fato.
-- O banco em si e recriado pelo Python (banco.recriar_banco). Este script so cria as tabelas.
-- As dimensoes vem primeiro, porque a fato tem chave estrangeira para elas.

-- DIMENSAO: quem comprou (uma linha por CNPJ de orgao)
CREATE TABLE dim_orgao (
    sk_orgao    INTEGER PRIMARY KEY,
    cnpj_orgao  VARCHAR(20) NOT NULL UNIQUE,
    nome_orgao  VARCHAR(500),
    poder       VARCHAR(30)
);

-- DIMENSAO: quem vendeu (uma linha por CNPJ/CPF de fornecedor)
CREATE TABLE dim_fornecedor (
    sk_fornecedor    INTEGER PRIMARY KEY,
    ni_fornecedor    VARCHAR(30) NOT NULL UNIQUE,
    nome_fornecedor  VARCHAR(500),
    tipo_pessoa      VARCHAR(5),
    porte            VARCHAR(50)
);

-- DIMENSAO: como comprou (uma linha por modalidade)
CREATE TABLE dim_modalidade (
    sk_modalidade    INTEGER PRIMARY KEY,
    modalidade_id    INTEGER NOT NULL UNIQUE,
    nome_modalidade  VARCHAR(100) NOT NULL
);

-- DIMENSAO: onde (uma linha por UF)
CREATE TABLE dim_localidade (
    sk_localidade  INTEGER PRIMARY KEY,
    uf_sigla       VARCHAR(5) NOT NULL UNIQUE,
    uf_nome        VARCHAR(60),
    regiao         VARCHAR(20)
);

-- FATO: uma linha por item de contratacao, com o fornecedor vencedor
CREATE TABLE fato_item_contratado (
    sk_fato                    BIGSERIAL PRIMARY KEY,
    numero_controle_pncp       VARCHAR(50) NOT NULL,
    numero_item                INTEGER NOT NULL,
    sk_orgao                   INTEGER NOT NULL REFERENCES dim_orgao (sk_orgao),
    sk_fornecedor              INTEGER NOT NULL REFERENCES dim_fornecedor (sk_fornecedor),
    sk_modalidade              INTEGER NOT NULL REFERENCES dim_modalidade (sk_modalidade),
    sk_localidade              INTEGER NOT NULL REFERENCES dim_localidade (sk_localidade),
    data_publicacao            DATE,
    data_homologacao           DATE,
    descricao_item             TEXT,
    perfil_gasto               VARCHAR(30),
    quantidade                 DECIMAL(18,4) NOT NULL,
    valor_unitario_estimado    DECIMAL(18,4),
    valor_total_estimado       DECIMAL(18,2),
    valor_unitario_homologado  DECIMAL(18,4),
    valor_total_homologado     DECIMAL(18,2),
    comparavel                 SMALLINT NOT NULL,
    economia_valor             DECIMAL(18,2),
    dias_ciclo                 INTEGER,
    -- o grao da fato: um item de uma contratacao so aparece uma vez
    CONSTRAINT uq_fato_item UNIQUE (numero_controle_pncp, numero_item),
    -- o banco e a segunda barreira das regras de negocio
    CONSTRAINT ck_quantidade_positiva CHECK (quantidade > 0),
    CONSTRAINT ck_valores_nao_negativos CHECK (
        valor_unitario_estimado >= 0 AND valor_total_estimado >= 0
        AND valor_unitario_homologado >= 0 AND valor_total_homologado >= 0
    ),
    CONSTRAINT ck_comparavel_binario CHECK (comparavel IN (0, 1)),
    CONSTRAINT ck_ciclo_nao_negativo CHECK (dias_ciclo IS NULL OR dias_ciclo >= 0)
);