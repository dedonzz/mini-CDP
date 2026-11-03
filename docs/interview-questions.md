# 面試題庫

每個里程碑做完後補上題目，全部實作完成後統一回顧。重點放在 GCP 與資料工程。

## M0 環境與基礎建設

1. 為什麼所有 dataset 都放在 `US` multi-region？如果公司的資料在 `asia-east1`，又要 join `US` 的公開資料集，你會怎麼處理？
2. `cdp_raw` / `cdp_staging` / `cdp_marts` 三層各自負責什麼？為什麼不直接從 raw 做 marts？
3. 為什麼在 BigQuery 前面多放一層 GCS Parquet，而不是直接 `CREATE TABLE AS SELECT` 到 `cdp_raw`？兩種做法的取捨是什麼？
4. BigQuery on-demand 是怎麼計費的？你在這個專案用了哪些手段控制成本？預算提醒能不能真正擋住花費？
5. 為什麼本機用 ADC、不建 service account 金鑰檔？到了正式環境，Airflow 應該怎麼向 BigQuery 認證？

## M1 raw / staging 層 + 資料品質檢查

1. `orders` 沒有 `updated_at`，你為什麼對它做每日全量快照，而 `events` 只抽當天增量？如果 `orders` 有一億筆，你會怎麼改？（提示：CDC、`updated_at` 水位線、Datastream）
2. 你的 extract 和 load 怎麼做到冪等？`WRITE_APPEND` 和 `WRITE_TRUNCATE` 加分區裝飾器（`table$YYYYMMDD`）差在哪裡？
3. 公開的 `events` 表沒有分區，只抽一天也要掃 385 MB。你怎麼處理歷史回補？如果來源是你們自己的表，你會給上游什麼建議？
4. `WHERE dt = (SELECT MAX(dt) ...)` 和 `WHERE dt = DATE '2026-11-01'` 在 BigQuery 掃描量上有什麼差別？你怎麼驗證分區剪枝真的有生效？
5. `EXPORT DATA` 把 247 筆資料拆成 13 個小檔案，這會造成什麼問題？量大時怎麼處理？
6. 哪些 dbt 測試你設成 `error`、哪些設成 `warn`？判斷標準是什麼？`relationships` 測試遇到 null 會怎樣？
7. source freshness 是怎麼運作的？`_extracted_at` 和資料本身的 `created_at` 該用哪一個當 `loaded_at_field`？

## M2 marts：維度表、事實表、Customer 360、RFM

1. `fct_order_items` 和 `fct_orders` 的粒度各是什麼？為什麼營收口徑（`is_revenue`）只在一個地方定義？
2. 事實表為什麼依 `order_date` 分區、依 `user_id` 做 cluster？分區欄位和 cluster 欄位各自怎麼挑？
3. `fct_events` 為什麼用 incremental 加 `insert_overwrite`，而不是 `merge`？static partitions 和 dynamic partitions 差在哪裡？遲到資料怎麼處理？
4. RFM 的 F 為什麼不用 `NTILE`？`NTILE` 在同分很多時會發生什麼事？為什麼要加 `user_id` 當 tie-breaker？
5. 為什麼 RFM 的基準日用快照日，而不是 `CURRENT_DATE()`？如果用 `CURRENT_DATE()`，重跑歷史日期會怎樣？
6. 沒有下過單的用戶要不要放進 Customer 360？放進去和不放各對哪些下游用途有影響？
7. `customer_360` 一列一位客戶，你用什麼測試保證它沒有因為 join 而重複、也沒有漏掉人？
8. 如果行銷要看「客戶上個月是什麼分群」，現在的設計做得到嗎？要怎麼改？（提示：SCD Type 2、dbt snapshots、每日分群快照表）

## M3 Airflow 排程與冪等

1. `logical_date`、data interval 和實際執行時間的差別是什麼？你的 DAG 為什麼處理的是「前一天」？
2. 什麼是冪等？你的 DAG 重跑同一天，從 GCS、raw 到 marts，每一層分別怎麼保證結果不變？
3. 快照表可以 backfill 嗎？用今天的快照去 backfill 上個月的 `dt`，會得到什麼？這個限制要怎麼跟使用者說明？
4. 為什麼 dbt 要裝在獨立的 venv，而不是直接裝進 Airflow 的環境？還有哪些整合方式？（提示：Cosmos、KubernetesPodOperator、Cloud Run Jobs）
5. `max_active_runs=1`、`retries`、指數退避、`execution_timeout` 各自防的是什麼問題？
6. 本機用掛載的 ADC，到了 Cloud Composer 或 GKE 要怎麼認證？為什麼不建議用 service account 金鑰檔？
7. 每張表的 extract 和 load 平行執行，再匯合到 `dbt build`，這樣切 task 的好處是什麼？task 切太細又會有什麼問題？

## M4 CI、架構圖、README、面試講稿

1. 你的 CI 不需要任何 GCP 憑證，它能抓到哪些問題、抓不到哪些問題？如果要在 PR 上跑 `dbt build`，要怎麼安全地給 CI 權限？（提示：Workload Identity Federation、PR 專用 dataset、`state:modified+` slim CI）
2. Terraform state 為什麼要放 GCS？state bucket 為什麼不讓同一份 Terraform 管理？GCS backend 怎麼處理多人同時 apply 的問題？
3. `users` 表裡有 PII，在 BigQuery 上有哪些保護方式？（提示：policy tags、column-level security、row-level security、authorized views、dynamic data masking）
4. 用兩分鐘講完這個專案的架構，並說出你最自豪的一個設計決策，以及你最想改進的地方。
