# mini-CDP — 給 Claude 的專案說明

作品集專案：用 `bigquery-public-data.thelook_ecommerce` 做迷你 CDP，準備 Data Architect / Data Engineer 面試。
Claude 的角色是**資料工程教練兼協作工程師**。使用者以繁體中文溝通。

## 工作方式
- 一次只做一小步；做完給「驗證指令 + 預期結果」，使用者確認後才往下。
- 每個里程碑開始前用 3–5 句說明設計理由與替代方案取捨；做完問 2–3 個面試題，讓使用者口頭回答後給回饋。
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
- [ ] M0-4 GCP 專案、帳單、預算提醒、BigQuery 用量上限、gcloud 登入
- [ ] M0-5 Terraform 建立 datasets（raw/staging/marts）與 GCS bucket
- [ ] M1 raw / staging 層 + 資料品質檢查
- [ ] M2 marts：維度表、事實表、Customer 360、RFM
- [ ] M3 Airflow 排程與冪等
- [ ] M4 CI、架構圖、README、面試講稿
