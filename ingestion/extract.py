"""抽取：thelook 公開資料集 → GCS Parquet（每次執行覆寫該日分區，可重跑）。

- snapshot 表（會變動或量小）：每天全量快照，寫到 dt=<ds>
- incremental 表（只增不改、量大）：只抽 created_at 落在 ds 當天的資料
"""

import argparse
import logging
from datetime import date

from google.cloud import bigquery

PROJECT = "mini-cdp-dedonzz"
BUCKET = "mini-cdp-dedonzz-lake"
SOURCE = "bigquery-public-data.thelook_ecommerce"
MAX_BYTES = 1_000_000_000  # 單一查詢上限 1 GB

TABLES = {
    "users": (
        "snapshot",
        "id, first_name, last_name, email, age, gender, state, street_address, "
        "postal_code, city, country, latitude, longitude, traffic_source, created_at",
    ),
    "products": ("snapshot", "id, cost, category, name, brand, retail_price, department, sku, distribution_center_id"),
    "orders": (
        "snapshot",
        "order_id, user_id, status, gender, created_at, returned_at, shipped_at, delivered_at, num_of_item",
    ),
    "order_items": (
        "snapshot",
        "id, order_id, user_id, product_id, inventory_item_id, status, created_at, "
        "shipped_at, delivered_at, returned_at, sale_price",
    ),
    "events": (
        "incremental",
        "id, user_id, sequence_number, session_id, created_at, ip_address, city, "
        "state, postal_code, browser, traffic_source, uri, event_type",
    ),
}


def build_sql(table: str, ds: date) -> str:
    mode, cols = TABLES[table]
    where = ""
    if mode == "incremental":
        where = f"WHERE created_at >= TIMESTAMP('{ds}') AND created_at < TIMESTAMP(DATE_ADD('{ds}', INTERVAL 1 DAY))"
    uri = f"gs://{BUCKET}/raw/{table}/dt={ds}/*.parquet"
    return f"""
EXPORT DATA OPTIONS (uri = '{uri}', format = 'PARQUET', compression = 'SNAPPY', overwrite = true)
AS SELECT {cols}, CURRENT_TIMESTAMP() AS _extracted_at
FROM `{SOURCE}.{table}` {where}"""


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--ds", required=True, type=date.fromisoformat, help="邏輯日期 YYYY-MM-DD")
    p.add_argument("--tables", nargs="+", default=list(TABLES), choices=list(TABLES))
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
    client = bigquery.Client(project=PROJECT, location="US")
    cfg = bigquery.QueryJobConfig(dry_run=args.dry_run, use_query_cache=False, maximum_bytes_billed=MAX_BYTES)

    for table in args.tables:
        job = client.query(build_sql(table, args.ds), job_config=cfg)
        if args.dry_run:
            logging.info("%-12s dry run: %.1f MB", table, job.total_bytes_processed / 1e6)
        else:
            job.result()
            logging.info("%-12s exported, billed %.1f MB", table, (job.total_bytes_billed or 0) / 1e6)


if __name__ == "__main__":
    main()
