-- Модель: focus__errors_warnings
-- Инвариант: каждая строка витрины содержит непустое значение slot_errors.
-- Ответственность: целостность витрины аномалий.
--   slot_errors формируется через CONCAT_WS и никогда не бывает NULL — только
--   непустая строка (есть ошибки) или '' (ошибок нет). Витрина фильтрует
--   WHERE slot_errors != '' — значит в ней должны быть только строки с реальными ошибками.
--   Пустая строка или NULL означает что фильтр не сработал или CONCAT_WS изменил поведение.
-- При нарушении: фильтр в focus__errors_warnings изменён с != '' на IS NOT NULL,
--   либо логика CONCAT_WS в операционной модели вернула NULL или пустую строку.
SELECT
    slot_name
    , doc_name
    , moment_day
    , op_type
    , slot_errors
    , doc_type
    , store_name
    , agent_name
    , open_slot_balance
    , close_slot_balance
FROM {{ ref('focus__errors_warnings') }}
WHERE slot_errors IS NULL OR slot_errors = ''
