locals {
  labels = { project = "mini-cdp", managed_by = "terraform" }

  # One dataset per layer: raw (as landed) -> staging (cleaned) -> marts (business-ready).
  datasets = {
    cdp_raw     = "Raw layer: data as loaded from the lake, partitioned by load date."
    cdp_staging = "Staging layer: typed, renamed, deduplicated models (dbt)."
    cdp_marts   = "Marts layer: dimensions, facts, Customer 360 and RFM (dbt)."
  }
}

resource "google_bigquery_dataset" "layer" {
  for_each = local.datasets

  dataset_id  = each.key
  description = each.value
  location    = var.location
  labels      = local.labels

  # Sandbox project: allow `terraform destroy` to remove tables too.
  # Everything here can be rebuilt from the public dataset.
  delete_contents_on_destroy = true
}

resource "google_storage_bucket" "lake" {
  name     = "${var.project_id}-lake"
  location = var.location
  labels   = local.labels

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true # sandbox: same reasoning as the datasets

  lifecycle_rule {
    condition { age = var.lake_retention_days }
    action { type = "Delete" }
  }
}
