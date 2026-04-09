FROM prefecthq/prefect:3-python3.11

# Устанавливаем зависимости через pip (без pipenv — внутри контейнера он не нужен)
RUN pip install --no-cache-dir \
    dbt-postgres==1.10.0 \
    psycopg2-binary==2.9.9 \
    requests==2.31.0 \
    python-dotenv==1.0.1

WORKDIR /app
