"""一次性回補：把 events 歷史直接寫進 cdp_raw.events 的各日分區。

來源表沒有分區，逐日走 extract → load 回補 N 天要掃 N × 385 MB；
這裡只掃一次，用查詢結果整批覆寫 <= --until 的所有分區。之後每日排程照常走 GCS。
"""

import argparse
import logging
from datetime import date

from extract import MAX_BYTES, PROJECT, SOURCE, TABLES
from google.cloud import bigquery


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--until", required=True, type=date.fromisoformat, help="回補到這天（含）")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
    client = bigquery.Client(project=PROJECT, location="US")
    cfg = bigquery.QueryJobConfig(
        dry_run=args.dry_run,
        maximum_bytes_billed=MAX_BYTES,
        destination=f"{PROJECT}.cdp_raw.events",
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        time_partitioning=bigquery.TimePartitioning(field="dt"),
    )
    sql = f"""
SELECT {TABLES["events"][1]}, CURRENT_TIMESTAMP() AS _extracted_at, DATE(created_at) AS dt
FROM `{SOURCE}.events`
WHERE created_at < TIMESTAMP(DATE_ADD('{args.until}', INTERVAL 1 DAY))"""
    job = client.query(sql, job_config=cfg)
    if args.dry_run:
        logging.info("dry run: %.1f MB", job.total_bytes_processed / 1e6)
        return
    job.result()
    table = client.get_table(f"{PROJECT}.cdp_raw.events")
    logging.info("events backfilled: %s rows, billed %.1f MB", table.num_rows, job.total_bytes_billed / 1e6)


if __name__ == "__main__":
    main()
