-- =====================================================================================
--  ARQUIVO 4:  A TABELA FATO
--  Case: Pata Amiga - rede de petshops de SC  |  MySQL 8.0
-- =====================================================================================
--  Rode depois de: 03-dimensoes.sql
--
--  UMA fato, UM unico INSERT ... SELECT. A tabela ja existe, vazia (arquivo 02).
--  4.044 linhas = 4.044 pedidos.
--
--  Regra geral: a limpeza dos dados fica nas dimensoes; a fato apenas procura a
--  linha correta (por JOIN). Nenhuma FK fica nula: quando o dado falta, ela
--  aponta para a linha -1 (CASE WHEN ... IS NULL THEN -1).
--
--  Sugestao: comece pelo esqueleto (numero_pedido + as duas FKs de tempo +
--  FROM), rode e confira 4.044 linhas; depois acrescente as colunas aos poucos.
-- =====================================================================================

USE dw_pata_amiga;

INSERT INTO fato_pedido (
    numero_pedido,
    sk_tempo_pedido,
    sk_tempo_entrega,
    sk_loja,
    sk_categoria,
    houve_desconto,
    canal_pedido,
    dt_pedido,
    qt_itens,
    vl_liquido,
    dias_integracao_separacao,
    dias_separacao_nota,
    dias_nota_despacho,
    dias_despacho_entrega,
    dias_total_ate_entrega
)
SELECT
    sp.`NumeroPedido`,

    CAST(DATE_FORMAT(
        STR_TO_DATE(sp.`DtHoraPedido`, '%m/%d/%Y %h:%i %p'),
        '%Y%m%d'
    ) AS SIGNED),

    CASE
        WHEN sp.`DtEntregaCliente` = '' THEN -1
        ELSE CAST(DATE_FORMAT(DATE(sp.`DtEntregaCliente`), '%Y%m%d') AS SIGNED)
    END,

    COALESCE(dl.sk_loja, -1),

    COALESCE(dc.sk_categoria, -1),

    CASE
        WHEN UPPER(TRIM(sp.`HouveDesconto`)) IN ('S','SIM','1','X','TRUE','V') THEN 'Sim'
        WHEN UPPER(TRIM(sp.`HouveDesconto`)) IN ('N','NAO','0','FALSE','F')    THEN 'Nao'
        ELSE 'Nao Informado'
    END,

    CASE
        WHEN UPPER(sp.`CanalPedido`) LIKE '%WHATS%' THEN 'WhatsApp'
        WHEN UPPER(sp.`CanalPedido`) LIKE '%APP%'   THEN 'App'
        WHEN UPPER(sp.`CanalPedido`) LIKE '%SITE%'  THEN 'Site'
        WHEN UPPER(sp.`CanalPedido`) LIKE '%LOJA%'  THEN 'Loja Fisica'
        WHEN UPPER(sp.`CanalPedido`) LIKE '%TEL%'   THEN 'Telefone'
        ELSE 'Nao Informado'
    END,

    STR_TO_DATE(sp.`DtHoraPedido`, '%m/%d/%Y %h:%i %p'),

    CASE WHEN TRIM(sp.`QTD.Itens`) IN ('', '-') THEN NULL
         ELSE CAST(sp.`QTD.Itens` AS SIGNED) END,

    CASE
        WHEN TRIM(REPLACE(sp.`ValorLiquidoPedido(R$)`, 'R$', '')) IN ('', '-') THEN NULL
        WHEN sp.`ValorLiquidoPedido(R$)` LIKE '%,%'
            THEN CAST(REPLACE(REPLACE(REPLACE(REPLACE(sp.`ValorLiquidoPedido(R$)`,
                        'R$', ''), ' ', ''), '.', ''), ',', '.') AS DECIMAL(15,2))
        ELSE CAST(REPLACE(REPLACE(sp.`ValorLiquidoPedido(R$)`, 'R$', ''), ' ', '')
                  AS DECIMAL(15,2))
    END,

    DATEDIFF(
        CASE WHEN sp.`Dt Separacao Estoque` = '' THEN NULL ELSE sp.`Dt Separacao Estoque` END,
        DATE(STR_TO_DATE(sp.`DtHoraIntegracaoERP`, '%m/%d/%Y %h:%i %p'))
    ),
    DATEDIFF(
        CASE WHEN sp.`DtNotaFiscal` = '' THEN NULL ELSE sp.`DtNotaFiscal` END,
        CASE WHEN sp.`Dt Separacao Estoque` = '' THEN NULL ELSE sp.`Dt Separacao Estoque` END
    ),
    DATEDIFF(
        CASE WHEN sp.`Dt_Despacho_Transportadora` = '' THEN NULL ELSE sp.`Dt_Despacho_Transportadora` END,
        CASE WHEN sp.`DtNotaFiscal` = '' THEN NULL ELSE sp.`DtNotaFiscal` END
    ),
    DATEDIFF(
        CASE WHEN sp.`DtEntregaCliente` = '' THEN NULL ELSE sp.`DtEntregaCliente` END,
        CASE WHEN sp.`Dt_Despacho_Transportadora` = '' THEN NULL ELSE sp.`Dt_Despacho_Transportadora` END
    ),
    DATEDIFF(
        CASE WHEN sp.`DtEntregaCliente` = '' THEN NULL ELSE sp.`DtEntregaCliente` END,
        DATE(STR_TO_DATE(sp.`DtHoraIntegracaoERP`, '%m/%d/%Y %h:%i %p'))
    )

FROM stg_pedido sp

LEFT JOIN dim_categoria dc
       ON dc.categoria_origem = sp.`CategoriaProduto`

LEFT JOIN dim_loja dl
       ON dl.chave_loja = CASE
            WHEN UPPER(TRIM(REPLACE(REPLACE(sp.`Loja-Nome`, '/SC', ''), '  ', ' ')))
                 = 'PATA AMIGA BLUMENAL CENTRO' THEN 'PATA AMIGA BLUMENAU CENTRO'
            WHEN UPPER(TRIM(REPLACE(REPLACE(sp.`Loja-Nome`, '/SC', ''), '  ', ' ')))
                 = 'PATA AMIGA FLORIPA NORTE'   THEN 'PATA AMIGA FLORIANOPOLIS NORTE'
            WHEN UPPER(TRIM(REPLACE(REPLACE(sp.`Loja-Nome`, '/SC', ''), '  ', ' ')))
                 = 'PATA AMIGA JGUA DO SUL'     THEN 'PATA AMIGA JARAGUA DO SUL'
            ELSE UPPER(TRIM(REPLACE(REPLACE(sp.`Loja-Nome`, '/SC', ''), '  ', ' ')))
       END;

-- =====================================================================================
--  Confira o resultado com o 00-conferencia.sql (bloco "DEPOIS DO 04").
-- =====================================================================================
