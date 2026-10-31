# mini-CDP

A small Customer Data Platform on GCP, built on the public
`bigquery-public-data.thelook_ecommerce` dataset.

**Stack:** BigQuery · GCS · dbt · Airflow (Astro CLI, local Docker) · Terraform · GitHub Actions

**Pipeline:** raw → staging → marts (including a Customer 360 table with RFM segments)

> Work in progress. Architecture, design decisions, cost controls and PII notes will be added in milestone M4.
