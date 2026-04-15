-- int_operations_united.sql — все операционные документы в единой таблице позиций.
-- Объединяет 5 staging-таблиц по типам документов.

SELECT * FROM {{ ref('stg_moy_sklad__demand') }}
UNION ALL
SELECT * FROM {{ ref('stg_moy_sklad__supply') }}
UNION ALL
SELECT * FROM {{ ref('stg_moy_sklad__loss') }}
UNION ALL
SELECT * FROM {{ ref('stg_moy_sklad__enter') }}
UNION ALL
SELECT * FROM {{ ref('stg_moy_sklad__move') }}
ORDER BY moment, number
