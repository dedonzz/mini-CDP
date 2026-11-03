"""載入：GCS Parquet → cdp_raw 分區表。

每次以 WRITE_TRUNCATE 覆寫 `table$YYYYMMDD` 單一分區，重跑同一天結果不變（冪等）。
dt 欄位由 GCS 路徑 dt=YYYY-MM-DD 解析（hive partitioning），表依 dt 做日分區。
"""

import argparse
import logging
from datetime import date

from google.cloud import bigquery

PROJECT = "mini-cdp-dedonzz"
BUCKET = "mini-cdp-dedonzz-lake"
DATASET = "cdp_raw"
TABLES = ["users", "products", "orders", "order_items", "events"]


def load_partition(client: bigquery.Client, table: str, ds: date) -> bigquery.LoadJob:
    prefix = f"gs://{BUCKET}/raw/{table}"
    hive = bigquery.HivePartitioningOptions()
    hive.mode = "CUSTOM"
    hive.source_uri_prefix = f"{prefix}/{{dt:DATE}}"

    cfg = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.PARQUET,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        hive_partitioning=hive,
        time_partitioning=bigquery.TimePartitioning(type_=bigquery.TimePartitioningType.DAY, field="dt"),
    )
    dest = f"{PROJECT}.{DATASET}.{table}${ds:%Y%m%d}"
    return client.load_table_from_uri(f"{prefix}/dt={ds}/*.parquet", dest, job_config=cfg)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--ds", required=True, type=date.fromisoformat, help="邏輯日期 YYYY-MM-DD")
    p.add_argument("--tables", nargs="+", default=TABLES, choices=TABLES)
    args = p.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
    client = bigquery.Client(project=PROJECT, location="US")

    for table in args.tables:
        job = load_partition(client, table, args.ds)
        job.result()
        logging.info("%-12s loaded %s rows into %s", table, job.output_rows, job.destination)


if __name__ == "__main__":
    main()
