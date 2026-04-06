# -----------------------------------------------------------------------------
# Variables — Phase 3: Cloud SQL
# -----------------------------------------------------------------------------

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-east4"
}

variable "environment" {
  description = "Environment label"
  type        = string
  default     = "dev"
}

variable "db_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
  # sensitive = true means this value won't appear in plan/apply output
  # or in the CLI logs. It's STILL in the state file though — which is
  # why remote state with encryption matters.
}

variable "db_tier" {
  description = "Cloud SQL machine tier (similar to RDS instance class)"
  type        = string
  default     = "db-f1-micro"
  # db-f1-micro is the smallest tier. Production would use db-custom-*
  # or db-n1-standard-* depending on workload.
}
