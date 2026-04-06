# -----------------------------------------------------------------------------
# Outputs — Phase 2: Compute Engine
# -----------------------------------------------------------------------------

output "instance_name" {
  description = "Name of the Compute Engine instance"
  value       = google_compute_instance.main.name
}

output "instance_id" {
  description = "Unique ID of the instance"
  value       = google_compute_instance.main.instance_id
}

output "instance_internal_ip" {
  description = "Internal IP address (no public IP assigned)"
  value       = google_compute_instance.main.network_interface[0].network_ip
}

output "service_account_email" {
  description = "Email of the custom service account"
  value       = google_service_account.vm.email
}

output "ssh_command" {
  description = "Command to SSH via IAP tunneling (no public IP needed)"
  value       = "gcloud compute ssh ${google_compute_instance.main.name} --zone=${var.zone} --tunnel-through-iap"
}
