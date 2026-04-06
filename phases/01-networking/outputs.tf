# -----------------------------------------------------------------------------
# Outputs — Phase 1: Networking
# -----------------------------------------------------------------------------
# These outputs will be consumed by later phases via terraform_remote_state
# or as input variables. This is how you chain independent Terraform configs.

output "vpc_id" {
  description = "Self-link of the VPC (used by other resources to reference this network)"
  value       = google_compute_network.main.id
}

output "vpc_name" {
  description = "Name of the VPC"
  value       = google_compute_network.main.name
}

output "subnet_id" {
  description = "Self-link of the private subnet"
  value       = google_compute_subnetwork.private.id
}

output "subnet_name" {
  description = "Name of the private subnet"
  value       = google_compute_subnetwork.private.name
}

output "subnet_cidr" {
  description = "CIDR range of the private subnet"
  value       = google_compute_subnetwork.private.ip_cidr_range
}

output "pod_range_name" {
  description = "Name of the secondary range for GKE pods"
  value       = "pods"
}

output "service_range_name" {
  description = "Name of the secondary range for GKE services"
  value       = "services"
}
