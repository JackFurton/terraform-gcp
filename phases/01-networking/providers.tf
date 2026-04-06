# -----------------------------------------------------------------------------
# Provider Configuration — Phase 1
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # For the interview, know that production/gov environments ALWAYS use a
  # remote backend. GCS is the GCP equivalent of S3 for state storage.
  # Uncomment and configure when you have a real GCP project:
  #
  # backend "gcs" {
  #   bucket = "your-project-tfstate"
  #   prefix = "phases/01-networking"
  # }
  #
  # Key points for the interview:
  # - State bucket should have versioning enabled (object recovery)
  # - State bucket should have uniform bucket-level access (no per-object ACLs)
  # - Enable state locking (GCS does this automatically, unlike S3 which
  #   needs a separate DynamoDB table)
  # - For DoD: state contains secrets — bucket must be in the same
  #   Assured Workloads folder as your compute resources
}

provider "google" {
  project = var.project_id
  region  = var.region
}
