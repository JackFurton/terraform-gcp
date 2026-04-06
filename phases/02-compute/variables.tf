# -----------------------------------------------------------------------------
# Variables — Phase 2: Compute Engine
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

variable "zone" {
  description = "GCP zone within the region (Compute Engine instances are zonal)"
  type        = string
  default     = "us-east4-b"
  # GCP vs AWS: EC2 instances are also per-AZ, so this maps directly.
  # The difference: GCP subnets span the whole region, so any zone works.
}

variable "environment" {
  description = "Environment label"
  type        = string
  default     = "dev"
}

variable "machine_type" {
  description = "Compute Engine machine type (AWS equivalent: instance type)"
  type        = string
  default     = "e2-micro"
  # e2-micro is free tier eligible. In production/gov you'd use
  # n2-standard-* or c2-standard-* depending on workload.
}
