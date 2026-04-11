-- 01_raw_schema.sql — создаёт схему layer_raw.
--
-- Таблица raw создаётся и перезаписывается Prefect при каждом запуске.
-- Здесь только схема — обязательный шаг при первом старте контейнера.

CREATE SCHEMA IF NOT EXISTS layer_raw;
