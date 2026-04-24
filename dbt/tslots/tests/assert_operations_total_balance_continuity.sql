-- open_total_balance каждой строки должен равняться close_total_balance предыдущей строки
-- в той же партиции (agent_id, item_id), упорядоченной по (moment, id).
-- Нарушение означает разрыв в нарастающем остатке — симптом недетерминированного ORDER BY
-- или пропущенной операции.

WITH ordered AS (
    SELECT
        agent_id
        , item_id
        , id
        , moment
        , open_total_balance
        , close_total_balance
        , LAG(close_total_balance) OVER (
            PARTITION BY agent_id, item_id
            ORDER BY moment, id
        ) AS prev_close_total_balance
    FROM {{ ref('int_operations_with_balance__agent_slot_item') }}
)
SELECT *
FROM ordered
WHERE prev_close_total_balance IS NOT NULL
  AND open_total_balance != prev_close_total_balance
