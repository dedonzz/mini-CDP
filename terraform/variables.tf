variable "project_id" {
  description = "GCP project that hosts all mini-CDP resources."
  type        = string
}

variable "location" {
  description = "Must be US: the thelook_ecommerce public dataset lives in US, and BigQuery cannot query across locations."
  type        = string
  default     = "US"
}

variable "lake_retention_days" {
  description = "Days to keep exported Parquet files in the lake bucket. They can be re-exported from the public dataset."
  type        = number
  default     = 90
}
