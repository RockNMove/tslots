-- depositor_id не должен быть NULL ни в одной операции.
-- Критично для биллинга: операция без поклажедателя не может быть выставлена в счёт.
-- Нарушение означает что у товара не заполнено поле «Поклажедатель» в МойСклад.

SELECT *
FROM {{ ref('int_operations_with_balance__slot_item') }}
WHERE depositor_id IS NULL
