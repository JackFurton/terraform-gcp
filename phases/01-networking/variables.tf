# -----------------------------------------------------------------------------
# Variables — Phase 1: Networking
# -----------------------------------------------------------------------------

variable "project_id" {
  description = "GCP project ID (not the display name — the unique slug)"
  type        = string
  # In AWS terms: this is like your AWS account ID.
  # Every GCP resource lives inside a project.
}

variable "region" {
  description = "GCP region for subnet placement"
  type        = string
  default     = "us-east4"
  # us-east4 = Ashburn, VA — common for DoD/IC workloads.
  # GCP regions are like AWS regions, but subnets are regional (not per-AZ).
}

variable "environment" {
  description = "Environment label (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
