terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }

  # State is local by default. For shared use, create a versioned GCS bucket
  # and uncomment (then `terraform init -migrate-state`):
  #
  # backend "gcs" {
  #   bucket = "<project-id>-tfstate"
  #   prefix = "lucidboard/auth"
  # }
}

provider "google" {
  project = var.project_id

  # The Identity Toolkit and API Keys APIs reject user (ADC) credentials that
  # have no quota project; bill those calls to the target project instead.
  user_project_override = true
  billing_project       = var.project_id
}
