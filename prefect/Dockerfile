FROM prefecthq/prefect:3.6.27-python3.11

# Устанавливаем зависимости через pip (без pipenv — внутри контейнера он не нужен)
RUN pip install --no-cache-dir \
    dbt-postgres==1.10.0 \
    requests==2.31.0 \
    pandas==3.0.0 \
    sqlalchemy==2.0.36 \
    pg8000==1.31.2

WORKDIR /app
