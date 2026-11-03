# 實作導覽：一步一步回顧

照順序讀，每一步都列出：看哪些檔案、怎麼運作、面試重點、怎麼自己驗證。對應的面試題在 `interview-questions.md`。

---

## M0 環境與基礎建設（🤖）

- **檔案**：`terraform/main.tf`、`variables.tf`、`versions.tf`
- **做了什麼**：三個 dataset（`cdp_raw` / `cdp_staging` / `cdp_marts`，都在 `US`）和 lake bucket（90 天後自動刪除）。
- **重點**
  - 公開資料集在 `US`，BigQuery 不能跨 location 查詢，所以全部放 `US`。
  - 分層的目的：raw 保留「載入時的原樣」可以重算；staging 只做清洗、不做商業邏輯；marts 給業務用。
  - 認證全部用 ADC，沒有任何金鑰檔。

## M1-1 dbt 專案骨架（🤖）

- **檔案**：`pyproject.toml`、`dbt/dbt_project.yml`、`dbt/profiles.yml`、`dbt/macros/generate_schema_name.sql`
- **重點**
  - `profiles.yml` 用 `method: oauth`，也就是走 ADC，所以可以安全地放進 repo。
  - `maximum_bytes_billed: 1 GB`：任何查詢超過 1 GB 直接失敗，是成本的最後一道防線。
  - `generate_schema_name` 覆寫：dbt 預設會把 dataset 名稱組成 `cdp_staging_cdp_marts`，覆寫後直接用 `+schema` 指定的名稱。

## M1-2 抽取：公開資料集 → GCS Parquet（🧑）

- **檔案**：`ingestion/extract.py`
- **怎麼運作**：`EXPORT DATA OPTIONS(uri='gs://.../raw/<table>/dt=<ds>/*.parquet', overwrite=true) AS SELECT ...`
  - snapshot 表（users、products、orders、order_items）每天全量匯出。
  - incremental 表（events）只匯出 `created_at` 落在 ds 當天的資料。
- **重點**
  - **為什麼 orders 要做快照**：狀態會變，又沒有 `updated_at`。只抽當天新訂單的話，舊訂單的出貨和退貨永遠不會進來。
  - **冪等**：`overwrite=true` 加上以 ds 命名的資料夾，重跑同一天只會覆蓋同一個資料夾。
  - **成本**：公開的 events 表沒有分區，只抽一天也要掃 385 MB。這就是 M1 的 backfill 和面試題 M1-3 的由來。
  - 不用 `SELECT *`，欄位明確列出（GEOGRAPHY 欄位可以由經緯度重建，所以不匯出）。
- **驗證**：`uv run python ingestion/extract.py --ds 2026-11-01 --dry-run`

## M1-3 載入：GCS → cdp_raw（🧑）

- **檔案**：`ingestion/load.py`、`ingestion/backfill_events.py`
- **怎麼運作**：load job 的目標寫成 `cdp_raw.<table>$20261101`，加上 `WRITE_TRUNCATE`，就只會整個替換那一個分區。
  - hive partitioning（`{dt:DATE}`）從路徑 `dt=2026-11-01` 解析出真正的 `dt` 欄位，表依 `dt` 做日分區。
- **重點**
  - load job **免費**，`MERGE` 要依掃描量付費。只要「整個分區替換」就夠用，就不需要 `MERGE`。
  - `WRITE_APPEND` 重跑會重複；`WRITE_TRUNCATE` 不加分區裝飾器會清空整張表。兩者都不對。
  - **events 回補**：用一次查詢（掃 385 MB）把整段歷史依 `DATE(created_at)` 寫進各分區，取代逐日跑 N 次。
- **驗證**：重跑後查 `cdp_raw.INFORMATION_SCHEMA.PARTITIONS`，筆數不會翻倍（這是 metadata 查詢，不掃資料）。

## M1-4 staging（🧑）

- **檔案**：`dbt/models/staging/_sources.yml`、`stg_*.sql`、`dbt/macros/snapshot_dt.sql`
- **怎麼運作**：每個 staging view 只做重新命名、轉型（金額轉 `NUMERIC`）、轉小寫；快照表只讀一個 dt。
- **重點**：`snapshot_dt()` 回傳的是**常數日期**。
  - 有傳 `--vars '{ds: ...}'` 就用 ds，這是 Airflow 的情況，重跑舊日期也會讀到正確的快照。
  - 沒傳就查 `INFORMATION_SCHEMA.PARTITIONS` 取最新分區，這是本機開發的情況。
  - 為什麼不用 `WHERE dt = (SELECT MAX(dt) ...)`：剪枝沒有保證，而且重跑舊日期會讀錯資料。
- **驗證**：對一個不存在的日期做 dry run，掃描量是 0 bytes，證明剪枝有生效。

## M1-5 資料品質（🧑）

