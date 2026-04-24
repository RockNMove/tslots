{{ config(tags=['cross_layer']) }}
-- Таблицы: int_prep__operations_united vs 5 staging-таблиц операций
-- Инвариант: количество строк в int_prep__operations_united равно сумме строк
--   во всех пяти staging-таблицах (demand + supply + loss + enter + move).
-- Ответственность: полнота UNION ALL — ни одна операция не теряется при объединении.
--   int_prep__operations_united строится через UNION ALL без каких-либо фильтров.
--   Любое расхождение означает что одна из таблиц не включена или включена дважды.
-- При нарушении: проверить список таблиц в UNION ALL запросе int_prep__operations_united.
SELECT
    united_count
    , staging_sum          AS staging_count
    , united_count - staging_sum AS diff
FROM (
    SELECT COUNT(*) AS united_count
    FROM {{ ref('int_prep__operations_united') }}
) u
CROSS JOIN (
    SELECT
        (SELECT COUNT(*) FROM {{ ref('stg_moy_sklad__demand') }})  +
        (SELECT COUNT(*) FROM {{ ref('stg_moy_sklad__supply') }})  +
        (SELECT COUNT(*) FROM {{ ref('stg_moy_sklad__loss') }})    +
        (SELECT COUNT(*) FROM {{ ref('stg_moy_sklad__enter') }})   +
        (SELECT COUNT(*) FROM {{ ref('stg_moy_sklad__move') }})    AS staging_sum
) s
WHERE u.united_count != s.staging_sum
