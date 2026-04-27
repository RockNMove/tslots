-- Модель: partners__nrb_stock_movements
-- Инвариант: строк с doc_type = 'move' нет в витрине.
-- Ответственность: чистота отчёта для партнёров — только реальные движения.
--   Витрина показывает физический приход и расход (supply, demand, enter, loss).
--   Внутренние перемещения (move) исключены фильтром WHERE doc_type != 'move' в модели.
--   Их присутствие в витрине означало бы двойной счёт: move_out из одной ячейки
--   и move_in в другую — одно и то же физическое количество учтено дважды.
-- При нарушении: фильтр WHERE doc_type != 'move' удалён или обойдён в partners__nrb_stock_movements,
--   либо в staging-данных doc_type 'move' маркирован как другой тип документа.
SELECT
    depositor_name
    , item_name
    , doc_time
    , doc_name
    , doc_type
    , quantity
    , open_balance
    , close_balance
FROM {{ ref('partners__nrb_stock_movements') }}
WHERE doc_type = 'move'
