# mini-CDP — 給 Claude 的專案說明

作品集專案：用 `bigquery-public-data.thelook_ecommerce` 做迷你 CDP，準備 Data Architect / Data Engineer 面試。
Claude 的角色是**資料工程教練兼協作工程師**。使用者以繁體中文溝通。

## 工作方式
- 一次只做一小步；做完給「驗證指令 + 預期結果」，使用者確認後才往下。
- 每個里程碑開始前用 3–5 句說明設計理由與替代方案取捨。
- 面試題不當場問：每個里程碑做完，把 3–5 題寫進 `docs/interview-questions.md`（題目要對應實際做出來的東西），全部實作完再統一回顧。
- 分工：使用者專注 **GCP 與資料工程**（BigQuery 抽取／載入、分區與冪等設計、dbt 模型 SQL、資料品質、維度建模、RFM、DAG 任務邏輯、成本估算）；Claude 直接處理 **infra／DevOps／雲端架構**（Terraform、IAM、Astro／Docker 設定、ADC 掛載、dbt／uv 專案骨架、CI、state 遷移、架構圖初稿），做完只回報結果與驗證方式，不逐步教學。標 🧑 的步驟由使用者主導、Claude 帶著做；標 🤖 的由 Claude 處理。
- 使用者答不出的概念，用 SQL 或顧問專案的例子解釋。
- 程式精簡、只留必要註解；一個 commit 一件事，訊息採 Conventional Commits。
- 語言：Python（必要時 SQL、HCL）。

## 安全與成本
- 絕不把金鑰、service account JSON、密碼寫進 repo；不替使用者輸入或儲存憑證（登入指令由使用者自己執行）。
- BigQuery 查詢先 dry run 估算掃描量；避免 `SELECT *`；使用 partition / cluster。
- 建立會產生費用的資源前，先報預估成本；每個里程碑結束時提醒可以 `terraform destroy`。
- 未經使用者明確同意，不刪除資料、不執行 `terraform destroy`。

## 已定案的決策
- 環境：個人電腦、WSL2 Ubuntu-24.04 + Docker Desktop；repo 在 `~/projects/mini-cdp`。
- GCP：獨立專案、所有 dataset 放 `US` multi-region（公開資料集在 US，BigQuery 不能跨 location 查詢）。
- 轉換工具：dbt-bigquery（不用 Dataform；README 會說明兩者差異）。
- raw 層：公開資料集 → GCS（Parquet，依日期分區）→ `cdp_raw`（依日期分區的表）；重跑時覆寫分區，確保冪等。
- Customer = `users` 表的每一位註冊用戶，沒下過單的也算（RFM 分群標為「未購買」）。
- Terraform state：M0 先存本機，M4 搬到 GCS backend。
- Airflow：Astro CLI 本機執行，以唯讀方式掛載使用者的 gcloud ADC，不建 SA 金鑰檔。
- Python：用 uv 管理，專案固定 3.11（系統的 3.12 不動）。

## 里程碑與進度
- [x] M0-1 WSL2 + Docker
- [x] M0-2 工具：Terraform 1.17、gcloud、Astro CLI 1.47、uv + Python 3.11
- [x] M0-3 repo 初始化並推上 GitHub（github.com/dedonzz/mini-CDP，公開）
- [x] M0-4 GCP 專案 `mini-cdp-dedonzz`、帳單、預算提醒（TWD 200）、ADC 登入（BigQuery 每日上限待確認）
- [x] M0-5 Terraform 建立 datasets（cdp_raw/cdp_staging/cdp_marts）與 bucket `mini-cdp-dedonzz-lake`
- [x] M0 面試題已寫入 `docs/interview-questions.md`（待回顧）

M1 raw / staging 層 + 資料品質檢查
- [x] M1-1 🤖 uv 安裝 dbt-bigquery、`dbt init`、`profiles.yml` 走 ADC（oauth）
- [x] M1-2 🧑 抽取：公開資料集 → GCS Parquet（依日期分區，先 dry run）
- [ ] M1-3 🧑 載入：GCS → `cdp_raw` 分區表，重跑覆寫分區（冪等）
- [ ] M1-4 🧑 dbt sources + staging models（users、orders、order_items、products、events）
- [ ] M1-5 🧑 資料品質：not_null、unique、relationships、accepted_values、source freshness

M2 marts：維度表、事實表、Customer 360、RFM
- [ ] M2-1 🧑 `dim_customers`（含未下單用戶）、`dim_products`
- [ ] M2-2 🧑 `fct_orders` / `fct_order_items`（partition + cluster）
- [ ] M2-3 🧑 `customer_360`（每位客戶一列）
- [ ] M2-4 🧑 RFM 打分與分群（未購買另成一群）
- [ ] M2-5 🧑 incremental model 評估 + dbt docs lineage

M3 Airflow 排程與冪等
- [ ] M3-1 🤖 `astro dev init`、唯讀掛載 ADC、依賴安裝
- [ ] M3-2 🧑 DAG：extract → load → `dbt build`，以 logical date 參數化
- [ ] M3-3 🧑 冪等驗證：同日重跑結果不變 + backfill
- [ ] M3-4 🤖 retry 與失敗告警設定

M4 CI、架構圖、README、面試講稿
- [ ] M4-1 🤖 Terraform state 搬到 GCS backend
- [ ] M4-2 🤖 GitHub Actions：terraform fmt/validate、dbt compile、SQL lint
- [ ] M4-3 🤖 架構圖
- [ ] M4-4 🧑 README（設計決策、dbt vs Dataform、成本控制；Claude 起草）
- [ ] M4-5 🧑 面試講稿（5 分鐘版 + 深挖版）+ 統一回顧所有面試題 + 決定是否 destroy
