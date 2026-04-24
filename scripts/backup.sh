#!/bin/bash
# backup.sh — ежедневный бэкап PostgreSQL
#
# ОТКУДА: база tslots внутри Docker-контейнера tslots-postgres
# КУДА:   папка /opt/tslots/backups/ на сервере (вне Docker)
# ФОРМАТ: бинарный дамп pg_dump -Fc (восстанавливается через pg_restore)
# РОТАЦИЯ: файлы старше BACKUP_KEEP_DAYS дней удаляются автоматически
#
# Автозапуск — добавить в cron на сервере (crontab -e):
#   0 3 * * * /opt/tslots/scripts/backup.sh >> /opt/tslots/scripts/backup.log 2>&1

set -euo pipefail

BACKUP_DIR="/var/backups/tslots"
CONTAINER="tslots-postgres"
DB_NAME="${DB_NAME:-tslots}"
DB_USER="${DB_USER:-admin}"
KEEP_DAYS="${BACKUP_KEEP_DAYS:-7}"

mkdir -p "$BACKUP_DIR"

FILENAME="$BACKUP_DIR/$(date +%Y-%m-%d_%H-%M-%S).dump"

echo "$(date '+%Y-%m-%d %H:%M:%S') — начинаем бэкап базы $DB_NAME из контейнера $CONTAINER..."
docker exec "$CONTAINER" pg_dump -U "$DB_USER" -Fc "$DB_NAME" > "$FILENAME"
echo "$(date '+%Y-%m-%d %H:%M:%S') — бэкап сохранён: $FILENAME ($(du -sh "$FILENAME" | cut -f1))"

echo "$(date '+%Y-%m-%d %H:%M:%S') — удаляем дампы старше $KEEP_DAYS дней..."
find "$BACKUP_DIR" -name "*.dump" -mtime +$KEEP_DAYS -delete
echo "$(date '+%Y-%m-%d %H:%M:%S') — готово"

# ---------------------------------------------------------------------------
# Загрузка в S3 (настроить под своего провайдера)
# ---------------------------------------------------------------------------
# AWS S3:
#   aws s3 cp "$FILENAME" s3://your-bucket/tslots-backups/
#
# Yandex Object Storage:
#   aws s3 cp "$FILENAME" s3://your-bucket/tslots-backups/ \
#     --endpoint-url=https://storage.yandexcloud.net
#
# Раскомментируй нужную строку и добавь переменные S3_BUCKET, AWS_ACCESS_KEY_ID,
# AWS_SECRET_ACCESS_KEY в .env
