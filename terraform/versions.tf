terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.9" # any 8.x >= 8.9; exact version pinned in .terraform.lock.hcl
    }
  }

  # State lives in a GCS backend (see backend.tf).
}

provider "google" {
  project = var.project_id
  # Auth comes from ADC (`gcloud auth application-default login`); no key files.
}
