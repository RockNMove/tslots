-- Модель: focus__errors_warnings_operations
-- Инвариант: каждая строка витрины содержит непустое значение slot_oper_errors.
-- Ответственность: целостность витрины операционных аномалий.
--   slot_oper_errors формируется через CONCAT_WS и никогда не бывает NULL — только
--   непустая строка (есть ошибки) или '' (ошибок нет). Витрина фильтрует
--   WHERE slot_oper_errors != '' — значит в ней должны быть только строки с реальными ошибками.
--   Пустая строка или NULL означает что фильтр не сработал или CONCAT_WS изменил поведение.
-- При нарушении: фильтр в focus__errors_warnings_operations изменён с != '' на IS NOT NULL,
--   либо логика CONCAT_WS в int_operations_with_balance__slot_item вернула NULL или пустую строку.
SELECT
    slot_name
    , doc_name
    , moment_day
    , op_type
    , slot_oper_errors
    , doc_type
    , store_name
    , open_slot_balance
    , close_slot_balance
FROM {{ ref('focus__errors_warnings_operations') }}
WHERE slot_oper_errors IS NULL OR slot_oper_errors = ''
