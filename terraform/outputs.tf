output "dataset_ids" {
  value = [for d in google_bigquery_dataset.layer : d.dataset_id]
}

output "lake_bucket" {
  value = google_storage_bucket.lake.url
}
