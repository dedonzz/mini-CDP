# 面試講稿

## 30 秒版（自我介紹時帶到）

我在 GCP 上做了一個迷你 CDP：每天把電商資料從 BigQuery 公開資料集抽到 GCS，再載入分區表，用 dbt 建出 Customer 360 和 RFM 分群，由 Airflow 排程。整條 pipeline 每一步都以邏輯日期參數化，可以任意重跑和回補，每天的成本控制在免費額度內。

## 5 分鐘版

1. **問題**（30 秒）
   行銷需要「一位客戶一列」的完整視圖：基本資料、消費、行為、分群。資料來源是電商的用戶、訂單、商品和網站事件。

2. **架構**（1 分鐘，邊講邊指 README 的圖）
   - 來源 → GCS Parquet lake → BigQuery raw → staging → marts。
   - Airflow 每天跑：5 張表平行抽取和載入，然後 dbt build（模型加測試）。
   - Terraform 管 dataset、bucket 和 state；CI 做靜態檢查。

3. **最關鍵的三個設計決策**（2 分鐘）
   - **抽取策略依表的特性決定。** orders 的狀態會變，又沒有 `updated_at`，所以每天全量快照；events 只會新增、量大，所以依日期增量。這讓我避開了「舊訂單退貨永遠不會進來」的坑。
   - **每一層都是冪等的。** 每一步都只替換 ds 那一個分區：GCS 用 overwrite，raw 用 load job 加 `table$YYYYMMDD` 和 `WRITE_TRUNCATE`，events 事實表用 dbt `insert_overwrite`。所以 Airflow 重跑任何一天都不會重複。
   - **成本是設計出來的。** 每個 job 都有 `maximum_bytes_billed` 上限；staging 用常數日期過濾，保證分區剪枝，我用 dry run 驗證過掃描量是 0。我還發現公開的 events 表沒有分區，每抽一天要掃 385 MB，所以歷史改成一次查詢回補，而不是逐日跑。

4. **資料品質**（45 秒）
   主鍵、關聯、值域壞掉時讓 pipeline 失敗；來源資料的業務瑕疵只發警告。另外有對帳測試，以及 Customer 360 和客戶數的列數一致性檢查。source freshness 用來偵測 pipeline 有沒有在跑。

5. **結果和反思**（45 秒）
   - 10 萬位客戶，34% 從未購買，這群人也被保留下來，因為他們是行銷轉換的目標。champions 佔客戶 7.6%，貢獻 24.6% 的營收。
   - 想改進的地方：
     - 分群目前只有當下的狀態，應該每天存一份分群快照，才能分析客戶在分群之間的移動。
     - 正式環境要改用 Workload Identity 和 CDC。
     - PII 要加上 policy tag。

## 深挖時準備好的話題

| 被問到 | 你要講的 |
|---|---|
| 「為什麼不直接 CTAS 到 raw？」 | GCS 是可重播的 lake，和 BigQuery 解耦，也能給其他引擎讀。代價是多一跳，以及小檔案問題。 |
| 「冪等怎麼測？」 | 同一天重跑兩次，用 `INFORMATION_SCHEMA.PARTITIONS` 比對筆數；Airflow 上手動觸發同一個 logical date。 |
| 「快照能 backfill 嗎？」 | 不能。來源只有現在的狀態，這是快照設計的固有限制。要歷史就要從第一天開始累積，或改用 CDC。 |
| 「為什麼 dbt 不用 Dataform？」 | 生態系（套件、測試、文件）和跨倉儲的可攜性。如果團隊只用 GCP，Dataform 免維運，也是合理選擇。 |
| 「RFM 怎麼分？」 | R、M 用 NTILE(5) 加 tie-breaker；F 用固定門檻，因為大多數人只買一次；基準日用快照日，確保可重現。 |
| 「上線到正式環境要改什麼？」 | Composer 或 GKE 用 Workload Identity；dbt 用 KubernetesPodOperator 或 Cosmos；告警接 Slack；CI 加上 slim `dbt build`（WIF）；PII 加 policy tags。 |
| 「最大的坑？」 | 公開的 events 表沒有分區，WHERE 條件省不了掃描量。我是 dry run 時才發現的，所以養成了先 dry run 的習慣。 |
