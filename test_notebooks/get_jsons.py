import json
from pathlib import Path
import requests
from dotenv import dotenv_values

# Читаем токен из корневого .env проекта
ENV_FILE = dotenv_values(Path(__file__).parent.parent / '.env')
TOKEN = ENV_FILE.get('MS_TOKEN')

HEADERS = {
    'Authorization': f'Bearer {TOKEN}',
    'Accept-Encoding': 'gzip',
}
LIMIT = 100

START_TIMESTAMP = '2010-04-05 00:00:00'
STOP_TIMESTAMP = '2027-04-07 00:00:00'

# --- Параметры запросов ---

params_store = {
    "expand": "zones,slots.zone",
    "filter": f"updated>={START_TIMESTAMP};updated<{STOP_TIMESTAMP}",
    "limit": LIMIT}
params_uom = {
    "limit": LIMIT}
params_product = {
    "expand": "uom,attributes.value",
    "filter": f"updated>={START_TIMESTAMP};updated<{STOP_TIMESTAMP}",
    "limit": LIMIT}
params_variant = {
    "expand": "product",
    "filter": f"updated>={START_TIMESTAMP};updated<{STOP_TIMESTAMP}",
    "limit": LIMIT}
params_agent = {
    "filter": f"updated>={START_TIMESTAMP};updated<{STOP_TIMESTAMP}",
    "limit": LIMIT}
# params_in_out = {
#     "expand": "positions.slot,positions.assortment,agent,store",
#     "filter": f"updated>={START_TIMESTAMP};updated<{STOP_TIMESTAMP};applicable=true",
#     "limit": LIMIT}
params_in_out = {
    "expand": "positions.slot,positions.assortment,agent,store",
    "filter": f"updated>={START_TIMESTAMP};updated<{STOP_TIMESTAMP}",
    "limit": LIMIT}
params_move = {
    "expand": "positions.targetSlot,positions.sourceSlot,positions.assortment",
    "filter": f"updated>={START_TIMESTAMP};updated<{STOP_TIMESTAMP};applicable=true",
    "limit": LIMIT}

# --- Запросы к API ---

BASE = 'https://api.moysklad.ru/api/remap/1.2/entity'


def get(endpoint, params):
    try:
        r = requests.get(f'{BASE}/{endpoint}', headers=HEADERS, params=params, timeout=30)
        r.raise_for_status()
        return r.json()
    except requests.exceptions.ReadTimeout:
        print(f'[{endpoint}] таймаут — API не ответил за 30 секунд, проверь соединение')
        raise
    except requests.exceptions.HTTPError as e:
        print(f'[{endpoint}] HTTP ошибка {e.response.status_code} — возможно неверный токен или нет доступа')
        raise
    except requests.exceptions.ConnectionError:
        print(f'[{endpoint}] нет соединения — проверь интернет')
        raise


store_raw = get('store',        params_store)
uom_raw = get('uom',          params_uom)
product_raw = get('product',      params_product)
variant_raw = get('variant',      params_variant)
agent_raw = get('counterparty', params_agent)
demand_raw = get('demand',       params_in_out)
supply_raw = get('supply',       params_in_out)
loss_raw = get('loss',         params_in_out)
enter_raw = get('enter',        params_in_out)
move_raw = get('move',         params_move)

# --- Сохранение в temp/raw_json ---

data_to_save = {
    'store_raw.json':   store_raw,
    'uom_raw.json':     uom_raw,
    'product_raw.json': product_raw,
    'variant_raw.json': variant_raw,
    'agent_raw.json':   agent_raw,
    'demand_raw.json':  demand_raw,
    'supply_raw.json':  supply_raw,
    'loss_raw.json':    loss_raw,
    'enter_raw.json':   enter_raw,
    'move_raw.json':    move_raw,
}

out_dir = Path(__file__).parent / 'temp' / 'raw_json'
out_dir.mkdir(parents=True, exist_ok=True)

for filename, content in data_to_save.items():
    (out_dir / filename).write_text(
        json.dumps(content, ensure_ascii=False, indent=4),
        encoding='utf-8'
    )
    print(f'saved {filename}')
