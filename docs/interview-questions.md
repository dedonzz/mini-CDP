# 面試題庫

每個里程碑做完後補上題目，全部實作完成後統一回顧。重點放在 GCP 與資料工程。

## M0 環境與基礎建設

1. 為什麼所有 dataset 都放在 `US` multi-region？如果公司的資料在 `asia-east1`，又要 join `US` 的公開資料集，你會怎麼處理？
2. `cdp_raw` / `cdp_staging` / `cdp_marts` 三層各自負責什麼？為什麼不直接從 raw 做 marts？
3. 為什麼在 BigQuery 前面多放一層 GCS Parquet，而不是直接 `CREATE TABLE AS SELECT` 到 `cdp_raw`？兩種做法的取捨是什麼？
4. BigQuery on-demand 是怎麼計費的？你在這個專案用了哪些手段控制成本？預算提醒能不能真正擋住花費？
5. 為什麼本機用 ADC、不建 service account 金鑰檔？到了正式環境，Airflow 應該怎麼向 BigQuery 認證？

## M1 raw / staging 層 + 資料品質檢查

（完成後補上）

## M2 marts：維度表、事實表、Customer 360、RFM

（完成後補上）

## M3 Airflow 排程與冪等

（完成後補上）

## M4 CI、架構圖、README、面試講稿

（完成後補上）