- **檔案**：`dbt/models/staging/_staging.yml`、`dbt/tests/assert_order_item_count_matches.sql`、`dbt/packages.yml`
- **重點**
  - 主鍵（`unique` + `not_null`）、關聯（`relationships`）、值域（`accepted_values`）設成 **error**。這些壞掉，下游一定算錯，所以要擋下 pipeline。
  - 來源資料本身的業務瑕疵（出貨時間早於下單時間、訪客對不到用戶）設成 **warn**，記錄下來但不阻斷。
  - `relationships` 會自動略過 null，所以 events 的訪客（`user_id` 為 null）不會讓測試失敗。
  - 對帳測試（singular test）：`orders.item_count` 應該等於品項的實際筆數。
  - source freshness 用 `_extracted_at`：要偵測的是 pipeline 有沒有在跑，不是業務有沒有新訂單。

## M2 marts（🧑）

- **檔案**：`dbt/models/marts/*.sql`、`_marts.yml`
- **模型**

| 模型 | 粒度 | 物化 | 重點 |
|---|---|---|---|
| `dim_customers` | 一位用戶 | table | 包含沒下過單的人，另外算出 `age_band` |
| `dim_products` | 一個商品 | table | `list_margin_rate` |
| `fct_order_items` | 一個品項 | table，依 `order_date` 分區、依 user/product 做 cluster | **營收口徑 `is_revenue` 只在這裡定義** |
| `fct_orders` | 一張訂單 | table，分區 + cluster | 金額由品項加總，`user_order_seq` |
| `fct_events` | 一個事件 | **incremental insert_overwrite** | 有傳 ds 時只覆寫那一個分區 |
| `customer_rfm` | 一位用戶 | table | 基準日是快照日；F 用固定門檻；未購買的人另成一群 |
| `customer_360` | 一位用戶 | table，依分群/國家做 cluster | 整合基本資料、交易、行為與 RFM |

- **重點**
  - `fct_events` 的 incremental：dbt 對 BigQuery 的 `insert_overwrite` 是「刪除再寫入整個分區」。有傳 ds 時用 static partitions，最便宜，也是冪等的。MERGE 回報的列數等於刪除數加插入數（494 = 247 + 247）。
  - RFM 的 NTILE 陷阱：大多數人只買 1 次，NTILE 會把同樣 F=1 的人硬切成 1 到 5 分。加 `user_id` 當 tie-breaker，結果才可重現。
  - 基準日不用 `CURRENT_DATE()`，否則重跑歷史日期，分群結果會跟當時不同。
  - `equal_rowcount` 測試保證 `customer_360` 沒有因為 join 而重複，也沒有漏掉人。
- **結果**：champions 佔客戶 7.6%，貢獻 24.6% 的營收；未購買 34,020 人。

## M3 Airflow（🤖 環境 + 🧑 DAG 邏輯）

- **檔案**：`airflow/dags/cdp_daily.py`、`airflow/Dockerfile`、`airflow/docker-compose.override.yml`、`airflow/tests/dags/test_dag_integrity.py`
- **DAG 流程**：`ingest` task group（5 張表各自 extract → load，彼此平行）→ `dbt_build`（`deps` → `source freshness` → `build --vars '{ds: <ds>}'`）
- **重點**
  - `CronDataIntervalTimetable`：11-03 00:00 觸發的 run，data interval 是 [11-02, 11-03)，ds = 11-02，也就是處理「前一天」。
  - **冪等鏈**：GCS 用 `overwrite`、raw 用 `$YYYYMMDD WRITE_TRUNCATE`、`fct_events` 用 `insert_overwrite`，其他 marts 是全量重建。所以任何一天都可以重跑。
  - **快照不能真的 backfill**：公開資料集只有「現在」的狀態。backfill 10/15 的 orders 快照，拿到的其實是今天的資料。這要明確告訴使用者。
  - dbt 裝在獨立的 venv，避免和 Airflow 的套件衝突。
  - `max_active_runs=1` 避免兩個 run 同時寫同一張表；retries 加指數退避處理暫時性錯誤；`execution_timeout` 防止 task 卡住；`on_failure_callback` 是告警的掛載點。
  - **認證**：ADC 以唯讀方式掛進容器，容器的 uid 50000 透過 `group_add` 取得讀取權，檔案權限是 640。到了正式環境，改用 Composer / GKE 的 Workload Identity。

## M4 CI、Terraform state、文件（🤖）

- **檔案**：`.github/workflows/ci.yml`、`terraform/backend.tf`、`.sqlfluff`、`README.md`
- **重點**
  - CI 不需要任何雲端憑證：ruff、sqlfluff、`dbt parse`、`terraform fmt` / `validate`。如果要在 PR 上跑 `dbt build`，應該用 Workload Identity Federation 加上 PR 專用的 dataset。
  - Terraform state 放在開了版本控管的 GCS bucket。這個 bucket 用 gcloud 建立，不讓 Terraform 自己管，避免 `destroy` 連 state 一起刪掉。GCS backend 內建鎖，可以防止多人同時 apply。
