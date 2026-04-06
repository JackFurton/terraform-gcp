# -----------------------------------------------------------------------------
# Outputs — Phase 3: Cloud SQL
# -----------------------------------------------------------------------------

output "instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.main.name
}

output "instance_connection_name" {
  description = "Connection name (used by Cloud SQL Proxy and IAM auth)"
  value       = google_sql_database_instance.main.connection_name
}

output "private_ip" {
  description = "Private IP address of the database (no public IP)"
  value       = google_sql_database_instance.main.private_ip_address
}

output "database_name" {
  description = "Name of the application database"
  value       = google_sql_database.app.name
}

output "connect_command" {
  description = "Connect via Cloud SQL Proxy (from a VM in the VPC)"
  value       = "cloud-sql-proxy ${google_sql_database_instance.main.connection_name}"
}
