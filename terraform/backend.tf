# State 存在 GCS（開啟版本控管，可回溯）；bucket 由 gcloud 預先建立，不受本設定管理，
# 避免 terraform destroy 連 state 一起刪掉。GCS backend 內建 state locking。
terraform {
  backend "gcs" {
    bucket = "mini-cdp-dedonzz-tfstate"
    prefix = "mini-cdp"
  }
}
