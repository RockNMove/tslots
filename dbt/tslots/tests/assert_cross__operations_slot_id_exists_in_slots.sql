{{ config(tags=['cross_layer']) }}
-- Каждый slot_id в операциях должен существовать в справочнике ячеек.
-- off_slot — виртуальная ячейка для операций без указания ячейки, исключается из проверки.
-- Нарушение означает ссылку на удалённую или несуществующую ячейку.

SELECT DISTINCT o.slot_id
FROM {{ ref('int_operations_with_balance__slot_item') }} o
WHERE o.slot_id != 'off_slot'
  AND o.slot_id NOT IN (
      SELECT slot_id FROM {{ ref('stg_moy_sklad__slots') }}
  )
